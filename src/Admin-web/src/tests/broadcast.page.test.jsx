import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import BroadcastPage from '../pages/system/BroadcastPage';
import { LanguageProvider } from '../store/language.context';
import adminApi from '../api/admin.api';
import notificationApi from '../api/notification.api';
import useSocket from '../hooks/useSocket';

vi.mock('../api/admin.api', () => ({
  default: {
    getMaintenanceStatus: vi.fn(),
    setMaintenanceStatus: vi.fn(),
    cancelScheduledMaintenance: vi.fn(),
    getMaintenanceHistory: vi.fn().mockResolvedValue({
      data: {
        data: [],
        pagination: { page: 1, limit: 10, total: 0, totalPages: 1 },
      },
    }),
  },
}));

vi.mock('../api/notification.api', () => ({
  default: {
    broadcastToAll: vi.fn(),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: vi.fn(),
}));

describe('Admin-web System Suite — BroadcastPage (2-Mode Maintenance & Broadcasts)', () => {
  const socketListeners = {};
  const mockSocket = {
    connected: true,
    on: vi.fn((event, cb) => {
      socketListeners[event] = cb;
    }),
    off: vi.fn((event) => {
      delete socketListeners[event];
    }),
  };

  const mockMaintenanceNormal = {
    active: false,
    isEmergency: true,
    reason: '',
    activatedBy: null,
    activatedAt: null,
    scheduled: null,
  };

  const renderComponent = () => {
    return render(
      <BrowserRouter>
        <LanguageProvider>
          <BroadcastPage />
        </LanguageProvider>
      </BrowserRouter>
    );
  };

  beforeEach(() => {
    vi.clearAllMocks();
    useSocket.mockReturnValue(mockSocket);
    adminApi.getMaintenanceStatus.mockResolvedValue({ data: mockMaintenanceNormal });
    adminApi.getMaintenanceHistory.mockResolvedValue({
      data: {
        data: [],
        pagination: { page: 1, limit: 10, total: 0, totalPages: 1 },
      },
    });
  });

  it('6.1. Tải và hiển thị trạng thái bảo trì mặc định với Nút Đỏ "Bật Bảo Trì Khẩn Cấp"', async () => {
    renderComponent();

    await waitFor(() => {
      expect(adminApi.getMaintenanceStatus).toHaveBeenCalledTimes(1);
      expect(screen.getByText('Điều Hành Bảo Trì')).toBeInTheDocument();
      expect(screen.getByText('Kích Hoạt Bảo Trì Khẩn Cấp')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Bật Bảo Trì Khẩn Cấp/i })).toBeInTheDocument();
      // Không còn checkbox khẩn cấp bị thừa
      expect(screen.queryByRole('checkbox', { name: /Bảo trì khẩn cấp/i })).not.toBeInTheDocument();
    });
  });

  it('6.2. Kích hoạt bảo trì khẩn cấp gửi isEmergency = true và cắt tải người dùng', async () => {
    adminApi.setMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: true,
        isEmergency: true,
        reason: 'Sự cố nghẽn mạng khẩn cấp',
      },
    });

    renderComponent();

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /Bật Bảo Trì Khẩn Cấp/i })).toBeInTheDocument();
    });

    const reasonInput = screen.getByPlaceholderText(/hệ thống khẩn cấp/i);
    fireEvent.change(reasonInput, { target: { value: 'Sự cố nghẽn mạng khẩn cấp' } });

    const toggleBtn = screen.getByRole('button', { name: /Bật Bảo Trì Khẩn Cấp/i });
    expect(toggleBtn.className).toContain('bg-red-600');
    fireEvent.click(toggleBtn);

    await waitFor(() => {
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith({
        active: true,
        reason: 'Sự cố nghẽn mạng khẩn cấp',
        isEmergency: true,
      });
    });
  });

  it('6.3. Tắt bảo trì khi hệ thống đang ở trạng thái bảo trì', async () => {
    adminApi.getMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: true,
        isEmergency: true,
        reason: 'Bảo trì hệ thống khẩn cấp',
        activatedBy: 'admin',
        activatedAt: '2026-03-10T10:00:00Z',
      },
    });

    adminApi.setMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: false,
        isEmergency: true,
      },
    });

    renderComponent();

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /Tắt Bảo Trì Khẩn Cấp/i })).toBeInTheDocument();
    });

    const turnOffBtn = screen.getByRole('button', { name: /Tắt Bảo Trì Khẩn Cấp/i });
    fireEvent.click(turnOffBtn);

    await waitFor(() => {
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith(
        expect.objectContaining({ active: false })
      );
    });
  });

  it('6.5. Chuyển sang Tab Phát Thông Báo và gửi thông điệp hệ thống tới toàn bộ người dùng', async () => {
    notificationApi.broadcastToAll.mockResolvedValueOnce({ data: { success: true } });

    renderComponent();

    await waitFor(() => {
      expect(screen.getByText('Phát Thông Báo')).toBeInTheDocument();
    });

    // Click chuyển tab Phát Thông Báo
    const broadcastTabBtn = screen.getByText('Phát Thông Báo');
    fireEvent.click(broadcastTabBtn);

    expect(screen.getByLabelText(/Tiêu đề thông báo/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Nội dung thông báo/i)).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText(/Tiêu đề thông báo/i), {
      target: { value: 'Cập nhật phiên bản mới 2.0' },
    });
    fireEvent.change(screen.getByLabelText(/Nội dung thông báo/i), {
      target: { value: 'Hệ thống đã nâng cấp tính năng đồng bộ và AIOps Sentinel.' },
    });

    const submitBtn = screen.getByRole('button', { name: /Phát Sóng Thông Báo/i });
    fireEvent.click(submitBtn);

    await waitFor(() => {
      expect(notificationApi.broadcastToAll).toHaveBeenCalledWith({
        title: 'Cập nhật phiên bản mới 2.0',
        message: 'Hệ thống đã nâng cấp tính năng đồng bộ và AIOps Sentinel.',
        level: 'info',
      });
      expect(screen.getByText(/Đã phát thông báo tới toàn bộ người dùng đang online/i)).toBeInTheDocument();
    });
  });

  it('6.6. Cập nhật giao diện khi nhận sự kiện Socket admin.maintenance_changed realtime', async () => {
    renderComponent();

    await waitFor(() => {
      expect(screen.getByText('Điều Hành Bảo Trì')).toBeInTheDocument();
    });

    const mHandler = socketListeners['admin.maintenance_changed'];
    expect(mHandler).toBeDefined();

    act(() => {
      mHandler({
        active: true,
        isEmergency: true,
        reason: 'Sự cố khẩn cấp từ Sentinel',
        activatedBy: 'Sentinel-AIOps',
        activatedAt: new Date().toISOString(),
      });
    });

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /Tắt Bảo Trì Khẩn Cấp/i })).toBeInTheDocument();
      expect(screen.getAllByText('Sự cố khẩn cấp từ Sentinel').length).toBeGreaterThanOrEqual(1);
    });
  });

  it('6.7. Lên lịch bảo trì với thời điểm bắt đầu và kết thúc dự kiến', async () => {
    adminApi.setMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: false,
        scheduled: {
          scheduledAt: '2026-10-20T02:00:00.000Z',
          scheduledEndAt: '2026-10-20T04:00:00.000Z',
          reason: 'Bảo trì hạ tầng định kỳ',
          isEmergency: false,
          createdBy: 'admin',
          createdAt: new Date().toISOString(),
        },
      },
    });

    renderComponent();

    await waitFor(() => {
      expect(screen.getByText('Lên Lịch Thời Điểm Bảo Trì')).toBeInTheDocument();
    });

    const startDatetimeInput = screen.getByLabelText(/Thời điểm bắt đầu/i);
    const endDatetimeInput = screen.getByLabelText(/Thời điểm kết thúc \(Dự kiến\)/i);
    const reasonInput = screen.getByLabelText(/Nội dung \/ Lý do bảo trì/i);

    fireEvent.change(startDatetimeInput, { target: { value: '2026-10-20T02:00' } });
    fireEvent.change(endDatetimeInput, { target: { value: '2026-10-20T04:00' } });
    fireEvent.change(reasonInput, { target: { value: 'Bảo trì hạ tầng định kỳ' } });

    const form = startDatetimeInput.closest('form');
    fireEvent.submit(form);

    await waitFor(() => {
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith(
        expect.objectContaining({
          reason: 'Bảo trì hạ tầng định kỳ',
          isEmergency: false,
        })
      );
    });
  });

  it('6.8. Khi hệ thống đang bảo trì trực tiếp, giao diện chặn form lên lịch và hướng dẫn kết thúc bảo trì', async () => {
    adminApi.getMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: true,
        isEmergency: false,
        reason: 'Nâng cấp máy chủ',
        activatedBy: 'admin',
        activatedAt: new Date().toISOString(),
        scheduled: null,
      },
    });

    renderComponent();

    await waitFor(() => {
      expect(screen.getByText('Chế độ bảo trì đang kích hoạt')).toBeInTheDocument();
      expect(screen.getByText(/Không thể thiết lập thêm lịch bảo trì mới để tránh xung đột thời gian/i)).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Tắt Bảo Trì Khẩn Cấp/i })).toBeInTheDocument();
      // Form lên lịch không xuất hiện
      expect(screen.queryByRole('button', { name: /Lên Lịch Bảo Trì Hệ Thống/i })).not.toBeInTheDocument();
    });
  });

  it('6.9. Nút "Làm mới & Đặt lại biểu mẫu" xóa sạch toàn bộ input đang nhập và tải lại trạng thái', async () => {
    renderComponent();

    await waitFor(() => {
      expect(screen.getByText('Lên Lịch Thời Điểm Bảo Trì')).toBeInTheDocument();
    });

    const startDatetimeInput = screen.getByLabelText(/Thời điểm bắt đầu/i);
    const endDatetimeInput = screen.getByLabelText(/Thời điểm kết thúc \(Dự kiến\)/i);
    const reasonInput = screen.getByLabelText(/Nội dung \/ Lý do bảo trì/i);
    const notifyCheckbox = screen.getByRole('checkbox', { name: /Tự động phát thông báo cho Client & Admin/i });

    // Điền dữ liệu vào form
    fireEvent.change(startDatetimeInput, { target: { value: '2026-10-25T10:00' } });
    fireEvent.change(endDatetimeInput, { target: { value: '2026-10-25T12:00' } });
    fireEvent.change(reasonInput, { target: { value: 'Nội dung đang soạn dở...' } });
    fireEvent.click(notifyCheckbox);

    expect(startDatetimeInput.value).toBe('2026-10-25T10:00');
    expect(endDatetimeInput.value).toBe('2026-10-25T12:00');
    expect(reasonInput.value).toBe('Nội dung đang soạn dở...');
    expect(notifyCheckbox.checked).toBe(true);

    // Bấm nút Làm mới & Đặt lại biểu mẫu
    const refreshBtn = screen.getByRole('button', { name: /Làm mới & Đặt lại biểu mẫu/i });
    fireEvent.click(refreshBtn);

    await waitFor(() => {
      // Xác nhận toàn bộ input đã được xóa trắng
      expect(startDatetimeInput.value).toBe('');
      expect(endDatetimeInput.value).toBe('');
      expect(reasonInput.value).toBe('');
      expect(notifyCheckbox.checked).toBe(false);
      // Xác nhận gọi lại API lấy trạng thái
      expect(adminApi.getMaintenanceStatus).toHaveBeenCalledTimes(2);
      // Xác nhận thông báo phản hồi hiển thị
      expect(screen.getByText(/Đã làm mới trạng thái và xóa trắng biểu mẫu lên lịch thành công/i)).toBeInTheDocument();
    });
  });

  it('6.10. Tuyệt đối không còn hiển thị dòng thông tin kỹ thuật /health/admin', async () => {
    renderComponent();

    await waitFor(() => {
      expect(screen.getByText('Lên Lịch Thời Điểm Bảo Trì')).toBeInTheDocument();
    });

    expect(screen.queryByText(/Cổng kiểm tra bảo trì/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/\/health\/admin/i)).not.toBeInTheDocument();
  });

  it('6.11. Lên lịch bảo trì với tùy chọn Tự động phát thông báo (isEmergency = true)', async () => {
    adminApi.setMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: false,
        scheduled: {
          scheduledAt: '2026-10-20T02:00:00.000Z',
          scheduledEndAt: null,
          reason: 'Bảo trì hệ thống diện rộng có phát thông báo',
          isEmergency: true,
          createdBy: 'admin',
          createdAt: new Date().toISOString(),
        },
      },
    });

    renderComponent();

    await waitFor(() => {
      expect(screen.getByText('Lên Lịch Thời Điểm Bảo Trì')).toBeInTheDocument();
    });

    const startDatetimeInput = screen.getByLabelText(/Thời điểm bắt đầu/i);
    const reasonInput = screen.getByLabelText(/Nội dung \/ Lý do bảo trì/i);
    const notifyCheckbox = screen.getByRole('checkbox', { name: /Tự động phát thông báo cho Client & Admin/i });

    fireEvent.change(startDatetimeInput, { target: { value: '2026-10-20T02:00' } });
    fireEvent.change(reasonInput, { target: { value: 'Bảo trì hệ thống diện rộng có phát thông báo' } });
    fireEvent.click(notifyCheckbox);

    const form = startDatetimeInput.closest('form');
    fireEvent.submit(form);

    await waitFor(() => {
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith(
        expect.objectContaining({
          reason: 'Bảo trì hệ thống diện rộng có phát thông báo',
          isEmergency: true,
        })
      );
    });
  });
});

