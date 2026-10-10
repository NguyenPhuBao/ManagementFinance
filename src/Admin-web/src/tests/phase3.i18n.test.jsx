// src/Admin-web/src/tests/phase3.i18n.test.jsx
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, act } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { LanguageProvider } from '../store/language.context';
import { SettingsProvider } from '../store/settings.context';
import { AlertProvider } from '../store/alert.context';
import LanguageToggle from '../components/common/LanguageToggle';
import AuditLogPage from '../pages/system/AuditLogPage';
import BroadcastPage from '../pages/system/BroadcastPage';
import LoginPage from '../pages/auth/LoginPage';
import ForgotPasswordPage from '../pages/auth/ForgotPasswordPage';
import AIOpsPage from '../pages/system/AIOpsPage';

// Mock Socket
const mockSocket = {
  connected: true,
  id: 'socket-phase3-test-123',
  on: vi.fn(),
  off: vi.fn(),
  emit: vi.fn(),
};

vi.mock('../hooks/useSocket', () => ({
  default: () => mockSocket,
}));

// Mock sound service
vi.mock('../services/sound.service', () => ({
  default: {
    playCriticalAlarm: vi.fn(),
    playNotificationSound: vi.fn(),
  },
}));

// Mock auth context for LoginPage
const mockLogin = vi.fn().mockResolvedValue({ token: 'mock-token' });
vi.mock('../store/auth.context', () => ({
  useAuthContext: () => ({
    login: mockLogin,
    user: null,
    isAuthenticated: false,
  }),
}));

// Mock adminApi
vi.mock('../api/admin.api', () => ({
  default: {
    getAuditLogs: vi.fn().mockResolvedValue({
      data: {
        items: [
          {
            idlog: 1,
            request: 'Đăng nhập hệ thống',
            req_status: 'Pass',
            reason: 'Web Client',
            time_req: '2026-10-09T10:00:00Z',
            time_res: '2026-10-09T10:00:01Z',
            idaccount: 101,
            account: { username: 'admin' },
            ip: '192.168.1.1',
          },
        ],
        total: 1,
      },
    }),
    getMaintenanceStatus: vi.fn().mockResolvedValue({
      data: {
        active: false,
        isEmergency: false,
        reason: '',
        activatedBy: null,
        activatedAt: null,
        scheduled: null,
      },
    }),
    setMaintenanceStatus: vi.fn().mockResolvedValue({
      data: {
        active: true,
        isEmergency: false,
        reason: 'Nâng cấp máy chủ cơ sở dữ liệu định kỳ...',
      },
    }),
    cancelScheduledMaintenance: vi.fn().mockResolvedValue({
      data: {
        active: false,
        scheduled: null,
      },
    }),
  },
}));

// Mock notificationApi
vi.mock('../api/notification.api', () => ({
  default: {
    broadcastToAll: vi.fn().mockResolvedValue({ success: true }),
  },
}));

// Mock aiopsApi
vi.mock('../api/aiops.api', () => ({
  default: {
    getStatus: vi.fn().mockResolvedValue({
      data: {
        status: 'NORMAL',
        threatScore: 15,
        targetConcurrency: 1000,
        vectorScores: { auth: 10, traffic: 12, exploit: 5, resource: 18 },
        vectorDefenses: {},
        sample: { failedLogins: 1, requestsPerMin: 120 },
        anomalies: [],
        vectorConfig: { auth: true, traffic: true, exploit: true, resource: true },
      },
    }),
    getHistory: vi.fn().mockResolvedValue({ data: [] }),
    getQuarantineList: vi.fn().mockResolvedValue({ data: [] }),
    getVectorConfig: vi.fn().mockResolvedValue({
      data: { auth: true, traffic: true, exploit: true, resource: true },
    }),
    getIncidents: vi.fn().mockResolvedValue({ data: { items: [], total: 0 } }),
    setScale: vi.fn().mockResolvedValue({ success: true, message: 'Scale updated' }),
    calibrate: vi.fn().mockResolvedValue({ success: true, message: 'Calibrated' }),
  },
}));

const renderWithProviders = (ui) => {
  return render(
    <MemoryRouter>
      <LanguageProvider>
        <SettingsProvider>
          <AlertProvider>
            <div>
              <LanguageToggle />
              {ui}
            </div>
          </AlertProvider>
        </SettingsProvider>
      </LanguageProvider>
    </MemoryRouter>
  );
};

