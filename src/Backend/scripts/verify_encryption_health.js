/**
 * Script thẩm tra toàn vẹn mã hóa dữ liệu At-Rest (AES-256-GCM) trên CSDL (Task 52.3 - 52.5)
 * Tuân thủ Nghị định 13/2023/NĐ-CP & PCI-DSS v4.0
 * 
 * Quét toàn bộ các cột nhạy cảm:
 * - transaction.note
 * - user.phone
 * - user.address
 * - bank_account.account_number
 * - bill.note
 * - budget.note
 * - goal.note
 * 
 * Kiểm tra: Mọi chuỗi enc:... đều phải giải mã thành công bằng DATA_ENCRYPTION_KEY hiện tại.
 * Trả về Exit Code: 0 nếu 100% bản ghi an toàn; 1 nếu có bản ghi bị lỗi giải mã.
 */

require('dotenv').config({ path: 'src/Backend/.env' });
const { PrismaClient } = require('@prisma/client');
const { decrypt, isEncrypted } = require('../utils/crypto.util');

const prisma = new PrismaClient();

async function verifyEncryptionHealth() {
  console.log('🔄 [AUDIT DATA ENCRYPTION] Bắt đầu thẩm tra toàn vẹn dữ liệu mã hóa...');
  console.log('Host CSDL:', process.env.DATABASE_URL ? process.env.DATABASE_URL.split('@')[1]?.split('/')[0] : 'local');

  let totalEncrypted = 0;
  let totalErrors = 0;
  const errorDetails = [];

  // 1. Transaction (note)
  const txs = await prisma.transaction.findMany({
    select: { idtran: true, note: true, idaccount: true, deleted_at: true },
  });
  let txEnc = 0;
  let txErr = 0;
  for (const t of txs) {
    if (t.note && isEncrypted(t.note)) {
      totalEncrypted++;
      txEnc++;
      try {
        decrypt(t.note, { table: 'transaction', id: t.idtran });
      } catch (err) {
        totalErrors++;
        txErr++;
        errorDetails.push({ table: 'transaction', id: t.idtran, account: t.idaccount, deleted: !!t.deleted_at, error: err.message });
      }
    }
  }
  console.log(`  [transaction] Tổng: ${txs.length} | Mã hóa: ${txEnc} | Lỗi giải mã: ${txErr}`);

  // 2. User (phone & address)
  const users = await prisma.user.findMany({
    select: { iduser: true, idaccount: true, phone: true, address: true, delete_at: true },
  });
  let userEnc = 0;
  let userErr = 0;
  for (const u of users) {
    if (u.phone && isEncrypted(u.phone)) {
      totalEncrypted++;
      userEnc++;
      try {
        decrypt(u.phone, { table: 'user', id: u.iduser || u.idaccount, field: 'phone' });
      } catch (err) {
        totalErrors++;
        userErr++;
        errorDetails.push({ table: 'user', id: u.iduser, field: 'phone', account: u.idaccount, deleted: !!u.delete_at, error: err.message });
      }
    }
    if (u.address && isEncrypted(u.address)) {
      totalEncrypted++;
      userEnc++;
      try {
        decrypt(u.address, { table: 'user', id: u.iduser || u.idaccount, field: 'address' });
      } catch (err) {
        totalErrors++;
        userErr++;
        errorDetails.push({ table: 'user', id: u.iduser, field: 'address', account: u.idaccount, deleted: !!u.delete_at, error: err.message });
      }
    }
  }
  console.log(`  [user]        Tổng: ${users.length} | Mã hóa: ${userEnc} | Lỗi giải mã: ${userErr}`);

  // 3. Bank Account (account_number)
  const bankAccounts = await prisma.bank_account.findMany({
    select: { id_bank_account: true, account_number: true, idaccount: true },
  });
  let bankEnc = 0;
  let bankErr = 0;
  for (const b of bankAccounts) {
    if (b.account_number && isEncrypted(b.account_number)) {
      totalEncrypted++;
      bankEnc++;
      try {
        decrypt(b.account_number, { table: 'bank_account', id: b.id_bank_account });
      } catch (err) {
        totalErrors++;
        bankErr++;
        errorDetails.push({ table: 'bank_account', id: b.id_bank_account, account: b.idaccount, error: err.message });
      }
    }
  }
  console.log(`  [bank_account]Tổng: ${bankAccounts.length} | Mã hóa: ${bankEnc} | Lỗi giải mã: ${bankErr}`);

  // 4. Bills, Budgets, Goals (note)
  const bills = await prisma.bill.findMany({ select: { idbill: true, note: true, idaccount: true } });
  let billEnc = 0, billErr = 0;
  for (const b of bills) {
    if (b.note && isEncrypted(b.note)) {
      totalEncrypted++;
      billEnc++;
      try {
        decrypt(b.note, { table: 'bill', id: b.idbill });
      } catch (err) {
        totalErrors++;
        billErr++;
        errorDetails.push({ table: 'bill', id: b.idbill, error: err.message });
      }
    }
  }

  const budgets = await prisma.budget.findMany({ select: { idbudget: true, note: true, idaccount: true } });
  let budgetEnc = 0, budgetErr = 0;
  for (const b of budgets) {
    if (b.note && isEncrypted(b.note)) {
      totalEncrypted++;
      budgetEnc++;
      try {
        decrypt(b.note, { table: 'budget', id: b.idbudget });
      } catch (err) {
        totalErrors++;
        budgetErr++;
        errorDetails.push({ table: 'budget', id: b.idbudget, error: err.message });
      }
    }
  }

  const goals = await prisma.goal.findMany({ select: { idgoal: true, note: true, idaccount: true } });
  let goalEnc = 0, goalErr = 0;
  for (const g of goals) {
    if (g.note && isEncrypted(g.note)) {
      totalEncrypted++;
      goalEnc++;
      try {
        decrypt(g.note, { table: 'goal', id: g.idgoal });
      } catch (err) {
        totalErrors++;
        goalErr++;
        errorDetails.push({ table: 'goal', id: g.idgoal, error: err.message });
      }
    }
  }
  console.log(`  [bill/budget/goal] Mã hóa: ${billEnc + budgetEnc + goalEnc} | Lỗi giải mã: ${billErr + budgetErr + goalErr}`);

  console.log('-----------------------------------------------------------');
  console.log(`📊 TỔNG KẾT: ${totalEncrypted} trường dữ liệu mã hóa được kiểm tra.`);

  if (totalErrors === 0) {
    console.log('🎉 100% DỮ LIỆU MÃ HÓA HỢP LỆ VÀ AN TOÀN TUYỆT ĐỐI (0 LỖI)!');
    return true;
  } else {
    console.error(`❌ PHÁT HIỆN ${totalErrors} BẢN GHI LỖI GIẢI MÃ:`, JSON.stringify(errorDetails, null, 2));
    process.exit(1);
  }
}

verifyEncryptionHealth()
  .catch((err) => {
    console.error('Lỗi thẩm tra mã hóa:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
