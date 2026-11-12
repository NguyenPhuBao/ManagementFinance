import React, { useState, useEffect, useRef } from 'react';
import notificationApi from '../../api/notification.api';
import useSocket from '../../hooks/useSocket';
import { useAlertSafe } from '../../store/alert.context';
import { useSettingsSafe } from '../../store/settings.context';
import { useLanguageSafe } from '../../store/language.context';
import { useAuthContext } from '../../store/auth.context';
import soundService from '../../services/sound.service';
import SettingsModal from './SettingsModal';
import LanguageToggle from '../common/LanguageToggle';
import RealtimeStatusBadge from '../common/RealtimeStatusBadge';
import { Button, Icon, Spinner, EmptyState } from '../ui';

const LEVELS = {
  CRITICAL: { icon: 'error', tone: 'bg-danger-soft text-danger' },
  WARNING: { icon: 'warning', tone: 'bg-warning-soft text-warning' },
  INFO: { icon: 'info', tone: 'bg-info-soft text-info' },
};

const levelOf = (level) => LEVELS[String(level || '').toUpperCase()] || LEVELS.INFO;

const formatTime = (value) =>
  value ? new Date(value).toLocaleString('vi-VN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit' }) : '';

const Header = ({ onMenuToggle, sidebarCollapsed }) => {
  const alert = useAlertSafe();
  const settings = useSettingsSafe()?.settings;
  const { t } = useLanguageSafe();
  const { user } = useAuthContext();
  const socket = useSocket();
  const dropdownRef = useRef(null);
  const [open, setOpen] = useState(false);
  const [showSettings, setShowSettings] = useState(false);
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(false);

  const fetchAlerts = async () => {
    try {
      setLoading(true);
      const res = await notificationApi.getAdminAlerts({ page: 1, limit: 10 });
      const payload = res?.data || res;
      if (payload) {
        setNotifications(payload.notifications || (Array.isArray(payload) ? payload : []));
        setUnreadCount(typeof payload.unreadCount === 'number' ? payload.unreadCount : 0);
      }
    } catch (err) {
      console.error('[Header] Failed to fetch admin alerts', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAlerts();
  }, []);

  useEffect(() => {
    if (!socket) return undefined;

    const handleAdminNotification = (item) => {
      setNotifications((prev) => [item, ...prev.slice(0, 9)]);
      setUnreadCount((prev) => prev + 1);
      if (alert && item?.message) {
        if (item.level === 'critical') alert.error(item.message, item.title || t('header.alertCritical'));
        else if (item.level === 'warning') alert.warning(item.message, item.title || t('header.alertWarning'));
        else alert.info(item.message, item.title || t('header.alertInfo'));
      }
    };

    const handleSecurityAlert = (data) => {
      if (!data) return;
      const message = data.anomalies?.map((a) => a.message).join(' | ') || t('header.securityFallback');
      const title = `AIOps ${data.status}: ${data.threatScore}/100`;
      setNotifications((prev) => [
        {
          id: `aiops-${Date.now()}`,
          title,
          message,
          level: data.status === 'CRITICAL' ? 'critical' : 'warning',
          createdAt: data.timestamp || new Date().toISOString(),
          isRead: false,
        },
        ...prev.slice(0, 9),
      ]);
      setUnreadCount((prev) => prev + 1);
      if (!alert) return;
      if (data.status === 'CRITICAL') {
        if (settings?.soundEnabled !== false) soundService.playCriticalAlarm();
        alert.error(message, title);
      } else {
        alert.warning(message, title);
      }
    };

    socket.on('admin.notification', handleAdminNotification);
    socket.on('admin.security_alert', handleSecurityAlert);
    return () => {
      socket.off('admin.notification', handleAdminNotification);
      socket.off('admin.security_alert', handleSecurityAlert);
    };
  }, [socket, settings?.soundEnabled]);

  useEffect(() => {
    if (!open) return undefined;
    const onPointer = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) setOpen(false);
    };
    const onKey = (e) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onPointer);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onPointer);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const handleMarkAsRead = async (item) => {
    if (item.isRead) return;
    try {
      await notificationApi.markAdminAlertAsRead(item.id);
      setNotifications((prev) => prev.map((n) => (n.id === item.id ? { ...n, isRead: true } : n)));
      setUnreadCount((prev) => Math.max(0, prev - 1));
    } catch (err) {
      console.error('[Header] Failed to mark alert as read', err);
    }
  };

  const toggleDropdown = () => {
    if (!open) fetchAlerts();
    setOpen(!open);
  };

  const showBadge = settings?.showUnreadBadge !== false && unreadCount > 0;
  const displayName = user?.username || user?.fullname || user?.email;

  return (
    <header className="sticky top-0 z-20 flex h-14 items-center justify-between gap-3 border-b border-line bg-card px-4 md:px-6">
      <Button
        variant="ghost"
        size="sm"
        icon={sidebarCollapsed ? 'menu' : 'menu_open'}
        aria-label={t('header.toggleMenu', 'Mở/đóng menu')}
        onClick={onMenuToggle}
      />

      <div className="flex items-center gap-2 sm:gap-3">
        <RealtimeStatusBadge className="hidden sm:inline-flex" />

        <div className="relative" ref={dropdownRef}>
          <button
            type="button"
            aria-label={showBadge ? `${t('header.notifications')}, ${t('header.unread', { count: unreadCount })}` : t('header.notifications')}
            aria-expanded={open}
            onClick={toggleDropdown}
            className="relative flex h-9 w-9 cursor-pointer items-center justify-center rounded-lg text-ink-muted transition-colors hover:bg-muted hover:text-ink"
          >
            <Icon name="notifications" />
            {showBadge && (
              <span className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-danger px-1 text-xs font-semibold leading-none text-card">
                {unreadCount > 99 ? '99+' : unreadCount}
              </span>
            )}
          </button>

          {open && (
            <div className="absolute right-0 top-full z-50 mt-2 w-80 overflow-hidden rounded-xl border border-line bg-card shadow-xl md:w-96">
              <div className="flex items-center justify-between gap-2 border-b border-line px-4 py-3">
                <span className="text-sm font-semibold text-ink">{t('header.systemAlerts')}</span>
                <Button variant="ghost" size="sm" icon="refresh" onClick={fetchAlerts}>
                  {t('header.refreshAlerts')}
                </Button>
              </div>
              <div className="max-h-96 divide-y divide-line overflow-y-auto">
                {loading && notifications.length === 0 ? (
                  <div className="flex justify-center py-8 text-brand">
                    <Spinner />
                  </div>
                ) : notifications.length === 0 ? (
                  <EmptyState icon="notifications_off" title={t('header.systemStableTitle')} description={t('header.systemStableDesc')} />
                ) : (
                  notifications.map((item) => {
                    const level = levelOf(item.level);
                    return (
                      <button
                        key={item.id}
                        type="button"
                        onClick={() => handleMarkAsRead(item)}
                        className={`flex w-full cursor-pointer items-start gap-3 px-4 py-3 text-left transition-colors hover:bg-muted ${
                          item.isRead ? '' : 'bg-info-soft/40'
                        }`}
                      >
                        <span className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full ${level.tone}`}>
                          <Icon name={level.icon} size="sm" />
                        </span>
                        <span className="min-w-0 flex-1">
                          <span className={`block truncate text-sm ${item.isRead ? 'text-ink-muted' : 'font-semibold text-ink'}`}>
                            {item.title}
                          </span>
                          <span className="mt-0.5 line-clamp-2 block text-xs text-ink-muted">{item.message}</span>
                          <span className="mt-1 block text-xs text-ink-faint">{formatTime(item.createdAt)}</span>
                        </span>
                        {!item.isRead && <span aria-hidden="true" className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-info" />}
                      </button>
                    );
                  })
                )}
              </div>
            </div>
          )}
        </div>

        <LanguageToggle />

        <Button variant="ghost" size="sm" icon="settings" aria-label={t('header.settings')} onClick={() => setShowSettings(true)} />

        {displayName && (
          <div className="hidden items-center gap-2 md:flex">
            <span aria-hidden="true" className="flex h-8 w-8 items-center justify-center rounded-full bg-muted text-xs font-semibold uppercase text-ink-muted">
              {String(displayName).slice(0, 2)}
            </span>
            <span className="max-w-40 truncate text-sm font-medium text-ink">{displayName}</span>
          </div>
        )}
      </div>

      <SettingsModal isOpen={showSettings} onClose={() => setShowSettings(false)} />
    </header>
  );
};

export default Header;
