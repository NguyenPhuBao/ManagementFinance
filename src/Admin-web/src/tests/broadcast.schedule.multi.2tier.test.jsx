import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import BroadcastPage from '../pages/system/BroadcastPage';
import adminApi from '../api/admin.api';
import notificationApi from '../api/notification.api';
import { LanguageProvider } from '../store/language.context';
import { AlertProvider } from '../store/alert.context';

vi.mock('../api/admin.api', () => ({
  default: {
    getMaintenanceStatus: vi.fn(),
    setMaintenanceStatus: vi.fn(),
    cancelScheduledMaintenance: vi.fn(),
    getMaintenanceHistory: vi.fn(),
  },
}));

vi.mock('../api/notification.api', () => ({
  default: {
    getBroadcastHistory: vi.fn(),
    broadcastToAll: vi.fn(),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: vi.fn(() => ({
    on: vi.fn(),
    off: vi.fn(),
    emit: vi.fn(),
  })),
}));

const renderWithProviders = (ui, initialLang = 'vi') => {
  localStorage.setItem('admin_language', initialLang);
  return render(
    <LanguageProvider key={initialLang}>
      <AlertProvider>
        {ui}
      </AlertProvider>
    </LanguageProvider>
  );
};

const toLocalInputString = (date) => {
  const d = new Date(date);
  const pad = (n) => String(n).padStart(2, '0');
  const year = d.getFullYear();
  const month = pad(d.getMonth() + 1);
  const day = pad(d.getDate());
  const hours = pad(d.getHours());
  const minutes = pad(d.getMinutes());
  return `${year}-${month}-${day}T${hours}:${minutes}`;
};

describe('BroadcastPage & Maintenance Schedule Refinements (2-Tier Architecture)', () => {
  const now = Date.now();

  beforeEach(() => {
    vi.clearAllMocks();
    window.confirm = vi.fn(() => true);
    adminApi.getMaintenanceHistory.mockResolvedValue({ data: { data: [], pagination: { total: 0 } } });
    notificationApi.getBroadcastHistory.mockResolvedValue({ data: { data: [], pagination: { total: 0 } } });
  });

  // =========================================================================
  // 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN (UI RENDERING & INTERACTION)
  // =========================================================================
  describe('🧱 TẦNG 1: UI Rendering & Visual Hierarchy', () => {
    it('1.1. Banner: Khi bảo trì theo lịch (isEmergency: false) -> Tiêu đề HỆ THỐNG ĐANG BẢO TRÌ, badge [THEO LỊCH]', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: true,
        isEmergency: false,
        reason: 'Nâng cấp kỹ thuật máy chủ theo lịch',
        activatedBy: 'admin-lead',
        activatedAt: new Date(now - 300000).toISOString(),
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        const banner = document.getElementById('banner-active-maintenance');
        expect(banner).toBeInTheDocument();
        expect(banner).toHaveTextContent('HỆ THỐNG ĐANG BẢO TRÌ');
        expect(banner).not.toHaveTextContent(/BẢO TRÌ KHẨN CẤP/i);
        expect(banner).toHaveTextContent('Theo lịch');
      });
    });

    it('1.2. Banner: Khi bảo trì khẩn cấp (isEmergency: true) -> Tiêu đề HỆ THỐNG ĐANG BẢO TRÌ KHẨN CẤP, badge [KHẨN CẤP]', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: true,
        isEmergency: true,
        reason: 'Sự cố máy chủ nghiêm trọng',
        activatedBy: 'admin-root',
        activatedAt: new Date(now - 100000).toISOString(),
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        const banner = document.getElementById('banner-active-maintenance');
        expect(banner).toBeInTheDocument();
        expect(banner).toHaveTextContent('HỆ THỐNG ĐANG BẢO TRÌ KHẨN CẤP');
        expect(banner).toHaveTextContent('Khẩn cấp');
      });
    });

    it('1.3. Card Cảnh Báo "LỊCH BẢO TRÌ SẮP DIỄN RA" chỉ hiển thị khi thời gian <= 1 tiếng, và ẨN khi > 1 tiếng', async () => {
      // Trường hợp A: Lịch cách hiện tại 5 tiếng (> 1 tiếng) -> Card cảnh báo PHẢI ẨN HOÀN TOÀN
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: false,
        isEmergency: false,
        scheduled: {
          id: 101,
          scheduledAt: new Date(now + 5 * 3600 * 1000).toISOString(),
          reason: 'Bảo trì cách 5 tiếng',
          createdBy: 'admin',
        },
        scheduledList: [
          {
            id: 101,
            scheduledAt: new Date(now + 5 * 3600 * 1000).toISOString(),
            reason: 'Bảo trì cách 5 tiếng',
            createdBy: 'admin',
          },
        ],
      });

      const { unmount } = renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        expect(screen.queryByText(/LỊCH BẢO TRÌ SẮP DIỄN RA/i)).not.toBeInTheDocument();
      });

      unmount();

      // Trường hợp B: Lịch cách hiện tại 40 phút (<= 1 tiếng) -> Card cảnh báo PHẢI HIỂN THỊ
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: false,
        isEmergency: false,
        scheduled: {
          id: 102,
          scheduledAt: new Date(now + 40 * 60 * 1000).toISOString(),
          reason: 'Bảo trì sắp diễn ra sau 40 phút',
          createdBy: 'admin',
        },
        scheduledList: [
          {
            id: 102,
            scheduledAt: new Date(now + 40 * 60 * 1000).toISOString(),
            reason: 'Bảo trì sắp diễn ra sau 40 phút',
            createdBy: 'admin',
          },
        ],
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        expect(screen.getByText(/LỊCH BẢO TRÌ SẮP DIỄN RA/i)).toBeInTheDocument();
        expect(screen.getByText(/Bắt đầu sau/i)).toBeInTheDocument();
      });
    });

    it('1.4. Form Lập Lịch Bảo Trì Định Kỳ LUÔN LUÔN HIỆN DIỆN (kể cả khi có Card cảnh báo và có lịch đã đặt)', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: false,
        isEmergency: false,
        scheduledList: [
          {
            id: 201,
            scheduledAt: new Date(now + 30 * 60 * 1000).toISOString(), // Còn 30 phút -> kích hoạt card cảnh báo
            reason: 'Bảo trì tối nay',
            createdBy: 'admin',
          },
        ],
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        // 1. Card cảnh báo hiển thị
        expect(screen.getByText(/LỊCH BẢO TRÌ SẮP DIỄN RA/i)).toBeInTheDocument();
        // 2. PO QUY ĐỊNH: Form lập lịch VẪN PHẢI HIỆN DIỆN ĐẦY ĐỦ, không bị biến mất!
        expect(screen.getByLabelText(/Thời điểm bắt đầu/i)).toBeInTheDocument();
        expect(screen.getByLabelText(/Thời điểm kết thúc/i)).toBeInTheDocument();
        expect(screen.getByRole('button', { name: /Lên lịch bảo trì/i })).toBeInTheDocument();
        // 3. Bảng danh sách các lịch hẹn tương lai cũng hiển thị
        expect(screen.getByText(/Danh Sách Lịch Bảo Trì Đã Lên Lịch/i)).toBeInTheDocument();
      });
    });
  });

  // =========================================================================
  // ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG & RÀNG BUỘC THỰC TẾ (SYSTEM IMPACT)
  // =========================================================================
  describe('⚡ TẦNG 2: Real System Impact & Business Constraints', () => {
    it('2.1. Ràng buộc 4 tiếng: Nhập thời gian bắt đầu dưới 4 tiếng -> Chặn submit và phát Toast cảnh báo', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: false,
        isEmergency: false,
        scheduledList: [],
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        expect(screen.getByLabelText(/Thời điểm bắt đầu/i)).toBeInTheDocument();
      });

      const startInput = screen.getByLabelText(/Thời điểm bắt đầu/i);

      // Nhập thời gian chỉ 2 tiếng nữa (< 4 tiếng)
      const invalidTime = toLocalInputString(now + 2 * 3600 * 1000);
      fireEvent.change(startInput, { target: { value: invalidTime } });

      fireEvent.submit(startInput.closest('form'));

      await waitFor(() => {
        // Kiểm tra không gọi API Backend
        expect(adminApi.setMaintenanceStatus).not.toHaveBeenCalled();
        // Kiểm tra hiển thị thông báo lỗi ít nhất 4 tiếng
        expect(screen.getByText(/Thời gian bảo trì theo lịch phải được thiết lập trước ít nhất 4 tiếng/i)).toBeInTheDocument();
      });
    });

    it('2.2. Nhập thời gian hợp lệ (>= 4 tiếng) -> Gửi yêu cầu đặt lịch tới Backend thành công với isEmergency = false', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: false,
        isEmergency: false,
        scheduledList: [],
      });

      adminApi.setMaintenanceStatus.mockResolvedValue({
        data: {
          active: false,
          isEmergency: false,
          scheduledList: [
            {
              id: 301,
              scheduledAt: new Date(now + 5 * 3600 * 1000).toISOString(),
              scheduledEndAt: new Date(now + 7 * 3600 * 1000).toISOString(),
              reason: 'Bảo trì hệ thống 5h hợp lệ',
              createdBy: 'admin',
            },
          ],
        },
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        expect(screen.getByLabelText(/Thời điểm bắt đầu/i)).toBeInTheDocument();
      });

      const validStart = toLocalInputString(now + 5 * 3600 * 1000);
      const validEnd = toLocalInputString(now + 7 * 3600 * 1000);

      fireEvent.change(screen.getByLabelText(/Thời điểm bắt đầu/i), { target: { value: validStart } });
      fireEvent.change(screen.getByLabelText(/Thời điểm kết thúc/i), { target: { value: validEnd } });
      fireEvent.change(screen.getByPlaceholderText(/Ví dụ: Nâng cấp cụm máy chủ/i), { target: { value: 'Bảo trì hệ thống 5h hợp lệ' } });

      const submitBtn = screen.getByRole('button', { name: /Lên lịch bảo trì/i });
      fireEvent.click(submitBtn);

      await waitFor(() => {
        expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith(
          expect.objectContaining({
            isEmergency: false,
            reason: 'Bảo trì hệ thống 5h hợp lệ',
          })
        );
      });
    });

    it('2.3. Hủy lịch bảo trì theo ID cụ thể trên bảng danh sách lịch hẹn', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: false,
        isEmergency: false,
        scheduledList: [
          {
            id: 999,
            scheduledAt: new Date(now + 6 * 3600 * 1000).toISOString(),
            scheduledEndAt: new Date(now + 8 * 3600 * 1000).toISOString(),
            reason: 'Lịch bảo trì cần hủy',
            createdBy: 'admin',
          },
        ],
      });

      adminApi.cancelScheduledMaintenance.mockResolvedValue({
        data: {
          active: false,
          isEmergency: false,
          scheduledList: [],
        },
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        expect(screen.getByText('Lịch bảo trì cần hủy')).toBeInTheDocument();
      });

      const cancelBtn = screen.getByRole('button', { name: /Hủy/i });
      fireEvent.click(cancelBtn);

      await waitFor(() => {
        expect(window.confirm).toHaveBeenCalled();
        expect(adminApi.cancelScheduledMaintenance).toHaveBeenCalledWith(999);
      });
    });
  });
});
