import React, { useState, useEffect, useRef } from 'react';
import notificationApi from '../../api/notification.api';
import useSocket from '../../hooks/useSocket';
import { useAlertSafe } from '../../store/alert.context';
import { useSettingsSafe } from '../../store/settings.context';
import { useLanguageSafe } from '../../store/language.context';
import soundService from '../../services/sound.service';
import SettingsModal from './SettingsModal';
import LanguageToggle from '../common/LanguageToggle';

const Header = ({ onMenuToggle }) => {
  const alert = useAlertSafe();
  const settingsCtx = useSettingsSafe();
  const settings = settingsCtx?.settings;
  const { t } = useLanguageSafe();
  const [showNotifications, setShowNotifications] = useState(false);

  const [showSettings, setShowSettings] = useState(false);
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(false);
  const dropdownRef = useRef(null);
  const socket = useSocket();

  // Tải danh sách cảnh báo admin ban đầu
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

  // Lắng nghe sự kiện socket realtime admin.notification & admin.security_alert
  useEffect(() => {
    if (!socket) return;

    const handleAdminNotification = (newAlert) => {
      setNotifications((prev) => [newAlert, ...prev.slice(0, 9)]);
      setUnreadCount((prev) => prev + 1);

      // Kích hoạt Alert Toast nổi song song với icon chuông
      if (alert && newAlert?.message) {
        if (newAlert.level === 'critical') alert.error(newAlert.message, newAlert.title || 'Cảnh Báo Khẩn');
        else if (newAlert.level === 'warning') alert.warning(newAlert.message, newAlert.title || 'Cảnh Báo Hệ Thống');
        else alert.info(newAlert.message, newAlert.title || 'Thông Báo');
      }
    };

    const handleSecurityAlert = (alertData) => {
      if (!alertData) return;
      const formatted = {
        id: `aiops-${Date.now()}`,
        title: `🚨 [AIOps] ${alertData.status}: Threat Score ${alertData.threatScore}/100`,
        message: alertData.anomalies?.map(a => a.message).join(' | ') || 'Phát hiện rủi ro an ninh/quá tải hệ thống',
        level: alertData.status === 'CRITICAL' ? 'critical' : 'warning',
        createdAt: alertData.timestamp || new Date().toISOString(),
        isRead: false,
      };
      setNotifications((prev) => [formatted, ...prev.slice(0, 9)]);
      setUnreadCount((prev) => prev + 1);

      // Kích hoạt Alert Toast nổi cảnh báo an ninh
      if (alert) {
        const alertMsg = alertData.anomalies?.map(a => a.message).join(' | ') || `Threat Score ${alertData.threatScore}/100`;
        if (alertData.status === 'CRITICAL') {
          if (settings?.soundEnabled !== false) {
            soundService.playCriticalAlarm();
          }
          alert.error(alertMsg, `🚨 AIOps: ${alertData.status}`);
        } else {
          alert.warning(alertMsg, `⚠️ AIOps: ${alertData.status}`);
        }
      }
    };

    socket.on('admin.notification', handleAdminNotification);
    socket.on('admin.security_alert', handleSecurityAlert);

    return () => {
      socket.off('admin.notification', handleAdminNotification);
      socket.off('admin.security_alert', handleSecurityAlert);
    };
  }, [socket, settings?.soundEnabled]);

  // Đóng dropdown khi click ra ngoài
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setShowNotifications(false);
      }
    };
    if (showNotifications) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [showNotifications]);

  // Đánh dấu 1 thông báo đã đọc
  const handleMarkAsRead = async (item) => {
    if (item.isRead) return;
    try {
      await notificationApi.markAdminAlertAsRead(item.id);
      setNotifications((prev) =>
        prev.map((n) => (n.id === item.id ? { ...n, isRead: true } : n))
      );
      setUnreadCount((prev) => Math.max(0, prev - 1));
    } catch (err) {
      console.error('[Header] Failed to mark alert as read', err);
    }
  };

  const getLevelBadgeClass = (level) => {
    switch (level?.toUpperCase()) {
      case 'CRITICAL':
        return 'bg-red-100 text-red-700 border-red-200';
      case 'WARNING':
        return 'bg-amber-100 text-amber-700 border-amber-200';
      default:
        return 'bg-blue-100 text-blue-700 border-blue-200';
    }
  };

  const getLevelIcon = (level) => {
    switch (level?.toUpperCase()) {
      case 'CRITICAL':
        return 'error';
      case 'WARNING':
        return 'warning';
      default:
        return 'info';
    }
  };

  const shouldShowBadge = settings?.showUnreadBadge !== false && unreadCount > 0;

  return (
    <header className="fixed top-0 right-0 left-0 md:left-[280px] h-16 bg-surface border-b border-outline-variant flex items-center justify-between px-page-padding z-30">
      <div className="flex items-center gap-4">
        <button onClick={onMenuToggle} className="md:hidden text-on-surface hover:text-primary transition-colors">
          <span className="material-symbols-outlined">menu</span>
        </button>
        <div className="font-headline-sm text-headline-sm font-semibold text-on-surface md:hidden">{t('nav.brandTitle')}</div>
      </div>

      <div className="flex items-center gap-2 relative" ref={dropdownRef}>
        {/* Nút Chuông Thông Báo */}
        <button 
          className="p-2 rounded-full text-on-surface-variant hover:bg-surface-container-low transition-all cursor-pointer active:opacity-80 relative"
          onClick={() => {
            setShowNotifications(!showNotifications);
            if (!showNotifications) fetchAlerts();
          }}
          title={t('header.notifications')}
        >
          <span className="material-symbols-outlined text-[24px]">notifications</span>
          {shouldShowBadge && (
            <span className="absolute top-1 right-1 min-w-[18px] h-[18px] bg-red-600 text-white text-[10px] font-bold rounded-full flex items-center justify-center px-1 shadow-sm animate-pulse">
              {unreadCount > 99 ? '99+' : unreadCount}
            </span>
          )}
        </button>

        {/* Component Chuyển Đổi Ngôn Ngữ Pill [ EN | VI ] */}
        <LanguageToggle />

        {/* Nút Cài đặt Hệ thống */}
        <button 
          className="p-2 rounded-full text-on-surface-variant hover:bg-surface-container-low transition-all cursor-pointer active:opacity-80"
          onClick={() => setShowSettings(true)}
          title={t('header.settings')}
        >
          <span className="material-symbols-outlined text-[24px]">settings</span>
        </button>
        
        {/* Dropdown danh sách cảnh báo */}
        {showNotifications && (
          <div className="absolute right-0 top-full mt-2 w-80 md:w-96 bg-white rounded-xl shadow-[0_12px_28px_rgba(11,28,48,0.15)] border border-outline-variant z-50 overflow-hidden">
            <div className="px-4 py-3 border-b border-outline-variant flex items-center justify-between bg-surface-container-lowest">
              <div className="flex items-center gap-2">
                <span className="font-semibold text-sm text-on-surface">{t('header.systemAlerts')}</span>
                {unreadCount > 0 && (
                  <span className="px-2 py-0.5 bg-red-100 text-red-700 text-xs font-medium rounded-full">
                    {unreadCount} {t('header.newBadge')}
                  </span>
                )}
              </div>
              <button 
                onClick={fetchAlerts}
                className="text-xs text-primary hover:underline flex items-center gap-1 cursor-pointer"
              >
                <span className="material-symbols-outlined text-[16px]">refresh</span>
                {t('header.refreshAlerts')}
              </button>
            </div>

            <div className="max-h-[380px] overflow-y-auto divide-y divide-outline-variant">
              {loading ? (
                <div className="p-6 text-center text-secondary text-sm">{t('common.loading')}</div>
              ) : notifications.length === 0 ? (
                <div className="p-8 flex flex-col items-center justify-center gap-2 text-center">
                  <span className="material-symbols-outlined text-secondary text-[36px] opacity-40">notifications_off</span>
                  <p className="text-secondary text-sm">{t('header.systemStableTitle')}</p>
                  <p className="text-secondary text-xs opacity-75">{t('header.systemStableDesc')}</p>
                </div>
              ) : (
                notifications.map((item) => (
                  <div
                    key={item.id}
                    onClick={() => handleMarkAsRead(item)}
                    className={`p-3.5 hover:bg-surface-container-low transition-colors cursor-pointer flex items-start gap-3 ${
                      !item.isRead ? 'bg-blue-50/40' : ''
                    }`}
                  >
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 border ${getLevelBadgeClass(item.level)}`}>
                      <span className="material-symbols-outlined text-[18px]">
                        {getLevelIcon(item.level)}
                      </span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between gap-1 mb-0.5">
                        <p className={`text-xs font-medium truncate ${!item.isRead ? 'text-on-surface font-semibold' : 'text-secondary'}`}>
                          {item.title}
                        </p>
                        {!item.isRead && (
                          <span className="w-2 h-2 bg-blue-600 rounded-full flex-shrink-0"></span>
                        )}
                      </div>
                      <p className="text-xs text-on-surface-variant line-clamp-2 mb-1">
                        {item.message}
                      </p>
                      <span className="text-[10px] text-secondary">
                        {item.createdAt ? new Date(item.createdAt).toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit' }) : ''}
                      </span>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        )}
      </div>

      {/* Modal Cài Đặt Hệ Thống */}
      <SettingsModal 
        isOpen={showSettings} 
        onClose={() => setShowSettings(false)} 
      />
    </header>
  );
};

export default Header;
