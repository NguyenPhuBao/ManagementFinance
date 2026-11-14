import React from 'react';
import { render, screen, fireEvent, waitFor, act, within } from '@testing-library/react';
import AuditLogPage from '../pages/system/AuditLogPage';
import adminApi from '../api/admin.api';

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
vi.mock('../api/admin.api', () => ({
  default: {
    getAuditLogs: vi.fn(),
    getDataIncidents: vi.fn(),
    createDataIncident: vi.fn(),
    updateDataIncident: vi.fn(),
    dataIncidentAction: vi.fn(),
    verifySecurityAction: vi.fn(),
  },
}));

const H = 3600 * 1000;
const iso = (ms) => new Date(ms).toISOString();
const incident = (over) => ({
  id: 1, code: 'SC-2026-001', title: 'Lộ bản sao lưu', description: 'Bản sao lưu công khai', source: 'PROCESSOR', status: 'OPEN',
  detected_at: iso(Date.now() - 2 * H), deadline: iso(Date.now() + 70 * H), remainingMs: 70 * H, overdue: false, reportedLate: false,
  sensitive: true, affected_users: 12, report_not_required: false, ...over,
});
const LIST = () => [
  incident(),
  incident({ id: 2, code: 'SC-2026-002', title: 'Admin bị chiếm', detected_at: iso(Date.now() - 80 * H), deadline: iso(Date.now() - 8 * H), remainingMs: -8 * H, overdue: true }),
  incident({ id: 3, code: 'SC-2026-003', title: 'Đã xử lý xong', status: 'CLOSED', authority_reported_at: iso(Date.now() - 50 * H), overdue: false }),
];

const openTab = async () => {
  render(<AuditLogPage />);
  const tabs = await screen.findByRole('tablist', { name: 'Nội dung nhật ký' });
  fireEvent.click(within(tabs).getByRole('tab', { name: 'Sự cố dữ liệu' }));
  await screen.findByRole('heading', { level: 2, name: 'Sổ sự cố dữ liệu' });
};
const card = (code) => screen.getByRole('article', { name: new RegExp(code) });

beforeEach(() => {
  Object.keys(handlers).forEach((k) => delete handlers[k]);
  adminApi.getAuditLogs.mockReset().mockResolvedValue({ data: { items: [], total: 0 } });
  adminApi.getDataIncidents.mockReset().mockResolvedValue({ data: LIST() });
  adminApi.createDataIncident.mockReset().mockResolvedValue({ data: incident({ id: 9, code: 'SC-2026-009' }) });
  adminApi.updateDataIncident.mockReset().mockResolvedValue({ data: incident() });
  adminApi.dataIncidentAction.mockReset().mockResolvedValue({ data: incident() });
  adminApi.verifySecurityAction.mockReset().mockResolvedValue({ success: true });
});

describe('Sự cố dữ liệu — Tầng 1: hiển thị', () => {
  it('trang Nhật ký có 2 tab; tab sự cố tải danh sách, mỗi sự cố có mã, tiêu đề, trạng thái, đồng hồ 72 giờ', async () => {
    await openTab();
    expect(adminApi.getDataIncidents).toHaveBeenCalled();
    await waitFor(() => expect(card('SC-2026-001')).toBeInTheDocument());
    const a = card('SC-2026-001');
    expect(a).toHaveTextContent('Lộ bản sao lưu');
    expect(a).toHaveTextContent('Đang mở');
    expect(within(a).getByRole('timer')).toHaveTextContent(/^Còn (69|70):\d{2}:\d{2}/);
    const b = card('SC-2026-002');
    expect(within(b).getByRole('timer')).toHaveTextContent(/^Quá hạn 0?8:\d{2}:\d{2}/);
    const c = card('SC-2026-003');
    expect(c).toHaveTextContent('Đã đóng');
    expect(within(c).queryByRole('timer')).not.toBeInTheDocument();
    expect(within(c).queryByRole('button', { name: 'Đóng sự cố' })).not.toBeInTheDocument();
  });

  it('chưa có sự cố: hiện thông báo trống', async () => {
    adminApi.getDataIncidents.mockResolvedValue({ data: [] });
    await openTab();
    expect(await screen.findByText('Chưa có sự cố dữ liệu')).toBeInTheDocument();
  });
});

