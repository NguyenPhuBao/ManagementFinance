import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import DashboardPage from '../pages/dashboard/DashboardPage';
import ServerHealthPanel from '../components/common/ServerHealthPanel';
import RealtimeStatusBadge from '../components/common/RealtimeStatusBadge';
import { LanguageProvider } from '../store/language.context';
import { SocketContext } from '../store/socket.context';
import adminApi from '../api/admin.api';

// Mock Socket
const mockSocketListeners = {};
const mockSocket = {
  connected: true,
  id: 'test-admin-socket',
  on: vi.fn((event, callback) => {
    mockSocketListeners[event] = callback;
  }),
  off: vi.fn((event) => {
    delete mockSocketListeners[event];
  }),
  emit: vi.fn(),
};

vi.mock('../hooks/useSocket', () => ({
  default: () => mockSocket,
}));

// Mock adminApi
vi.mock('../api/admin.api', () => ({
  default: {
    getTotalUsers: vi.fn().mockResolvedValue({ data: { total: 1250 } }),
    getTotalCategories: vi.fn().mockResolvedValue({ data: { total: 42 } }),
    getSystemHealth: vi.fn().mockResolvedValue({
      data: {
        cpu: { cores: 8, percent: 35 },
        ram: { usedMb: 2048, totalMb: 8192, percent: 25 },
        eventLoop: { lagMs: 4, overloaded: false },
        dbPool: { clientActive: 2, clientLimit: 16, adminActive: 1, maxConnections: 20 },
        maintenance: { active: false, reason: '', isEmergency: true },
        loadShedding: { shedCount24h: 0 },
        uptime: {
          uptimeSeconds: 3600,
          rawUptimeSeconds: 3600,
          uptimeFormatted: '1 giờ',
          uptimePercent: 100.0,
          slaWindowDays: 30,
        },
      },
    }),
    getUserToTime: vi.fn().mockResolvedValue({ data: { current: 15, previous: 10, growth: 50 } }),
    getLoginStats: vi.fn().mockResolvedValue({
      data: {
        summary: { total: 120, max: 25, avg: 5 },
        timeline: [{ label: '00:00', count: 2 }, { label: '01:00', count: 4 }],
        format: 'hour',
      },
    }),
    getRequestStats: vi.fn().mockResolvedValue({
      data: {
        summary: { total: 4500, max: 320, avg: 187 },
        timeline: [{ label: '00:00', count: 50 }, { label: '01:00', count: 75 }],
        format: 'hour',
      },
    }),
    getRecentActivities: vi.fn().mockResolvedValue({
      data: {
        items: [
          {
            id: 'act-1',
            user: 'Admin Root',
            action: '[AUTH] Đăng nhập hệ thống quản trị với phiên làm việc bảo mật',
            request: 'POST /api/auth/login',
            reason: 'Đăng nhập định kỳ',
            status: 'Pass',
            time: '1 phút trước',
          },
          {
            id: 'act-2',
            user: 'Finance Specialist',
            action: '[CATEGORY] Cập nhật danh mục chi tiêu mua sắm cá nhân hàng ngày',
            request: 'PUT /api/categories/12',
            reason: 'Tối ưu danh mục',
            status: 'Pass',
            time: '5 phút trước',
          },
        ],
        pagination: { total: 2, page: 1, limit: 10, totalPages: 1 },
      },
    }),
    getMaintenanceStatus: vi.fn().mockResolvedValue({
      data: { active: false, reason: '', isEmergency: true },
    }),
    setMaintenanceStatus: vi.fn().mockResolvedValue({
      data: { success: true },
    }),
    verifySecurityAction: vi.fn().mockResolvedValue({
      data: { success: true, message: 'Xác thực thành công' },
    }),
  },
}));

const renderDashboard = (socketOverrides = {}) => {
  const currentSocket = { ...mockSocket, ...socketOverrides };
  return render(
    <MemoryRouter initialEntries={['/dashboard']}>
      <LanguageProvider>
        <SocketContext.Provider value={{ socket: currentSocket, connected: currentSocket.connected }}>
          <DashboardPage />
        </SocketContext.Provider>
      </LanguageProvider>
    </MemoryRouter>
  );
};

