import React from 'react';
import { render, screen, fireEvent, waitFor, act, within } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import AppLayout from '../components/layout/AppLayout';
import aiopsApi from '../api/aiops.api';
import adminApi from '../api/admin.api';
import notificationApi from '../api/notification.api';

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

const logout = vi.fn();

vi.mock('../hooks/useSocket', () => ({ default: () => fakeSocket }));
vi.mock('../store/socket.context', () => ({
  useSocketContext: () => ({ socket: fakeSocket, connected: true }),
  SocketContext: React.createContext(null),
}));
vi.mock('../store/auth.context', () => ({
  useAuthContext: () => ({ logout, user: { username: 'admin.local' } }),
}));
vi.mock('../api/aiops.api', () => ({ default: { getStatus: vi.fn() } }));
vi.mock('../api/admin.api', () => ({
  default: { getMaintenanceStatus: vi.fn(), setMaintenanceStatus: vi.fn(), verifySecurityAction: vi.fn() },
}));
vi.mock('../api/notification.api', () => ({
  default: { getAdminAlerts: vi.fn(), markAdminAlertAsRead: vi.fn() },
}));
vi.mock('../components/layout/LockScreenModal', () => ({ default: () => null }));
vi.mock('../components/layout/FirstLoginModal', () => ({ default: () => null }));
vi.mock('../components/layout/SettingsModal', () => ({
  default: ({ isOpen }) => (isOpen ? <div role="dialog" aria-label="Cài đặt" /> : null),
}));

const NAV = [
  ['/dashboard', 'Bảng điều khiển'],
  ['/aiops', 'AIOps Sentinel'],
  ['/users', 'Quản lý người dùng'],
  ['/permissions', 'Phân quyền dịch vụ'],
  ['/payments', 'Lịch sử thanh toán'],
  ['/categories', 'Quản lý danh mục'],
  ['/audit-logs', 'Nhật ký kiểm toán'],
  ['/broadcast', 'Bảo trì & Thông báo'],
];

const renderLayout = (path = '/users') =>
  render(
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route element={<AppLayout />}>
          {NAV.map(([p]) => (
            <Route key={p} path={p} element={<div>trang {p}</div>} />
          ))}
        </Route>
        <Route path="/login" element={<div>trang đăng nhập</div>} />
      </Routes>
    </MemoryRouter>
  );

afterEach(() => vi.unstubAllEnvs());

beforeEach(() => {
  // Các nhóm test dưới đây mô tả AIOps khi BẬT; nhóm "AIOps tạm dừng" tự đặt lại công tắc = tắt.
  vi.stubEnv('VITE_AIOPS_ENABLED', 'true');
  Object.keys(handlers).forEach((k) => delete handlers[k]);
  localStorage.clear();
  logout.mockReset().mockResolvedValue();
  aiopsApi.getStatus.mockReset().mockResolvedValue({ data: { recommendedAction: 'NONE', vectorScores: { resource: 10 } } });
  adminApi.getMaintenanceStatus.mockReset().mockResolvedValue({ data: { active: false } });
  adminApi.setMaintenanceStatus.mockReset().mockResolvedValue({ success: true });
  notificationApi.getAdminAlerts.mockReset().mockResolvedValue({
    data: {
      notifications: [
        { id: 11, title: 'Đơn hoàn tiền mới', message: 'Có yêu cầu hoàn tiền', level: 'info', isRead: false, createdAt: '2026-11-12T10:00:00Z' },
        { id: 12, title: 'Đã xử lý', message: 'Cũ', level: 'warning', isRead: true, createdAt: '2026-11-11T10:00:00Z' },
      ],
      unreadCount: 1,
    },
  });
  notificationApi.markAdminAlertAsRead.mockReset().mockResolvedValue({ success: true });
});

