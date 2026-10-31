import React, { createContext, useContext, useState, useEffect, useRef } from 'react';
import { io } from 'socket.io-client';
import { STORAGE_KEYS } from '../utils/constants';
import { useAuthContext } from './auth.context';

const defaultSocketUrl =
  import.meta.env.VITE_SOCKET_URL ||
  (typeof window !== 'undefined' && window.location.hostname === 'localhost'
    ? 'http://localhost:3000'
    : 'https://managementfinance.onrender.com');

export const SocketContext = createContext({
  socket: null,
  connected: false,
  socketId: null,
});

export const SocketProvider = ({ children, serverUrl = defaultSocketUrl, options = {} }) => {
  const [socket, setSocket] = useState(null);
  const [connected, setConnected] = useState(false);
  const [socketId, setSocketId] = useState(null);
  const socketRef = useRef(null);

  // Lấy trạng thái đăng nhập từ AuthContext (nếu có)
  let authContext = null;
  try {
    authContext = useAuthContext();
  } catch (_) {
    // Dự phòng khi chạy trong môi trường test không có AuthProvider
  }
  const tokenInStorage = typeof window !== 'undefined' ? localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN) : null;
  const isAuthenticated = Boolean(authContext?.isAuthenticated || tokenInStorage);

  useEffect(() => {
    const token = typeof window !== 'undefined' ? localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN) : null;

    // Nếu không có token và không xác thực, dọn dẹp socket cũ nếu có
    if (!token && !isAuthenticated) {
      if (socketRef.current) {
        socketRef.current.disconnect();
        socketRef.current = null;
        setSocket(null);
        setConnected(false);
        setSocketId(null);
      }
      return;
    }

    // Nếu socket hiện tại đã tồn tại và token khớp, không cần tái tạo socket instance
    if (socketRef.current && socketRef.current.auth?.token === token) {
      return;
    }

    const targetUrl = serverUrl || (typeof window !== 'undefined' && window.location.hostname === 'localhost'
      ? 'http://localhost:3000'
      : 'https://managementfinance.onrender.com');

    // Khởi tạo DUY NHẤT một instance socket client cho toàn bộ ứng dụng Admin-web
    // Sử dụng transports: ['polling', 'websocket'] (chuẩn Socket.IO): kết nối tức thì qua HTTP polling (<50ms) rồi nâng cấp mượt mà lên WebSocket mà không bị treo khi cold start / Cloudflare proxy
    const client = io(targetUrl, {
      path: '/socket.io',
      transports: ['polling', 'websocket'],
      autoConnect: true,
      reconnection: true,
      reconnectionAttempts: 10,
      reconnectionDelay: 2000,
      timeout: 10000,
      auth: { token },
      ...options,
    });

    socketRef.current = client;
    setSocket(client);

    client.on('connect', () => {
      setConnected(true);
      setSocketId(client.id);
      console.log('[Socket] Singleton kết nối thành công:', client.id);
    });

    client.on('reconnect_attempt', () => {
      const freshToken = localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);
      if (freshToken) {
        client.auth.token = freshToken;
      }
    });

    client.on('joined_admin_room', (data) => {
      console.log('[Socket] Singleton đã gia nhập admin_room:', data);
    });

    client.on('disconnect', (reason) => {
      setConnected(false);
      console.log('[Socket] Singleton ngắt kết nối:', reason);
    });

    client.on('connect_error', (error) => {
      console.warn('[Socket] Lỗi kết nối Socket.io Singleton:', error.message);
      if (error.message && error.message.includes('Authentication error')) {
        const freshToken = localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);
        if (freshToken && client.auth?.token !== freshToken) {
          client.auth.token = freshToken;
          setTimeout(() => client.connect(), 2000);
        }
      }
    });

    return () => {
      client.disconnect();
      socketRef.current = null;
      setSocket(null);
      setConnected(false);
      setSocketId(null);
    };
  }, [serverUrl, isAuthenticated]);

  return (
    <SocketContext.Provider value={{ socket, connected, socketId }}>
      {children}
    </SocketContext.Provider>
  );
};

export const useSocketContext = () => useContext(SocketContext);

export default SocketContext;