const renderServerHealth = (socketOverrides = {}) => {
  const currentSocket = { ...mockSocket, ...socketOverrides };
  return render(
    <MemoryRouter>
      <LanguageProvider>
        <SocketContext.Provider value={{ socket: currentSocket, connected: currentSocket.connected }}>
          <ServerHealthPanel />
        </SocketContext.Provider>
      </LanguageProvider>
    </MemoryRouter>
  );
};

describe('TẦNG 1: Kiểm thử Hiển thị & Thao tác giao diện Dashboard (UI Rendering & Interaction)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockSocket.connected = true;
  });

  it('1.1. Header: Loại bỏ hoàn toàn dòng subtitle và nút Bảo trì khẩn cấp', async () => {
    renderDashboard();

    await waitFor(() => {
      expect(screen.getByText(/Tổng quan hệ thống|Dashboard/i)).toBeInTheDocument();
    });

    // Subtitle cũ tuyệt đối KHÔNG xuất hiện
    expect(
      screen.queryByText(/Dữ liệu tài chính và hoạt động được cập nhật liên tục/i)
    ).not.toBeInTheDocument();

    // Nút Bảo trì khẩn cấp ở Header đã bị loại bỏ
    const emergencyButtons = screen.queryAllByRole('button', { name: /Bảo trì khẩn cấp/i });
    expect(emergencyButtons.length).toBe(0);
  });

  it('1.2. Bảng Hoạt động gần đây: Cột Hành động thu nhỏ 50%, áp dụng table-fixed và tooltip', async () => {
    const { container } = renderDashboard();

    await waitFor(() => {
      expect(screen.getByText('Admin Root')).toBeInTheDocument();
    });

    // Kiểm tra table có class table-fixed
    const table = container.querySelector('table');
    expect(table).toHaveClass('table-fixed');

    // Kiểm tra header cột Hành động có class w-[12%] (thu nhỏ một nửa từ 24%)
    const thAction = container.querySelector('th.w-\\[12\\%\\]');
    expect(thAction).toBeInTheDocument();

    // Kiểm tra nội dung text dài có tooltip title
    const cellsWithTitle = container.querySelectorAll('[title]');
    expect(cellsWithTitle.length).toBeGreaterThan(0);
  });

  it('1.3. Biểu đồ: Biểu đồ Request bỏ nút Live Mode; cả 2 biểu đồ hiển thị Real-time badge', async () => {
    renderDashboard();

    await waitFor(() => {
      expect(screen.getByText('Tần suất đăng nhập')).toBeInTheDocument();
      expect(screen.getByText('Lưu lượng Request')).toBeInTheDocument();
    });

    // Nút "Live Mode" đã được loại bỏ hoàn toàn
    expect(screen.queryByText('Live Mode')).not.toBeInTheDocument();

    // Cả 2 biểu đồ và Bảng đều có RealtimeStatusBadge (tổng cộng ít nhất 3 badge)
    const realtimeBadges = screen.getAllByTestId('realtime-status-badge');
    expect(realtimeBadges.length).toBeGreaterThanOrEqual(3);
  });

  it('1.4. ServerHealthPanel: Bấm toggle khi chưa nhập lý do hiển thị cảnh báo lỗi', async () => {
    renderServerHealth();

    await waitFor(() => {
      expect(screen.getByText(/Bảo trì khẩn cấp/i)).toBeInTheDocument();
    });

    const toggleBtn = screen.getByRole('button', { name: /Bấm để bật bảo trì/i });
    fireEvent.click(toggleBtn);

    // Hiển thị thông báo yêu cầu nhập lý do
    await waitFor(() => {
      expect(screen.getByText(/Vui lòng nhập lý do trước khi kích hoạt bảo trì khẩn cấp!/i)).toBeInTheDocument();
    });
  });
});

