// src/Admin-web/src/tests/phase1.i18n.test.jsx
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, act } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { LanguageProvider, useLanguage } from '../store/language.context';
import { SettingsProvider, useSettings } from '../store/settings.context';
import { AlertProvider, useAlert } from '../store/alert.context';
import ConfirmModal from '../components/common/ConfirmModal';
import EmptyState from '../components/common/EmptyState';
import Loading from '../components/common/Loading';
import AlertContainer from '../components/common/AlertToast';
import ServerHealthPanel from '../components/common/ServerHealthPanel';
import SettingsModal from '../components/layout/SettingsModal';
import LockScreenModal from '../components/layout/LockScreenModal';
import LanguageToggle from '../components/common/LanguageToggle';
import adminApi from '../api/admin.api';

// Mock Socket
const mockSocket = {
  connected: true,
  id: 'socket-phase1-test-123',
  on: vi.fn(),
  off: vi.fn(),
  timeout: vi.fn().mockReturnValue({
    emit: vi.fn((event, cb) => cb(null, { pong: true })),
  }),
};

vi.mock('../hooks/useSocket', () => ({
  default: () => mockSocket,
}));

vi.mock('../services/sound.service', () => ({
  default: {
    playCriticalAlarm: vi.fn(),
    playNotificationSound: vi.fn(),
  },
  soundService: {
    playCriticalAlarm: vi.fn(),
    playNotificationSound: vi.fn(),
  },
}));

vi.mock('../store/auth.context', () => ({
  useAuthContext: () => ({
    logout: vi.fn(),
    user: { fullname: 'Quản Trị Viên Trưởng', username: 'superadmin', email: 'admin@finance.local' },
  }),
}));

vi.mock('../api/admin.api', () => ({
  default: {
    getMaintenanceStatus: vi.fn().mockResolvedValue({
      data: { active: false, reason: '', activatedBy: null, activatedAt: null },
    }),
    getSystemHealth: vi.fn().mockResolvedValue({
      data: {
        cpu: { percent: 25 },
        ram: { percent: 40, usedMb: 400, totalMb: 1000 },
        eventLoop: { lagMs: 12, overloaded: false },
        uptime: { uptimeFormatted: '5d 12h', uptimePercent: 99.98, startedAt: '2026-10-01T00:00:00Z', slaWindowDays: 30 },
        dbPool: {
          clientActive: 0,
          clientLimit: 16,
          adminActive: 0,
          adminReserved: 4,
          maxConnections: 20,
        },
        loadShedding: { shedCount24h: 0 },
      },
    }),
    setMaintenanceStatus: vi.fn().mockResolvedValue({ data: { success: true } }),
  },
}));