describe('Sidebar', () => {
  it('có đủ 8 mục menu đúng đường dẫn, mục đang mở có aria-current', async () => {
    renderLayout('/users');
    const nav = screen.getByRole('navigation', { name: 'Menu chính' });
    NAV.forEach(([path, label]) => {
      expect(within(nav).getByRole('link', { name: label })).toHaveAttribute('href', path);
    });
    expect(within(nav).getByRole('link', { name: 'Quản lý người dùng' })).toHaveAttribute('aria-current', 'page');
    await waitFor(() => expect(notificationApi.getAdminAlerts).toHaveBeenCalled());
  });

  it('thanh bên không còn nút Thu gọn menu; thu gọn bằng nút menu trên đầu trang, nhớ lựa chọn, giữ tên truy cập của liên kết', async () => {
    renderLayout();
    expect(screen.queryByRole('button', { name: 'Thu gọn menu' })).not.toBeInTheDocument();
    expect(screen.queryByText('Thu gọn menu')).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Mở/đóng menu' }));
    expect(localStorage.getItem('admin_sidebar_collapsed')).toBe('true');
    expect(screen.queryByRole('button', { name: 'Mở rộng menu' })).not.toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Quản lý người dùng' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Đăng xuất' })).toBeInTheDocument();
    await waitFor(() => expect(notificationApi.getAdminAlerts).toHaveBeenCalled());
  });

  it('trên điện thoại: menu đóng khi tải, nút menu mở ra mà không đổi lựa chọn thu gọn của máy tính, chọn mục thì đóng lại', async () => {
    const original = window.matchMedia;
    window.matchMedia = (query) => ({
      matches: query.includes('max-width'),
      media: query,
      addEventListener: () => {},
      removeEventListener: () => {},
      addListener: () => {},
      removeListener: () => {},
    });
    try {
      const { container } = renderLayout('/users');
      const aside = container.querySelector('aside');
      expect(aside).toHaveAttribute('data-mobile-open', 'false');
      fireEvent.click(screen.getByRole('button', { name: 'Mở/đóng menu' }));
      expect(aside).toHaveAttribute('data-mobile-open', 'true');
      expect(localStorage.getItem('admin_sidebar_collapsed')).toBeNull();
      fireEvent.click(screen.getByRole('link', { name: 'Nhật ký kiểm toán' }));
      expect(aside).toHaveAttribute('data-mobile-open', 'false');
      expect(await screen.findByText('trang /audit-logs')).toBeInTheDocument();
    } finally {
      window.matchMedia = original;
    }
  });

  it('đăng xuất gọi logout rồi về trang đăng nhập', async () => {
    renderLayout();
    fireEvent.click(screen.getByRole('button', { name: 'Đăng xuất' }));
    await waitFor(() => expect(logout).toHaveBeenCalledTimes(1));
    expect(await screen.findByText('trang đăng nhập')).toBeInTheDocument();
  });
});

