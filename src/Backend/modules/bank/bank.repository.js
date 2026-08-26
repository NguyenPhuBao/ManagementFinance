const { prisma } = require('../../config/db');

const bankRepository = {
  /**
   * Lưu hoặc cập nhật danh sách thẻ ngân hàng lấy từ Casso
   * CSDL mới: casso_account_id → id_casso_account, update_at
   */
  async upsertBankAccounts(idaccount, cassoAccountList) {
    const results = [];
    for (const acc of cassoAccountList) {
      const cassoAccountId = String(acc.id);

      const data = {
        idaccount: idaccount,
        id_casso_account: cassoAccountId,
        account_number: acc.bankSubAccId || 'UNKNOWN',
        account_name: acc.virtualAccountName || 'Unknown Name',
        bank_name: acc.bankAbbrName || acc.bankName || 'Unknown Bank',
        balance: acc.balance || 0,
        connect_status: 'active',
        update_at: new Date()
      };

      const upserted = await prisma.bank_account.upsert({
        where: { id_casso_account: cassoAccountId },
        update: data,
        create: data
      });
      results.push(upserted);
    }
    return results;
  },

  /**
   * Lấy danh sách tài khoản ngân hàng của 1 user (chỉ tài khoản đang hoạt động)
   */
  async getBankAccountsByUser(idaccount) {
    return prisma.bank_account.findMany({
      where: { idaccount, delete_at: null }
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
        update_at: new Date()
      }
    });
  },

  /**
   * Tìm giao dịch dựa trên (provider, bank_tran_id) để tránh duplicate (Webhook)
   * CSDL mới: external_transaction_id → bank_tran_id
   */
  async findTransactionByExternalId(provider, externalId) {
    return prisma.transaction.findFirst({
      where: {
        provider: provider,
        bank_tran_id: externalId
      }
    });
  },

  /**
   * Tạo transaction mới từ Webhook Casso
   */
  async createTransactionFromWebhook(data) {
    return prisma.transaction.create({
      data: data
    });
  },

  /**
   * Tìm bank_account bằng id_casso_account
   */
  async findBankAccountByCassoId(cassoAccountId) {
    return prisma.bank_account.findUnique({
      where: { id_casso_account: cassoAccountId }
    });
  }
};

module.exports = bankRepository;
