import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import { SettingsProvider, useSettings } from '../store/settings.context';
import { AuthProvider } from '../store/auth.context';
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

const TestLockController = () => {
  const { isLocked, lockScreen, unlockScreen } = useSettings();
  const [pass, setPass] = React.useState('');
  const [unlockErr, setUnlockErr] = React.useState('');

  const handleUnlock = async () => {
    try {
      setUnlockErr('');
      await unlockScreen(pass);
    } catch (err) {
      setUnlockErr(err.message || 'Mật khẩu sai');
    }
  };

  return (
    <div>
      <div data-testid="is-locked-status">{isLocked ? 'LOCKED' : 'UNLOCKED'}</div>
      <button data-testid="btn-trigger-lock" onClick={lockScreen}>
        Kích hoạt Khóa
      </button>
      <input
        data-testid="input-unlock-pass"
        value={pass}
        onChange={(e) => setPass(e.target.value)}
      />
      <button data-testid="btn-trigger-unlock" onClick={handleUnlock}>
        Mở Khóa
      </button>
      {unlockErr && <div data-testid="unlock-error-msg">{unlockErr}</div>}
      <LockScreenModal />
    </div>
  );
};

describe('Admin-web Auto-Lock & Token Wipe Security Suite (2-Tier Testing)', () => {
  const mockUser = {
    idaccount: 1,
    fullname: 'Trần Quản Trị',
    username: 'admin_security',
    email: 'admin@finance.local',
    idrole: 1,
    rolename: 'admin',
  };

  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
    document.documentElement.className = '';
  });

  // =========================================================================
  // TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN (UI Rendering & Interaction)
  // =========================================================================
  describe('🧱 TẦNG 1: UI Rendering & Thao tác tại LockScreenModal', () => {
    it('1.1. Render đầy đủ thông tin danh tính Admin và các controls trên màn hình khóa', () => {
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockUser));

      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockController />
          </AuthProvider>
        </SettingsProvider>
      );

      // Verify thông tin hiển thị
      expect(screen.getByTestId('is-locked-status').textContent).toBe('LOCKED');
      expect(screen.getByText('Trần Quản Trị')).toBeInTheDocument();
      expect(screen.getByText('admin@finance.local')).toBeInTheDocument();
      expect(screen.getByText('T')).toBeInTheDocument(); // Avatar letter

      // Verify Form inputs
      expect(screen.getByPlaceholderText(/Mật khẩu quản trị viên/i)).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Mở Khóa Màn Hình/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Đăng xuất/i })).toBeInTheDocument();
    });

    it('1.2. Thao tác nhập mật khẩu và toggle hiển thị/ẩn mật khẩu', () => {
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockUser));

      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockController />
          </AuthProvider>
        </SettingsProvider>
      );

      const passInputs = screen.getAllByPlaceholderText(/Mật khẩu quản trị viên/i);
      const modalPassInput = passInputs[passInputs.length - 1];
      expect(modalPassInput.type).toBe('password');

      // Nhập mật khẩu
      fireEvent.change(modalPassInput, { target: { value: 'Secret@123' } });
      expect(modalPassInput.value).toBe('Secret@123');

      // Toggle hiển thị
      const toggleVisBtn = screen.getByText('visibility').closest('button');
      fireEvent.click(toggleVisBtn);
      expect(modalPassInput.type).toBe('text');
      expect(screen.getByText('visibility_off')).toBeInTheDocument();
    });

    it('1.3. Bắt lỗi tại chỗ khi bấm Mở khóa với mật khẩu rỗng', async () => {
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockUser));

      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockController />
          </AuthProvider>
        </SettingsProvider>
      );

      const unlockBtn = screen.getByRole('button', { name: /Mở Khóa Màn Hình/i });
      fireEvent.click(unlockBtn);

      await waitFor(() => {
        expect(screen.getByText(/Vui lòng nhập mật khẩu tài khoản quản trị/i)).toBeInTheDocument();
      });
    });
  });

  // =========================================================================
  // TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG & BẢO MẬT THỰC TẾ (System Impact)
  // =========================================================================
  describe('⚡ TẦNG 2: Real System Impact & Token Destruction Verification', () => {
    it('2.1. Kích hoạt lockScreen() tiêu hủy 100% JWT Tokens khỏi localStorage', () => {
      // Giả lập trạng thái đã đăng nhập bình thường có token
      localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'access_jwt_valid_123');
      localStorage.setItem(STORAGE_KEYS.REFRESH_TOKEN, 'refresh_jwt_valid_7days');
      localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(mockUser));

      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockController />
          </AuthProvider>
        </SettingsProvider>
      );

      expect(screen.getByTestId('is-locked-status').textContent).toBe('UNLOCKED');
      expect(localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN)).toBe('access_jwt_valid_123');
      expect(localStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN)).toBe('refresh_jwt_valid_7days');

      // Kích hoạt khóa màn hình
      act(() => {
        screen.getByTestId('btn-trigger-lock').click();
      });

      // Tác động hệ thống: CẢ 2 TOKEN BỊ TIÊU HỦY HOÀN TOÀN KHỎI BỘ NHỚ TRÌNH DUYỆT!
      expect(screen.getByTestId('is-locked-status').textContent).toBe('LOCKED');
      expect(localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN)).toBeNull();
      expect(localStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN)).toBeNull();

      // Cờ khóa bền vững được lưu trữ
      expect(localStorage.getItem(STORAGE_KEYS.IS_LOCKED)).toBe('true');
      expect(localStorage.getItem(STORAGE_KEYS.LOCKED_AT)).toBeDefined();

      // Snapshot người dùng an toàn được lưu lại
      const lockedUserRaw = localStorage.getItem(STORAGE_KEYS.LOCKED_USER);
      expect(lockedUserRaw).toBeDefined();
      const lockedUserData = JSON.parse(lockedUserRaw);
      expect(lockedUserData.username).toBe('admin_security');
    });

    it('2.2. Chống Bypass: Reload trang (F5) khi đang khóa vẫn duy trì khóa và không có JWT', () => {
      // Giả lập trạng thái trước đó đã bị khóa
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_AT, '10:30');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockUser));
      // Không có token trong localStorage
      localStorage.removeItem(STORAGE_KEYS.ACCESS_TOKEN);
      localStorage.removeItem(STORAGE_KEYS.REFRESH_TOKEN);

      // Reload trang (render mới hoàn toàn)
      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockController />
          </AuthProvider>
        </SettingsProvider>
      );

      // Xác nhận: Hệ thống lập tức nhận diện trạng thái khóa từ storage, không thể bypass!
      expect(screen.getByTestId('is-locked-status').textContent).toBe('LOCKED');
      expect(localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN)).toBeNull();
      expect(localStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN)).toBeNull();
      expect(screen.getByText('Trần Quản Trị')).toBeInTheDocument();
    });

    it('2.3. Tự động Khóa & Tiêu Hủy Token sau 60 phút offline khi người dùng mở lại trang', () => {
      const now = Date.now();
      const sixtyFiveMinutesAgo = now - 65 * 60 * 1000;

      // Giả lập có token và mốc hoạt động cuối cùng là 65 phút trước
      localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'old_token_123');
      localStorage.setItem(STORAGE_KEYS.REFRESH_TOKEN, 'old_refresh_123');
      localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(mockUser));
      localStorage.setItem(STORAGE_KEYS.LAST_ACTIVE_AT, String(sixtyFiveMinutesAgo));
      localStorage.setItem('admin_system_settings', JSON.stringify({ autoLockMinutes: 60 }));

      // Người dùng mở lại trang sau 65 phút offline
      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockController />
          </AuthProvider>
        </SettingsProvider>
      );

      // Tác động hệ thống: Nhận diện hết hạn session nhàn rỗi, lập tức khóa và xóa token!
      expect(screen.getByTestId('is-locked-status').textContent).toBe('LOCKED');
      expect(localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN)).toBeNull();
      expect(localStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN)).toBeNull();
      expect(localStorage.getItem(STORAGE_KEYS.IS_LOCKED)).toBe('true');
    });

    it('2.4. Mở khóa với mật khẩu đúng: Cấp Token mới, xóa cờ khóa và phục hồi trạng thái', async () => {
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockUser));

      authApi.login.mockResolvedValueOnce({
        data: {
          accessToken: 'fresh_access_token_999',
          refreshToken: 'fresh_refresh_token_999',
          user: mockUser,
        },
      });

      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockController />
          </AuthProvider>
        </SettingsProvider>
      );

      expect(screen.getByTestId('is-locked-status').textContent).toBe('LOCKED');

      // Nhập mật khẩu đúng và bấm mở khóa
      fireEvent.change(screen.getByTestId('input-unlock-pass'), { target: { value: 'CorrectPass@123' } });
      
      await act(async () => {
        screen.getByTestId('btn-trigger-unlock').click();
      });

      // Tác động hệ thống:
      // 1. API login được gọi đúng username của admin đang bị khóa
      expect(authApi.login).toHaveBeenCalledWith({
        username: 'admin_security',
        password: 'CorrectPass@123',
      });

      // 2. Token mới được lưu lại vào localStorage
      expect(localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN)).toBe('fresh_access_token_999');
      expect(localStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN)).toBe('fresh_refresh_token_999');

      // 3. Cờ khóa được xóa sạch
      expect(localStorage.getItem(STORAGE_KEYS.IS_LOCKED)).toBeNull();
      expect(localStorage.getItem(STORAGE_KEYS.LOCKED_USER)).toBeNull();

      // 4. Màn hình chuyển sang UNLOCKED
      expect(screen.getByTestId('is-locked-status').textContent).toBe('UNLOCKED');
    });

    it('2.5. Nhập mật khẩu sai: Backend từ chối 401, không cấp token, màn hình tiếp tục khóa', async () => {
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockUser));

      authApi.login.mockRejectedValueOnce(new Error('Mật khẩu không chính xác'));

      render(
        <SettingsProvider>
          <AuthProvider>
            <TestLockController />
          </AuthProvider>
        </SettingsProvider>
      );

      fireEvent.change(screen.getByTestId('input-unlock-pass'), { target: { value: 'WrongPass@999' } });

      await act(async () => {
        screen.getByTestId('btn-trigger-unlock').click();
      });

      // Tác động hệ thống:
      // 1. Màn hình VẪN TIẾP TỤC KHÓA
      expect(screen.getByTestId('is-locked-status').textContent).toBe('LOCKED');
      // 2. Tuyệt đối KHÔNG có token nào trong localStorage
      expect(localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN)).toBeNull();
      expect(localStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN)).toBeNull();
      // 3. Hiển thị thông báo lỗi
      expect(screen.getByTestId('unlock-error-msg')).toHaveTextContent(/Mật khẩu không chính xác/i);
    });

    it('2.6. Đăng xuất từ màn hình khóa: Xóa sạch toàn bộ storage và phiên làm việc', async () => {
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(mockUser));

      // Mock window.confirm trả về true
      const origConfirm = window.confirm;
      window.confirm = () => true;

      try {
        render(
          <SettingsProvider>
            <AuthProvider>
              <TestLockController />
            </AuthProvider>
          </SettingsProvider>
        );

        const logoutBtn = screen.getByRole('button', { name: /Đăng xuất/i });
        await act(async () => {
          fireEvent.click(logoutBtn);
        });

        // Tác động hệ thống: Toàn bộ thông tin phiên bị dọn sạch
        expect(localStorage.getItem(STORAGE_KEYS.IS_LOCKED)).toBeNull();
        expect(localStorage.getItem(STORAGE_KEYS.LOCKED_USER)).toBeNull();
        expect(localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN)).toBeNull();
        expect(localStorage.getItem(STORAGE_KEYS.USER)).toBeNull();
      } finally {
        window.confirm = origConfirm;
      }
    });
  });
});