describe('Header', () => {
  it('có nút mở/đóng menu, trạng thái kết nối, tên quản trị viên và nút cài đặt', async () => {
    renderLayout();
    expect(screen.getByRole('button', { name: 'Mở/đóng menu' })).toBeInTheDocument();
    expect(screen.getByTestId('realtime-status-badge')).toHaveAttribute('data-status', 'connected');
    expect(screen.getByText('admin.local')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Cài đặt' }));
    expect(screen.getByRole('dialog', { name: 'Cài đặt' })).toBeInTheDocument();
    await waitFor(() => expect(notificationApi.getAdminAlerts).toHaveBeenCalled());
  });

  it('tải cảnh báo khi mở trang, hiện số chưa đọc; bấm cảnh báo chưa đọc thì đánh dấu đã đọc', async () => {
    renderLayout();
    await waitFor(() => expect(notificationApi.getAdminAlerts).toHaveBeenCalledWith({ page: 1, limit: 10 }));
    const bell = screen.getByRole('button', { name: /Thông báo/ });
    expect(bell).toHaveTextContent('1');
    fireEvent.click(bell);
    const item = await screen.findByRole('button', { name: /Đơn hoàn tiền mới/ });
    fireEvent.click(item);
    await waitFor(() => expect(notificationApi.markAdminAlertAsRead).toHaveBeenCalledWith(11));
    await waitFor(() => expect(bell).not.toHaveTextContent('1'));
    fireEvent.click(screen.getByRole('button', { name: /Đã xử lý/ }));
    expect(notificationApi.markAdminAlertAsRead).toHaveBeenCalledTimes(1);
  });

  it('sự kiện admin.notification thêm cảnh báo mới và tăng số chưa đọc', async () => {
    renderLayout();
    await waitFor(() => expect(notificationApi.getAdminAlerts).toHaveBeenCalled());
    const bell = screen.getByRole('button', { name: /Thông báo/ });
    await waitFor(() => expect(bell).toHaveTextContent('1'));
    emit('admin.notification', { id: 99, title: 'Người dùng mới', message: 'Vừa đăng ký', level: 'info', isRead: false });
    expect(bell).toHaveTextContent('2');
    notificationApi.getAdminAlerts.mockImplementationOnce(() => new Promise(() => {}));
    fireEvent.click(bell);
    expect(screen.getByRole('button', { name: /Người dùng mới/ })).toBeInTheDocument();
  });
});

describe('Banner bảo trì và báo động', () => {
  it('admin.maintenance_changed bật/tắt banner bảo trì và báo đã kết thúc bảo trì', async () => {
    renderLayout();
    await waitFor(() => expect(adminApi.getMaintenanceStatus).toHaveBeenCalled());
    emit('admin.maintenance_changed', { active: true, reason: 'Nâng cấp CSDL', activatedBy: 'admin2' });
    const banner = screen.getByRole('region', { name: 'Hệ thống đang bảo trì' });
    expect(banner).toHaveTextContent('Nâng cấp CSDL');
    expect(within(banner).getByRole('link', { name: 'Quản lý bảo trì' })).toHaveAttribute('href', '/broadcast');
    emit('admin.maintenance_changed', { active: false });
    expect(screen.queryByRole('region', { name: 'Hệ thống đang bảo trì' })).not.toBeInTheDocument();
    expect(screen.getByText('Đã kết thúc bảo trì')).toBeInTheDocument();
  });

  it('máy chủ nguy cơ quá tải: hiện báo động; bật bảo trì khẩn cấp bắt buộc PIN, PIN gửi kèm lệnh', async () => {
    aiopsApi.getStatus.mockResolvedValue({ data: { recommendedAction: 'EMERGENCY_MAINTENANCE', vectorScores: { resource: 92 } } });
    renderLayout();
    const alertBox = await screen.findByRole('alert');
    expect(alertBox).toHaveTextContent('92/100');
    fireEvent.click(within(alertBox).getByRole('button', { name: 'Bật bảo trì khẩn cấp' }));
    expect(adminApi.setMaintenanceStatus).not.toHaveBeenCalled();
    const dialog = screen.getByRole('dialog', { name: 'Bật bảo trì khẩn cấp?' });
    expect(within(dialog).getByRole('button', { name: 'Bật bảo trì' })).toBeDisabled();
    fireEvent.change(within(dialog).getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Bật bảo trì' }));
    await waitFor(() =>
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith({ active: true, reason: expect.any(String), isEmergency: true, pin: '246810' })
    );
    expect(await screen.findByText('Đã bật bảo trì khẩn cấp')).toBeInTheDocument();
  });

  it('ẩn báo động bằng nút Ẩn cảnh báo', async () => {
    aiopsApi.getStatus.mockResolvedValue({ data: { recommendedAction: 'EMERGENCY_MAINTENANCE', vectorScores: { resource: 92 } } });
    renderLayout();
    const alertBox = await screen.findByRole('alert');
    fireEvent.click(within(alertBox).getByRole('button', { name: 'Ẩn cảnh báo' }));
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  });

  it('admin.security_blocked hiện thông báo IP đã bị chặn và liên kết tới danh sách cách ly', async () => {
    renderLayout();
    await waitFor(() => expect(adminApi.getMaintenanceStatus).toHaveBeenCalled());
    emit('admin.security_blocked', { maskedIp: '10.0.*.*', reason: 'Dò mật khẩu' });
    expect(screen.getByText(/10\.0\.\*\.\*/)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Xem danh sách cách ly' })).toHaveAttribute('href', '/aiops');
  });
});

// Đặc tả: docs/Admin-web/09-aiops-sentinel-and-quarantine.md, mục "Trạng thái: tạm dừng" (2026-11-17).
// VITE_AIOPS_ENABLED khác 'true' ⇒ AIOps ẩn hoàn toàn khỏi Admin-web.
describe('AIOps tạm dừng (VITE_AIOPS_ENABLED khác true)', () => {
  beforeEach(() => vi.stubEnv('VITE_AIOPS_ENABLED', ''));

  it('menu không còn mục AIOps, 7 mục còn lại giữ nguyên', async () => {
    renderLayout('/users');
    const nav = screen.getByRole('navigation', { name: 'Menu chính' });
    expect(within(nav).queryByRole('link', { name: 'AIOps Sentinel' })).not.toBeInTheDocument();
    NAV.filter(([p]) => p !== '/aiops').forEach(([path, label]) => {
      expect(within(nav).getByRole('link', { name: label })).toHaveAttribute('href', path);
    });
    await waitFor(() => expect(notificationApi.getAdminAlerts).toHaveBeenCalled());
  });

  it('không gọi trạng thái AIOps, không đăng ký sự kiện socket AIOps, không hiện báo động', async () => {
    aiopsApi.getStatus.mockResolvedValue({ data: { recommendedAction: 'EMERGENCY_MAINTENANCE', vectorScores: { resource: 92 } } });
    renderLayout();
    await waitFor(() => expect(adminApi.getMaintenanceStatus).toHaveBeenCalled());
    await waitFor(() => expect(notificationApi.getAdminAlerts).toHaveBeenCalled());
    expect(aiopsApi.getStatus).not.toHaveBeenCalled();
    expect(handlers['admin.security_alert']?.size || 0).toBe(0);
    expect(handlers['admin.security_blocked']?.size || 0).toBe(0);
    emit('admin.security_alert', { status: 'CRITICAL', threatScore: 95, recommendedAction: 'EMERGENCY_MAINTENANCE', vectorScores: { resource: 95 } });
    emit('admin.security_blocked', { maskedIp: '10.0.*.*', reason: 'Dò mật khẩu' });
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Xem danh sách cách ly' })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Thông báo/ })).toHaveTextContent('1');
  });
});
