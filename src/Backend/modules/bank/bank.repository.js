const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const bankRepository = {
  /**
   * Lưu hoặc cập nhật danh sách thẻ ngân hàng lấy từ Casso
   */
  async upsertBankAccounts(idaccount, cassoAccountList) {
    const results = [];
    for (const acc of cassoAccountList) {
      const cassoAccountId = String(acc.id);
      
      const data = {
        idaccount: idaccount,
        casso_account_id: cassoAccountId,
        account_number: acc.bankSubAccId || 'UNKNOWN',
        account_name: acc.virtualAccountName || 'Unknown Name',
        bank_name: acc.bankAbbrName || acc.bankName || 'Unknown Bank',
        balance: acc.balance || 0,
        connect_status: 'active',
        updated_at: new Date()
      };

      const upserted = await prisma.bank_account.upsert({
        where: { casso_account_id: cassoAccountId },
        update: data,
        create: data
      });
      results.push(upserted);
    }
    return results;
  },

  /**
   * Lấy danh sách tài khoản ngân hàng của 1 user
   */
  async getBankAccountsByUser(idaccount) {
    return prisma.bank_account.findMany({
      where: { idaccount }
    });
  },

  /**
   * Cập nhật số dư tài khoản ngân hàng từ webhook
   */
  async updateBankBalance(cassoAccountId, balance) {
    return prisma.bank_account.update({
      where: { casso_account_id: cassoAccountId },
      data: {
        balance: balance,
        updated_at: new Date()
      }
    });
  },

  /**
   * Tìm giao dịch dựa trên external_id để tránh duplicate (Webhook)
   */
  async findTransactionByExternalId(provider, externalId) {
    return prisma.transaction.findFirst({
      where: {
        provider: provider,
        external_transaction_id: externalId
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
   * Tìm bank_account bằng casso_account_id
   */
  async findBankAccountByCassoId(cassoAccountId) {
    return prisma.bank_account.findUnique({
      where: { casso_account_id: cassoAccountId }
    });
  }
};

module.exports = bankRepository;
