import React from 'react';
import { render, screen, fireEvent, waitFor, act, within } from '@testing-library/react';
import UserListPage from '../pages/users/UserListPage';
import adminApi from '../api/admin.api';

const handlers = {};
const fakeSocket = {
  on: (event, fn) => {
    handlers[event] = handlers[event] || new Set();
    handlers[event].add(fn);
  },
  off: (event, fn) => handlers[event] && handlers[event].delete(fn),
};
const emit = (event, payload) => act(() => {
  (handlers[event] || []).forEach((fn) => fn(payload));
});

vi.mock('../hooks/useSocket', () => ({ default: () => fakeSocket }));
vi.mock('../api/admin.api', () => ({
  default: {
    getUsers: vi.fn(),
    getUserById: vi.fn(),
    updateUserStatus: vi.fn(),
    deleteUser: vi.fn(),
    verifySecurityAction: vi.fn(),
    getUserDevices: vi.fn(),
    revealDeviceIp: vi.fn(),
    getUserPolicy: vi.fn(),
  },
}));

const DEVICES = [
  { id: '5', device_name: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0', ip_address: '113.161.xx.xx', first_seen_at: '2026-11-10T01:00:00Z', last_active_at: '2026-11-13T02:00:00Z', canRevealIp: true },
  { id: '4', device_name: 'Samsung Galaxy S24', ip_address: '171.244.xx.xx', first_seen_at: '2024-01-01T00:00:00Z', last_active_at: '2024-02-01T00:00:00Z', canRevealIp: false },
  { id: '3', device_name: 'Unknown Device', ip_address: '14.162.xx.xx', first_seen_at: '2026-11-01T00:00:00Z', last_active_at: '2026-11-02T00:00:00Z', canRevealIp: true },
];

const USERS = [
  { id: 1, idaccount: 101, fullname: 'Nguyễn Văn An', username: 'an', email: 'a***@mail.test', phone: '0981234567', status: 'Active', type: 'Basic' },
  { id: 2, idaccount: 102, fullname: 'Trần Thị Bình', username: 'binh', email: 'b***@mail.test', phone: '0912345678', status: 'Inactive', type: 'Premium', reason_inactive: 'Spam' },
  { id: 3, idaccount: 103, fullname: 'Lê Minh Châu', username: 'chau', email: 'c***@mail.test', phone: '0931234567', status: 'PendingDelete', type: 'Basic', countdown: 12 },
  { id: 4, idaccount: 104, fullname: 'Phạm Quốc Dũng', username: 'dung', email: 'd***@mail.test', phone: '0941234567', status: 'Deleted', type: 'Basic' },
];

const row = (name) => screen.getByRole('row', { name: new RegExp(name) });
const queryRow = (name) => screen.queryByRole('row', { name: new RegExp(name) });

const renderPage = async () => {
  render(<UserListPage />);
  await screen.findByRole('row', { name: /Nguyễn Văn An/ });
};

beforeEach(() => {
  Object.keys(handlers).forEach((k) => delete handlers[k]);
  adminApi.getUsers.mockReset().mockResolvedValue({ data: USERS.map((u) => ({ ...u })) });
  adminApi.getUserById.mockReset().mockResolvedValue({
    data: { id: 1, fullname: 'Nguyễn Văn An', username: 'an', email: 'a***@mail.test', status: 'Active', type: 'Basic', rolename: 'user' },
  });
  adminApi.updateUserStatus.mockReset().mockResolvedValue({ success: true });
  adminApi.deleteUser.mockReset().mockResolvedValue({ success: true });
  adminApi.verifySecurityAction.mockReset().mockResolvedValue({ success: true });
  adminApi.getUserDevices.mockReset().mockResolvedValue({ data: DEVICES.map((d) => ({ ...d })) });
  adminApi.revealDeviceIp.mockReset().mockResolvedValue({ data: { ip: '113.161.45.12' } });
  adminApi.getUserPolicy.mockReset().mockResolvedValue({ data: { currentVersion: 2, acceptances: [{ policy_version: 2, accepted_at: '2026-11-13T02:00:00Z' }] } });
});

describe('Chính sách bảo mật trong hộp chi tiết', () => {
  const open = async () => {
    await renderPage();
    fireEvent.click(within(row('Nguyễn Văn An')).getByRole('button', { name: 'Xem chi tiết' }));
    return screen.findByRole('dialog', { name: 'Chi tiết người dùng' });
  };

  it('đã đồng ý phiên bản hiện hành: hiện Đã đồng ý v2', async () => {
    const dialog = await open();
    expect(adminApi.getUserPolicy).toHaveBeenCalledWith(1);
    expect(await within(dialog).findByText(/Đã đồng ý v2/)).toBeInTheDocument();
  });

  it('mới đồng ý v1 trong khi hiện hành v2: báo chưa đồng ý v2', async () => {
    adminApi.getUserPolicy.mockResolvedValue({ data: { currentVersion: 2, acceptances: [{ policy_version: 1, accepted_at: '2026-11-01T02:00:00Z' }] } });
    const dialog = await open();
    expect(await within(dialog).findByText('Chưa đồng ý v2')).toBeInTheDocument();
  });
});

describe('Thiết bị đăng nhập', () => {
  const openDetail = async () => {
    await renderPage();
    fireEvent.click(within(row('Nguyễn Văn An')).getByRole('button', { name: 'Xem chi tiết' }));
    const dialog = await screen.findByRole('dialog', { name: 'Chi tiết người dùng' });
    return within(dialog).findByRole('region', { name: 'Thiết bị đăng nhập' });
  };

  it('tải thiết bị theo id người dùng; tên thiết bị rút gọn, IP đã che, IP hết hạn thì không có nút xem', async () => {
    const section = await openDetail();
    expect(adminApi.getUserDevices).toHaveBeenCalledWith(1);
    const items = within(section).getAllByRole('listitem');
    expect(items).toHaveLength(3);
    expect(items[0]).toHaveTextContent('Edge trên Windows');
    expect(items[0]).toHaveTextContent('113.161.xx.xx');
    expect(within(items[0]).getByRole('button', { name: 'Xem IP đầy đủ' })).toBeInTheDocument();
    expect(items[1]).toHaveTextContent('Samsung Galaxy S24');
    expect(within(items[1]).queryByRole('button', { name: 'Xem IP đầy đủ' })).not.toBeInTheDocument();
    expect(items[1]).toHaveTextContent('Không còn IP đầy đủ');
    expect(items[2]).toHaveTextContent('Không rõ thiết bị');
  });

  it('xem IP: nhập PIN, gửi PIN cùng lời gọi revealDeviceIp, không gọi verifySecurityAction, hiện IP trong dòng', async () => {
    const section = await openDetail();
    fireEvent.click(within(within(section).getAllByRole('listitem')[0]).getByRole('button', { name: 'Xem IP đầy đủ' }));
    const pinDialog = screen.getByRole('dialog', { name: 'Xem IP đầy đủ' });
    expect(pinDialog).toHaveTextContent('nhật ký');
    fireEvent.change(within(pinDialog).getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(within(pinDialog).getByRole('button', { name: 'Xem IP' }));
    await waitFor(() => expect(adminApi.revealDeviceIp).toHaveBeenCalledWith(1, '5', { pin: '246810', password: '' }));
    expect(adminApi.verifySecurityAction).not.toHaveBeenCalled();
    expect(await within(section).findByText('113.161.45.12')).toBeInTheDocument();
    expect(screen.queryByRole('dialog', { name: 'Xem IP đầy đủ' })).not.toBeInTheDocument();
  });

  it('chưa có lượt truy cập thì báo trống', async () => {
    adminApi.getUserDevices.mockResolvedValue({ data: [] });
    const section = await openDetail();
    expect(await within(section).findByText('Chưa có lượt truy cập nào.')).toBeInTheDocument();
  });
});

describe('Hiển thị', () => {
  it('có tiêu đề trang, 4 thẻ số liệu đúng số đếm', async () => {
    await renderPage();
    expect(screen.getByRole('heading', { level: 1, name: 'Quản lý người dùng' })).toBeInTheDocument();
    const card = (label) => screen.getByText(label, { selector: 'div' }).parentElement;
    expect(card('Tổng người dùng')).toHaveTextContent('4');
    expect(card('Đang hoạt động')).toHaveTextContent('1');
    expect(card('Vô hiệu hóa')).toHaveTextContent('1');
    expect(card('Chờ xóa')).toHaveTextContent('1');
  });

  it('mặc định ẩn người dùng đã xóa, che số điện thoại, hiện số ngày chờ xóa', async () => {
    await renderPage();
    expect(queryRow('Phạm Quốc Dũng')).not.toBeInTheDocument();
    expect(within(row('Nguyễn Văn An')).getByText('098****567')).toBeInTheDocument();
    expect(within(row('Lê Minh Châu')).getByText('Chờ xóa (12 ngày)')).toHaveAttribute('data-tone', 'warning');
    expect(within(row('Lê Minh Châu')).queryByRole('button', { name: 'Xóa' })).not.toBeInTheDocument();
  });
});

describe('Lọc và tìm kiếm', () => {
  it('tab trạng thái lọc danh sách', async () => {
    await renderPage();
    const tabs = screen.getByRole('tablist', { name: 'Lọc theo trạng thái' });
    fireEvent.click(within(tabs).getByRole('tab', { name: /Đã xóa/ }));
    expect(row('Phạm Quốc Dũng')).toBeInTheDocument();
    expect(queryRow('Nguyễn Văn An')).not.toBeInTheDocument();
    fireEvent.click(within(tabs).getByRole('tab', { name: /Tất cả/ }));
    ['Nguyễn Văn An', 'Trần Thị Bình', 'Lê Minh Châu', 'Phạm Quốc Dũng'].forEach((n) => expect(row(n)).toBeInTheDocument());
  });

  it('tìm theo tên', async () => {
    await renderPage();
    fireEvent.change(screen.getByLabelText('Tìm người dùng'), { target: { value: 'bình' } });
    expect(row('Trần Thị Bình')).toBeInTheDocument();
    expect(queryRow('Nguyễn Văn An')).not.toBeInTheDocument();
  });

  it('bộ lọc theo gói dịch vụ', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('button', { name: 'Bộ lọc' }));
    const dialog = screen.getByRole('dialog', { name: 'Bộ lọc' });
    fireEvent.change(within(dialog).getByTestId('filter-package'), { target: { value: 'Premium' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Áp dụng' }));
    expect(row('Trần Thị Bình')).toBeInTheDocument();
    expect(queryRow('Nguyễn Văn An')).not.toBeInTheDocument();
  });
});

describe('Thao tác trạng thái', () => {
  it('vô hiệu hóa bắt buộc lý do rồi gọi API với lý do đã nhập', async () => {
    await renderPage();
    fireEvent.click(within(row('Nguyễn Văn An')).getByRole('button', { name: 'Vô hiệu hóa' }));
    const dialog = screen.getByRole('dialog', { name: 'Vô hiệu hóa tài khoản' });
    const submit = within(dialog).getByRole('button', { name: 'Vô hiệu hóa' });
    expect(submit).toBeDisabled();
    fireEvent.change(within(dialog).getByLabelText(/Lý do/), { target: { value: ' Spam quảng cáo ' } });
    fireEvent.click(submit);
    await waitFor(() =>
      expect(adminApi.updateUserStatus).toHaveBeenCalledWith(1, { status: 'Inactive', reason_inactive: 'Spam quảng cáo' })
    );
    await waitFor(() => expect(within(row('Nguyễn Văn An')).getByText('Vô hiệu hóa')).toHaveAttribute('data-tone', 'neutral'));
  });

  it('kích hoạt lại qua hộp xác nhận', async () => {
    await renderPage();
    fireEvent.click(within(row('Trần Thị Bình')).getByRole('button', { name: 'Kích hoạt' }));
    const dialog = screen.getByRole('dialog', { name: 'Kích hoạt lại tài khoản?' });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Kích hoạt' }));
    await waitFor(() => expect(adminApi.updateUserStatus).toHaveBeenCalledWith(2, { status: 'Active' }));
    await waitFor(() => expect(within(row('Trần Thị Bình')).getByText('Đang hoạt động')).toBeInTheDocument());
  });

  it('xóa mềm phải qua xác thực PIN rồi mới gọi deleteUser; người dùng chuyển sang Đã xóa và vẫn hiện', async () => {
    await renderPage();
    fireEvent.click(within(row('Trần Thị Bình')).getByRole('button', { name: 'Xóa' }));
    const dialog = screen.getByRole('dialog', { name: 'Xóa người dùng' });
    expect(adminApi.deleteUser).not.toHaveBeenCalled();
    fireEvent.change(within(dialog).getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Xóa' }));
    await waitFor(() => expect(adminApi.deleteUser).toHaveBeenCalledWith(2));
    expect(adminApi.verifySecurityAction).toHaveBeenCalledWith({ pin: '246810', password: '', action: 'DELETE_USER', targetId: '@binh' });
    await waitFor(() => expect(within(row('Trần Thị Bình')).getByText('Đã xóa')).toHaveAttribute('data-tone', 'danger'));
  });

  it('xem chi tiết mở hộp thoại và tải người dùng theo id', async () => {
    await renderPage();
    fireEvent.click(within(row('Nguyễn Văn An')).getByRole('button', { name: 'Xem chi tiết' }));
    const dialog = await screen.findByRole('dialog', { name: 'Chi tiết người dùng' });
    expect(adminApi.getUserById).toHaveBeenCalledWith(1);
    expect(await within(dialog).findByText('an')).toBeInTheDocument();
  });
});

describe('Realtime', () => {
  it('admin.user_registered thêm người dùng mới; admin.user_status_changed đổi trạng thái', async () => {
    await renderPage();
    emit('admin.user_registered', { id: 9, idaccount: 109, fullname: 'Võ Thanh Khoa', username: 'khoa', email: 'k***@mail.test', status: 'Active' });
    expect(row('Võ Thanh Khoa')).toBeInTheDocument();
    emit('admin.user_status_changed', { idaccount: 101, status: 'Inactive', reason_inactive: 'Khóa từ máy khác' });
    expect(within(row('Nguyễn Văn An')).getByText('Vô hiệu hóa')).toBeInTheDocument();
  });
});
