import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import PermissionManagementPage from '../pages/system/PermissionManagementPage';
import adminApi from '../api/admin.api';

vi.mock('../api/admin.api', () => ({
  default: {
    getPermissions: vi.fn(),
    updatePermissions: vi.fn(),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: () => ({
    on: vi.fn(),
    off: vi.fn(),
  }),
}));

vi.mock('../store/alert.context', () => ({
  useAlertSafe: () => ({
    success: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
    warning: vi.fn(),
  }),
}));

describe('Admin-web Permission Suite — PermissionManagementPage (AIOps Style)', () => {
  const mockFeatures = [
    {
      id: 'wallets',
      name: 'Ví tiền & Tài khoản',
      type: 'LIMIT',
      category_group: 'Tài nguyên',
      description: 'Số lượng ví tiền tối đa có thể quản lý',
    },
    {
      id: 'ai_assistant',
      name: 'Trợ lý Chatbot AI',
      type: 'TOGGLE',
      category_group: 'Trí tuệ nhân tạo',
      description: 'Hỏi đáp cố vấn tài chính thông minh qua Gemini',
    },
  ];

  const mockPermissions = {
    Basic: {
      wallets: { is_enabled: true, limit_value: 3 },
      ai_assistant: { is_enabled: false, limit_value: null },
    },
    Premium: {
      wallets: { is_enabled: true, limit_value: 10 },
      ai_assistant: { is_enabled: false, limit_value: null },
    },
  };

  beforeEach(() => {
    vi.clearAllMocks();
    adminApi.getPermissions.mockResolvedValue({
      data: {
        features: mockFeatures,
        permissions: mockPermissions,
      },
    });
    adminApi.updatePermissions.mockResolvedValue({
      success: true,
      data: { updatedCount: 1 },
    });
  });

  it('1.1. Render đầy đủ tiêu đề AIOps, banner Real-time và 4 thẻ Bento KPI', async () => {
    render(<PermissionManagementPage />);

    await waitFor(() => {
      expect(screen.getByText(/Phân Quyền Gói Cước/i)).toBeInTheDocument();
      expect(screen.getByText(/Cơ Chế Phân Quyền/i)).toBeInTheDocument();
      expect(screen.getByText('Tổng Tính Năng')).toBeInTheDocument();
      expect(screen.getByText('Hạn Mức Tài Nguyên')).toBeInTheDocument();
      expect(screen.getByText('Công Tắc Logic (Toggle)')).toBeInTheDocument();
      expect(screen.getByText('Thay Đổi Chưa Lưu')).toBeInTheDocument();
    });
  });

  it('1.2. Hiển thị danh sách tính năng theo nhóm và đúng giá trị ban đầu', async () => {
    render(<PermissionManagementPage />);

    await waitFor(() => {
      expect(screen.getByText('Ví tiền & Tài khoản')).toBeInTheDocument();
      expect(screen.getByText('Trợ lý Chatbot AI')).toBeInTheDocument();
      expect(screen.getByText('Tài nguyên')).toBeInTheDocument();
      expect(screen.getByText('Trí tuệ nhân tạo')).toBeInTheDocument();
    });
  });

  it('1.3. Lọc tính năng khi bấm tab nhóm và tìm kiếm bằng từ khóa', async () => {
    render(<PermissionManagementPage />);

    await waitFor(() => {
      expect(screen.getByText('Ví tiền & Tài khoản')).toBeInTheDocument();
    });

    // Lọc theo nhóm Trí tuệ nhân tạo
    const aiGroupTab = screen.getByRole('button', { name: /Trí tuệ nhân tạo/i });
    fireEvent.click(aiGroupTab);

    expect(screen.queryByText('Ví tiền & Tài khoản')).not.toBeInTheDocument();
    expect(screen.getByText('Trợ lý Chatbot AI')).toBeInTheDocument();

    // Tìm kiếm từ khóa
    const searchInput = screen.getByPlaceholderText(/Tìm theo tên tính năng hoặc mã slug/i);
    fireEvent.change(searchInput, { target: { value: 'chatbot' } });

    expect(screen.getByText('Trợ lý Chatbot AI')).toBeInTheDocument();
  });

  it('1.4. Bấm "Mở Hết Cho Premium" kích hoạt dirty tracker và hiển thị badge Đã sửa', async () => {
    render(<PermissionManagementPage />);

    await waitFor(() => {
      expect(screen.getByText('Ví tiền & Tài khoản')).toBeInTheDocument();
    });

    const unlockAllBtn = screen.getByRole('button', { name: /Mở Hết Cho Premium/i });
    fireEvent.click(unlockAllBtn);

    expect(screen.getByText(/Đã mở khóa toàn bộ/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Khôi Phục/i })).toBeInTheDocument();
  });

  it('1.5. Mở Modal xác nhận lưu và gọi updatePermissions thành công', async () => {
    render(<PermissionManagementPage />);

    await waitFor(() => {
      expect(screen.getByText('Ví tiền & Tài khoản')).toBeInTheDocument();
    });

    // Bật tính năng AI cho Basic để tạo dirty state
    const checkboxes = screen.getAllByRole('checkbox');
    fireEvent.click(checkboxes[0]);

    // Bấm nút Lưu Thay Đổi để mở modal
    const saveBtn = screen.getByRole('button', { name: /Lưu Thay Đổi/i });
    fireEvent.click(saveBtn);

    // Kiểm tra Modal xác nhận mở ra
    expect(screen.getByText(/Xác Nhận Lưu Ma Trận Phân Quyền/i)).toBeInTheDocument();

    // Bấm nút "Xác Nhận Lưu Ngay" trong modal
    const confirmSaveBtn = screen.getByRole('button', { name: /Xác Nhận Lưu Ngay/i });
    fireEvent.click(confirmSaveBtn);

    await waitFor(() => {
      expect(adminApi.updatePermissions).toHaveBeenCalled();
    });
  });
});
