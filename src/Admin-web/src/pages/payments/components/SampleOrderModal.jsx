import React, { useEffect, useState } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Badge, Button, Icon, Modal } from '../../../components/ui';
import { formatCountdown, formatVnd } from '../paymentFormat';

const AMOUNTS = [
  { value: 2000, key: 'amount2k', months: 1 },
  { value: 49000, key: 'amountMonth', months: 1 },
  { value: 270000, key: 'amount6Months', months: 6 },
];

const SampleOrderModal = ({ open, onClose, onCreate, creating, order, onCopy }) => {
  const { t } = useLanguageSafe();
  const [amount, setAmount] = useState(49000);
  const [seconds, setSeconds] = useState(600);

  useEffect(() => {
    setSeconds(600);
    if (!open || !order) return undefined;
    const timer = setInterval(() => setSeconds((s) => (s > 0 ? s - 1 : 0)), 1000);
    return () => clearInterval(timer);
  }, [open, order]);

  const plan = AMOUNTS.find((a) => a.value === (order?.amount || amount)) || AMOUNTS[1];

  return (
    <Modal
      open={open}
      onClose={onClose}
      size="lg"
      title={t('payments.sample.title')}
      description={t('payments.sample.description')}
      footer={<Button onClick={onClose}>{t('common.close')}</Button>}
    >
      <div className="flex flex-col gap-5">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="m-0 mb-2 text-sm font-medium text-ink">{t('payments.sample.amountLabel')}</p>
            <div className="flex flex-wrap gap-2">
              {AMOUNTS.map((a) => (
                <button
                  key={a.value}
                  type="button"
                  aria-pressed={amount === a.value}
                  onClick={() => setAmount(a.value)}
                  className={`h-9 cursor-pointer rounded-lg border px-3 text-sm transition-colors ${
                    amount === a.value ? 'border-brand bg-brand-soft font-semibold text-brand' : 'border-line bg-card text-ink hover:bg-muted'
                  }`}
                >
                  {t(`payments.sample.${a.key}`)}
                </button>
              ))}
            </div>
          </div>
          <Button variant="primary" icon="qr_code_2" loading={creating} onClick={() => onCreate(amount)}>
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
                  [t('payments.detail.packageType'), `Premium · ${plan.months === 6 ? t('payments.package.sixMonths') : t('payments.package.month')}`],
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
  );
};

export default SampleOrderModal;
