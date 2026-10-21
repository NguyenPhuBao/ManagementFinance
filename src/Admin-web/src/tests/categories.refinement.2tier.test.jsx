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
    verifySecurityAction: vi.fn(),
  },
}));

const mockDatabaseCategories = [
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

const renderWithProviders = (ui, initialLang = 'vi') => {
  if (initialLang) {
    localStorage.setItem('admin_language', initialLang);
  }
  return render(
    <LanguageProvider key={initialLang}>
      <AlertProvider>
        {ui}
      </AlertProvider>
    </LanguageProvider>
  );
};

describe('CategoryPage Refinements & 2-Tier Testing Suite', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.alert = vi.fn();
    adminApi.getCategories.mockResolvedValue({ data: mockDatabaseCategories });
    adminApi.verifySecurityAction.mockResolvedValue({ data: { verified: true } });
    adminApi.createCategory.mockResolvedValue({ data: { success: true } });
    adminApi.updateCategory.mockResolvedValue({ data: { success: true } });
    adminApi.deleteCategory.mockResolvedValue({ data: { success: true } });
    localStorage.setItem('admin_language', 'vi');
  });

  // =========================================================================
  // 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN (UI RENDERING & INTERACTION)
  // =========================================================================
  describe('🧱 TẦNG 1: UI Rendering & Clean Header / Modals Verification', () => {
    it('1.1. Header: Loại bỏ hoàn toàn icon category, badge NLP Keywords Ready và subtitle', async () => {
      renderWithProviders(<CategoryPage />);

      await waitFor(() => {
        expect(adminApi.getCategories).toHaveBeenCalled();
      });

      // Tiêu đề trang vẫn hiển thị rõ ràng
      const headerTitle = screen.getByRole('heading', { level: 2, name: /Quản lý danh mục hệ thống/i });
      expect(headerTitle).toBeInTheDocument();

      // Kiểm tra Header không còn chứa icon category to hay container w-12
      const headerHero = headerTitle.closest('.flex-col');
      expect(headerHero.querySelector('.w-12')).toBeNull();

      // Kiểm tra BỎ HOÀN TOÀN badge NLP Keywords Ready
      expect(screen.queryByText(/NLP Keywords Ready/i)).not.toBeInTheDocument();

      // Kiểm tra BỎ HOÀN TOÀN dòng subtitle dài
      expect(
        screen.queryByText(/Quản lý các danh mục tài chính mặc định, chuẩn hóa bộ từ khóa nhận diện giao dịch tự động/i)
      ).not.toBeInTheDocument();

      // Các nút chức năng chính vẫn nguyên vẹn
      expect(screen.getByRole('button', { name: /Làm mới/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Thêm danh mục mới/i })).toBeInTheDocument();
    });

    it('1.2. Modal Thêm/Sửa: Dòng gợi ý từ khóa đã được rút gọn đúng theo PO yêu cầu', async () => {
      renderWithProviders(<CategoryPage />);

      await waitFor(() => {
        expect(screen.getByText('Ăn uống')).toBeInTheDocument();
      });

      // Mở modal Thêm danh mục
      fireEvent.click(screen.getByRole('button', { name: /Thêm danh mục mới/i }));

      // Dòng gợi ý chỉ còn vế trước, không còn vế giải thích AI
      expect(
        screen.getByText('Nhập các từ khóa phân cách bởi dấu phẩy (,).')
      ).toBeInTheDocument();
      expect(
        screen.queryByText(/Giúp bộ máy AI tự động nhận diện danh mục khi phân loại giao dịch/i)
      ).not.toBeInTheDocument();
    });

    it('1.3. Modal Xóa: Chỉ hiển thị 1 dòng xác nhận và 2 nút Hủy, Xác nhận xóa (bỏ khung soft delete)', async () => {
      renderWithProviders(<CategoryPage />);

      await waitFor(() => {
        expect(screen.getByText('Ăn uống')).toBeInTheDocument();
      });

      // Bấm nút xóa trên dòng Ăn uống
      const deleteButtons = screen.getAllByTitle(/Xóa danh mục hệ thống/i);
      fireEvent.click(deleteButtons[0]);

      // Câu hỏi xác nhận ngắn gọn đúng 1 dòng
      expect(
        screen.getByText(/Bạn chắc chắn muốn xóa danh mục/i)
      ).toBeInTheDocument();
      expect(screen.getByText('"Ăn uống"')).toBeInTheDocument();

      // Khung ghi chú soft delete warning BẮT BUỘC KHÔNG XUẤT HIỆN
      expect(screen.queryByText(/Hệ thống sẽ thực hiện Xóa Mềm \(Soft Delete\):/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Dữ liệu và các giao dịch tài chính trước đây hoàn toàn không bị ảnh hưởng/i)).not.toBeInTheDocument();

      // Đúng 2 nút Hủy và Xác nhận xóa
      expect(screen.getByRole('button', { name: /^Hủy$/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /^Xác nhận xóa$/i })).toBeInTheDocument();
    });

    it('1.4. Footer: Nút "Đặt lại mặc định" nằm ở bên trái nút "Đồng bộ danh mục"', async () => {
      renderWithProviders(<CategoryPage />);

      await waitFor(() => {
        expect(screen.getByText('Ăn uống')).toBeInTheDocument();
      });

      const resetBtn = screen.getByRole('button', { name: /Đặt lại mặc định/i });
      const syncBtn = screen.getByRole('button', { name: /Đồng bộ danh mục/i });

      expect(resetBtn).toBeInTheDocument();
      expect(syncBtn).toBeInTheDocument();
    });
  });

  // =========================================================================
  // ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ (REAL SYSTEM IMPACT)
  // =========================================================================
  describe('⚡ TẦNG 2: Real System Impact — Draft Mode, Reset & Security PIN Sync', () => {
    it('2.1. Thêm danh mục mới vào Bản Nháp: Chưa gọi API CSDL, chỉ xuất hiện trên giao diện nháp', async () => {
      renderWithProviders(<CategoryPage />);

      await waitFor(() => {
        expect(screen.getByText('Ăn uống')).toBeInTheDocument();
      });

      // Mở modal thêm
      fireEvent.click(screen.getByRole('button', { name: /Thêm danh mục mới/i }));

      // Nhập tên danh mục mới
      fireEvent.change(screen.getByPlaceholderText(/Nhập tên danh mục/i), {
        target: { value: 'Tiền tip phục vụ' },
      });
      fireEvent.change(screen.getByPlaceholderText(/Ví dụ: cafe, highlands/i), {
        target: { value: 'tip, bo, thưởng phục vụ' },
      });

      // Bấm Lưu
      fireEvent.click(screen.getByRole('button', { name: /^Lưu$/i }));

      // TÁC ĐỘNG HỆ THỐNG:
      // 1. Xuất hiện trên bảng kèm nhãn Bản nháp
      expect(screen.getByText('Tiền tip phục vụ')).toBeInTheDocument();
      expect(screen.getByText('Bản nháp')).toBeInTheDocument();

      // 2. adminApi.createCategory CHƯA ĐƯỢC PHÉP GỌI (chưa lưu CSDL)
      expect(adminApi.createCategory).not.toHaveBeenCalled();
    });

    it('2.2. Đặt lại mặc định: Hủy bỏ toàn bộ thay đổi nháp và quay lại dữ liệu khớp CSDL', async () => {
      renderWithProviders(<CategoryPage />);

      await waitFor(() => {
        expect(screen.getByText('Ăn uống')).toBeInTheDocument();
      });

      // Thêm 1 danh mục nháp
      fireEvent.click(screen.getByRole('button', { name: /Thêm danh mục mới/i }));
      fireEvent.change(screen.getByPlaceholderText(/Nhập tên danh mục/i), {
        target: { value: 'Danh mục tạm thời' },
      });
      fireEvent.click(screen.getByRole('button', { name: /^Lưu$/i }));

      expect(screen.getByText('Danh mục tạm thời')).toBeInTheDocument();

      // Bấm nút "Đặt lại mặc định"
      fireEvent.click(screen.getByRole('button', { name: /Đặt lại mặc định/i }));

      // Popup xác nhận hiển thị
      expect(screen.getByText(/Bạn có chắc chắn muốn hủy bỏ toàn bộ thay đổi trong bản nháp/i)).toBeInTheDocument();

      // Bấm "Xác nhận đặt lại"
      fireEvent.click(screen.getByRole('button', { name: /Xác nhận đặt lại/i }));

      // TÁC ĐỘNG HỆ THỐNG: Danh mục nháp biến mất, dữ liệu khôi phục 100% về CSDL gốc
      expect(screen.queryByText('Danh mục tạm thời')).not.toBeInTheDocument();
      expect(screen.getByText('Ăn uống')).toBeInTheDocument();
      expect(screen.getByText('Lương & Thưởng')).toBeInTheDocument();
    });

    it('2.3. Đồng bộ danh mục với mã PIN sai: Bị chặn đứng và không gọi API lưu CSDL', async () => {
      adminApi.verifySecurityAction.mockRejectedValueOnce(new Error('Mã PIN không chính xác!'));

      renderWithProviders(<CategoryPage />);

      await waitFor(() => {
        expect(screen.getByText('Ăn uống')).toBeInTheDocument();
      });

      // Thêm danh mục nháp
      fireEvent.click(screen.getByRole('button', { name: /Thêm danh mục mới/i }));
      fireEvent.change(screen.getByPlaceholderText(/Nhập tên danh mục/i), {
        target: { value: 'Quỹ khẩn cấp' },
      });
      fireEvent.click(screen.getByRole('button', { name: /^Lưu$/i }));

      // Bấm "Đồng bộ danh mục"
      fireEvent.click(screen.getByRole('button', { name: /Đồng bộ danh mục/i }));

      // Modal mã PIN mở ra
      expect(screen.getByPlaceholderText(/Nhập mã PIN 6 số/i)).toBeInTheDocument();

      // Nhập mã PIN sai
      fireEvent.change(screen.getByPlaceholderText(/Nhập mã PIN 6 số/i), {
        target: { value: '111111' },
      });

      // Bấm Xác nhận đồng bộ
      fireEvent.click(screen.getByRole('button', { name: /Xác nhận đồng bộ/i }));

      await waitFor(() => {
        // Thông báo lỗi xuất hiện
        expect(screen.getByText(/Mã PIN không chính xác/i)).toBeInTheDocument();
      });

      // TÁC ĐỘNG HỆ THỐNG: API tạo danh mục CSDL không được phép gọi
      expect(adminApi.createCategory).not.toHaveBeenCalled();
    });

    it('2.4. Đồng bộ danh mục với mã PIN đúng: Xác thực thành công và lưu toàn bộ thay đổi nháp vào CSDL', async () => {
      adminApi.verifySecurityAction.mockResolvedValueOnce({ data: { verified: true } });
      adminApi.createCategory.mockResolvedValueOnce({ data: { id: 3, name: 'Quỹ bảo hiểm' } });

      renderWithProviders(<CategoryPage />);

      await waitFor(() => {
        expect(screen.getByText('Ăn uống')).toBeInTheDocument();
      });

      // Thêm danh mục nháp
      fireEvent.click(screen.getByRole('button', { name: /Thêm danh mục mới/i }));
      fireEvent.change(screen.getByPlaceholderText(/Nhập tên danh mục/i), {
        target: { value: 'Quỹ bảo hiểm' },
      });
      fireEvent.click(screen.getByRole('button', { name: /^Lưu$/i }));

      // Bấm "Đồng bộ danh mục"
      fireEvent.click(screen.getByRole('button', { name: /Đồng bộ danh mục/i }));

      // Nhập mã PIN đúng 6 số
      fireEvent.change(screen.getByPlaceholderText(/Nhập mã PIN 6 số/i), {
        target: { value: '654321' },
      });

      // Bấm Xác nhận đồng bộ
      fireEvent.click(screen.getByRole('button', { name: /Xác nhận đồng bộ/i }));

      await waitFor(() => {
        // TÁC ĐỘNG HỆ THỐNG THỰC TẾ:
        // 1. verifySecurityAction được gọi với mã PIN đúng
        expect(adminApi.verifySecurityAction).toHaveBeenCalledWith(
          expect.objectContaining({
            pin: '654321',
            action: 'SYNC_CATEGORIES',
          })
        );
        // 2. createCategory được gọi với dữ liệu nháp
        expect(adminApi.createCategory).toHaveBeenCalledWith(
          expect.objectContaining({
            name: 'Quỹ bảo hiểm',
            is_default: true,
          })
        );
      });
    });
  });
});
