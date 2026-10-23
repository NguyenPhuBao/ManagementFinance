import React from 'react';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import SecurityConfirmModal from '../components/common/SecurityConfirmModal';
import SettingsModal from '../components/layout/SettingsModal';
import adminApi from '../api/admin.api';
import axiosClient from '../api/axios-client';
import { STORAGE_KEYS } from '../utils/constants';

// Mock adminApi
vi.mock('../api/admin.api', () => ({
  default: {
    verifySecurityAction: vi.fn(),
    changePin: vi.fn().mockResolvedValue({ data: { message: 'Đổi mã PIN thành công' } }),
    changePassword: vi.fn().mockResolvedValue({ data: { message: 'Đổi mật khẩu thành công' } }),
    createAdmin: vi.fn().mockResolvedValue({ data: { success: true } }),
  },
}));

// Mock Contexts
const mockSettings = {
  settings: {
    theme: 'light',
    density: 'comfortable',
    soundEnabled: true,
    toastDuration: 4500,
    metricsInterval: 3000,
    autoLockTime: 30,
  },
  theme: 'light',
  density: 'comfortable',
  soundEnabled: true,
  toastDuration: 4500,
  metricsInterval: 3000,
  autoLockTime: 30,
  isLocked: false,
  updateSetting: vi.fn(),
  resetSettings: vi.fn(),
  resetToDefaults: vi.fn(),
  safeClearCache: vi.fn(),
  getStorageUsageKb: vi.fn().mockReturnValue(12),
  testPingLatency: vi.fn(),
  lockScreen: vi.fn(),
};

vi.mock('../store/settings.context', () => ({
  useSettings: () => mockSettings,
  useSettingsSafe: () => mockSettings,
}));

vi.mock('../store/alert.context', () => ({
  useAlertSafe: () => ({
    success: vi.fn(),
    error: vi.fn(),
    warning: vi.fn(),
  }),
}));

const renderWithProviders = (ui) => {
  return render(<MemoryRouter>{ui}</MemoryRouter>);
};

