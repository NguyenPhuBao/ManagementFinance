/**
 * Tạo 2 bucket riêng tư cho Supabase Storage (lũy đẳng: bucket đã có thì bỏ qua).
 *   refund-proofs : minh chứng hoàn tiền (ảnh JPG / PNG / WEBP hoặc PDF, tối đa 5 MB)
 *   data-exports  : bản sao dữ liệu cá nhân (JSON / CSV, tối đa 20 MB, tự xóa sau 24 giờ)
 * Đọc SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY từ biến môi trường. Bắt buộc --xac-nhan-tu-xa (chỉ khi Chủ dự án đã xác nhận).
 *   node scripts/setup_storage_buckets.js --xac-nhan-tu-xa
 */
require('dotenv').config();
const { createStorage, resolveDriverName, BUCKETS } = require('../core/storage');

if (resolveDriverName(process.env) !== 'supabase') {
  console.error('Thiếu SUPABASE_URL hoặc SUPABASE_SERVICE_ROLE_KEY: không có gì để tạo.');
  process.exit(1);
}
if (!process.argv.includes('--xac-nhan-tu-xa')) {
  console.error(`Sẽ tạo bucket trên ${new URL(process.env.SUPABASE_URL).hostname}. Cần --xac-nhan-tu-xa (chỉ khi Chủ dự án đã xác nhận).`);
  process.exit(1);
}

(async () => {
  const storage = createStorage();
  const plan = [
    [BUCKETS.REFUND_PROOFS, { fileSizeLimit: 5 * 1024 * 1024, allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'] }],
    [BUCKETS.DATA_EXPORTS, { fileSizeLimit: 20 * 1024 * 1024, allowedMimeTypes: ['application/json', 'text/csv'] }],
  ];
  for (const [bucket, opts] of plan) {
    const result = await storage.ensureBucket(bucket, opts);
    console.log(`${bucket}: ${result === 'created' ? 'đã tạo' : 'đã có sẵn'}`);
  }
})().catch((err) => {
  console.error('Lỗi:', err?.response?.data || err.message);
  process.exit(1);
});
