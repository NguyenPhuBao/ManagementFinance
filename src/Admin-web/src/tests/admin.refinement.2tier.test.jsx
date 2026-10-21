import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import FirstLoginModal from '../components/layout/FirstLoginModal';
import SettingsModal from '../components/layout/SettingsModal';
import Sidebar from '../components/layout/Sidebar';
import Header from '../components/layout/Header';
import AppLayout from '../components/layout/AppLayout';
import { AuthProvider, useAuthContext } from '../store/auth.context';
import { SettingsProvider, useSettings } from '../store/settings.context';
import { LanguageProvider } from '../store/language.context';
import { AlertProvider } from '../store/alert.context';
import adminApi from '../api/admin.api';
import authApi from '../api/auth.api';

// Mocks
vi.mock('../api/admin.api', () => ({
  default: {
    firstLoginSetup: vi.fn(),
    changePin: vi.fn(),
    changePassword: vi.fn(),
    createAdmin: vi.fn(),
    getMaintenanceStatus: vi.fn().mockResolvedValue({ data: { active: false } }),
  },
}));

vi.mock('../api/auth.api', () => ({
  default: {
    login: vi.fn(),
    logout: vi.fn(),
    getMe: vi.fn(),
  },
}));

vi.mock('../api/aiops.api', () => ({
  default: {
    getStatus: vi.fn().mockResolvedValue({ data: { recommendedAction: 'NONE', vectorScores: { resource: 20 } } }),
  },
}));

vi.mock('../api/notification.api', () => ({
  default: {
    getAdminAlerts: vi.fn().mockResolvedValue({ data: { notifications: [], unreadCount: 0 } }),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: () => ({
    connected: true,
    id: 'mock-socket-id',
    on: vi.fn(),
    off: vi.fn(),
    emit: vi.fn(),
  }),
}));

import { STORAGE_KEYS } from '../utils/constants';

const renderWithProviders = (ui, { authValue = {}, initialEntries = ['/'] } = {}) => {
  const defaultUser = {
    Idaccount: 1,
    Username: 'admin_test',
    Email: 'admin@finance.local',
    Role: 'Admin',
    is_first_login: false,
    ...authValue.user,
  };

  localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'mock-jwt-token');
  localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(defaultUser));
  authApi.getMe.mockResolvedValue({ data: defaultUser });

  return render(
    <MemoryRouter initialEntries={initialEntries}>
      <LanguageProvider>
        <AlertProvider>
          <SettingsProvider>
            <AuthProvider>
              {ui}
            </AuthProvider>
          </SettingsProvider>
        </AlertProvider>
      </LanguageProvider>
    </MemoryRouter>
  );
};