describe('Test Suite: PIN Verification & Security Validation (Rule 11 - 2-Tier Testing)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
    localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'mock_access_token_123');
    localStorage.setItem(STORAGE_KEYS.REFRESH_TOKEN, 'mock_refresh_token_456');
    localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify({ idaccount: 1, username: 'admin', rolename: 'admin' }));
  });

  afterEach(() => {
    localStorage.clear();
  });

  // =========================================================================
  // 1. ISSUE 1: XÁC THỰC MÃ PIN (Không out về login khi sai PIN)
  // =========================================================================
  describe('1. Issue 1: Xác Thực Mã PIN An Toàn (Zero Session Drop)', () => {
    it('1.1. Tầng 1: Nhập sai mã PIN hiển thị thông báo lỗi đỏ và giữ nguyên modal', async () => {
      adminApi.verifySecurityAction.mockRejectedValueOnce({
        response: { data: { message: 'Mã PIN hoặc mật khẩu quản trị viên không chính xác!' } },
      });

      render(
        <SecurityConfirmModal
          isOpen={true}
          onClose={vi.fn()}
          onConfirm={vi.fn()}
          title="Xác thực hành động khẩn cấp"
          description="Vui lòng xác nhận mã PIN quản trị."
        />
      );

      const pinInput = screen.getByPlaceholderText(/Nhập mã PIN 6 số/i);
      fireEvent.change(pinInput, { target: { value: '999999' } });

      const submitBtn = screen.getByRole('button', { name: /Xác thực & Thực thi/i });
      fireEvent.click(submitBtn);

      await waitFor(() => {
        expect(screen.getByText('Mã PIN hoặc mật khẩu quản trị viên không chính xác!')).toBeInTheDocument();
      });
      // Modal vẫn hiển thị, không bị unmount/đóng
      expect(screen.getByText('Xác thực hành động khẩn cấp')).toBeInTheDocument();
    });

    it('1.2. Tầng 2 (System Impact): Khi API xác thực mã PIN thất bại, axios-client KHÔNG xóa token và KHÔNG out về login', async () => {
      // Giả lập request thất bại đến endpoint verify-security-action với status 401
      const mockError = {
        config: { url: '/admin/verify-security-action', _retry: true },
        response: { status: 401, data: { message: 'Mã PIN hoặc mật khẩu quản trị viên không chính xác!' } },
      };

      // Đưa lỗi vào response interceptor của axiosClient
      const errorInterceptor = axiosClient.interceptors.response.handlers[0].rejected;

      await expect(errorInterceptor(mockError)).rejects.toEqual(mockError);

      // KHẲNG ĐỊNH TẦNG 2: Toàn bộ Token và phiên đăng nhập vẫn được bảo toàn nguyên vẹn 100%
      expect(localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN)).toBe('mock_access_token_123');
      expect(localStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN)).toBe('mock_refresh_token_456');
      expect(localStorage.getItem(STORAGE_KEYS.USER)).toContain('admin');
    });
  });

  // =========================================================================
  // 2. ISSUE 2 - PHẦN A: ĐỔI MÃ PIN (Validation không trùng PIN cũ & chỉ nhận số)
  // =========================================================================
  describe('2. Issue 2 - Phần A: Validation Đổi Mã PIN', () => {
    it('2.1. Tầng 1: Chặn submit và hiển thị lỗi khi mã PIN mới trùng với mã PIN hiện tại', async () => {
      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      fireEvent.click(screen.getByRole('button', { name: /Bảo Mật & Thông Tin/i }));
      fireEvent.click(screen.getByRole('button', { name: /Đổi mã PIN/i }));

      // Nhập mật khẩu hiện tại
      fireEvent.change(screen.getByPlaceholderText('••••••••'), { target: { value: 'AdminPass@123' } });
      // Nhập mã PIN cũ
      fireEvent.change(screen.getByPlaceholderText('6 chữ số cũ'), { target: { value: '123456' } });
      // Nhập mã PIN mới TRÙNG với mã PIN cũ
      fireEvent.change(screen.getByPlaceholderText('6 chữ số mới'), { target: { value: '123456' } });
      fireEvent.change(screen.getByPlaceholderText('Nhập lại 6 số'), { target: { value: '123456' } });

      fireEvent.click(screen.getByRole('button', { name: /Lưu mã PIN mới/i }));

      // Tầng 1 Assertion: Hiển thị thông báo lỗi không trùng PIN
      expect(screen.getByText('Mã PIN mới không được trùng với mã PIN hiện tại')).toBeInTheDocument();

      // Tầng 2 Assertion: adminApi.changePin KHÔNG được gọi
      expect(adminApi.changePin).not.toHaveBeenCalled();
    });

    it('2.2. Tầng 1 & Tầng 2: Ô nhập PIN chỉ cho phép nhập số (tự động loại bỏ chữ cái)', async () => {
      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      fireEvent.click(screen.getByRole('button', { name: /Bảo Mật & Thông Tin/i }));
      fireEvent.click(screen.getByRole('button', { name: /Đổi mã PIN/i }));

      const newPinInput = screen.getByPlaceholderText('6 chữ số mới');

      // Nhập lẫn lộn chữ và số: "12abc34xyz56"
      fireEvent.change(newPinInput, { target: { value: '12abc34xyz56' } });

      // Tầng 1 Assertion: Input chỉ giữ lại các ký tự số đúng 6 ký tự
      expect(newPinInput.value).toBe('123456');

      // Kiểm tra ô PIN cũ cũng chỉ nhận số
      const oldPinInput = screen.getByPlaceholderText('6 chữ số cũ');
      fireEvent.change(oldPinInput, { target: { value: 'invalid-pin-654321' } });
      expect(oldPinInput.value).toBe('654321');
    });

    it('2.3. Tầng 2: Form hợp lệ với mã PIN mới khác mã PIN cũ gọi đúng adminApi.changePin', async () => {
      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      fireEvent.click(screen.getByRole('button', { name: /Bảo Mật & Thông Tin/i }));
      fireEvent.click(screen.getByRole('button', { name: /Đổi mã PIN/i }));

      fireEvent.change(screen.getByPlaceholderText('••••••••'), { target: { value: 'AdminPass@123' } });
      fireEvent.change(screen.getByPlaceholderText('6 chữ số cũ'), { target: { value: '123456' } });
      fireEvent.change(screen.getByPlaceholderText('6 chữ số mới'), { target: { value: '654321' } });
      fireEvent.change(screen.getByPlaceholderText('Nhập lại 6 số'), { target: { value: '654321' } });

      fireEvent.click(screen.getByRole('button', { name: /Lưu mã PIN mới/i }));

      await waitFor(() => {
        expect(adminApi.changePin).toHaveBeenCalledWith({
          password: 'AdminPass@123',
          oldPin: '123456',
          newPin: '654321',
        });
      });
    });
  });

  // =========================================================================
  // 3. ISSUE 2 - PHẦN B: ĐỔI MẬT KHẨU (Validation không trùng Mật khẩu cũ & PIN chỉ nhận số)
  // =========================================================================
  describe('3. Issue 2 - Phần B: Validation Đổi Mật Khẩu', () => {
    it('3.1. Tầng 1: Chặn submit và hiển thị lỗi khi mật khẩu mới trùng với mật khẩu hiện tại', async () => {
      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      fireEvent.click(screen.getByRole('button', { name: /Quản Lý Admin/i }));
      fireEvent.click(screen.getByRole('button', { name: /Đổi Mật Khẩu/i }));

      // Nhập mật khẩu hiện tại
      fireEvent.change(screen.getByTestId('password-input-old'), { target: { value: 'Admin@123456' } });
      // Nhập mã PIN bảo mật
      fireEvent.change(screen.getByTestId('password-input-pin'), { target: { value: '123456' } });
      // Nhập mật khẩu mới TRÙNG với mật khẩu hiện tại
      fireEvent.change(screen.getByTestId('password-input-new'), { target: { value: 'Admin@123456' } });
      fireEvent.change(screen.getByTestId('password-input-confirm'), { target: { value: 'Admin@123456' } });

      fireEvent.click(screen.getByTestId('submit-change-password-btn'));

      // Tầng 1 Assertion: Hiển thị lỗi không trùng mật khẩu
      expect(screen.getByText('Mật khẩu mới không được trùng với mật khẩu hiện tại')).toBeInTheDocument();

      // Tầng 2 Assertion: adminApi.changePassword KHÔNG được gọi
      expect(adminApi.changePassword).not.toHaveBeenCalled();
    });

    it('3.2. Tầng 1 & Tầng 2: Ô nhập PIN bảo mật trong form đổi mật khẩu chỉ cho phép nhập số', async () => {
      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      fireEvent.click(screen.getByRole('button', { name: /Quản Lý Admin/i }));
      fireEvent.click(screen.getByRole('button', { name: /Đổi Mật Khẩu/i }));

      const pinInput = screen.getByTestId('password-input-pin');

      // Nhập chữ lẫn số vào ô PIN bảo mật
      fireEvent.change(pinInput, { target: { value: 'pin-abc-654321' } });

      // Tầng 1 Assertion: Lọc ký tự chữ, chỉ giữ lại số
      expect(pinInput.value).toBe('654321');
    });

    it('3.3. Tầng 2: Form đổi mật khẩu hợp lệ gọi đúng adminApi.changePassword', async () => {
      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      fireEvent.click(screen.getByRole('button', { name: /Quản Lý Admin/i }));
      fireEvent.click(screen.getByRole('button', { name: /Đổi Mật Khẩu/i }));

      fireEvent.change(screen.getByTestId('password-input-old'), { target: { value: 'OldAdmin@123' } });
      fireEvent.change(screen.getByTestId('password-input-pin'), { target: { value: '123456' } });
      fireEvent.change(screen.getByTestId('password-input-new'), { target: { value: 'NewAdmin@2026' } });
      fireEvent.change(screen.getByTestId('password-input-confirm'), { target: { value: 'NewAdmin@2026' } });

      fireEvent.click(screen.getByTestId('submit-change-password-btn'));

      await waitFor(() => {
        expect(adminApi.changePassword).toHaveBeenCalledWith({
          oldPassword: 'OldAdmin@123',
          pin: '123456',
          newPassword: 'NewAdmin@2026',
        });
      });
    });
  });
});
