import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { SettingsProvider, useSettings } from '../store/settings.context';
import { AuthProvider, useAuthContext } from '../store/auth.context';
import LockScreenModal from '../components/layout/LockScreenModal';
import { STORAGE_KEYS } from '../utils/constants';
import authApi from '../api/auth.api';

vi.mock('../api/auth.api', () => ({
  default: {
    login: vi.fn(),
    logout: vi.fn(),
    getMe: vi.fn(),
  },
}));

const TestLockContainer = () => {
  const { isLocked, lockScreen } = useSettings();
  return (
    <div>
      <div data-testid="is-locked-status">{isLocked ? 'LOCKED' : 'UNLOCKED'}</div>
      <button data-testid="btn-lock" onClick={lockScreen}>Khóa Màn Hình</button>
      <LockScreenModal />
    </div>
  );
};

describe('Màn Hình Khóa An Toàn (LockScreenModal) — 2-Tier Testing Suite (PO Refinement)', () => {
  const mockDbUser = {
    idaccount: 99,
    username: 'admin_master',
    email: 'admin_real@company.com',
    fullname: 'Nguyễn Văn Quản Trị',
    idrole: 1,
    rolename: 'admin',
  };

  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
    document.documentElement.className = '';
  });

  // =========================================================================
  // 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN (UI Rendering & Interaction)
  // =========================================================================
  describe('🧱 TẦNG 1: Kiểm thử hiển thị & Thao tác giao diện LockScreenModal', () => {
    it('1.1. Bỏ phần hình ảnh cá nhân "A", hiển thị icon Ổ khóa an ninh trung tâm (lock icon)', () => {
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockDbUser));

      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockContainer />
          </AuthProvider>
        </SettingsProvider>
      );

      // Xác nhận không còn chữ cái avatar "N" hay "A"
      expect(screen.queryByText('A')).not.toBeInTheDocument();
      expect(screen.queryByText('N')).not.toBeInTheDocument();

      // Xác nhận có icon ổ khóa an ninh trung tâm
      const lockIcons = screen.getAllByText('lock');
      expect(lockIcons.length).toBeGreaterThanOrEqual(1);
    });

    it('1.2. Hiển thị đúng Username và Email từ CSDL, TUYỆT ĐỐI KHÔNG gán cứng admin@finance.local', () => {
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockDbUser));

      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockContainer />
          </AuthProvider>
        </SettingsProvider>
      );

      // Username phải hiển thị đúng từ CSDL
      expect(screen.getByText('admin_master')).toBeInTheDocument();

      // Email phải hiển thị đúng từ CSDL
      expect(screen.getByText('admin_real@company.com')).toBeInTheDocument();

      // Không bao giờ gán cứng chuỗi giả lập
      expect(screen.queryByText('admin@finance.local')).not.toBeInTheDocument();
    });

    it('1.3. Bỏ icon "key" trong ô input mật khẩu, input sạch đẹp', () => {
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockDbUser));

      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockContainer />
          </AuthProvider>
        </SettingsProvider>
      );

      // Icon key không còn xuất hiện trên DOM
      expect(screen.queryByText('key')).not.toBeInTheDocument();

      const passInput = screen.getByPlaceholderText(/Mật khẩu quản trị viên/i);
      expect(passInput).toBeInTheDocument();
      // Class padding đã được tối ưu không còn pl-9
      expect(passInput.className).toContain('px-3.5');
      expect(passInput.className).not.toContain('pl-9');
    });

    it('1.4. Bỏ dòng subtitle "Hệ thống tự động kích hoạt bảo vệ an toàn thông tin quản trị"', () => {
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockDbUser));

      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockContainer />
          </AuthProvider>
        </SettingsProvider>
      );

      // Subtitle rườm rà đã bị loại bỏ
      expect(screen.queryByText(/Hệ thống tự động kích hoạt bảo vệ an toàn thông tin quản trị/i)).not.toBeInTheDocument();
    });

    it('1.5. Đưa nút "Đăng xuất" lên ngang hàng với nút "Mở Khóa Màn Hình"', () => {
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockDbUser));

      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockContainer />
          </AuthProvider>
        </SettingsProvider>
      );

      const logoutBtn = screen.getByRole('button', { name: /Đăng xuất/i });
      const unlockBtn = screen.getByRole('button', { name: /Mở Khóa Màn Hình/i });

      expect(logoutBtn).toBeInTheDocument();
      expect(unlockBtn).toBeInTheDocument();

      // Cả 2 nút nằm trong cùng 1 thẻ cha Flexbox ngang hàng (flex items-center gap-3)
      expect(logoutBtn.parentElement).toBe(unlockBtn.parentElement);
      expect(logoutBtn.parentElement.className).toContain('flex items-center gap-3');
    });
  });

  // =========================================================================
  // ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ (Real System Impact Verification)
  // =========================================================================
  describe('⚡ TẦNG 2: Kiểm thử tác động hệ thống thực tế (System Impact)', () => {
    it('2.1. Thao tác Mở khóa: Gọi authApi.login với Username thật từ CSDL và mật khẩu nhập vào', async () => {
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockDbUser));

      authApi.login.mockResolvedValueOnce({
        data: {
          accessToken: 'fresh_jwt_access_token_999',
          refreshToken: 'fresh_jwt_refresh_token_999',
          user: mockDbUser,
        },
      });

      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockContainer />
          </AuthProvider>
        </SettingsProvider>
      );

      const passInput = screen.getByPlaceholderText(/Mật khẩu quản trị viên/i);
      const unlockBtn = screen.getByRole('button', { name: /Mở Khóa Màn Hình/i });

      fireEvent.change(passInput, { target: { value: 'Secret@123' } });
      fireEvent.click(unlockBtn);

      await waitFor(() => {
        // Tác động hệ thống: API login phải được gọi với username thật từ CSDL
        expect(authApi.login).toHaveBeenCalledWith({
          username: 'admin_master',
          password: 'Secret@123',
        });
      });

      // Tác động Persistence: Tokens mới được lưu vào localStorage
      await waitFor(() => {
        expect(localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN)).toBe('fresh_jwt_access_token_999');
        expect(localStorage.getItem(STORAGE_KEYS.IS_LOCKED)).toBeNull();
      });
    });

    it('2.2. Thao tác Đăng xuất: Bấm nút Đăng xuất trên màn hình khóa xóa sạch 6 keys bảo mật', async () => {
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockDbUser));
      localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'test_token');
      localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(mockDbUser));

      // Mock window.confirm = true
      vi.spyOn(window, 'confirm').mockReturnValue(true);

      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockContainer />
          </AuthProvider>
        </SettingsProvider>
      );

      const logoutBtn = screen.getByRole('button', { name: /Đăng xuất/i });
      fireEvent.click(logoutBtn);

      await waitFor(() => {
        // Tác động hệ thống: Xóa sạch 100% dữ liệu phiên làm việc
        expect(localStorage.getItem(STORAGE_KEYS.IS_LOCKED)).toBeNull();
        expect(localStorage.getItem(STORAGE_KEYS.LOCKED_USER)).toBeNull();
        expect(localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN)).toBeNull();
        expect(localStorage.getItem(STORAGE_KEYS.USER)).toBeNull();
      });
    });
  });
});
