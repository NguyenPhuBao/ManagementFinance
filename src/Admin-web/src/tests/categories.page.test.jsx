import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import CategoryPage from '../pages/categories/CategoryPage';
import adminApi from '../api/admin.api';

vi.mock('../api/admin.api', () => ({
  default: {
    getCategories: vi.fn(),
    createCategory: vi.fn(),
    updateCategory: vi.fn(),
    deleteCategory: vi.fn(),
  },
}));

describe('Admin-web Categories Suite — CategoryPage', () => {
  const mockCategories = [
    {
      id: 1,
      name: 'Ăn uống',
      classify: 'Chi',
      keyword: 'an uong, com, pho',
      is_default: true,
      create_at: '2026-01-01T00:00:00Z',
    },
    {
      id: 2,
      name: 'Lương & Thưởng',
      classify: 'Thu',
      keyword: 'luong, cong ty, thuong',
      is_default: true,
      create_at: '2026-01-01T00:00:00Z',
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
    window.alert = vi.fn();
    adminApi.getCategories.mockResolvedValue({ data: mockCategories });
  });

  it('2.1. Tải và hiển thị danh mục mặc định với query bắt buộc is_default = true', async () => {
    render(<CategoryPage />);

    await waitFor(() => {
      expect(adminApi.getCategories).toHaveBeenCalledWith(
        expect.objectContaining({ is_default: true })
      );
      expect(screen.getByText('Ăn uống')).toBeInTheDocument();
      expect(screen.getByText('Lương & Thưởng')).toBeInTheDocument();
    });
  });

  it('2.2. Nút "Làm mới" gọi lại API fetchCategories để đồng bộ thủ công (Không dùng Socket.io theo chỉ đạo PO)', async () => {
    render(<CategoryPage />);

    await waitFor(() => {
      expect(screen.getByText('Ăn uống')).toBeInTheDocument();
    });

    const refreshBtn = screen.getByTitle('Làm mới danh sách danh mục');
    fireEvent.click(refreshBtn);

    await waitFor(() => {
      expect(adminApi.getCategories).toHaveBeenCalledTimes(2);
    });
  });

  it('2.3. Phòng thủ quyền riêng tư: Tự động che dấu (masking) danh mục nếu thuộc người dùng cá nhân', async () => {
    adminApi.getCategories.mockResolvedValueOnce({
      data: [
        {
          id: 99,
          name: 'Quỹ đen cá nhân',
          classify: 'Chi',
          keyword: 'mat_mat',
          is_default: false,
          is_user_category: true,
        },
      ],
    });

    render(<CategoryPage />);

    await waitFor(() => {
      // Tên danh mục và keyword bị ẩn thành ***
      const maskedItems = screen.getAllByText('***');
      expect(maskedItems.length).toBeGreaterThanOrEqual(1);
      expect(screen.queryByText('Quỹ đen cá nhân')).not.toBeInTheDocument();
    });
  });

  it('2.4. Ngăn chặn tạo danh mục hệ thống trùng tên (Client-side validation)', async () => {
    render(<CategoryPage />);

    await waitFor(() => {
      expect(screen.getByText('Ăn uống')).toBeInTheDocument();
    });

    // Mở modal Thêm danh mục
    const addBtn = screen.getByText('Thêm danh mục mới');
    fireEvent.click(addBtn);

    // Nhập tên trùng với danh mục hệ thống đã có: 'Ăn uống'
    const nameInput = screen.getByPlaceholderText('Nhập tên danh mục');
    fireEvent.change(nameInput, { target: { value: 'ăn uống' } });

    const submitBtn = screen.getByRole('button', { name: /^Lưu$/i });
    fireEvent.click(submitBtn);

    expect(window.alert).toHaveBeenCalledWith(
      expect.stringContaining('đã tồn tại trong hệ thống. Không được phép tạo/đổi trùng tên!')
    );
    expect(adminApi.createCategory).not.toHaveBeenCalled();
  });

  it('2.5. Tạo danh mục hệ thống mới hợp lệ gửi API createCategory với is_default = true', async () => {
    adminApi.createCategory.mockResolvedValueOnce({ data: { id: 3, name: 'Đầu tư' } });

    render(<CategoryPage />);

    await waitFor(() => {
      expect(screen.getByText('Ăn uống')).toBeInTheDocument();
    });

    // Mở modal Thêm danh mục
    fireEvent.click(screen.getByText('Thêm danh mục mới'));

    const nameInput = screen.getByPlaceholderText('Nhập tên danh mục');
    fireEvent.change(nameInput, { target: { value: 'Đầu tư vàng' } });

    const submitBtn = screen.getByRole('button', { name: /^Lưu$/i });
    fireEvent.click(submitBtn);

    await waitFor(() => {
      expect(adminApi.createCategory).toHaveBeenCalledWith(
        expect.objectContaining({
          name: 'Đầu tư vàng',
          is_default: true,
        })
      );
    });
  });
});
