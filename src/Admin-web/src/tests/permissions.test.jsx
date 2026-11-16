import React from 'react';
import { render, screen, fireEvent, waitFor, act, within } from '@testing-library/react';
import PermissionManagementPage from '../pages/system/PermissionManagementPage';
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
  default: { getPermissions: vi.fn(), updatePermissions: vi.fn(), resetPermissionsDefault: vi.fn() },
}));

const FEATURES = [
  { id: 'wallets', name: 'Ví', description: 'Số ví tối đa', category_group: 'Tài nguyên', type: 'LIMIT', default_downgrade_policy: 'BLOCK_CREATE' },
  { id: 'ai_assistant', name: 'Trợ lý AI', description: 'Hỏi đáp tài chính', category_group: 'Trí tuệ nhân tạo', type: 'TOGGLE', scope_schema: { daily_scans: 'number' } },
  { id: 'household', name: 'Gia đình — tạo nhà', description: 'Tạo và quản trị nhà', category_group: 'Gia đình', type: 'TOGGLE' },
  { id: 'household_members', name: 'Gia đình — số thành viên tối đa', description: 'Thành viên', category_group: 'Gia đình', type: 'LIMIT' },
  { id: 'transaction_management', name: 'Sổ giao dịch', description: 'Ghi thu chi', category_group: 'Sổ giao dịch Thu Chi', type: 'TOGGLE' },
];
const PERMS = {
  Basic: {
    wallets: { is_enabled: true, limit_value: 3, downgrade_policy: 'BLOCK_CREATE', scope_config: {} },
    ai_assistant: { is_enabled: false, limit_value: null, downgrade_policy: 'LOCK_FEATURE', scope_config: {} },
    household: { is_enabled: false, limit_value: null, downgrade_policy: 'LOCK_FEATURE', scope_config: {} },
    household_members: { is_enabled: false, limit_value: 0, downgrade_policy: 'BLOCK_CREATE', scope_config: {} },
    transaction_management: { is_enabled: true, limit_value: null, downgrade_policy: 'LOCK_FEATURE', scope_config: {} },
  },
  Premium: {
    wallets: { is_enabled: true, limit_value: null, downgrade_policy: 'BLOCK_CREATE', scope_config: {} },
    ai_assistant: { is_enabled: true, limit_value: null, downgrade_policy: 'LOCK_FEATURE', scope_config: { daily_scans: 50 } },
    household: { is_enabled: true, limit_value: null, downgrade_policy: 'LOCK_FEATURE', scope_config: {} },
    household_members: { is_enabled: true, limit_value: 6, downgrade_policy: 'BLOCK_CREATE', scope_config: {} },
    transaction_management: { is_enabled: true, limit_value: null, downgrade_policy: 'LOCK_FEATURE', scope_config: {} },
  },
};

const renderPage = async () => {
  render(<PermissionManagementPage />);
  await screen.findByRole('checkbox', { name: 'Truy cập Ví (Basic)' });
};
const saveButton = () => screen.getByTestId('btn-save-permissions');
const lastUpdates = () => adminApi.updatePermissions.mock.calls.at(-1)[0];

const confirmSave = async () => {
  fireEvent.click(saveButton());
  const dialog = screen.getByRole('dialog', { name: 'Lưu thay đổi phân quyền' });
  expect(within(dialog).getByRole('button', { name: 'Lưu' })).toBeDisabled();
  fireEvent.change(within(dialog).getByLabelText(/PIN/), { target: { value: '246810' } });
  fireEvent.click(within(dialog).getByRole('button', { name: 'Lưu' }));
  await waitFor(() => expect(adminApi.updatePermissions).toHaveBeenCalledTimes(1));
  expect(adminApi.updatePermissions.mock.calls[0][1]).toEqual({ pin: '246810' });
};

beforeEach(() => {
  Object.keys(handlers).forEach((k) => delete handlers[k]);
  adminApi.getPermissions.mockReset().mockResolvedValue({ data: { data: { features: FEATURES, permissions: JSON.parse(JSON.stringify(PERMS)) } } });
  adminApi.updatePermissions.mockReset().mockResolvedValue({ data: { success: true } });
  adminApi.resetPermissionsDefault.mockReset().mockResolvedValue({ data: { success: true } });
});

