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

  it('3.6. [Tầng 1 - UI] Modal lọc dữ liệu: Chuyển đổi trạng thái bằng checkbox, chọn Tất cả thì toàn bộ trạng thái con được check theo, bỏ chọn 1 con thì Tất cả uncheck', async () => {
    render(<UserListPage />);

    await waitFor(() => {
      expect(screen.getByText('Nguyễn Văn A')).toBeInTheDocument();
    });

    // Mở modal lọc
    const filterBtn = screen.getByRole('button', { name: /bộ lọc/i });
    fireEvent.click(filterBtn);

    // Kiểm tra modal xuất hiện
    expect(screen.getByText('Lọc dữ liệu')).toBeInTheDocument();

    // Checkbox Tất cả và các checkbox trạng thái con
    const allCheckbox = screen.getByTestId('filter-status-all');
    const activeCheckbox = screen.getByTestId('filter-status-active');
    const inactiveCheckbox = screen.getByTestId('filter-status-inactive');
    const pendingDeleteCheckbox = screen.getByTestId('filter-status-pendingdelete');
    const deletedCheckbox = screen.getByTestId('filter-status-deleted');

    // Mặc định ban đầu: Tất cả đều được check
    expect(allCheckbox).toBeChecked();
    expect(activeCheckbox).toBeChecked();
    expect(inactiveCheckbox).toBeChecked();
    expect(pendingDeleteCheckbox).toBeChecked();
    expect(deletedCheckbox).toBeChecked();

    // Thao tác 1: Bỏ chọn checkbox con 'deleted'
    fireEvent.click(deletedCheckbox);
    expect(deletedCheckbox).not.toBeChecked();
    // Kỳ vọng: Checkbox 'Tất cả' tự động bị uncheck
    expect(allCheckbox).not.toBeChecked();
    expect(activeCheckbox).toBeChecked();
    expect(inactiveCheckbox).toBeChecked();
    expect(pendingDeleteCheckbox).toBeChecked();

    // Thao tác 2: Chọn lại checkbox 'deleted' -> Đủ tất cả 4 con -> 'Tất cả' tự động được check theo
    fireEvent.click(deletedCheckbox);
    expect(deletedCheckbox).toBeChecked();
    expect(allCheckbox).toBeChecked();

    // Thao tác 3: Click bỏ chọn checkbox 'Tất cả' -> Toàn bộ các trạng thái con bị uncheck theo
    fireEvent.click(allCheckbox);
    expect(allCheckbox).not.toBeChecked();
    expect(activeCheckbox).not.toBeChecked();
    expect(inactiveCheckbox).not.toBeChecked();
    expect(pendingDeleteCheckbox).not.toBeChecked();
    expect(deletedCheckbox).not.toBeChecked();

    // Thao tác 4: Click chọn lại checkbox 'Tất cả' -> Toàn bộ các trạng thái con được check theo
    fireEvent.click(allCheckbox);
    expect(allCheckbox).toBeChecked();
    expect(activeCheckbox).toBeChecked();
    expect(inactiveCheckbox).toBeChecked();
    expect(pendingDeleteCheckbox).toBeChecked();
    expect(deletedCheckbox).toBeChecked();
  });

  it('3.7. [Tầng 2 - System Impact] Bộ lọc nhiều trạng thái: Lọc chính xác danh sách người dùng theo các trạng thái được check', async () => {
    render(<UserListPage />);

    await waitFor(() => {
      expect(screen.getByText('Nguyễn Văn A')).toBeInTheDocument();
      expect(screen.getByText('Trần Thị B')).toBeInTheDocument();
      expect(screen.getByText('Lê Văn C')).toBeInTheDocument();
    });

    // Mở modal lọc
    const filterBtn = screen.getByRole('button', { name: /bộ lọc/i });
    fireEvent.click(filterBtn);

    const allCheckbox = screen.getByTestId('filter-status-all');
    const activeCheckbox = screen.getByTestId('filter-status-active');
    const pendingDeleteCheckbox = screen.getByTestId('filter-status-pendingdelete');

    // Bỏ chọn Tất cả -> Bỏ chọn hết
    fireEvent.click(allCheckbox);

    // Chỉ chọn Active và PendingDelete (chọn 2 trạng thái cùng lúc)
    fireEvent.click(activeCheckbox);
    fireEvent.click(pendingDeleteCheckbox);

    // Nhấp nút Áp dụng
    const applyBtn = screen.getByRole('button', { name: /^áp dụng$/i });
    fireEvent.click(applyBtn);

    // Modal đóng lại
    expect(screen.queryByText('Lọc dữ liệu')).not.toBeInTheDocument();

    // Kiểm tra tác động hệ thống:
    // Hiển thị: Nguyễn Văn A (Active) và Lê Văn C (PendingDelete)
    expect(screen.getByText('Nguyễn Văn A')).toBeInTheDocument();
    expect(screen.getByText('Lê Văn C')).toBeInTheDocument();
    // Ẩn hoàn toàn: Trần Thị B (Inactive)
    expect(screen.queryByText('Trần Thị B')).not.toBeInTheDocument();

    // Mở lại modal và nhấn nút "Đặt lại"
    fireEvent.click(screen.getByRole('button', { name: /bộ lọc/i }));
    const resetBtn = screen.getByRole('button', { name: /đặt lại/i });
    fireEvent.click(resetBtn);

    // Kiểm tra tất cả người dùng lại xuất hiện đầy đủ
    expect(screen.getByText('Nguyễn Văn A')).toBeInTheDocument();
    expect(screen.getByText('Trần Thị B')).toBeInTheDocument();
    expect(screen.getByText('Lê Văn C')).toBeInTheDocument();
  });
});
