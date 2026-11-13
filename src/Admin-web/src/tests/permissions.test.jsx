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
];
const PERMS = {
  Basic: {
    wallets: { is_enabled: true, limit_value: 3, downgrade_policy: 'BLOCK_CREATE', scope_config: {} },
    ai_assistant: { is_enabled: false, limit_value: null, downgrade_policy: 'LOCK_FEATURE', scope_config: {} },
  },
  Premium: {
    wallets: { is_enabled: true, limit_value: null, downgrade_policy: 'BLOCK_CREATE', scope_config: {} },
    ai_assistant: { is_enabled: true, limit_value: null, downgrade_policy: 'LOCK_FEATURE', scope_config: { daily_scans: 50 } },
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
  fireEvent.click(within(dialog).getByRole('button', { name: 'Lưu' }));
  await waitFor(() => expect(adminApi.updatePermissions).toHaveBeenCalledTimes(1));
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
    expect(screen.getByText('2 tính năng · 1 có hạn mức')).toBeInTheDocument();
    expect(saveButton()).toBeDisabled();
    expect(screen.getByRole('checkbox', { name: 'Truy cập Trợ lý AI (Basic)' })).not.toBeChecked();
    expect(screen.getByRole('spinbutton', { name: 'Hạn mức Ví (Basic)' })).toHaveValue(3);
    expect(document.body.textContent).not.toMatch(/PostgreSQL|Socket\.IO|50ms|Trụ \d/);
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

  it('không giới hạn khóa ô hạn mức; lưu qua hộp xác nhận gửi đúng dòng đã đổi rồi tải lại', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('checkbox', { name: 'Không giới hạn Ví (Basic)' }));
    expect(screen.getByRole('spinbutton', { name: 'Hạn mức Ví (Basic)' })).toBeDisabled();
    fireEvent.change(screen.getByRole('combobox', { name: 'Chính sách hạ cấp Trợ lý AI (Premium)' }), { target: { value: 'READ_ONLY' } });
    await confirmSave();
    expect(lastUpdates()).toEqual([
      { account_type: 'Basic', feature_id: 'wallets', is_enabled: true, limit_value: null, scope_config: {}, downgrade_policy: 'BLOCK_CREATE' },
      { account_type: 'Premium', feature_id: 'ai_assistant', is_enabled: true, limit_value: null, scope_config: { daily_scans: 50 }, downgrade_policy: 'READ_ONLY' },
    ]);
    await waitFor(() => expect(adminApi.getPermissions).toHaveBeenCalledTimes(2));
  });

  it('sửa phạm vi: JSON sai báo lỗi; JSON đúng áp vào bản nháp và được lưu', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('button', { name: 'Sửa phạm vi Trợ lý AI (Premium)' }));
    const dialog = screen.getByRole('dialog', { name: 'Phạm vi: Trợ lý AI' });
    const editor = within(dialog).getByLabelText('Cấu hình phạm vi (JSON)');
    expect(editor.value).toContain('daily_scans');
    fireEvent.change(editor, { target: { value: '{' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Áp dụng' }));
    expect(within(dialog).getByText('JSON không hợp lệ.')).toBeInTheDocument();
    fireEvent.change(editor, { target: { value: '{"daily_scans":10}' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Áp dụng' }));
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    await confirmSave();
    expect(lastUpdates()).toEqual([
      { account_type: 'Premium', feature_id: 'ai_assistant', is_enabled: true, limit_value: null, scope_config: { daily_scans: 10 }, downgrade_policy: 'LOCK_FEATURE' },
    ]);
  });

  it('đặt lại mặc định qua hộp xác nhận rồi tải lại', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('button', { name: 'Đặt lại mặc định' }));
    const dialog = screen.getByRole('dialog', { name: 'Đặt lại phân quyền mặc định' });
    expect(within(dialog).getByText(/không hoàn tác/)).toBeInTheDocument();
    fireEvent.click(within(dialog).getByRole('button', { name: 'Đặt lại' }));
    await waitFor(() => expect(adminApi.resetPermissionsDefault).toHaveBeenCalledTimes(1));
    await waitFor(() => expect(adminApi.getPermissions).toHaveBeenCalledTimes(2));
  });
});

describe('Realtime', () => {
  it('account.permissions_updated tải lại ma trận', async () => {
    await renderPage();
    emit('account.permissions_updated', {});
    await waitFor(() => expect(adminApi.getPermissions).toHaveBeenCalledTimes(2));
  });
});
