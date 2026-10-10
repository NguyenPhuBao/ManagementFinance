import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, act } from '@testing-library/react';
import SettingsModal from '../components/layout/SettingsModal';
import { SettingsProvider } from '../store/settings.context';
import soundService from '../services/sound.service';

vi.mock('../services/sound.service', () => ({
  default: {
    playCriticalAlarm: vi.fn(),
    playNotificationSound: vi.fn(),
  },
  soundService: {
    playCriticalAlarm: vi.fn(),
    playNotificationSound: vi.fn(),
  },
}));

const mockSocket = {
  connected: true,
  id: 'socket-test-12345',
  on: vi.fn(),
  off: vi.fn(),
  timeout: vi.fn().mockReturnValue({
    emit: vi.fn((event, cb) => cb(null, { pong: true })),
  }),
};

vi.mock('../hooks/useSocket', () => ({
  default: () => mockSocket,
}));

describe('Admin-web Full Settings Engine Suite — SettingsModal & 4 Domains', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
    document.documentElement.className = '';
    document.body.removeAttribute('data-density');
  });

  const renderModal = (isOpen = true, onClose = vi.fn()) => {
    return render(
      <SettingsProvider>
        <SettingsModal isOpen={isOpen} onClose={onClose} />
      </SettingsProvider>
    );
  };

  it('1. Render đầy đủ 4 Tabs: Giao diện, Cảnh báo, Socket, Bảo mật', () => {
    renderModal();

    expect(screen.getByText('Cài Đặt Hệ Thống Admin')).toBeInTheDocument();
    expect(screen.getByText('Giao Diện & Hiển Thị')).toBeInTheDocument();
    expect(screen.getByText('Cảnh Báo & Âm Thanh')).toBeInTheDocument();
    expect(screen.getByText('Thời Gian Thực & Socket')).toBeInTheDocument();
    expect(screen.getByText('Bảo Mật & Thông Tin')).toBeInTheDocument();
  });

  it('2. Tab 1 (Giao diện): Chuyển Dark Mode, Compact Table Density, và đã bỏ Theo Hệ Thống', () => {
    renderModal();

    // Xác nhận đã bỏ nút Theo Hệ Thống
    expect(screen.queryByText('Theo Hệ Thống')).not.toBeInTheDocument();
    expect(screen.getByText('Giao diện Sáng')).toBeInTheDocument();
    expect(screen.getByText('Giao diện Tối')).toBeInTheDocument();

    // Chuyển sang Dark Mode
    const darkBtn = screen.getByText('Giao diện Tối');
    fireEvent.click(darkBtn);
    expect(document.documentElement.classList.contains('dark')).toBe(true);

    // Chuyển sang Thu gọn (Compact)
    const compactBtn = screen.getByText('Thu gọn');
    fireEvent.click(compactBtn);
    expect(document.body.getAttribute('data-density')).toBe('compact');
  });

  it('3. Tab 2 (Cảnh báo & Âm thanh): Nghe thử còi báo động và đổi thời gian Toast', () => {
    renderModal();

    // Chuyển sang tab Cảnh Báo & Âm Thanh
    fireEvent.click(screen.getByText('Cảnh Báo & Âm Thanh'));

    // Bấm nút Nghe thử
    const testSoundBtn = screen.getByText('Nghe thử');
    fireEvent.click(testSoundBtn);
    expect(soundService.playCriticalAlarm).toHaveBeenCalledTimes(1);

    // Thay đổi thời gian Toast thành 7 giây
    const toastSelect = screen.getByDisplayValue(/4.5 giây/);
    fireEvent.change(toastSelect, { target: { value: '7000' } });
    expect(toastSelect.value).toBe('7000');
  });

  it('4. Tab 3 (Thời gian thực & Socket): Tự động hiển thị trạng thái kết nối và tự động đo Ping', () => {
    renderModal();

    // Chuyển sang tab Socket
    fireEvent.click(screen.getByText('Thời Gian Thực & Socket'));

    expect(screen.getByText(/Trực Tuyến/)).toBeInTheDocument();
    expect(screen.getByText(/ID: socket-t/)).toBeInTheDocument();

    // Đã tự động gọi ping khi mount tab
    expect(mockSocket.timeout).toHaveBeenCalledWith(5000);

    // Bấm nút Ping Test thủ công để re-ping
    const pingBtn = screen.getByTitle('Kiểm tra lại độ trễ phản hồi ngay lập tức');
    fireEvent.click(pingBtn);
    expect(mockSocket.timeout).toHaveBeenCalledTimes(2);
  });

  it('5. Tab 4 (Bảo mật & Thông tin): Dọn dẹp Cache an toàn và Thông tin nền tảng', () => {
    window.confirm = vi.fn().mockReturnValue(true);
    localStorage.setItem('wealthcommand_access_token', 'token-real');
    localStorage.setItem('temp_cache_data', 'to-be-deleted');

    renderModal();

    // Chuyển sang tab Bảo Mật & Thông Tin
    fireEvent.click(screen.getByText('Bảo Mật & Thông Tin'));

    expect(screen.getByText(/FinanceAdmin v2.5.0/)).toBeInTheDocument();

    // Bấm nút Xóa Cache
    const clearBtn = screen.getByText('Xóa Cache');
    fireEvent.click(clearBtn);

    expect(window.confirm).toHaveBeenCalledTimes(1);
    expect(localStorage.getItem('wealthcommand_access_token')).toBe('token-real');
    expect(localStorage.getItem('temp_cache_data')).toBeNull();
  });

  it('6. Nút Footer "Khôi phục cài đặt gốc" khôi phục toàn bộ cấu hình về mặc định', () => {
    window.confirm = vi.fn().mockReturnValue(true);
    renderModal();

    // Đổi theme sang dark trước
    fireEvent.click(screen.getByText('Giao diện Tối'));
    expect(document.documentElement.classList.contains('dark')).toBe(true);

    // Bấm nút Khôi phục cài đặt gốc ở footer
    const resetBtn = screen.getByText('Khôi phục cài đặt gốc');
    fireEvent.click(resetBtn);

    expect(window.confirm).toHaveBeenCalledTimes(1);
    // Theme đã trở về light
    expect(document.documentElement.classList.contains('dark')).toBe(false);
  });
});
