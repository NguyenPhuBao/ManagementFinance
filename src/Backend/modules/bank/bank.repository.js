/**
 * Bank Repository
 * Quản trị dữ liệu tài khoản ngân hàng và giao dịch trong PostgreSQL (Prisma)
 */

const { randomUUID } = require('crypto');
const { prisma } = require('../../config/db');
const logger = require('../../core/logger');
const { encrypt, decrypt, hashBlindIndex } = require('../../utils/crypto.util');
const { filterSensitiveNote } = require('../../utils/content-filter.util');

const bankRepository = {
  /**
   * Người dùng tự khai báo/đăng ký tài khoản ngân hàng từ Client-app
   * Tự động tạo bản ghi bank_account và ví wallet Banking
   */
  async registerAccount(idaccount, { account_number, bank_name, account_name, balance = 0 }) {
    const accNumber = String(account_number).trim();
    const externalId = `acc_${accNumber}`;
    const encryptedAccNumber = encrypt(accNumber);
    const accNumberHash = hashBlindIndex(accNumber);

    const updateData = {
      idaccount,
      id_casso_account: externalId,
      account_number: encryptedAccNumber,
      account_number_hash: accNumberHash,
      account_name: account_name || 'Tài khoản ngân hàng',
      bank_name: bank_name || 'Ngân hàng',
      balance: Number(balance) || 0,
      connect_status: 'Active',
      update_at: new Date(),
    };

    const upserted = await prisma.bank_account.upsert({
      where: { id_casso_account: externalId },
      update: updateData,
      create: {
        id_bank_account: randomUUID(),
        ...updateData,
      },
    });

    let wallet = await prisma.wallet.findFirst({
      where: {
        idaccount,
        id_bank_casso: upserted.id_bank_account,
        delete_at: null,
      },
    });

    if (!wallet) {
      const rawWalletName = `${upserted.bank_name} - ${upserted.account_number}`;
      const walletName = rawWalletName.length > 100 ? rawWalletName.substring(0, 100) : rawWalletName;

      wallet = await prisma.wallet.create({
        data: {
          idwallet: randomUUID(),
          idaccount,
          name: walletName,
          type: 'Banking',
          id_bank_casso: upserted.id_bank_account,
          balance: Number(balance) || 0,
          update_at: new Date(),
        },
      });
      logger.info('Auto-created Banking wallet for registered account', {
        idaccount,
        walletName,
      });
    }

    return { bank_account: upserted, wallet };
  },

  /**
   * Lưu hoặc cập nhật danh sách tài khoản ngân hàng từ SePay / Gateway
   * Đồng thời tự động sinh ví Banking tương ứng trong bảng wallet nếu chưa có
   *
   * @param {number} idaccount User ID
   * @param {Array<Object>} accountList Danh sách tài khoản
   */
  async upsertBankAccounts(idaccount, accountList) {
    const results = [];
    for (const acc of accountList) {
      const sepayAccountId = String(acc.bank_account_xid || acc.id_casso_account || acc.id);
      const accountNumber = String(acc.account_number || acc.bankSubAccId || acc.accountNumber || 'UNKNOWN');
      const accountName = String(acc.account_name || acc.holder_name || acc.virtualAccountName || 'Unknown Name');
      const bankName = String(acc.gateway || acc.bank_name || acc.bankAbbrName || 'Unknown Bank');
      const balance = acc.accumulated !== undefined ? Number(acc.accumulated) : Number(acc.balance) || 0;
      const status =
        acc.status === 'active' || acc.status === 'Active' || acc.connect_status === 'Active'
          ? 'Active'
          : 'Expired';

      const encryptedAccNumber = encrypt(accountNumber);
      const accNumberHash = hashBlindIndex(accountNumber);

      const updateData = {
        idaccount,
        id_casso_account: sepayAccountId,
        account_number: encryptedAccNumber,
        account_number_hash: accNumberHash,
        account_name: accountName,
        bank_name: bankName,
        balance,
        connect_status: status,
        update_at: new Date(),
      };

      const upserted = await prisma.bank_account.upsert({
        where: { id_casso_account: sepayAccountId },
        update: updateData,
        create: {
          id_bank_account: randomUUID(),
          ...updateData,
        },
      });

      // Tự động kiểm tra và khởi tạo ví Banking nếu chưa tồn tại
      const existingWallet = await prisma.wallet.findFirst({
        where: {
          idaccount,
          id_bank_casso: upserted.id_bank_account,
          delete_at: null,
        },
      });

      if (!existingWallet) {
        const rawWalletName = `${bankName} - ${accountNumber}`;
        const walletName = rawWalletName.length > 100 ? rawWalletName.substring(0, 100) : rawWalletName;

        await prisma.wallet.create({
          data: {
            idwallet: randomUUID(),
            idaccount,
            name: walletName,
            type: 'Banking',
            id_bank_casso: upserted.id_bank_account,
            balance,
            update_at: new Date(),
          },
        });
        logger.info('Auto-created Banking wallet for linked bank account', {
          idaccount,
          bankAccountId: upserted.id_bank_account,
          walletName,
        });
      }

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
        balance,
        update_at: new Date(),
      },
    });
  },

  /**
   * Tìm giao dịch dựa trên (provider, bank_tran_id) để tránh duplicate (Webhook)
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
   * Tạo transaction mới từ Webhook (mặc định status = Pending chờ người dùng duyệt)
   */
  async createTransactionFromWebhook(data) {
    const rawNote = data.note || 'Giao dịch ngân hàng';
    const safeNote = encrypt(filterSensitiveNote(rawNote));

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
        note: safeNote,
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
    const list = await prisma.transaction.findMany({
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

    return list.map((tx) => ({
      ...tx,
      note: tx.note ? decrypt(tx.note) : tx.note,
    }));
  },

  /**
   * Người dùng xác nhận duyệt giao dịch (Chuyển sang Confirmed)
   */
  async confirmTransaction(idtran, idaccount, { idcategory, note }) {
    const data = {
      status: 'Confirmed',
      update_at: new Date(),
    };
    if (idcategory) {
      data.idcategory = idcategory;
    }
    if (note) {
      data.note = encrypt(filterSensitiveNote(note));
    }

    return prisma.transaction.update({
      where: {
        idtran,
        idaccount,
      },
      data,
    });
  },

  /**
   * Người dùng từ chối giao dịch (Chuyển sang Rejected)
   */
  async rejectTransaction(idtran, idaccount) {
    return prisma.transaction.update({
      where: {
        idtran,
        idaccount,
      },
      data: {
        status: 'Rejected',
        update_at: new Date(),
      },
    });
  },

  /**
   * Đánh dấu giao dịch bị lỗi (Fail)
   */
  async failTransaction(idtran, idaccount) {
    return prisma.transaction.update({
      where: {
        idtran,
        idaccount,
      },
      data: {
        status: 'Fail',
        update_at: new Date(),
      },
    });
  },
};

module.exports = bankRepository;