describe('Sự cố dữ liệu — Tầng 2: thao tác gọi đúng API', () => {
  it('mở sự cố mới: gửi tiêu đề, mô tả, nguồn, thời điểm phát hiện', async () => {
    await openTab();
    fireEvent.click(screen.getByRole('button', { name: 'Mở sự cố' }));
    const dialog = await screen.findByRole('dialog', { name: 'Mở sự cố dữ liệu' });
    fireEvent.change(within(dialog).getByLabelText('Tiêu đề'), { target: { value: 'Lộ khóa mã hóa' } });
    fireEvent.change(within(dialog).getByLabelText('Mô tả'), { target: { value: 'Khóa bị đẩy lên kho mã' } });
    fireEvent.change(within(dialog).getByLabelText('Nguồn phát hiện'), { target: { value: 'AUDIT_LOG' } });
    fireEvent.change(within(dialog).getByLabelText('Số người dùng bị ảnh hưởng'), { target: { value: '30' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Lưu' }));
    await waitFor(() => expect(adminApi.createDataIncident).toHaveBeenCalled());
    const body = adminApi.createDataIncident.mock.calls[0][0];
    expect(body).toMatchObject({ title: 'Lộ khóa mã hóa', description: 'Khóa bị đẩy lên kho mã', source: 'AUDIT_LOG', affectedUsers: '30' });
    expect(new Date(body.detectedAt).getTime()).toBeGreaterThan(Date.now() - 5 * 60 * 1000);
    await waitFor(() => expect(adminApi.getDataIncidents.mock.calls.length).toBeGreaterThan(1));
  });

  it('ghi nhận đã ngăn chặn gọi đúng thao tác', async () => {
    await openTab();
    await waitFor(() => expect(card('SC-2026-001')).toBeInTheDocument());
    fireEvent.click(within(card('SC-2026-001')).getByRole('button', { name: 'Đã ngăn chặn' }));
    await waitFor(() => expect(adminApi.dataIncidentAction).toHaveBeenCalledWith(1, 'contain', {}));
  });

  it('báo cơ quan khi đã quá hạn: bắt buộc lý do báo muộn rồi mới lưu', async () => {
    await openTab();
    await waitFor(() => expect(card('SC-2026-002')).toBeInTheDocument());
    fireEvent.click(within(card('SC-2026-002')).getByRole('button', { name: 'Đã báo cơ quan' }));
    const dialog = await screen.findByRole('dialog', { name: 'Ghi nhận đã báo cơ quan' });
    fireEvent.change(within(dialog).getByLabelText('Số công văn / mã tiếp nhận'), { target: { value: 'CV-12' } });
    expect(within(dialog).getByRole('button', { name: 'Lưu' })).toBeDisabled();
    fireEvent.change(within(dialog).getByLabelText('Lý do báo muộn'), { target: { value: 'Bên xử lý báo chậm' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Lưu' }));
    await waitFor(() => expect(adminApi.dataIncidentAction).toHaveBeenCalledWith(2, 'report', expect.objectContaining({ reference: 'CV-12', lateReason: 'Bên xử lý báo chậm' })));
  });

  it('đóng sự cố: nhập nguyên nhân gốc, lý do không cần báo, rồi xác thực PIN trong cùng lời gọi', async () => {
    await openTab();
    await waitFor(() => expect(card('SC-2026-001')).toBeInTheDocument());
    fireEvent.click(within(card('SC-2026-001')).getByRole('button', { name: 'Đóng sự cố' }));
    const dialog = await screen.findByRole('dialog', { name: 'Đóng sự cố dữ liệu' });
    fireEvent.change(within(dialog).getByLabelText('Nguyên nhân gốc'), { target: { value: 'Cấu hình sai quyền bucket' } });
    fireEvent.click(within(dialog).getByLabelText('Không cần báo cơ quan'));
    fireEvent.change(within(dialog).getByLabelText('Lý do không cần báo'), { target: { value: 'Dữ liệu đã mã hóa' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Tiếp tục' }));
    const pin = await screen.findByRole('dialog', { name: 'Xác nhận đóng sự cố' });
    fireEvent.change(within(pin).getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(within(pin).getByRole('button', { name: 'Đóng sự cố' }));
    await waitFor(() => expect(adminApi.dataIncidentAction).toHaveBeenCalledWith(1, 'close', {
      rootCause: 'Cấu hình sai quyền bucket', reportNotRequired: true, noReportReason: 'Dữ liệu đã mã hóa', pin: '246810', password: '',
    }));
  });

  it('sự kiện admin.data_incident_changed tải lại danh sách', async () => {
    await openTab();
    await waitFor(() => expect(adminApi.getDataIncidents).toHaveBeenCalledTimes(1));
    emit('admin.data_incident_changed', { id: 1, code: 'SC-2026-001', status: 'CONTAINED' });
    await waitFor(() => expect(adminApi.getDataIncidents).toHaveBeenCalledTimes(2));
  });
});