describe('TẦNG 2: Kiểm thử Hoạt động thực tế & Tác động hệ thống (Real System Impact)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockSocket.connected = true;
  });

  it('2.1. Bảo mật: Công tắc Bảo trì khẩn cấp bắt buộc xác thực mã PIN trước khi gọi API', async () => {
    renderServerHealth();

    await waitFor(() => {
      expect(screen.getByPlaceholderText(/Nhập lý do bảo trì trước khi bật/i)).toBeInTheDocument();
    });

    // 1. Nhập lý do bảo trì
    const reasonInput = screen.getByPlaceholderText(/Nhập lý do bảo trì trước khi bật/i);
    fireEvent.change(reasonInput, { target: { value: 'Nâng cấp database server khẩn cấp' } });

    // 2. Click công tắc
    const toggleBtn = screen.getByRole('button', { name: /Bấm để bật bảo trì/i });
    fireEvent.click(toggleBtn);

    // 3. Modal xác thực mã PIN hiển thị
    await waitFor(() => {
      expect(screen.getByText(/Xác thực kích hoạt Bảo trì khẩn cấp/i)).toBeInTheDocument();
    });

    // Đảm bảo API setMaintenanceStatus CHƯA được gọi khi chưa qua xác thực PIN
    expect(adminApi.setMaintenanceStatus).not.toHaveBeenCalled();

    // 4. Nhập mã PIN 6 số và submit
    const pinInput = screen.getByPlaceholderText(/Nhập mã PIN/i);
    fireEvent.change(pinInput, { target: { value: '123456' } });

    const submitBtn = screen.getByRole('button', { name: /Xác thực & Thực thi/i });
    fireEvent.click(submitBtn);

    // 5. Xác nhận verifySecurityAction được gọi với mã PIN đúng
    await waitFor(() => {
      expect(adminApi.verifySecurityAction).toHaveBeenCalledWith(
        expect.objectContaining({
          pin: '123456',
          action: 'EMERGENCY_MAINTENANCE',
        })
      );
    });

    // 6. Sau khi xác thực PIN thành công, API setMaintenanceStatus mới thực sự được gọi
    await waitFor(() => {
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith({
        active: true,
        reason: 'Nâng cấp database server khẩn cấp',
        isEmergency: true,
      });
    });
  });

  it('2.2. Realtime Socket Liveness: Badge lập tức chuyển trạng thái sang Mất kết nối khi mất mạng', async () => {
    const { rerender } = render(
      <LanguageProvider>
        <SocketContext.Provider value={{ socket: mockSocket, connected: true }}>
          <RealtimeStatusBadge />
        </SocketContext.Provider>
      </LanguageProvider>
    );

    // Trạng thái ban đầu: Real-time (Connected)
    expect(screen.getByTestId('realtime-status-badge')).toHaveAttribute('data-status', 'connected');
    expect(screen.getByText('Real-time')).toBeInTheDocument();

    // Giả lập sự kiện Socket disconnect
    act(() => {
      if (mockSocketListeners['disconnect']) {
        mockSocketListeners['disconnect']('transport close');
      }
    });

    // Badge BẮT BUỘC đổi trạng thái ngay sang Mất kết nối
    await waitFor(() => {
      const badge = screen.getByTestId('realtime-status-badge');
      expect(badge).toHaveAttribute('data-status', 'disconnected');
      expect(screen.getByText('Mất kết nối')).toBeInTheDocument();
    });

    // Giả lập Socket kết nối lại thành công
    act(() => {
      if (mockSocketListeners['connect']) {
        mockSocketListeners['connect']();
      }
    });

    // Tự động khôi phục về trạng thái Real-time
    await waitFor(() => {
      const badge = screen.getByTestId('realtime-status-badge');
      expect(badge).toHaveAttribute('data-status', 'connected');
      expect(screen.getByText('Real-time')).toBeInTheDocument();
    });
  });

  it('2.3. Đồng bộ Uptime: Luồng admin.metrics_stream cập nhật đồng bộ cho cả Card Uptime và Panel', async () => {
    renderDashboard();

    await waitFor(() => {
      expect(screen.getAllByText(/100.000%/i).length).toBeGreaterThanOrEqual(1);
    });

    // Giả lập luồng nhịp tim metrics_stream phát từ máy chủ Backend
    act(() => {
      if (mockSocketListeners['admin.metrics_stream']) {
        mockSocketListeners['admin.metrics_stream']({
          uptimeFormatted: '2 giờ 15 phút',
          uptimePercent: 99.85,
          uptimeSeconds: 8100,
        });
      }
    });

    // Cả Card Uptime phải nhận giá trị mới đồng bộ với Backend
    await waitFor(() => {
      expect(screen.getAllByText(/99.850%/i).length).toBeGreaterThanOrEqual(1);
      expect(screen.getAllByText(/2 giờ 15 phút/i).length).toBeGreaterThanOrEqual(1);
    });
  });
});
