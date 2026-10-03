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
});