describe('Admin-web Phase 1 i18n Suite — Shared Components, Modals & Layouts', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
    document.documentElement.removeAttribute('lang');
    document.documentElement.removeAttribute('data-language');
  });

  const renderWithProviders = (ui) => {
    return render(
      <BrowserRouter>
        <LanguageProvider>
          <SettingsProvider>
            <AlertProvider>
              {ui}
            </AlertProvider>
          </SettingsProvider>
        </LanguageProvider>
      </BrowserRouter>
    );
  };

  // ─── 1. CONFIRM MODAL I18N ────────────────────────────────────────────────
  describe('1. ConfirmModal i18n Verification', () => {
    it('1.1. Chuyển đổi chính xác ConfirmModal giữa VI và EN khi dùng default props', () => {
      const TestConfirmWrapper = () => (
        <div>
          <LanguageToggle />
          <ConfirmModal open={true} onConfirm={() => {}} onCancel={() => {}} />
        </div>
      );

      renderWithProviders(<TestConfirmWrapper />);

      // Mặc định VI
      expect(screen.getByRole('heading', { level: 3 })).toHaveTextContent('Xác nhận');
      expect(screen.getByText('Vui lòng xem kỹ thông tin trước khi tiếp tục')).toBeInTheDocument();
      expect(screen.getByText('Hủy bỏ')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Xác nhận/i })).toBeInTheDocument();

      // Đổi sang EN
      fireEvent.click(screen.getByTestId('lang-btn-en'));
      expect(screen.getByRole('heading', { level: 3 })).toHaveTextContent('Confirmation');
      expect(screen.getByText('Please review details carefully before proceeding')).toBeInTheDocument();
      expect(screen.getByText('Cancel')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Confirm/i })).toBeInTheDocument();

      // Đổi lại VI
      fireEvent.click(screen.getByTestId('lang-btn-vi'));
      expect(screen.getByRole('heading', { level: 3 })).toHaveTextContent('Xác nhận');
    });
  });

  // ─── 2. EMPTY STATE & LOADING I18N ───────────────────────────────────────
  describe('2. EmptyState & Loading i18n Verification', () => {
    it('2.1. Chuyển đổi chính xác EmptyState và Loading giữa VI và EN', () => {
      const TestWrapper = () => (
        <div>
          <LanguageToggle />
          <EmptyState />
          <Loading />
        </div>
      );

      renderWithProviders(<TestWrapper />);

      // Mặc định VI
      expect(screen.getByText('Không có dữ liệu')).toBeInTheDocument();
      expect(screen.getByText('Chưa có mục nào để hiển thị.')).toBeInTheDocument();
      expect(screen.getByText('Đang tải dữ liệu...')).toBeInTheDocument();

      // Đổi sang EN
      fireEvent.click(screen.getByTestId('lang-btn-en'));
      expect(screen.getByText('No Data Available')).toBeInTheDocument();
      expect(screen.getByText('There are no items to display.')).toBeInTheDocument();
      expect(screen.getByText('Loading data...')).toBeInTheDocument();

      // Đổi lại VI
      fireEvent.click(screen.getByTestId('lang-btn-vi'));
      expect(screen.getByText('Không có dữ liệu')).toBeInTheDocument();
      expect(screen.getByText('Đang tải dữ liệu...')).toBeInTheDocument();
    });
  });

  // ─── 3. ALERT TOAST I18N ─────────────────────────────────────────────────
  describe('3. AlertToast i18n Verification', () => {
    it('3.1. Chuyển đổi chính xác AlertToast default titles và close tooltip', () => {
      const TestAlertTrigger = () => {
        const alert = useAlert();
        return (
          <div>
            <LanguageToggle />
            <AlertContainer />
            <button
              onClick={() => alert.success('Thao tác hoàn tất')}
              data-testid="trigger-alert-btn"
            >
              Trigger
            </button>
          </div>
        );
      };

      renderWithProviders(<TestAlertTrigger />);

      // Bật thông báo
      fireEvent.click(screen.getByTestId('trigger-alert-btn'));
      expect(screen.getByText('Thành công')).toBeInTheDocument();
      expect(screen.getByTestId('alert-close-btn')).toHaveAttribute('title', 'Đóng thông báo');

      // Đổi sang EN
      fireEvent.click(screen.getByTestId('lang-btn-en'));
      expect(screen.getByText('Success')).toBeInTheDocument();
      expect(screen.getByTestId('alert-close-btn')).toHaveAttribute('title', 'Dismiss notification');
    });
  });

  // ─── 4. SERVER HEALTH PANEL I18N ─────────────────────────────────────────
  describe('4. ServerHealthPanel i18n Verification', () => {
    it('4.1. Chuyển đổi chính xác ServerHealthPanel giữa VI và EN', async () => {
      const TestHealthWrapper = () => (
        <div>
          <LanguageToggle />
          <ServerHealthPanel />
        </div>
      );

      renderWithProviders(<TestHealthWrapper />);

      // Mặc định VI
      expect(await screen.findByText('Sức Khỏe Máy Chủ')).toBeInTheDocument();
      expect(screen.getByText('Bảo trì khẩn cấp')).toBeInTheDocument();
      expect(screen.getByText('Cắt toàn bộ Client, giữ Admin thông luồng')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('Nhập lý do bảo trì trước khi bật...')).toBeInTheDocument();

      // Đổi sang EN
      fireEvent.click(screen.getByTestId('lang-btn-en'));
      expect(screen.getByText('Server Health')).toBeInTheDocument();
      expect(screen.getByText('Emergency Maintenance')).toBeInTheDocument();
      expect(screen.getByText('Cut off all Clients, keep Admin channel open')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('Enter maintenance reason before activating...')).toBeInTheDocument();

      // Đổi lại VI
      fireEvent.click(screen.getByTestId('lang-btn-vi'));
      expect(screen.getByText('Sức Khỏe Máy Chủ')).toBeInTheDocument();
      expect(screen.getByText('Bảo trì khẩn cấp')).toBeInTheDocument();
    });

    it('4.2. Hiển thị đầy đủ DB Pool & Bulkhead với 0/16 và 0/4 không bị khuyết số', async () => {
      adminApi.getSystemHealth.mockResolvedValueOnce({
        data: {
          cpu: { percent: 10 },
          ram: { percent: 20, usedMb: 200, totalMb: 1000 },
          eventLoop: { lagMs: 5, overloaded: false },
          uptime: { uptimeFormatted: '1d', uptimePercent: 99.9, startedAt: '2026-10-01T00:00:00Z', slaWindowDays: 30 },
          dbPool: {
            clientActive: 0,
            clientLimit: 16,
            adminActive: 0,
            maxConnections: 20,
          },
          loadShedding: { shedCount24h: 0 },
        },
      });

      renderWithProviders(<ServerHealthPanel />);

      expect(await screen.findByText('0/16')).toBeInTheDocument();
      expect(screen.getByText('0/4')).toBeInTheDocument();
      expect(screen.getByText('0 lần')).toBeInTheDocument();
    });

    it('4.3. Cập nhật chính xác DB Pool từ Socket nhịp tim activeClientConnections/activeAdminConnections', async () => {
      renderWithProviders(<ServerHealthPanel />);
      expect(await screen.findByText('0/16')).toBeInTheDocument();

      const metricsCall = mockSocket.on.mock.calls.find(call => call[0] === 'admin.metrics_stream');
      const metricsCallback = metricsCall?.[1];
      expect(metricsCallback).toBeDefined();

      await act(async () => {
        metricsCallback({
          cpuPercent: 15,
          ramPercent: 30,
          ramRssMb: 300,
          eventLoopLagMs: 8,
          uptimeSeconds: 3600,
          uptimeFormatted: '0d 1h 0m 0s',
          dbPool: {
            activeClientConnections: 3,
            clientLimit: 16,
            activeAdminConnections: 1,
            adminReserved: 4,
            maxConnections: 20,
          },
        });
      });

      expect(await screen.findByText('3/16')).toBeInTheDocument();
      expect(screen.getByText('1/4')).toBeInTheDocument();
    });
  });

  // ─── 5. SETTINGS MODAL I18N ──────────────────────────────────────────────
  describe('5. SettingsModal i18n Verification', () => {
    it('5.1. Chuyển đổi chính xác SettingsModal tiêu đề, tabs và các nhãn cấu hình', () => {
      const TestSettingsWrapper = () => (
        <div>
          <LanguageToggle />
          <SettingsModal isOpen={true} onClose={() => {}} />
        </div>
      );

      renderWithProviders(<TestSettingsWrapper />);

      // Mặc định VI
      expect(screen.getByText('Cài Đặt Hệ Thống Admin')).toBeInTheDocument();
      expect(screen.getByText('Giao Diện & Hiển Thị')).toBeInTheDocument();
      expect(screen.getByText('Cảnh Báo & Âm Thanh')).toBeInTheDocument();
      expect(screen.getByText('Thời Gian Thực & Socket')).toBeInTheDocument();
      expect(screen.getByText('Bảo Mật & Thông Tin')).toBeInTheDocument();
      expect(screen.getByText('Khôi phục cài đặt gốc')).toBeInTheDocument();
      expect(screen.getByText('Hoàn Tất')).toBeInTheDocument();

      // Đổi sang EN
      fireEvent.click(screen.getByTestId('lang-btn-en'));
      expect(screen.getByText('Admin System Settings')).toBeInTheDocument();
      expect(screen.getByText('Display & Interface')).toBeInTheDocument();
      expect(screen.getByText('Alerts & Audio')).toBeInTheDocument();
      expect(screen.getByText('Realtime & Socket')).toBeInTheDocument();
      expect(screen.getByText('Security & Info')).toBeInTheDocument();
      expect(screen.getByText('Restore Default Settings')).toBeInTheDocument();
      expect(screen.getByText('Done')).toBeInTheDocument();

      // Đổi lại VI
      fireEvent.click(screen.getByTestId('lang-btn-vi'));
      expect(screen.getByText('Cài Đặt Hệ Thống Admin')).toBeInTheDocument();
    });
  });

  // ─── 6. LOCK SCREEN MODAL I18N ───────────────────────────────────────────
  describe('6. LockScreenModal i18n Verification', () => {
    it('6.1. Chuyển đổi chính xác LockScreenModal khi màn hình bị khóa', () => {
      const TestLockWrapper = () => {
        const { lockScreen } = useSettings();
        return (
          <div>
            <LanguageToggle />
            <button onClick={lockScreen} data-testid="lock-btn">Khóa</button>
            <LockScreenModal />
          </div>
        );
      };

      renderWithProviders(<TestLockWrapper />);

      // Khóa màn hình
      fireEvent.click(screen.getByTestId('lock-btn'));

      // Mặc định VI
      expect(screen.getByText('Nhập mật khẩu quản trị viên để mở khóa:')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('Mật khẩu quản trị viên...')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Mở Khóa Màn Hình/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Đăng xuất/i })).toBeInTheDocument();

      // Đổi sang EN
      fireEvent.click(screen.getByTestId('lang-btn-en'));
      expect(screen.getByText('Enter administrator password to unlock:')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('Administrator password...')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Unlock Screen/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Logout/i })).toBeInTheDocument();

      // Đổi lại VI
      fireEvent.click(screen.getByTestId('lang-btn-vi'));
      expect(screen.getByText('Nhập mật khẩu quản trị viên để mở khóa:')).toBeInTheDocument();
    });
  });
});
