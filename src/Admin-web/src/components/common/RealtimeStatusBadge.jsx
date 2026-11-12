import React, { useState, useEffect } from 'react';
import { useSocketContext } from '../../store/socket.context';
import { useLanguageSafe } from '../../store/language.context';

const initialStatus = (propConnected, socket, contextConnected) => {
  if (propConnected !== undefined) return propConnected ? 'connected' : 'disconnected';
  if (socket) return socket.connected || contextConnected ? 'connected' : 'connecting';
  return contextConnected ? 'connected' : 'disconnected';
};

const STYLES = {
  connected: { dot: 'bg-success', text: 'text-ink-muted' },
  connecting: { dot: 'bg-warning animate-pulse', text: 'text-warning' },
  disconnected: { dot: 'bg-danger', text: 'text-danger' },
};

const RealtimeStatusBadge = ({ connected: propConnected, className = '' }) => {
  const { socket, connected: contextConnected } = useSocketContext();
  const { t } = useLanguageSafe();
  const [status, setStatus] = useState(() => initialStatus(propConnected, socket, contextConnected));

  useEffect(() => {
    if (propConnected !== undefined) {
      setStatus(propConnected ? 'connected' : 'disconnected');
      return undefined;
    }
    if (!socket) {
      setStatus(contextConnected ? 'connected' : 'disconnected');
      return undefined;
    }
    setStatus(socket.connected || contextConnected ? 'connected' : 'connecting');

    const events = {
      connect: () => setStatus('connected'),
      disconnect: () => setStatus('disconnected'),
      connect_error: () => setStatus('disconnected'),
      reconnect_attempt: () => setStatus('connecting'),
      reconnect_failed: () => setStatus('disconnected'),
      error: () => setStatus('disconnected'),
    };
    Object.entries(events).forEach(([name, fn]) => socket.on(name, fn));
    return () => Object.entries(events).forEach(([name, fn]) => socket.off(name, fn));
  }, [socket, propConnected, contextConnected]);

  useEffect(() => {
    if (status !== 'connecting') return undefined;
    const timer = setTimeout(() => {
      if (!socket?.connected) setStatus('disconnected');
    }, 8000);
    return () => clearTimeout(timer);
  }, [status, socket]);

  const hint = status === 'connected' ? t('realtime.connectedHint') : status === 'disconnected' ? t('realtime.disconnectedHint') : undefined;

  return (
    <span
      data-testid="realtime-status-badge"
      data-status={status}
      title={hint}
      className={`inline-flex select-none items-center gap-1.5 text-xs font-medium ${STYLES[status].text} ${className}`}
    >
      <span aria-hidden="true" className={`h-2 w-2 rounded-full ${STYLES[status].dot}`} />
      {t(`realtime.${status}`)}
    </span>
  );
};

export default RealtimeStatusBadge;
