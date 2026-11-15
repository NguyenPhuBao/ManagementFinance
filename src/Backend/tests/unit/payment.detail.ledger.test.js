/**
 * Chi tiết đơn cho admin: sổ giao dịch hiện đủ để đối chiếu (mã GD ngân hàng, chiều tiền, nguồn, tài khoản nhận,
 * ngân hàng người chuyển) nhưng KHÔNG lộ dữ liệu cá nhân / chứng cứ thô:
 *  - không trả payload gốc (raw_payload) hay bản mã của tên / số tài khoản người chuyển;
 *  - số tài khoản người chuyển chỉ còn 4 số cuối.
 */
const { describe, it } = require('node:test');
const assert = require('node:assert');
const paymentService = require('../../modules/payment/payment.service');
const paymentRepository = require('../../modules/payment/payment.repository');
const { encrypt } = require('../../utils/crypto.util');

describe('getOrderDetailForAdmin: sổ giao dịch an toàn để hiển thị', () => {
  it('bỏ payload gốc và bản mã; số tài khoản người chuyển che còn 4 số cuối', async () => {
    const orig = paymentRepository.getOrderDetailForAdmin;
    paymentRepository.getOrderDetailForAdmin = async () => ({
      id: 'o1',
      status: 'PAID',
      payment_transaction: [{
        id: 't1',
        payos_transaction_id: 'FT26313015169909',
        direction: 'IN',
        source: 'WEBHOOK',
        amount: 49000,
        receiving_account_number: '0123456789',
        counter_account_bank_name: 'MB Bank',
        counter_account_name: encrypt('NGUYEN VAN A'),
        counter_account_number: encrypt('9876543210'),
        raw_payload: encrypt('{"signature":"x"}'),
        raw_webhook_hash: 'abc',
      }],
    });
    try {
      const order = await paymentService.getOrderDetailForAdmin('o1');
      const tx = order.payment_transaction[0];
      assert.strictEqual(tx.payos_transaction_id, 'FT26313015169909');
      assert.strictEqual(tx.direction, 'IN');
      assert.strictEqual(tx.receiving_account_number, '0123456789');
      assert.strictEqual(tx.counter_account_bank_name, 'MB Bank');
      assert.strictEqual(tx.counter_account_number, '••••3210');
      assert.strictEqual(tx.raw_payload, undefined);
      assert.strictEqual(tx.counter_account_name, undefined);
      assert.doesNotMatch(JSON.stringify(order), /enc:|9876543210|NGUYEN VAN A/);
    } finally {
      paymentRepository.getOrderDetailForAdmin = orig;
    }
  });
});
