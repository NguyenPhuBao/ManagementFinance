const { randomUUID } = require('crypto');
const { prisma } = require('../../config/db');

const bankRepository = {
  /**
   * Lưu hoặc cập nhật danh sách thẻ ngân hàng lấy từ Casso
   * CSDL mới: Connect_status in ('Active', 'expired', 'Disconnected'), Id_casso_account unique
   */
  async upsertBankAccounts(idaccount, cassoAccountList) {
    const results = [];
    for (const acc of cassoAccountList) {
      const cassoAccountId = String(acc.id);

      const updateData = {
        idaccount: idaccount,
        id_casso_account: cassoAccountId,
        account_number: acc.bankSubAccId || acc.accountNumber || 'UNKNOWN',
        account_name: acc.accountName || acc.virtualAccountName || 'Unknown Name',
        bank_name: acc.bankAbbrName || acc.bankName || 'Unknown Bank',
        balance: acc.balance || 0,
        connect_status: 'Active',
        update_at: new Date(),
      };

      const upserted = await prisma.bank_account.upsert({
        where: { id_casso_account: cassoAccountId },
        update: updateData,
        create: {
          id_bank_account: randomUUID(),
          ...updateData,
        },
      });
      results.push(upserted);
    }
    return results;
  },

  /**
   * Lấy danh sách tài khoản ngân hàng của 1 user (chỉ tài khoản chưa xóa)
   */
  async getBankAccountsByUser(idaccount) {
    return prisma.bank_account.findMany({
      where: { idaccount, delete_at: null },
      orderBy: { update_at: 'desc' },
    });
  },

  /**
   * Cập nhật số dư tài khoản ngân hàng từ webhook
   */
  async updateBankBalance(idCassoAccount, balance) {
    return prisma.bank_account.update({
      where: { id_casso_account: idCassoAccount },
      data: {
        balance: balance,
        update_at: new Date(),
      },
    });
  },

  /**
   * Tìm giao dịch dựa trên (provider, bank_tran_id) để tránh duplicate (Webhook)
   * CSDL mới: bank_tran_id, provider
   */
  async findTransactionByExternalId(provider, externalId) {
    return prisma.transaction.findFirst({
      where: {
        provider: { in: [provider, 'BankSync', 'Casso'] },
        bank_tran_id: String(externalId),
      },
    });
  },

  /**
   * Tạo transaction mới từ Webhook Casso (mặc định status = Pending chờ người dùng duyệt)
   */
  async createTransactionFromWebhook(data) {
    return prisma.transaction.create({
      data: {
        idtran: data.idtran || randomUUID(),
        idaccount: data.idaccount,
        idwallet: data.idwallet,
        idcategory: data.idcategory || null,
        idwallet_transfer: data.idwallet_transfer || null,
        bank_tran_id: String(data.bank_tran_id),
        amount: data.amount ?? 0,
        type: data.type || 'Transaction',
        status: data.status || 'Pending',
        provider: data.provider || 'BankSync',
        note: data.note || 'Giao dịch ngân hàng',
        images: data.images || null,
        date_transaction: data.date_transaction || data.create_at || new Date(),
        update_at: new Date(),
        deleted_at: null,
      },
    });
  },

  /**
   * Lấy danh sách các giao dịch đang Pending (chờ duyệt) của người dùng
   */
  async getPendingTransactions(idaccount) {
    return prisma.transaction.findMany({
      where: {
        idaccount,
        status: 'Pending',
        deleted_at: null,
      },
      include: {
        wallet: {
          select: {
            name: true,
            type: true,
            id_bank_casso: true,
          },
        },
      },
      orderBy: { date_transaction: 'desc' },
    });
  },

  /**
   * Xác nhận giao dịch ngân hàng (Duyệt và gán danh mục)
   */
  async confirmTransaction(idtran, idaccount, { idcategory, note }) {
    return prisma.transaction.update({
      where: {
        idtran: String(idtran),
        idaccount: Number(idaccount),
      },
      data: {
        status: 'Confirmed',
        idcategory: idcategory || null,
        ...(note !== undefined ? { note } : {}),
        update_at: new Date(),
      },
    });
  },

  /**
   * Từ chối giao dịch ngân hàng (Chuyển status sang Rejected)
   */
  async rejectTransaction(idtran, idaccount) {
    return prisma.transaction.update({
      where: {
        idtran: String(idtran),
        idaccount: Number(idaccount),
      },
      data: {
        status: 'Rejected',
        update_at: new Date(),
      },
    });
  },

  /**
   * Đánh dấu giao dịch bị lỗi xử lý (Fail)
   */
  async failTransaction(idtran, idaccount) {
    return prisma.transaction.update({
      where: {
        idtran: String(idtran),
        idaccount: Number(idaccount),
      },
      data: {
        status: 'Fail',
        update_at: new Date(),
      },
    });
  },

  /**
   * Tìm bank_account bằng id_casso_account
   */
  async findBankAccountByCassoId(cassoAccountId) {
    return prisma.bank_account.findUnique({
      where: { id_casso_account: String(cassoAccountId) },
    });
  },

  /**
   * Tìm bank_account bằng account_number
   */
  async findBankAccountByAccountNumber(accountNumber) {
    return prisma.bank_account.findFirst({
      where: {
        account_number: String(accountNumber),
        connect_status: { in: ['Active', 'active'] },
        delete_at: null,
      },
    });
  },
};

module.exports = bankRepository;
