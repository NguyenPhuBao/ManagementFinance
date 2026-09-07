import { useEffect, useRef } from 'react';
import { io } from 'socket.io-client';
import { STORAGE_KEYS } from '../utils/constants';

const useSocket = (namespace = '/') => {
  const socketRef = useRef(null);

  useEffect(() => {
    const token = localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);
    const socket = io(namespace, {
      transports: ['websocket', 'polling'],
      autoConnect: true,
      auth: { token },
    });

    socket.on('connect', () => {
      console.log('[Socket] Connected:', socket.id);
    });

    socket.on('disconnect', (reason) => {
      console.log('[Socket] Disconnected:', reason);
    });

    socket.on('error', (error) => {
      console.error('[Socket] Error:', error);
    });

    socketRef.current = socket;

    return () => {
      socket.disconnect();
    };
  }, [namespace]);

  return socketRef.current;
};

export default useSocket;

