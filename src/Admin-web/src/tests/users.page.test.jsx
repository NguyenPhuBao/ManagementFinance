import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import UserListPage from '../pages/users/UserListPage';
import adminApi from '../api/admin.api';
import useSocket from '../hooks/useSocket';

vi.mock('../api/admin.api', () => ({
  default: {
    getUsers: vi.fn(),
    updateUserStatus: vi.fn(),
    deleteUser: vi.fn(),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: vi.fn(),
}));

describe('Admin-web Users Suite — UserListPage', () => {
  const socketListeners = {};
  const mockSocket = {
    on: vi.fn((event, cb) => {
      socketListeners[event] = cb;
    }),
    off: vi.fn((event) => {
      delete socketListeners[event];
    }),
  };

  const mockUsers = [
    {
      id: 1,
      idaccount: 'acc-1',
      fullname: 'Nguyễn Văn A',
      email: 'nguyenvana@example.com',
      phone: '0901234567',
      status: 'Active',
      username: 'nguyenvana',
      created_at: '2026-01-01T00:00:00Z',
    },
    {
      id: 2,
      idaccount: 'acc-2',
      fullname: 'Trần Thị B',
      email: 'tranthib@example.com',
      phone: '0987654321',
      status: 'Inactive',
      reason_inactive: 'Vi phạm điều khoản dịch vụ',
      username: 'tranthib',
      created_at: '2026-01-02T00:00:00Z',
    },
    {
      id: 3,
      idaccount: 'acc-3',
      fullname: 'Lê Văn C',
      email: 'levanc@example.com',
      phone: '0912345678',
      status: 'PendingDelete',
      countdown: 28,
      username: 'levanc',
      created_at: '2026-01-03T00:00:00Z',
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
    useSocket.mockReturnValue(mockSocket);
    adminApi.getUsers.mockResolvedValue({ data: mockUsers });
  });

  it('3.1. Tải và hiển thị danh sách người dùng đầy đủ các trạng thái', async () => {
    render(<UserListPage />);

    await waitFor(() => {
      expect(adminApi.getUsers).toHaveBeenCalledTimes(1);
      expect(screen.getByText('Nguyễn Văn A')).toBeInTheDocument();
      expect(screen.getByText('Trần Thị B')).toBeInTheDocument();
      expect(screen.getByText('Lê Văn C')).toBeInTheDocument();
    });
  });

  it('3.2. Hiển thị badge PendingDelete "Chờ xóa (28 ngày)" và khóa hành động "Chỉ xem"', async () => {
    render(<UserListPage />);

    await waitFor(() => {
      expect(screen.getByText('Chờ xóa (28 ngày)')).toBeInTheDocument();
      expect(screen.getByText('Chỉ xem')).toBeInTheDocument();
    });
  });

  it('3.3. Vô hiệu hóa tài khoản Active bắt buộc phải nhập lý do (reason_inactive)', async () => {
    adminApi.updateUserStatus.mockResolvedValueOnce({ data: { success: true } });

    render(<UserListPage />);

    await waitFor(() => {
      expect(screen.getByText('Nguyễn Văn A')).toBeInTheDocument();
    });

    // Click nút Vô hiệu hóa của user Active
    const inactivateRowBtn = screen.getAllByRole('button', { name: /^Vô hiệu hóa$/i })[0];
    fireEvent.click(inactivateRowBtn);

    // Kiểm tra modal vô hiệu hóa mở ra
    expect(screen.getByText(/Tài khoản vô hiệu hóa:/i)).toBeInTheDocument();

    // Nút submit vô hiệu hóa bị disable khi lý do rỗng
    const submitBtn = screen.getAllByRole('button', { name: /^Vô hiệu hóa$/i }).slice(-1)[0];
    expect(submitBtn).toBeDisabled();

    // Nhập lý do hợp lệ
    const reasonInput = screen.getByPlaceholderText(/Nhập lý do vô hiệu hóa/i);
    fireEvent.change(reasonInput, { target: { value: 'Nghi vấn lừa đảo giao dịch' } });
    expect(submitBtn).not.toBeDisabled();

    fireEvent.click(submitBtn);

    await waitFor(() => {
      expect(adminApi.updateUserStatus).toHaveBeenCalledWith(1, {
        status: 'Inactive',
        reason_inactive: 'Nghi vấn lừa đảo giao dịch',
      });
    });
  });

  it('3.4. Kích hoạt tài khoản Inactive gọi API với status = "Active"', async () => {
    adminApi.updateUserStatus.mockResolvedValueOnce({ data: { success: true } });

    render(<UserListPage />);

    await waitFor(() => {
      expect(screen.getByText('Trần Thị B')).toBeInTheDocument();
    });

    // Click nút Kích hoạt của user Inactive
    const activateRowBtn = screen.getAllByRole('button', { name: /^Kích hoạt$/i })[0];
    fireEvent.click(activateRowBtn);

    // Modal kích hoạt xuất hiện
    expect(screen.getByText(/Bạn có chắc chắn muốn kích hoạt lại tài khoản/i)).toBeInTheDocument();

    // Nút xác nhận Kích hoạt bên trong modal (nút Kích hoạt cuối cùng)
    const modalActivateBtn = screen.getAllByRole('button', { name: /^Kích hoạt$/i }).slice(-1)[0];
    fireEvent.click(modalActivateBtn);

    await waitFor(() => {
      expect(adminApi.updateUserStatus).toHaveBeenCalledWith(2, {
        status: 'Active',
      });
    });
  });

  it('3.5. Cập nhật trạng thái người dùng theo thời gian thực khi nhận sự kiện Socket admin.user_status_changed', async () => {
    render(<UserListPage />);

    await waitFor(() => {
      expect(screen.getByText('Nguyễn Văn A')).toBeInTheDocument();
    });

    // Giả lập Socket.io server bắn sự kiện user 1 chuyển sang PendingDelete
    const statusHandler = socketListeners['admin.user_status_changed'];
    expect(statusHandler).toBeDefined();

    act(() => {
      statusHandler({
        iduser: 1,
        idaccount: 'acc-1',
        status: 'pendingdelete',
        countdown: 30,
      });
    });

    await waitFor(() => {
      expect(screen.getByText('Chờ xóa (30 ngày)')).toBeInTheDocument();
    });
  });
});
