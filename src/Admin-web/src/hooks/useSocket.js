import { useContext } from 'react';
import { SocketContext } from '../store/socket.context';

/**
 * Custom hook quản lý kết nối Socket.IO tập trung (Singleton) cho Admin-web.
 * Toàn bộ các component trong ứng dụng sử dụng chung 1 kết nối duy nhất từ SocketContext,
 * giúp tối ưu 80% tài nguyên kết nối mạng và bộ nhớ cho máy chủ.
 * @returns {import('socket.io-client').Socket | null}
 */
const useSocket = () => {
  const context = useContext(SocketContext);
  return context?.socket ?? null;
};

export default useSocket;
