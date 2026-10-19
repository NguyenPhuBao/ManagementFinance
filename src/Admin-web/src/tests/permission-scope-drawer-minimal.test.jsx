import { describe, it, expect, vi } from 'vitest';
import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import PermissionScopeDrawer from '../pages/system/components/PermissionScopeDrawer';

describe('Task 6: Minimalist Permission Scope Drawer (Pillar 3 only)', () => {
  const mockFeature = {
    id: 'F_TXN_OCR',
    name: 'Quét hóa đơn thông minh (OCR)',
    default_downgrade_policy: 'BLOCK_CREATE',
    scope_schema: {
      max_scans_per_month: { type: 'number', description: 'Số lượt quét tối đa' },
    },
  };

  describe('Tier 1: Giao diện tối giản (Chỉ hiển thị Trụ 3, loại bỏ hoàn toàn Trụ 4)', () => {
    it('Hiển thị editor JSON Scope cho Trụ 3 nhưng KHÔNG hiển thị dropdown chọn Trụ 4', () => {
      render(
        <PermissionScopeDrawer
          isOpen={true}
          feature={mockFeature}
          accountType="Premium"
          initialScope={{ max_scans_per_month: 50 }}
          initialPolicy="BLOCK_CREATE"
          onClose={() => {}}
          onApply={() => {}}
        />
      );

      // Trụ 3 Scope JSON textarea phải tồn tại
      expect(screen.getByTestId('textarea-scope-json')).toBeDefined();

      // Trụ 4 Dropdown Downgrade Policy BẮT BUỘC KHÔNG TỒN TẠI
      expect(screen.queryByTestId('select-downgrade-policy')).toBeNull();
      expect(screen.queryByText('Chính sách khi hạ cấp gói')).toBeNull();
    });
  });

  describe('Tier 2: Tác động hệ thống & tính toàn vẹn dữ liệu (System Impact)', () => {
    it('Áp dụng cấu hình Scope JSON hợp lệ và gọi callback onApply chính xác', () => {
      const handleApply = vi.fn();
      const handleClose = vi.fn();

      render(
        <PermissionScopeDrawer
          isOpen={true}
          feature={mockFeature}
          accountType="Basic"
          initialScope={{ max_scans_per_month: 5 }}
          initialPolicy="BLOCK_CREATE"
          onClose={handleClose}
          onApply={handleApply}
        />
      );

      const textarea = screen.getByTestId('textarea-scope-json');
      fireEvent.change(textarea, {
        target: { value: JSON.stringify({ max_scans_per_month: 10 }) },
      });

      const applyBtn = screen.getByTestId('btn-apply-drawer');
      fireEvent.click(applyBtn);

      expect(handleApply).toHaveBeenCalledTimes(1);
      expect(handleApply).toHaveBeenCalledWith({
        featureId: 'F_TXN_OCR',
        accountType: 'Basic',
        scope_config: { max_scans_per_month: 10 },
        downgrade_policy: 'BLOCK_CREATE',
      });
      expect(handleClose).toHaveBeenCalledTimes(1);
    });

    it('Chặn áp dụng và báo lỗi nếu cú pháp JSON không hợp lệ (Safety Validation)', () => {
      const handleApply = vi.fn();

      render(
        <PermissionScopeDrawer
          isOpen={true}
          feature={mockFeature}
          accountType="Basic"
          initialScope={{}}
          initialPolicy="BLOCK_CREATE"
          onClose={() => {}}
          onApply={handleApply}
        />
      );

      const textarea = screen.getByTestId('textarea-scope-json');
      fireEvent.change(textarea, { target: { value: '{ invalid_json: 123 ' } });

      const applyBtn = screen.getByTestId('btn-apply-drawer');
      fireEvent.click(applyBtn);

      // Không được gọi onApply
      expect(handleApply).not.toHaveBeenCalled();
      // Báo lỗi trên màn hình
      expect(screen.getByText(/JSON không hợp lệ/i)).toBeDefined();
    });
  });
});
