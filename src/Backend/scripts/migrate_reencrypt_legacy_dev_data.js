/**
 * Migration Script: Di trú và Mã hóa lại dữ liệu cũ sang Khóa .env chính thức (Task 52.3 - 52.5)
 * 
 * Mục tiêu:
 * - Tìm các bản ghi transaction.note, user.phone, v.v. được mã hóa bằng khóa dev mặc định cũ
 * - Giải mã an toàn bằng khóa dev cũ
 * - Mã hóa lại bằng khóa DATA_ENCRYPTION_KEY từ .env hiện tại
 * - Đảm bảo sau khi chạy, 100% CSDL giải mã thành công bằng khóa .env (0 bản ghi hỏng)
 */

require('dotenv').config({ path: 'src/Backend/.env' });
const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');
const { encrypt, decrypt } = require('../utils/crypto.util');

const prisma = new PrismaClient();

const defaultDevKeyHex = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
let devKey;
try {
  devKey = Buffer.from(defaultDevKeyHex, 'hex');
  if (devKey.length !== 32) {
    devKey = crypto.createHash('sha256').update(defaultDevKeyHex).digest();
  }
} catch {
  devKey = crypto.createHash('sha256').update(defaultDevKeyHex).digest();
}

function tryDecryptDev(cipherText) {
  if (!cipherText || !cipherText.startsWith('enc:')) return null;
  try {
    const parts = cipherText.slice(4).split(':');
    if (parts.length !== 3) return null;
    const [ivHex, tagHex, dataHex] = parts;
    const iv = Buffer.from(ivHex, 'hex');
    const tag = Buffer.from(tagHex, 'hex');
    const decipher = crypto.createDecipheriv('aes-256-gcm', devKey, iv);
    decipher.setAuthTag(tag);
    let dec = decipher.update(dataHex, 'hex', 'utf8');
    dec += decipher.final('utf8');
    return dec;
  } catch {
    return null;
  }
}

function canDecryptEnv(cipherText) {
  if (!cipherText || !cipherText.startsWith('enc:')) return true;
  try {
    decrypt(cipherText);
    return true;
  } catch {
    return false;
  }
}

async function runMigration() {
  console.log('🔄 [MIGRATION 52] Bắt đầu rà soát và mã hóa lại dữ liệu dev cũ...');
  console.log('Database URL Host:', process.env.DATABASE_URL ? process.env.DATABASE_URL.split('@')[1]?.split('/')[0] : 'local');

  // 1. Quét bảng transaction
  const txs = await prisma.transaction.findMany({
    where: { note: { startsWith: 'enc:' } },
    select: { idtran: true, note: true, idaccount: true, deleted_at: true },
  });

  console.log(`📋 Tìm thấy ${txs.length} giao dịch có chứa chuỗi mã hóa enc:...`);
  let txReencrypted = 0;

  let soKhongXuLy = 0;

  for (const tx of txs) {
    // Nếu khóa env không giải được nhưng khóa dev giải được -> cần re-encrypt
    if (!canDecryptEnv(tx.note)) {
      const plain = tryDecryptDev(tx.note);
      if (plain !== null) {
        const newEnc = encrypt(plain);
        await prisma.transaction.update({
          where: { idtran: tx.idtran },
          data: { note: newEnc },
        });
        txReencrypted++;
        console.log(`  ✔ [transaction] Đã re-encrypt idtran: ${tx.idtran} (account: ${tx.idaccount})`);
      } else {
        soKhongXuLy++;
        console.warn(`  ⚠️ [transaction] Không thể giải mã cả dev lẫn env cho idtran: ${tx.idtran}`);
      }
    }
  }

  // 2. Quét bảng User (phone & address)
  const users = await prisma.user.findMany({
    select: { iduser: true, idaccount: true, phone: true, address: true },
  });

  let userReencrypted = 0;
  for (const u of users) {
    let needsUpdate = false;
    const updateData = {};

    if (u.phone && u.phone.startsWith('enc:') && !canDecryptEnv(u.phone)) {
      const plainPhone = tryDecryptDev(u.phone);
      if (plainPhone !== null) {
        updateData.phone = encrypt(plainPhone);
        needsUpdate = true;
      } else {
        soKhongXuLy++;
        console.warn(`  ⚠️ [user] Không thể giải mã phone cả dev lẫn env cho iduser: ${u.iduser}`);
      }
    }

    if (u.address && u.address.startsWith('enc:') && !canDecryptEnv(u.address)) {
      const plainAddress = tryDecryptDev(u.address);
      if (plainAddress !== null) {
        updateData.address = encrypt(plainAddress);
        needsUpdate = true;
      } else {
        soKhongXuLy++;
        console.warn(`  ⚠️ [user] Không thể giải mã address cả dev lẫn env cho iduser: ${u.iduser}`);
      }
    }

    if (needsUpdate) {
      await prisma.user.update({
        where: { iduser: u.iduser },
        data: updateData,
      });
      userReencrypted++;
      console.log(`  ✔ [user] Đã re-encrypt thông tin iduser: ${u.iduser} (account: ${u.idaccount})`);
    }
  }

  console.log('-----------------------------------------------------------');
  if (soKhongXuLy > 0) {
    console.error(`❌ CÒN HÀNG HỎNG: Có ${soKhongXuLy} ô dữ liệu không giải được bằng cả hai khóa.`);
    process.exit(1);
  }
  console.log(`🎉 HOÀN TẤT DI TRÚ: Re-encrypt thành công ${txReencrypted} transactions và ${userReencrypted} users.`);
}

runMigration()
  .catch((err) => {
    console.error('❌ Lỗi di trú re-encryption:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

