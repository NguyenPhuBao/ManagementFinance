import React from 'react';
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import LoginPage from '../pages/auth/LoginPage';
import ForgotPasswordPage from '../pages/auth/ForgotPasswordPage';
import LockScreenModal from '../components/layout/LockScreenModal';
import FirstLoginModal from '../components/layout/FirstLoginModal';
import { LanguageProvider } from '../store/language.context';
import { STORAGE_KEYS } from '../utils/constants';
import adminApi from '../api/admin.api';

const navigate = vi.fn();
const authState = {};
const settingsState = {};
const notify = { success: vi.fn(), error: vi.fn() };

vi.mock('react-router-dom', async (importOriginal) => ({
  ...(await importOriginal()),
  useNavigate: () => navigate,
}));
vi.mock('../store/auth.context', () => ({ useAuthContext: () => authState }));
vi.mock('../store/settings.context', () => ({ useSettingsSafe: () => settingsState }));
vi.mock('../store/alert.context', () => ({ useAlertSafe: () => notify }));
vi.mock('../api/admin.api', () => ({ default: { firstLoginSetup: vi.fn() } }));

const inRouter = (ui) => render(<MemoryRouter>{ui}</MemoryRouter>);
const apiError = (message) => Object.assign(new Error('x'), { response: { data: { message } } });
const LOCKED_USER = { username: 'admin.local', email: 'admin@local.test', fullname: 'Quản Trị' };

beforeEach(() => {
  localStorage.clear();
  navigate.mockReset();
  notify.success.mockReset();
  Object.keys(authState).forEach((k) => delete authState[k]);
  Object.keys(settingsState).forEach((k) => delete settingsState[k]);
  Object.assign(authState, {
    user: null,
    login: vi.fn().mockResolvedValue({}),
    logout: vi.fn().mockResolvedValue(),
    syncAuthSession: vi.fn(),
  });
  Object.assign(settingsState, {
    isLocked: false,
    lockedAt: null,
    resetLockState: vi.fn(),
    unlockScreen: vi.fn(),
  });
  adminApi.firstLoginSetup.mockReset().mockResolvedValue({ data: { user: { username: 'admin.local' } } });
});

