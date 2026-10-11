// src/Admin-web/src/tests/phase2.i18n.test.jsx
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, act } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { LanguageProvider } from '../store/language.context';
import { SettingsProvider } from '../store/settings.context';
import { AlertProvider } from '../store/alert.context';
import LanguageToggle from '../components/common/LanguageToggle';
import UserDetailPage from '../pages/users/UserDetailPage';
import UserListPage from '../pages/users/UserListPage';
import CategoryPage from '../pages/categories/CategoryPage';
import PermissionManagementPage from '../pages/system/PermissionManagementPage';
import DashboardPage from '../pages/dashboard/DashboardPage';

// Mock Socket
const mockSocket = {
  connected: true,
  id: 'socket-phase2-test-123',
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

// Mock adminApi
vi.mock('../api/admin.api', () => ({
  default: {
    getTotalUsers: vi.fn().mockResolvedValue({ data: { total: 120 } }),
    getTotalCategories: vi.fn().mockResolvedValue({ data: { total: 24 } }),
    getUserToTime: vi.fn().mockResolvedValue({ data: { current: 15, previous: 10, growth: 50 } }),
    getLoginStats: vi.fn().mockResolvedValue({
      data: {
        summary: { total: 350, max: 80, avg: 50 },
        timeline: [{ label: 'T2', value: 30 }, { label: 'T3', value: 45 }],
      },
    }),
    getRequestStats: vi.fn().mockResolvedValue({
      data: {
        summary: { total: 5000, peak: 900, avg: 350 },
        timeline: [{ label: '10:00', value: 120 }, { label: '11:00', value: 150 }],
      },
    }),
    getRecentActivities: vi.fn().mockResolvedValue({
      data: {
        items: [
          { id: 1, user: 'Nguyen Van A', action: 'Đăng nhập hệ thống', reason: 'Web Client', status: 'Pass', time: '10:30' },
        ],
        pagination: { total: 1, page: 1, limit: 5, totalPages: 1 },
      },
    }),
    getSystemHealth: vi.fn().mockResolvedValue({
      data: {
        uptime: { uptimeFormatted: '12 ngày 5 giờ', uptimePercent: 99.98 },
      },
    }),
    getUsers: vi.fn().mockResolvedValue({
      data: [
        {
          id: 101,
          idaccount: 201,
          fullname: 'Nguyen Van A',
          username: 'nguyenvana',
          email: 'vana@gmail.com',
          phone: '0901234567',
          status: 'Active',
          address: 'TP. Hồ Chí Minh',
        },
        {
          id: 102,
          idaccount: 202,
          fullname: 'Tran Thi B',
          username: 'tranthib',
          email: 'thib@gmail.com',
          phone: '0909876543',
          status: 'Inactive',
          address: 'Hà Nội',
        },
      ],
    }),
    getUserById: vi.fn().mockResolvedValue({
      data: {
        id: 101,
        fullname: 'Nguyen Van A',
        username: 'nguyenvana',
        email: 'vana@gmail.com',
        phone: '0901234567',
        status: 'Active',
        address: 'Quận 1, TP. Hồ Chí Minh',
        country_code: '+84',
        rolename: 'Client User',
      },
    }),
    updateUserStatus: vi.fn().mockResolvedValue({ data: { success: true } }),
    deleteUser: vi.fn().mockResolvedValue({ data: { success: true } }),
    getCategories: vi.fn().mockResolvedValue({
      data: [
        {
          id: 1,
          name: 'Ăn uống',
          classify: 'Chi',
          is_default: true,
          is_user_category: false,
          keyword: 'food',
          create_at: '2026-01-01T00:00:00Z',
        },
        {
          id: 2,
          name: 'Lương',
          classify: 'Thu',
          is_default: true,
          is_user_category: false,
          keyword: 'salary',
          create_at: '2026-01-01T00:00:00Z',
        },
      ],
    }),
    createCategory: vi.fn().mockResolvedValue({ data: { success: true } }),
    updateCategory: vi.fn().mockResolvedValue({ data: { success: true } }),
    deleteCategory: vi.fn().mockResolvedValue({ data: { success: true } }),
    getPermissions: vi.fn().mockResolvedValue({
      data: {
        features: [
          { id: 'wallets', name: 'Số lượng ví', type: 'LIMIT', category_group: 'Tài nguyên', description: 'Hạn mức tạo ví' },
          { id: 'ai_assistant', name: 'Trợ lý Gemini AI', type: 'TOGGLE', category_group: 'Trí tuệ nhân tạo', description: 'Tư vấn tài chính AI' },
          { id: 'financial_health_fhs', name: 'Chỉ số sức khỏe FHS', type: 'TOGGLE', category_group: 'Báo cáo & Phân tích', description: 'Đo lường FHS' },
          { id: 'bill_auto_pay', name: 'Tự động thanh toán hóa đơn', type: 'TOGGLE', category_group: 'Tự động hóa & Tiện ích', description: 'Auto-pay' },
        ],
        permissions: {
          Basic: {
            wallets: { is_enabled: true, limit_value: 3 },
            ai_assistant: { is_enabled: false, limit_value: null },
            financial_health_fhs: { is_enabled: true, limit_value: null },
            bill_auto_pay: { is_enabled: false, limit_value: null },
          },
          Premium: {
            wallets: { is_enabled: true, limit_value: null },
            ai_assistant: { is_enabled: true, limit_value: null },
            financial_health_fhs: { is_enabled: true, limit_value: null },
            bill_auto_pay: { is_enabled: true, limit_value: null },
          },
        },
      },
    }),
    updatePermissions: vi.fn().mockResolvedValue({ data: { success: true } }),
  },
}));

describe('Admin-web Phase 2 i18n Suite — Core Business Pages (2-Tier Testing)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
    document.documentElement.removeAttribute('lang');
    document.documentElement.removeAttribute('data-language');
  });

  const renderWithProviders = (ui, initialEntries = ['/']) => {
    return render(
      <MemoryRouter initialEntries={initialEntries}>
        <LanguageProvider>
          <SettingsProvider>
            <AlertProvider>
              {ui}
            </AlertProvider>
          </SettingsProvider>
        </LanguageProvider>
      </MemoryRouter>
    );
  };

  // ─── 1. USER DETAIL PAGE ──────────────────────────────────────────────────
  describe('1. UserDetailPage i18n Verification', () => {
    it('1.1. Hiển thị tiếng Việt mặc định và chuyển đổi mượt sang tiếng Anh (2 Tầng)', async () => {
      const Wrapper = () => (
        <div>
          <LanguageToggle />
          <UserDetailPage />
        </div>
      );

      renderWithProviders(<Wrapper />);

      // Tier 1 (VI Rendering)
      expect(await screen.findByText('Chi tiết người dùng')).toBeInTheDocument();
      expect(screen.getByText('Thông tin cá nhân')).toBeInTheDocument();
      expect(screen.getByText('Thông tin tài khoản')).toBeInTheDocument();
      expect(screen.getByText('Quay lại danh sách')).toBeInTheDocument();
      expect(screen.getByText('Họ tên')).toBeInTheDocument();

      // Tier 2 (System Impact: Chuyển EN qua LanguageToggle)
      const langBtnEn = screen.getByTestId('lang-btn-en');
      await act(async () => {
        fireEvent.click(langBtnEn);
      });

      // Kiểm tra tác động Root DOM & LocalStorage
      expect(document.documentElement.getAttribute('data-language')).toBe('en');
      expect(localStorage.getItem('admin_language')).toBe('en');

      // Giao diện UserDetailPage phải chuyển sang tiếng Anh chuẩn
      expect(screen.getByText('User Details')).toBeInTheDocument();
      expect(screen.getByText('Personal Information')).toBeInTheDocument();
      expect(screen.getByText('Account Information')).toBeInTheDocument();
      expect(screen.getByText('Back to User List')).toBeInTheDocument();
      expect(screen.getByText('Full Name')).toBeInTheDocument();
    });
  });

  // ─── 2. USER LIST PAGE ────────────────────────────────────────────────────
  describe('2. UserListPage i18n Verification', () => {
    it('2.1. Kiểm tra bộ lọc địa điểm và văn bản hiển thị chuyển đổi sang EN', async () => {
      const Wrapper = () => (
        <div>
          <LanguageToggle />
          <UserListPage />
        </div>
      );

      renderWithProviders(<Wrapper />);

      // Tier 1: VI ban đầu
      expect(await screen.findByPlaceholderText('Tìm kiếm người dùng...')).toBeInTheDocument();
      expect(screen.getByText('Tất Cả')).toBeInTheDocument();

      // Mở modal filter
      const filterBtn = screen.getByText('Bộ lọc');
      fireEvent.click(filterBtn);

      expect(screen.getByText('Lọc dữ liệu')).toBeInTheDocument();
      expect(screen.getByText('TP. Hồ Chí Minh')).toBeInTheDocument();
      expect(screen.getByText('Hà Nội')).toBeInTheDocument();

      // Đóng filter modal
      const closeBtn = screen.getByText('Đặt lại');
      fireEvent.click(closeBtn);

      // Tier 2: Chuyển ngữ sang EN
      const langBtnEn = screen.getByTestId('lang-btn-en');
      await act(async () => {
        fireEvent.click(langBtnEn);
      });

      expect(document.documentElement.getAttribute('data-language')).toBe('en');
      expect(screen.getByPlaceholderText('Search users...')).toBeInTheDocument();
      expect(screen.getByText('All')).toBeInTheDocument();

      // Mở lại modal filter để kiểm tra location EN
      const filterBtnEn = screen.getByText('Filter');
      fireEvent.click(filterBtnEn);

      expect(screen.getByText('Filter Data')).toBeInTheDocument();
      expect(screen.getByText('Ho Chi Minh City')).toBeInTheDocument();
      expect(screen.getByText('Hanoi')).toBeInTheDocument();
    });
  });

  // ─── 3. CATEGORY PAGE ─────────────────────────────────────────────────────
  describe('3. CategoryPage i18n Verification', () => {
    it('3.1. Danh mục tạo bởi hệ thống và các nhãn hành động hiển thị chuẩn theo ngôn ngữ', async () => {
      const Wrapper = () => (
        <div>
          <LanguageToggle />
          <CategoryPage />
        </div>
      );

      renderWithProviders(<Wrapper />);

      // Tier 1: VI ban đầu
      expect(await screen.findByText('Ăn uống')).toBeInTheDocument();
      expect(screen.getAllByText(/Tạo bởi Hệ thống/).length).toBeGreaterThan(0);
      expect(screen.getByPlaceholderText('Tìm kiếm danh mục...')).toBeInTheDocument();

      // Tier 2: Chuyển sang EN
      const langBtnEn = screen.getByTestId('lang-btn-en');
      await act(async () => {
        fireEvent.click(langBtnEn);
      });

      expect(document.documentElement.getAttribute('data-language')).toBe('en');
      expect(await screen.findByText('Ăn uống')).toBeInTheDocument();
      // "Tạo bởi Hệ thống" chuyển thành "Created by System"
      expect(screen.getAllByText(/Created by System/).length).toBeGreaterThan(0);
      expect(screen.getByPlaceholderText('Search categories...')).toBeInTheDocument();
      expect(screen.getByText('Add New Category')).toBeInTheDocument();
    });
  });

  // ─── 4. PERMISSION MANAGEMENT PAGE ────────────────────────────────────────
  describe('4. PermissionManagementPage i18n Verification', () => {
    it('4.1. Nhóm tính năng và thông điệp ma trận quyền tự động cập nhật khi chuyển EN', async () => {
      const Wrapper = () => (
        <div>
          <LanguageToggle />
          <PermissionManagementPage />
        </div>
      );

      renderWithProviders(<Wrapper />);

      // Tier 1: VI ban đầu
      expect(await screen.findByText(/Tài nguyên \(/)).toBeInTheDocument();
      expect(screen.getByText(/Trí tuệ nhân tạo \(/)).toBeInTheDocument();
      expect(screen.getByText(/Báo cáo & Phân tích \(/)).toBeInTheDocument();
      expect(screen.getByText(/Tự động hóa & Tiện ích \(/)).toBeInTheDocument();

      // Tier 2: Chuyển sang EN
      const langBtnEn = screen.getByTestId('lang-btn-en');
      await act(async () => {
        fireEvent.click(langBtnEn);
      });

      expect(document.documentElement.getAttribute('data-language')).toBe('en');

      // Nhóm tính năng chuyển sang tên tiếng Anh
      expect(screen.getByText(/Resources \(/)).toBeInTheDocument();
      expect(screen.getByText(/Artificial Intelligence \(/)).toBeInTheDocument();
      expect(screen.getByText(/Reports & Analytics \(/)).toBeInTheDocument();
      expect(screen.getByText(/Automation & Utilities \(/)).toBeInTheDocument();

      // Kiểm tra tiêu đề trang bằng tiếng Anh
      expect(screen.getByText(/Plan Permissions — Dynamic Matrix & Real-Time Sync/)).toBeInTheDocument();
    });
  });

  // ─── 5. DASHBOARD PAGE ────────────────────────────────────────────────────
  describe('5. DashboardPage i18n Verification', () => {
    it('5.1. Bộ lọc thời gian, hoạt động gần đây và KPI cập nhật ngôn ngữ đồng bộ', async () => {
      const Wrapper = () => (
        <div>
          <LanguageToggle />
          <DashboardPage />
        </div>
      );

      renderWithProviders(<Wrapper />);

      // Chờ nạp dữ liệu xong
      expect(await screen.findByText('Tổng quan hệ thống')).toBeInTheDocument();
      expect(screen.getByText('Hôm nay')).toBeInTheDocument();
      expect(screen.getByText('7 Ngày')).toBeInTheDocument();
      expect(screen.getByText('Hoạt động gần đây')).toBeInTheDocument();

      // Tier 2: Chuyển sang EN
      const langBtnEn = screen.getByTestId('lang-btn-en');
      await act(async () => {
        fireEvent.click(langBtnEn);
      });

      expect(document.documentElement.getAttribute('data-language')).toBe('en');

      // Kiểm tra text EN trên Dashboard
      expect(screen.getByText('System Overview')).toBeInTheDocument();
      expect(screen.getByText('Today')).toBeInTheDocument();
      expect(screen.getByText('7 Days')).toBeInTheDocument();
      expect(screen.getByText('Recent Activities')).toBeInTheDocument();
    });
  });
});
