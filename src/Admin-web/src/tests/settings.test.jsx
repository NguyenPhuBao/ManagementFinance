import React from 'react';
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
import SettingsModal from '../components/layout/SettingsModal';
import { SettingsProvider } from '../store/settings.context';
import { STORAGE_KEYS } from '../utils/constants';
import adminApi from '../api/admin.api';
import soundService from '../services/sound.service';

const fakeSocket = {
  connected: true,
  id: 'abcdef123456',
  on: vi.fn(),
  off: vi.fn(),
  emit: vi.fn(),
  timeout: vi.fn(),
};

vi.mock('../hooks/useSocket', () => ({ default: () => fakeSocket }));
vi.mock('../store/auth.context', () => ({
  useAuthContext: () => ({ user: { Username: 'admin.local', Role: 'Admin', Email: 'admin@local.test' } }),
}));
vi.mock('../services/sound.service', () => ({ default: { playCriticalAlarm: vi.fn() } }));
vi.mock('../api/admin.api', () => ({ default: { changePin: vi.fn(), changePassword: vi.fn(), createAdmin: vi.fn() } }));

const saved = () => JSON.parse(localStorage.getItem('admin_system_settings') || '{}');
const onClose = vi.fn();

const renderModal = () =>
  render(
    <SettingsProvider>
      <SettingsModal isOpen onClose={onClose} />
    </SettingsProvider>
  );

const openTab = (name) => fireEvent.click(screen.getByRole('tab', { name }));
const dialogNamed = (name) => screen.getByRole('dialog', { name });

beforeEach(() => {
  localStorage.clear();
  sessionStorage.clear();
  document.documentElement.classList.remove('dark');
  onClose.mockReset();
  soundService.playCriticalAlarm.mockReset();
  fakeSocket.emit.mockReset();
  fakeSocket.timeout.mockReset().mockReturnValue({ emit: (event, cb) => cb(null) });
  adminApi.changePin.mockReset().mockResolvedValue({ data: { success: true } });
  adminApi.changePassword.mockReset().mockResolvedValue({ data: { success: true } });
  adminApi.createAdmin.mockReset().mockResolvedValue({ data: { data: { username: 'admin2', email: 'a2@x.test', fullname: 'Quản Trị Hai', phone: '0912345678' } } });
});

describe('Giao diện', () => {
  it('hộp Cài đặt có 5 tab; đổi chế độ Tối gắn lớp dark lên html; đổi mật độ; không lộ chữ kỹ thuật', () => {
    renderModal();
    expect(dialogNamed('Cài đặt')).toBeInTheDocument();
    expect(screen.getAllByRole('tab')).toHaveLength(5);
    expect(screen.getByTestId('settings-tab-general')).toHaveAttribute('aria-selected', 'true');
    expect(screen.getByTestId('settings-lang-vi')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('radio', { name: 'Tối' }));
    expect(document.documentElement.classList.contains('dark')).toBe(true);
    expect(saved().theme).toBe('dark');
    fireEvent.click(screen.getByRole('radio', { name: 'Thu gọn' }));
    expect(document.body.getAttribute('data-density')).toBe('compact');
    fireEvent.click(screen.getByRole('radio', { name: 'Sáng' }));
    expect(document.documentElement.classList.contains('dark')).toBe(false);
    expect(document.body.textContent).not.toMatch(/Socket\.IO|PostgreSQL|Supabase|Bcrypt|Cổng 3000/);
  });
});

describe('Thông báo và kết nối', () => {
  it('tắt âm thanh, nghe thử, đổi thời gian thông báo và huy hiệu đều lưu lại', () => {
    renderModal();
    openTab('Thông báo');
    fireEvent.click(screen.getByRole('switch', { name: 'Âm thanh cảnh báo' }));
    expect(saved().soundEnabled).toBe(false);
    fireEvent.click(screen.getByRole('button', { name: 'Nghe thử' }));
    expect(soundService.playCriticalAlarm).toHaveBeenCalledTimes(1);
    fireEvent.change(screen.getByLabelText('Thời gian hiện thông báo'), { target: { value: '7000' } });
    expect(saved().toastDuration).toBe(7000);
    fireEvent.click(screen.getByRole('switch', { name: 'Số thông báo chưa đọc' }));
    expect(saved().showUnreadBadge).toBe(false);
  });

  it('tab Kết nối: hiện trạng thái, tự đo độ trễ, đo tay, đổi nhịp cập nhật', async () => {
    renderModal();
    openTab('Kết nối');
    expect(screen.getByText('Đã kết nối')).toBeInTheDocument();
    await waitFor(() => expect(fakeSocket.timeout).toHaveBeenCalled());
    const calls = fakeSocket.timeout.mock.calls.length;
    fireEvent.click(screen.getByRole('button', { name: /Đo độ trễ|ms/ }));
    await waitFor(() => expect(fakeSocket.timeout.mock.calls.length).toBeGreaterThan(calls));
    expect(screen.getByText(/\d+ ms/)).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText('Nhịp cập nhật số liệu'), { target: { value: '5' } });
    expect(saved().metricsInterval).toBe(5);
  });
});

