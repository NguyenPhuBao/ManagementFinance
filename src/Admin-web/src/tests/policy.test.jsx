import React from 'react';
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
// Tab Chính sách đang ẩn trên trang Bảo trì & Thông báo (2026-11-16); dựng thẳng PolicyTab để giữ test cho lúc bật lại.
import PolicyTab from '../pages/system/broadcast/PolicyTab';
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
    setPolicyStatus: vi.fn(),
  },
}));
vi.mock('../api/notification.api', () => ({ default: { broadcastToAll: vi.fn(), getBroadcastHistory: vi.fn().mockResolvedValue({ data: { data: [], pagination: { total: 0 } } }) } }));

// version = mã nội bộ; docVersion = phiên bản trong chính sách
const POLICIES = {
  policies: [
    { version: 3, policyId: 1, docVersion: 2, title: 'Chính sách người dùng', status: 'ACTIVE', content: 'Người dùng bản 2', publishedAt: '2026-11-13T02:00:00Z', acceptedCount: 1 },
    { version: 1, policyId: 1, docVersion: 1, title: 'Chính sách người dùng', status: 'INACTIVE', content: 'Người dùng bản 1', publishedAt: '2026-11-01T02:00:00Z', acceptedCount: 3 },
    { version: 2, policyId: 2, docVersion: 1, title: 'Thu thập dữ liệu', status: 'ACTIVE', content: 'Thu thập bản 1', publishedAt: '2026-11-05T02:00:00Z', acceptedCount: 2 },
  ],
  documents: [
    { id: 1, title: 'Chính sách người dùng' },
    { id: 2, title: 'Thu thập dữ liệu' },
  ],
  activeUsers: 4,
};

const openPolicyTab = async () => {
  render(<PolicyTab />);
  return screen.findByRole('region', { name: 'Chính sách đang sử dụng' });
};
const table = () => screen.getByRole('table', { name: 'Các chính sách' });
const rowOf = (title, version) =>
  within(table())
    .getAllByRole('row')
    .find((r) => r.textContent.includes(title) && within(r).queryByText(`v${version}`));

beforeEach(() => {
  adminApi.getMaintenanceStatus.mockReset().mockResolvedValue({ data: { active: false, scheduledList: [] } });
  adminApi.getMaintenanceHistory.mockReset().mockResolvedValue({ data: { data: [], pagination: { total: 0 } } });
  adminApi.verifySecurityAction.mockReset().mockResolvedValue({ success: true });
  adminApi.getPolicies.mockReset().mockResolvedValue({ data: POLICIES });
  adminApi.publishPolicy.mockReset().mockResolvedValue({ data: { version: 4 } });
  adminApi.setPolicyStatus.mockReset().mockResolvedValue({ data: { version: 1 } });
});

