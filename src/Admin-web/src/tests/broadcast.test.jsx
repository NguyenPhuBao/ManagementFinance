import React from 'react';
import { render, screen, fireEvent, waitFor, act, within } from '@testing-library/react';
import BroadcastPage from '../pages/system/BroadcastPage';
import adminApi from '../api/admin.api';
import notificationApi from '../api/notification.api';
import { formatDateTime } from '../utils/format';

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
    getMaintenanceStatus: vi.fn(),
    setMaintenanceStatus: vi.fn(),
    cancelScheduledMaintenance: vi.fn(),
    getMaintenanceHistory: vi.fn(),
    verifySecurityAction: vi.fn(),
  },
}));
vi.mock('../api/notification.api', () => ({ default: { broadcastToAll: vi.fn(), getBroadcastHistory: vi.fn() } }));

const NOW = new Date('2026-11-13T03:00:00Z').getTime();
const H = 3600 * 1000;
const iso = (ms) => new Date(ms).toISOString();
const pad = (n) => String(n).padStart(2, '0');
const local = (ms) => {
  const d = new Date(ms);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

const IDLE = { active: false, isEmergency: false, reason: '', activatedBy: null, activatedAt: null, scheduled: null, scheduledList: [] };
const HISTORY = [
  { id: 41, type: 'EMERGENCY', status: 'COMPLETED', activated_by: 'admin', reason: 'Sự cố cơ sở dữ liệu', started_at: iso(NOW - 5 * H), ended_at: iso(NOW - 3.5 * H) },
  { id: 42, type: 'SCHEDULED', status: 'SCHEDULED', activated_by: 'admin', reason: 'Nâng cấp xa', started_at: iso(NOW + 5 * H), scheduled_end_at: iso(NOW + 6 * H) },
  { id: 43, type: 'SCHEDULED', status: 'SCHEDULED', activated_by: 'admin', reason: 'Nâng cấp gần', started_at: iso(NOW + 1 * H) },
];

const lastHistoryCall = () => adminApi.getMaintenanceHistory.mock.calls.at(-1)[0];

const renderPage = async () => {
  render(<BroadcastPage />);
  await screen.findByText('Sự cố cơ sở dữ liệu');
};

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(NOW);
  Object.keys(handlers).forEach((k) => delete handlers[k]);
  adminApi.getMaintenanceStatus.mockReset().mockResolvedValue({ data: { ...IDLE } });
  adminApi.setMaintenanceStatus.mockReset().mockImplementation((p) => Promise.resolve({ data: { ...IDLE, ...p } }));
  adminApi.cancelScheduledMaintenance.mockReset().mockResolvedValue({ data: { ...IDLE } });
  adminApi.getMaintenanceHistory.mockReset().mockResolvedValue({ data: { data: HISTORY, pagination: { total: 3, totalPages: 1 } } });
  adminApi.verifySecurityAction.mockReset().mockResolvedValue({ success: true });
  notificationApi.broadcastToAll.mockReset().mockResolvedValue({ success: true, data: { id: 'u1', deliveredCount: 3 } });
  notificationApi.getBroadcastHistory.mockReset().mockResolvedValue({
    data: { data: [{ id: 9, level: 'warning', title: 'Bảo trì cuối tuần', message: 'Hệ thống tạm dừng', sender_username: 'admin', created_at: iso(NOW - H) }], pagination: { total: 1 } },
  });
});

afterEach(() => {
  vi.useRealTimers();
});

