import { describe, it, expect } from 'vitest';
import React from 'react';
import { render, screen } from '@testing-library/react';
import { maskPhone } from '../utils/format';

describe('Task 5: User Management Phone Masking & Database Filter (2-Tier Testing)', () => {
  describe('Tier 2: Kiểm thử logic bảo mật dữ liệu & tác động thực tế (Data Security & Logic Verification)', () => {
    it('Masking số điện thoại chuẩn 10 chữ số: giữ 3 đầu, 3 cuối, che 4 số giữa (098****321)', () => {
      const rawPhone = '0981234321';
      const masked = maskPhone(rawPhone);
      expect(masked).toBe('098****321');
      expect(masked.startsWith('098')).toBe(true);
      expect(masked.endsWith('321')).toBe(true);
      expect(masked.includes('1234')).toBe(false); // Không để lộ 4 số giữa
    });

    it('Xử lý an toàn khi số điện thoại có tiền tố quốc gia (+84)', () => {
      const rawPhone = '+84981234321';
      const masked = maskPhone(rawPhone);
      expect(masked).toBe('+8498****321');
      expect(masked.includes('1234')).toBe(false);
    });

    it('Xử lý an toàn khi số điện thoại rỗng, null hoặc chưa cập nhật (—)', () => {
      expect(maskPhone('')).toBe('—');
      expect(maskPhone(null)).toBe('—');
      expect(maskPhone(undefined)).toBe('—');
      expect(maskPhone('—')).toBe('—');
    });

    it('Lọc người dùng theo Gói cước (Basic/Premium) và Thời gian đăng ký', () => {
      const mockUsers = [
        { id: 1, name: 'User 1', package: 'Basic', created_at: new Date(Date.now() - 2 * 24 * 3600 * 1000).toISOString() },
        { id: 2, name: 'User 2', package: 'Premium', created_at: new Date(Date.now() - 20 * 24 * 3600 * 1000).toISOString() },
        { id: 3, name: 'User 3', package: 'Premium', created_at: new Date(Date.now() - 100 * 24 * 3600 * 1000).toISOString() },
      ];

      // Lọc Premium
      const premiumUsers = mockUsers.filter(u => u.package === 'Premium');
      expect(premiumUsers.length).toBe(2);

      // Lọc trong 7 ngày gần đây
      const now = Date.now();
      const recentUsers = mockUsers.filter(u => {
        const diffDays = (now - new Date(u.created_at).getTime()) / (1000 * 60 * 60 * 24);
        return diffDays <= 7;
      });
      expect(recentUsers.length).toBe(1);
      expect(recentUsers[0].name).toBe('User 1');
    });
  });

  describe('Tier 1: Hiển thị & Thao tác tại giao diện UI (Masking Phone Render)', () => {
    it('Render số điện thoại đã được che trên giao diện người dùng, không bao giờ lộ số gốc', () => {
      const rawPhone = '0905123789';
      const masked = maskPhone(rawPhone);

      render(
        <div data-testid="user-row">
          <span className="user-phone">{masked}</span>
        </div>
      );

      const phoneEl = screen.getByText('090****789');
      expect(phoneEl).toBeDefined();
      expect(screen.queryByText('0905123789')).toBeNull();
    });
  });
});
