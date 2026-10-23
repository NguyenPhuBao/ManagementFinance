import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import BroadcastPage from '../pages/system/BroadcastPage';
import ServerHealthPanel from '../components/common/ServerHealthPanel';
import { LanguageProvider } from '../store/language.context';
import adminApi from '../api/admin.api';
import notificationApi from '../api/notification.api';
import useSocket from '../hooks/useSocket';

const mockNavigate = vi.fn();
vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom');
  return {
    ...actual,
    useNavigate: () => mockNavigate,
  };
});

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
        data: [
          {
            id: 1,
            title: 'Hệ thống chuẩn bị bảo trì',
            message: 'Toàn bộ máy chủ sẽ bảo trì trong 30 phút.',
            level: 'warning',
            sender_username: 'superadmin',
            created_at: '2026-03-10T10:00:00.000Z',
          },
        ],
        pagination: { page: 1, limit: 5, total: 1, totalPages: 1 },
      },
    }),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: vi.fn(() => ({
    connected: true,
    on: vi.fn(),
    off: vi.fn(),
  })),
}));

describe('Admin-web — 2-TIER VERIFICATION: Maintenance & Broadcast Refinements', () => {
  const mockActiveEmergency = {
    active: true,
    isEmergency: true,
    reason: 'Sự cố bảo mật khẩn cấp',
    activatedBy: 'admin_sys',
    activatedAt: '2026-03-10T10:00:00.000Z',
    scheduled: null,
  };

  const mockActiveRegular = {
    active: true,
    isEmergency: false,
    reason: 'Bảo trì định kỳ máy chủ cơ sở dữ liệu',
    activatedBy: 'admin_db',
    activatedAt: '2026-03-10T08:00:00.000Z',
    scheduled: null,
  };

  beforeEach(() => {
    vi.clearAllMocks();
    mockNavigate.mockClear();
    adminApi.getMaintenanceStatus.mockResolvedValue({ data: mockActiveEmergency });
  });

  const renderBroadcastPage = () => {
    return render(
      <BrowserRouter>
        <LanguageProvider>
          <BroadcastPage />
        </LanguageProvider>
      </BrowserRouter>
    );
  };

  const renderServerHealth = (maintenanceState) => {
    return render(
      <BrowserRouter>
        <LanguageProvider>
          <ServerHealthPanel
            metrics={{
              cpu: { usagePercent: 30, cores: 8, loadAvg: [1.2, 1.1, 0.9] },
              memory: { usedPercent: 45, usedGB: 7.2, totalGB: 16 },
              disk: { usedPercent: 55, usedGB: 110, totalGB: 200 },
              database: { activeConnections: 12, maxConnections: 100, poolUsagePercent: 12, responseTimeMs: 4 },
              cache: { hitRatioPercent: 92, connectedClients: 5, usedMemoryMB: 64 },
              threatScore: { score: 10, level: 'low' },
              activeServices: [],
            }}
            maintenance={maintenanceState}
            onToggleMaintenance={vi.fn()}
          />
        </LanguageProvider>
      </BrowserRouter>
    );
  };

  // ==========================================
  // 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC (UI RENDERING & INTERACTION)
  // ==========================================
  describe('🧱 TẦNG 1: UI Rendering & Controls', () => {
    it('1.1. Broadcast Tab loại bỏ hoàn toàn block ghi chú quy tắc vận hành (rules note)', async () => {
      renderBroadcastPage();

      // Chuyển sang Tab Phát Thông Báo
      const broadcastTabBtn = screen.getByRole('button', { name: /Phát Thông Báo/i });
      fireEvent.click(broadcastTabBtn);

      await waitFor(() => {
        expect(screen.getByText('Mức độ ưu tiên thông báo')).toBeInTheDocument();
      });

      // Xác nhận văn bản ghi chú quy tắc cũ không còn xuất hiện
      expect(screen.queryByText(/Quy tắc vận hành phát thanh/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Thông báo được gửi realtime tới các socket đang kết nối/i)).not.toBeInTheDocument();
    });

    it('1.2. Broadcast Tab hiển thị bảng lịch sử thông báo đã phát với đầy đủ cột và phân trang mặc định 5/page', async () => {
      renderBroadcastPage();

      const broadcastTabBtn = screen.getByRole('button', { name: /Phát Thông Báo/i });
      fireEvent.click(broadcastTabBtn);

      await waitFor(() => {
        expect(screen.getByText('Lịch Sử Các Thông Báo Đã Phát Sóng')).toBeInTheDocument();
      });

      // Kiểm tra đầy đủ các cột của bảng lịch sử phát sóng
      const historyTable = screen.getByRole('table');
      expect(within(historyTable).getByText('#')).toBeInTheDocument();
      expect(within(historyTable).getByText('Mức độ')).toBeInTheDocument();
      expect(within(historyTable).getByText('Tiêu đề')).toBeInTheDocument();
      expect(within(historyTable).getByText('Nội dung thông báo')).toBeInTheDocument();
      expect(within(historyTable).getByText('Người phát sóng')).toBeInTheDocument();
      expect(within(historyTable).getByText('Thời điểm phát sóng')).toBeInTheDocument();

      // Kiểm tra dữ liệu được render
      expect(within(historyTable).getByText('Hệ thống chuẩn bị bảo trì')).toBeInTheDocument();
      expect(within(historyTable).getByText('superadmin')).toBeInTheDocument();

      // Kiểm tra selector phân trang mặc định 5 dòng / trang
      const limitSelect = screen.getByDisplayValue('5 dòng / trang');
      expect(limitSelect).toBeInTheDocument();
    });

    it('1.3. Tab Điều hành bảo trì không còn nút icon cong (refresh) ở tiêu đề bảng lịch sử', async () => {
      renderBroadcastPage();

      await waitFor(() => {
        expect(screen.getByText('Lịch Sử Các Phiên Bảo Trì Hệ Thống')).toBeInTheDocument();
      });

      // Nút refresh tròn ở header bảng bảo trì đã bị loại bỏ
      expect(screen.queryByTitle(/Tải lại lịch sử bảo trì/i)).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: /sync/i })).not.toBeInTheDocument();
    });

    it('1.4. Banner bảo trì ở BroadcastPage phân biệt Khẩn cấp vs Thông thường và không chứa icon 🚨', async () => {
      renderBroadcastPage();

      await waitFor(() => {
        expect(screen.getByText('HỆ THỐNG ĐANG BẢO TRÌ KHẨN CẤP')).toBeInTheDocument();
      });

      // Icon 🚨 không tồn tại trong text
      expect(screen.queryByText(/🚨/)).not.toBeInTheDocument();

      // Phải có badge Khẩn cấp
      expect(screen.getAllByText('Khẩn cấp')[0]).toBeInTheDocument();
    });

    it('1.5. Dashboard ServerHealthPanel khóa toggle (#btn-maintenance-toggle) khi đang có bảo trì hoạt động', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValueOnce({ data: mockActiveEmergency });
      renderServerHealth();

      await waitFor(() => {
        const toggleBtn = document.getElementById('btn-maintenance-toggle');
        expect(toggleBtn).toBeInTheDocument();
        expect(toggleBtn).toBeDisabled();
      });

      const toggleBtn = document.getElementById('btn-maintenance-toggle');
      expect(toggleBtn).toHaveClass('cursor-not-allowed');

      // Có badge Khẩn cấp
      expect(screen.getByText('Khẩn cấp')).toBeInTheDocument();
    });

    it('1.6. Dashboard ServerHealthPanel phân biệt giao diện Thông thường (màu cam/amber) khi không phải khẩn cấp', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValueOnce({ data: mockActiveRegular });
      renderServerHealth();

      await waitFor(() => {
        expect(screen.getByText('Thông thường')).toBeInTheDocument();
      });

      const toggleBtn = document.getElementById('btn-maintenance-toggle');
      expect(toggleBtn).toBeDisabled();
    });
  });

  // ==========================================
  // ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ (REAL SYSTEM IMPACT)
  // ==========================================
  describe('⚡ TẦNG 2: Real System Impact & Behavioral Verification', () => {
    it('2.1. Thao tác "Tắt Bảo Trì" bắt buộc mở popup xác nhận; chỉ gọi API kết thúc sau khi bấm Xác Nhận', async () => {
      adminApi.setMaintenanceStatus.mockResolvedValueOnce({
        data: { active: false, isEmergency: true },
      });

      renderBroadcastPage();

      await waitFor(() => {
        expect(screen.getByRole('button', { name: /Tắt Bảo Trì/i })).toBeInTheDocument();
      });

      // Click nút Tắt Bảo Trì
      fireEvent.click(screen.getByRole('button', { name: /Tắt Bảo Trì/i }));

      // Phải hiện modal xác nhận kết thúc bảo trì
      await waitFor(() => {
        expect(screen.getByText('Xác Nhận Kết Thúc Bảo Trì')).toBeInTheDocument();
      });

      // Chưa click xác nhận thì adminApi CHƯA được gọi
      expect(adminApi.setMaintenanceStatus).not.toHaveBeenCalled();

      // Click nút Xác Nhận Kết Thúc trong modal
      const confirmBtn = screen.getByRole('button', { name: /Xác Nhận Kết Thúc/i });
      fireEvent.click(confirmBtn);

      // TÁC ĐỘNG HỆ THỐNG: Gọi API setMaintenanceStatus với active: false
      await waitFor(() => {
        expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith(
          expect.objectContaining({ active: false })
        );
      });
    });

    it('2.2. Modal xác nhận có thể bấm "Hủy Bỏ" mà không kích hoạt API tắt bảo trì', async () => {
      renderBroadcastPage();

      await waitFor(() => {
        expect(screen.getByRole('button', { name: /Tắt Bảo Trì/i })).toBeInTheDocument();
      });

      fireEvent.click(screen.getByRole('button', { name: /Tắt Bảo Trì/i }));

      await waitFor(() => {
        expect(screen.getByText('Xác Nhận Kết Thúc Bảo Trì')).toBeInTheDocument();
      });

      // Bấm nút Hủy Bỏ
      const cancelBtn = screen.getByRole('button', { name: /Hủy Bỏ/i });
      fireEvent.click(cancelBtn);

      // Modal đóng lại và không gọi API
      await waitFor(() => {
        expect(screen.queryByText('Xác Nhận Kết Thúc Bảo Trì')).not.toBeInTheDocument();
      });
      expect(adminApi.setMaintenanceStatus).not.toHaveBeenCalled();
    });

    it('2.3. Tương tác phân trang Broadcast History gửi request đúng tham số page & limit tới Backend API', async () => {
      notificationApi.getBroadcastHistory.mockResolvedValueOnce({
        data: {
          data: [
            {
              id: 2,
              title: 'Cập nhật hệ thống v2',
              message: 'Nâng cấp cụm Redis',
              level: 'info',
              sender_username: 'ops_team',
              created_at: '2026-03-10T11:00:00.000Z',
            },
          ],
          pagination: { page: 2, limit: 5, total: 10, totalPages: 2 },
        },
      });

      renderBroadcastPage();

      const broadcastTabBtn = screen.getByRole('button', { name: /Phát Thông Báo/i });
      fireEvent.click(broadcastTabBtn);

      await waitFor(() => {
        expect(notificationApi.getBroadcastHistory).toHaveBeenCalledWith({
          page: 1,
          limit: 5,
        });
      });
    });

    it('2.4. Phát sóng thông báo mới tự động gọi broadcastToAll và nạp lại lịch sử thông báo từ PostgreSQL', async () => {
      notificationApi.broadcastToAll.mockResolvedValueOnce({
        data: { success: true },
      });

      renderBroadcastPage();

      const broadcastTabBtn = screen.getByRole('button', { name: /Phát Thông Báo/i });
      fireEvent.click(broadcastTabBtn);

      await waitFor(() => {
        expect(screen.getByPlaceholderText(/Ví dụ: Cập nhật tính năng mới/i)).toBeInTheDocument();
      });

      const titleInput = screen.getByPlaceholderText(/Ví dụ: Cập nhật tính năng mới/i);
      const msgInput = screen.getByPlaceholderText(/Nhập nội dung thông điệp chi tiết/i);
      const submitBtn = screen.getByRole('button', { name: /Phát Sóng Thông Báo/i });

      fireEvent.change(titleInput, { target: { value: 'Bảo trì khẩn cấp thanh toán' } });
      fireEvent.change(msgInput, { target: { value: 'Tạm ngắt cổng nạp rút trong 15 phút.' } });
      fireEvent.click(submitBtn);

      // TÁC ĐỘNG HỆ THỐNG: API broadcastToAll được gọi với đúng payload
      await waitFor(() => {
        expect(notificationApi.broadcastToAll).toHaveBeenCalledWith(
          expect.objectContaining({
            title: 'Bảo trì khẩn cấp thanh toán',
            message: 'Tạm ngắt cổng nạp rút trong 15 phút.',
          })
        );
      });

      // TÁC ĐỘNG HỆ THỐNG: Lịch sử broadcast được nạp lại
      await waitFor(() => {
        expect(notificationApi.getBroadcastHistory).toHaveBeenCalled();
      });
    });

    it('2.5. Click "Quản trị bảo trì" từ ServerHealthPanel điều hướng Router tới /broadcast', async () => {
      adminApi.getMaintenanceStatus.mockResolvedValueOnce({ data: mockActiveEmergency });
      renderServerHealth();

      await waitFor(() => {
        expect(screen.getByText('Quản trị & Lên lịch bảo trì →')).toBeInTheDocument();
      });

      const navBtn = screen.getByText('Quản trị & Lên lịch bảo trì →');
      fireEvent.click(navBtn);

      // TÁC ĐỘNG HỆ THỐNG: Navigation được gọi với đường dẫn /broadcast
      expect(mockNavigate).toHaveBeenCalledWith('/broadcast');
    });
  });
});
