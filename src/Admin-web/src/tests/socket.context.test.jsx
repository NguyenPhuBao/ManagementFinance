import React, { useEffect, useState } from 'react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, act } from '@testing-library/react';
import { SocketProvider, useSocketContext } from '../store/socket.context';
import useSocket from '../hooks/useSocket';
import { STORAGE_KEYS } from '../utils/constants';

// Mock socket.io-client
let mockSockets = [];
vi.mock('socket.io-client', () => ({
  io: vi.fn((url, options) => {
    const listeners = {};
    const mockClient = {
      id: 'mock-socket-' + (mockSockets.length + 1),
      auth: options?.auth || {},
      connected: false,
      on: vi.fn((event, callback) => {
        listeners[event] = listeners[event] || [];
        listeners[event].push(callback);
      }),
      off: vi.fn((event, callback) => {
        if (!listeners[event]) return;
        listeners[event] = listeners[event].filter(cb => cb !== callback);
      }),
      emit: vi.fn(),
      connect: vi.fn(() => {
        mockClient.connected = true;
        if (listeners['connect']) {
          listeners['connect'].forEach(cb => cb());
        }
      }),
      disconnect: vi.fn(() => {
        mockClient.connected = false;
        if (listeners['disconnect']) {
          listeners['disconnect'].forEach(cb => cb('client_disconnect'));
        }
      }),
      _trigger: (event, data) => {
        if (listeners[event]) {
          listeners[event].forEach(cb => cb(data));
        }
      },
    };
    mockSockets.push(mockClient);
    return mockClient;
  }),
}));

// Test Component A (đại diện Header)
const HeaderComponent = ({ onSocketObtained }) => {
  const socket = useSocket();
  useEffect(() => {
    if (socket && onSocketObtained) onSocketObtained(socket);
  }, [socket, onSocketObtained]);
  return <div data-testid="header-socket">{socket ? socket.id : 'no-socket'}</div>;
};

// Test Component B (đại diện ServerHealthPanel)
const HealthPanelComponent = ({ onSocketObtained }) => {
  const socket = useSocket();
  const { connected } = useSocketContext();
  useEffect(() => {
    if (socket && onSocketObtained) onSocketObtained(socket);
  }, [socket, onSocketObtained]);
  return (
    <div>
      <div data-testid="health-socket">{socket ? socket.id : 'no-socket'}</div>
      <div data-testid="connection-status">{connected ? 'connected' : 'disconnected'}</div>
    </div>
  );
};

describe('Admin-web SocketContext & Singleton Architecture (2-Tier Testing)', () => {
  beforeEach(() => {
    localStorage.clear();
    mockSockets = [];
    vi.clearAllMocks();
  });

  afterEach(() => {
    localStorage.clear();
  });

  // ========================================================
  // 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & TIÊU THỤ HOOK TẠI GIAO DIỆN
  // ========================================================
  describe('🧱 TẦNG 1: UI Rendering & Hook Consumption', () => {
    it('1.1. Không kết nối socket khi chưa có token đăng nhập trong LocalStorage', () => {
      render(
        <SocketProvider>
          <HeaderComponent />
          <HealthPanelComponent />
        </SocketProvider>
      );

      expect(screen.getByTestId('header-socket').textContent).toBe('no-socket');
      expect(screen.getByTestId('health-socket').textContent).toBe('no-socket');
      expect(screen.getByTestId('connection-status').textContent).toBe('disconnected');
      expect(mockSockets.length).toBe(0);
    });

    it('1.2. Tự động kết nối socket và hiển thị ID khi có token đăng nhập hợp lệ', () => {
      localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'mock-jwt-admin-token');

      render(
        <SocketProvider>
          <HeaderComponent />
          <HealthPanelComponent />
        </SocketProvider>
      );

      expect(mockSockets.length).toBe(1);
      expect(screen.getByTestId('header-socket').textContent).toBe('mock-socket-1');
      expect(screen.getByTestId('health-socket').textContent).toBe('mock-socket-1');
    });

    it('1.3. Cập nhật trạng thái connected khi socket kích hoạt sự kiện connect', () => {
      localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'mock-jwt-admin-token');

      render(
        <SocketProvider>
          <HealthPanelComponent />
        </SocketProvider>
      );

      const client = mockSockets[0];
      act(() => {
        client._trigger('connect');
      });

      expect(screen.getByTestId('connection-status').textContent).toBe('connected');

      act(() => {
        client._trigger('disconnect', 'server_closed');
      });

      expect(screen.getByTestId('connection-status').textContent).toBe('disconnected');
    });
  });

  // ========================================================
  // ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG & TÍNH CHẤT SINGLETON
  // ========================================================
  describe('⚡ TẦNG 2: System Impact & Singleton Verification', () => {
    it('2.1. ĐẢM BẢO TÍNH CHẤT SINGLETON: Nhiều component cùng gọi useSocket() chỉ mở DUY NHẤT 1 kết nối Socket.IO', () => {
      localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'mock-admin-token-123');

      let socketA = null;
      let socketB = null;

      render(
        <SocketProvider>
          <HeaderComponent onSocketObtained={(s) => { socketA = s; }} />
          <HealthPanelComponent onSocketObtained={(s) => { socketB = s; }} />
        </SocketProvider>
      );

      // TÁC ĐỘNG HỆ THỐNG 1: Chỉ tạo duy nhất 1 socket instance cho toàn bộ ứng dụng
      expect(mockSockets.length).toBe(1);

      // TÁC ĐỘNG HỆ THỐNG 2: Socket instance của Header và HealthPanel là TRÙNG KHỚP 100% (cùng con trỏ bộ nhớ)
      expect(socketA).not.toBeNull();
      expect(socketB).not.toBeNull();
      expect(socketA).toBe(socketB);
      expect(socketA.id).toBe(socketB.id);
    });

    it('2.2. TÁC ĐỘNG BẢO MẬT: Ngắt kết nối socket khi unmount Provider để triệt tiêu rò rỉ kết nối', () => {
      localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'mock-admin-token-123');

      const { unmount } = render(
        <SocketProvider>
          <HeaderComponent />
        </SocketProvider>
      );

      expect(mockSockets.length).toBe(1);
      const activeSocket = mockSockets[0];

      // Khi unmount ứng dụng (hoặc đăng xuất)
      unmount();

      // Tác động hệ thống: Phương thức disconnect() của Socket.io client BẮT BUỘC phải được gọi
      expect(activeSocket.disconnect).toHaveBeenCalled();
    });

    it('2.3. BẢO TOÀN SỰ KIỆN: Khi Server gửi sự kiện, các component đăng ký trên singleton đều nhận được dữ liệu', () => {
      localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'mock-admin-token-123');

      let receivedEventData = null;

      const ListenerComponent = () => {
        const socket = useSocket();
        useEffect(() => {
          if (!socket) return;
          const onOrderCreated = (data) => {
            receivedEventData = data;
          };
          socket.on('payment.order_created', onOrderCreated);
          return () => socket.off('payment.order_created', onOrderCreated);
        }, [socket]);
        return <div>Listening</div>;
      };

      render(
        <SocketProvider>
          <ListenerComponent />
        </SocketProvider>
      );

      const socketInstance = mockSockets[0];
      const payload = { orderCode: 8888, amount: 49000, packageType: 'PREMIUM_1_MONTH' };

      // Kích hoạt sự kiện từ Server
      act(() => {
        socketInstance._trigger('payment.order_created', payload);
      });

      // Tác động: Listener nhận chính xác payload từ luồng duy nhất
      expect(receivedEventData).toEqual(payload);
    });
  });
});
