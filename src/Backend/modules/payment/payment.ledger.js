/**
 * Sổ giao dịch thanh toán (payment_transaction, migration 53) — dựng dòng sổ và nhật ký webhook.
 * Nguyên tắc:
 *  - Mỗi dòng sổ mang MÃ GIAO DỊCH NGÂN HÀNG thật (PayOS `reference` / mã chuyển khoản hoàn tiền).
 *    Không có mã thì KHÔNG ghi sổ; tuyệt đối không thay bằng mã đơn hay mã tự sinh.
 *  - Lưu đủ chứng cứ đối chiếu PayOS / ngân hàng: tài khoản nhận, người chuyển (mã hoá), payload gốc (mã hoá).
 *  - Sổ bất biến: CSDL chặn UPDATE / DELETE (trigger), mã chỉ tạo dòng mới.
 */
const crypto = require('crypto');
const { prisma } = require('../../config/db');
const logger = require('../../core/logger');
const { encrypt } = require('../../utils/crypto.util');
const payosClient = require('./payos.client');

const str = (v, max) => (v === undefined || v === null || v === '' ? null : String(v).slice(0, max));

/**
 * Dòng sổ tiền vào từ một giao dịch PayOS (webhook `data` hoặc phần tử `transactions[]` của API).
 * @returns {object|null} null khi giao dịch không có mã ngân hàng
 */
function ledgerFromPayos({ order, tx, amount, txTime, source, rawPayload, rawWebhookHash }) {
  const reference = str(tx && tx.reference, 100);
  if (!reference) return null;
  return {
    id: crypto.randomUUID(),
    orderId: order.id,
    idaccount: order.idaccount,
    payosTransactionId: reference,
    amount,
    bankCode: str(tx.counterAccountBankId, 50),
    transactionTime: txTime,
    signatureVerified: source === 'WEBHOOK',
    rawWebhookHash: rawWebhookHash || null,
    direction: 'IN',
    source,
    receivingAccountNumber: str(tx.accountNumber, 50),
    paymentLinkId: str(tx.paymentLinkId || order.payment_link_id, 64),
    transferDescription: str(tx.description, 255),
    currency: str(tx.currency || 'VND', 10),
    counterAccountBankId: str(tx.counterAccountBankId, 20),
    counterAccountBankName: str(tx.counterAccountBankName, 255),
    counterAccountName: tx.counterAccountName ? encrypt(String(tx.counterAccountName)) : null,
    counterAccountNumber: tx.counterAccountNumber ? encrypt(String(tx.counterAccountNumber)) : null,
    rawPayload: rawPayload ? encrypt(JSON.stringify(rawPayload)) : null,
  };
}

/** Ánh xạ dòng sổ (camelCase) sang cột CSDL. */
function ledgerRow(d) {
  return {
    id: d.id,
    order_id: d.orderId,
    idaccount: d.idaccount,
    payos_transaction_id: d.payosTransactionId,
    amount: d.amount,
    bank_code: d.bankCode || null,
    transaction_time: d.transactionTime || new Date(),
    signature_verified: d.signatureVerified ?? false,
    raw_webhook_hash: d.rawWebhookHash || null,
    direction: d.direction || 'IN',
    source: d.source || null,
    receiving_account_number: d.receivingAccountNumber || null,
    payment_link_id: d.paymentLinkId || null,
    transfer_description: d.transferDescription || null,
    currency: d.currency || null,
    counter_account_bank_id: d.counterAccountBankId || null,
    counter_account_bank_name: d.counterAccountBankName || null,
    counter_account_name: d.counterAccountName || null,
    counter_account_number: d.counterAccountNumber || null,
    raw_payload: d.rawPayload || null,
    created_by: d.createdBy ?? null,
    proof: d.proof || null,
  };
}

/**
 * Webhook thiếu `reference`: hỏi lại PayOS danh sách giao dịch của đơn, lấy giao dịch khớp số tiền.
 * @returns {object|null} giao dịch PayOS có `reference`, hoặc null
 */
async function findPayosTransaction(orderCode, amount) {
  try {
    const info = await payosClient.getPaymentLinkInfo(orderCode);
    const list = Array.isArray(info && info.transactions) ? info.transactions : [];
    const withRef = list.filter((t) => t && t.reference);
    return withRef.find((t) => Number(t.amount) === Number(amount)) || withRef[withRef.length - 1] || null;
  } catch (err) {
    logger.warn('[PAYMENT_LEDGER] Không tra được giao dịch trên PayOS', { orderCode, error: err.message });
    return null;
  }
}

/** Ghi nhật ký webhook có chữ ký hợp lệ (append-only, payload mã hoá). Không làm hỏng luồng nếu lỗi. */
async function logWebhook({ payload, data, handledAs }) {
  try {
    await prisma.payment_webhook_log.create({
      data: {
        order_code: data && data.orderCode ? BigInt(data.orderCode) : null,
        reference: str(data && data.reference, 100),
        amount: data && data.amount !== undefined ? Number(data.amount) : null,
        signature_valid: true,
        handled_as: str(handledAs, 40),
        payload: encrypt(JSON.stringify(payload)),
      },
    });
  } catch (err) {
    logger.error('[PAYMENT_LEDGER] Không ghi được nhật ký webhook', { error: err.message });
  }
}

module.exports = { ledgerFromPayos, ledgerRow, findPayosTransaction, logWebhook };
