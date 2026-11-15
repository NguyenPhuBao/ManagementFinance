import React, { useEffect, useState } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Badge, Button, Icon, Modal, SecurityConfirmModal } from '../../../components/ui';
import { formatCountdown, formatVnd } from '../paymentFormat';

/**
 * Đơn thử nghiệm: một mức tiền cố định do Backend quyết định (2.000 ₫), hạn mức chung toàn hệ thống mỗi ngày,
 * bắt buộc PIN. onCreate(pin) gửi PIN cùng lời gọi tạo đơn.
 */
const SampleOrderModal = ({ open, onClose, onCreate, creating, order, onCopy, quota }) => {
  const { t } = useLanguageSafe();
  const [seconds, setSeconds] = useState(600);
  const [pinOpen, setPinOpen] = useState(false);

  useEffect(() => {
    setSeconds(600);
    if (!open || !order) return undefined;
    const timer = setInterval(() => setSeconds((s) => (s > 0 ? s - 1 : 0)), 1000);
    return () => clearInterval(timer);
  }, [open, order]);

  useEffect(() => {
    if (!open) setPinOpen(false);
  }, [open]);

  const amount = quota?.amount || 2000;
  const left = quota ? Math.max(0, quota.limit - quota.used) : null;
  const exhausted = left === 0;

  return (
    <>
    <Modal
      open={open && !pinOpen}
      onClose={onClose}
      size="lg"
      title={t('payments.sample.title')}
      description={t('payments.sample.description')}
      footer={<Button onClick={onClose}>{t('common.close')}</Button>}
    >
      <div className="flex flex-col gap-5">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div className="flex flex-col gap-1">
            <p className="m-0 text-sm font-medium text-ink">{t('payments.sample.amountLabel')}</p>
            <p className="m-0 text-base font-semibold tabular-nums text-brand">{t('payments.sample.amountFixed', { amount: formatVnd(amount) })}</p>
            {quota && (
              <p className={`m-0 text-xs ${exhausted ? 'text-danger' : 'text-ink-muted'}`}>
                {exhausted
                  ? t('payments.sample.quotaOut', { limit: quota.limit })
                  : t('payments.sample.quotaLeft', { left, limit: quota.limit })}
              </p>
            )}
          </div>
          <Button variant="primary" icon="qr_code_2" loading={creating} disabled={exhausted} onClick={() => setPinOpen(true)}>
            {t('payments.sample.createBtn')}
          </Button>
        </div>

        {!order ? (
          <p className="m-0 rounded-lg border border-dashed border-line p-8 text-center text-sm text-ink-muted">{t('payments.sample.empty')}</p>
        ) : seconds === 0 ? (
          <p className="m-0 rounded-lg bg-danger-soft p-6 text-center text-sm text-danger">{t('payments.sample.expired')}</p>
        ) : (
          <div className="grid gap-5 md:grid-cols-2">
            <div className="flex flex-col items-center gap-3 rounded-lg border border-line p-4">
              <div className="flex w-full items-center justify-between">
                <Badge tone="info">PayOS</Badge>
                <Badge tone="warning">{formatCountdown(seconds)}</Badge>
              </div>
              <img src={order.qrUrl} alt={t('payments.detail.qrTitle')} className="w-56 rounded-lg bg-white p-2" loading="lazy" />
              {order.recognitionCode && (
                <div className="flex w-full items-center justify-between rounded-lg bg-muted px-3 py-2 text-sm">
                  <span className="text-ink-muted">{t('payments.detail.recognitionCode')}</span>
                  <span className="flex items-center gap-1 font-mono font-semibold tracking-wider text-brand">
                    {order.recognitionCode}
                    <Button variant="ghost" size="sm" icon="content_copy" aria-label={t('payments.detail.copy')} onClick={() => onCopy(order.recognitionCode)} />
                  </span>
                </div>
              )}
              {order.checkoutUrl && (
                <a href={order.checkoutUrl} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1.5 text-sm font-medium text-brand hover:underline">
                  <Icon name="open_in_new" size="sm" />
                  {t('payments.detail.openCheckout')}
                </a>
              )}
            </div>
            <div className="flex flex-col gap-3">
              <dl className="m-0 flex flex-col divide-y divide-line rounded-lg border border-line px-3 text-sm">
                {[
                  [t('payments.detail.orderCode'), `#${order.orderCode}`],
                  [t('payments.detail.bank'), order.bankName || '—'],
                  [t('payments.detail.accountNo'), order.accountNumber || '—'],
                  [t('payments.detail.accountName'), order.accountName || '—'],
                  [t('payments.detail.amount'), formatVnd(order.amount || amount)],
                  [t('payments.detail.transferContent'), order.description || '—'],
                  [t('payments.detail.status'), <Badge key="s" tone="warning">{t('payments.status.PENDING')}</Badge>],
                ].map(([label, value]) => (
                  <div key={label} className="flex items-center justify-between gap-3 py-2">
                    <dt className="text-ink-muted">{label}</dt>
                    <dd className="m-0 break-all text-right font-medium text-ink">{value}</dd>
                  </div>
                ))}
              </dl>
              <p className="m-0 text-xs text-ink-faint">{t('payments.sample.scanNotice')}</p>
            </div>
          </div>
        )}
      </div>
    </Modal>

    <SecurityConfirmModal
      isOpen={open && pinOpen}
      onClose={() => setPinOpen(false)}
      title={t('payments.sample.pinTitle')}
      description={t('payments.sample.pinDescription', { amount: formatVnd(amount) })}
      confirmText={t('payments.sample.pinConfirm')}
      actionType="CREATE_SAMPLE_ORDER"
      onVerify={({ pin }) => onCreate(pin)}
    />
    </>
  );
};

export default SampleOrderModal;
