import React, { useEffect, useState } from 'react';
import { useAlert } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';

const ALERT_CONFIG = {
  success: {
    icon: 'check_circle',
    borderColor: 'border-emerald-500',
    iconBg: 'bg-emerald-100 text-emerald-600',
    titleColor: 'text-emerald-950',
    progressBg: 'bg-emerald-500',
    defaultTitle: 'Thành công',
  },
  error: {
    icon: 'error',
    borderColor: 'border-rose-500',
    iconBg: 'bg-rose-100 text-rose-600',
    titleColor: 'text-rose-950',
    progressBg: 'bg-rose-500',
    defaultTitle: 'Lỗi / Thất bại',
  },
  warning: {
    icon: 'warning',
    borderColor: 'border-amber-500',
    iconBg: 'bg-amber-100 text-amber-600',
    titleColor: 'text-amber-950',
    progressBg: 'bg-amber-500',
    defaultTitle: 'Cảnh báo',
  },
  info: {
    icon: 'info',
    borderColor: 'border-sky-500',
    iconBg: 'bg-sky-100 text-sky-600',
    titleColor: 'text-sky-950',
    progressBg: 'bg-sky-500',
    defaultTitle: 'Thông báo',
  },
};

const AlertItem = ({ alert, onRemove }) => {
  const { t } = useLanguageSafe();
  const cfg = ALERT_CONFIG[alert.type] || ALERT_CONFIG.info;
  const defaultTitle = t(`common.alertToast.${alert.type}`, cfg.defaultTitle);
  const [progress, setProgress] = useState(100);

  useEffect(() => {
    if (!alert.duration || alert.duration <= 0) return;
    const startTime = Date.now();
    const interval = setInterval(() => {
      const elapsed = Date.now() - startTime;
      const remaining = Math.max(0, 100 - (elapsed / alert.duration) * 100);
      setProgress(remaining);
      if (remaining <= 0) {
        clearInterval(interval);
      }
    }, 30);

    return () => clearInterval(interval);
  }, [alert.duration]);

  return (
    <div
      role="alert"
      data-testid={`alert-toast-${alert.type}`}
      className={`pointer-events-auto w-full bg-white/95 text-slate-800 rounded-xl shadow-xl border-l-4 ${cfg.borderColor} border border-slate-200/80 backdrop-blur-md overflow-hidden transition-all transform duration-200 animate-in slide-in-from-right-6 fade-in select-none`}
    >
      <div className="p-3.5 flex items-start gap-3">
        <div className={`w-8 h-8 rounded-lg ${cfg.iconBg} flex items-center justify-center flex-shrink-0 mt-0.5`}>
          <span className="material-symbols-outlined text-[20px]">{cfg.icon}</span>
        </div>

        <div className="flex-1 min-w-0 pr-1">
          <div className="flex items-center justify-between gap-2">
            <h4 className={`text-xs font-bold ${cfg.titleColor} truncate m-0`}>
              {alert.title || defaultTitle}
            </h4>
            <button
              type="button"
              data-testid="alert-close-btn"
              onClick={() => onRemove(alert.id)}
              className="text-slate-400 hover:text-slate-700 transition-colors p-0.5 rounded cursor-pointer"
              title={t('common.alertToast.close', 'Đóng thông báo')}
            >
              <span className="material-symbols-outlined text-[16px]">close</span>
            </button>
          </div>
          <p className="text-xs text-slate-600 mt-1 font-medium leading-relaxed break-words">
            {alert.message}
          </p>
        </div>
      </div>

      {/* Thanh tiến trình thời gian tự đóng */}
      {alert.duration > 0 && (
        <div className="h-1 w-full bg-slate-100 overflow-hidden">
          <div
            className={`h-full ${cfg.progressBg} transition-all ease-linear`}
            style={{ width: `${progress}%` }}
          />
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
      className="fixed top-20 right-4 md:right-6 z-[9999] flex flex-col gap-2.5 max-w-sm sm:max-w-md w-full pointer-events-none"
    >
      {alerts.map((alert) => (
        <AlertItem key={alert.id} alert={alert} onRemove={removeAlert} />
      ))}
    </div>
  );
};

export default AlertContainer;
