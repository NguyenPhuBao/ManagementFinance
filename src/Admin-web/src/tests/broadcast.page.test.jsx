import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import BroadcastPage from '../pages/system/BroadcastPage';
import adminApi from '../api/admin.api';
import notificationApi from '../api/notification.api';
import useSocket from '../hooks/useSocket';

vi.mock('../api/admin.api', () => ({
  default: {
    getMaintenanceStatus: vi.fn(),
    setMaintenanceStatus: vi.fn(),
    cancelScheduledMaintenance: vi.fn(),
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
    isEmergency: false,
    reason: '',
    activatedBy: null,
    activatedAt: null,
    scheduled: null,
  };

  beforeEach(() => {
    vi.clearAllMocks();
    useSocket.mockReturnValue(mockSocket);
    adminApi.getMaintenanceStatus.mockResolvedValue({ data: mockMaintenanceNormal });
  });

  it('6.1. Tải và hiển thị trạng thái bảo trì mặc định (Bình thường / Chưa kích hoạt)', async () => {
    render(<BroadcastPage />);

    await waitFor(() => {
      expect(adminApi.getMaintenanceStatus).toHaveBeenCalledTimes(1);
      expect(screen.getByText('Điều Hành Bảo Trì')).toBeInTheDocument();
      expect(screen.getByText('Kích Hoạt Bảo Trì Tức Thì')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Bật Bảo Trì Kỹ Thuật/i })).toBeInTheDocument();
    });
  });

  it('6.2. Kích hoạt bảo trì tức thì (Chế độ thường) gọi setMaintenanceStatus với isEmergency = false', async () => {
    adminApi.setMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: true,
        isEmergency: false,
        reason: 'Nâng cấp máy chủ cơ sở dữ liệu định kỳ...',
      },
    });

    render(<BroadcastPage />);

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /Bật Bảo Trì Kỹ Thuật/i })).toBeInTheDocument();
    });

    const reasonInput = screen.getByPlaceholderText(/Ví dụ: Nâng cấp máy chủ/i);
    fireEvent.change(reasonInput, { target: { value: 'Bảo trì tối ưu DB' } });

    const toggleBtn = screen.getByRole('button', { name: /Bật Bảo Trì Kỹ Thuật/i });
    fireEvent.click(toggleBtn);

    await waitFor(() => {
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith({
        active: true,
        reason: 'Bảo trì tối ưu DB',
        isEmergency: false,
      });
    });
  });

  it('6.3. Kích hoạt bảo trì khẩn cấp (Emergency) gọi setMaintenanceStatus với isEmergency = true', async () => {
    adminApi.setMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: true,
        isEmergency: true,
        reason: 'Sự cố rò rỉ bộ nhớ nghiêm trọng',
      },
    });

    render(<BroadcastPage />);

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /Bật Bảo Trì Kỹ Thuật/i })).toBeInTheDocument();
    });

    // Checkbox khẩn cấp
    const emergencyCheckbox = screen.getByRole('checkbox', {
      name: /Bảo trì khẩn cấp/i,
    });
    fireEvent.click(emergencyCheckbox);

    // Nút đổi thành "🚨 Bật Bảo Trì Khẩn Cấp Ngay"
    const emergencyBtn = screen.getByRole('button', { name: /Bật Bảo Trì Khẩn Cấp Ngay/i });
    fireEvent.click(emergencyBtn);

    await waitFor(() => {
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith(
        expect.objectContaining({
          active: true,
          isEmergency: true,
        })
      );
    });
  });

  it('6.4. Tắt bảo trì khi hệ thống đang ở trạng thái bảo trì', async () => {
    adminApi.getMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: true,
        isEmergency: false,
        reason: 'Bảo trì hệ thống',
        activatedBy: 'admin',
        activatedAt: '2026-03-10T10:00:00Z',
      },
    });

    adminApi.setMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: false,
        isEmergency: false,
      },
    });

    render(<BroadcastPage />);

    await waitFor(() => {
      expect(screen.getByText('Tắt Bảo Trì & Mở Lại Hệ Thống')).toBeInTheDocument();
    });

    const turnOffBtn = screen.getByRole('button', { name: /Tắt Bảo Trì & Mở Lại Hệ Thống/i });
    fireEvent.click(turnOffBtn);

    await waitFor(() => {
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith(
        expect.objectContaining({ active: false })
      );
    });
  });

  it('6.5. Chuyển sang Tab Phát Thông Báo và gửi thông điệp hệ thống tới toàn bộ người dùng', async () => {
    notificationApi.broadcastToAll.mockResolvedValueOnce({ data: { success: true } });

    render(<BroadcastPage />);

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
    render(<BroadcastPage />);

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
      expect(screen.getByText('Tắt Bảo Trì & Mở Lại Hệ Thống')).toBeInTheDocument();
      expect(screen.getByText('Kết Thúc Bảo Trì — Khôi Phục Hệ Thống')).toBeInTheDocument();
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

    render(<BroadcastPage />);

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

    render(<BroadcastPage />);

    await waitFor(() => {
      expect(screen.getByText('Chế độ bảo trì đang kích hoạt')).toBeInTheDocument();
      expect(screen.getByText(/Không thể thiết lập thêm lịch bảo trì mới để tránh xung đột thời gian/i)).toBeInTheDocument();
      expect(screen.getByText(/Kết Thúc Bảo Trì — Khôi Phục Hệ Thống/i)).toBeInTheDocument();
      // Form lên lịch không xuất hiện
      expect(screen.queryByRole('button', { name: /Lên Lịch Bảo Trì Hệ Thống/i })).not.toBeInTheDocument();
    });
  });

  it('6.9. Nút "Làm mới & Đặt lại biểu mẫu" xóa sạch toàn bộ input đang nhập và tải lại trạng thái', async () => {
    render(<BroadcastPage />);

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
    render(<BroadcastPage />);

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

    render(<BroadcastPage />);

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

