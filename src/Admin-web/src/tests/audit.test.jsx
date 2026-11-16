import React from 'react';
import { render, screen, fireEvent, waitFor, act, within } from '@testing-library/react';
import AuditLogPage from '../pages/system/AuditLogPage';
import adminApi from '../api/admin.api';
import { exportToCsv } from '../utils/csv-exporter.util';

const handlers = {};
const fakeSocket = {
  connected: true,
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
vi.mock('../utils/csv-exporter.util', () => ({ exportToCsv: vi.fn() }));
vi.mock('../api/admin.api', () => ({ default: { getAuditLogs: vi.fn() } }));

const LOGS = [
  { id: 501, idaccount: 1, ip: '10.0.0.1', account: { username: 'admin', User: { fullname: 'Quản trị' } }, action: '[AUTH] Đăng nhập', request: 'POST /api/auth/login', req_status: 'Pass', time_req: '2026-11-12T10:00:00Z', time_res: '2026-11-12T10:00:01Z' },
  { id: 502, idaccount: 2, ip: '10.0.0.2', account: { username: 'an' }, action: 'PATCH /api/admin/updatestatus/5', request: 'PATCH /api/admin/updatestatus/5', req_status: 'Fail', reason: 'Sai mã PIN', time_req: '2026-11-12T09:00:00Z', time_res: '2026-11-12T09:00:01Z' },
];

const row = (text) => screen.getByRole('row', { name: new RegExp(text) });
const lastCall = () => adminApi.getAuditLogs.mock.calls.at(-1)[0];

const renderPage = async () => {
  render(<AuditLogPage />);
  await screen.findByRole('row', { name: /501/ });
};

beforeEach(() => {
  Object.keys(handlers).forEach((k) => delete handlers[k]);
  adminApi.getAuditLogs.mockReset().mockResolvedValue({ data: { items: LOGS.map((l) => ({ ...l })), total: 2 } });
  exportToCsv.mockReset();
});

describe('Hiển thị', () => {
  it('tải trang đầu, có tiêu đề; hàng hiện nhãn phân loại, phương thức, trạng thái và lý do', async () => {
    await renderPage();
    expect(adminApi.getAuditLogs).toHaveBeenCalledWith({ page: 1, limit: 10 });
    expect(screen.getByRole('heading', { level: 1, name: 'Nhật ký kiểm toán' })).toBeInTheDocument();
    const first = row('501');
    expect(within(first).getByText('Xác thực')).toHaveAttribute('data-tone', 'info');
    expect(within(first).getByText('POST')).toBeInTheDocument();
    expect(within(first).getByText('Thành công')).toHaveAttribute('data-tone', 'success');
    const second = row('502');
    expect(within(second).getByText('Thất bại')).toHaveAttribute('data-tone', 'danger');
    expect(within(second).getByText('Sai mã PIN')).toBeInTheDocument();
    expect(within(second).getByText('10.0.0.2')).toBeInTheDocument();
  });
});

describe('Bộ lọc', () => {
  it('tìm, trạng thái và khoảng ngày gửi lên máy chủ; đặt lại xóa hết', async () => {
    await renderPage();
    fireEvent.change(screen.getByLabelText('Tìm nhật ký'), { target: { value: 'login' } });
    fireEvent.change(screen.getByLabelText('Trạng thái'), { target: { value: 'Fail' } });
    fireEvent.change(screen.getByLabelText('Từ ngày'), { target: { value: '2026-11-01' } });
    fireEvent.change(screen.getByLabelText('Đến ngày'), { target: { value: '2026-11-12' } });
    await waitFor(() =>
      expect(lastCall()).toEqual({ page: 1, limit: 10, search: 'login', status: 'Fail', startDate: '2026-11-01', endDate: '2026-11-12T23:59:59' })
    );
    fireEvent.click(screen.getByRole('button', { name: 'Đặt lại' }));
    await waitFor(() => expect(lastCall()).toEqual({ page: 1, limit: 10 }));
  });
});

describe('Realtime, làm mới, xuất CSV', () => {
  it('bản ghi mới chèn lên đầu khi đang ở trang đầu và không lọc', async () => {
    await renderPage();
    emit('audit_activity', { id: 777, username: 'binh', action: '[USER] Khóa tài khoản', request: 'PATCH /api/admin/updatestatus/9', status: 'Pass' });
    expect(screen.getAllByRole('row')[1]).toHaveTextContent('777');
  });

  it('đang lọc thì không chèn mà báo số bản ghi mới; bấm Xem ngay tải lại', async () => {
    await renderPage();
    fireEvent.change(screen.getByLabelText('Trạng thái'), { target: { value: 'Fail' } });
    await waitFor(() => expect(lastCall()).toEqual({ page: 1, limit: 10, status: 'Fail' }));
    emit('audit_activity', { id: 778, username: 'binh', action: 'x', status: 'Pass' });
    const banner = screen.getByRole('status', { name: '' });
    expect(banner).toHaveTextContent('1 hoạt động mới');
    const calls = adminApi.getAuditLogs.mock.calls.length;
    fireEvent.click(within(banner).getByRole('button', { name: 'Xem ngay' }));
    await waitFor(() => expect(adminApi.getAuditLogs.mock.calls.length).toBeGreaterThan(calls));
    expect(screen.queryByText(/hoạt động mới/)).not.toBeInTheDocument();
  });

  it('làm mới gọi lại API; xuất CSV ghi đủ dòng', async () => {
    await renderPage();
    const calls = adminApi.getAuditLogs.mock.calls.length;
    fireEvent.click(screen.getByRole('button', { name: 'Làm mới' }));
    await waitFor(() => expect(adminApi.getAuditLogs.mock.calls.length).toBe(calls + 1));
    fireEvent.click(screen.getByRole('button', { name: 'Xuất CSV' }));
    await waitFor(() => expect(exportToCsv).toHaveBeenCalledTimes(1));
    expect(lastCall()).toEqual({ page: 1, limit: 2 });
    expect(exportToCsv.mock.calls[0][0].rows).toHaveLength(2);
  });
});
