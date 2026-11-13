import React from 'react';
import { render, screen, fireEvent, waitFor, act, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import AIOpsPage from '../pages/system/AIOpsPage';
import ServerHealthPanel from '../components/common/ServerHealthPanel';
import aiopsApi from '../api/aiops.api';
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
vi.mock('../hooks/useAuth', () => ({ default: () => ({ user: { username: 'admin.local' } }) }));
vi.mock('../api/aiops.api', () => ({
  default: {
    getStatus: vi.fn(),
    getHistory: vi.fn(),
    getQuarantineList: vi.fn(),
    getVectorConfig: vi.fn(),
    getIncidents: vi.fn(),
    setScale: vi.fn(),
    calibrate: vi.fn(),
    toggleVector: vi.fn(),
    clearIncidents: vi.fn(),
    quarantineActor: vi.fn(),
    getForensics: vi.fn(),
    temporaryBlockIp: vi.fn(),
    permanentBanIp: vi.fn(),
    unblockIp: vi.fn(),
    temporaryBlockAccount: vi.fn(),
    permanentBanAccount: vi.fn(),
    unblockAccount: vi.fn(),
    revealQuarantineIp: vi.fn(),
  },
}));
vi.mock('../api/admin.api', () => ({
  default: {
    getMaintenanceStatus: vi.fn(),
    setMaintenanceStatus: vi.fn(),
    getSystemHealth: vi.fn(),
    verifySecurityAction: vi.fn(),
  },
}));

const SAMPLE = {
  failedLogins: 2,
  tokenReuseAttacks: 0,
  malformedRequests: 1,
  distinctIpsCount: 7,
  eventLoopLagMs: 12,
  cpuPercent: 42,
  cpuCores: 8,
  ramUsedMb: 2048,
  ramTotalMb: 8192,
  ramPercent: 25,
  requestsPerMin: 300,
  errorRate4xx: 0.02,
  errorRate5xx: 0,
};
const status = (over = {}) => ({
  data: {
    threatScore: 20,
    status: 'NORMAL',
    targetConcurrency: 1000,
    vectorScores: { auth: 10, traffic: 20, exploit: 0, resource: 30 },
    vectorDefenses: {},
    sample: SAMPLE,
    ...over,
  },
});
const HISTORY = [
  { timestamp: '2026-11-13T04:55:00Z', vectorScores: { auth: 10, traffic: 40, exploit: 0, resource: 20 }, threatScore: 40 },
  { timestamp: '2026-11-13T04:58:00Z', vectorScores: { auth: 75, traffic: 30, exploit: 5, resource: 25 }, threatScore: 75 },
];

const renderPage = async () => {
  render(
    <MemoryRouter>
      <AIOpsPage />
    </MemoryRouter>
  );
  await screen.findByRole('heading', { level: 1, name: 'Giám sát an ninh' });
  await waitFor(() => expect(aiopsApi.getStatus).toHaveBeenCalled());
};
const card = (title) => screen.getByRole('heading', { level: 2, name: title }).closest('section');

beforeEach(() => {
  Object.keys(handlers).forEach((k) => delete handlers[k]);
  try { localStorage.clear(); } catch (_) {}
  aiopsApi.getStatus.mockReset().mockResolvedValue(status());
  aiopsApi.getHistory.mockReset().mockResolvedValue({ data: HISTORY });
  aiopsApi.getQuarantineList.mockReset().mockResolvedValue({ data: [] });
  aiopsApi.getVectorConfig.mockReset().mockResolvedValue({ data: { auth: true, traffic: true, exploit: true, resource: true } });
  aiopsApi.getIncidents.mockReset().mockResolvedValue({ data: { incidents: [], total: 0 } });
  aiopsApi.setScale.mockReset().mockResolvedValue({ message: 'ok' });
  aiopsApi.calibrate.mockReset().mockResolvedValue({ data: {} });
  adminApi.getMaintenanceStatus.mockReset().mockResolvedValue({ data: { active: false } });
  adminApi.setMaintenanceStatus.mockReset().mockResolvedValue({});
  adminApi.getSystemHealth.mockReset();
  adminApi.verifySecurityAction.mockReset().mockResolvedValue({ verified: true });
});

describe('AIOps — Tầng 1: hiển thị', () => {
  it('tiêu đề trang, nút Làm mới và Hiệu chuẩn; nút bảo trì khẩn cấp ẩn khi bình thường', async () => {
    await renderPage();
    expect(screen.getByRole('button', { name: 'Làm mới' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Hiệu chuẩn' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Bảo trì khẩn cấp' })).not.toBeInTheDocument();
  });

  it('nút bảo trì khẩn cấp hiện khi rủi ro tài nguyên vượt ngưỡng', async () => {
    aiopsApi.getStatus.mockResolvedValue(status({ recommendedAction: 'EMERGENCY_MAINTENANCE' }));
    await renderPage();
    expect(await screen.findByRole('button', { name: 'Bảo trì khẩn cấp' })).toBeInTheDocument();
  });

  it('quy mô: 4 mức có sẵn, mức hiện tại được chọn; 3 số liệu suy ra từ quy mô', async () => {
    await renderPage();
    const scale = card('Quy mô người dùng');
    await waitFor(() => expect(within(scale).getByRole('button', { name: '1.000' })).toHaveAttribute('aria-pressed', 'true'));
    expect(within(scale).getByRole('button', { name: '500' })).toHaveAttribute('aria-pressed', 'false');
    expect(within(scale).getByText('Lưu lượng nền').parentElement).toHaveTextContent('10.000');
    expect(within(scale).getByText('Trần an toàn').parentElement).toHaveTextContent('30.000');
    expect(within(scale).getByText('Ngưỡng chặn IP').parentElement).toHaveTextContent('170');
  });

  it('chỉ số an ninh và tải máy chủ lấy từ trạng thái', async () => {
    await renderPage();
    const attack = card('Dấu hiệu tấn công');
    await waitFor(() => expect(within(attack).getByText('Số IP khác nhau').parentElement).toHaveTextContent('7'));
    expect(within(attack).getByText('Đăng nhập sai').parentElement).toHaveTextContent('2');
    const load = card('Tải máy chủ');
    expect(within(load).getByText('CPU').parentElement).toHaveTextContent('42%');
    expect(within(load).getByText('RAM').parentElement).toHaveTextContent('2.048 / 8.192 MB');
  });

  it('xu hướng: 5 tab nhóm rủi ro, 5 khoảng thời gian, biểu đồ có dữ liệu; rỗng thì báo', async () => {
    await renderPage();
    const trend = card('Xu hướng rủi ro');
    const tabs = within(trend).getByRole('tablist', { name: 'Nhóm rủi ro' });
    expect(within(tabs).getAllByRole('tab')).toHaveLength(5);
    const range = within(trend).getByRole('group', { name: 'Khoảng thời gian' });
    expect(within(range).getAllByRole('button')).toHaveLength(5);
    expect(within(range).getByRole('button', { name: '10 phút' })).toHaveAttribute('aria-pressed', 'true');
    expect(await within(trend).findByRole('img', { name: 'Xu hướng rủi ro' })).toBeInTheDocument();

    fireEvent.click(within(tabs).getByRole('tab', { name: 'Xác thực' }));
    expect(within(tabs).getByRole('tab', { name: 'Xác thực' })).toHaveAttribute('aria-selected', 'true');
  });

  it('xu hướng rỗng: hiện thông báo và nút về 10 phút', async () => {
    aiopsApi.getHistory.mockResolvedValue({ data: [] });
    await renderPage();
    const trend = card('Xu hướng rủi ro');
    expect(await within(trend).findByText('Chưa có dữ liệu trong khoảng này')).toBeInTheDocument();
  });
});

describe('AIOps — Tầng 2: tác động thật', () => {
  it('chọn mức quy mô và nhập số tùy ý gọi setScale đúng giá trị; số ngoài 100–50.000 không gọi', async () => {
    await renderPage();
    const scale = card('Quy mô người dùng');
    fireEvent.click(within(scale).getByRole('button', { name: '5.000' }));
    await waitFor(() => expect(aiopsApi.setScale).toHaveBeenCalledWith(5000));
    await waitFor(() => expect(within(scale).getByRole('button', { name: '5.000' })).toHaveAttribute('aria-pressed', 'true'));

    const input = within(scale).getByLabelText('Số người dùng đồng thời');
    fireEvent.change(input, { target: { value: '2500' } });
    fireEvent.click(within(scale).getByRole('button', { name: 'Áp dụng' }));
    await waitFor(() => expect(aiopsApi.setScale).toHaveBeenLastCalledWith(2500));

    aiopsApi.setScale.mockClear();
    fireEvent.change(input, { target: { value: '50' } });
    fireEvent.click(within(scale).getByRole('button', { name: 'Áp dụng' }));
    expect(aiopsApi.setScale).not.toHaveBeenCalled();
  });

  it('chọn khoảng 1 giờ tải lại xu hướng và sự cố theo range 1h', async () => {
    await renderPage();
    const range = within(card('Xu hướng rủi ro')).getByRole('group', { name: 'Khoảng thời gian' });
    fireEvent.click(within(range).getByRole('button', { name: '1 giờ' }));
    await waitFor(() => expect(aiopsApi.getHistory).toHaveBeenLastCalledWith({ range: '1h' }));
    expect(aiopsApi.getIncidents.mock.calls.at(-1)[0]).toMatchObject({ range: '1h', page: 1 });
    expect(within(range).getByRole('button', { name: '1 giờ' })).toHaveAttribute('aria-pressed', 'true');
  });

  it('vòng làm mới định kỳ giữ đúng khoảng thời gian đang chọn', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true, toFake: ['setInterval', 'clearInterval'] });
    try {
      await renderPage();
      const range = within(card('Xu hướng rủi ro')).getByRole('group', { name: 'Khoảng thời gian' });
      fireEvent.click(within(range).getByRole('button', { name: '1 giờ' }));
      await waitFor(() => expect(aiopsApi.getHistory).toHaveBeenLastCalledWith({ range: '1h' }));
      const before = aiopsApi.getHistory.mock.calls.length;
      await act(async () => { vi.advanceTimersByTime(3500); });
      await waitFor(() => expect(aiopsApi.getHistory.mock.calls.length).toBeGreaterThan(before));
      expect(aiopsApi.getHistory).toHaveBeenLastCalledWith({ range: '1h' });
    } finally {
      vi.useRealTimers();
    }
  });

  it('lọc khoảng tùy chọn: gửi from / to cho xu hướng và sự cố; Bỏ lọc trả về khoảng có sẵn', async () => {
    await renderPage();
    const trend = card('Xu hướng rủi ro');
    fireEvent.change(within(trend).getByLabelText('Từ'), { target: { value: '2026-11-13T08:00' } });
    fireEvent.change(within(trend).getByLabelText('Đến'), { target: { value: '2026-11-13T10:00' } });
    fireEvent.click(within(trend).getByRole('button', { name: 'Lọc' }));
    await waitFor(() => expect(aiopsApi.getHistory).toHaveBeenLastCalledWith({ from: '2026-11-13T08:00', to: '2026-11-13T10:00' }));
    expect(aiopsApi.getIncidents.mock.calls.at(-1)[0]).toMatchObject({ from: '2026-11-13T08:00', to: '2026-11-13T10:00' });

    fireEvent.click(within(trend).getByRole('button', { name: 'Bỏ lọc' }));
    await waitFor(() => expect(aiopsApi.getHistory).toHaveBeenLastCalledWith({ range: '10m' }));
  });

  it('hiệu chuẩn: ô trống dùng ngưỡng gợi ý, ô đã nhập dùng giá trị nhập', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('button', { name: 'Hiệu chuẩn' }));
    const dialog = await screen.findByRole('dialog', { name: 'Hiệu chuẩn ngưỡng' });
    expect(within(dialog).getByLabelText('Đăng nhập sai (lần/phút)')).toHaveAttribute('placeholder', '25');
    expect(within(dialog).getByLabelText('Lưu lượng đột biến (yêu cầu/giây)')).toHaveAttribute('placeholder', '500');
    fireEvent.change(within(dialog).getByLabelText('CPU (%)'), { target: { value: '90' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Hiệu chuẩn' }));
    await waitFor(() => expect(aiopsApi.calibrate).toHaveBeenCalledWith({
      targetConcurrency: 1000,
      customThresholds: {
        authFailureThreshold: 25,
        trafficSpikeRps: 500,
        exploitLimit: 8,
        resourceCpuPercent: 90,
        resourceMemoryPercent: 85,
        eventLoopLagMs: 100,
      },
    }));
  });

  it('bảo trì khẩn cấp: gửi lý do đã nhập, bật chế độ khẩn cấp', async () => {
    aiopsApi.getStatus.mockResolvedValue(status({ recommendedAction: 'EMERGENCY_MAINTENANCE' }));
    await renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'Bảo trì khẩn cấp' }));
    const dialog = await screen.findByRole('dialog', { name: 'Bật bảo trì khẩn cấp' });
    fireEvent.change(within(dialog).getByLabelText('Lý do'), { target: { value: 'CPU quá tải' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Kích hoạt' }));
    await waitFor(() => expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith({ active: true, reason: 'CPU quá tải', isEmergency: true }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Bật bảo trì khẩn cấp' })).not.toBeInTheDocument());
  });

  it('sự kiện admin.metrics_stream cập nhật chỉ số tải ngay', async () => {
    await renderPage();
    await waitFor(() => expect(within(card('Tải máy chủ')).getByText('CPU').parentElement).toHaveTextContent('42%'));
    emit('admin.metrics_stream', { cpuPercent: 77, ramPercent: 30, eventLoopLagMs: 140, requestsPerMin: 900, threatScore: 10 });
    expect(within(card('Tải máy chủ')).getByText('CPU').parentElement).toHaveTextContent('77%');
    expect(within(card('Tải máy chủ')).getByText('Độ trễ xử lý').parentElement).toHaveTextContent('140');
  });

  it('Làm mới gọi lại trạng thái và sự cố', async () => {
    await renderPage();
    const before = aiopsApi.getStatus.mock.calls.length;
    const beforeInc = aiopsApi.getIncidents.mock.calls.length;
    fireEvent.click(screen.getByRole('button', { name: 'Làm mới' }));
    await waitFor(() => expect(aiopsApi.getStatus.mock.calls.length).toBeGreaterThan(before));
    await waitFor(() => expect(aiopsApi.getIncidents.mock.calls.length).toBeGreaterThan(beforeInc));
  });
});

const INCIDENTS = [
  {
    id: 'i1', code: 'AUTH_BRUTE', vector: 'auth', status: 'ACTIVE', hits: 3, actor_type: 'IP_SOURCE',
    actor_identity: '203.0.xxx.xxx', actor_hash: 'h-203', username: 'an', metric_current: 30, metric_baseline: 10,
    metric_unit: 'lần/phút', message: 'Dò mật khẩu liên tục', mitigation_taken: null, first_detected_at: '2026-11-13T04:00:00Z',
  },
  {
    id: 'i2', code: 'RES_CPU', vector: 'resource', status: 'MITIGATED', hits: 1, actor_type: 'SYSTEM_INTERNAL',
    actor_identity: 'Internal', actor_hash: 'system_core', metric_current: 95, metric_baseline: 85, metric_unit: '%',
    message: 'CPU cao', mitigation_taken: 'Giảm tải', first_detected_at: '2026-11-13T03:00:00Z',
  },
];
const inHours = (h) => new Date(Date.now() + h * 3600e3).toISOString();
const QUARANTINE = () => [
  {
    id: 'q1', hash: 'h-1', ipHash: 'h-1', maskedIp: '203.0.xxx.xxx', username: 'an', idaccount: 5, vector: 'auth',
    ipStatus: 'temporary', accountStatus: 'temporary', reason: 'Dò mật khẩu', bannedAt: '2026-11-13T04:00:00Z',
    ipExpiresAt: inHours(2), accountExpiresAt: inHours(1), hits: 2,
  },
  {
    id: 'q2', hash: 'h-2', ipHash: 'h-2', maskedIp: '198.51.xxx.xxx', username: 'N/A', idaccount: null, vector: 'exploit',
    ipStatus: 'unlocked', accountStatus: 'unlocked', reason: 'Tiêm mã độc', bannedAt: '2026-11-13T03:00:00Z', hits: 1,
  },
];
const rowOf = (section, text) => within(section).getAllByRole('row').find((r) => r.textContent.includes(text));
const withData = () => {
  aiopsApi.getIncidents.mockResolvedValue({ data: { incidents: INCIDENTS, total: 2 } });
  aiopsApi.getQuarantineList.mockResolvedValue({ data: QUARANTINE() });
  aiopsApi.getVectorConfig.mockResolvedValue({ data: { auth: true, traffic: true, exploit: true, resource: false } });
};

describe('AIOps — G4.1c Tầng 1: nhóm rủi ro, sự cố, nguồn bị chặn', () => {
  beforeEach(withData);

  it('4 thẻ nhóm rủi ro có công tắc phòng vệ; nhóm tắt ghi "Chỉ đo, không tự chặn"', async () => {
    await renderPage();
    const vectors = card('Nhóm rủi ro');
    await waitFor(() => expect(within(vectors).getByRole('switch', { name: 'Phòng vệ nhóm Tài nguyên' })).toHaveAttribute('aria-checked', 'false'));
    expect(within(vectors).getAllByRole('switch')).toHaveLength(4);
    expect(within(vectors).getByRole('switch', { name: 'Phòng vệ nhóm Xác thực' })).toHaveAttribute('aria-checked', 'true');
    expect(within(vectors).getByText('Chỉ đo, không tự chặn')).toBeInTheDocument();
    await waitFor(() => expect(within(vectors).getByText('Đang chặn 1 nguồn')).toBeInTheDocument());
  });

  it('bảng sự cố: bộ lọc nhóm / trạng thái, dòng đủ thông tin; sự cố hệ thống không có nút Chặn', async () => {
    await renderPage();
    const incidents = card('Sự cố');
    expect(within(incidents).getByRole('tablist', { name: 'Lọc theo nhóm' })).toBeInTheDocument();
    expect(within(incidents).getByRole('tablist', { name: 'Lọc theo trạng thái' })).toBeInTheDocument();
    await waitFor(() => expect(rowOf(incidents, 'Dò mật khẩu liên tục')).toBeTruthy());
    const r1 = rowOf(incidents, 'Dò mật khẩu liên tục');
    expect(r1).toHaveTextContent('an');
    expect(r1).toHaveTextContent('203.0.xxx.xxx');
    expect(r1).toHaveTextContent('Đang diễn ra');
    expect(r1).toHaveTextContent('Lặp 3 lần');
    expect(r1).toHaveTextContent('Vượt 3 lần');
    expect(within(r1).getByRole('button', { name: 'Chặn' })).toBeInTheDocument();
    const r2 = rowOf(incidents, 'CPU cao');
    expect(r2).toHaveTextContent('Hệ thống');
    expect(r2).toHaveTextContent('Đã giảm thiểu');
    expect(within(r2).queryByRole('button', { name: 'Chặn' })).not.toBeInTheDocument();
  });

  it('bảng nguồn bị chặn: nút theo trạng thái IP / tài khoản, thời gian còn lại, lọc theo IP', async () => {
    await renderPage();
    const q = card('Nguồn bị chặn');
    await waitFor(() => expect(rowOf(q, '203.0.xxx.xxx')).toBeTruthy());
    const r1 = rowOf(q, '203.0.xxx.xxx');
    for (const name of ['Khóa thêm 4 giờ', 'Mở khóa IP', 'Khóa vĩnh viễn', 'Mở khóa tài khoản', 'Xem IP đầy đủ', 'Hồ sơ điều tra']) {
      expect(within(r1).getByRole('button', { name })).toBeInTheDocument();
    }
    expect(r1).toHaveTextContent(/IP: [12] giờ/);
    const r2 = rowOf(q, '198.51.xxx.xxx');
    expect(within(r2).getByRole('button', { name: 'Tạm khóa IP' })).toBeInTheDocument();
    expect(within(r2).queryByRole('button', { name: 'Tạm khóa tài khoản' })).not.toBeInTheDocument();

    fireEvent.change(within(q).getByLabelText('Lọc theo IP'), { target: { value: '198' } });
    expect(rowOf(q, '203.0.xxx.xxx')).toBeUndefined();
    expect(rowOf(q, '198.51.xxx.xxx')).toBeTruthy();
    fireEvent.click(within(q).getByRole('button', { name: 'Xóa lọc' }));
    expect(rowOf(q, '203.0.xxx.xxx')).toBeTruthy();
  });

  it('danh sách rỗng hiện thông báo', async () => {
    aiopsApi.getIncidents.mockResolvedValue({ data: { incidents: [], total: 0 } });
    aiopsApi.getQuarantineList.mockResolvedValue({ data: [] });
    await renderPage();
    expect(await within(card('Sự cố')).findByText('Chưa có sự cố')).toBeInTheDocument();
    expect(within(card('Nguồn bị chặn')).getByText('Chưa có nguồn nào bị chặn')).toBeInTheDocument();
  });
});

describe('AIOps — G4.1c Tầng 2: thao tác gọi đúng API', () => {
  beforeEach(() => {
    withData();
    aiopsApi.toggleVector.mockReset().mockResolvedValue({ data: { vectorConfig: { auth: false, traffic: true, exploit: true, resource: false } } });
    aiopsApi.quarantineActor.mockReset().mockResolvedValue({ data: { hash: 'h-203', maskedIp: '203.0.xxx.xxx' } });
    ['temporaryBlockIp', 'permanentBanIp', 'unblockIp', 'temporaryBlockAccount', 'permanentBanAccount', 'unblockAccount'].forEach((k) => aiopsApi[k].mockReset().mockResolvedValue({}));
    aiopsApi.revealQuarantineIp.mockReset().mockResolvedValue({ data: { data: { ip: '203.0.113.9' } } });
    aiopsApi.getForensics.mockReset().mockResolvedValue({ data: { incidents: [{ id: 77, incident_code: 'INC-77', detected_at: '2026-11-13T04:00:00Z', ip_hash: 'h-1abcdef0123', username: 'an', reason: 'Dò mật khẩu' }], total: 1 } });
  });

  it('tắt phòng vệ một nhóm: hỏi xác nhận rồi gọi toggleVector', async () => {
    await renderPage();
    const vectors = card('Nhóm rủi ro');
    const sw = await within(vectors).findByRole('switch', { name: 'Phòng vệ nhóm Xác thực' });
    fireEvent.click(sw);
    const dialog = await screen.findByRole('dialog', { name: 'Tắt phòng vệ nhóm Xác thực?' });
    expect(aiopsApi.toggleVector).not.toHaveBeenCalled();
    fireEvent.click(within(dialog).getByRole('button', { name: 'Tắt' }));
    await waitFor(() => expect(aiopsApi.toggleVector).toHaveBeenCalledWith('auth', false));
    await waitFor(() => expect(sw).toHaveAttribute('aria-checked', 'false'));
  });

  it('lọc sự cố theo nhóm, trạng thái và từ khóa gửi đúng tham số', async () => {
    await renderPage();
    const incidents = card('Sự cố');
    fireEvent.click(within(within(incidents).getByRole('tablist', { name: 'Lọc theo nhóm' })).getByRole('tab', { name: 'Khai thác' }));
    await waitFor(() => expect(aiopsApi.getIncidents.mock.calls.at(-1)[0]).toMatchObject({ vector: 'exploit', page: 1 }));
    fireEvent.click(within(within(incidents).getByRole('tablist', { name: 'Lọc theo trạng thái' })).getByRole('tab', { name: 'Đang diễn ra' }));
    await waitFor(() => expect(aiopsApi.getIncidents.mock.calls.at(-1)[0]).toMatchObject({ vector: 'exploit', status: 'ACTIVE' }));
    fireEvent.change(within(incidents).getByLabelText('Tìm sự cố'), { target: { value: 'an' } });
    fireEvent.click(within(incidents).getByRole('button', { name: 'Tìm' }));
    await waitFor(() => expect(aiopsApi.getIncidents.mock.calls.at(-1)[0]).toMatchObject({ search: 'an', page: 1 }));
  });

  it('chặn nguồn từ sự cố gửi ipHash của sự cố, không gửi IP đầy đủ', async () => {
    await renderPage();
    const incidents = card('Sự cố');
    await waitFor(() => expect(rowOf(incidents, 'Dò mật khẩu liên tục')).toBeTruthy());
    fireEvent.click(within(rowOf(incidents, 'Dò mật khẩu liên tục')).getByRole('button', { name: 'Chặn' }));
    const dialog = await screen.findByRole('dialog', { name: 'Chặn nguồn 203.0.xxx.xxx?' });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Chặn' }));
    await waitFor(() => expect(aiopsApi.quarantineActor).toHaveBeenCalledWith({
      hash: 'h-203', ip: null, maskedIp: '203.0.xxx.xxx', vector: 'auth', reason: 'Admin quarantine (AUTH_BRUTE)', durationMinutes: 240,
    }));
  });

  it('thao tác IP / tài khoản hỏi xác nhận bằng hộp thoại (không dùng window.confirm) rồi gọi đúng API', async () => {
    const confirmSpy = vi.spyOn(window, 'confirm');
    await renderPage();
    const q = card('Nguồn bị chặn');
    await waitFor(() => expect(rowOf(q, '198.51.xxx.xxx')).toBeTruthy());

    fireEvent.click(within(rowOf(q, '198.51.xxx.xxx')).getByRole('button', { name: 'Tạm khóa IP' }));
    let dialog = await screen.findByRole('dialog', { name: 'Tạm khóa IP 198.51.xxx.xxx?' });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Tạm khóa' }));
    await waitFor(() => expect(aiopsApi.temporaryBlockIp).toHaveBeenCalledWith({ ipHash: 'h-2' }));

    fireEvent.click(within(rowOf(q, '203.0.xxx.xxx')).getByRole('button', { name: 'Mở khóa IP' }));
    dialog = await screen.findByRole('dialog', { name: 'Mở khóa IP 203.0.xxx.xxx?' });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Mở khóa' }));
    await waitFor(() => expect(aiopsApi.unblockIp).toHaveBeenCalledWith({ ipHash: 'h-1' }));

    fireEvent.click(within(rowOf(q, '203.0.xxx.xxx')).getByRole('button', { name: 'Khóa vĩnh viễn' }));
    dialog = await screen.findByRole('dialog', { name: 'Khóa vĩnh viễn tài khoản an?' });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Khóa vĩnh viễn' }));
    await waitFor(() => expect(aiopsApi.permanentBanAccount).toHaveBeenCalledWith({ username: 'an', idaccount: 5 }));

    expect(confirmSpy).not.toHaveBeenCalled();
    confirmSpy.mockRestore();
  });

  it('xem IP đầy đủ phải nhập PIN; IP hiện ngay trong dòng', async () => {
    await renderPage();
    const q = card('Nguồn bị chặn');
    await waitFor(() => expect(rowOf(q, '203.0.xxx.xxx')).toBeTruthy());
    fireEvent.click(within(rowOf(q, '203.0.xxx.xxx')).getByRole('button', { name: 'Xem IP đầy đủ' }));
    const dialog = await screen.findByRole('dialog');
    expect(aiopsApi.revealQuarantineIp).not.toHaveBeenCalled();
    fireEvent.change(within(dialog).getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Xem' }));
    await waitFor(() => expect(aiopsApi.revealQuarantineIp).toHaveBeenCalledWith('h-1', { pin: '246810', password: '' }));
    await waitFor(() => expect(rowOf(q, '203.0.113.9')).toBeTruthy());
  });

  it('hồ sơ điều tra tải theo IP, chuyển sang lọc theo tài khoản', async () => {
    await renderPage();
    const q = card('Nguồn bị chặn');
    await waitFor(() => expect(rowOf(q, '203.0.xxx.xxx')).toBeTruthy());
    fireEvent.click(within(rowOf(q, '203.0.xxx.xxx')).getByRole('button', { name: 'Hồ sơ điều tra' }));
    const dialog = await screen.findByRole('dialog', { name: 'Hồ sơ điều tra' });
    await waitFor(() => expect(aiopsApi.getForensics).toHaveBeenCalledWith({ page: 1, limit: 5, ipHash: 'h-1' }));
    expect(await within(dialog).findByText('INC-77')).toBeInTheDocument();
    fireEvent.click(within(dialog).getByRole('tab', { name: 'Theo tài khoản' }));
    await waitFor(() => expect(aiopsApi.getForensics).toHaveBeenLastCalledWith({ page: 1, limit: 5, username: 'an' }));
  });

  it('tạm khóa thủ công IP và tài khoản gửi đúng thời hạn', async () => {
    await renderPage();
    fireEvent.click(within(card('Nguồn bị chặn')).getByRole('button', { name: 'Tạm khóa thủ công' }));
    let dialog = await screen.findByRole('dialog', { name: 'Tạm khóa thủ công' });
    fireEvent.change(within(dialog).getByLabelText('Địa chỉ IP'), { target: { value: '198.51.100.7' } });
    fireEvent.change(within(dialog).getByLabelText('Thời hạn'), { target: { value: '60' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Tạm khóa' }));
    await waitFor(() => expect(aiopsApi.quarantineActor).toHaveBeenCalledWith(expect.objectContaining({ ip: '198.51.100.7', durationMinutes: 60 })));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Tạm khóa thủ công' })).not.toBeInTheDocument());

    fireEvent.click(within(card('Nguồn bị chặn')).getByRole('button', { name: 'Tạm khóa thủ công' }));
    dialog = await screen.findByRole('dialog', { name: 'Tạm khóa thủ công' });
    fireEvent.click(within(dialog).getByRole('tab', { name: 'Tài khoản' }));
    fireEvent.change(within(dialog).getByLabelText('Tên đăng nhập hoặc mã tài khoản'), { target: { value: 'binh' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Tạm khóa' }));
    await waitFor(() => expect(aiopsApi.temporaryBlockAccount).toHaveBeenCalledWith({ username: 'binh', durationMinutes: 240 }));
  });

  it('sự kiện realtime thêm nguồn bị chặn và sự cố mới vào bảng', async () => {
    await renderPage();
    await waitFor(() => expect(rowOf(card('Nguồn bị chặn'), '203.0.xxx.xxx')).toBeTruthy());
    emit('admin.security_blocked', { hash: 'h-3', maskedIp: '192.0.xxx.xxx', reason: 'Tự chặn', bannedAt: '2026-11-13T05:00:00Z', hits: 1 });
    await waitFor(() => expect(rowOf(card('Nguồn bị chặn'), '192.0.xxx.xxx')).toBeTruthy());
    emit('admin.anomaly_detected', { ...INCIDENTS[0], id: 'i9', message: 'Quét lỗ hổng mới', vector: 'exploit' });
    await waitFor(() => expect(rowOf(card('Sự cố'), 'Quét lỗ hổng mới')).toBeTruthy());
  });
});

describe('Sức khỏe máy chủ (ServerHealthPanel)', () => {
  const HEALTH = {
    data: {
      data: {
        cpu: { percent: 35, cores: 4 },
        ram: { percent: 50, usedMb: 1024, totalMb: 2048 },
        eventLoop: { lagMs: 8 },
        uptime: { uptimePercent: 99.9, uptimeFormatted: '2 ngày' },
        dbPool: { clientActive: 3, clientLimit: 16, adminActive: 1, adminReserved: 4 },
        loadShedding: { shedCount24h: 0 },
      },
    },
  };
  const renderPanel = async () => {
    render(
      <MemoryRouter>
        <ServerHealthPanel />
      </MemoryRouter>
    );
    await screen.findByRole('heading', { name: 'Sức khỏe máy chủ' });
    await waitFor(() => expect(adminApi.getSystemHealth).toHaveBeenCalled());
  };

  beforeEach(() => {
    adminApi.getSystemHealth.mockResolvedValue(HEALTH);
  });

  it('Tầng 1: hiện CPU, RAM, độ trễ, thời gian hoạt động, kết nối CSDL; thiếu lý do thì không bật được', async () => {
    await renderPanel();
    expect(await screen.findByText('CPU')).toBeInTheDocument();
    expect(screen.getByRole('progressbar', { name: 'CPU' })).toHaveAttribute('aria-valuenow', '35');
    expect(screen.getByRole('progressbar', { name: 'RAM' })).toHaveAttribute('aria-valuenow', '50');
    expect(screen.getByText('99.90%')).toBeInTheDocument();
    expect(screen.getByText('3/16')).toBeInTheDocument();

    fireEvent.click(screen.getByRole('switch', { name: 'Bảo trì khẩn cấp' }));
    expect(screen.getByText('Nhập lý do trước khi bật.')).toBeInTheDocument();
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('Tầng 2: nhập lý do, xác thực PIN rồi mới bật bảo trì khẩn cấp', async () => {
    await renderPanel();
    fireEvent.change(screen.getByLabelText('Lý do bảo trì'), { target: { value: 'Nâng cấp CSDL' } });
    fireEvent.click(screen.getByRole('switch', { name: 'Bảo trì khẩn cấp' }));
    const dialog = await screen.findByRole('dialog');
    expect(adminApi.setMaintenanceStatus).not.toHaveBeenCalled();
    fireEvent.change(within(dialog).getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Bật bảo trì' }));
    await waitFor(() => expect(adminApi.verifySecurityAction).toHaveBeenCalledWith(expect.objectContaining({ pin: '246810', action: 'EMERGENCY_MAINTENANCE' })));
    await waitFor(() => expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith({ active: true, reason: 'Nâng cấp CSDL', isEmergency: true }));
  });

  it('Tầng 2: bảo trì đang bật thì công tắc khóa; socket cập nhật CPU', async () => {
    adminApi.getMaintenanceStatus.mockResolvedValue({ data: { active: true, isEmergency: true, reason: 'Sự cố' } });
    await renderPanel();
    await waitFor(() => expect(screen.getByRole('switch', { name: 'Bảo trì khẩn cấp' })).toBeDisabled());
    emit('admin.metrics_stream', { cpuPercent: 91, ramPercent: 50, ramUsedMb: 1024, ramTotalMb: 2048, eventLoopLagMs: 5 });
    expect(screen.getByRole('progressbar', { name: 'CPU' })).toHaveAttribute('aria-valuenow', '91');
  });
});
