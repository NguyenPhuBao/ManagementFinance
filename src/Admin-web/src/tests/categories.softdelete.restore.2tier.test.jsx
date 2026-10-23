import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import CategoryPage from '../pages/categories/CategoryPage';
import adminApi from '../api/admin.api';
import { LanguageProvider } from '../store/language.context';
import { AlertProvider } from '../store/alert.context';

vi.mock('../api/admin.api', () => ({
  default: {
    getCategories: vi.fn(),
    createCategory: vi.fn(),
    updateCategory: vi.fn(),
    deleteCategory: vi.fn(),
    restoreCategory: vi.fn(),
    verifySecurityAction: vi.fn(),
  },
}));

const mockCategoriesWithSoftDeleted = [
  {
    id: 'cat-active-1',
    name: 'Ăn uống',
    classify: 'Chi',
    keyword: 'an uong, com, pho, bun cha',
    is_default: true,
    create_at: '2026-01-01T00:00:00Z',
    status: 'active',
    delete_at: null,
  },
  {
    id: 'cat-deleted-2',
    name: 'Xăng xe & Nhiên liệu',
    classify: 'Chi',
    keyword: 'xang, dau, petrolimex, ron95',
    is_default: true,
    create_at: '2026-01-01T00:00:00Z',
    status: 'deleted',
    delete_at: '2026-10-10T10:00:00Z',
  },
];

const renderWithProviders = (ui, initialLang = 'vi') => {
  localStorage.setItem('admin_language', initialLang);
  return render(
    <LanguageProvider key={initialLang}>
      <AlertProvider>
        {ui}
      </AlertProvider>
    </LanguageProvider>
  );
};

