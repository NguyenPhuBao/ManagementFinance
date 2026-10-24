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

// Mock SecurityConfirmModal để test trực tiếp luồng xác nhận
vi.mock('../components/common/SecurityConfirmModal', () => ({
  default: ({ isOpen, onClose, onSuccess, title }) => {
    if (!isOpen) return null;
    return (
      <div data-testid="mock-security-modal">
        <span>{title}</span>
        <button data-testid="btn-confirm-mock-modal" onClick={onSuccess}>
          Confirm Modal Action
        </button>
        <button data-testid="btn-close-mock-modal" onClick={onClose}>
          Cancel Modal Action
        </button>
      </div>
    );
  },
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

describe('BroadcastPage Refinements — Emergency Checkbox & Maintenance History (2-Tier Architecture)', () => {
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
  describe('🧱 TẦNG 1: UI Rendering & Controls Hierarchy', () => {
    it('1.1. Header: Tuyệt đối không còn icon "construction" theo yêu cầu PO', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: false,
        isEmergency: false,
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        expect(screen.getByText(/Điều Hành Bảo Trì & Phát Sóng Thông Báo/i)).toBeInTheDocument();
      });

      // Header H1 không chứa icon construction
      const heading = screen.getByRole('heading', { level: 1 });
      expect(heading).toBeInTheDocument();
      expect(heading.querySelector('.material-symbols-outlined')).toBeNull();
      expect(heading).not.toHaveTextContent('construction');
    });

    it('1.2. Form Lập lịch: Đã loại bỏ box ghi chú giả thông báo theo yêu cầu PO', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: false,
        isEmergency: false,
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        expect(
          screen.queryByText(/Mặc định khi bảo trì \(Định kỳ hay khẩn cấp\), hệ thống đều sẽ tự động phát thông báo tới Client-app người dùng và Quản trị viên\./i)
        ).not.toBeInTheDocument();
      });
    });

    it('1.3. Form Lập lịch: Nút checkbox "Bảo trì khẩn cấp" bị chặn (disabled) khi bảo trì khẩn cấp đang kích hoạt', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: true,
        isEmergency: true,
        reason: 'Khắc phục sự cố khẩn cấp',
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        const checkbox = screen.getByLabelText(/Bảo trì khẩn cấp/i);
        expect(checkbox).toBeInTheDocument();
        expect(checkbox).toBeDisabled();
        expect(screen.getByText(/Hệ thống đang trong chế độ bảo trì khẩn cấp/i)).toBeInTheDocument();
      });
    });

    it('1.4. Form Lập lịch: Nút checkbox "Bảo trì khẩn cấp" KHÔNG bị chặn khi bảo trì định kỳ đang diễn ra hoặc đã lên lịch', async () => {
      // Đang bảo trì định kỳ
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: true,
        isEmergency: false,
        reason: 'Bảo trì định kỳ hệ thống',
        scheduled: {
          scheduledAt: new Date(now + 10000000).toISOString(),
          reason: 'Nâng cấp cụm database',
        },
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        const checkbox = screen.getByLabelText(/Bảo trì khẩn cấp/i);
        expect(checkbox).toBeInTheDocument();
        expect(checkbox).not.toBeDisabled();
      });
    });

    it('1.5. Thao tác Form: Khi tick "Bảo trì khẩn cấp", giao diện chuyển sang chế độ khẩn cấp (nút đỏ, ẩn input giờ bắt buộc)', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: false,
        isEmergency: false,
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        expect(screen.getByLabelText(/Bảo trì khẩn cấp/i)).toBeInTheDocument();
      });

      const checkbox = screen.getByLabelText(/Bảo trì khẩn cấp/i);
      expect(checkbox).not.toBeChecked();

      // Kiểm tra nút submit ban đầu là Lên lịch bảo trì (primary)
      expect(document.getElementById('btn-submit-schedule-maintenance')).toBeInTheDocument();

      // Tick vào checkbox "Bảo trì khẩn cấp"
      fireEvent.click(checkbox);
      expect(checkbox).toBeChecked();

      // Nút submit chuyển sang nút đỏ khẩn cấp
      expect(document.getElementById('btn-submit-emergency-maintenance')).toBeInTheDocument();
      expect(screen.getByText(/Kích hoạt bảo trì khẩn cấp/i)).toBeInTheDocument();
      expect(screen.queryByLabelText(/Thời điểm bắt đầu/i)).not.toBeInTheDocument();
    });

    it('1.6. Tab Lịch sử: Trạng thái SCHEDULED hiển thị đúng badge "Đã lên lịch", không bị hiển thị nhầm thành "Đã hủy"', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({ active: false });
      adminApi.getMaintenanceHistory.mockResolvedValue({
        data: {
          data: [
            {
              id: 'maint-sch-01',
              type: 'SCHEDULED',
              status: 'SCHEDULED',
              reason: 'Bảo trì định kỳ máy chủ cuối tuần',
              activated_by: 'lead_admin',
              started_at: null,
              ended_at: null,
              scheduled_at: new Date(now + 86400000).toISOString(),
              scheduled_end_at: new Date(now + 90000000).toISOString(),
            },
            {
              id: 'maint-emg-02',
              type: 'EMERGENCY',
              status: 'CANCELLED',
              reason: 'Phiên khẩn cấp đã hủy',
              activated_by: 'system',
              started_at: new Date(now - 7200000).toISOString(),
              ended_at: new Date(now - 3600000).toISOString(),
            },
          ],
          pagination: { total: 2 },
        },
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        expect(screen.getByText('maint-sch-01')).toBeInTheDocument();
        expect(screen.getByText('maint-emg-02')).toBeInTheDocument();
      });

      // Kiểm tra bản ghi maint-sch-01 có badge "Đã lên lịch"
      const scheduledRow = screen.getByText('maint-sch-01').closest('tr');
      expect(scheduledRow).toHaveTextContent('Định kỳ');
      expect(scheduledRow).toHaveTextContent('Đã lên lịch');
      expect(scheduledRow).not.toHaveTextContent('Đã hủy');

      // Kiểm tra bản ghi maint-emg-02 có badge "Đã hủy"
      const cancelledRow = screen.getByText('maint-emg-02').closest('tr');
      expect(cancelledRow).toHaveTextContent('Khẩn cấp');
      expect(cancelledRow).toHaveTextContent('Đã hủy');

      // Dropdown lọc trạng thái có tùy chọn "Đã lên lịch"
      const statusSelect = screen.getByDisplayValue(/Tất cả trạng thái/i);
      expect(statusSelect).toBeInTheDocument();
      const options = Array.from(statusSelect.querySelectorAll('option')).map((o) => o.value);
      expect(options).toContain('SCHEDULED');
    });
  });

  // =========================================================================
  // ⚡ TẦNG 2: KIỂM THỬ HOẠT ĐỘNG THỰC TẾ & TÁC ĐỘNG HỆ THỐNG (SYSTEM IMPACT)
  // =========================================================================
  describe('⚡ TẦNG 2: System Impact & Behavioral Verification', () => {
    it('2.1. System Impact: Tick "Bảo trì khẩn cấp" và Submit -> Mở modal xác nhận an toàn -> Gọi API kích hoạt bảo trì khẩn cấp', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: false,
        isEmergency: false,
      });
      adminApi.setMaintenanceStatus.mockResolvedValue({
        active: true,
        isEmergency: true,
        reason: 'Sự cố nghẽn mạng khẩn cấp',
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        expect(screen.getByLabelText(/Bảo trì khẩn cấp/i)).toBeInTheDocument();
      });

      // 1. Tick chọn bảo trì khẩn cấp
      const checkbox = screen.getByLabelText(/Bảo trì khẩn cấp/i);
      fireEvent.click(checkbox);

      // 2. Nhập lý do khẩn cấp
      const reasonInput = screen.getByPlaceholderText(/Nhập lý do bảo trì khẩn cấp/i);
      fireEvent.change(reasonInput, { target: { value: 'Sự cố nghẽn mạng khẩn cấp' } });

      // 3. Submit form kích hoạt khẩn cấp
      const submitBtn = document.getElementById('btn-submit-emergency-maintenance');
      fireEvent.click(submitBtn);

      // 4. Modal bảo mật mở ra
      await waitFor(() => {
        expect(screen.getByTestId('mock-security-modal')).toBeInTheDocument();
      });

      // 5. Xác nhận trên modal -> Tác động API
      const confirmBtn = screen.getByTestId('btn-confirm-mock-modal');
      fireEvent.click(confirmBtn);

      await waitFor(() => {
        expect(adminApi.setMaintenanceStatus).toHaveBeenCalledTimes(1);
        expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith(
          expect.objectContaining({
            active: true,
            isEmergency: true,
            reason: 'Sự cố nghẽn mạng khẩn cấp',
          })
        );
      });
    });

    it('2.2. System Impact: Nút làm mới (Reset) xóa trắng biểu mẫu và bỏ tick checkbox khẩn cấp', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({
        active: false,
        isEmergency: false,
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        expect(screen.getByLabelText(/Bảo trì khẩn cấp/i)).toBeInTheDocument();
      });

      const checkbox = screen.getByLabelText(/Bảo trì khẩn cấp/i);
      fireEvent.click(checkbox);
      expect(checkbox).toBeChecked();

      // Bấm nút Làm mới
      const resetBtn = screen.getByTitle(/Làm mới/i);
      fireEvent.click(resetBtn);

      await waitFor(() => {
        expect(checkbox).not.toBeChecked();
        expect(document.getElementById('btn-submit-schedule-maintenance')).toBeInTheDocument();
      });
    });

    it('2.3. System Impact: Thay đổi filter trạng thái sang SCHEDULED -> Gọi API fetch lịch sử với param SCHEDULED', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValue({ active: false });
      adminApi.getMaintenanceHistory.mockResolvedValue({
        data: { data: [], pagination: { total: 0 } },
      });

      renderWithProviders(<BroadcastPage />);

      await waitFor(() => {
        expect(adminApi.getMaintenanceHistory).toHaveBeenCalledWith(
          expect.objectContaining({
            status: undefined,
          })
        );
      });

      // Chọn lọc trạng thái "Đã lên lịch" (SCHEDULED)
      const statusSelect = screen.getByDisplayValue(/Tất cả trạng thái/i);
      fireEvent.change(statusSelect, { target: { value: 'SCHEDULED' } });

      await waitFor(() => {
        expect(adminApi.getMaintenanceHistory).toHaveBeenCalledWith(
          expect.objectContaining({
            status: 'SCHEDULED',
            page: 1,
          })
        );
      });
    });
  });
});
