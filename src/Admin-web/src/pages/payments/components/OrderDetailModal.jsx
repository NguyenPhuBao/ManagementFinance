import React, { useEffect, useState } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Badge, Button, Icon, Modal, Spinner } from '../../../components/ui';
import { STATUS_TONE, assetUrl, effectiveStatus, formatCountdown, formatDate, formatVnd, packageLabel } from '../paymentFormat';

const Field = ({ label, children, wide }) => (
  <div className={wide ? 'col-span-2' : ''}>
    <dt className="text-xs text-ink-faint">{label}</dt>
    <dd className="m-0 mt-0.5 break-words text-sm font-medium text-ink">{children}</dd>
  </div>
);

const Section = ({ title, children }) => (
  <section className="flex flex-col gap-2">
    <h3 className="m-0 text-xs font-semibold uppercase tracking-wide text-ink-faint">{title}</h3>
    <dl className="m-0 grid grid-cols-2 gap-3 rounded-lg border border-line p-3">{children}</dl>
  </section>
);

const Notice = ({ tone, icon, children }) => (
  <div className={`flex items-center gap-3 rounded-lg p-3 text-sm ${tone}`}>
    <Icon name={icon} />
    <span>{children}</span>
  </div>
);

const remainingSeconds = (order) => {
  if (order.status !== 'PENDING') return null;
  const target = order.expired_at
    ? new Date(order.expired_at).getTime()
    : order.created_at
      ? new Date(order.created_at).getTime() + 10 * 60 * 1000
      : null;
  return target ? Math.max(0, Math.floor((target - Date.now()) / 1000)) : null;
};

const CopyButton = ({ value, label, onCopy }) =>
  value ? <Button variant="ghost" size="sm" icon="content_copy" aria-label={label} title={label} onClick={() => onCopy(value)} /> : null;

