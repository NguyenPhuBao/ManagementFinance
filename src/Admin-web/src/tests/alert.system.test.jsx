import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, act } from '@testing-library/react';
import { AlertProvider, useAlert } from '../store/alert.context';
import AlertContainer from '../components/common/AlertToast';
import Header from '../components/layout/Header';
import notificationApi from '../api/notification.api';

// Mock notificationApi
vi.mock('../api/notification.api', () => ({
  default: {
    getAdminAlerts: vi.fn(),
    markAdminAlertAsRead: vi.fn(),
  },
}));

// Mock socket
const mockSocketListeners = {};
vi.mock('../hooks/useSocket', () => ({
  default: () => ({
    on: vi.fn((event, cb) => { mockSocketListeners[event] = cb; }),
    off: vi.fn((event) => { delete mockSocketListeners[event]; }),
  }),
}));

// Test component dùng để bắn các loại Alert
const TestAlertTrigger = () => {
  const { success, error, warning, info, clearAllAlerts } = useAlert();

  return (
    <div>
      <button onClick={() => success('Thao tác thành công rực rỡ', 'Thành Công')}>Bắn Success</button>
      <button onClick={() => error('Đã có lỗi xảy ra trong hệ thống', 'Lỗi Nghiêm Trọng')}>Bắn Error</button>
      <button onClick={() => warning('Cảnh báo tài nguyên vượt ngưỡng', 'Cảnh Báo')}>Bắn Warning</button>
      <button onClick={() => info('Thông tin bảo trì định kỳ', 'Thông Tin')}>Bắn Info</button>
      <button onClick={clearAllAlerts}>Xóa Tất Cả</button>
    </div>
  );
};

describe('Admin-web Global Alert & Toast System Suite', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('1. Bắn Alert Success và hiển thị đúng Toast nổi với icon và nội dung', () => {
    render(
      <AlertProvider>
        <AlertContainer />
        <TestAlertTrigger />
      </AlertProvider>
    );

    fireEvent.click(screen.getByText('Bắn Success'));

    const alertToast = screen.getByTestId('alert-toast-success');
    expect(alertToast).toBeInTheDocument();
    expect(screen.getByText('Thành Công')).toBeInTheDocument();
    expect(screen.getByText('Thao tác thành công rực rỡ')).toBeInTheDocument();
  });

  it('2. Bắn Alert Error, Warning, Info và hỗ trợ xếp chồng', () => {
    render(
      <AlertProvider>
        <AlertContainer />
        <TestAlertTrigger />
      </AlertProvider>
    );

    fireEvent.click(screen.getByText('Bắn Error'));
    fireEvent.click(screen.getByText('Bắn Warning'));
    fireEvent.click(screen.getByText('Bắn Info'));

    expect(screen.getByTestId('alert-toast-error')).toBeInTheDocument();
    expect(screen.getByTestId('alert-toast-warning')).toBeInTheDocument();
    expect(screen.getByTestId('alert-toast-info')).toBeInTheDocument();
  });

  it('3. Bấm nút "x" đóng Alert thủ công', () => {
    render(
      <AlertProvider>
        <AlertContainer />
        <TestAlertTrigger />
      </AlertProvider>
    );

    fireEvent.click(screen.getByText('Bắn Success'));
    expect(screen.getByTestId('alert-toast-success')).toBeInTheDocument();

    const closeBtn = screen.getByTestId('alert-close-btn');
    fireEvent.click(closeBtn);

    expect(screen.queryByTestId('alert-toast-success')).toBeNull();
  });

  it('4. Tự động đóng Alert sau khoảng thời gian duration', () => {
    render(
      <AlertProvider>
        <AlertContainer />
        <TestAlertTrigger />
      </AlertProvider>
    );

    fireEvent.click(screen.getByText('Bắn Success'));
    expect(screen.getByTestId('alert-toast-success')).toBeInTheDocument();

    // Fast-forward thời gian quá duration (4500ms)
    act(() => {
      vi.advanceTimersByTime(5000);
    });

    expect(screen.queryByTestId('alert-toast-success')).toBeNull();
  });

  it('5. Icon Chuông Thông Báo (🔔) trên Header hoạt động ổn định và giữ nguyên badge số lượng', async () => {
    vi.useRealTimers();
    notificationApi.getAdminAlerts.mockResolvedValue({
      data: {
        notifications: [
          { id: 'n-1', title: 'Cảnh báo DDoS', message: 'Tấn công lưu lượng', level: 'critical', isRead: false },
        ],
        unreadCount: 14, // Số lượng 14 như PO yêu cầu
      },
    });

    render(
      <AlertProvider>
        <AlertContainer />
        <Header onMenuToggle={vi.fn()} />
      </AlertProvider>
    );

    // Kiểm tra icon chuông và badge 14
    const bellBtn = screen.getByTitle('Thông báo hệ thống');
    expect(bellBtn).toBeInTheDocument();

    const { waitFor } = await import('@testing-library/react');
    await waitFor(() => {
      expect(screen.getByText('14')).toBeInTheDocument();
    });

    // Bấm vào chuông -> mở dropdown
    fireEvent.click(bellBtn);

    await waitFor(() => {
      expect(screen.getByText('Cảnh báo hệ thống')).toBeInTheDocument();
      expect(screen.getByText(/14 mới/i)).toBeInTheDocument();
      expect(screen.getByText('Cảnh báo DDoS')).toBeInTheDocument();
    });
  });
});
