const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const payosClient = require('../modules/payment/payos.client');

async function main() {
  console.log('====================================================');
  console.log('   ĐĂNG KÝ & XÁC NHẬN WEBHOOK VỚI CỔNG PAYOS       ');
  console.log('====================================================\n');

  const webhookUrl = process.argv[2];
  if (!webhookUrl) {
    console.error('❌ Vui lòng truyền đường dẫn Webhook URL!');
    console.error('Ví dụ sử dụng:');
    console.error('  rtk node scripts/confirm_payos_webhook.js https://xxxx.ngrok-free.app/api/payment/webhook');
    console.error('  rtk node scripts/confirm_payos_webhook.js https://managementfinance.onrender.com/api/payment/webhook\n');
    process.exit(1);
  }

  if (!webhookUrl.includes('/api/payment/webhook')) {
    console.warn('⚠️ Cảnh báo: Webhook URL nên kết thúc bằng /api/payment/webhook');
  }

  console.log(`⏳ Đang gửi yêu cầu đăng ký Webhook URL tới PayOS:`);
  console.log(`   🔗 ${webhookUrl}\n`);
  console.log('Lưu ý: Backend của bạn PHẢI ĐANG CHẠY để phản hồi test ping từ PayOS!');

  try {
    const result = await payosClient.confirmWebhook(webhookUrl);
    console.log('\n🎉 ĐĂNG KÝ VÀ XÁC NHẬN WEBHOOK THÀNH CÔNG 100%!');
    console.log('----------------------------------------------------');
    console.log('Kết quả từ PayOS:', result);
    console.log('----------------------------------------------------');
    console.log('👉 Bây giờ khi khách hàng thanh toán qua VietQR, PayOS sẽ tự động bắn webhook về Backend của bạn!');
  } catch (error) {
    console.error('\n❌ XÁC NHẬN WEBHOOK THẤT BẠI!');
    console.error(`Chi tiết lỗi: ${error.message}`);
    console.error('\nNguyên nhân có thể do:');
    console.error('1. Backend chưa được khởi động (chưa chạy npm run dev hoặc Render đang ngủ).');
    console.error('2. PayOS từ Internet không thể kết nối tới URL (nếu dùng localhost, bạn phải dùng ngrok).');
    console.error('3. Checksum Key trong .env không khớp với kênh thanh toán.');
    process.exit(1);
  }
}

main();