describe('Admin-web Phase 3 i18n Suite — System & Operations Pages (2-Tier Testing)', () => {
  beforeEach(() => {
    localStorage.clear();
    document.documentElement.removeAttribute('lang');
    document.documentElement.removeAttribute('data-language');
    vi.clearAllMocks();
  });

  // =========================================================================
  // 1. AuditLogPage (Nhật ký hoạt động)
  // =========================================================================
  describe('1. AuditLogPage i18n Verification', () => {
    it('1.1. Tầng 1: Render đầy đủ thanh công cụ, bộ lọc, bảng nhật ký và phân trang', async () => {
      await act(async () => {
        renderWithProviders(<AuditLogPage />);
      });

      // Tầng 1: UI Rendering
      expect(screen.getByText('Nhật Ký Hoạt Động')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('Tìm thao tác hoặc username...')).toBeInTheDocument();
      expect(screen.getByText('Tất cả trạng thái')).toBeInTheDocument();
      expect(screen.getByText('Thao tác (Request)')).toBeInTheDocument();
      expect(screen.getByText('Thời gian gửi')).toBeInTheDocument();
    });

    it('1.2. Tầng 2: Tác động hệ thống khi đổi sang EN — Bảng, tooltip IP, status và dropdown cập nhật đồng bộ', async () => {
      await act(async () => {
        renderWithProviders(<AuditLogPage />);
      });

      // Chuyển sang Tiếng Anh
      const enBtn = screen.getByTestId('lang-btn-en');
      await act(async () => {
        fireEvent.click(enBtn);
      });

      // Tầng 2: Kiểm tra tác động LocalStorage & Root DOM
      expect(localStorage.getItem('admin_language')).toBe('en');
      expect(document.documentElement.getAttribute('lang')).toBe('en');
      expect(document.documentElement.getAttribute('data-language')).toBe('en');

      // Tầng 2: Kiểm tra hiển thị ngôn ngữ mới không còn hardcoded tiếng Việt
      expect(screen.getByText('Audit Logs')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('Search request or username...')).toBeInTheDocument();
      expect(screen.getByText('All statuses')).toBeInTheDocument();
      expect(screen.getByText('Operation (Request)')).toBeInTheDocument();
      expect(screen.getByText('Request Time')).toBeInTheDocument();
    });
  });

  // =========================================================================
  // 2. BroadcastPage (Bảo trì & Phát thông báo)
  // =========================================================================
  describe('2. BroadcastPage i18n Verification', () => {
    it('2.1. Tầng 1: Render đầy đủ Banner, Tabs điều hành, Form tức thì và Form hẹn giờ', async () => {
      await act(async () => {
        renderWithProviders(<BroadcastPage />);
      });

      // Tầng 1: UI Rendering
      expect(screen.getByText('Điều Hành Bảo Trì & Phát Sóng Thông Báo')).toBeInTheDocument();
      expect(screen.getByText('Điều Hành Bảo Trì')).toBeInTheDocument();
      expect(screen.getByText('Phát Thông Báo')).toBeInTheDocument();
      expect(screen.getByText('Kích Hoạt Bảo Trì Tức Thì')).toBeInTheDocument();
      expect(screen.getByText('Lên Lịch Thời Điểm Bảo Trì')).toBeInTheDocument();
    });

    it('2.2. Tầng 2: Chuyển tab sang Phát thông báo và chuyển ngôn ngữ EN — Tiêu đề, mức ưu tiên và preview đổi sang EN', async () => {
      await act(async () => {
        renderWithProviders(<BroadcastPage />);
      });

      // Chuyển sang Tab Broadcast
      const broadcastTab = screen.getByText('Phát Thông Báo');
      await act(async () => {
        fireEvent.click(broadcastTab);
      });

      // Chuyển sang Tiếng Anh
      const enBtn = screen.getByTestId('lang-btn-en');
      await act(async () => {
        fireEvent.click(enBtn);
      });

      // Tầng 2: System Impact
      expect(localStorage.getItem('admin_language')).toBe('en');
      expect(screen.getByText('Maintenance & System Broadcast')).toBeInTheDocument();
      expect(screen.getByText('Notification Priority Level')).toBeInTheDocument();
      expect(screen.getByText('Notification Title')).toBeInTheDocument();
      expect(screen.getByText('Notification Content')).toBeInTheDocument();
      expect(screen.getByText('Broadcast Notification')).toBeInTheDocument();
    });
  });

  // =========================================================================
  // 3. LoginPage (Đăng nhập & Nút chuyển ngữ trực tiếp)
  // =========================================================================
  describe('3. LoginPage i18n Verification', () => {
    it('3.1. Tầng 1: Render đầy đủ thương hiệu, ô email, mật khẩu, nút đăng nhập', async () => {
      await act(async () => {
        renderWithProviders(<LoginPage />);
      });

      // Tầng 1: UI Rendering
      expect(screen.getByText('Đăng nhập hệ thống')).toBeInTheDocument();
      expect(screen.getByText('Email hoặc Tên đăng nhập')).toBeInTheDocument();
      expect(screen.getByText('Mật khẩu')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Đăng nhập/i })).toBeInTheDocument();
    });

    it('3.2. Tầng 2: Click nút switcher EN trực tiếp trên form — Tiêu đề trang, placeholder, footer chuyển ngữ tức thì', async () => {
      await act(async () => {
        renderWithProviders(<LoginPage />);
      });

      // Nút EN trực tiếp trên trang Login
      const enButtons = screen.getAllByRole('button', { name: 'EN' });
      await act(async () => {
        fireEvent.click(enButtons[0]);
      });

      // Tầng 2: System Impact trên LocalStorage & Root DOM
      expect(localStorage.getItem('admin_language')).toBe('en');
      expect(document.documentElement.getAttribute('lang')).toBe('en');

      // Kiểm tra tiêu đề và nhãn đổi sang EN
      expect(screen.getByText('System Sign In')).toBeInTheDocument();
      expect(screen.getByText('Email or Username')).toBeInTheDocument();
      expect(screen.getByText('Password')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Sign In/i })).toBeInTheDocument();
      expect(screen.getByText('Forgot password?')).toBeInTheDocument();
    });
  });

  // =========================================================================
  // 4. ForgotPasswordPage (Quên mật khẩu & Hướng dẫn kỹ thuật)
  // =========================================================================
  describe('4. ForgotPasswordPage i18n Verification', () => {
    it('4.1. Tầng 1: Render hướng dẫn bảo mật, hotline hỗ trợ và nút quay lại', async () => {
      await act(async () => {
        renderWithProviders(<ForgotPasswordPage />);
      });

      // Tầng 1: UI Rendering
      expect(screen.getByText('Quên mật khẩu?')).toBeInTheDocument();
      expect(screen.getByText('+84 355 281 276')).toBeInTheDocument();
      expect(screen.getByText('Quay lại Đăng nhập')).toBeInTheDocument();
    });

    it('4.2. Tầng 2: Click nút switcher EN — Toàn bộ thông điệp cảnh báo và hướng dẫn chuyển sang tiếng Anh', async () => {
      await act(async () => {
        renderWithProviders(<ForgotPasswordPage />);
      });

      // Click nút EN
      const enButtons = screen.getAllByRole('button', { name: 'EN' });
      await act(async () => {
        fireEvent.click(enButtons[0]);
      });

      // Tầng 2: System Impact
      expect(localStorage.getItem('admin_language')).toBe('en');
      expect(screen.getByText('Forgot Password?')).toBeInTheDocument();
      expect(screen.getByText(/For security reasons, Administrator accounts cannot self-reset passwords/i)).toBeInTheDocument();
      expect(screen.getByText('Back to Sign In')).toBeInTheDocument();
    });
  });

  // =========================================================================
  // 5. AIOpsPage (Giám sát máy học & Phòng vệ Sentinel)
  // =========================================================================
  describe('5. AIOpsPage i18n Verification', () => {
    it('5.1. Tầng 1: Render đầy đủ tiêu đề AIOps, Scaler, Gauge, 4 Vectors, Quarantine và RCA Journal', async () => {
      await act(async () => {
        renderWithProviders(<AIOpsPage />);
      });

      // Tầng 1: UI Rendering ở chế độ mặc định (Tiếng Việt)
      expect(screen.getByText(/AIOps Sentinel — Giám Sát Máy Học & Phòng Vệ Tự Động/i)).toBeInTheDocument();
      expect(screen.getByText('Hệ Số Đe Dọa (Threat Score)')).toBeInTheDocument();
      expect(screen.getByText(/Quy Mô Người Dùng Mục Tiêu & Mô Hình Chịu Tải/i)).toBeInTheDocument();
      expect(screen.getByText('Mẫu chọn nhanh:')).toBeInTheDocument();
      expect(screen.getByText('Áp Dụng')).toBeInTheDocument();
      expect(screen.getByText(/4 Vectơ Rủi Ro Độc Lập & Cá Nhân Hóa Phòng Vệ/i)).toBeInTheDocument();
      expect(screen.getByText(/Nguồn Request Đang Bị Cô Lập & Tự Động Chặn/i)).toBeInTheDocument();
      expect(screen.getByText(/Bóc Tách & Phân Tích Nguyên Nhân Bất Thường/i)).toBeInTheDocument();
    });

    it('5.2. Tầng 2: Chuyển đổi sang EN — Toàn bộ 5 khối chức năng AIOps hiển thị 100% tiếng Anh, không lẫn tiếng Việt', async () => {
      await act(async () => {
        renderWithProviders(<AIOpsPage />);
      });

      // Kích hoạt đổi ngôn ngữ sang EN qua nút switcher
      const enBtn = screen.getByTestId('lang-btn-en');
      await act(async () => {
        fireEvent.click(enBtn);
      });

      // Tầng 2: System Impact trên LocalStorage & Root DOM
      expect(localStorage.getItem('admin_language')).toBe('en');
      expect(document.documentElement.getAttribute('lang')).toBe('en');

      // Khối 0: Concurrency Scaler
      expect(screen.getByText(/AIOps Sentinel — Machine Learning Monitoring & Automated Defense/i)).toBeInTheDocument();
      expect(screen.getByText('Target User Concurrency & Capacity Model (Target Concurrency Scaler)')).toBeInTheDocument();
      expect(screen.getByText('Quick presets:')).toBeInTheDocument();
      expect(screen.getByText('1,000 Users (Standard)')).toBeInTheDocument();
      expect(screen.getByText('Expected Baseline RPM')).toBeInTheDocument();
      expect(screen.getByText('Safe Peak Ceiling')).toBeInTheDocument();
      expect(screen.getByText('IP Quarantine Firewall Threshold')).toBeInTheDocument();
      expect(screen.getByText('Apply')).toBeInTheDocument();

      // Khối 1: Threat Score Gauge & Signals
      expect(screen.getByText('Threat Score')).toBeInTheDocument();
      expect(screen.getByText('Intrusion & Attack Signals')).toBeInTheDocument();
      expect(screen.getByText('Failed Logins')).toBeInTheDocument();
      expect(screen.getByText('Revoked Token Reuse')).toBeInTheDocument();
      expect(screen.getByText('System Resilience & Hardware')).toBeInTheDocument();
      expect(screen.getByText('System CPU')).toBeInTheDocument();
      expect(screen.getByText('RAM Memory')).toBeInTheDocument();

      // Khối 1.5: 4 Vector Risk Architecture
      expect(screen.getByText('Multi-Vector Risk Architecture & Granular Defense')).toBeInTheDocument();
      expect(screen.getAllByText('1. Identity & Auth').length).toBeGreaterThanOrEqual(1);
      expect(screen.getAllByText('2. Traffic & DoS').length).toBeGreaterThanOrEqual(1);
      expect(screen.getAllByText('3. Vulnerability Exploit').length).toBeGreaterThanOrEqual(1);
      expect(screen.getAllByText('4. Resource Health').length).toBeGreaterThanOrEqual(1);

      // Khối 2: Active Quarantine Blacklist
      expect(screen.getByText('Active Quarantine Blacklist & Dropped Sources')).toBeInTheDocument();
      expect(screen.getByText('No IP sources currently quarantined')).toBeInTheDocument();

      // Khối 3: SVG Chart & Timeline
      expect(screen.getByText(/Multi-Vector Real-Time Trend Chart/i)).toBeInTheDocument();
      expect(screen.getByText('Observation window preset:')).toBeInTheDocument();
      expect(screen.getByText('Precision date range:')).toBeInTheDocument();
      expect(screen.getByText('Apply Filter')).toBeInTheDocument();

      // Khối 4: Root Cause Analysis (RCA)
      expect(screen.getByText('Root Cause Analysis (RCA) & Incident Journal')).toBeInTheDocument();
      expect(screen.getAllByText('All Vectors').length).toBeGreaterThanOrEqual(1);
      expect(screen.getByText('All Statuses')).toBeInTheDocument();
      expect(screen.getByText('Filter')).toBeInTheDocument();

      // Xác minh tuyệt đối không còn các cụm từ tiếng Việt gốc trên giao diện
      expect(screen.queryByText('Hệ Số Đe Dọa (Threat Score)')).not.toBeInTheDocument();
      expect(screen.queryByText('Mẫu chọn nhanh:')).not.toBeInTheDocument();
      expect(screen.queryByText('4 Vectơ Rủi Ro Độc Lập & Cá Nhân Hóa Phòng Vệ (Multi-Vector Risk Architecture)')).not.toBeInTheDocument();
      expect(screen.queryByText('Nguồn Request Đang Bị Cô Lập & Tự Động Chặn (Active Quarantine Blacklist)')).not.toBeInTheDocument();
      expect(screen.queryByText('Bóc Tách & Phân Tích Nguyên Nhân Bất Thường (Root Cause Analysis - RCA)')).not.toBeInTheDocument();
    });
  });
});
