import React from 'react';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { SettingsProvider, useSettings } from '../store/settings.context';
import { AuthProvider, useAuthContext } from '../store/auth.context';
import LockScreenModal from '../components/layout/LockScreenModal';
import ProtectedRoute from '../router/ProtectedRoute';
import authApi from '../api/auth.api';
import { STORAGE_KEYS } from '../utils/constants';

vi.mock('../api/auth.api', () => ({
  default: {
    login: vi.fn(),
    logout: vi.fn(),
    getMe: vi.fn().mockResolvedValue({ data: { iduser: 1, username: 'admin', fullname: 'Quản Trị Viên', rolename: 'Admin' } }),
  },
}));

// Dummy protected dashboard component
const MockDashboard = () => {
  const { user, isAuthenticated } = useAuthContext();
  const settings = useSettings();
  return (
    <div>
      <div data-testid="dashboard-content">Bảng Điều Khiển Quản Trị</div>
      <div data-testid="auth-status">{isAuthenticated ? 'AUTHENTICATED' : 'ANONYMOUS'}</div>
      <div data-testid="user-name">{user?.fullname || user?.username}</div>
      <div data-testid="lock-status">{settings.isLocked ? 'LOCKED' : 'UNLOCKED'}</div>
      <LockScreenModal />
    </div>
  );
};

const MockLoginPage = () => (
  <div data-testid="login-page">Trang Đăng Nhập Admin</div>
);

describe('Task 1: LockScreen Session Recovery & No Login Redirect Test', () => {
  beforeEach(() => {
    localStorage.clear();
    vi.clearAllMocks();
  });

  it('Tier 1 & Tier 2: Khi mở khóa màn hình thành công, phải duy trì phiên đăng nhập và KHÔNG bị đá về trang /login', async () => {
    // Giả lập trạng thái ban đầu: Đã đăng nhập và sau đó màn hình bị khóa
    const initialUser = { iduser: 1, username: 'admin', fullname: 'Quản Trị Viên', idrole: 1, rolename: 'Admin' };
    localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(initialUser));
    localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(initialUser));
    localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
    localStorage.setItem(STORAGE_KEYS.LOCKED_AT, '14:00');

    // Giả lập authApi.login trả về token mới khi nhập đúng mật khẩu
    authApi.login.mockResolvedValueOnce({
      data: {
        accessToken: 'new-fresh-access-token-12345',
        refreshToken: 'new-fresh-refresh-token-67890',
        user: initialUser,
      },
    });

    render(
      <MemoryRouter initialEntries={['/dashboard']}>
        <SettingsProvider>
          <AuthProvider>
            <Routes>
              <Route path="/login" element={<MockLoginPage />} />
              <Route
                path="/dashboard"
                element={
                  <ProtectedRoute>
                    <MockDashboard />
                  </ProtectedRoute>
                }
              />
            </Routes>
          </AuthProvider>
        </SettingsProvider>
      </MemoryRouter>
    );

    // ==========================================
    // 🧱 TẦNG 1: HIỂN THỊ & THAO TÁC GIAO DIỆN
    // ==========================================
    // Kiểm tra Modal LockScreen hiển thị đầy đủ
    const adminTexts = await screen.findAllByText('Quản Trị Viên');
    expect(adminTexts.length).toBeGreaterThanOrEqual(1);
    expect(screen.getByPlaceholderText(/Mật khẩu quản trị viên/i)).toBeInTheDocument();

    const passwordInput = screen.getByPlaceholderText(/Mật khẩu quản trị viên/i);
    const unlockBtn = screen.getByRole('button', { name: /Mở Khóa Màn Hình/i });

    // Nhập mật khẩu
    fireEvent.change(passwordInput, { target: { value: 'SecretAdmin@123' } });
    expect(passwordInput.value).toBe('SecretAdmin@123');

    // Click mở khóa
    fireEvent.click(unlockBtn);

    // ==========================================
    // ⚡ TẦNG 2: TÁC ĐỘNG HỆ THỐNG THỰC TẾ
    // ==========================================
    // 1. API login phải được gọi với đúng username và password
    await waitFor(() => {
      expect(authApi.login).toHaveBeenCalledWith({
        username: 'admin',
        password: 'SecretAdmin@123',
      });
    });

    // 2. LocalStorage phải được cập nhật token mới và xóa cờ IS_LOCKED
    await waitFor(() => {
      expect(localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN)).toBe('new-fresh-access-token-12345');
      expect(localStorage.getItem(STORAGE_KEYS.IS_LOCKED)).toBeNull();
    });

    // 3. Người dùng phải TIẾP TỤC ở lại Dashboard, KHÔNG bị redirect về trang Login!
    await waitFor(() => {
      expect(screen.queryByTestId('login-page')).not.toBeInTheDocument();
      expect(screen.getByTestId('dashboard-content')).toBeInTheDocument();
      expect(screen.getByTestId('auth-status')).toHaveTextContent('AUTHENTICATED');
      expect(screen.getByTestId('lock-status')).toHaveTextContent('UNLOCKED');
    });
  });
});
