import { useEffect, useState } from 'react';
import { io } from 'socket.io-client';
import { STORAGE_KEYS } from '../utils/constants';

const defaultSocketUrl =
  import.meta.env.VITE_SOCKET_URL ||
  (typeof window !== 'undefined' && window.location.hostname === 'localhost'
    ? 'http://localhost:3000'
    : 'https://managementfinance.onrender.com');

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
    const targetUrl = serverUrl || (typeof window !== 'undefined' && window.location.hostname === 'localhost'
      ? 'http://localhost:3000'
      : 'https://managementfinance.onrender.com');

    const client = io(targetUrl, {
      path: '/socket.io',
      transports: ['websocket', 'polling'],
      autoConnect: true,
      reconnection: true,
      reconnectionAttempts: 10,
      reconnectionDelay: 2000,
      timeout: 10000,
      auth: { token },
      ...options,
    });

    client.on('connect', () => {
      console.log('[Socket] Kết nối thành công:', client.id);
    });

    client.on('reconnect_attempt', () => {
      // Cập nhật token mới nhất nếu có refresh
      const freshToken = localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);
      if (freshToken) {
        client.auth.token = freshToken;
      }
    });

    client.on('joined_admin_room', (data) => {
      console.log('[Socket] Đã xác thực đặc quyền Admin trong room admin_room:', data);
    });

    client.on('disconnect', (reason) => {
      console.log('[Socket] Mất kết nối:', reason);
    });

    client.on('connect_error', (error) => {
      console.warn('[Socket] Lỗi kết nối Socket.io:', error.message);
      // Nếu lỗi xác thực, thử cập nhật token mới nhất từ localStorage và thử lại
      if (error.message && error.message.includes('Authentication error')) {
        const freshToken = localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);
        if (freshToken && client.auth?.token !== freshToken) {
          client.auth.token = freshToken;
          setTimeout(() => client.connect(), 2000);
        }
      }
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
