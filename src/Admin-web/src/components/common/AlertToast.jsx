import React, { useEffect, useState } from 'react';
import { useAlert } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import { Button, Icon } from '../ui';

const TYPES = {
  success: { icon: 'check_circle', tone: 'bg-success-soft text-success', bar: 'bg-success', fallback: 'Thành công' },
  error: { icon: 'error', tone: 'bg-danger-soft text-danger', bar: 'bg-danger', fallback: 'Lỗi' },
  warning: { icon: 'warning', tone: 'bg-warning-soft text-warning', bar: 'bg-warning', fallback: 'Cảnh báo' },
  info: { icon: 'info', tone: 'bg-info-soft text-info', bar: 'bg-info', fallback: 'Thông báo' },
};

const AlertItem = ({ alert, onRemove }) => {
  const { t } = useLanguageSafe();
  const cfg = TYPES[alert.type] || TYPES.info;
  const [progress, setProgress] = useState(100);

  useEffect(() => {
    if (!alert.duration || alert.duration <= 0) return undefined;
    const startTime = Date.now();
    const interval = setInterval(() => {
      const remaining = Math.max(0, 100 - ((Date.now() - startTime) / alert.duration) * 100);
      setProgress(remaining);
      if (remaining <= 0) clearInterval(interval);
    }, 30);
    return () => clearInterval(interval);
  }, [alert.duration]);

  return (
    <div
      role="alert"
      data-testid={`alert-toast-${alert.type}`}
      className="pointer-events-auto w-full overflow-hidden rounded-xl border border-line bg-card shadow-xl"
    >
      <div className="flex items-start gap-3 p-3.5">
        <span className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full ${cfg.tone}`}>
          <Icon name={cfg.icon} size="sm" />
        </span>
        <div className="min-w-0 flex-1">
          <p className="m-0 truncate text-sm font-semibold text-ink">{alert.title || t(`common.alertToast.${alert.type}`, cfg.fallback)}</p>
          <p className="m-0 mt-0.5 break-words text-sm text-ink-muted">{alert.message}</p>
        </div>
        <Button
          variant="ghost"
          size="sm"
          icon="close"
          data-testid="alert-close-btn"
          aria-label={t('common.alertToast.close', 'Đóng thông báo')}
          onClick={() => onRemove(alert.id)}
        />
      </div>
      {alert.duration > 0 && (
        <div className="h-1 w-full bg-muted">
          <div className={`h-full transition-all ease-linear ${cfg.bar}`} style={{ width: `${progress}%` }} />
        </div>
      )}
    </div>
  );
};

export const AlertContainer = () => {
  const { alerts, removeAlert } = useAlert();
  const { t } = useLanguageSafe();
  if (!alerts || alerts.length === 0) return null;
  return (
    <div
      aria-live="polite"
      aria-label={t('common.alertToast.ariaLabel', 'Thông báo hệ thống')}
      className="pointer-events-none fixed right-4 top-16 z-[9999] flex w-full max-w-sm flex-col gap-2.5 md:right-6"
    >
      {alerts.map((alert) => (
        <AlertItem key={alert.id} alert={alert} onRemove={removeAlert} />
      ))}
    </div>
  );
};

export default AlertContainer;
