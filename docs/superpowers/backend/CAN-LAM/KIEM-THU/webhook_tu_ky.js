// Gửi webhook PayOS tự ký vào backend dev, ký bằng đúng hàm của SDK. KHÔNG có giao dịch ngân hàng nào.
// Khoá lấy từ .env, không in ra. Chỉ dùng cho CSDL dev, đơn của tài khoản thử.
// Cách chạy (từ src/Backend):
//   node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/webhook_tu_ky.js <orderCode> <soTien> [sai] [cong]
// `sai` làm hỏng chữ ký (phải ra 400). Mỗi lần gửi một `reference` mới.
const path = require('path');
const cwd = process.cwd();
require(require.resolve('dotenv', { paths: [cwd] })).config({ path: path.join(cwd, '.env') });
const { NodeCryptoProvider } = require(path.join(cwd, 'node_modules/@payos/node/lib/crypto/node-crypto.js'));

(async () => {
  const [orderCode, soTien, kieu, cong = '3000'] = process.argv.slice(2);
  if (!orderCode || !soTien) throw new Error('Thiếu orderCode hoặc soTien');
  const data = {
    orderCode: Number(orderCode),
    amount: Number(soTien),
    description: 'CSTEST WEBHOOK',
    accountNumber: '0000000000',
    reference: `WHTEST-${Date.now()}`,
    // PayOS gửi giờ Việt Nam không kèm múi giờ.
    transactionDateTime: new Date(Date.now() + 7 * 3600 * 1000).toISOString().slice(0, 19).replace('T', ' '),
    currency: 'VND',
    paymentLinkId: 'tu-ky',
    code: '00',
    desc: 'success',
    counterAccountBankId: '',
    counterAccountBankName: '',
    counterAccountName: '',
    counterAccountNumber: '',
    virtualAccountName: '',
    virtualAccountNumber: '',
  };
  let signature = await new NodeCryptoProvider().createSignatureFromObj(data, process.env.PAYOS_CHECKSUM_KEY);
  if (kieu === 'sai') signature = signature.replace(/^./, (c) => (c === '0' ? '1' : '0'));
  const r = await fetch(`http://127.0.0.1:${cong}/api/payment/webhook`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ code: '00', desc: 'success', success: true, data, signature }),
  });
  console.log(r.status, (await r.text()).slice(0, 300));
})().catch((e) => {
  console.error('LOI', e.message);
  process.exit(1);
});
