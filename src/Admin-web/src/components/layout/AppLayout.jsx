import React, { useState, useEffect } from 'react';
import { Link, Outlet } from 'react-router-dom';
import AppSidebar from './Sidebar';
import AppHeader from './Header';
import LockScreenModal from './LockScreenModal';
import FirstLoginModal from './FirstLoginModal';
import useSocket from '../../hooks/useSocket';
import aiopsApi from '../../api/aiops.api';
import adminApi from '../../api/admin.api';
import { useLanguageSafe } from '../../store/language.context';
import { useSettingsSafe } from '../../store/settings.context';
import { useAlertSafe } from '../../store/alert.context';
import { Button, ConfirmModal, Icon } from '../ui';

const SIDEBAR_KEY = 'admin_sidebar_collapsed';

const isCriticalThreat = (data) => Boolean(data) && (data.recommendedAction === 'EMERGENCY_MAINTENANCE' || data.vectorScores?.resource >= 85);

const Toast = ({ tone, icon, title, onClose, closeLabel, children }) => (
  <div
    role="status"
    className={`fixed bottom-6 z-50 flex max-w-sm items-start gap-3 rounded-xl border border-line bg-card p-4 shadow-xl ${
      tone === 'danger' ? 'right-6' : 'left-6'
    }`}
  >
    <span className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full ${tone === 'danger' ? 'bg-danger-soft text-danger' : 'bg-success-soft text-success'}`}>
      <Icon name={icon} size="sm" />
    </span>
    <div className="min-w-0 flex-1 text-sm">
      <p className="m-0 font-semibold text-ink">{title}</p>
      <div className="mt-0.5 text-ink-muted">{children}</div>
    </div>
    <Button variant="ghost" size="sm" icon="close" aria-label={closeLabel} onClick={onClose} />
  </div>
);

const AppLayout = () => {
  const { t } = useLanguageSafe();
  const settingsCtx = useSettingsSafe();
  const notify = useAlertSafe();
  const socket = useSocket();

  const [sidebarCollapsed, setSidebarCollapsed] = useState(() => {
    try {
      return localStorage.getItem(SIDEBAR_KEY) === 'true';
    } catch (_) {
      return false;
    }
  });
  const [mobileOpen, setMobileOpen] = useState(false);
  const [threatAlert, setThreatAlert] = useState(null);
  const [dismissed, setDismissed] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [mitigating, setMitigating] = useState(false);
  const [mitigatedSuccess, setMitigatedSuccess] = useState(false);
  const [maintenanceState, setMaintenanceState] = useState(null);
  const [restoredToast, setRestoredToast] = useState(false);
  const [blockedToast, setBlockedToast] = useState(null);

  const toggleSidebar = () => {
    if (window.matchMedia?.('(max-width: 767px)').matches) {
      setMobileOpen((prev) => !prev);
      return;
    }
    setSidebarCollapsed((prev) => {
      const next = !prev;
      try {
        localStorage.setItem(SIDEBAR_KEY, String(next));
      } catch (_) {}
      return next;
    });
  };

  const checkThreatStatus = async () => {
    if (settingsCtx?.isLocked) return;
    try {
      const res = await aiopsApi.getStatus();
      const data = res?.data || res;
      if (isCriticalThreat(data)) {
        setThreatAlert(data);
      } else {
        setThreatAlert(null);
        setDismissed(false);
      }
    } catch (_) {}
  };

  useEffect(() => {
    checkThreatStatus();
    adminApi
      .getMaintenanceStatus()
      .then((res) => {
        const data = res?.data || res;
        if (data?.active) setMaintenanceState(data);
      })
      .catch(() => {});
    const interval = setInterval(checkThreatStatus, 15000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (!socket) return undefined;

    const handleSecurityAlert = (data) => {
      if (isCriticalThreat(data)) {
        setThreatAlert(data);
        setDismissed(false);
      } else if (data && data.threatScore < 70) {
        setThreatAlert(null);
      }
    };

    const handleSecurityBlocked = (data) => {
      setBlockedToast(data);
      setTimeout(() => setBlockedToast(null), 7000);
    };

    const handleMaintenanceChanged = (data) => {
      if (!data) return;
      if (data.active) {
        setMaintenanceState(data);
        setRestoredToast(false);
      } else {
        setMaintenanceState(null);
        setRestoredToast(true);
        setTimeout(() => setRestoredToast(false), 7000);
      }
    };

    socket.on('admin.security_alert', handleSecurityAlert);
    socket.on('admin.security_blocked', handleSecurityBlocked);
    socket.on('admin.maintenance_changed', handleMaintenanceChanged);
    return () => {
      socket.off('admin.security_alert', handleSecurityAlert);
      socket.off('admin.security_blocked', handleSecurityBlocked);
      socket.off('admin.maintenance_changed', handleMaintenanceChanged);
    };
  }, [socket]);

  const handleQuickMitigation = async () => {
    try {
      setMitigating(true);
      await adminApi.setMaintenanceStatus({
        active: true,
        reason: t('appLayout.emergencyReason'),
        isEmergency: true,
      });
      setConfirmOpen(false);
      setMitigatedSuccess(true);
      setTimeout(() => setDismissed(true), 3000);
    } catch (err) {
      const message = err.response?.data?.message || err.message;
      setConfirmOpen(false);
      if (notify) notify.error(message, t('appLayout.activateFailed'));
      else window.alert(`${t('appLayout.activateFailed')}: ${message}`);
    } finally {
      setMitigating(false);
    }
  };

  const isAlertVisible = isCriticalThreat(threatAlert) && !dismissed;
  const isMaintenanceVisible = Boolean(maintenanceState?.active) && !isAlertVisible;
  const score = threatAlert?.vectorScores?.resource ?? threatAlert?.threatScore;

  return (
    <div className="min-h-screen bg-canvas text-ink">
      <AppSidebar
        collapsed={sidebarCollapsed}
        mobileOpen={mobileOpen}
        onToggle={toggleSidebar}
        onCloseMobile={() => setMobileOpen(false)}
      />

      <div className={`flex min-h-screen min-w-0 flex-col transition-[padding] duration-200 ${sidebarCollapsed ? 'md:pl-[72px]' : 'md:pl-60'}`}>
        <AppHeader onMenuToggle={toggleSidebar} sidebarCollapsed={sidebarCollapsed} />

        {isAlertVisible && (
          <div role="alert" className="flex flex-wrap items-center justify-between gap-3 border-b border-line bg-danger-soft px-4 py-3 md:px-6">
            <div className="flex min-w-0 items-center gap-2.5 text-sm text-danger">
              <Icon name="crisis_alert" />
              <span className="font-semibold">{t('appLayout.threatTitle')}</span>
              <span>
                {t('appLayout.threatScore', { score })}
                {threatAlert.anomalies?.length > 0 && ` · ${threatAlert.anomalies[0].code}`}
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              {mitigatedSuccess ? (
                <span className="text-sm font-semibold text-danger">{t('appLayout.emergencyLocked')}</span>
              ) : (
                <Button variant="danger" size="sm" icon="lock" onClick={() => setConfirmOpen(true)}>
                  {t('appLayout.emergencyLockBtn')}
                </Button>
              )}
              <Link to="/aiops" className="inline-flex h-9 items-center rounded-lg px-3 text-sm font-medium text-danger hover:bg-card">
                {t('appLayout.viewAnalysis')}
              </Link>
              <Button variant="danger-ghost" size="sm" icon="close" aria-label={t('appLayout.dismiss')} onClick={() => setDismissed(true)} />
            </div>
          </div>
        )}

        {isMaintenanceVisible && (
          <section
            aria-label={t('appLayout.maintenanceTitle')}
            className="flex flex-wrap items-center justify-between gap-3 border-b border-line bg-warning-soft px-4 py-3 md:px-6"
          >
            <div className="flex min-w-0 items-center gap-2.5 text-sm text-warning">
              <Icon name="engineering" />
              <span className="font-semibold">{t('appLayout.maintenanceTitle')}</span>
              <span>
                {maintenanceState.reason || t('appLayout.maintenanceDefaultReason')}
                {maintenanceState.activatedBy && ` (${t('appLayout.activatedBy', { name: maintenanceState.activatedBy })})`}
              </span>
            </div>
            <Link to="/broadcast" className="inline-flex h-9 items-center rounded-lg px-3 text-sm font-medium text-warning hover:bg-card">
              {t('appLayout.manageMaintenance')}
            </Link>
          </section>
        )}

        <main className="w-full flex-1 px-4 py-6 md:px-6">
          <div className="mx-auto w-full min-w-0 max-w-screen-2xl">
            <Outlet />
          </div>
        </main>
      </div>

      <ConfirmModal
        open={confirmOpen}
        title={t('appLayout.confirmEmergencyTitle')}
        message={t('appLayout.confirmEmergency')}
        confirmText={t('appLayout.confirmEmergencyBtn')}
        confirmDanger
        loading={mitigating}
        onConfirm={handleQuickMitigation}
        onCancel={() => setConfirmOpen(false)}
      />

      {restoredToast && (
        <Toast tone="success" icon="check_circle" title={t('appLayout.restoredToastTitle')} closeLabel={t('common.close')} onClose={() => setRestoredToast(false)}>
          {t('appLayout.restoredToastDesc')}
        </Toast>
      )}

      {blockedToast && (
        <Toast tone="danger" icon="shield" title={t('appLayout.quarantineToastTitle')} closeLabel={t('common.close')} onClose={() => setBlockedToast(null)}>
          <p className="m-0">{t('appLayout.quarantineToastIp', { ip: blockedToast.maskedIp })}</p>
          {blockedToast.reason && <p className="m-0 mt-0.5 line-clamp-2 text-xs">{t('appLayout.quarantineToastReason', { reason: blockedToast.reason })}</p>}
          <Link to="/aiops" onClick={() => setBlockedToast(null)} className="mt-2 inline-block text-sm font-medium text-danger hover:underline">
            {t('appLayout.viewQuarantineList')}
          </Link>
        </Toast>
      )}

      <LockScreenModal />
      <FirstLoginModal />
    </div>
  );
};

export default AppLayout;
