// src/Admin-web/src/tests/language.system.test.jsx
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, act } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { LanguageProvider, useLanguage } from '../store/language.context';
import LanguageToggle from '../components/common/LanguageToggle';
import Header from '../components/layout/Header';
import Sidebar from '../components/layout/Sidebar';
import SettingsModal from '../components/layout/SettingsModal';
import { SettingsProvider } from '../store/settings.context';
import { AlertProvider } from '../store/alert.context';
import { STORAGE_KEY } from '../locales';

// Mock Socket để phục vụ SettingsModal và Header
const mockSocket = {
  connected: true,
  id: 'socket-test-lang-123',
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
    admin: { name: 'Admin Root', role: 'SUPER_ADMIN' },
  }),
}));

describe('Admin-web Language Switcher 2-Tier Architecture Suite', () => {
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

  // =========================================================================
  // TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN (UI Rendering & Interaction)
  // =========================================================================
  describe('🧱 TẦNG 1: UI Rendering & User Interaction', () => {
    it('1.1. Render LanguageToggle pill dạng [ EN | VI ] với nút VI active mặc định', () => {
      renderWithProviders(<LanguageToggle />);

      const toggleWrapper = screen.getByTestId('language-toggle');
      expect(toggleWrapper).toBeInTheDocument();

      const btnEn = screen.getByTestId('lang-btn-en');
      const btnVi = screen.getByTestId('lang-btn-vi');

      expect(btnEn).toBeInTheDocument();
      expect(btnVi).toBeInTheDocument();
      expect(btnEn).toHaveTextContent('EN');
      expect(btnVi).toHaveTextContent('VI');

      // Mặc định Tiếng Việt active: có class nền xanh bg-blue-600 và text-white
      expect(btnVi).toHaveClass('bg-blue-600');
      expect(btnVi).toHaveClass('text-white');
      expect(btnVi).toHaveAttribute('aria-pressed', 'true');

      // Nút EN inactive
      expect(btnEn).not.toHaveClass('bg-blue-600');
      expect(btnEn).toHaveAttribute('aria-pressed', 'false');
    });

    it('1.2. Hover vào LanguageToggle hiển thị Tooltip "Ngôn ngữ giao diện", unhover thì ẩn', () => {
      renderWithProviders(<LanguageToggle />);

      const toggleWrapper = screen.getByTestId('language-toggle');

      // Ban đầu chưa hover: không có tooltip
      expect(screen.queryByRole('tooltip')).not.toBeInTheDocument();

      // Hover vào
      fireEvent.mouseEnter(toggleWrapper);
      const tooltip = screen.getByRole('tooltip');
      expect(tooltip).toBeInTheDocument();
      expect(tooltip).toHaveTextContent('Ngôn ngữ giao diện');

      // Rời chuột ra (mouse leave)
      fireEvent.mouseLeave(toggleWrapper);
      expect(screen.queryByRole('tooltip')).not.toBeInTheDocument();
    });

    it('1.3. Bấm vào nút EN chuyển đổi trạng thái active sang EN và đổi nội dung tooltip sang Tiếng Anh', () => {
      renderWithProviders(<LanguageToggle />);

      const btnEn = screen.getByTestId('lang-btn-en');
      const btnVi = screen.getByTestId('lang-btn-vi');
      const toggleWrapper = screen.getByTestId('language-toggle');

      // Click EN
      fireEvent.click(btnEn);

      // EN trở thành active
      expect(btnEn).toHaveClass('bg-blue-600');
      expect(btnEn).toHaveAttribute('aria-pressed', 'true');
      expect(btnVi).toHaveAttribute('aria-pressed', 'false');

      // Hover để kiểm tra tooltip đã đổi sang "Interface language"
      fireEvent.mouseEnter(toggleWrapper);
      const tooltip = screen.getByRole('tooltip');
      expect(tooltip).toBeInTheDocument();
      expect(tooltip).toHaveTextContent('Interface language');
    });
  });

  // =========================================================================
  // ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ (Real System Impact Verification)
  // =========================================================================
  describe('⚡ TẦNG 2: Real System Impact & Behavioral Verification', () => {
    it('2.1. Tác động CSDL Cục bộ (Persistence Impact): Lưu vào localStorage và bảo toàn khi tải lại', () => {
      const { unmount } = renderWithProviders(<LanguageToggle />);

      const btnEn = screen.getByTestId('lang-btn-en');
      fireEvent.click(btnEn);

      // Kiểm tra localStorage thực sự được lưu
      expect(localStorage.getItem(STORAGE_KEY)).toBe('en');

      // Unmount và mount lại component (giả lập F5 / Reload trang)
      unmount();

      renderWithProviders(<LanguageToggle />);
      const btnEnRehydrated = screen.getByTestId('lang-btn-en');
      expect(btnEnRehydrated).toHaveAttribute('aria-pressed', 'true');
      expect(btnEnRehydrated).toHaveClass('bg-blue-600');
    });

    it('2.2. Tác động Môi trường Root (Root DOM Impact): Cập nhật document.documentElement lang & data-language', () => {
      renderWithProviders(<LanguageToggle />);

      // Ban đầu là 'vi'
      expect(document.documentElement.getAttribute('lang')).toBe('vi');
      expect(document.documentElement.getAttribute('data-language')).toBe('vi');

      // Chuyển sang 'en'
      const btnEn = screen.getByTestId('lang-btn-en');
      fireEvent.click(btnEn);

      expect(document.documentElement.getAttribute('lang')).toBe('en');
      expect(document.documentElement.getAttribute('data-language')).toBe('en');

      // Chuyển lại về 'vi'
      const btnVi = screen.getByTestId('lang-btn-vi');
      fireEvent.click(btnVi);

      expect(document.documentElement.getAttribute('lang')).toBe('vi');
      expect(document.documentElement.getAttribute('data-language')).toBe('vi');
    });

    it('2.3. Tác động Chuyển ngữ Toàn hệ thống (Layout Impact): Sidebar & Header tự động dịch sang Tiếng Anh khi nhấn EN', () => {
      renderWithProviders(
        <div>
          <Header onToggleSidebar={vi.fn()} isSidebarCollapsed={false} />
          <Sidebar isCollapsed={false} onToggle={vi.fn()} />
        </div>
      );

      // Trạng thái ban đầu: Tiếng Việt
      expect(screen.getByText('Bảng điều khiển')).toBeInTheDocument();
      expect(screen.getByText('Quản lý người dùng')).toBeInTheDocument();
      expect(screen.getByText('Phân quyền gói cước')).toBeInTheDocument();
      expect(screen.getByText('Nhật ký kiểm toán')).toBeInTheDocument();
      expect(screen.getByText('Bảo trì & Thông báo')).toBeInTheDocument();
      expect(screen.getByText('Đăng xuất')).toBeInTheDocument();

      // Bấm nút EN trên Header
      const btnEn = screen.getByTestId('lang-btn-en');
      fireEvent.click(btnEn);

      // Kiểm tra các nhãn chuyển dịch sang Tiếng Anh trên DOM thực tế
      expect(screen.getByText('Dashboard')).toBeInTheDocument();
      expect(screen.getByText('User Management')).toBeInTheDocument();
      expect(screen.getByText('Role Permissions')).toBeInTheDocument();
      expect(screen.getByText('Audit Log')).toBeInTheDocument();
      expect(screen.getByText('Maintenance & Alerts')).toBeInTheDocument();
      expect(screen.getByText('Logout')).toBeInTheDocument();

      // Tiếng Việt không còn xuất hiện
      expect(screen.queryByText('Bảng điều khiển')).not.toBeInTheDocument();
      expect(screen.queryByText('Quản lý người dùng')).not.toBeInTheDocument();
    });

    it('2.4. Đồng bộ 2 Chiều (Two-Way Sync Impact): Thay đổi tại SettingsModal phản ánh tức thì lên LanguageToggle và ngược lại', () => {
      renderWithProviders(
        <div>
          <LanguageToggle />
          <SettingsModal isOpen={true} onClose={vi.fn()} />
        </div>
      );

      // Trong SettingsModal Tab 1: Có khối Cài đặt Ngôn ngữ giao diện
      const modalLangVi = screen.getByTestId('settings-lang-vi');
      const modalLangEn = screen.getByTestId('settings-lang-en');
      const headerBtnEn = screen.getByTestId('lang-btn-en');
      const headerBtnVi = screen.getByTestId('lang-btn-vi');

      // Mặc định VI active trên cả modal và header toggle
      expect(modalLangVi).toHaveClass('bg-primary');
      expect(headerBtnVi).toHaveClass('bg-blue-600');

      // Click chọn EN trong SettingsModal
      fireEvent.click(modalLangEn);

      // Cả hai cùng chuyển sang EN
      expect(modalLangEn).toHaveClass('bg-primary');
      expect(headerBtnEn).toHaveClass('bg-blue-600');
      expect(localStorage.getItem(STORAGE_KEY)).toBe('en');

      // Click chọn VI trên Header LanguageToggle
      fireEvent.click(headerBtnVi);

      // SettingsModal tự động cập nhật về VI
      expect(modalLangVi).toHaveClass('bg-primary');
      expect(headerBtnVi).toHaveClass('bg-blue-600');
      expect(localStorage.getItem(STORAGE_KEY)).toBe('vi');
    });

    it('2.5. Cơ chế Fallback và Parameter Interpolation của hàm t()', () => {
      // Component test dùng hook trực tiếp
      const TestConsumer = () => {
        const { t, changeLanguage } = useLanguage();
        return (
          <div>
            <div data-testid="greeting">{t('common.pagination.itemsPerPage')}</div>
            <div data-testid="fallback-test">{t('untranslated.key.that.does.not.exist')}</div>
            <button onClick={() => changeLanguage('en')} data-testid="switch-en">Switch</button>
          </div>
        );
      };

      renderWithProviders(<TestConsumer />);

      expect(screen.getByTestId('greeting')).toHaveTextContent('dòng / trang');

      // Key không tồn tại trả về chính key
      expect(screen.getByTestId('fallback-test')).toHaveTextContent('untranslated.key.that.does.not.exist');

      // Chuyển sang EN
      fireEvent.click(screen.getByTestId('switch-en'));
      expect(screen.getByTestId('greeting')).toHaveTextContent('rows / page');
    });

    it('2.6. Tác động Chuyển ngữ Toàn trang Dashboard & Shared Components (Dashboard & UI Elements)', () => {
      const DashboardPreview = () => {
        const { t } = useLanguage();
        return (
          <div>
            <LanguageToggle />
            <h1 data-testid="dash-title">{t('dashboard.title')}</h1>
            <p data-testid="dash-sub">{t('dashboard.subtitle')}</p>
            <span data-testid="kpi-users">{t('dashboard.kpi.totalUsers')}</span>
            <span data-testid="kpi-cat">{t('dashboard.kpi.totalCategories')}</span>
            <button data-testid="btn-refresh">{t('common.refresh')}</button>
          </div>
        );
      };

      renderWithProviders(<DashboardPreview />);

      // Trạng thái ban đầu: Tiếng Việt
      expect(screen.getByTestId('dash-title')).toHaveTextContent('Tổng quan hệ thống');
      expect(screen.getByTestId('dash-sub')).toHaveTextContent('Dữ liệu tài chính và hoạt động được cập nhật liên tục');
      expect(screen.getByTestId('kpi-users')).toHaveTextContent('Tổng người dùng');
      expect(screen.getByTestId('kpi-cat')).toHaveTextContent('Tổng danh mục');
      expect(screen.getByTestId('btn-refresh')).toHaveTextContent('Làm mới');

      // Bấm chuyển sang EN
      fireEvent.click(screen.getByTestId('lang-btn-en'));

      // Tác động hệ thống: Toàn bộ Dashboard và Shared components chuyển sang Tiếng Anh
      expect(screen.getByTestId('dash-title')).toHaveTextContent('System Overview');
      expect(screen.getByTestId('dash-sub')).toHaveTextContent('Financial data and activities are continuously updated');
      expect(screen.getByTestId('kpi-users')).toHaveTextContent('Total Users');
      expect(screen.getByTestId('kpi-cat')).toHaveTextContent('Total Categories');
      expect(screen.getByTestId('btn-refresh')).toHaveTextContent('Refresh');

      // Chuyển lại về VI: Khôi phục chính xác
      fireEvent.click(screen.getByTestId('lang-btn-vi'));
      expect(screen.getByTestId('dash-title')).toHaveTextContent('Tổng quan hệ thống');
      expect(screen.getByTestId('kpi-users')).toHaveTextContent('Tổng người dùng');
    });

    it('2.7. Tác động Chuyển ngữ Toàn trang Quản lý Dữ liệu (Users, Categories, Permissions)', () => {
      const DataPagesPreview = () => {
        const { t } = useLanguage();
        return (
          <div>
            <LanguageToggle />
            <div data-testid="users-title">{t('users.title')}</div>
            <div data-testid="users-sub">{t('users.subtitle')}</div>
            <div data-testid="cat-title">{t('categories.title')}</div>
            <div data-testid="cat-add">{t('categories.addCategory')}</div>
            <div data-testid="perm-title">{t('permissions.title')}</div>
            <div data-testid="perm-save">{t('permissions.saveBtn')}</div>
          </div>
        );
      };

      renderWithProviders(<DataPagesPreview />);

      // Tiếng Việt
      expect(screen.getByTestId('users-title')).toHaveTextContent('Quản lý người dùng');
      expect(screen.getByTestId('cat-title')).toHaveTextContent('Quản lý danh mục hệ thống');
      expect(screen.getByTestId('cat-add')).toHaveTextContent('Thêm danh mục mới');
      expect(screen.getByTestId('perm-title')).toHaveTextContent('Phân Quyền Gói Cước');
      expect(screen.getByTestId('perm-save')).toHaveTextContent('Lưu Thay Đổi');

      // Chuyển sang EN
      fireEvent.click(screen.getByTestId('lang-btn-en'));

      // Tiếng Anh chuẩn doanh nghiệp
      expect(screen.getByTestId('users-title')).toHaveTextContent('User Management');
      expect(screen.getByTestId('cat-title')).toHaveTextContent('System Category Management');
      expect(screen.getByTestId('cat-add')).toHaveTextContent('Add New Category');
      expect(screen.getByTestId('perm-title')).toHaveTextContent('Plan Permissions — Dynamic Matrix & Real-Time Sync');
      expect(screen.getByTestId('perm-save')).toHaveTextContent('Save Changes');
    });

    it('2.8. Tác động Chuyển ngữ Toàn trang Vận hành & Hệ thống (Audit Logs, Broadcast, AIOps, Auth)', () => {
      const SystemPagesPreview = () => {
        const { t } = useLanguage();
        return (
          <div>
            <LanguageToggle />
            <div data-testid="audit-title">{t('auditLogs.title')}</div>
            <div data-testid="broadcast-title">{t('broadcast.title')}</div>
            <div data-testid="broadcast-maint">{t('broadcast.tabMaintenance')}</div>
            <div data-testid="aiops-threat">{t('aiops.threatScoreTitle')}</div>
            <div data-testid="aiops-status">{t('aiops.statusNormal')}</div>
            <div data-testid="auth-login-title">{t('auth.login.title')}</div>
            <div data-testid="auth-login-submit">{t('auth.login.submitBtn')}</div>
          </div>
        );
      };

      renderWithProviders(<SystemPagesPreview />);

      // Tiếng Việt
      expect(screen.getByTestId('audit-title')).toHaveTextContent('Nhật Ký Hoạt Động');
      expect(screen.getByTestId('broadcast-title')).toHaveTextContent('Điều Hành Bảo Trì & Phát Sóng Thông Báo');
      expect(screen.getByTestId('broadcast-maint')).toHaveTextContent('Điều Hành Bảo Trì');
      expect(screen.getByTestId('aiops-threat')).toHaveTextContent('Hệ Số Đe Dọa (Threat Score)');
      expect(screen.getByTestId('aiops-status')).toHaveTextContent('BÌNH THƯỜNG (NORMAL)');
      expect(screen.getByTestId('auth-login-title')).toHaveTextContent('Đăng nhập hệ thống');
      expect(screen.getByTestId('auth-login-submit')).toHaveTextContent('Đăng nhập');

      // Chuyển sang EN
      fireEvent.click(screen.getByTestId('lang-btn-en'));

      // Tiếng Anh
      expect(screen.getByTestId('audit-title')).toHaveTextContent('Audit Logs');
      expect(screen.getByTestId('broadcast-title')).toHaveTextContent('Maintenance & System Broadcast');
      expect(screen.getByTestId('broadcast-maint')).toHaveTextContent('Maintenance Management');
      expect(screen.getByTestId('aiops-threat')).toHaveTextContent('Threat Score');
      expect(screen.getByTestId('aiops-status')).toHaveTextContent('NORMAL');
      expect(screen.getByTestId('auth-login-title')).toHaveTextContent('Sign In');
      expect(screen.getByTestId('auth-login-submit')).toHaveTextContent('Sign In');
    });
  });
});
