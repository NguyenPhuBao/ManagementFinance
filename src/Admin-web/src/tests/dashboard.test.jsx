import React from 'react';
import { render, screen, fireEvent, waitFor, act, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import DashboardPage from '../pages/dashboard/DashboardPage';
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
vi.mock('../components/common/ServerHealthPanel', () => ({ default: () => <div data-testid="server-health" /> }));
vi.mock('../api/admin.api', () => ({
  default: {
    getTotalUsers: vi.fn(),
    getTotalCategories: vi.fn(),
    getSystemHealth: vi.fn(),
    getUserToTime: vi.fn(),
    getLoginStats: vi.fn(),
    getRequestStats: vi.fn(),
    getRecentActivities: vi.fn(),
    getAvailability: vi.fn(),
  },
}));

const ACTIVITIES = [
  { id: 901, user: 'admin', action: '[AUTH] Đăng nhập', request: 'POST /api/auth/login', reason: null, status: 'Pass', time_req: '2026-11-12T03:00:00Z' },
  { id: 902, user: 'an', action: '[USER] Khóa tài khoản', request: 'PATCH /api/admin/updatestatus/5', reason: 'Sai mã PIN', status: 'Fail', time_req: '2026-11-11T03:00:00Z' },
];

const statsArgs = () => [adminApi.getUserToTime, adminApi.getLoginStats, adminApi.getRequestStats].map((fn) => fn.mock.calls.at(-1)[0]);

const renderPage = async () => {
  render(
    <MemoryRouter>
      <DashboardPage />
    </MemoryRouter>
  );
  await screen.findByRole('row', { name: /Đăng nhập/ });
};

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(new Date('2026-11-12T05:00:00Z'));
  Object.keys(handlers).forEach((k) => delete handlers[k]);
  adminApi.getTotalUsers.mockReset().mockResolvedValue({ data: { total: 1248 } });
  adminApi.getTotalCategories.mockReset().mockResolvedValue({ data: { total: 42 } });
  adminApi.getSystemHealth.mockReset().mockResolvedValue({
    data: { data: { uptime: { runningFormatted: '3 ngày', startedAt: '2026-11-09T05:00:00Z', availability: { period: 'month', year: 2026, month: 11, percent: 99.98 } } } },
  });
  adminApi.getUserToTime.mockReset().mockResolvedValue({ data: { current: 39, previous: 35, growth: 12 } });
  adminApi.getLoginStats.mockReset().mockResolvedValue({
    data: { summary: { total: 20, max: 12, avg: 4 }, timeline: [{ label: '08:00', count: 12 }, { label: '09:00', count: 8 }], format: 'hour' },
  });
  adminApi.getRequestStats.mockReset().mockResolvedValue({
    data: { summary: { total: 300, max: 180, avg: 150 }, timeline: [{ label: '08:00', count: 180 }, { label: '09:00', count: 120 }], format: 'hour' },
  });
  adminApi.getRecentActivities.mockReset().mockResolvedValue({
    data: { items: ACTIVITIES.map((a) => ({ ...a })), pagination: { total: 25, page: 1, limit: 10, totalPages: 3 } },
  });
});

afterEach(() => {
  vi.useRealTimers();
});

