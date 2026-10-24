import React, { useState, useEffect } from 'react';
import { useSocketContext } from '../../store/socket.context';
import { useLanguageSafe } from '../../store/language.context';

/**
 * Component RealtimeStatusBadge:
 * Hiển thị chính xác trạng thái kết nối thời gian thực (Socket.IO)
 * Tự động chuyển đổi giữa 3 trạng thái:
 * 1. 🟢 Real-time: Đang kết nối ổn định (ping animation)
 * 2. 🟡 Đang kết nối...: Đang kết nối lần đầu hoặc đang thử kết nối lại
 * 3. 🔴 Mất kết nối: Socket bị ngắt hoặc gặp sự cố mạng (cảnh báo đỏ/cam)
 *
 * @param {boolean} [props.connected] - Ghi đè trạng thái kết nối thủ công (nếu có)
 * @param {string} [props.className] - CSS class bổ sung
 */
const RealtimeStatusBadge = ({ connected: propConnected, className = '' }) => {
  const { socket, connected: contextConnected } = useSocketContext();
  const { t } = useLanguageSafe();

  // Xác định trạng thái kết nối nội bộ
  const [internalStatus, setInternalStatus] = useState(() => {
    if (propConnected !== undefined) {
      return propConnected ? 'connected' : 'disconnected';
    }
    if (socket) {
      return socket.connected ? 'connected' : 'connecting';
    }
    return contextConnected ? 'connected' : 'connecting';
  });

  useEffect(() => {
    // Nếu có prop ghi đè trực tiếp
    if (propConnected !== undefined) {
      setInternalStatus(propConnected ? 'connected' : 'disconnected');
      return;
    }

    if (!socket) {
      setInternalStatus(contextConnected ? 'connected' : 'disconnected');
      return;
    }

    // Khởi tạo theo socket hiện tại
    setInternalStatus(socket.connected ? 'connected' : 'connecting');

    const handleConnect = () => setInternalStatus('connected');
    const handleDisconnect = () => setInternalStatus('disconnected');
    const handleConnectError = () => setInternalStatus('disconnected');
    const handleReconnectAttempt = () => setInternalStatus('connecting');
    const handleReconnectFailed = () => setInternalStatus('disconnected');
    const handleError = () => setInternalStatus('disconnected');

    socket.on('connect', handleConnect);
    socket.on('disconnect', handleDisconnect);
    socket.on('connect_error', handleConnectError);
    socket.on('reconnect_attempt', handleReconnectAttempt);
    socket.on('reconnect_failed', handleReconnectFailed);
    socket.on('error', handleError);

    return () => {
      socket.off('connect', handleConnect);
      socket.off('disconnect', handleDisconnect);
      socket.off('connect_error', handleConnectError);
      socket.off('reconnect_attempt', handleReconnectAttempt);
      socket.off('reconnect_failed', handleReconnectFailed);
      socket.off('error', handleError);
    };
  }, [socket, propConnected, contextConnected]);

  if (internalStatus === 'connected') {
    return (
      <span
        data-testid="realtime-status-badge"
        data-status="connected"
        className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-[#dcfce7] text-[#166534] font-label-md text-[11px] font-semibold border border-[#86efac] shadow-2xs transition-all duration-200 select-none ${className}`}
        title={t('dashboard.recentActivities.realtimeTooltip', 'Máy chủ thời gian thực Socket.IO đang kết nối ổn định')}
      >
        <span className="relative flex h-2 w-2">
          <span className="inline-flex rounded-full h-2 w-2 bg-[#166534]"></span>
        </span>
        <span>{t('dashboard.recentActivities.realtime', 'Real-time')}</span>
      </span>
    );
  }

  if (internalStatus === 'connecting') {
    return (
      <span
        data-testid="realtime-status-badge"
        data-status="connecting"
        className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-amber-50 text-amber-700 font-label-md text-[11px] font-medium border border-amber-200 shadow-2xs transition-all duration-200 select-none ${className}`}
        title={t('dashboard.recentActivities.reconnecting', 'Đang kết nối lại socket...')}
      >
        <span className="material-symbols-outlined text-[13px] animate-spin text-amber-600">sync</span>
        <span>{t('dashboard.recentActivities.connecting', 'Đang kết nối...')}</span>
      </span>
    );
  }

  // disconnected
  return (
    <span
      data-testid="realtime-status-badge"
      data-status="disconnected"
      className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-rose-50 text-rose-700 font-label-md text-[11px] font-medium border border-rose-200 shadow-2xs transition-all duration-200 select-none ${className}`}
      title={t('dashboard.recentActivities.disconnectedTooltip', 'Mất kết nối thời gian thực tới máy chủ')}
    >
      <span className="relative flex h-2 w-2">
        <span className="relative inline-flex rounded-full h-2 w-2 bg-rose-500"></span>
      </span>
      <span>{t('dashboard.recentActivities.disconnected', 'Mất kết nối')}</span>
    </span>
  );
};

export default RealtimeStatusBadge;
