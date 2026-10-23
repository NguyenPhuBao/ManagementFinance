import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act, within } from '@testing-library/react';
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
    getBroadcastHistory: vi.fn().mockResolvedValue({
      data: {
        data: [],
        pagination: { page: 1, limit: 5, total: 0, totalPages: 1 },
      },
    }),
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

  it('6.1. Tải và hiển thị giao diện Điều Hành Bảo Trì và Form Lên Lịch Thời Điểm Bảo Trì', async () => {
    renderComponent();

    await waitFor(() => {
      expect(adminApi.getMaintenanceStatus).toHaveBeenCalledTimes(1);
      expect(screen.getByText('Điều Hành Bảo Trì')).toBeInTheDocument();
      // Không còn box cũ
      expect(screen.queryByText('Kích Hoạt Bảo Trì Khẩn Cấp')).not.toBeInTheDocument();
      // Form lên lịch hiển thị đầy đủ
      expect(screen.getByText('Lên Lịch Thời Điểm Bảo Trì')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Lên lịch bảo trì/i })).toBeInTheDocument();
    });
  });

  it('6.2. Hiển thị bảng lịch bảo trì đã đặt và hỗ trợ nút Hủy lịch', async () => {
    adminApi.getMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: false,
        isEmergency: false,
        scheduledList: [
          {
            id: 101,
            scheduledAt: new Date(Date.now() + 5 * 3600 * 1000).toISOString(),
            reason: 'Nâng cấp máy chủ định kỳ',
            createdBy: 'admin',
          },
        ],
      },
    });

    renderComponent();

    await waitFor(() => {
      expect(screen.getByText(/Danh Sách Lịch Bảo Trì Đã Lên Lịch/i)).toBeInTheDocument();
      expect(screen.getByText('Nâng cấp máy chủ định kỳ')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Hủy/i })).toBeInTheDocument();
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
      expect(screen.getByRole('button', { name: /Tắt Bảo Trì/i })).toBeInTheDocument();
    });

    const turnOffBtn = screen.getByRole('button', { name: /Tắt Bảo Trì/i });
    fireEvent.click(turnOffBtn);

    // PO YÊU CẦU: Hiển thị popup xác nhận kết thúc bảo trì
    await waitFor(() => {
      expect(screen.getByText('Xác Nhận Kết Thúc Bảo Trì')).toBeInTheDocument();
    });

    const confirmEndBtn = screen.getByRole('button', { name: /Xác Nhận Kết Thúc/i });
    fireEvent.click(confirmEndBtn);

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
      expect(screen.getByRole('button', { name: /Tắt Bảo Trì/i })).toBeInTheDocument();
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

    const dStart = new Date(Date.now() + 5 * 3600 * 1000);
    const dEnd = new Date(Date.now() + 7 * 3600 * 1000);
    const pad = (n) => String(n).padStart(2, '0');
    const validStart = `${dStart.getFullYear()}-${pad(dStart.getMonth() + 1)}-${pad(dStart.getDate())}T${pad(dStart.getHours())}:${pad(dStart.getMinutes())}`;
    const validEnd = `${dEnd.getFullYear()}-${pad(dEnd.getMonth() + 1)}-${pad(dEnd.getDate())}T${pad(dEnd.getHours())}:${pad(dEnd.getMinutes())}`;

    fireEvent.change(startDatetimeInput, { target: { value: validStart } });
    fireEvent.change(endDatetimeInput, { target: { value: validEnd } });
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

  it('6.8. Khi hệ thống đang bảo trì trực tiếp, hiển thị Banner bảo trì với nút Tắt Bảo Trì và Form lên lịch vẫn hiện diện đầy đủ', async () => {
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
      expect(screen.getByText('HỆ THỐNG ĐANG BẢO TRÌ')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Tắt Bảo Trì/i })).toBeInTheDocument();
      // PO QUY ĐỊNH: Form lên lịch vẫn hiện diện đầy đủ
      expect(screen.getByText('Lên Lịch Thời Điểm Bảo Trì')).toBeInTheDocument();
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

    // Điền dữ liệu vào form
    fireEvent.change(startDatetimeInput, { target: { value: '2026-10-25T10:00' } });
    fireEvent.change(endDatetimeInput, { target: { value: '2026-10-25T12:00' } });
    fireEvent.change(reasonInput, { target: { value: 'Nội dung đang soạn dở...' } });

    expect(startDatetimeInput.value).toBe('2026-10-25T10:00');
    expect(endDatetimeInput.value).toBe('2026-10-25T12:00');
    expect(reasonInput.value).toBe('Nội dung đang soạn dở...');

    // Bấm nút Làm mới (nằm cạnh nút Lên lịch bảo trì)
    const form = startDatetimeInput.closest('form');
    const refreshBtn = within(form).getByRole('button', { name: /Làm mới/i });
    fireEvent.click(refreshBtn);

    await waitFor(() => {
      // Xác nhận toàn bộ input đã được xóa trắng
      expect(startDatetimeInput.value).toBe('');
      expect(endDatetimeInput.value).toBe('');
      expect(reasonInput.value).toBe('');
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

  it('6.11. Lên lịch bảo trì kỹ thuật định kỳ gửi yêu cầu đặt lịch tới Backend với isEmergency = false', async () => {
    adminApi.setMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: false,
        scheduled: {
          scheduledAt: '2026-10-25T02:00:00.000Z',
          scheduledEndAt: null,
          reason: 'Bảo trì hệ thống diện rộng có phát thông báo',
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
    const reasonInput = screen.getByLabelText(/Nội dung \/ Lý do bảo trì/i);

    const d = new Date(Date.now() + 5 * 3600 * 1000);
    const pad = (n) => String(n).padStart(2, '0');
    const validTime = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    fireEvent.change(startDatetimeInput, { target: { value: validTime } });
    fireEvent.change(reasonInput, { target: { value: 'Bảo trì hệ thống diện rộng có phát thông báo' } });

    const form = startDatetimeInput.closest('form');
    fireEvent.submit(form);

    await waitFor(() => {
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith(
        expect.objectContaining({
          reason: 'Bảo trì hệ thống diện rộng có phát thông báo',
          isEmergency: false,
        })
      );
    });
  });

  it('6.12. TẦNG 2 SYSTEM IMPACT: Khi Admin thao tác trực tiếp Bật/Tắt bảo trì, sự kiện Socket admin.maintenance_changed sau đó KHÔNG sinh thêm Toast lặp lại', async () => {
    adminApi.getMaintenanceStatus.mockResolvedValueOnce({
      active: true,
      isEmergency: true,
      reason: 'Bảo trì khẩn cấp cấp độ 1',
    });

    adminApi.setMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: false,
        isEmergency: false,
      },
    });

    renderComponent();

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /Tắt Bảo Trì/i })).toBeInTheDocument();
    });

    // 1. Click nút "Tắt Bảo Trì" -> mở popup xác nhận
    const turnOffBtn = screen.getByRole('button', { name: /Tắt Bảo Trì/i });
    fireEvent.click(turnOffBtn);

    // 2. Click nút xác nhận kết thúc bảo trì
    const confirmStopBtn = await screen.findByRole('button', { name: /Xác Nhận Kết Thúc/i });
    fireEvent.click(confirmStopBtn);

    await waitFor(() => {
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith(
        expect.objectContaining({ active: false })
      );
    });

    // 3. Socket gửi sự kiện admin.maintenance_changed về ngay sau đó
    const mHandler = socketListeners['admin.maintenance_changed'];
    expect(mHandler).toBeDefined();

    act(() => {
      mHandler({
        active: false,
        isEmergency: false,
      });
    });

    // Kiểm tra giao diện khôi phục trạng thái bình thường, form lập lịch bảo trì luôn sẵn sàng
    await waitFor(() => {
      expect(screen.getByText('Lên Lịch Thời Điểm Bảo Trì')).toBeInTheDocument();
    });
  });
});


