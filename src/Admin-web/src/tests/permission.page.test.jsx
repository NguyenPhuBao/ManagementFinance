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

  it('1.1. Render đầy đủ tiêu đề Phân quyền dịch vụ, thanh công cụ tối giản và bảng ma trận (không có nút refresh)', async () => {
    render(<PermissionManagementPage />);

    await waitFor(() => {
      expect(screen.getByText(/Phân quyền dịch vụ/i)).toBeInTheDocument();
      expect(screen.queryByTestId('btn-refresh')).not.toBeInTheDocument();
      expect(screen.getByTestId('btn-reset-default')).toBeInTheDocument();
      expect(screen.getByTestId('btn-save-permissions')).toBeInTheDocument();
    });
  });

  it('1.2. Hiển thị danh sách tính năng theo nhóm và đúng giá trị ban đầu', async () => {
    render(<PermissionManagementPage />);

    await waitFor(() => {
      expect(screen.getByText('Ví tiền & Tài khoản')).toBeInTheDocument();
      expect(screen.getByText('Trợ lý Chatbot AI')).toBeInTheDocument();
      expect(screen.getAllByText(/Tài nguyên/).length).toBeGreaterThan(0);
      expect(screen.getAllByText(/Trí tuệ nhân tạo/).length).toBeGreaterThan(0);
    });
  });

  it('1.3. Lọc tính năng khi bấm tab nhóm và tìm kiếm bằng từ khóa', async () => {
    render(<PermissionManagementPage />);

    await waitFor(() => {
      expect(screen.getByText('Ví tiền & Tài khoản')).toBeInTheDocument();
    });

    // Lọc theo nhóm Trí tuệ nhân tạo qua select dropdown
    const groupSelect = screen.getByTestId('select-group-filter');
    fireEvent.change(groupSelect, { target: { value: 'Trí tuệ nhân tạo' } });

    expect(screen.queryByText('Ví tiền & Tài khoản')).not.toBeInTheDocument();
    expect(screen.getByText('Trợ lý Chatbot AI')).toBeInTheDocument();

    // Tìm kiếm từ khóa
    const searchInput = screen.getByTestId('input-search-features');
    fireEvent.change(searchInput, { target: { value: 'chatbot' } });

    expect(screen.getByText('Trợ lý Chatbot AI')).toBeInTheDocument();
  });

  it('1.4. Thay đổi quyền kích hoạt dirty tracker và nút Lưu Thay Đổi', async () => {
    render(<PermissionManagementPage />);

    await waitFor(() => {
      expect(screen.getByText('Ví tiền & Tài khoản')).toBeInTheDocument();
    });

    const checkboxes = screen.getAllByRole('checkbox');
    fireEvent.click(checkboxes[0]);

    const saveBtn = screen.getByRole('button', { name: /Lưu Thay Đổi/i });
    expect(saveBtn).not.toBeDisabled();
  });

  it('1.5. Mở Modal xác nhận lưu và gọi updatePermissions thành công', async () => {
    render(<PermissionManagementPage />);

    await waitFor(() => {
      expect(screen.getByText('Ví tiền & Tài khoản')).toBeInTheDocument();
    });

    // Bật tính năng để tạo dirty state
    const checkboxes = screen.getAllByRole('checkbox');
    fireEvent.click(checkboxes[0]);

    // Bấm nút Lưu Thay Đổi để mở modal
    const saveBtn = screen.getByRole('button', { name: /Lưu Thay Đổi/i });
    fireEvent.click(saveBtn);

    // Kiểm tra Modal xác nhận mở ra
    expect(screen.getByText(/Xác Nhận Lưu Thay Đổi/i)).toBeInTheDocument();

    // Bấm nút "Xác Nhận Lưu" trong modal
    const confirmSaveBtn = screen.getByTestId('btn-confirm-save');
    fireEvent.click(confirmSaveBtn);

    await waitFor(() => {
      expect(adminApi.updatePermissions).toHaveBeenCalled();
    });
  });
});