describe('Hiển thị', () => {
  it('tải ma trận; có tiêu đề, tab chế độ xem, nhóm, thống kê; nút lưu khóa khi chưa sửa; không lộ chữ kỹ thuật', async () => {
    await renderPage();
    expect(adminApi.getPermissions).toHaveBeenCalledTimes(1);
    expect(screen.getByRole('heading', { level: 1, name: 'Phân quyền dịch vụ' })).toBeInTheDocument();
    expect(within(screen.getByRole('tablist', { name: 'Chế độ xem gói' })).getByRole('tab', { name: 'Tất cả' })).toHaveAttribute('aria-selected', 'true');
    expect(screen.getByRole('button', { name: /Tài nguyên \(1\)/ })).toHaveAttribute('aria-expanded', 'true');
    expect(screen.getByRole('button', { name: /Trí tuệ nhân tạo \(1\)/ })).toBeInTheDocument();
    expect(screen.getByText('5 tính năng · 2 có hạn mức')).toBeInTheDocument();
    expect(saveButton()).toBeDisabled();
    expect(screen.getByRole('checkbox', { name: 'Truy cập Trợ lý AI (Basic)' })).not.toBeChecked();
    expect(screen.getByRole('spinbutton', { name: 'Hạn mức Ví (Basic)' })).toHaveValue(3);
    expect(document.body.textContent).not.toMatch(/PostgreSQL|Socket\.IO|50ms|Trụ \d/);
  });

  it('không còn cột Phạm vi; cột Khi hạ cấp chỉ đọc, ghi đúng cách ứng dụng di động xử lý theo từng loại tính năng', async () => {
    await renderPage();
    expect(screen.queryByRole('columnheader', { name: /Phạm vi/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Sửa phạm vi/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('combobox', { name: /Chính sách hạ cấp/ })).not.toBeInTheDocument();
    const policy = (name, plan) => screen.getByTestId(`policy-${name}-${plan}`).textContent;
    expect(policy('wallets', 'Basic')).toBe('Chặn tạo mới, giữ dữ liệu');
    expect(policy('ai_assistant', 'Premium')).toBe('Khóa tính năng');
    expect(policy('household', 'Premium')).toBe('Nhà chuyển chỉ xem');
    expect(policy('household_members', 'Premium')).toBe('Nhà chuyển chỉ xem');
    expect(policy('transaction_management', 'Basic')).toBe('Không khóa');
  });

  it('tab Gói Premium chỉ hiện dòng Premium; thu gọn nhóm ẩn các dòng của nhóm', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('tab', { name: 'Gói Premium' }));
    expect(screen.queryByRole('checkbox', { name: 'Truy cập Ví (Basic)' })).not.toBeInTheDocument();
    expect(screen.getByRole('checkbox', { name: 'Truy cập Ví (Premium)' })).toBeInTheDocument();
    const header = screen.getByRole('button', { name: /Tài nguyên \(1\)/ });
    fireEvent.click(header);
    expect(header).toHaveAttribute('aria-expanded', 'false');
    expect(screen.queryByRole('checkbox', { name: 'Truy cập Ví (Premium)' })).not.toBeInTheDocument();
  });
});

describe('Bộ lọc', () => {
  it('tìm kiếm, chọn phân hệ và trạng thái rỗng', async () => {
    await renderPage();
    fireEvent.change(screen.getByLabelText('Tìm tính năng'), { target: { value: 'trợ lý' } });
    expect(screen.queryByRole('button', { name: /Tài nguyên/ })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Trí tuệ nhân tạo/ })).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText('Tìm tính năng'), { target: { value: '' } });
    fireEvent.change(screen.getByLabelText('Phân hệ'), { target: { value: 'Tài nguyên' } });
    expect(screen.queryByRole('button', { name: /Trí tuệ nhân tạo/ })).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText('Tìm tính năng'), { target: { value: 'xyz' } });
    expect(screen.getByText('Không tìm thấy tính năng')).toBeInTheDocument();
  });
});