describe('Hiển thị', () => {
  it('tải đủ dữ liệu ban đầu; có tiêu đề, tab thời gian mặc định Hôm nay', async () => {
    await renderPage();
    expect(screen.getByRole('heading', { level: 1, name: 'Tổng quan hệ thống' })).toBeInTheDocument();
    expect(within(screen.getByRole('tablist', { name: 'Khoảng thời gian' })).getByRole('tab', { name: 'Hôm nay' })).toHaveAttribute('aria-selected', 'true');
    expect(adminApi.getTotalUsers).toHaveBeenCalled();
    expect(adminApi.getTotalCategories).toHaveBeenCalled();
    expect(adminApi.getSystemHealth).toHaveBeenCalled();
    expect(statsArgs()).toEqual([{ period: 'today' }, { period: 'today' }, { period: 'today' }]);
    expect(adminApi.getRecentActivities).toHaveBeenCalledWith({ page: 1, limit: 10, sort: 'desc' });
    expect(screen.queryByText('Đang tải dữ liệu báo cáo')).not.toBeInTheDocument();
    expect(screen.getByTestId('server-health')).toBeInTheDocument();
  });

  it('bốn thẻ số liệu: tổng người dùng, người dùng mới kèm tăng trưởng, danh mục, độ khả dụng tháng hiện tại kèm chạy liên tục (A1)', async () => {
    await renderPage();
    const card = (label) => screen.getByText(label, { selector: 'div' }).parentElement;
    await waitFor(() => expect(card('Tổng người dùng')).toHaveTextContent('1.248'));
    expect(card('Người dùng mới')).toHaveTextContent('39');
    expect(card('Người dùng mới')).toHaveTextContent('+12% so với kỳ trước');
    expect(card('Tổng danh mục')).toHaveTextContent('42');
    await waitFor(() => expect(card('Độ khả dụng · Tháng 11/2026')).toHaveTextContent('99,98%'));
    expect(card('Độ khả dụng · Tháng 11/2026')).toHaveTextContent('Chạy liên tục 3 ngày');
    expect(within(card('Độ khả dụng · Tháng 11/2026')).getByRole('button', { name: 'Xem chi tiết' })).toBeInTheDocument();
  });

  it('chưa có dữ liệu phiên chạy thì thẻ ghi "Chưa có dữ liệu" (A1)', async () => {
    adminApi.getSystemHealth.mockResolvedValue({ data: { data: { uptime: { runningFormatted: '5 phút', availability: { period: 'month', year: 2026, month: 11, percent: null } } } } });
    await renderPage();
    const card = screen.getByText('Độ khả dụng · Tháng 11/2026', { selector: 'div' }).parentElement;
    await waitFor(() => expect(card).toHaveTextContent('Chưa có dữ liệu'));
    expect(card).toHaveTextContent('Chạy liên tục 5 phút');
  });

  it('hai biểu đồ có trung bình, cao nhất, tổng yêu cầu; rê chuột lên điểm hiện chú thích', async () => {
    await renderPage();
    const login = screen.getByRole('heading', { level: 2, name: 'Đăng nhập' }).closest('section');
    const req = screen.getByRole('heading', { level: 2, name: 'Lưu lượng yêu cầu' }).closest('section');
    await waitFor(() => expect(login).toHaveTextContent('Trung bình 4 · Cao nhất 12'));
    expect(req).toHaveTextContent('Tổng 300');
    fireEvent.mouseEnter(within(login).getAllByTestId('chart-point')[0]);
    expect(within(login).getByText('12 lượt')).toBeInTheDocument();
  });

  it('bảng hoạt động: nhãn phân loại, phương thức, trạng thái, lý do; có liên kết sang Nhật ký', async () => {
    await renderPage();
    const first = screen.getByRole('row', { name: /Đăng nhập/ });
    expect(within(first).getByText('Xác thực')).toHaveAttribute('data-tone', 'info');
    expect(within(first).getByText('POST')).toBeInTheDocument();
    expect(within(first).getByText('Thành công')).toHaveAttribute('data-tone', 'success');
    const second = screen.getByRole('row', { name: /Sai mã PIN/ });
    expect(within(second).getByText('Thất bại')).toHaveAttribute('data-tone', 'danger');
    expect(screen.getByRole('link', { name: 'Xem nhật ký' })).toHaveAttribute('href', '/audit-logs');
  });
});

