/**
 * Test: BroadcastPage Emergency Maintenance & History Table (2-Tier: UI Rendering & System Impact)
 * Kiểm tra:
 * 1. Đã xóa bỏ checkbox thừa, bảo trì tức thì luôn là KHẨN CẤP với nút bấm ĐỎ "Bật Bảo Trì Khẩn Cấp".
 * 2. Render đầy đủ Bảng Lịch Sử Bảo Trì từ CSDL PostgreSQL, hiển thị cột Người kích hoạt, Thời gian, Thời lượng, Trạng thái.
 */
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import BroadcastPage from '../pages/system/BroadcastPage';
import { LanguageProvider } from '../store/language.context';
import adminApi from '../api/admin.api';

const mockSocket = {
  on: vi.fn(),
  off: vi.fn(),
  emit: vi.fn(),
};

vi.mock('../hooks/useSocket', () => ({
  default: () => mockSocket,
}));

vi.mock('../api/admin.api', () => ({
  default: {
    getMaintenanceStatus: vi.fn().mockResolvedValue({
      data: {
        active: false,
        isEmergency: true,
        reason: '',
        activatedBy: null,
        activatedAt: null,
        scheduled: null,
      },
    }),
    setMaintenanceStatus: vi.fn().mockResolvedValue({
      data: {
        active: true,
        isEmergency: true,
        reason: 'Khắc phục sự cố khẩn cấp',
        activatedBy: 'admin_test',
        activatedAt: new Date().toISOString(),
      },
    }),
    cancelScheduledMaintenance: vi.fn().mockResolvedValue({ data: { cancelled: true } }),
    verifySecurityAction: vi.fn().mockResolvedValue({ data: { verified: true } }),
    getMaintenanceHistory: vi.fn().mockResolvedValue({
      data: {
        data: [
          {
            id: 101,
            type: 'EMERGENCY',
            reason: 'Nâng cấp máy chủ cơ sở dữ liệu khẩn cấp',
            activated_by: 'super_admin',
            started_at: '2026-10-10T10:00:00.000Z',
            ended_at: '2026-10-10T10:25:00.000Z',
            status: 'COMPLETED',
          },
          {
            id: 102,
            type: 'SCHEDULED',
            reason: 'Bảo trì định kỳ tuần 41',
            activated_by: 'devops_lead',
            started_at: '2026-10-11T01:00:00.000Z',
            ended_at: null,
            status: 'ONGOING',
          },
        ],
        pagination: { page: 1, limit: 10, total: 2, totalPages: 1 },
      },
    }),
  },
}));

vi.mock('../api/notification.api', () => ({
  default: {
    sendBroadcast: vi.fn().mockResolvedValue({ data: { success: true } }),
    broadcastToAll: vi.fn().mockResolvedValue({ data: { success: true } }),
    getBroadcastHistory: vi.fn().mockResolvedValue({ data: { data: [], pagination: { page: 1, limit: 5, total: 0, totalPages: 1 } } }),
  },
}));

