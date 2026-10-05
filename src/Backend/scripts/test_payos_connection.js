const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const payosClient = require('../modules/payment/payos.client');

async function testPayOSConnection() {
  console.log('====================================================');
  console.log('   KIỂM TRA KẾT NỐI CỔNG THANH TOÁN PAYOS THẬT     ');
  console.log('====================================================\n');

  const clientId = process.env.PAYOS_CLIENT_ID;
  const apiKey = process.env.PAYOS_API_KEY;
  const checksumKey = process.env.PAYOS_CHECKSUM_KEY;

  if (!clientId || !apiKey || !checksumKey || clientId.includes('your_payos_')) {
    console.error('❌ CHƯA CẤU HÌNH THÔNG TIN PAYOS TRONG TỆP .env!');
    console.error('Vui lòng mở file src/Backend/.env và điền 3 thông số:');
    console.error('  1. PAYOS_CLIENT_ID=...');
    console.error('  2. PAYOS_API_KEY=...');
    console.error('  3. PAYOS_CHECKSUM_KEY=...\n');
    console.error('👉 Xem hướng dẫn chi tiết tại: docs/Payment/PAYOS_SETUP_GUIDE.md');
    process.exit(1);
  }

  console.log('✔ Đã tìm thấy cấu hình PayOS:');
  console.log(`  - Client ID: ${clientId.slice(0, 8)}...${clientId.slice(-4)}`);
  console.log(`  - API Key:   ${apiKey.slice(0, 8)}...${apiKey.slice(-4)}`);
  console.log(`  - Checksum:  ${checksumKey.slice(0, 8)}...${checksumKey.slice(-4)}\n`);

  try {
    const testOrderCode = Number(Date.now().toString().slice(-9));
    console.log(`⏳ Đang gửi yêu cầu tạo liên kết thanh toán mẫu tới PayOS (orderCode: ${testOrderCode})...`);

    const result = await payosClient.createPaymentLink({
      orderCode: testOrderCode,
      amount: 2000,
      description: `Test ket noi PayOS ${testOrderCode}`,
      returnUrl: process.env.PAYOS_RETURN_URL || 'https://managementfinance-admin.vercel.app/payment/success',
      cancelUrl: process.env.PAYOS_CANCEL_URL || 'https://managementfinance-admin.vercel.app/payment/cancel',
    });

    console.log('\n🎉 KẾT NỐI TỚI PAYOS THÀNH CÔNG 100%!');
    console.log('----------------------------------------------------');
    console.log(`- Mã đơn hàng (orderCode): ${result.orderCode}`);
    console.log(`- Payment Link ID:         ${result.paymentLinkId}`);
    console.log(`- Link thanh toán VietQR:  ${result.checkoutUrl}`);
    console.log('----------------------------------------------------');
    console.log('👉 Bạn có thể mở link trên trong trình duyệt để xem trang thanh toán VietQR thật của PayOS!');
  } catch (error) {
    console.error('\n❌ KẾT NỐI TỚI PAYOS THẤT BẠI!');
    console.error(`Chi tiết lỗi: ${error.message}`);
    console.error('Vui lòng kiểm tra lại Client ID, API Key hoặc Checksum Key trên https://my.payos.vn.');
    process.exit(1);
  }
}

testPayOSConnection();