describe('Bộ lọc thời gian', () => {
  it('chọn tab 7 ngày gửi period 7days cho cả ba thống kê', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('tab', { name: '7 ngày' }));
    await waitFor(() => expect(statsArgs()).toEqual([{ period: '7days' }, { period: '7days' }, { period: '7days' }]));
    expect(screen.getByRole('tab', { name: '7 ngày' })).toHaveAttribute('aria-selected', 'true');
  });

  it('chọn một ngày cụ thể; ngày trong tương lai bị khóa', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('button', { name: 'Chọn thời gian' }));
    const picker = screen.getByRole('dialog', { name: 'Chọn thời gian' });
    expect(within(picker).getByRole('button', { name: '20' })).toBeDisabled();
    fireEvent.click(within(picker).getByRole('button', { name: '5' }));
    await waitFor(() => expect(statsArgs()[1]).toEqual({ customType: 'date', date: '2026-11-05' }));
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: '05/11/2026' })).toBeInTheDocument();
  });

  it('chọn theo tháng và theo năm', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('button', { name: 'Chọn thời gian' }));
    let picker = screen.getByRole('dialog', { name: 'Chọn thời gian' });
    fireEvent.click(within(picker).getByRole('tab', { name: 'Theo tháng' }));
    expect(within(picker).getByRole('button', { name: 'T12' })).toBeDisabled();
    fireEvent.click(within(picker).getByRole('button', { name: 'T10' }));
    await waitFor(() => expect(statsArgs()[2]).toEqual({ customType: 'month', month: 10, year: 2026 }));

    fireEvent.click(screen.getByRole('button', { name: 'Tháng 10/2026' }));
    picker = screen.getByRole('dialog', { name: 'Chọn thời gian' });
    fireEvent.click(within(picker).getByRole('tab', { name: 'Theo năm' }));
    fireEvent.click(within(picker).getByRole('button', { name: '2024' }));
    await waitFor(() => expect(statsArgs()[0]).toEqual({ customType: 'year', year: 2024 }));
  });
});

describe('Phân trang và realtime', () => {
  it('sang trang 2 của bảng hoạt động', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('button', { name: '2' }));
    await waitFor(() => expect(adminApi.getRecentActivities).toHaveBeenLastCalledWith({ page: 2, limit: 10, sort: 'desc' }));
  });

  it('audit_activity chèn hoạt động mới lên đầu bảng', async () => {
    await renderPage();
    emit('audit_activity', { id: 903, user: 'binh', action: '[PAYMENT] Hoàn tiền', request: 'POST /api/admin/payments/refund', status: 'Pass', time_req: '2026-11-12T04:59:00Z' });
    const rows = await screen.findAllByRole('row');
    expect(rows[1]).toHaveTextContent('binh');
  });

  it('admin.metrics_stream cập nhật độ khả dụng và chạy liên tục (A4)', async () => {
    await renderPage();
    emit('admin.metrics_stream', { runningFormatted: '2 giờ', availability: { period: 'month', year: 2026, month: 11, percent: 97.5 } });
    const card = screen.getByText('Độ khả dụng · Tháng 11/2026', { selector: 'div' }).parentElement;
    await waitFor(() => expect(card).toHaveTextContent('97,50%'));
    expect(card).toHaveTextContent('Chạy liên tục 2 giờ');
  });
});

