import React, { createContext, useContext, useState, useEffect, useRef } from 'react';
import { io } from 'socket.io-client';
import { STORAGE_KEYS } from '../utils/constants';
import { useAuthContext } from './auth.context';
import { refreshAccessToken } from '../api/axios-client';

const defaultSocketUrl =
  import.meta.env.VITE_SOCKET_URL || 'https://managementfinance.onrender.com';

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

    if (socketRef.current) return;

    const targetUrl = serverUrl || (typeof window !== 'undefined' && window.location.hostname === 'localhost'
      ? 'http://localhost:3000'
      : 'https://managementfinance.onrender.com');

    // Token gửi ở lần bắt tay gần nhất. `auth` là hàm: socket.io gọi lại mỗi lần (kết nối lại),
    // nên luôn lấy token mới nhất trong trình duyệt thay vì giữ token lúc mở trang (token admin chỉ sống 15 phút).
    let lastToken = null;
    // Đã làm mới token vì bị từ chối mà chưa kết nối lại được ⇒ không làm mới lặp vòng
    let refreshedSinceConnect = false;

    // Khởi tạo DUY NHẤT một instance socket client cho toàn bộ ứng dụng Admin-web.
    // Không đặt reconnectionAttempts: mặc định thử mãi (chờ tăng dần tới reconnectionDelayMax), máy chủ khởi động lại lâu vẫn tự nối lại.
    const client = io(targetUrl, {
      path: '/socket.io',
      transports: ['polling', 'websocket'],
      autoConnect: true,
      reconnection: true,
      reconnectionDelay: 2000,
      reconnectionDelayMax: 10000,
      timeout: 10000,
      auth: (cb) => {
        lastToken = localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);
        cb({ token: lastToken });
      },
      ...options,
    });

    socketRef.current = client;
    setSocket(client);

    client.on('connect', () => {
      refreshedSinceConnect = false;
      setConnected(true);
      setSocketId(client.id);
      console.log('[Socket] Singleton kết nối thành công:', client.id);
    });

    client.on('joined_admin_room', (data) => {
      console.log('[Socket] Singleton đã gia nhập admin_room:', data);
    });

    client.on('disconnect', (reason) => {
      setConnected(false);
      console.log('[Socket] Singleton ngắt kết nối:', reason);
    });

    // Máy chủ từ chối ở bước bắt tay thì socket.io KHÔNG tự thử lại: phải gọi connect() bằng token hợp lệ.
    client.on('connect_error', (error) => {
      console.warn('[Socket] Lỗi kết nối Socket.io Singleton:', error.message);
      const message = error?.message || '';
      if (!message.includes('Authentication error')) return;
      const freshToken = localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);
      if (freshToken && freshToken !== lastToken) {
        client.connect(); // API vừa làm mới token
        return;
      }
      const locked = localStorage.getItem(STORAGE_KEYS.IS_LOCKED) === 'true';
      if (!message.includes('Token expired') || locked || refreshedSinceConnect) return;
      refreshedSinceConnect = true;
      refreshAccessToken()
        .then(() => client.connect())
        .catch((err) => console.warn('[Socket] Không làm mới được token:', err?.message));
    });

    // Có mạng trở lại / quay lại tab: nối lại ngay thay vì chờ hết khoảng chờ thử lại
    const reconnectNow = () => {
      if (!client.connected && document.visibilityState !== 'hidden') client.connect();
    };
    window.addEventListener('online', reconnectNow);
    document.addEventListener('visibilitychange', reconnectNow);

    return () => {
      window.removeEventListener('online', reconnectNow);
      document.removeEventListener('visibilitychange', reconnectNow);
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