describe('Bảo mật', () => {
  it('khóa ngay đóng hộp và khóa phiên; tự khóa lưu lại; xóa bộ nhớ đệm qua xác nhận', () => {
    renderModal();
    openTab('Bảo mật');
    fireEvent.change(screen.getByLabelText('Tự khóa sau'), { target: { value: '60' } });
    expect(saved().autoLockMinutes).toBe(60);
    sessionStorage.setItem('tam', '1');
    fireEvent.click(screen.getByRole('button', { name: 'Xóa bộ nhớ đệm' }));
    fireEvent.click(within(dialogNamed('Xóa bộ nhớ đệm')).getByRole('button', { name: 'Xóa' }));
    expect(sessionStorage.getItem('tam')).toBeNull();
    expect(saved().autoLockMinutes).toBe(60);
    fireEvent.click(screen.getByRole('button', { name: 'Khóa ngay' }));
    expect(onClose).toHaveBeenCalled();
    expect(localStorage.getItem(STORAGE_KEYS.IS_LOCKED)).toBe('true');
  });

  it('đổi PIN: báo lỗi khi xác nhận không khớp; hợp lệ thì gọi changePin rồi đóng hộp', async () => {
    renderModal();
    openTab('Bảo mật');
    fireEvent.click(within(screen.getByTestId('settings-pin-section')).getByRole('button', { name: 'Đổi mã PIN' }));
    const dialog = dialogNamed('Đổi mã PIN');
    fireEvent.change(within(dialog).getByLabelText('Mật khẩu hiện tại'), { target: { value: 'Matkhau@1' } });
    fireEvent.change(within(dialog).getByLabelText('Mã PIN hiện tại'), { target: { value: '111111' } });
    fireEvent.change(within(dialog).getByLabelText('Mã PIN mới'), { target: { value: '222222' } });
    fireEvent.change(within(dialog).getByLabelText('Nhập lại mã PIN mới'), { target: { value: '333333' } });
    fireEvent.click(within(dialog).getByTestId('submit-change-pin-btn'));
    expect(within(dialog).getByRole('alert')).toHaveTextContent('không khớp');
    expect(adminApi.changePin).not.toHaveBeenCalled();
    fireEvent.change(within(dialog).getByLabelText('Nhập lại mã PIN mới'), { target: { value: '222222' } });
    fireEvent.click(within(dialog).getByTestId('submit-change-pin-btn'));
    await waitFor(() => expect(adminApi.changePin).toHaveBeenCalledWith({ password: 'Matkhau@1', oldPin: '111111', newPin: '222222' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Đổi mã PIN' })).not.toBeInTheDocument());
  });
});

describe('Hộp con mở lại', () => {
  it('đóng rồi mở lại hộp đổi mã PIN thì không còn giữ mật khẩu đã nhập', () => {
    renderModal();
    openTab('Bảo mật');
    const open = () => fireEvent.click(within(screen.getByTestId('settings-pin-section')).getByRole('button', { name: 'Đổi mã PIN' }));
    open();
    fireEvent.change(within(dialogNamed('Đổi mã PIN')).getByLabelText('Mật khẩu hiện tại'), { target: { value: 'BiMat@1' } });
    fireEvent.click(within(dialogNamed('Đổi mã PIN')).getByRole('button', { name: 'Hủy bỏ' }));
    open();
    expect(within(dialogNamed('Đổi mã PIN')).getByLabelText('Mật khẩu hiện tại')).toHaveValue('');
  });
});

describe('Quản trị viên', () => {
  it('hiện admin đang đăng nhập; đổi mật khẩu kiểm độ dài rồi gọi changePassword', async () => {
    renderModal();
    openTab('Quản trị viên');
    expect(screen.getByTestId('settings-admin-mgmt-section')).toHaveTextContent('admin.local');
    fireEvent.click(screen.getByTestId('open-change-password-btn'));
    const dialog = dialogNamed('Đổi mật khẩu');
    fireEvent.change(within(dialog).getByLabelText('Mật khẩu hiện tại'), { target: { value: 'Cu@12345' } });
    fireEvent.change(within(dialog).getByLabelText('Mã PIN hiện tại'), { target: { value: '246810' } });
    fireEvent.change(within(dialog).getByLabelText('Mật khẩu mới'), { target: { value: '123' } });
    fireEvent.change(within(dialog).getByLabelText('Nhập lại mật khẩu mới'), { target: { value: '123' } });
    fireEvent.click(within(dialog).getByTestId('submit-change-password-btn'));
    expect(within(dialog).getByRole('alert')).toHaveTextContent('ít nhất 6 ký tự');
    fireEvent.change(within(dialog).getByLabelText('Mật khẩu mới'), { target: { value: 'Moi@12345' } });
    fireEvent.change(within(dialog).getByLabelText('Nhập lại mật khẩu mới'), { target: { value: 'Moi@12345' } });
    fireEvent.click(within(dialog).getByTestId('submit-change-password-btn'));
    await waitFor(() =>
      expect(adminApi.changePassword).toHaveBeenCalledWith({ oldPassword: 'Cu@12345', pin: '246810', oldPin: '246810', newPassword: 'Moi@12345' })
    );
  });

  it('cấp admin ba bước: kiểm email, xác thực PIN, hiện kết quả', async () => {
    renderModal();
    openTab('Quản trị viên');
    fireEvent.click(screen.getByTestId('open-create-admin-btn'));
    const dialog = dialogNamed('Cấp tài khoản quản trị');
    fireEvent.change(within(dialog).getByLabelText('Họ và tên'), { target: { value: 'Quản Trị Hai' } });
    fireEvent.change(within(dialog).getByLabelText('Tên đăng nhập'), { target: { value: 'admin2' } });
    fireEvent.change(within(dialog).getByLabelText('Email'), { target: { value: 'sai-email' } });
    fireEvent.change(within(dialog).getByLabelText('Số điện thoại'), { target: { value: '0912 345 678' } });
    fireEvent.click(within(dialog).getByTestId('btn-next-create-admin'));
    expect(within(dialog).getByRole('alert')).toHaveTextContent('Email');
    fireEvent.change(within(dialog).getByLabelText('Email'), { target: { value: 'a2@x.test' } });
    fireEvent.click(within(dialog).getByTestId('btn-next-create-admin'));
    expect(within(dialog).getByText('Bước 2/2')).toBeInTheDocument();
    fireEvent.change(within(dialog).getByLabelText('Mã PIN của bạn'), { target: { value: '246810' } });
    fireEvent.click(within(dialog).getByTestId('submit-create-admin-btn'));
    await waitFor(() =>
      expect(adminApi.createAdmin).toHaveBeenCalledWith({
        fullName: 'Quản Trị Hai',
        username: 'admin2',
        email: 'a2@x.test',
        phone: '0912345678',
        address: null,
        countryCode: '+84',
        pin: '246810',
      })
    );
    expect(await within(dialog).findByText('Đã cấp tài khoản')).toBeInTheDocument();
    expect(within(dialog).getAllByText('123456')).toHaveLength(2);
    fireEvent.click(within(dialog).getByTestId('btn-finish-create-admin'));
    expect(screen.queryByRole('dialog', { name: 'Cấp tài khoản quản trị' })).not.toBeInTheDocument();
  });
});

describe('Khôi phục mặc định', () => {
  it('qua hộp xác nhận, đưa giao diện về Sáng', () => {
    renderModal();
    fireEvent.click(screen.getByRole('radio', { name: 'Tối' }));
    fireEvent.click(screen.getByRole('button', { name: 'Khôi phục mặc định' }));
    fireEvent.click(within(dialogNamed('Khôi phục mặc định')).getByRole('button', { name: 'Khôi phục' }));
    expect(document.documentElement.classList.contains('dark')).toBe(false);
    expect(saved().theme).toBe('light');
  });
});