describe('Chi tiết độ khả dụng theo kỳ', () => {
  const AVAIL = (over = {}) => ({
    data: {
      data: {
        period: 'month', year: 2026, month: 11, quarter: null, label: '11/2026', trackingAvailable: true,
        percent: 99.5, measuredSeconds: 432000, coverageFrom: '2026-11-09T17:00:00.000Z',
        plannedMaintenanceSeconds: 1800, emergencyMaintenanceSeconds: 300, unplannedSeconds: 60, plannedStopSeconds: 120,
        buckets: [{ label: '1', start: '2026-10-31T17:00:00.000Z', end: '2026-11-01T17:00:00.000Z', percent: null }, { label: '10', start: 'a', end: 'b', percent: 99.1 }],
        incidents: [{ kind: 'EMERGENCY', start: '2026-11-11T02:00:00.000Z', end: '2026-11-11T02:05:00.000Z', durationSeconds: 300, reason: 'Sửa CSDL' }],
        availableYears: [2026, 2025],
        ...over,
      },
    },
  });

  beforeEach(() => {
    adminApi.getAvailability.mockReset().mockResolvedValue(AVAIL());
  });

  const openDetail = async () => {
    await renderPage();
    const card = screen.getByText('Độ khả dụng · Tháng 11/2026', { selector: 'div' }).parentElement;
    fireEvent.click(await within(card).findByRole('button', { name: 'Xem chi tiết' }));
    return screen.findByRole('dialog', { name: 'Độ khả dụng hệ thống' });
  };

  it('A2. Mở chi tiết: mặc định Tháng hiện tại; chuyển Quý / Năm đổi đúng ô chọn', async () => {
    const dialog = await openDetail();
    const kinds = within(dialog).getByRole('tablist', { name: 'Loại kỳ' });
    expect(within(kinds).getByRole('tab', { name: 'Tháng' })).toHaveAttribute('aria-selected', 'true');
    expect(within(dialog).getByLabelText('Chọn tháng')).toHaveValue('11');
    expect(within(dialog).getByLabelText('Chọn năm')).toHaveValue('2026');

    fireEvent.click(within(kinds).getByRole('tab', { name: 'Quý' }));
    expect(within(dialog).queryByLabelText('Chọn tháng')).not.toBeInTheDocument();
    expect(within(dialog).getByLabelText('Chọn quý')).toHaveValue('4');

    fireEvent.click(within(kinds).getByRole('tab', { name: 'Năm' }));
    expect(within(dialog).queryByLabelText('Chọn quý')).not.toBeInTheDocument();
    expect(within(dialog).getByLabelText('Chọn năm')).toBeInTheDocument();
  });

  it('A3. Gọi API đúng tham số theo kỳ chọn; hiện %, "Dữ liệu từ", chia nhỏ và sự cố', async () => {
    const dialog = await openDetail();
    await waitFor(() => expect(adminApi.getAvailability).toHaveBeenCalledWith({ period: 'month', year: 2026, month: 11 }));
    expect(await within(dialog).findByText('99,50%')).toBeInTheDocument();
    expect(within(dialog).getByText('Dữ liệu từ 10/11/2026')).toBeInTheDocument();
    const line = (label) => within(dialog).getByText(label, { selector: 'span.text-ink-muted' }).parentElement;
    expect(line('Bảo trì có kế hoạch')).toHaveTextContent('30 phút');
    expect(line('Bảo trì khẩn cấp')).toHaveTextContent('5 phút');
    expect(line('Gián đoạn ngoài dự kiến')).toHaveTextContent('1 phút');
    expect(line('Tắt có chủ đích (không trừ)')).toHaveTextContent('2 phút');
    expect(within(dialog).getByRole('row', { name: /Sửa CSDL/ })).toHaveTextContent('09:00 11/11/2026');

    adminApi.getAvailability.mockResolvedValue(AVAIL({ period: 'quarter', quarter: 4, percent: 98.25 }));
    fireEvent.click(within(dialog).getByRole('tab', { name: 'Quý' }));
    fireEvent.change(within(dialog).getByLabelText('Chọn năm'), { target: { value: '2025' } });
    await waitFor(() => expect(adminApi.getAvailability).toHaveBeenLastCalledWith({ period: 'quarter', year: 2025, quarter: 4 }));
    expect(await within(dialog).findByText('98,25%')).toBeInTheDocument();
  });

  it('A3b. Kỳ chưa có dữ liệu thì ghi rõ, không hiện 100%', async () => {
    adminApi.getAvailability.mockResolvedValue(AVAIL({ percent: null, measuredSeconds: 0, coverageFrom: null, incidents: [] }));
    const dialog = await openDetail();
    expect(await within(dialog).findByText('Chưa có dữ liệu cho kỳ này')).toBeInTheDocument();
    expect(within(dialog).queryByText('100,00%')).not.toBeInTheDocument();
  });
});
