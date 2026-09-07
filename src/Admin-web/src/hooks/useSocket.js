import { useEffect, useState } from 'react';
import { io } from 'socket.io-client';
import { STORAGE_KEYS } from '../utils/constants';

const defaultSocketUrl =
  import.meta.env.VITE_SOCKET_URL ||
  (typeof window !== 'undefined' && window.location.hostname === 'localhost'
    ? 'http://localhost:3000'
    : '');

/**
 * Custom hook quản lý kết nối Socket.IO tập trung cho Admin-web
 * @param {string} [serverUrl] URL của socket server
 * @param {object} [options] Các tùy chọn socket.io
 * @returns {import('socket.io-client').Socket | null}
 */
const useSocket = (serverUrl = defaultSocketUrl, options = {}) => {
  const [socket, setSocket] = useState(null);

  useEffect(() => {
    const token = localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);
    const client = io(serverUrl || '/', {
      path: '/socket.io',
      transports: ['websocket', 'polling'],
      autoConnect: true,
      reconnectionAttempts: 5,
      auth: { token },
      ...options,
    });

    client.on('connect', () => {
      console.log('[Socket] Connected:', client.id);
    });

    client.on('disconnect', (reason) => {
      console.log('[Socket] Disconnected:', reason);
    });

    client.on('connect_error', (error) => {
      console.error('[Socket] Connection Error:', error);
    });

    setSocket(client);

    return () => {
      client.disconnect();
      setSocket(null);
    };
  }, [serverUrl]);

  return socket;
};

export default useSocket;