describe('Tab Bảo trì', () => {
  it('tải trạng thái và lịch sử; có tiêu đề, hai tab; lịch sử hiện loại, trạng thái, thời lượng; không lộ chữ kỹ thuật', async () => {
    await renderPage();
    expect(screen.getByRole('heading', { level: 1, name: 'Bảo trì & Thông báo' })).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: 'Bảo trì' })).toHaveAttribute('aria-selected', 'true');
    expect(screen.getByRole('tab', { name: 'Thông báo' })).toBeInTheDocument();
    expect(adminApi.getMaintenanceStatus).toHaveBeenCalled();
    expect(lastHistoryCall()).toEqual({ page: 1, limit: 5 });
    const row = screen.getByRole('row', { name: /Sự cố cơ sở dữ liệu/ });
    expect(within(row).getByText('Khẩn cấp')).toHaveAttribute('data-tone', 'danger');
    expect(within(row).getByText('Đã hoàn thành')).toHaveAttribute('data-tone', 'success');
    expect(within(row).getByText('1h 30m')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Kết thúc bảo trì' })).not.toBeInTheDocument();
    expect(document.body.textContent).not.toMatch(/PostgreSQL|Client-app|HTTP 503|Socket/);
  });

  it('đang bảo trì khẩn cấp: banner hiện lý do; ô khẩn cấp bị khóa; kết thúc phải nhập PIN, PIN gửi kèm lệnh', async () => {
    adminApi.getMaintenanceStatus.mockResolvedValue({ data: { ...IDLE, active: true, isEmergency: true, reason: 'Sửa máy chủ', activatedBy: 'admin', activatedAt: iso(NOW - H) } });
    await renderPage();
    expect(await screen.findByText('Đang bảo trì khẩn cấp')).toBeInTheDocument();
    expect(screen.getByText('Sửa máy chủ')).toBeInTheDocument();
    expect(screen.getByLabelText('Bảo trì khẩn cấp')).toBeDisabled();
    fireEvent.click(screen.getByRole('button', { name: 'Kết thúc bảo trì' }));
    const dialog = screen.getByRole('dialog', { name: 'Kết thúc bảo trì' });
    expect(within(dialog).getByRole('button', { name: 'Kết thúc' })).toBeDisabled();
    fireEvent.change(within(dialog).getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Kết thúc' }));
    await waitFor(() =>
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith({ active: false, reason: 'Sửa máy chủ', isEmergency: true, pin: '246810' })
    );
  });

  it('lên lịch: chặn khi trước dưới 3 giờ và khi kết thúc trước bắt đầu; hợp lệ thì hỏi PIN, gửi đúng dữ liệu kèm PIN rồi tải lại lịch sử', async () => {
    await renderPage();
    const submit = () => fireEvent.click(screen.getByRole('button', { name: 'Lên lịch bảo trì' }));
    fireEvent.change(screen.getByLabelText('Bắt đầu'), { target: { value: local(NOW + H) } });
    submit();
    expect(screen.getByRole('alert')).toHaveTextContent('ít nhất 3 giờ');
    fireEvent.change(screen.getByLabelText('Bắt đầu'), { target: { value: local(NOW + 8 * H) } });
    fireEvent.change(screen.getByLabelText('Kết thúc dự kiến'), { target: { value: local(NOW + 7 * H) } });
    submit();
    expect(screen.getByRole('alert')).toHaveTextContent('sau giờ bắt đầu');
    expect(adminApi.setMaintenanceStatus).not.toHaveBeenCalled();
    fireEvent.change(screen.getByLabelText('Kết thúc dự kiến'), { target: { value: local(NOW + 10 * H) } });
    fireEvent.change(screen.getByLabelText('Lý do'), { target: { value: 'Nâng cấp' } });
    const before = adminApi.getMaintenanceHistory.mock.calls.length;
    submit();
    expect(adminApi.setMaintenanceStatus).not.toHaveBeenCalled();
    const dialog = screen.getByRole('dialog', { name: 'Xác nhận lên lịch bảo trì' });
    expect(within(dialog).getByRole('button', { name: 'Lên lịch' })).toBeDisabled();
    fireEvent.change(within(dialog).getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Lên lịch' }));
    await waitFor(() =>
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith({
        scheduledAt: iso(new Date(local(NOW + 8 * H)).getTime()),
        scheduledEndAt: iso(new Date(local(NOW + 10 * H)).getTime()),
        reason: 'Nâng cấp',
        isEmergency: false,
        type: 'SCHEDULED',
        pin: '246810',
      })
    );
    await waitFor(() => expect(adminApi.getMaintenanceHistory.mock.calls.length).toBeGreaterThan(before));
    expect(screen.getByLabelText('Bắt đầu')).toHaveValue('');
  });

  it('lên lịch: chặn thời điểm bắt đầu xa hơn 14 ngày, không mở hộp PIN; ô Bắt đầu giới hạn tối đa 14 ngày; quy tắc ghi rõ', async () => {
    await renderPage();
    expect(screen.getByText(/không quá 14 ngày/)).toBeInTheDocument();
    expect(screen.getByLabelText('Bắt đầu')).toHaveAttribute('max', local(NOW + 14 * 24 * H));
    fireEvent.change(screen.getByLabelText('Bắt đầu'), { target: { value: local(NOW + 15 * 24 * H) } });
    fireEvent.click(screen.getByRole('button', { name: 'Lên lịch bảo trì' }));
    expect(screen.getByRole('alert')).toHaveTextContent('trong vòng 14 ngày');
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText('Bắt đầu'), { target: { value: local(NOW + 13 * 24 * H) } });
    fireEvent.click(screen.getByRole('button', { name: 'Lên lịch bảo trì' }));
    expect(screen.getByRole('dialog', { name: 'Xác nhận lên lịch bảo trì' })).toBeInTheDocument();
  });

  it('lên lịch: giờ kết thúc cách giờ bắt đầu quá 7 ngày thì chặn; ô Kết thúc giới hạn tối đa 7 ngày sau bắt đầu', async () => {
    await renderPage();
    expect(screen.getByText(/tối đa 7 ngày/)).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText('Bắt đầu'), { target: { value: local(NOW + 8 * H) } });
    expect(screen.getByLabelText('Kết thúc dự kiến')).toHaveAttribute('max', local(NOW + 8 * H + 7 * 24 * H));
    fireEvent.change(screen.getByLabelText('Kết thúc dự kiến'), { target: { value: local(NOW + 8 * H + 7 * 24 * H + H) } });
    fireEvent.click(screen.getByRole('button', { name: 'Lên lịch bảo trì' }));
    expect(screen.getByRole('alert')).toHaveTextContent('tối đa 7 ngày');
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText('Kết thúc dự kiến'), { target: { value: local(NOW + 8 * H + 7 * 24 * H) } });
    fireEvent.click(screen.getByRole('button', { name: 'Lên lịch bảo trì' }));
    expect(screen.getByRole('dialog', { name: 'Xác nhận lên lịch bảo trì' })).toBeInTheDocument();
  });

  it('lên lịch với PIN sai: hộp PIN hiện lỗi máy chủ, biểu mẫu giữ nguyên', async () => {
    adminApi.setMaintenanceStatus.mockRejectedValue({ response: { data: { message: 'Mã PIN quản trị viên không chính xác!' } } });
    await renderPage();
    fireEvent.change(screen.getByLabelText('Bắt đầu'), { target: { value: local(NOW + 8 * H) } });
    fireEvent.click(screen.getByRole('button', { name: 'Lên lịch bảo trì' }));
    const dialog = screen.getByRole('dialog', { name: 'Xác nhận lên lịch bảo trì' });
    fireEvent.change(within(dialog).getByLabelText(/PIN/), { target: { value: '111111' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Lên lịch' }));
    expect(await within(dialog).findByRole('alert')).toHaveTextContent('Mã PIN quản trị viên không chính xác!');
    expect(screen.getByLabelText('Bắt đầu')).toHaveValue(local(NOW + 8 * H));
  });

  it('bảo trì khẩn cấp: ẩn ô thời gian; bắt buộc PIN, PIN gửi kèm lệnh kích hoạt', async () => {
    await renderPage();
    expect(screen.getByText(/phiên theo lịch đang chạy bị hủy, lịch tới giờ trong lúc khẩn cấp còn chạy cũng bị hủy/)).toBeInTheDocument();
    fireEvent.click(screen.getByLabelText('Bảo trì khẩn cấp'));
    expect(screen.queryByLabelText('Bắt đầu')).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText('Lý do'), { target: { value: 'Sự cố' } });
    fireEvent.click(screen.getByRole('button', { name: 'Kích hoạt bảo trì khẩn cấp' }));
    expect(adminApi.setMaintenanceStatus).not.toHaveBeenCalled();
    const dialog = screen.getByRole('dialog', { name: 'Xác nhận bảo trì khẩn cấp' });
    expect(dialog).toHaveTextContent('tự kết thúc sau 7 ngày');
    expect(within(dialog).getByRole('button', { name: 'Kích hoạt' })).toBeDisabled();
    fireEvent.change(within(dialog).getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Kích hoạt' }));
    await waitFor(() =>
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith({ active: true, reason: 'Sự cố', isEmergency: true, pin: '246810' })
    );
    expect(adminApi.verifySecurityAction).not.toHaveBeenCalled();
  });

  it('không còn bảng "Lịch đã đặt"; lịch còn dưới 1 giờ vẫn hiện cảnh báo; hủy lịch qua bảng Lịch sử bảo trì', async () => {
    adminApi.getMaintenanceStatus.mockResolvedValue({
      data: {
        ...IDLE,
        scheduledList: [
          { id: 7, scheduledAt: iso(NOW + 0.5 * H), scheduledEndAt: iso(NOW + 1.5 * H), reason: 'Sao lưu', createdBy: 'admin' },
          { id: 42, scheduledAt: iso(NOW + 5 * H), reason: 'Nâng cấp xa', createdBy: 'admin' },
        ],
      },
    });
    await renderPage();
    const banner = (await screen.findByText('Bảo trì bắt đầu sau 30 phút')).closest('div.rounded-xl');
    // Băng cảnh báo chỉ báo tin: lịch dưới 3 giờ máy chủ không cho hủy nên không có nút hủy
    expect(within(banner).queryByRole('button', { name: 'Hủy lịch' })).not.toBeInTheDocument();
    expect(within(banner).getByText(/Sao lưu/)).toBeInTheDocument();
    expect(screen.queryByRole('table', { name: 'Lịch đã đặt' })).not.toBeInTheDocument();
    expect(screen.queryByText(/Lịch đã đặt/)).not.toBeInTheDocument();
    const row = screen.getByRole('row', { name: /Nâng cấp xa/ });
    fireEvent.click(within(row).getByRole('button', { name: 'Hủy lịch' }));
    const dialog = screen.getByRole('dialog', { name: 'Hủy lịch bảo trì' });
    expect(within(dialog).getByRole('button', { name: 'Hủy lịch' })).toBeDisabled();
    fireEvent.change(within(dialog).getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Hủy lịch' }));
    await waitFor(() => expect(adminApi.cancelScheduledMaintenance).toHaveBeenCalledWith(42, { pin: '246810' }));
  });

  it('lịch sử: tách "Kết thúc dự kiến" và "Kết thúc thực tế"; lịch hủy trước giờ ghi giờ hủy, vẫn giữ giờ dự kiến', async () => {
    const rows = [
      HISTORY[0],
      { id: 51, type: 'SCHEDULED', status: 'COMPLETED', reason: 'Xong sớm', started_at: iso(NOW - 10 * H), scheduled_end_at: iso(NOW - 7 * H), ended_at: iso(NOW - 8 * H), actual_duration_seconds: 7200 },
      { id: 52, type: 'SCHEDULED', status: 'CANCELLED', reason: 'Hủy trước giờ', started_at: iso(NOW + 20 * H), scheduled_end_at: iso(NOW + 22 * H), ended_at: iso(NOW - 2 * H), actual_duration_seconds: 0 },
      { id: 53, type: 'SCHEDULED', status: 'CANCELLED', reason: 'Bị khẩn cấp ngắt', started_at: iso(NOW - 6 * H), scheduled_end_at: iso(NOW - 3 * H), ended_at: iso(NOW - 5 * H), actual_duration_seconds: 3600 },
      { id: 54, type: 'EMERGENCY', status: 'ONGOING', reason: 'Đang sửa', started_at: iso(NOW - H) },
      { id: 55, type: 'SCHEDULED', status: 'SCHEDULED', reason: 'Chờ chạy', started_at: iso(NOW + 30 * H), scheduled_end_at: iso(NOW + 31 * H) },
    ];
    adminApi.getMaintenanceHistory.mockResolvedValue({ data: { data: rows, pagination: { total: 6, totalPages: 1 } } });
    await renderPage();
    const table = screen.getByRole('row', { name: /Xong sớm/ }).closest('table');
    expect(within(table).getByRole('columnheader', { name: 'Kết thúc dự kiến' })).toBeInTheDocument();
    expect(within(table).getByRole('columnheader', { name: 'Kết thúc thực tế' })).toBeInTheDocument();
    const cells = (reason) => {
      const r = screen.getByRole('row', { name: new RegExp(reason) });
      const heads = within(table).getAllByRole('columnheader').map((h) => h.textContent);
      const tds = within(r).getAllByRole('cell');
      return { planned: tds[heads.indexOf('Kết thúc dự kiến')].textContent, actual: tds[heads.indexOf('Kết thúc thực tế')].textContent };
    };
    expect(cells('Xong sớm')).toEqual({ planned: formatDateTime(iso(NOW - 7 * H)), actual: formatDateTime(iso(NOW - 8 * H)) });
    expect(cells('Hủy trước giờ')).toEqual({ planned: formatDateTime(iso(NOW + 22 * H)), actual: `Hủy lúc ${formatDateTime(iso(NOW - 2 * H))}` });
    expect(cells('Bị khẩn cấp ngắt')).toEqual({ planned: formatDateTime(iso(NOW - 3 * H)), actual: formatDateTime(iso(NOW - 5 * H)) });
    expect(cells('Đang sửa')).toEqual({ planned: '—', actual: 'Đang diễn ra' });
    expect(cells('Chờ chạy')).toEqual({ planned: formatDateTime(iso(NOW + 31 * H)), actual: '—' });
    expect(document.body.textContent).not.toMatch(/\(hủy\)|\(dự kiến\)/);
  });

  it('lịch sử: lọc loại gửi lên máy chủ; chỉ cho hủy lịch còn từ 3 giờ', async () => {
    await renderPage();
    const far = screen.getByRole('row', { name: /Nâng cấp xa/ });
    expect(within(far).getByRole('button', { name: 'Hủy lịch' })).toBeInTheDocument();
    const near = screen.getByRole('row', { name: /Nâng cấp gần/ });
    expect(within(near).queryByRole('button', { name: 'Hủy lịch' })).not.toBeInTheDocument();
    expect(within(near).getByText('Dưới 3 giờ')).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText('Loại bảo trì'), { target: { value: 'EMERGENCY' } });
    await waitFor(() => expect(lastHistoryCall()).toEqual({ page: 1, limit: 5, type: 'EMERGENCY' }));
    fireEvent.change(screen.getByLabelText('Trạng thái bảo trì'), { target: { value: 'COMPLETED' } });
    await waitFor(() => expect(lastHistoryCall()).toEqual({ page: 1, limit: 5, type: 'EMERGENCY', status: 'COMPLETED' }));
  });

  it('admin.maintenance_changed hiện banner và tải lại lịch sử', async () => {
    await renderPage();
    const before = adminApi.getMaintenanceHistory.mock.calls.length;
    emit('admin.maintenance_changed', { ...IDLE, active: true, isEmergency: false, reason: 'Bảo trì theo lịch' });
    expect(await screen.findByText('Đang bảo trì theo lịch')).toBeInTheDocument();
    await waitFor(() => expect(adminApi.getMaintenanceHistory.mock.calls.length).toBeGreaterThan(before));
  });
});

describe('Tab Thông báo', () => {
  it('tải lịch sử; chọn mức độ, nhập nội dung có bộ đếm và xem trước; gửi rồi xóa biểu mẫu', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('tab', { name: 'Thông báo' }));
    await screen.findByText('Bảo trì cuối tuần');
    expect(notificationApi.getBroadcastHistory).toHaveBeenCalledWith({ page: 1, limit: 5 });
    const send = screen.getByRole('button', { name: 'Gửi thông báo' });
    expect(send).toBeDisabled();
    fireEvent.click(screen.getByRole('radio', { name: 'Cảnh báo' }));
    fireEvent.change(screen.getByLabelText('Tiêu đề'), { target: { value: 'Chào' } });
    fireEvent.change(screen.getByLabelText('Nội dung'), { target: { value: 'Phiên bản mới' } });
    expect(screen.getByText('4/120')).toBeInTheDocument();
    expect(screen.getByRole('region', { name: 'Xem trước' })).toHaveTextContent('Phiên bản mới');
    fireEvent.click(send);
    await waitFor(() => expect(notificationApi.broadcastToAll).toHaveBeenCalledWith({ title: 'Chào', message: 'Phiên bản mới', level: 'warning' }));
    // Máy chủ chỉ gửi tới thiết bị đang kết nối: báo đúng số thiết bị, không nói "mọi người dùng"
    const status = await screen.findByRole('status');
    expect(status).toHaveTextContent('Đã gửi tới 3 thiết bị đang kết nối');
    expect(status).not.toHaveTextContent('mọi người dùng');
    expect(screen.getByLabelText('Tiêu đề')).toHaveValue('');
    expect(notificationApi.getBroadcastHistory).toHaveBeenCalledTimes(2);
  });

  it('không có thiết bị nào đang kết nối: cảnh báo tin không tới ai ngay lúc này', async () => {
    notificationApi.broadcastToAll.mockResolvedValue({ success: true, data: { id: 'u1', deliveredCount: 0 } });
    await renderPage();
    fireEvent.click(screen.getByRole('tab', { name: 'Thông báo' }));
    await screen.findByText('Bảo trì cuối tuần');
    fireEvent.change(screen.getByLabelText('Tiêu đề'), { target: { value: 'Chào' } });
    fireEvent.change(screen.getByLabelText('Nội dung'), { target: { value: 'Tin thử' } });
    fireEvent.click(screen.getByRole('button', { name: 'Gửi thông báo' }));
    const status = (await screen.findByText(/Không có thiết bị nào đang kết nối/)).closest('[role="status"]');
    expect(status).toHaveAttribute('data-tone', 'warning');
    expect(notificationApi.broadcastToAll).toHaveBeenCalledTimes(1);
  });
});