const OrderDetailModal = ({ open, loading, order, onClose, onExpired, onConfirmUpgrade, onRefund, actionLoading, onCopy }) => {
  const { t } = useLanguageSafe();
  const [countdown, setCountdown] = useState(null);

  useEffect(() => {
    if (!order) {
      setCountdown(null);
      return undefined;
    }
    const tick = () => {
      const left = remainingSeconds(order);
      setCountdown(left);
      if (left === 0) onExpired();
    };
    tick();
    const timer = setInterval(tick, 1000);
    return () => clearInterval(timer);
  }, [order]);

  const status = order ? effectiveStatus(order) : null;
  const pendingActive = order && order.status === 'PENDING' && countdown !== 0 && Boolean(order.qr_url) && status !== 'EXPIRED';
  const transfer = order?.transfer_content || order?.recognition_code;
  const showRefund = order && (order.status === 'REFUND_PENDING' || order.status === 'REFUNDED' || order.refunded_at);

  return (
    <Modal
      open={open}
      onClose={onClose}
      size="lg"
      title={t('payments.detail.title')}
      footer={
        <>
          {order?.status === 'REFUND_PENDING' && (
            <Button variant="primary" icon="currency_exchange" onClick={() => onRefund(order)}>
              {t('payments.table.refundBtn')}
            </Button>
          )}
          <Button onClick={onClose}>{t('common.close')}</Button>
        </>
      }
    >
      {loading || !order ? (
        <div className="flex justify-center py-10 text-brand">
          <Spinner size="lg" />
        </div>
      ) : (
        <div className="flex flex-col gap-5">
          {pendingActive && (
            <section className="flex flex-col gap-3 rounded-lg border border-line p-3">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h3 className="m-0 text-sm font-semibold text-ink">{t('payments.detail.qrTitle')}</h3>
                <Badge tone="warning">{t('payments.detail.timeLeft', { time: formatCountdown(countdown ?? 0) })}</Badge>
              </div>
              <div className="grid items-center gap-4 sm:grid-cols-3">
                <img src={order.qr_url} alt={t('payments.detail.qrTitle')} className="mx-auto w-40 rounded-lg bg-white p-2" loading="lazy" />
                <dl className="m-0 flex flex-col gap-2 text-sm sm:col-span-2">
                  <div className="flex justify-between gap-2">
                    <dt className="text-ink-muted">{t('payments.detail.bank')}</dt>
                    <dd className="m-0 font-medium text-ink">{order.bank_info?.bankName || '—'}</dd>
                  </div>
                  <div className="flex items-center justify-between gap-2">
                    <dt className="text-ink-muted">{t('payments.detail.accountNo')}</dt>
                    <dd className="m-0 flex items-center gap-1 font-mono font-medium text-ink">
                      {order.bank_info?.accountNumber || '—'}
                      <CopyButton value={order.bank_info?.accountNumber} label={t('payments.detail.copy')} onCopy={onCopy} />
                    </dd>
                  </div>
                  <div className="flex justify-between gap-2">
                    <dt className="text-ink-muted">{t('payments.detail.accountName')}</dt>
                    <dd className="m-0 font-medium text-ink">{order.bank_info?.accountName || '—'}</dd>
                  </div>
                  <div className="flex items-center justify-between gap-2">
                    <dt className="text-ink-muted">{t('payments.detail.transferContent')}</dt>
                    <dd className="m-0 flex items-center gap-1 break-all font-mono font-medium text-brand">
                      {transfer || '—'}
                      <CopyButton value={transfer} label={t('payments.detail.copy')} onCopy={onCopy} />
                    </dd>
                  </div>
                  {order.checkout_url && (
                    <a href={order.checkout_url} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1.5 text-sm font-medium text-brand hover:underline">
                      <Icon name="open_in_new" size="sm" />
                      {t('payments.detail.openCheckout')}
                    </a>
                  )}
                </dl>
              </div>
            </section>
          )}
          {status === 'PAID' && (
            <Notice tone="bg-success-soft text-success" icon="verified">
              {t('payments.detail.paidNotice')}
            </Notice>
          )}
          {(status === 'EXPIRED' || (order.status === 'PENDING' && countdown === 0)) && (
            <Notice tone="bg-danger-soft text-danger" icon="timer_off">
              {t('payments.detail.expiredNotice')}
            </Notice>
          )}
          {status === 'REFUNDED' && (
            <Notice tone="bg-quiet-soft text-quiet" icon="history">
              {t('payments.detail.refundedNotice')}
            </Notice>
          )}
          {status === 'CANCELLED' && (
            <Notice tone="bg-quiet-soft text-quiet" icon="cancel">
              {t('payments.detail.cancelledNotice')}
            </Notice>
          )}

          {order.status === 'WAITING_CONFIRMATION' && (
            <section className="flex flex-col gap-3 rounded-lg bg-info-soft p-3">
              <p className="m-0 text-sm text-info">
                {t('payments.detail.overpaid', { received: formatVnd(order.amount_received), amount: formatVnd(order.amount) })}
              </p>
              <div className="flex flex-wrap gap-2">
                <Button variant="primary" loading={actionLoading} onClick={() => onConfirmUpgrade(order.order_code, true)}>
                  {t('payments.detail.acceptBtn')}
                </Button>
                <Button disabled={actionLoading} onClick={() => onConfirmUpgrade(order.order_code, false)}>
                  {t('payments.detail.rejectBtn')}
                </Button>
              </div>
            </section>
          )}

          <Section title={t('payments.detail.orderInfo')}>
            <Field label={t('payments.detail.orderCode')}>#{order.order_code}</Field>
            <Field label={t('payments.detail.status')}>
              <Badge tone={STATUS_TONE[status] || 'neutral'}>{t(`payments.status.${status}`, status)}</Badge>
            </Field>
            <Field label={t('payments.detail.amount')}>{formatVnd(order.amount)}</Field>
            <Field label={t('payments.detail.amountReceived')}>{formatVnd(order.amount_received || order.amount)}</Field>
            <Field label={t('payments.detail.recognitionCode')}>{order.recognition_code || '—'}</Field>
            <Field label={t('payments.detail.packageType')}>{packageLabel(order.package_type, t)}</Field>
            <Field label={t('payments.detail.createdAt')}>{formatDate(order.created_at)}</Field>
            <Field label={t('payments.detail.paidAt')}>{formatDate(order.paid_at)}</Field>
            {order.transfer_content && (
              <Field wide label={t('payments.detail.transferContent')}>
                <span className="font-mono">{order.transfer_content}</span>
              </Field>
            )}
            {order.payment_link_id && (
              <Field wide label={t('payments.detail.payosLinkId')}>
                <span className="font-mono text-ink-muted">{order.payment_link_id}</span>
              </Field>
            )}
          </Section>

          {showRefund && (
            <Section title={t('payments.detail.refundInfo')}>
              <Field label={t('payments.detail.refundedAmount')}>{formatVnd(order.refunded_amount || order.amount_received)}</Field>
              <Field label={t('payments.detail.refundedAt')}>{formatDate(order.refunded_at)}</Field>
              <Field wide label={t('payments.detail.refundReason')}>{order.refund_reason || '—'}</Field>
              {order.refund_proof && (
                <Field wide label={t('payments.detail.refundProof')}>
                  <div className="flex items-center gap-3">
                    {/\.(jpg|jpeg|png|webp|gif)$/i.test(order.refund_proof) && (
                      <img src={assetUrl(order.refund_proof)} alt="" className="h-16 w-24 rounded-lg border border-line object-cover" />
                    )}
                    <a href={assetUrl(order.refund_proof)} target="_blank" rel="noopener noreferrer" className="break-all font-mono text-xs text-brand hover:underline">
                      {order.refund_proof}
                    </a>
                  </div>
                </Field>
              )}
            </Section>
          )}

          <Section title={t('payments.detail.customerInfo')}>
            <Field label={t('payments.detail.username')}>{order.account?.username || '—'}</Field>
            <Field label={t('payments.detail.fullname')}>{order.account?.User?.fullname || '—'}</Field>
            <Field label={t('payments.detail.email')}>{order.account?.email || '—'}</Field>
            <Field label={t('payments.detail.accountType')}>{order.account?.type || '—'}</Field>
          </Section>

          <section className="flex flex-col gap-2">
            <h3 className="m-0 text-xs font-semibold uppercase tracking-wide text-ink-faint">{t('payments.detail.transactions')}</h3>
            {!order.payment_transaction?.length ? (
              <p className="m-0 rounded-lg border border-line p-3 text-center text-sm text-ink-muted">{t('payments.detail.noTransactions')}</p>
            ) : (
              order.payment_transaction.map((tx) => (
                <div key={tx.id} className="flex flex-col gap-1.5 rounded-lg border border-line p-3 text-sm">
                  <div className="flex items-center justify-between">
                    <span className="font-medium text-ink">{tx.bank_code || 'VietQR'}</span>
                    <span className="font-semibold tabular-nums text-success">{formatVnd(tx.amount)}</span>
                  </div>
                  <div className="grid gap-1 text-ink-muted sm:grid-cols-2">
                    <span>
                      {t('payments.detail.txId')}: <span className="font-mono text-ink">{tx.payos_transaction_id || '—'}</span>
                    </span>
                    <span>
                      {t('payments.detail.txTime')}: {formatDate(tx.transaction_time)}
                    </span>
                    <span className="flex items-center gap-1.5 sm:col-span-2">
                      {t('payments.detail.signature')}:
                      <Badge tone={tx.signature_verified ? 'success' : 'danger'}>
                        {tx.signature_verified ? t('payments.detail.sigVerified') : t('payments.detail.sigUnverified')}
                      </Badge>
                    </span>
                  </div>
                </div>
              ))
            )}
          </section>
        </div>
      )}
    </Modal>
  );
};

export default OrderDetailModal;