describe('BroadcastPage - Emergency Maintenance & History Journal Suite', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const renderComponent = () => {
    return render(
      <BrowserRouter>
        <LanguageProvider>
          <BroadcastPage />
        </LanguageProvider>
      </BrowserRouter>
    );
  };

  it('1. Đã bỏ box "Kích Hoạt Bảo Trì Khẩn Cấp", Form lên lịch có đầy đủ trường bắt đầu, kết thúc, lý do và không có checkbox thừa', async () => {
    renderComponent();

    // Xác nhận ĐÃ BỎ box Kích Hoạt Bảo Trì Khẩn Cấp
    expect(screen.queryByText('Kích Hoạt Bảo Trì Khẩn Cấp')).not.toBeInTheDocument();

    // Checkbox "Bảo trì khẩn cấp" mới theo yêu cầu PO và không còn checkbox notify cũ
    expect(screen.getByRole('checkbox', { name: /Bảo trì khẩn cấp/i })).toBeInTheDocument();
    expect(screen.queryByText(/Phát thông báo qua socket/i)).not.toBeInTheDocument();

    // Form lên lịch hiển thị đầy đủ các trường và nút submit
    expect(screen.getByLabelText(/Thời điểm bắt đầu/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Thời điểm kết thúc/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Nội dung \/ Lý do/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Lên lịch bảo trì/i })).toBeInTheDocument();
  });

  it('2. Render đầy đủ Bảng Lịch Sử Bảo Trì với cột Người kích hoạt và dữ liệu từ CSDL', async () => {
    renderComponent();

    // Tiêu đề bảng
    expect(await screen.findByText('Lịch Sử Các Phiên Bảo Trì Hệ Thống')).toBeInTheDocument();

    // Các tiêu đề cột
    expect(screen.getByText('Người kích hoạt')).toBeInTheDocument();
    expect(screen.getByText('Loại bảo trì')).toBeInTheDocument();
    expect(screen.getByText('Thời lượng')).toBeInTheDocument();
    expect(screen.getByText('Trạng thái')).toBeInTheDocument();

    // Dữ liệu dòng 1 (Khẩn cấp, hoàn thành)
    expect(screen.getByText('super_admin')).toBeInTheDocument();
    expect(screen.getByText('Nâng cấp máy chủ cơ sở dữ liệu khẩn cấp')).toBeInTheDocument();
    expect(screen.getAllByText('Đã hoàn thành').length).toBeGreaterThanOrEqual(1);

    // Dữ liệu dòng 2 (Theo lịch, đang diễn ra)
    expect(screen.getByText('devops_lead')).toBeInTheDocument();
    expect(screen.getByText('Bảo trì định kỳ tuần 41')).toBeInTheDocument();
    expect(screen.getAllByText('Đang diễn ra').length).toBeGreaterThanOrEqual(1);
  });

  it('3. Tác động hệ thống: Khi submit form lên lịch bảo trì hợp lệ, gọi adminApi.setMaintenanceStatus với payload chuẩn xác', async () => {
    adminApi.setMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: false,
        scheduled: {
          scheduledAt: new Date(Date.now() + 5 * 3600 * 1000).toISOString(),
          reason: 'Bảo trì định kỳ CSDL',
          isEmergency: false,
        },
      },
    });

    renderComponent();

    const startDatetimeInput = screen.getByLabelText(/Thời điểm bắt đầu/i);
    const dStart = new Date(Date.now() + 5 * 3600 * 1000);
    const pad = (n) => String(n).padStart(2, '0');
    const validStart = `${dStart.getFullYear()}-${pad(dStart.getMonth() + 1)}-${pad(dStart.getDate())}T${pad(dStart.getHours())}:${pad(dStart.getMinutes())}`;

    fireEvent.change(startDatetimeInput, { target: { value: validStart } });
    fireEvent.change(screen.getByLabelText(/Nội dung \/ Lý do bảo trì/i), {
      target: { value: 'Bảo trì định kỳ CSDL' },
    });

    const submitBtn = screen.getByRole('button', { name: /Lên lịch bảo trì/i });
    fireEvent.click(submitBtn);

    await waitFor(() => {
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith(
        expect.objectContaining({
          reason: 'Bảo trì định kỳ CSDL',
          isEmergency: false,
        })
      );
    });
  });

  it('4. Bảng Lịch sử các phiên bảo trì có bộ phân trang chuẩn (Pagination) với Page Size và Range (mặc định 5 dòng/trang)', async () => {
    adminApi.getMaintenanceHistory.mockResolvedValueOnce({
      data: {
        data: Array.from({ length: 25 }, (_, i) => ({
          id: i + 1,
          type: i % 2 === 0 ? 'EMERGENCY' : 'SCHEDULED',
          reason: `Phiên bảo trì số ${i + 1}`,
          activated_by: 'admin',
          started_at: '2026-10-10T10:00:00.000Z',
          ended_at: '2026-10-10T11:00:00.000Z',
          status: 'COMPLETED',
        })),
        pagination: { page: 1, limit: 5, total: 25, totalPages: 5 },
      },
    });

    renderComponent();

    // Hiển thị text dải số phần tử của phân trang: "1 - 5 of 25" hoặc tương tự
    expect(await screen.findByText(/1 - 5 of 25/i)).toBeInTheDocument();

    // Có selector chọn page size với các lựa chọn 5, 10, 20, 50 (mặc định là 5)
    const selects = screen.getAllByRole('combobox');
    const pageSizeSelect = selects.find((s) => s.value === '5');
    expect(pageSizeSelect).toBeInTheDocument();
  });

  it('5. Tác động hệ thống: Khi đổi page size trong Pagination, gọi getMaintenanceHistory với page = 1 và limit mới', async () => {
    adminApi.getMaintenanceHistory.mockResolvedValue({
      data: {
        data: Array.from({ length: 25 }, (_, i) => ({
          id: i + 1,
          type: 'EMERGENCY',
          reason: `Phiên bảo trì ${i + 1}`,
          activated_by: 'admin',
          started_at: '2026-10-10T10:00:00.000Z',
          ended_at: '2026-10-10T11:00:00.000Z',
          status: 'COMPLETED',
        })),
        pagination: { page: 1, limit: 5, total: 25, totalPages: 5 },
      },
    });

    renderComponent();

    await screen.findByText(/1 - 5 of 25/i);

    // Tìm select page size trong pagination (phần tử select thứ 3 sau filter Type và filter Status)
    const selects = screen.getAllByRole('combobox');
    const paginationSelect = selects.find((sel) => sel.value === '5');
    expect(paginationSelect).toBeInTheDocument();

    fireEvent.change(paginationSelect, { target: { value: '20' } });

    await waitFor(() => {
      expect(adminApi.getMaintenanceHistory).toHaveBeenCalledWith(
        expect.objectContaining({ page: 1, limit: 20 })
      );
    });
  });

  it('6. Đã loại bỏ các ghi chú và quy tắc không cần thiết (Khối đỏ bên Kích hoạt & Khối vàng bên Lên lịch)', async () => {
    renderComponent();

    await screen.findByText('Lên Lịch Thời Điểm Bảo Trì');

    // Không còn khối đỏ: "Nguyên tắc bảo trì khẩn cấp" & "Tác động thời gian thực"
    expect(screen.queryByText(/Nguyên tắc bảo trì khẩn cấp/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Cắt tải toàn bộ người dùng/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Tác động thời gian thực \(Real-time Broadcast\)/i)).not.toBeInTheDocument();

    // Không còn khối vàng: "Quy tắc bảo trì khẩn cấp ghi đè (PO Policy)"
    expect(screen.queryByText(/Quy tắc bảo trì khẩn cấp ghi đè/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/PO Policy/i)).not.toBeInTheDocument();
  });

  it('7. Tác động hệ thống: Khi hệ thống đang bảo trì, banner hiển thị và có nút Tắt Bảo Trì, form lên lịch vẫn hoạt động', async () => {
    adminApi.getMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: true,
        isEmergency: true,
        reason: 'Đang bảo trì trực tiếp',
        activatedBy: 'admin',
        activatedAt: '2026-10-13T10:00:00Z',
        scheduled: null,
      },
    });

    renderComponent();

    // Hiển thị banner bảo trì đang kích hoạt và nút Tắt Bảo Trì
    expect(await screen.findByRole('button', { name: /Tắt Bảo Trì/i })).toBeInTheDocument();

    // Form lên lịch bảo trì vẫn luôn luôn hiện diện theo chuẩn PO
    expect(screen.getByRole('button', { name: /Lên lịch bảo trì/i })).toBeInTheDocument();
  });

  it('8. Tầng 1: Đã xóa phụ đề, box bình thường, mô tả checkbox, footer riêng, mô tả CSDL và badge tổng phiên', async () => {
    renderComponent();

    await screen.findByText('Lên Lịch Thời Điểm Bảo Trì');

    // 1. Bỏ phụ đề trang
    expect(screen.queryByText(/Quản trị chế độ bảo trì 2 tầng/i)).not.toBeInTheDocument();

    // 2. Bỏ box "HỆ THỐNG ĐANG HOẠT ĐỘNG BÌNH THƯỜNG"
    expect(screen.queryByText(/HỆ THỐNG ĐANG HOẠT ĐỘNG BÌNH THƯỜNG/i)).not.toBeInTheDocument();

    // 3. Đã bỏ checkbox "Tự động phát thông báo" theo chuẩn PO
    expect(screen.queryByText('Tự động phát thông báo')).not.toBeInTheDocument();
    expect(screen.queryByText(/Khi tới giờ hẹn, hệ thống sẽ tự động phát sóng thông báo realtime qua Socket.IO/i)).not.toBeInTheDocument();

    // 4. "Lên lịch bảo trì" và "Làm mới" nằm cùng trong form
    expect(screen.getByRole('button', { name: /Lên lịch bảo trì/i })).toBeInTheDocument();
    const form = screen.getByLabelText(/Thời điểm bắt đầu/i).closest('form');
    const refreshBtn = form.querySelector('button[type="button"]');
    expect(refreshBtn).toBeInTheDocument();
    expect(refreshBtn.textContent).toContain('Làm mới');

    // 6. Bỏ mô tả CSDL PostgreSQL
    expect(screen.queryByText(/Nhật ký vĩnh viễn lưu trữ tại CSDL PostgreSQL/i)).not.toBeInTheDocument();

    // 7. Dropdown select bộ lọc có padding pr-8 chống đè icon
    const selects = screen.getAllByRole('combobox');
    const typeSelect = selects[0];
    const statusSelect = selects[1];
    expect(typeSelect.className).toContain('pr-8');
    expect(statusSelect.className).toContain('pr-8');

    // 8. Bỏ badge "Tổng: ... phiên" trên header
    expect(screen.queryByText(/Tổng: 2 phiên/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Tổng: 5 phiên/i)).not.toBeInTheDocument();
  });

  it('9. Tầng 2 (Tác động hệ thống): Chuyển trang và đổi page size hoạt động chuẩn xác, không bị race condition', async () => {
    adminApi.getMaintenanceHistory.mockResolvedValue({
      data: {
        data: Array.from({ length: 5 }, (_, i) => ({
          id: i + 1,
          type: 'EMERGENCY',
          reason: `Phiên bảo trì ${i + 1}`,
          activated_by: 'admin',
          started_at: '2026-10-10T10:00:00.000Z',
          ended_at: '2026-10-10T11:00:00.000Z',
          status: 'COMPLETED',
        })),
        pagination: { page: 1, limit: 5, total: 30, totalPages: 6 },
      },
    });

    renderComponent();

    await screen.findByText(/1 - 5 of 30/i);

    // Click chuyển sang trang 2
    const page2Btn = screen.getByRole('button', { name: '2' });
    expect(page2Btn).toBeInTheDocument();
    fireEvent.click(page2Btn);

    await waitFor(() => {
      expect(adminApi.getMaintenanceHistory).toHaveBeenCalledWith(
        expect.objectContaining({ page: 2, limit: 5 })
      );
    });

    // Đổi page size sang 10
    const selects = screen.getAllByRole('combobox');
    const paginationSelect = selects.find((sel) => sel.value === '5');
    fireEvent.change(paginationSelect, { target: { value: '10' } });

    await waitFor(() => {
      expect(adminApi.getMaintenanceHistory).toHaveBeenCalledWith(
        expect.objectContaining({ page: 1, limit: 10 })
      );
    });

    // Khi đổi filter Type sau khi đã chọn limit 10, vẫn giữ nguyên limit = 10 và reset về trang 1
    const typeSelect = selects[0];
    fireEvent.change(typeSelect, { target: { value: 'EMERGENCY' } });

    await waitFor(() => {
      expect(adminApi.getMaintenanceHistory).toHaveBeenCalledWith(
        expect.objectContaining({ page: 1, limit: 10, type: 'EMERGENCY' })
      );
    });
  });
});