describe('Tab Chính sách', () => {
  it('thẻ đầu tab liệt kê từng chính sách đang sử dụng kèm tỉ lệ đồng ý; nút Thêm chính sách', async () => {
    const current = await openPolicyTab();
    expect(current).toHaveTextContent('Chính sách người dùng');
    expect(current).toHaveTextContent('v2');
    expect(current).toHaveTextContent('1 / 4 người dùng đã đồng ý');
    expect(current).toHaveTextContent('Thu thập dữ liệu');
    expect(current).toHaveTextContent('2 / 4 người dùng đã đồng ý');
    expect(current).not.toHaveTextContent('Người dùng bản 1');
    expect(screen.getByRole('button', { name: 'Thêm chính sách' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Đăng phiên bản mới' })).not.toBeInTheDocument();
  });

  it('bảng: trạng thái và nút thao tác theo trạng thái (Ngừng chỉ khi đang dùng, Kích hoạt chỉ khi đã ngừng)', async () => {
    await openPolicyTab();
    const heads = within(table()).getAllByRole('columnheader').map((h) => h.textContent);
    expect(heads).toEqual(expect.arrayContaining(['Chính sách', 'Phiên bản', 'Trạng thái', 'Ngày đăng', 'Đã đồng ý', 'Thao tác']));
    const on = rowOf('Chính sách người dùng', 2);
    expect(within(on).getByText('Đang sử dụng')).toHaveAttribute('data-tone', 'success');
    expect(within(on).getByRole('button', { name: 'Ngừng chính sách' })).toBeInTheDocument();
    expect(within(on).queryByRole('button', { name: 'Kích hoạt chính sách' })).not.toBeInTheDocument();
    const off = rowOf('Chính sách người dùng', 1);
    expect(within(off).getByText('Ngừng sử dụng')).toHaveAttribute('data-tone', 'neutral');
    expect(within(off).getByRole('button', { name: 'Kích hoạt chính sách' })).toBeInTheDocument();
    expect(within(off).queryByRole('button', { name: 'Ngừng chính sách' })).not.toBeInTheDocument();
  });

  it('nút con mắt mở nội dung đầy đủ của đúng phiên bản', async () => {
    await openPolicyTab();
    fireEvent.click(within(rowOf('Chính sách người dùng', 1)).getByRole('button', { name: 'Xem nội dung' }));
    const dialog = screen.getByRole('dialog', { name: 'Chính sách người dùng v1' });
    expect(dialog).toHaveTextContent('Người dùng bản 1');
    expect(dialog).toHaveTextContent('Ngừng sử dụng');
  });

  it('Ngừng chính sách: nhập PIN, gửi PIN cùng setPolicyStatus(INACTIVE), tải lại danh sách', async () => {
    await openPolicyTab();
    fireEvent.click(within(rowOf('Thu thập dữ liệu', 1)).getByRole('button', { name: 'Ngừng chính sách' }));
    const pin = screen.getByRole('dialog', { name: 'Ngừng chính sách' });
    expect(pin).toHaveTextContent('Thu thập dữ liệu v1');
    fireEvent.change(within(pin).getByLabelText(/PIN/), { target: { value: '246810' } });
    const loadsBefore = adminApi.getPolicies.mock.calls.length;
    fireEvent.click(within(pin).getByRole('button', { name: 'Ngừng' }));
    await waitFor(() => expect(adminApi.setPolicyStatus).toHaveBeenCalledWith(2, { status: 'INACTIVE', pin: '246810' }));
    expect(adminApi.verifySecurityAction).not.toHaveBeenCalled();
    await waitFor(() => expect(adminApi.getPolicies.mock.calls.length).toBeGreaterThan(loadsBefore));
  });

  it('Kích hoạt khi chính sách đó đang có bản khác đang dùng: hộp PIN hiện lỗi máy chủ, không tải lại', async () => {
    adminApi.setPolicyStatus.mockRejectedValue({ response: { data: { message: 'Chính sách "Chính sách người dùng" đang dùng phiên bản v2.' } } });
    await openPolicyTab();
    fireEvent.click(within(rowOf('Chính sách người dùng', 1)).getByRole('button', { name: 'Kích hoạt chính sách' }));
    const pin = screen.getByRole('dialog', { name: 'Kích hoạt chính sách' });
    fireEvent.change(within(pin).getByLabelText(/PIN/), { target: { value: '246810' } });
    const loadsBefore = adminApi.getPolicies.mock.calls.length;
    fireEvent.click(within(pin).getByRole('button', { name: 'Kích hoạt' }));
    await waitFor(() => expect(adminApi.setPolicyStatus).toHaveBeenCalledWith(1, { status: 'ACTIVE', pin: '246810' }));
    expect(await within(pin).findByRole('alert')).toHaveTextContent('đang dùng phiên bản v2');
    expect(adminApi.getPolicies.mock.calls.length).toBe(loadsBefore);
  });

  it('chưa có chính sách: báo trống, vẫn có nút Thêm chính sách', async () => {
    adminApi.getPolicies.mockResolvedValue({ data: { policies: [], documents: [], activeUsers: 4 } });
    const current = await openPolicyTab();
    expect(within(current).getByText('Chưa có chính sách nào đang sử dụng.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Thêm chính sách' })).toBeInTheDocument();
  });
});

describe('Thêm chính sách', () => {
  const openForm = async () => {
    await openPolicyTab();
    fireEvent.click(screen.getByRole('button', { name: 'Thêm chính sách' }));
    return screen.getByRole('dialog', { name: 'Thêm chính sách' });
  };

  it('ô chọn có "Chính sách mới" và các chính sách hiện có; chọn chính sách có sẵn thì ẩn ô tiêu đề, báo phiên bản kế tiếp; gửi documentId cùng PIN', async () => {
    const form = await openForm();
    const select = within(form).getByLabelText('Chính sách');
    expect(within(select).getAllByRole('option').map((o) => o.textContent)).toEqual(['Chính sách mới', 'Chính sách người dùng', 'Thu thập dữ liệu']);
    fireEvent.change(select, { target: { value: '1' } });
    expect(within(form).queryByLabelText('Tiêu đề')).not.toBeInTheDocument();
    expect(form).toHaveTextContent('Tạo phiên bản v3 ở trạng thái Ngừng sử dụng');
    fireEvent.change(within(form).getByLabelText('Nội dung'), { target: { value: 'Người dùng bản 3' } });
    fireEvent.click(within(form).getByRole('button', { name: 'Tiếp tục' }));
    const pin = screen.getByRole('dialog', { name: 'Xác nhận thêm chính sách' });
    fireEvent.change(within(pin).getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(within(pin).getByRole('button', { name: 'Thêm' }));
    await waitFor(() => expect(adminApi.publishPolicy).toHaveBeenCalledWith({ documentId: 1, content: 'Người dùng bản 3', pin: '246810' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Thêm chính sách' })).not.toBeInTheDocument());
  });

  it('chính sách mới: bắt buộc tiêu đề + nội dung; gửi title cùng PIN; PIN sai giữ hộp PIN và hiện lỗi', async () => {
    adminApi.publishPolicy.mockRejectedValueOnce({ response: { data: { message: 'Mã PIN sai' } } });
    const form = await openForm();
    const next = within(form).getByRole('button', { name: 'Tiếp tục' });
    expect(next).toBeDisabled();
    fireEvent.change(within(form).getByLabelText('Tiêu đề'), { target: { value: 'Điều khoản thanh toán' } });
    fireEvent.change(within(form).getByLabelText('Nội dung'), { target: { value: 'Nội dung điều khoản' } });
    expect(form).toHaveTextContent('Tạo chính sách mới ở phiên bản v1, trạng thái Ngừng sử dụng');
    fireEvent.click(next);
    const pin = screen.getByRole('dialog', { name: 'Xác nhận thêm chính sách' });
    fireEvent.change(within(pin).getByLabelText(/PIN/), { target: { value: '111111' } });
    fireEvent.click(within(pin).getByRole('button', { name: 'Thêm' }));
    expect(await within(pin).findByRole('alert')).toHaveTextContent('Mã PIN sai');
    expect(adminApi.publishPolicy).toHaveBeenCalledWith({ title: 'Điều khoản thanh toán', content: 'Nội dung điều khoản', pin: '111111' });
    expect(screen.getByRole('dialog', { name: 'Thêm chính sách' })).toBeInTheDocument();
  });
});