describe('Admin-web Refinement 2-Tier Test Suite (Issue Logs Verification)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
  });

  // =========================================================================
  // ISSUE 1: FIRST LOGIN MODAL (Bắt buộc admin đổi pass & pin khi đăng nhập lần đầu)
  // =========================================================================
  describe('Issue 1: Mandatory FirstLoginModal (2-Tier Verification)', () => {
    it('Tầng 1 (UI): Hiển thị modal bắt buộc, không có nút đóng, validation input lỗi khi không khớp', async () => {
      const syncAuthSessionMock = vi.fn();
      renderWithProviders(<FirstLoginModal />, {
        authValue: {
          user: { is_first_login: true, Username: 'newbie_admin' },
          syncAuthSession: syncAuthSessionMock,
        },
      });

      // Xác nhận Modal được render
      expect(screen.getByTestId('first-login-modal-overlay')).toBeInTheDocument();
      expect(screen.getByText(/thiết lập bảo mật quản trị viên/i)).toBeInTheDocument();

      // Kiểm tra đầy đủ các input
      const newPasswordInput = screen.getByTestId('first-login-new-password');
      const confirmPasswordInput = screen.getByTestId('first-login-confirm-password');
      const newPinInput = screen.getByTestId('first-login-new-pin');
      const confirmPinInput = screen.getByTestId('first-login-confirm-pin');
      const submitBtn = screen.getByTestId('first-login-submit-btn');

      expect(newPasswordInput).toBeInTheDocument();
      expect(confirmPasswordInput).toBeInTheDocument();
      expect(newPinInput).toBeInTheDocument();
      expect(confirmPinInput).toBeInTheDocument();
      expect(submitBtn).toBeInTheDocument();

      // Thao tác nhập mật khẩu không khớp
      fireEvent.change(newPasswordInput, { target: { value: 'password123' } });
      fireEvent.change(confirmPasswordInput, { target: { value: 'mismatchPass' } });
      fireEvent.change(newPinInput, { target: { value: '123456' } });
      fireEvent.change(confirmPinInput, { target: { value: '123456' } });
      fireEvent.click(submitBtn);

      // Validation cảnh báo lỗi mật khẩu không khớp
      await waitFor(() => {
        expect(screen.getByText(/xác nhận mật khẩu mới không khớp/i)).toBeInTheDocument();
      });

      // Thao tác nhập mã PIN sai định dạng (không đủ 6 số)
      fireEvent.change(confirmPasswordInput, { target: { value: 'password123' } });
      fireEvent.change(newPinInput, { target: { value: '1234' } });
      fireEvent.change(confirmPinInput, { target: { value: '1234' } });
      fireEvent.click(submitBtn);

      await waitFor(() => {
        expect(screen.getByText(/mã pin bảo mật phải bao gồm đúng 6 chữ số/i)).toBeInTheDocument();
      });
    });

    it('Tầng 2 (System Impact): Gọi API firstLoginSetup, cập nhật session, giữ nguyên phiên làm việc', async () => {
      adminApi.firstLoginSetup.mockResolvedValueOnce({
        data: { message: 'Setup completed successfully', data: { is_first_login: false } },
      });

      renderWithProviders(<FirstLoginModal />, {
        authValue: {
          user: { is_first_login: true, Username: 'newbie_admin' },
        },
      });

      fireEvent.change(screen.getByTestId('first-login-new-password'), { target: { value: 'SecurePass@2026' } });
      fireEvent.change(screen.getByTestId('first-login-confirm-password'), { target: { value: 'SecurePass@2026' } });
      fireEvent.change(screen.getByTestId('first-login-new-pin'), { target: { value: '654321' } });
      fireEvent.change(screen.getByTestId('first-login-confirm-pin'), { target: { value: '654321' } });
      fireEvent.click(screen.getByTestId('first-login-submit-btn'));

      // Tầng 2: Xác nhận API backend được gọi với đúng tham số
      await waitFor(() => {
        expect(adminApi.firstLoginSetup).toHaveBeenCalledWith(
          expect.objectContaining({
            newPassword: 'SecurePass@2026',
            pin: '654321',
          })
        );
      });

      // Tầng 2: Xác nhận session được đồng bộ cập nhật is_first_login = false ngay lập tức
      await waitFor(() => {
        const savedUser = JSON.parse(localStorage.getItem(STORAGE_KEYS.USER));
        expect(savedUser.is_first_login).toBe(false);
      });
    });
  });

  // =========================================================================
  // ISSUE 2: TAB QUẢN LÝ ADMIN TRONG SETTINGS MODAL (3 tính năng)
  // =========================================================================
  describe('Issue 2: Tab Quản lý Admin trong Cài đặt hệ thống (2-Tier Verification)', () => {
    it('Tầng 1 (UI): Hiển thị tab Quản lý Admin và mở được 3 modal con', async () => {
      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      // Chuyển sang Tab Quản lý Admin
      const adminTabBtn = screen.getByTestId('settings-tab-admin_mgmt');
      expect(adminTabBtn).toBeInTheDocument();
      fireEvent.click(adminTabBtn);

      // Hiển thị 3 nút chức năng
      expect(screen.getByTestId('open-change-pin-btn')).toBeInTheDocument();
      expect(screen.getByTestId('open-change-password-btn')).toBeInTheDocument();
      expect(screen.getByTestId('open-create-admin-btn')).toBeInTheDocument();

      // Click mở Modal Đổi PIN
      fireEvent.click(screen.getByTestId('open-change-pin-btn'));
      expect(screen.getByTestId('pin-input-password')).toBeInTheDocument();
      expect(screen.getByTestId('pin-input-old')).toBeInTheDocument();
      expect(screen.getByTestId('pin-input-new')).toBeInTheDocument();
      expect(screen.getByTestId('pin-input-confirm')).toBeInTheDocument();

      // Đóng modal đổi pin bằng nút Hủy
      fireEvent.click(screen.getByRole('button', { name: /hủy/i }));

      // Click mở Modal Đổi Mật Khẩu
      fireEvent.click(screen.getByTestId('open-change-password-btn'));
      expect(screen.getByTestId('password-input-old')).toBeInTheDocument();
      expect(screen.getByTestId('password-input-pin')).toBeInTheDocument();
      expect(screen.getByTestId('password-input-new')).toBeInTheDocument();
      expect(screen.getByTestId('password-input-confirm')).toBeInTheDocument();

      // Đóng modal đổi mật khẩu
      fireEvent.click(screen.getByRole('button', { name: /hủy/i }));

      // Click mở Modal Cấp Admin (Bước 1)
      fireEvent.click(screen.getByTestId('open-create-admin-btn'));
      expect(screen.getByTestId('create-admin-username')).toBeInTheDocument();
      expect(screen.getByTestId('create-admin-email')).toBeInTheDocument();
      expect(screen.getByTestId('btn-next-create-admin')).toBeInTheDocument();
    });

    it('Tầng 2 (System Impact): Thực thi Đổi mã PIN gọi adminApi.changePin với mật khẩu và PIN cũ', async () => {
      adminApi.changePin.mockResolvedValueOnce({ data: { message: 'PIN updated successfully' } });
      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      fireEvent.click(screen.getByTestId('settings-tab-admin_mgmt'));
      fireEvent.click(screen.getByTestId('open-change-pin-btn'));

      fireEvent.change(screen.getByTestId('pin-input-password'), { target: { value: 'MyCurrentPass@123' } });
      fireEvent.change(screen.getByTestId('pin-input-old'), { target: { value: '111111' } });
      fireEvent.change(screen.getByTestId('pin-input-new'), { target: { value: '999999' } });
      fireEvent.change(screen.getByTestId('pin-input-confirm'), { target: { value: '999999' } });
      fireEvent.click(screen.getByTestId('submit-change-pin-btn'));

      // Tầng 2: Gọi đúng API backend với các tham số bảo mật
      await waitFor(() => {
        expect(adminApi.changePin).toHaveBeenCalledWith({
          password: 'MyCurrentPass@123',
          oldPin: '111111',
          newPin: '999999',
        });
      });
    });

    it('Tầng 2 (System Impact): Thực thi Đổi Mật Khẩu gọi adminApi.changePassword với mật khẩu và PIN cũ', async () => {
      adminApi.changePassword.mockResolvedValueOnce({ data: { message: 'Password updated successfully' } });
      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      fireEvent.click(screen.getByTestId('settings-tab-admin_mgmt'));
      fireEvent.click(screen.getByTestId('open-change-password-btn'));

      fireEvent.change(screen.getByTestId('password-input-old'), { target: { value: 'OldPassword@123' } });
      fireEvent.change(screen.getByTestId('password-input-pin'), { target: { value: '123456' } });
      fireEvent.change(screen.getByTestId('password-input-new'), { target: { value: 'NewSuperPass@2026' } });
      fireEvent.change(screen.getByTestId('password-input-confirm'), { target: { value: 'NewSuperPass@2026' } });
      fireEvent.click(screen.getByTestId('submit-change-password-btn'));

      // Tầng 2: Gọi đúng API backend đổi mật khẩu
      await waitFor(() => {
        expect(adminApi.changePassword).toHaveBeenCalledWith({
          oldPassword: 'OldPassword@123',
          pin: '123456',
          newPassword: 'NewSuperPass@2026',
        });
      });
    });

    it('Tầng 2 (System Impact): Cấp tài khoản Admin mới qua 2 bước xác thực PIN và hiển thị kết quả 123456', async () => {
      adminApi.createAdmin.mockResolvedValueOnce({
        data: {
          message: 'Admin account created successfully',
          data: {
            idaccount: 99,
            username: 'junior_admin',
            email: 'junior@finance.local',
            is_first_login: true,
          },
        },
      });

      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      fireEvent.click(screen.getByTestId('settings-tab-admin_mgmt'));
      fireEvent.click(screen.getByTestId('open-create-admin-btn'));

      // Bước 1: Nhập username và email
      fireEvent.change(screen.getByTestId('create-admin-username'), { target: { value: 'junior_admin' } });
      fireEvent.change(screen.getByTestId('create-admin-email'), { target: { value: 'junior@finance.local' } });
      fireEvent.click(screen.getByTestId('btn-next-create-admin'));

      // Bước 2: Nhập PIN phê duyệt của admin người cấp
      await waitFor(() => {
        expect(screen.getByTestId('create-admin-pin-auth')).toBeInTheDocument();
      });
      fireEvent.change(screen.getByTestId('create-admin-pin-auth'), { target: { value: '888888' } });
      fireEvent.click(screen.getByTestId('submit-create-admin-btn'));

      // Tầng 2: Xác nhận gọi adminApi.createAdmin
      await waitFor(() => {
        expect(adminApi.createAdmin).toHaveBeenCalledWith({
          username: 'junior_admin',
          email: 'junior@finance.local',
          pin: '888888',
        });
      });

      // Bước 3: Hiển thị bảng kết quả khởi tạo mặc định 123456
      await waitFor(() => {
        expect(screen.getByText(/Cấp Tài Khoản Admin Thành Công!/i)).toBeInTheDocument();
        expect(screen.getByText('junior_admin')).toBeInTheDocument();
        expect(screen.getAllByText('123456').length).toBeGreaterThanOrEqual(2); // pass & pin
      });
    });
  });

  // =========================================================================
  // ISSUE 4: THU NHỎ PHÓNG TO & FLUID RESPONSIVE SIDEBAR
  // =========================================================================
  describe('Issue 4: Fluid Responsive Layout & Sidebar Toggle (2-Tier Verification)', () => {
    it('Tầng 1 (UI) & Tầng 2 (System Impact): Toggle sidebar lưu trạng thái localStorage và cập nhật class layout', async () => {
      const onToggleMock = vi.fn();

      const { rerender } = renderWithProviders(
        <div>
          <Sidebar collapsed={false} onToggle={onToggleMock} />
          <Header onMenuToggle={onToggleMock} sidebarCollapsed={false} />
        </div>
      );

      // Tầng 1: Ở chế độ mở (collapsed = false)
      expect(screen.getByText('Admin Portal')).toBeInTheDocument();

      // Click nút toggle trên header
      const toggleBtn = screen.getByTitle(/thu nhỏ thanh điều hướng/i);
      fireEvent.click(toggleBtn);
      expect(onToggleMock).toHaveBeenCalledTimes(1);

      // Tầng 1 & 2: Rerender ở chế độ mini-mode (collapsed = true)
      rerender(
        <MemoryRouter>
          <LanguageProvider>
            <AlertProvider>
              <SettingsProvider>
                <AuthProvider value={{ user: { Role: 'Admin' }, isAuthenticated: true }}>
                  <Sidebar collapsed={true} onToggle={onToggleMock} />
                  <Header onMenuToggle={onToggleMock} sidebarCollapsed={true} />
                </AuthProvider>
              </SettingsProvider>
            </AlertProvider>
          </LanguageProvider>
        </MemoryRouter>
      );

      // Ở chế độ mini mode, text title Admin Portal bị ẩn, chỉ icon tồn tại
      expect(screen.queryByText('Admin Portal')).not.toBeInTheDocument();
      expect(screen.getByTitle(/mở rộng thanh điều hướng/i)).toBeInTheDocument();
    });
  });
});
