import { describe, it, expect } from 'vitest';
import React from 'react';
import { render, screen } from '@testing-library/react';
import { classifyAuditAction, AUDIT_TAGS } from '../utils/audit-tags.util';

describe('Task 4: Audit Tags Classification & 2-Tier Verification', () => {
  describe('Tier 2: Logic phân loại hành vi thực tế (System Impact & Classification Accuracy)', () => {
    it('Phân loại chính xác các hành động Xác thực [AUTH]', () => {
      const res1 = classifyAuditAction('Đăng nhập quản trị viên thành công');
      expect(res1.tagInfo.key).toBe('AUTH');
      expect(res1.tagInfo.tag).toBe('[AUTH]');

      const res2 = classifyAuditAction('POST /api/auth/login');
      expect(res2.tagInfo.key).toBe('AUTH');

      const res3 = classifyAuditAction('Xác thực mã PIN cấp 2');
      expect(res3.tagInfo.key).toBe('AUTH');
    });

    it('Phân loại chính xác các hành động Thanh toán & Gói cước [PAYMENT]', () => {
      const res1 = classifyAuditAction('Hoàn tiền đơn hàng #25120703');
      expect(res1.tagInfo.key).toBe('PAYMENT');
      expect(res1.tagInfo.tag).toBe('[PAYMENT]');

      const res2 = classifyAuditAction('Nâng cấp gói Premium 1 tháng');
      expect(res2.tagInfo.key).toBe('PAYMENT');

      const res3 = classifyAuditAction('PayOS Webhook thanh toán thành công');
      expect(res3.tagInfo.key).toBe('PAYMENT');
    });

    it('Phân loại chính xác các hành động Quản lý người dùng [USER]', () => {
      const res1 = classifyAuditAction('Xóa mềm tài khoản người dùng @nguyenvanb');
      expect(res1.tagInfo.key).toBe('USER');
      expect(res1.tagInfo.tag).toBe('[USER]');

      const res2 = classifyAuditAction('Vô hiệu hóa tài khoản vi phạm chính sách');
      expect(res2.tagInfo.key).toBe('USER');
    });

    it('Phân loại chính xác An ninh & Cô lập [AIOPS]', () => {
      const res1 = classifyAuditAction('AIOps Sentinel cách ly IP nghi vấn brute-force');
      expect(res1.tagInfo.key).toBe('AIOPS');
      expect(res1.tagInfo.tag).toBe('[AIOPS]');

      const res2 = classifyAuditAction('Tạm khóa IP 113.161.45.88 vào danh sách cách ly');
      expect(res2.tagInfo.key).toBe('AIOPS');
    });

    it('Xử lý an toàn khi chuỗi đã có tiền tố [TAG] hoặc chuỗi rỗng', () => {
      const res1 = classifyAuditAction('[PAYMENT] Nâng cấp gói dịch vụ');
      expect(res1.tagInfo.key).toBe('PAYMENT');
      expect(res1.cleanAction).toBe('Nâng cấp gói dịch vụ');

      const res2 = classifyAuditAction('');
      expect(res2.tagInfo.key).toBe('API');
    });
  });

  describe('Tier 1: Hiển thị & Thao tác giao diện UI (Badge Rendering)', () => {
    it('Render đầy đủ Badge phân loại kèm icon và màu sắc CSS chuẩn Tailwind', () => {
      const { tagInfo, cleanAction } = classifyAuditAction('Hoàn tiền đơn hàng');
      const { container } = render(
        <div data-testid="audit-row">
          <span className={`badge ${tagInfo.bg} ${tagInfo.text} ${tagInfo.border}`}>
            <span>{tagInfo.tag}</span>
          </span>
          <span className="action-text">{cleanAction}</span>
        </div>
      );

      expect(screen.getByText('[PAYMENT]')).toBeDefined();
      expect(screen.getByText('Hoàn tiền đơn hàng')).toBeDefined();
      expect(container.querySelector('.bg-emerald-50')).not.toBeNull();
      expect(container.querySelector('.text-emerald-700')).not.toBeNull();
    });
  });
});