describe('Chỉnh sửa và lưu', () => {
  it('bật quyền và đổi hạn mức đếm thay đổi; hoàn tác một dòng; lọc chỉ dòng đã sửa', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('checkbox', { name: 'Truy cập Trợ lý AI (Basic)' }));
    fireEvent.change(screen.getByRole('spinbutton', { name: 'Hạn mức Ví (Basic)' }), { target: { value: '5' } });
    expect(saveButton()).toBeEnabled();
    expect(saveButton()).toHaveTextContent('Lưu thay đổi (2)');
    fireEvent.click(screen.getByRole('button', { name: 'Hoàn tác Trợ lý AI (Basic)' }));
    expect(saveButton()).toHaveTextContent('Lưu thay đổi (1)');
    fireEvent.click(screen.getByLabelText('Chỉ xem dòng đã sửa'));
    expect(screen.queryByRole('button', { name: /Trí tuệ nhân tạo/ })).not.toBeInTheDocument();
  });

  it('đang lọc "Chỉ xem dòng đã sửa" mà hoàn tác dòng cuối: bộ lọc tự tắt, các phân hệ hiện lại', async () => {
    await renderPage();
    fireEvent.change(screen.getByRole('spinbutton', { name: 'Hạn mức Ví (Basic)' }), { target: { value: '5' } });
    fireEvent.click(screen.getByLabelText('Chỉ xem dòng đã sửa'));
    expect(screen.queryByRole('button', { name: /Trí tuệ nhân tạo/ })).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Hoàn tác Ví (Basic)' }));
    expect(screen.queryByText('Không tìm thấy tính năng')).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Tài nguyên \(1\)/ })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Trí tuệ nhân tạo \(1\)/ })).toBeInTheDocument();
    // sửa lại một dòng: ô lọc hiện ra ở trạng thái chưa chọn
    fireEvent.change(screen.getByRole('spinbutton', { name: 'Hạn mức Ví (Basic)' }), { target: { value: '6' } });
    expect(screen.getByLabelText('Chỉ xem dòng đã sửa')).not.toBeChecked();
  });

  it('không giới hạn khóa ô hạn mức; lưu chỉ gửi quyền truy cập và hạn mức (không gửi phạm vi, chính sách hạ cấp) rồi tải lại', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('checkbox', { name: 'Không giới hạn Ví (Basic)' }));
    expect(screen.getByRole('spinbutton', { name: 'Hạn mức Ví (Basic)' })).toBeDisabled();
    fireEvent.click(screen.getByRole('checkbox', { name: 'Truy cập Trợ lý AI (Premium)' }));
    await confirmSave();
    expect(lastUpdates()).toEqual([
      { account_type: 'Basic', feature_id: 'wallets', is_enabled: true, limit_value: null },
      { account_type: 'Premium', feature_id: 'ai_assistant', is_enabled: false, limit_value: null },
    ]);
    await waitFor(() => expect(adminApi.getPermissions).toHaveBeenCalledTimes(2));
  });

  it('hạn mức gia đình là số cố định: ô số và ô không giới hạn bị khóa, ghi "Cố định"; quyền truy cập vẫn sửa được', async () => {
    await renderPage();
    expect(screen.getByRole('spinbutton', { name: 'Hạn mức Gia đình — số thành viên tối đa (Premium)' })).toBeDisabled();
    expect(screen.getByRole('spinbutton', { name: 'Hạn mức Gia đình — số thành viên tối đa (Premium)' })).toHaveValue(6);
    expect(screen.getByRole('checkbox', { name: 'Không giới hạn Gia đình — số thành viên tối đa (Premium)' })).toBeDisabled();
    expect(screen.getAllByText('Cố định').length).toBe(2);
    expect(screen.getByRole('checkbox', { name: 'Truy cập Gia đình — số thành viên tối đa (Premium)' })).toBeEnabled();
  });

  it('đặt lại mặc định: nhập PIN, gửi PIN cùng lệnh đặt lại rồi tải lại', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('button', { name: 'Đặt lại mặc định' }));
    const dialog = screen.getByRole('dialog', { name: 'Đặt lại phân quyền mặc định' });
    expect(within(dialog).getByText(/không hoàn tác/)).toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: 'Đặt lại' })).toBeDisabled();
    fireEvent.change(within(dialog).getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Đặt lại' }));
    await waitFor(() => expect(adminApi.resetPermissionsDefault).toHaveBeenCalledWith({ pin: '246810' }));
    await waitFor(() => expect(adminApi.getPermissions).toHaveBeenCalledTimes(2));
  });

  it('lưu với PIN sai: hộp PIN hiện lỗi máy chủ, giữ bản nháp, không tải lại', async () => {
    adminApi.updatePermissions.mockRejectedValue({ response: { data: { message: 'Mã PIN quản trị viên không chính xác!' } } });
    await renderPage();
    fireEvent.change(screen.getByRole('spinbutton', { name: 'Hạn mức Ví (Basic)' }), { target: { value: '5' } });
    fireEvent.click(saveButton());
    const dialog = screen.getByRole('dialog', { name: 'Lưu thay đổi phân quyền' });
    fireEvent.change(within(dialog).getByLabelText(/PIN/), { target: { value: '111111' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Lưu' }));
    expect(await within(dialog).findByRole('alert')).toHaveTextContent('Mã PIN quản trị viên không chính xác!');
    expect(adminApi.getPermissions).toHaveBeenCalledTimes(1);
    expect(saveButton()).toHaveTextContent('Lưu thay đổi (1)');
  });
});

describe('Realtime', () => {
  it('account.permissions_updated tải lại ma trận', async () => {
    await renderPage();
    emit('account.permissions_updated', {});
    await waitFor(() => expect(adminApi.getPermissions).toHaveBeenCalledTimes(2));
  });
});
