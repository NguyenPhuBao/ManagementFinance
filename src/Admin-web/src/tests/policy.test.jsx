import React from 'react';
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
import BroadcastPage from '../pages/system/BroadcastPage';
import adminApi from '../api/admin.api';

vi.mock('../hooks/useSocket', () => ({ default: () => ({ on: () => {}, off: () => {} }) }));
vi.mock('../api/admin.api', () => ({
  default: {
    getMaintenanceStatus: vi.fn(),
    getMaintenanceHistory: vi.fn(),
    setMaintenanceStatus: vi.fn(),
    cancelScheduledMaintenance: vi.fn(),
    verifySecurityAction: vi.fn(),
    getPolicies: vi.fn(),
    publishPolicy: vi.fn(),
  },
}));
vi.mock('../api/notification.api', () => ({ default: { broadcastToAll: vi.fn(), getBroadcastHistory: vi.fn().mockResolvedValue({ data: { data: [], pagination: { total: 0 } } }) } }));

const POLICIES = {
  policies: [
    { version: 2, title: 'Chính sách bảo mật 2026', content: 'Nội dung phiên bản 2', publishedAt: '2026-11-13T02:00:00Z', acceptedCount: 1 },
    { version: 1, title: 'Chính sách bảo mật đầu tiên', content: 'Nội dung 1', publishedAt: '2026-11-01T02:00:00Z', acceptedCount: 3 },
  ],
  activeUsers: 4,
};

const openPolicyTab = async () => {
  render(<BroadcastPage />);
  fireEvent.click(await screen.findByRole('tab', { name: 'Chính sách' }));
  return screen.findByRole('region', { name: 'Chính sách hiện hành' });
};

beforeEach(() => {
  adminApi.getMaintenanceStatus.mockReset().mockResolvedValue({ data: { active: false, scheduledList: [] } });
  adminApi.getMaintenanceHistory.mockReset().mockResolvedValue({ data: { data: [], pagination: { total: 0 } } });
  adminApi.verifySecurityAction.mockReset().mockResolvedValue({ success: true });
  adminApi.getPolicies.mockReset().mockResolvedValue({ data: POLICIES });
  adminApi.publishPolicy.mockReset().mockResolvedValue({ data: { version: 3 } });
});

describe('Tab Chính sách', () => {
  it('trang có 3 tab; tab Chính sách tải danh sách, hiện phiên bản hiện hành, tỉ lệ đồng ý, nội dung và lịch sử phiên bản', async () => {
    const current = await openPolicyTab();
    expect(screen.getAllByRole('tab')).toHaveLength(3);
    expect(adminApi.getPolicies).toHaveBeenCalled();
    expect(current).toHaveTextContent('v2');
    expect(current).toHaveTextContent('Chính sách bảo mật 2026');
    expect(current).toHaveTextContent('1 / 4 người dùng đã đồng ý');
    expect(current).toHaveTextContent('Nội dung phiên bản 2');
    const history = screen.getByRole('table', { name: 'Các phiên bản' });
    expect(within(history).getAllByRole('row')).toHaveLength(3);
  });

  it('chưa có chính sách: báo trống và vẫn có nút đăng', async () => {
    adminApi.getPolicies.mockResolvedValue({ data: { policies: [], activeUsers: 4 } });
    const current = await openPolicyTab();
    expect(within(current).getByText('Chưa có chính sách nào.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Đăng phiên bản mới' })).toBeInTheDocument();
  });

  it('đăng phiên bản mới: điền tiêu đề + nội dung, nhập PIN, gửi PIN cùng publishPolicy (không gọi verifySecurityAction), tải lại danh sách', async () => {
    await openPolicyTab();
    fireEvent.click(screen.getByRole('button', { name: 'Đăng phiên bản mới' }));
    const form = screen.getByRole('dialog', { name: 'Đăng chính sách mới' });
    const next = within(form).getByRole('button', { name: 'Tiếp tục' });
    expect(next).toBeDisabled();
    fireEvent.change(within(form).getByLabelText('Tiêu đề'), { target: { value: 'Chính sách v3' } });
    fireEvent.change(within(form).getByLabelText('Nội dung'), { target: { value: 'Nội dung v3' } });
    expect(next).not.toBeDisabled();
    fireEvent.click(next);
    const pin = screen.getByRole('dialog', { name: 'Xác nhận đăng chính sách' });
    fireEvent.change(within(pin).getByLabelText(/PIN/), { target: { value: '246810' } });
    const loadsBefore = adminApi.getPolicies.mock.calls.length;
    fireEvent.click(within(pin).getByRole('button', { name: 'Đăng' }));
    await waitFor(() => expect(adminApi.publishPolicy).toHaveBeenCalledWith({ title: 'Chính sách v3', content: 'Nội dung v3', pin: '246810', password: '' }));
    expect(adminApi.verifySecurityAction).not.toHaveBeenCalled();
    await waitFor(() => expect(adminApi.getPolicies.mock.calls.length).toBeGreaterThan(loadsBefore));
    expect(screen.queryByRole('dialog', { name: 'Xác nhận đăng chính sách' })).not.toBeInTheDocument();
    expect(screen.queryByRole('dialog', { name: 'Đăng chính sách mới' })).not.toBeInTheDocument();
  });

  it('PIN sai: giữ hộp PIN và hiện lỗi máy chủ, không tải lại', async () => {
    adminApi.publishPolicy.mockRejectedValue({ response: { data: { message: 'Mã PIN sai' } } });
    await openPolicyTab();
    fireEvent.click(screen.getByRole('button', { name: 'Đăng phiên bản mới' }));
    const form = screen.getByRole('dialog', { name: 'Đăng chính sách mới' });
    fireEvent.change(within(form).getByLabelText('Tiêu đề'), { target: { value: 'A' } });
    fireEvent.change(within(form).getByLabelText('Nội dung'), { target: { value: 'B' } });
    fireEvent.click(within(form).getByRole('button', { name: 'Tiếp tục' }));
    const pin = screen.getByRole('dialog', { name: 'Xác nhận đăng chính sách' });
    fireEvent.change(within(pin).getByLabelText(/PIN/), { target: { value: '111111' } });
    fireEvent.click(within(pin).getByRole('button', { name: 'Đăng' }));
    expect(await within(pin).findByRole('alert')).toHaveTextContent('Mã PIN sai');
    expect(screen.getByRole('dialog', { name: 'Đăng chính sách mới' })).toBeInTheDocument();
  });
});
