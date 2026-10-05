/**
 * DB Safety Guard - Hàng rào bảo vệ CSDL PostgreSQL Supabase
 * Ngăn chặn việc chạy các lệnh có nguy cơ phá hủy Partial Indexes và Triggers
 * như `prisma migrate dev` hoặc `prisma db push` trên CSDL Cloud / Production.
 */
require('dotenv').config();
const { spawnSync } = require('child_process');

const args = process.argv.slice(2);
const commandStr = args.join(' ').toLowerCase();

const dbUrl = process.env.DATABASE_URL || '';
const directUrl = process.env.DIRECT_URL || '';
const nodeEnv = process.env.NODE_ENV || 'development';

const isCloudDatabase = 
  dbUrl.includes('supabase.co') || 
  dbUrl.includes('supabase.com') ||
  directUrl.includes('supabase.co') ||
  directUrl.includes('supabase.com') ||
  nodeEnv === 'production';

const isDestructivePrismaCmd = 
  commandStr.includes('migrate dev') || 
  commandStr.includes('db push') ||
  (commandStr.includes('migrate') && !commandStr.includes('migrate deploy') && !commandStr.includes('migrate status'));

if (isCloudDatabase && isDestructivePrismaCmd) {
  console.error('\x1b[41m\x1b[37m%s\x1b[0m', ' ============================================================================== ');
  console.error('\x1b[31m%s\x1b[0m', ' 🚨 CẢNH BÁO BẢO MẬT & TOÀN VẸN CSDL (DATABASE GUARD):');
  console.error('\x1b[33m%s\x1b[0m', ` Lệnh "${args.join(' ')}" BỊ CHẶN TUYỆT ĐỐI trên CSDL Cloud Supabase / Production!`);
  console.error('\x1b[37m%s\x1b[0m', ' ------------------------------------------------------------------------------ ');
  console.error('\x1b[36m%s\x1b[0m', ' LÝ DO:');
  console.error(' - Prisma Schema không hỗ trợ native mệnh đề Partial Filter: WHERE ("Delete_at" IS NULL).');
  console.error(' - Chạy `prisma migrate dev` hoặc `prisma db push` sẽ tự động XÓA & TẠO LẠI index thông thường,');
  console.error('   làm PHÁ HỦY toàn bộ điều kiện Soft-Delete và các Triggers bảo vệ dữ liệu nhạy cảm');
  console.error('   (Vi phạm quy định NĐ 13/2023/NĐ-CP & Luật Kế toán 2015).');
  console.error('\x1b[37m%s\x1b[0m', ' ------------------------------------------------------------------------------ ');
  console.error('\x1b[32m%s\x1b[0m', ' QUY TRÌNH CHUẨN THAY THẾ:');
  console.error(' 1. Viết script DDL SQL vào thư mục `database/` hoặc `scripts/`.');
  console.error(' 2. Chạy SQL an toàn qua Supabase SQL Editor Dashboard hoặc script deploy riêng biệt.');
  console.error(' 3. Chạy `npm run prisma:generate` để cập nhật Prisma Client cho Backend.');
  console.error(' 4. Kiểm tra sức khỏe chỉ mục bằng: `npm run db:verify-indexes`.');
  console.error('\x1b[41m\x1b[37m%s\x1b[0m', ' ============================================================================== \n');
  process.exit(1);
}

// Nếu là môi trường Local Dev an toàn hoặc lệnh không phá hủy (generate, studio, migrate deploy)
const path = require('path');
const isWin = process.platform === 'win32';
const prismaBin = path.resolve(__dirname, '..', 'node_modules', '.bin', isWin ? 'prisma.cmd' : 'prisma');

const result = spawnSync(prismaBin, args, {
  stdio: 'inherit',
  shell: true,
  env: process.env
});

process.exit(result.status ?? 0);