describe('Category Soft-Delete & Restore 2-Tier Testing Suite (Rule 11)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.alert = vi.fn();
    adminApi.getCategories.mockResolvedValue({ data: mockCategoriesWithSoftDeleted });
    adminApi.verifySecurityAction.mockResolvedValue({ data: { verified: true } });
    adminApi.createCategory.mockResolvedValue({ data: { success: true } });
    adminApi.updateCategory.mockResolvedValue({ data: { success: true } });
    adminApi.deleteCategory.mockResolvedValue({ data: { success: true } });
    adminApi.restoreCategory.mockResolvedValue({ data: { success: true } });
    localStorage.setItem('admin_language', 'vi');
  });

  // =========================================================================
  // 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN (UI RENDERING & INTERACTION)
  // =========================================================================
  describe('🧱 TẦNG 1: UI Rendering & User Interaction Verification', () => {
    it('1.1. Danh mục đã xóa mềm hiển thị badge "Đã xóa", giữ nguyên bộ từ khóa và có nút "Khôi phục"', async () => {
      renderWithProviders(<CategoryPage />);

      await waitFor(() => {
        expect(screen.getByText('Xăng xe & Nhiên liệu')).toBeInTheDocument();
      });

      // Kiểm tra tên có gạch ngang line-through
      const deletedName = screen.getByText('Xăng xe & Nhiên liệu');
      expect(deletedName.className).toContain('line-through');

      // Kiểm tra bộ từ khóa AI vẫn hiển thị nguyên vẹn, không bị mất
      expect(screen.getByText('xang, dau, petrolimex, ron95')).toBeInTheDocument();

      // Kiểm tra nút Khôi phục hiển thị trực tiếp tại hàng của danh mục đã xóa
      const restoreBtn = screen.getByRole('button', { name: /Khôi phục/i });
      expect(restoreBtn).toBeInTheDocument();
    });

    it('1.2. Click nút "Khôi phục": danh mục chuyển ngay sang trạng thái hoạt động với badge "Đã khôi phục (nháp)"', async () => {
      renderWithProviders(<CategoryPage />);

      await waitFor(() => {
        expect(screen.getByText('Xăng xe & Nhiên liệu')).toBeInTheDocument();
      });

      const restoreBtn = screen.getByRole('button', { name: /Khôi phục/i });
      fireEvent.click(restoreBtn);

      // Danh mục bỏ gạch ngang line-through và hiển thị badge "Đã khôi phục (nháp)"
      await waitFor(() => {
        expect(screen.getByText(/Đã khôi phục/i)).toBeInTheDocument();
      });

      // Tên danh mục không còn line-through
      const restoredName = screen.getByText('Xăng xe & Nhiên liệu');
      expect(restoredName.className).not.toContain('line-through');

      // Nút "Đồng bộ danh mục" hiển thị
      expect(screen.getByRole('button', { name: /Đồng bộ danh mục/i })).toBeInTheDocument();
    });

    it('1.3. Tạo mới danh mục cùng tên với danh mục đã xóa mềm (để trống keyword): Kế thừa bộ từ khóa cũ', async () => {
      renderWithProviders(<CategoryPage />);

      await waitFor(() => {
        expect(screen.getByText('Xăng xe & Nhiên liệu')).toBeInTheDocument();
      });

      // Mở modal thêm mới
      const addBtn = screen.getByRole('button', { name: /Thêm danh mục mới/i });
      fireEvent.click(addBtn);

      // Điền tên trùng với danh mục đã xóa mềm, loại "Chi", nhưng ĐỂ TRỐNG ô từ khóa
      const nameInput = screen.getByPlaceholderText(/Nhập tên danh mục/i);
      fireEvent.change(nameInput, { target: { value: 'Xăng xe & Nhiên liệu' } });

      const saveBtn = screen.getByRole('button', { name: /^Lưu$/i });
      fireEvent.click(saveBtn);

      // Danh mục mới tạo xuất hiện trên bảng và TỰ ĐỘNG KẾ THỪA bộ từ khóa 'xang, dau, petrolimex, ron95'
      await waitFor(() => {
        const keywordElements = screen.getAllByText('xang, dau, petrolimex, ron95');
        expect(keywordElements.length).toBeGreaterThanOrEqual(1);
      });
    });
  });

  // =========================================================================
  // ⚡ TẦNG 2: KIỂM THỬ HOẠT ĐỘNG THỰC TẾ & TÁC ĐỘNG HỆ THỐNG (SYSTEM IMPACT)
  // =========================================================================
  describe('⚡ TẦNG 2: Real System Impact & Database Persistence Verification', () => {
    it('2.1. Thao tác Khôi phục qua nút bấm: Gọi API restoreCategory với đúng id của danh mục khi nhập mã PIN', async () => {
      renderWithProviders(<CategoryPage />);

      await waitFor(() => {
        expect(screen.getByText('Xăng xe & Nhiên liệu')).toBeInTheDocument();
      });

      // Bấm nút Khôi phục
      const restoreBtn = screen.getByRole('button', { name: /Khôi phục/i });
      fireEvent.click(restoreBtn);

      // Bấm nút Đồng bộ danh mục
      const syncBtn = screen.getByRole('button', { name: /Đồng bộ danh mục/i });
      fireEvent.click(syncBtn);

      // Nhập mã PIN và xác nhận
      const pinInput = screen.getByPlaceholderText(/Nhập mã PIN 6 số/i);
      fireEvent.change(pinInput, { target: { value: '123456' } });

      const confirmSyncBtn = screen.getByRole('button', { name: /Xác nhận đồng bộ/i });
      fireEvent.click(confirmSyncBtn);

      // Tác động hệ thống thực tế: verifySecurityAction được gọi VÀ restoreCategory được gọi với đúng ID 'cat-deleted-2'
      await waitFor(() => {
        expect(adminApi.verifySecurityAction).toHaveBeenCalledWith({
          pin: '123456',
          action: 'SYNC_CATEGORIES',
          targetId: 'SYSTEM_CATEGORIES',
        });
        expect(adminApi.restoreCategory).toHaveBeenCalledWith('cat-deleted-2');
      });
    });

    it('2.2. Thao tác tạo danh mục mới cùng tên không nhập keyword: Gọi API createCategory mang đầy đủ bộ từ khóa kế thừa', async () => {
      renderWithProviders(<CategoryPage />);

      await waitFor(() => {
        expect(screen.getByText('Xăng xe & Nhiên liệu')).toBeInTheDocument();
      });

      // Mở modal thêm mới
      const addBtn = screen.getByRole('button', { name: /Thêm danh mục mới/i });
      fireEvent.click(addBtn);

      // Điền tên danh mục cũ, để trống ô từ khóa
      const nameInput = screen.getByPlaceholderText(/Nhập tên danh mục/i);
      fireEvent.change(nameInput, { target: { value: 'Xăng xe & Nhiên liệu' } });

      const saveBtn = screen.getByRole('button', { name: /^Lưu$/i });
      fireEvent.click(saveBtn);

      // Bấm đồng bộ danh mục
      const syncBtn = screen.getByRole('button', { name: /Đồng bộ danh mục/i });
      fireEvent.click(syncBtn);

      // Nhập mã PIN
      const pinInput = screen.getByPlaceholderText(/Nhập mã PIN 6 số/i);
      fireEvent.change(pinInput, { target: { value: '888888' } });

      const confirmSyncBtn = screen.getByRole('button', { name: /Xác nhận đồng bộ/i });
      fireEvent.click(confirmSyncBtn);

      // Tác động hệ thống thực tế: createCategory được gọi với keyword được bảo toàn 100% ('xang, dau, petrolimex, ron95')
      await waitFor(() => {
        expect(adminApi.createCategory).toHaveBeenCalledWith(
          expect.objectContaining({
            name: 'Xăng xe & Nhiên liệu',
            classify: 'Chi',
            is_default: true,
            keyword: 'xang, dau, petrolimex, ron95',
          })
        );
      });
    });
  });
});
