import React, { useEffect, useId, useState } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Button, Modal, SecurityConfirmModal } from '../../../components/ui';
import { useNumberFormat } from '../../../utils/format';

const inputClass =
  'w-full rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

// Giờ máy của admin, định dạng cho ô datetime-local (giới hạn "không ở tương lai")
const localNow = () => {
  const d = new Date();
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
  return d.toISOString().slice(0, 16);
};

/**
 * Ghi nhận hoàn tiền THỦ CÔNG: admin tự chuyển khoản trả khách rồi tự nhập số tiền, mã giao dịch, ngày giờ hoàn,
 * nội dung và minh chứng. PIN gửi cùng lời gọi hoàn tiền (Backend xác thực). Hoàn xong đơn bị khoá, không hoàn lần 2.
 */
const RefundModal = ({ order, onClose, onSubmit }) => {
  const { t } = useLanguageSafe();
  const { currency: money } = useNumberFormat();
  const id = useId();
  const [form, setForm] = useState({ amount: '', reason: '', proofUrl: '', bankReference: '', refundedAt: '' });
  const [proofFile, setProofFile] = useState(null);
  const [preview, setPreview] = useState(null);
  const [pinOpen, setPinOpen] = useState(false);

  useEffect(() => {
    if (!order) return;
    setForm({
      amount: order.amount_received || order.amount || '',
      reason: order.refund_reason || t('payments.refund.defaultReason'),
      proofUrl: order.refund_proof || '',
      bankReference: '',
      refundedAt: '',
    });
    setProofFile(null);
    setPreview(null);
    setPinOpen(false);
  }, [order]);

  const amountValid = Number(form.amount) > 0;
  const formValid = amountValid && form.reason.trim() && form.bankReference.trim() && form.refundedAt && (proofFile || form.proofUrl.trim());

  const execute = async ({ pin }) => {
    const data = new FormData();
    data.append('refunded_amount', Number(form.amount));
    data.append('refund_reason', form.reason);
    data.append('bank_reference', form.bankReference.trim());
    data.append('refunded_at', new Date(form.refundedAt).toISOString());
    data.append('pin', pin);
    if (proofFile) data.append('proofFile', proofFile);
    else if (form.proofUrl) data.append('refund_proof', form.proofUrl);
    await onSubmit(order, data);
  };

  return (
    <>
      <Modal
        open={Boolean(order) && !pinOpen}
        onClose={onClose}
        size="md"
        title={t('payments.refund.title')}
        description={order ? `#${order.order_code} · ${order.account?.username || '—'}` : undefined}
        footer={
          <>
            <Button onClick={onClose}>{t('common.cancel')}</Button>
            <Button type="submit" form={`${id}-form`} variant="primary" disabled={!formValid}>
              {t('payments.refund.continueBtn')}
            </Button>
          </>
        }
      >
        {order && (
          <form
            id={`${id}-form`}
            className="flex flex-col gap-4"
            onSubmit={(e) => {
              e.preventDefault();
              if (formValid) setPinOpen(true);
            }}
          >
            <p className="m-0 rounded-lg bg-warning-soft px-3 py-2 text-xs text-warning">{t('payments.refund.manualNotice')}</p>
            <dl className="m-0 grid grid-cols-2 gap-3 rounded-lg bg-muted p-3 text-sm">
              <div>
                <dt className="text-xs text-ink-faint">{t('payments.refund.expectedAmount')}</dt>
                <dd className="m-0 font-medium tabular-nums text-ink">{money(order.amount)}</dd>
              </div>
              <div>
                <dt className="text-xs text-ink-faint">{t('payments.refund.receivedAmount')}</dt>
                <dd className="m-0 font-semibold tabular-nums text-warning">{money(order.amount_received || order.amount)}</dd>
              </div>
            </dl>
            <div className="flex flex-col gap-1.5">
              <label htmlFor={`${id}-amount`} className="text-sm font-medium text-ink">
                {t('payments.refund.amountLabel')}
              </label>
              <input
                id={`${id}-amount`}
                type="number"
                min="1"
                required
                value={form.amount}
                onChange={(e) => setForm({ ...form, amount: e.target.value })}
                className={`${inputClass} h-10 tabular-nums`}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <label htmlFor={`${id}-ref`} className="text-sm font-medium text-ink">
                {t('payments.refund.bankRefLabel')}
              </label>
              <input
                id={`${id}-ref`}
                type="text"
                required
                maxLength={100}
                autoComplete="off"
                value={form.bankReference}
                onChange={(e) => setForm({ ...form, bankReference: e.target.value })}
                className={`${inputClass} h-10 font-mono`}
                aria-describedby={`${id}-ref-hint`}
              />
              <p id={`${id}-ref-hint`} className="m-0 text-xs text-ink-faint">{t('payments.refund.bankRefHint')}</p>
            </div>
            <div className="flex flex-col gap-1.5">
              <label htmlFor={`${id}-at`} className="text-sm font-medium text-ink">
                {t('payments.refund.refundedAtLabel')}
              </label>
              <input
                id={`${id}-at`}
                type="datetime-local"
                required
                max={localNow()}
                value={form.refundedAt}
                onChange={(e) => setForm({ ...form, refundedAt: e.target.value })}
                className={`${inputClass} h-10 tabular-nums`}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <label htmlFor={`${id}-reason`} className="text-sm font-medium text-ink">
                {t('payments.refund.reasonLabel')}
              </label>
              <textarea
                id={`${id}-reason`}
                rows={2}
                required
                value={form.reason}
                onChange={(e) => setForm({ ...form, reason: e.target.value })}
                className={`${inputClass} resize-none py-2`}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <label htmlFor={`${id}-file`} className="text-sm font-medium text-ink">
                {t('payments.refund.proofFileLabel')}
              </label>
              <input
                id={`${id}-file`}
                type="file"
                accept="image/*,.pdf"
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (!file) return;
                  setProofFile(file);
                  setPreview(URL.createObjectURL(file));
                }}
                className="text-sm text-ink-muted file:mr-3 file:cursor-pointer file:rounded-lg file:border-0 file:bg-brand-soft file:px-3 file:py-1.5 file:text-sm file:font-medium file:text-brand"
              />
              {preview && <img src={preview} alt="" className="h-20 w-32 rounded-lg border border-line object-cover" />}
            </div>
            {!proofFile && (
              <div className="flex flex-col gap-1.5">
                <label htmlFor={`${id}-url`} className="text-sm font-medium text-ink">
                  {t('payments.refund.proofUrlLabel')}
                </label>
                <input
                  id={`${id}-url`}
                  type="url"
                  placeholder="https://"
                  value={form.proofUrl}
                  onChange={(e) => setForm({ ...form, proofUrl: e.target.value })}
                  className={`${inputClass} h-10`}
                />
              </div>
            )}
          </form>
        )}
      </Modal>

      <SecurityConfirmModal
        isOpen={pinOpen}
        onClose={() => setPinOpen(false)}
        title={t('payments.refund.pinTitle')}
        description={order ? t('payments.refund.pinDescription', { amount: money(form.amount), code: order.order_code }) : undefined}
        confirmText={t('payments.refund.confirmBtn')}
        actionType="REFUND_ORDER"
        targetLabel={order ? `#${order.order_code}` : ''}
        dangerLevel="critical"
        onVerify={execute}
      />
    </>
  );
};

export default RefundModal;
