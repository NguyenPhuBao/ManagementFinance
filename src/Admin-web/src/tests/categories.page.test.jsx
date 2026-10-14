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

  it('2.6. [Tầng 1 & Tầng 2] Xóa mềm danh mục: Danh mục không biến mất, hiển thị badge Đã xóa và cột hành động hiện Đã xóa', async () => {
    adminApi.deleteCategory.mockResolvedValueOnce({ data: { success: true } });
    adminApi.getCategories
      .mockResolvedValueOnce({ data: mockCategories })
      .mockResolvedValueOnce({
        data: [
          {
            id: 1,
            name: 'Ăn uống',
            classify: 'Chi',
            keyword: 'an uong, com, pho',
            is_default: true,
            status: 'deleted',
            delete_at: '2026-10-14T00:00:00Z',
            create_at: '2026-01-01T00:00:00Z',
          },
          {
            id: 2,
            name: 'Lương & Thưởng',
            classify: 'Thu',
            keyword: 'luong, cong ty, thuong',
            is_default: true,
            status: 'active',
            delete_at: null,
            create_at: '2026-01-01T00:00:00Z',
          },
        ],
      });

    render(<CategoryPage />);

    await waitFor(() => {
      expect(screen.getByText('Ăn uống')).toBeInTheDocument();
    });

    // Bấm nút xóa trên dòng của danh mục "Ăn uống"
    const deleteBtns = screen.getAllByTitle('Xóa danh mục hệ thống');
    fireEvent.click(deleteBtns[0]);

    // Modal xác nhận xóa xuất hiện
    expect(screen.getByText('Xác nhận xóa danh mục')).toBeInTheDocument();

    // Nhấn nút xác nhận xóa
    const confirmBtn = screen.getByRole('button', { name: /xác nhận xóa/i });
    fireEvent.click(confirmBtn);

    // Tầng 2 (System Impact): Gọi API xóa danh mục với id 1
    await waitFor(() => {
      expect(adminApi.deleteCategory).toHaveBeenCalledWith(1);
    });

    // Tầng 1 (UI Rendering & Interaction):
    // Danh mục Ăn uống KHÔNG ĐƯỢC BIẾN MẤT khỏi giao diện
    expect(screen.getByText('Ăn uống')).toBeInTheDocument();

    // Xuất hiện badge/nhãn "Đã xóa"
    await waitFor(() => {
      expect(screen.getAllByText('Đã xóa').length).toBeGreaterThanOrEqual(1);
    });
  });
});
