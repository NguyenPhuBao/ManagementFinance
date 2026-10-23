import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import AuditLogPage from '../pages/system/AuditLogPage';
import adminApi from '../api/admin.api';
import useSocket from '../hooks/useSocket';
import * as csvExporter from '../utils/csv-exporter.util';

vi.mock('../api/admin.api', () => ({
  default: {
    getAuditLogs: vi.fn(),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: vi.fn(),
}));

vi.mock('../utils/csv-exporter.util', () => ({
  exportToCsv: vi.fn(),
}));

describe('Audit Log Refinement — 2-Tier Architecture Test Suite (Rule 11)', () => {
  const mockSocket = {
    connected: true,
    on: vi.fn(),
    off: vi.fn(),
  };

  const mockLogs = [
    {
      id: 101,
      idlog: 101,
      idaccount: 'acc-101',
      request: 'POST /api/v1/payments/create-order',
      action: 'POST /api/v1/payments/create-order', // Chuỗi API thô cần chuẩn hóa
      req_status: 'Pass',
      reason: null,
      time_req: '2026-03-10T10:00:00Z',
      time_res: '2026-03-10T10:00:00.050Z',
      account: {
        username: 'buyer_vip',
        User: { fullname: 'Nguyen Van VIP' },
      },
    },
    {
      id: 102,
      idlog: 102,
      idaccount: 'acc-102',
      request: 'PUT /api/admin/permissions',
      action: 'PUT /api/admin/permissions', // Chuỗi API thô quản trị
      req_status: 'Pass',
      reason: null,
      time_req: '2026-03-10T11:00:00Z',
      time_res: '2026-03-10T11:00:00.080Z',
      account: {
        username: 'lead_admin',
        User: { fullname: 'Lead Admin' },
      },
    },
    {
      id: 103,
      idlog: 103,
      idaccount: 'acc-103',
      request: 'POST /api/admin/verify-security-action',
      action: 'POST /api/admin/verify-security-action',
      req_status: 'Rejected',
      reason: 'Mã PIN bảo mật không chính xác',
      time_req: '2026-03-10T12:00:00Z',
      time_res: '2026-03-10T12:00:00.030Z',
      account: {
        username: 'lead_admin',
        User: { fullname: 'Lead Admin' },
      },
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
    useSocket.mockReturnValue(mockSocket);
    adminApi.getAuditLogs.mockResolvedValue({
      data: {
        items: mockLogs,
        total: 3,
      },
    });
  });

  // =========================================================================
  // 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN (UI RENDERING & INTERACTION)
  // =========================================================================
  describe('Tầng 1: Hiển thị & Thao tác Giao diện (UI Rendering & Interaction)', () => {
    it('1.1. Header: Loại bỏ subtitle dài và icon fact_check theo đúng yêu cầu từ PO', async () => {
      render(<AuditLogPage />);

      await waitFor(() => {
        expect(screen.getByText('Nhật Ký Hoạt Động')).toBeInTheDocument();
      });

      // Kiểm tra subtitle dài đã bị gỡ bỏ hoàn toàn
      expect(
        screen.queryByText(/Lưu vết toàn bộ thao tác và request gửi về hệ thống/i)
      ).toBeNull();

      // Kiểm tra icon fact_check không còn xuất hiện trong Header
      const headerTitle = screen.getByText('Nhật Ký Hoạt Động').closest('h1');
      expect(headerTitle.querySelector('.material-symbols-outlined')).toBeNull();
    });

    it('1.2. Header: Badge Real-time nằm ngay cạnh tiêu đề "Nhật Ký Hoạt Động"', async () => {
      render(<AuditLogPage />);

      await waitFor(() => {
        expect(screen.getByText('Real-time')).toBeInTheDocument();
      });

      const titleEl = screen.getByText('Nhật Ký Hoạt Động');
      const realtimeBadge = screen.getByText('Real-time');
      const parentContainer = titleEl.parentElement;

      // Cả 2 phần tử phải nằm chung trong container flex tiêu đề
      expect(parentContainer).toContainElement(titleEl);
      expect(parentContainer).toContainElement(realtimeBadge);
    });

    it('1.3. Header: Nút Đặt lại không còn tồn tại trên Header bên phải', async () => {
      render(<AuditLogPage />);

      await waitFor(() => {
        expect(screen.getByText('Xuất CSV')).toBeInTheDocument();
        expect(screen.getByText('Làm mới')).toBeInTheDocument();
      });

      // Header bên phải chỉ chứa Xuất CSV và Làm mới, không còn nút Đặt lại
      const exportBtn = screen.getByText('Xuất CSV').closest('div');
      expect(exportBtn.querySelector('button[title*="Xóa bộ lọc"]')).toBeNull();
    });

    it('1.4. Thanh lọc: Nút Đặt lại nằm ở góc phải ngoài cùng và cụm ngày được tối giản viền', async () => {
      render(<AuditLogPage />);

      await waitFor(() => {
        expect(screen.getByPlaceholderText('Tìm thao tác hoặc username...')).toBeInTheDocument();
      });

      // Nút Đặt lại nằm trong Toolbar bộ lọc
      const resetFilterBtn = screen.getByRole('button', { name: /Đặt lại/i });
      expect(resetFilterBtn).toBeInTheDocument();
      expect(resetFilterBtn.closest('div').classList.contains('ml-auto')).toBe(true);

      // Cụm ngày có icon lịch và cả 2 nhãn Từ - Đến
      expect(screen.getByText('Từ:')).toBeInTheDocument();
      expect(screen.getByText('Đến:')).toBeInTheDocument();
      expect(screen.getByText('calendar_month')).toBeInTheDocument();
    });
  });

  // =========================================================================
  // ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ (REAL SYSTEM IMPACT & BEHAVIOR)
  // =========================================================================
  describe('Tầng 2: Tác động Hệ thống & Hoạt động Nghiệp vụ Thực tế (System Impact)', () => {
    it('2.1. [Chuẩn hóa Hành động] Dịch 100% chuỗi API thô sang câu nghiệp vụ tiếng Việt, không để lọt raw API vào cột Hành động', async () => {
      render(<AuditLogPage />);

      await waitFor(() => {
        // Cột Hành động cho đơn hàng thanh toán
        expect(screen.getByText('[PAYMENT]')).toBeInTheDocument();
        expect(screen.getByText('Tạo đơn hàng thanh toán gói cước')).toBeInTheDocument();

        // Cột Hành động cho phân quyền quản trị
        expect(screen.getByText('[SYSTEM]')).toBeInTheDocument();
        expect(screen.getByText('Cập nhật phân quyền gói cước')).toBeInTheDocument();

        // Cột Hành động cho xác thực mã PIN
        expect(screen.getByText('[AUTH]')).toBeInTheDocument();
        expect(screen.getByText('Xác thực mã PIN bảo mật')).toBeInTheDocument();

        // Cột Yêu cầu API hiển thị đúng method badge và endpoint
        expect(screen.getByText('/api/v1/payments/create-order')).toBeInTheDocument();
        expect(screen.getByText('/api/admin/permissions')).toBeInTheDocument();
        expect(screen.getByText('/api/admin/verify-security-action')).toBeInTheDocument();
      });
    });

    it('2.2. [Thao tác Đặt lại] Nhấn nút Đặt lại xóa sạch bộ lọc và gọi lại API getAuditLogs với tham số mặc định', async () => {
      render(<AuditLogPage />);

      await waitFor(() => {
        expect(screen.getByPlaceholderText('Tìm thao tác hoặc username...')).toBeInTheDocument();
      });

      // Nhập từ khóa tìm kiếm và chọn trạng thái
      const searchInput = screen.getByPlaceholderText('Tìm thao tác hoặc username...');
      fireEvent.change(searchInput, { target: { value: 'buyer_vip' } });

      const selects = screen.getAllByRole('combobox');
      fireEvent.change(selects[0], { target: { value: 'Pass' } });

      await waitFor(() => {
        expect(adminApi.getAuditLogs).toHaveBeenCalledWith(
          expect.objectContaining({ search: 'buyer_vip', status: 'Pass' })
        );
      });

      // Nhấn nút Đặt lại trên thanh lọc
      const resetBtn = screen.getByRole('button', { name: /Đặt lại/i });
      fireEvent.click(resetBtn);

      await waitFor(() => {
        // Input phải bị xóa về rỗng
        expect(searchInput.value).toBe('');
        expect(selects[0].value).toBe('');

        // API getAuditLogs được gọi lại không còn search hay status
        const lastCall = adminApi.getAuditLogs.mock.calls[adminApi.getAuditLogs.mock.calls.length - 1][0];
        expect(lastCall.search).toBeUndefined();
        expect(lastCall.status).toBeUndefined();
        expect(lastCall.startDate).toBeUndefined();
        expect(lastCall.endDate).toBeUndefined();
      });
    });

    it('2.3. [Lọc khoảng ngày] Thay đổi Từ ngày và Đến ngày gửi đúng tham số startDate/endDate lên backend', async () => {
      const { container } = render(<AuditLogPage />);

      await waitFor(() => {
        expect(screen.getByText('Nhật Ký Hoạt Động')).toBeInTheDocument();
      });

      const dateInputs = container.querySelectorAll('input[type="date"]');
      expect(dateInputs.length).toBe(2);

      // Nhập Từ ngày và Đến ngày
      await waitFor(() => {
        fireEvent.change(dateInputs[0], { target: { value: '2026-03-01' } });
        fireEvent.change(dateInputs[1], { target: { value: '2026-03-15' } });
      });

      await waitFor(() => {
        expect(adminApi.getAuditLogs).toHaveBeenCalledWith(
          expect.objectContaining({
            startDate: '2026-03-01',
            endDate: '2026-03-15T23:59:59',
          })
        );
      });

      // Bấm nút xóa nhanh ngày (icon close)
      const clearBtn = screen.getByTitle('Xóa');
      expect(clearBtn).toBeInTheDocument();
      fireEvent.click(clearBtn);

      expect(dateInputs[0].value).toBe('');
      expect(dateInputs[1].value).toBe('');
    });

    it('2.4. [Xuất CSV bảo toàn câu tiếng Việt] Xuất CSV sử dụng câu mô tả nghiệp vụ chuẩn hóa cho cột Hành động', async () => {
      render(<AuditLogPage />);

      await waitFor(() => {
        expect(screen.getByText('Xuất CSV')).toBeInTheDocument();
      });

      const exportBtn = screen.getByRole('button', { name: /Xuất CSV/i });
      fireEvent.click(exportBtn);

      await waitFor(() => {
        expect(csvExporter.exportToCsv).toHaveBeenCalled();
        const exportCall = csvExporter.exportToCsv.mock.calls[0][0];

        // Headers phải chuẩn
        expect(exportCall.headers).toContain('Hành động');
        expect(exportCall.headers).toContain('Phân loại');

        // Rows phải chứa câu tiếng Việt thay vì raw API path
        const rows = exportCall.rows;
        expect(rows.length).toBe(3);
        const actionColValues = rows.map((r) => r[5]); // Cột index 5 là Hành động
        expect(actionColValues).toContain('Tạo đơn hàng thanh toán gói cước');
        expect(actionColValues).toContain('Cập nhật phân quyền gói cước');
        expect(actionColValues).toContain('Xác thực mã PIN bảo mật');
      });
    });
  });
});
