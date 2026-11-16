import React from 'react';
import { render, screen, act, waitFor } from '@testing-library/react';
import axios from 'axios';
import { io } from 'socket.io-client';
import { SocketProvider } from '../store/socket.context';
import RealtimeStatusBadge from '../components/common/RealtimeStatusBadge';
import { refreshAccessToken } from '../api/axios-client';
import { STORAGE_KEYS } from '../utils/constants';

/** Bộ phát sự kiện tối giản: socket và bộ quản lý kết nối (client.io) phát sự kiện riêng như socket.io v4. */
const emitter = () => {
  const handlers = {};
  return {
    on: vi.fn((name, fn) => {
      (handlers[name] = handlers[name] || new Set()).add(fn);
    }),
    off: vi.fn((name, fn) => handlers[name]?.delete(fn)),
    emit: (name, ...args) => act(() => (handlers[name] || []).forEach((fn) => fn(...args))),
  };
};

let client;
vi.mock('socket.io-client', () => ({ io: vi.fn() }));
vi.mock('../api/axios-client', async (importOriginal) => {
  const real = await importOriginal();
  return { ...real, refreshAccessToken: vi.fn(real.refreshAccessToken) };
});

const options = () => io.mock.calls.at(-1)[1];
const tokenSent = () => new Promise((resolve) => options().auth(({ token }) => resolve(token)));

beforeEach(() => {
  localStorage.clear();
  localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'token-cu');
  localStorage.setItem(STORAGE_KEYS.REFRESH_TOKEN, 'refresh-1');
  client = { ...emitter(), connected: false, active: true, connect: vi.fn(), disconnect: vi.fn(), io: emitter() };
  io.mockReset().mockImplementation(() => client);
  refreshAccessToken.mockReset().mockResolvedValue('token-moi');
});

const renderProvider = () =>
  render(
    <SocketProvider serverUrl="http://socket.test">
      <RealtimeStatusBadge />
    </SocketProvider>
  );

describe('Kết nối thời gian thực của Admin-web', () => {
  it('mỗi lần (kết nối lại) socket lấy token mới nhất trong trình duyệt, không giữ token lúc mở trang', async () => {
    renderProvider();
    expect(typeof options().auth).toBe('function');
    expect(await tokenSent()).toBe('token-cu');
    localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'token-moi');
    expect(await tokenSent()).toBe('token-moi');
  });

  it('không giới hạn số lần thử kết nối lại (máy chủ khởi động lại lâu vẫn tự nối lại)', () => {
    renderProvider();
    expect([undefined, Infinity]).toContain(options().reconnectionAttempts);
  });

  it('máy chủ từ chối vì token hết hạn: làm mới token một lần rồi kết nối lại', async () => {
    renderProvider();
    await tokenSent();
    client.emit('connect_error', new Error('Authentication error: Token expired'));
    await waitFor(() => expect(client.connect).toHaveBeenCalledTimes(1));
    expect(refreshAccessToken).toHaveBeenCalledTimes(1);
    // Vẫn bị từ chối ngay sau khi làm mới ⇒ không lặp vòng làm mới
    client.emit('connect_error', new Error('Authentication error: Token expired'));
    await new Promise((r) => setTimeout(r, 20));
    expect(refreshAccessToken).toHaveBeenCalledTimes(1);
    // Kết nối thành công thì lần hết hạn sau được làm mới tiếp
    client.connected = true;
    client.emit('connect');
    client.connected = false;
    client.emit('connect_error', new Error('Authentication error: Token expired'));
    await waitFor(() => expect(refreshAccessToken).toHaveBeenCalledTimes(2));
  });

  it('làm mới token thất bại: không kết nối lại, không ném lỗi', async () => {
    refreshAccessToken.mockRejectedValue(new Error('refresh failed'));
    renderProvider();
    await tokenSent();
    client.emit('connect_error', new Error('Authentication error: Token expired'));
    await waitFor(() => expect(refreshAccessToken).toHaveBeenCalledTimes(1));
    await new Promise((r) => setTimeout(r, 20));
    expect(client.connect).not.toHaveBeenCalled();
  });

  it('màn hình đang khoá: không tự làm mới token cho socket', async () => {
    localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
    renderProvider();
    await tokenSent();
    client.emit('connect_error', new Error('Authentication error: Token expired'));
    await new Promise((r) => setTimeout(r, 20));
    expect(refreshAccessToken).not.toHaveBeenCalled();
    expect(client.connect).not.toHaveBeenCalled();
  });

  it('trình duyệt báo có mạng trở lại hoặc quay lại tab: kết nối lại ngay nếu đang mất kết nối', () => {
    renderProvider();
    act(() => window.dispatchEvent(new Event('online')));
    expect(client.connect).toHaveBeenCalledTimes(1);
    act(() => document.dispatchEvent(new Event('visibilitychange')));
    expect(client.connect).toHaveBeenCalledTimes(2);
    client.connected = true;
    act(() => window.dispatchEvent(new Event('online')));
    expect(client.connect).toHaveBeenCalledTimes(2);
  });

  it('huy hiệu nghe sự kiện thử lại trên bộ quản lý kết nối: Đang kết nối → Mất kết nối khi bỏ cuộc', () => {
    renderProvider();
    const badge = screen.getByTestId('realtime-status-badge');
    client.emit('disconnect', 'transport close');
    expect(badge).toHaveAttribute('data-status', 'disconnected');
    client.io.emit('reconnect_attempt', 1);
    expect(badge).toHaveAttribute('data-status', 'connecting');
    client.io.emit('reconnect_failed');
    expect(badge).toHaveAttribute('data-status', 'disconnected');
  });
});

describe('refreshAccessToken dùng chung cho API và socket', () => {
  it('gọi đồng thời chỉ làm mới một lần, lưu token mới vào trình duyệt', async () => {
    const { refreshAccessToken: realRefresh } = await vi.importActual('../api/axios-client');
    const post = vi.spyOn(axios, 'post').mockResolvedValue({ data: { data: { accessToken: 'a2', refreshToken: 'r2' } } });
    try {
      const [t1, t2] = await Promise.all([realRefresh(), realRefresh()]);
      expect(t1).toBe('a2');
      expect(t2).toBe('a2');
      expect(post).toHaveBeenCalledTimes(1);
      expect(post.mock.calls[0][1]).toEqual({ refreshToken: 'refresh-1' });
      expect(localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN)).toBe('a2');
      expect(localStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN)).toBe('r2');
    } finally {
      post.mockRestore();
    }
  });
});