describe('Đăng nhập', () => {
  it('có tiêu đề, hai ô có nhãn, nút ẩn/hiện mật khẩu, liên kết Quên mật khẩu, nút đổi ngôn ngữ; không chữ kỹ thuật, không ảnh ngoài', () => {
    const { container } = inRouter(<LoginPage />);
    expect(screen.getByRole('heading', { level: 1, name: 'Đăng nhập' })).toBeInTheDocument();
    expect(screen.getByLabelText('Email hoặc tên đăng nhập')).toBeInTheDocument();
    const pw = screen.getByLabelText('Mật khẩu');
    expect(pw).toHaveAttribute('type', 'password');
    fireEvent.click(screen.getByRole('button', { name: 'Hiện mật khẩu' }));
    expect(pw).toHaveAttribute('type', 'text');
    expect(screen.getByRole('link', { name: 'Quên mật khẩu?' })).toHaveAttribute('href', '/forgot-password');
    expect(screen.getByTestId('language-toggle')).toBeInTheDocument();
    expect(document.body.textContent).not.toMatch(/256-bit|realtime/i);
    expect(container.innerHTML).not.toMatch(/unsplash|https?:\/\//);
    expect(settingsState.resetLockState).toHaveBeenCalled();
  });

  it('gửi gọi login đúng tham số, xóa cờ khóa rồi sang Tổng quan; nút khóa khi đang gửi', async () => {
    let resolve;
    authState.login.mockReturnValue(new Promise((r) => { resolve = r; }));
    inRouter(<LoginPage />);
    settingsState.resetLockState.mockClear();
    fireEvent.change(screen.getByLabelText('Email hoặc tên đăng nhập'), { target: { value: 'admin.local' } });
    fireEvent.change(screen.getByLabelText('Mật khẩu'), { target: { value: 'AdminWeb@2026' } });
    fireEvent.click(screen.getByRole('button', { name: 'Đăng nhập' }));
    expect(authState.login).toHaveBeenCalledWith({ username: 'admin.local', password: 'AdminWeb@2026' });
    await waitFor(() => expect(screen.getByRole('button', { name: 'Đăng nhập' })).toBeDisabled());
    resolve({});
    await waitFor(() => expect(navigate).toHaveBeenCalledWith('/dashboard'));
    expect(settingsState.resetLockState).toHaveBeenCalled();
  });

  it('thất bại thì hiện lỗi của máy chủ, không chuyển trang', async () => {
    authState.login.mockRejectedValue(apiError('Sai tài khoản hoặc mật khẩu'));
    inRouter(<LoginPage />);
    fireEvent.change(screen.getByLabelText('Email hoặc tên đăng nhập'), { target: { value: 'a' } });
    fireEvent.change(screen.getByLabelText('Mật khẩu'), { target: { value: 'b' } });
    fireEvent.click(screen.getByRole('button', { name: 'Đăng nhập' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Sai tài khoản hoặc mật khẩu');
    expect(navigate).not.toHaveBeenCalled();
  });

  it('đổi sang EN thì chữ đổi theo', () => {
    render(
      <LanguageProvider>
        <MemoryRouter>
          <LoginPage />
        </MemoryRouter>
      </LanguageProvider>
    );
    fireEvent.click(screen.getByTestId('lang-btn-en'));
    expect(screen.getByRole('heading', { level: 1, name: 'Sign in' })).toBeInTheDocument();
    expect(screen.getByLabelText('Email or username')).toBeInTheDocument();
  });
});

describe('Quên mật khẩu', () => {
  it('có tiêu đề, cảnh báo, số điện thoại gọi được, liên kết về Đăng nhập, nút đổi ngôn ngữ', () => {
    inRouter(<ForgotPasswordPage />);
    expect(screen.getByRole('heading', { level: 1, name: 'Quên mật khẩu' })).toBeInTheDocument();
    expect(screen.getByText('Tài khoản quản trị không tự đặt lại mật khẩu được.')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /355 281 276/ })).toHaveAttribute('href', 'tel:+84355281276');
    expect(screen.getByRole('link', { name: 'Về trang đăng nhập' })).toHaveAttribute('href', '/login');
    expect(screen.getByTestId('language-toggle')).toBeInTheDocument();
  });
});

describe('Khóa màn hình', () => {
  const lock = () => {
    settingsState.isLocked = true;
    settingsState.lockedAt = '10:30';
    localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify(LOCKED_USER));
  };

  it('không khóa thì không hiện gì', () => {
    render(<LockScreenModal />);
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('đang khóa: hộp có tên, hiện tài khoản và giờ khóa, không có nút đóng, Esc không đóng', () => {
    lock();
    render(<LockScreenModal />);
    const dialog = screen.getByRole('dialog', { name: 'Màn hình đã khóa' });
    expect(dialog.parentElement).toHaveClass('bg-canvas');
    expect(within(dialog).getByText('admin.local')).toBeInTheDocument();
    expect(within(dialog).getByText('admin@local.test')).toBeInTheDocument();
    expect(within(dialog).getByText('Khóa lúc 10:30')).toBeInTheDocument();
    expect(within(dialog).queryByRole('button', { name: 'Đóng' })).not.toBeInTheDocument();
    fireEvent.keyDown(window, { key: 'Escape' });
    expect(screen.getByRole('dialog', { name: 'Màn hình đã khóa' })).toBeInTheDocument();
  });

  it('mật khẩu trống thì báo lỗi và không gọi mở khóa', () => {
    lock();
    render(<LockScreenModal />);
    fireEvent.click(screen.getByRole('button', { name: 'Mở khóa' }));
    expect(screen.getByRole('alert')).toHaveTextContent('Nhập mật khẩu để mở khóa.');
    expect(settingsState.unlockScreen).not.toHaveBeenCalled();
  });

  it('mở khóa gọi unlockScreen với mật khẩu, đồng bộ phiên và báo thành công', async () => {
    lock();
    const session = { accessToken: 'a', user: LOCKED_USER };
    settingsState.unlockScreen.mockResolvedValue(session);
    render(<LockScreenModal />);
    fireEvent.change(screen.getByLabelText('Mật khẩu'), { target: { value: 'AdminWeb@2026' } });
    fireEvent.click(screen.getByRole('button', { name: 'Mở khóa' }));
    await waitFor(() => expect(authState.syncAuthSession).toHaveBeenCalledWith(session));
    expect(settingsState.unlockScreen).toHaveBeenCalledWith('AdminWeb@2026', authState.syncAuthSession);
    expect(notify.success).toHaveBeenCalledWith('Chào mừng trở lại, Quản Trị.', 'Đã mở khóa');
  });

  it('sai mật khẩu thì hiện lỗi của máy chủ', async () => {
    lock();
    settingsState.unlockScreen.mockRejectedValue(apiError('Mật khẩu sai'));
    render(<LockScreenModal />);
    fireEvent.change(screen.getByLabelText('Mật khẩu'), { target: { value: 'x' } });
    fireEvent.click(screen.getByRole('button', { name: 'Mở khóa' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Mật khẩu sai');
    expect(authState.syncAuthSession).not.toHaveBeenCalled();
  });

  it('đăng xuất qua hộp xác nhận: hủy thì giữ phiên, xác nhận thì xóa dữ liệu phiên và gọi logout', async () => {
    lock();
    localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
    localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(LOCKED_USER));
    const confirmSpy = vi.spyOn(window, 'confirm');
    render(<LockScreenModal />);
    const lockDialog = screen.getByRole('dialog', { name: 'Màn hình đã khóa' });
    fireEvent.click(within(lockDialog).getByRole('button', { name: 'Đăng xuất' }));
    const confirm = screen.getByRole('dialog', { name: 'Đăng xuất?' });
    fireEvent.click(within(confirm).getByRole('button', { name: 'Hủy bỏ' }));
    expect(screen.queryByRole('dialog', { name: 'Đăng xuất?' })).not.toBeInTheDocument();
    expect(authState.logout).not.toHaveBeenCalled();
    fireEvent.click(within(lockDialog).getByRole('button', { name: 'Đăng xuất' }));
    fireEvent.click(within(screen.getByRole('dialog', { name: 'Đăng xuất?' })).getByRole('button', { name: 'Đăng xuất' }));
    await waitFor(() => expect(authState.logout).toHaveBeenCalledTimes(1));
    expect(localStorage.getItem(STORAGE_KEYS.IS_LOCKED)).toBeNull();
    expect(localStorage.getItem(STORAGE_KEYS.LOCKED_USER)).toBeNull();
    expect(localStorage.getItem(STORAGE_KEYS.USER)).toBeNull();
    expect(confirmSpy).not.toHaveBeenCalled();
    confirmSpy.mockRestore();
  });
});

describe('Đăng nhập lần đầu', () => {
  const fill = ({ password = 'MatKhau@1', confirmPassword = password, pin = '246810', confirmPin = pin } = {}) => {
    fireEvent.change(screen.getByTestId('first-login-new-password'), { target: { value: password } });
    fireEvent.change(screen.getByTestId('first-login-confirm-password'), { target: { value: confirmPassword } });
    fireEvent.change(screen.getByTestId('first-login-new-pin'), { target: { value: pin } });
    fireEvent.change(screen.getByTestId('first-login-confirm-pin'), { target: { value: confirmPin } });
  };
  const submit = () => fireEvent.click(screen.getByTestId('first-login-submit-btn'));

  it('tài khoản đã thiết lập thì không hiện', () => {
    authState.user = { username: 'admin.local', is_first_login: false };
    render(<FirstLoginModal />);
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('lần đầu: hộp có tên, đủ bốn ô có nhãn, không nút đóng, Esc không đóng, không lộ mật khẩu mặc định', () => {
    authState.user = { username: 'admin.local', is_first_login: true };
    render(<FirstLoginModal />);
    const dialog = screen.getByRole('dialog', { name: 'Thiết lập bảo mật' });
    expect(dialog).toBe(screen.getByTestId('first-login-modal-overlay'));
    expect(dialog.parentElement).toHaveClass('bg-canvas');
    expect(screen.getByLabelText('Mật khẩu mới')).toBe(screen.getByTestId('first-login-new-password'));
    expect(screen.getByLabelText('Nhập lại mật khẩu')).toBe(screen.getByTestId('first-login-confirm-password'));
    expect(screen.getByLabelText('Mã PIN mới')).toBe(screen.getByTestId('first-login-new-pin'));
    expect(screen.getByLabelText('Nhập lại mã PIN')).toBe(screen.getByTestId('first-login-confirm-pin'));
    expect(within(dialog).queryByRole('button', { name: 'Đóng' })).not.toBeInTheDocument();
    fireEvent.keyDown(window, { key: 'Escape' });
    expect(screen.getByRole('dialog', { name: 'Thiết lập bảo mật' })).toBeInTheDocument();
    expect(dialog.textContent).not.toMatch(/123456/);
  });

  it.each([
    [{ password: '' }, 'Nhập mật khẩu mới.'],
    [{ password: 'abc' }, 'Mật khẩu cần ít nhất 6 ký tự.'],
    [{ password: '123456' }, 'Mật khẩu mới phải khác mật khẩu mặc định.'],
    [{ password: 'MatKhau@1', confirmPassword: 'MatKhau@2' }, 'Hai mật khẩu không khớp.'],
    [{ pin: '123' }, 'Mã PIN gồm đúng 6 chữ số.'],
    [{ pin: '123456' }, 'Mã PIN mới phải khác mã mặc định.'],
    [{ pin: '246810', confirmPin: '246811' }, 'Hai mã PIN không khớp.'],
  ])('kiểm tra %o báo "%s" và không gọi API', (values, message) => {
    authState.user = { username: 'admin.local', is_first_login: true };
    render(<FirstLoginModal />);
    fill(values);
    submit();
    expect(screen.getByRole('alert')).toHaveTextContent(message);
    expect(adminApi.firstLoginSetup).not.toHaveBeenCalled();
  });

  it('hợp lệ thì gọi firstLoginSetup đúng bốn trường, tắt cờ lần đầu, giữ token và báo thành công', async () => {
    authState.user = { username: 'admin.local', is_first_login: true };
    localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'tok-a');
    localStorage.setItem(STORAGE_KEYS.REFRESH_TOKEN, 'tok-r');
    render(<FirstLoginModal />);
    fill({ password: 'MatKhau@1', pin: '135790' });
    submit();
    await waitFor(() => expect(authState.syncAuthSession).toHaveBeenCalled());
    expect(adminApi.firstLoginSetup).toHaveBeenCalledWith({
      newPassword: 'MatKhau@1',
      confirmPassword: 'MatKhau@1',
      pin: '135790',
      confirmPin: '135790',
    });
    expect(authState.syncAuthSession).toHaveBeenCalledWith({
      user: { username: 'admin.local', is_first_login: false },
      accessToken: 'tok-a',
      refreshToken: 'tok-r',
    });
    expect(notify.success).toHaveBeenCalledWith('Mật khẩu và mã PIN mới đã được lưu.', 'Đã kích hoạt tài khoản');
  });

  it('máy chủ báo lỗi thì hiện lỗi, không tắt cờ lần đầu', async () => {
    authState.user = { username: 'admin.local', is_first_login: true };
    adminApi.firstLoginSetup.mockRejectedValue(apiError('Phiên đã hết hạn'));
    render(<FirstLoginModal />);
    fill();
    submit();
    expect(await screen.findByRole('alert')).toHaveTextContent('Phiên đã hết hạn');
    expect(authState.syncAuthSession).not.toHaveBeenCalled();
  });
});
