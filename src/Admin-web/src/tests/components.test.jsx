import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import ConfirmModal from '../components/common/ConfirmModal';
import Pagination from '../components/common/Pagination';
import EmptyState from '../components/common/EmptyState';
import Loading from '../components/common/Loading';

describe('Admin-web Shared Components Suite', () => {
  // ─── 1. CONFIRM MODAL ───────────────────────────────────────────────────
  describe('1. ConfirmModal', () => {
    it('1.1. Không render gì nếu open = false', () => {
      const { container } = render(
        <ConfirmModal
          open={false}
          title="Xác nhận xóa"
          message="Bạn có chắc chắn muốn xóa không?"
          onConfirm={vi.fn()}
          onCancel={vi.fn()}
        />
      );
      expect(container.firstChild).toBeNull();
    });

    it('1.2. Render đúng title, message và gọi onConfirm khi click nút Xác nhận', () => {
      const handleConfirm = vi.fn();
      const handleCancel = vi.fn();

      render(
        <ConfirmModal
          open={true}
          title="Xác nhận xóa danh mục"
          message="Hành động này sẽ xóa danh mục hệ thống."
          confirmText="Đồng ý xóa"
          cancelText="Hủy bỏ"
          onConfirm={handleConfirm}
          onCancel={handleCancel}
        />
      );

      expect(screen.getByText('Xác nhận xóa danh mục')).toBeInTheDocument();
      expect(screen.getByText('Hành động này sẽ xóa danh mục hệ thống.')).toBeInTheDocument();

      const confirmBtn = screen.getByText('Đồng ý xóa');
      fireEvent.click(confirmBtn);
      expect(handleConfirm).toHaveBeenCalledTimes(1);

      const cancelBtn = screen.getByText('Hủy bỏ');
      fireEvent.click(cancelBtn);
      expect(handleCancel).toHaveBeenCalledTimes(1);
    });
  });

  // ─── 2. PAGINATION ──────────────────────────────────────────────────────
  describe('2. Pagination', () => {
    it('2.1. Hiển thị thông tin trang và gọi onPageChange khi chuyển trang', () => {
      const handlePageChange = vi.fn();

      render(
        <Pagination
          currentPage={2}
          total={50}
          pageSize={10}
          onPageChange={handlePageChange}
        />
      );

      // Nút Trước (Prev) có title="Trang trước"
      const prevBtn = screen.getByTitle('Trang trước');
      fireEvent.click(prevBtn);
      expect(handlePageChange).toHaveBeenCalledWith(1);

      // Nút Sau (Next) có title="Trang tiếp"
      const nextBtn = screen.getByTitle('Trang tiếp');
      fireEvent.click(nextBtn);
      expect(handlePageChange).toHaveBeenCalledWith(3);
    });

    it('2.2. Vô hiệu hóa nút Trước khi ở trang 1', () => {
      render(
        <Pagination
          currentPage={1}
          total={30}
          pageSize={10}
          onPageChange={vi.fn()}
        />
      );

      const prevBtn = screen.getByTitle('Trang trước');
      expect(prevBtn).toBeDisabled();
    });
  });

  // ─── 3. EMPTY STATE & LOADING ───────────────────────────────────────────
  describe('3. EmptyState & Loading', () => {
    it('3.1. EmptyState hiển thị đúng tiêu đề và mô tả khi danh sách rỗng', () => {
      render(
        <EmptyState
          title="Không có kết quả"
          description="Không tìm thấy dữ liệu nào phù hợp."
        />
      );
      expect(screen.getByText('Không có kết quả')).toBeInTheDocument();
      expect(screen.getByText('Không tìm thấy dữ liệu nào phù hợp.')).toBeInTheDocument();
    });

    it('3.2. Loading hiển thị spinner tải dữ liệu', () => {
      const { container } = render(<Loading text="Đang tải dữ liệu..." />);
      expect(screen.getByText('Đang tải dữ liệu...')).toBeInTheDocument();
      expect(container.firstChild).toBeInTheDocument();
    });
  });
});
