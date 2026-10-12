import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import AuditLogPage from '../pages/system/AuditLogPage';
import adminApi from '../api/admin.api';
import useSocket from '../hooks/useSocket';

vi.mock('../api/admin.api', () => ({
  default: {
    getAuditLogs: vi.fn(),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: vi.fn(),
}));

describe('Admin-web System Suite — AuditLogPage', () => {
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

  const mockLogs = [
    {
      id: 1,
      idlog: 1,
      idaccount: 'acc-1',
      request: 'POST /api/v1/auth/login',
      req_status: 'Pass',
      reason: null,
      time_req: '2026-03-10T10:00:00Z',
      time_res: '2026-03-10T10:00:00.050Z',
      account: {
        username: 'admin',
        User: { fullname: 'System Administrator' },
      },
    },
    {
      id: 2,
      idlog: 2,
      idaccount: 'acc-2',
      request: 'DELETE /api/v1/admin/categories/10',
      req_status: 'Rejected',
      reason: 'Cấm xóa danh mục người dùng',
      time_req: '2026-03-10T10:05:00Z',
      time_res: '2026-03-10T10:05:00.020Z',
      account: {
        username: 'attacker',
        User: { fullname: 'Suspicious User' },
      },
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
    useSocket.mockReturnValue(mockSocket);
    adminApi.getAuditLogs.mockResolvedValue({
      data: {
        items: mockLogs,
        total: 2,
      },
    });
  });

  it('4.1. Tải và hiển thị danh sách nhật ký kiểm toán (Audit Logs) đúng cấu trúc', async () => {
    render(<AuditLogPage />);

    await waitFor(() => {
      expect(adminApi.getAuditLogs).toHaveBeenCalledWith(
        expect.objectContaining({ page: 1, limit: 50 })
      );
      expect(screen.getByText('POST /api/v1/auth/login')).toBeInTheDocument();
      expect(screen.getByText('DELETE /api/v1/admin/categories/10')).toBeInTheDocument();
      expect(screen.getByText('Cấm xóa danh mục người dùng')).toBeInTheDocument();
    });
  });

  it('4.2. Lọc theo trạng thái yêu cầu cập nhật API getAuditLogs với status tương ứng', async () => {
    render(<AuditLogPage />);

    await waitFor(() => {
      expect(screen.getByText('POST /api/v1/auth/login')).toBeInTheDocument();
    });

    // Thay đổi combobox trạng thái sang 'Rejected' (combobox đầu tiên trong toolbar)
    const statusSelect = screen.getAllByRole('combobox')[0];
    fireEvent.change(statusSelect, { target: { value: 'Rejected' } });

    await waitFor(() => {
      expect(adminApi.getAuditLogs).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'Rejected',
          page: 1,
        })
      );
    });
  });

  it('4.3. Nhận sự kiện Socket audit_activity thời gian thực và chèn log mới vào đầu bảng', async () => {
    render(<AuditLogPage />);

    await waitFor(() => {
      expect(screen.getByText('POST /api/v1/auth/login')).toBeInTheDocument();
    });

    const auditHandler = socketListeners['audit_activity'];
    expect(auditHandler).toBeDefined();

    act(() => {
      auditHandler({
        id: 99,
        idaccount: 'acc-99',
        action: 'PATCH /api/v1/admin/users/status',
        status: 'Pass',
        reason: 'Khóa tài khoản vi phạm',
        time_req: '2026-03-10T10:15:00Z',
        time_res: '2026-03-10T10:15:00.030Z',
        user: 'security_officer',
      });
    });

    await waitFor(() => {
      expect(screen.getByText('PATCH /api/v1/admin/users/status')).toBeInTheDocument();
      expect(screen.getByText('Khóa tài khoản vi phạm')).toBeInTheDocument();
    });
  });

  it('4.4. Giới hạn số lượng bản ghi tối đa (Capping) không vượt quá 200 items', async () => {
    render(<AuditLogPage />);

    await waitFor(() => {
      const call = adminApi.getAuditLogs.mock.calls[0][0];
      expect(call.limit).toBeLessThanOrEqual(200);
    });
  });

  it('4.5. [Tầng 2 - System Impact] Nhận Socket event hiển thị đúng thời gian thực tế, không bị gạch ngang "—"', async () => {
    render(<AuditLogPage />);

    await waitFor(() => {
      expect(screen.getByText('POST /api/v1/auth/login')).toBeInTheDocument();
    });

    const auditHandler = socketListeners['audit_activity'];
    expect(auditHandler).toBeDefined();

    act(() => {
      auditHandler({
        id: 777,
        idaccount: 'acc-777',
        action: 'POST /api/v1/wallets/transfer',
        status: 'Pass',
        time_req: '2026-03-10T14:30:00.000Z',
        time_res: '2026-03-10T14:30:00.120Z',
        username: 'nguyen_van_a',
      });
    });

    await waitFor(() => {
      expect(screen.getByText('POST /api/v1/wallets/transfer')).toBeInTheDocument();
      const row = screen.getByText('POST /api/v1/wallets/transfer').closest('tr');
      expect(row).not.toBeNull();
      const cells = row.querySelectorAll('td');
      // Cột 5 (Thời gian gửi) và Cột 6 (Thời gian phản hồi) KHÔNG ĐƯỢC LÀ '—'
      expect(cells[5].textContent.trim()).not.toBe('—');
      expect(cells[6].textContent.trim()).not.toBe('—');
      expect(cells[5].textContent.trim().length).toBeGreaterThan(5);
      expect(cells[6].textContent.trim().length).toBeGreaterThan(5);
    });
  });

  it('4.6. [Tầng 2 - Deduplication] Bộ lọc trùng ID hoạt động chính xác giữa REST item (id) và Socket item (idlog)', async () => {
    render(<AuditLogPage />);

    await waitFor(() => {
      expect(screen.getByText('POST /api/v1/auth/login')).toBeInTheDocument();
    });

    const auditHandler = socketListeners['audit_activity'];
    // Emit lại sự kiện với cùng ID = 1 (trùng với mockLog 1 ban đầu)
    act(() => {
      auditHandler({
        id: 1,
        idaccount: 'acc-1',
        action: 'POST /api/v1/auth/login',
        status: 'Pass',
        time_req: '2026-03-10T10:00:00Z',
        time_res: '2026-03-10T10:00:00.050Z',
        username: 'admin',
      });
    });

    await waitFor(() => {
      // Số lượng row hiển thị không được tăng lên thành 2 row cùng có POST /api/v1/auth/login
      const rows = screen.getAllByText('POST /api/v1/auth/login');
      expect(rows.length).toBe(1);
    });
  });

  it('4.7. [Tầng 2 - Filter Matching] Khi đang lọc Rejected, log Rejected được chèn còn log Pass kích hoạt banner thông báo', async () => {
    render(<AuditLogPage />);

    await waitFor(() => {
      expect(screen.getByText('POST /api/v1/auth/login')).toBeInTheDocument();
    });

    // Chọn bộ lọc trạng thái sang 'Rejected'
    const statusSelect = screen.getAllByRole('combobox')[0];
    fireEvent.change(statusSelect, { target: { value: 'Rejected' } });

    const auditHandler = socketListeners['audit_activity'];

    // 1. Gửi log Pass (không khớp bộ lọc Rejected hiện tại)
    act(() => {
      auditHandler({
        id: 501,
        idaccount: 'acc-501',
        action: 'GET /api/v1/categories',
        status: 'Pass',
        time_req: '2026-03-10T16:00:00Z',
        time_res: '2026-03-10T16:00:00.020Z',
        username: 'user_pass',
      });
    });

    // Phải hiển thị banner thông báo sự kiện mới
    await waitFor(() => {
      expect(screen.getByTestId('new-logs-banner')).toBeInTheDocument();
    });

    // 2. Gửi log Rejected (khớp bộ lọc Rejected)
    act(() => {
      auditHandler({
        id: 502,
        idaccount: 'acc-502',
        action: 'POST /api/v1/admin/forbidden-action',
        status: 'Rejected',
        reason: 'Không đủ thẩm quyền',
        time_req: '2026-03-10T16:05:00Z',
        time_res: '2026-03-10T16:05:00.010Z',
        username: 'intruder',
      });
    });

    // Log Rejected khớp bộ lọc nên được chèn trực tiếp vào bảng
    await waitFor(() => {
      expect(screen.getByText('POST /api/v1/admin/forbidden-action')).toBeInTheDocument();
      expect(screen.getByText('Không đủ thẩm quyền')).toBeInTheDocument();
    });
  });

  it('4.8. [Tầng 2 - Pagination Alert] Khi ở trang > 1, sự kiện socket kích hoạt banner và nhấn nút đưa về trang 1', async () => {
    // Mock API trả về total: 100 để có nhiều trang
    adminApi.getAuditLogs.mockResolvedValueOnce({
      data: {
        items: mockLogs,
        total: 100,
      },
    });

    render(<AuditLogPage />);

    await waitFor(() => {
      expect(screen.getByText('POST /api/v1/auth/login')).toBeInTheDocument();
    });

    // Chuyển sang trang 2 bằng nút trang "2"
    const page2Btn = screen.getByRole('button', { name: '2' });
    fireEvent.click(page2Btn);

    const auditHandler = socketListeners['audit_activity'];
    act(() => {
      auditHandler({
        id: 888,
        idaccount: 'acc-888',
        action: 'POST /api/v1/transactions/create',
        status: 'Pass',
        time_req: '2026-03-10T17:00:00Z',
        time_res: '2026-03-10T17:00:00.030Z',
        username: 'user_page_2',
      });
    });

    // Phải xuất hiện banner thông báo sự kiện mới
    await waitFor(() => {
      expect(screen.getByTestId('new-logs-banner')).toBeInTheDocument();
    });

    // Click nút "Xem ngay" trên banner
    const viewBtn = screen.getByTestId('btn-view-new-logs');
    fireEvent.click(viewBtn);

    // Banner biến mất và API getAuditLogs được gọi lại cho trang 1
    await waitFor(() => {
      expect(screen.queryByTestId('new-logs-banner')).not.toBeInTheDocument();
      expect(adminApi.getAuditLogs).toHaveBeenCalledWith(
        expect.objectContaining({ page: 1 })
      );
    });
  });
});

