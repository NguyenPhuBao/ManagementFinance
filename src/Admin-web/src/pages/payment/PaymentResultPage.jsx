import React from 'react';
import { useSearchParams } from 'react-router-dom';
import AuthShell from '../auth/AuthShell';
import Icon from '../../components/ui/Icon';
import { useLanguageSafe } from '../../store/language.context';

const VIEWS = {
  paid: { icon: 'check_circle', tone: 'text-success', key: 'paid' },
  pending: { icon: 'hourglass_top', tone: 'text-warning', key: 'pending' },
  cancelled: { icon: 'cancel', tone: 'text-ink-muted', key: 'cancelled' },
};

const resolveView = (outcome, params) => {
  const status = String(params.get('status') || '').toUpperCase();
  if (outcome === 'cancel' || params.get('cancel') === 'true' || status === 'CANCELLED') return VIEWS.cancelled;
  return status === 'PAID' ? VIEWS.paid : VIEWS.pending;
};

const PaymentResultPage = ({ outcome }) => {
  const { t } = useLanguageSafe();
  const [params] = useSearchParams();
  const view = resolveView(outcome, params);
  const orderCode = /^\d{1,20}$/.test(params.get('orderCode') || '') ? params.get('orderCode') : null;

  return (
    <AuthShell brand="FlowMoney" title={t(`paymentResult.${view.key}.title`)}>
      <div className="flex flex-col items-center gap-4 text-center">
        <Icon name={view.icon} size="lg" className={view.tone} />
        <p className="m-0 text-sm text-ink">{t(`paymentResult.${view.key}.body`)}</p>
        {orderCode && (
          <p className="m-0 text-sm text-ink-muted">
            {t('paymentResult.orderCode')}: <span className="font-semibold text-ink">{orderCode}</span>
          </p>
        )}
        <p className="m-0 text-sm text-ink-muted">{t('paymentResult.backToApp')}</p>
      </div>
    </AuthShell>
  );
};

export default PaymentResultPage;
