import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import UserListPage from '../pages/users/UserListPage';
import adminApi from '../api/admin.api';
import useSocket from '../hooks/useSocket';
import { LanguageProvider, useLanguage } from '../store/language.context';
import { AlertProvider } from '../store/alert.context';

// Mock Socket.io
let socketHandlers = {};
const mockSocket = {
  connected: true,
  on: vi.fn((event, handler) => {
    socketHandlers[event] = handler;
  }),
  off: vi.fn((event) => {
    delete socketHandlers[event];
  }),
};

vi.mock('../hooks/useSocket', () => ({
  default: () => mockSocket,
}));

vi.mock('../api/admin.api', () => ({
  default: {
    getUsers: vi.fn(),
    updateUserStatus: vi.fn(),
    deleteUser: vi.fn(),
    getUserById: vi.fn(),
    verifySecurityAction: vi.fn(),
  },
}));

// Mock dataset mô phỏng chính xác dữ liệu từ CSDL Supabase
const mockDatabaseUsers = [
  {
    id: 1,
    idaccount: 101,
    fullname: 'Nguyễn Phú Bảo',
    username: 'BaoNP',
    email: 'phubao9as@gmail.com',
    phone: '0901234567',
    status: 'Active',
    type: 'Premium',
    created_at: '2026-01-01T00:00:00Z',
  },
  {
    id: 2,
    idaccount: 102,
    fullname: 'Admin System',
    username: 'admin',
    email: 'admin@wealthcommand.com',
    phone: '0908889999',
    status: 'Active',
    type: 'Premium',
    created_at: '2026-01-02T00:00:00Z',
  },
  {
    id: 3,
    idaccount: 103,
    fullname: 'Đạt Quang',
    username: 'quangdat',
    email: 'tadd1632004@gmail.com',
    phone: '0912345678',
    status: 'Active',
    type: 'Basic',
    created_at: '2026-01-03T00:00:00Z',
  },
  {
    id: 4,
    idaccount: 104,
    fullname: 'Test Basic User',
    username: 'test_basic_01',
    email: 'basic01@example.com',
    phone: '0933221100',
    status: 'Inactive',
    type: 'Basic',
    created_at: '2026-01-04T00:00:00Z',
  },
];

const renderWithProviders = (ui, initialLang = 'vi') => {
  if (initialLang) {
    localStorage.setItem('admin_language', initialLang);
  }
  return render(
    <LanguageProvider key={initialLang}>
      <AlertProvider>
        {ui}
      </AlertProvider>
    </LanguageProvider>
  );
};

describe('UserListPage Refinements & 2-Tier Architecture Suite', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    socketHandlers = {};
    adminApi.getUsers.mockResolvedValue({ data: mockDatabaseUsers });
    localStorage.setItem('admin_language', 'vi');
  });

  // =========================================================================
  // 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN (UI RENDERING & INTERACTION)
  // =========================================================================
  describe('🧱 TẦNG 1: UI Rendering & Header / Filter Modal i18n Verification', () => {
    it('1.1. Header: Loại bỏ hoàn toàn icon manage_accounts, badge Realtime Sync và subtitle dài', async () => {
      renderWithProviders(<UserListPage />);

      await waitFor(() => {
        expect(adminApi.getUsers).toHaveBeenCalledTimes(1);
      });

      // Tiêu đề trang vẫn hiện rõ ràng
      expect(screen.getByRole('heading', { level: 2, name: /Quản lý người dùng/i })).toBeInTheDocument();

      // Kiểm tra BỎ HOÀN TOÀN icon manage_accounts
      expect(screen.queryByText('manage_accounts')).not.toBeInTheDocument();

      // Kiểm tra BỎ HOÀN TOÀN badge Realtime Sync
      expect(screen.queryByText(/Realtime Sync/i)).not.toBeInTheDocument();

      // Kiểm tra BỎ HOÀN TOÀN dòng subtitle Nghị định 13
      expect(screen.queryByText(/Nghị định 13\/2023\/NĐ-CP/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Giám sát người dùng, kiểm soát trạng thái kích hoạt/i)).not.toBeInTheDocument();

      // Nút Làm mới vẫn còn nguyên vẹn
      expect(screen.getByRole('button', { name: /Làm mới/i })).toBeInTheDocument();
    });

    it('1.2. Filter Modal i18n: Hiển thị "Gói dịch vụ" khi dùng Tiếng Việt (vi)', async () => {
      renderWithProviders(<UserListPage />, 'vi');

      await waitFor(() => {
        expect(adminApi.getUsers).toHaveBeenCalled();
      });

      // Mở modal bộ lọc
      const filterBtn = screen.getByRole('button', { name: /Bộ lọc/i });
      fireEvent.click(filterBtn);

      // Nhãn dropdown phải là "Gói dịch vụ" (không còn hardcode 'Gói dịch vụ / Membership')
      expect(screen.getByText('Gói dịch vụ')).toBeInTheDocument();
      expect(screen.queryByText('Gói dịch vụ / Membership')).not.toBeInTheDocument();

      // Kiểm tra các tùy chọn dropdown gói cước tiếng Việt
      const packageSelect = screen.getByTestId('filter-package');
      expect(packageSelect).toBeInTheDocument();
      expect(screen.getByRole('option', { name: /Tất cả gói cước/i })).toBeInTheDocument();
      expect(screen.getByRole('option', { name: /Gói Cơ bản \(Basic\)/i })).toBeInTheDocument();
      expect(screen.getByRole('option', { name: /Gói VIP \(Premium\)/i })).toBeInTheDocument();
    });

    it('1.3. Filter Modal i18n: Hiển thị "Membership" khi chuyển sang Tiếng Anh (en)', async () => {
      renderWithProviders(<UserListPage />, 'en');

      await waitFor(() => {
        expect(adminApi.getUsers).toHaveBeenCalled();
      });

      // Mở modal Filter
      const filterBtn = screen.getByRole('button', { name: /Filter/i });
      fireEvent.click(filterBtn);

      // Nhãn dropdown phải hiển thị "Membership"
      expect(screen.getByText('Membership')).toBeInTheDocument();
      expect(screen.queryByText('Gói dịch vụ / Membership')).not.toBeInTheDocument();

      // Kiểm tra các tùy chọn dropdown tiếng Anh
      expect(screen.getByRole('option', { name: /All Packages/i })).toBeInTheDocument();
      expect(screen.getByRole('option', { name: /Basic Package/i })).toBeInTheDocument();
      expect(screen.getByRole('option', { name: /VIP \(Premium\) Package/i })).toBeInTheDocument();
    });
  });

  // =========================================================================
  // ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ (REAL SYSTEM IMPACT & FILTERING)
  // =========================================================================
  describe('⚡ TẦNG 2: Real System Impact & Accurate Package Filtering Verification', () => {
    it('2.1. Lọc Gói VIP (Premium): Hiển thị chính xác BaoNP (phubao9as@gmail.com) và ẩn các tài khoản Basic', async () => {
      renderWithProviders(<UserListPage />);

      await waitFor(() => {
        expect(screen.getByText('Nguyễn Phú Bảo')).toBeInTheDocument();
        expect(screen.getByText('Đạt Quang')).toBeInTheDocument();
      });

      // Mở modal Lọc
      fireEvent.click(screen.getByRole('button', { name: /Bộ lọc/i }));

      // Chọn lọc Gói VIP (Premium)
      const packageSelect = screen.getByTestId('filter-package');
      fireEvent.change(packageSelect, { target: { value: 'Premium' } });

      // Nhấn nút Áp dụng
      fireEvent.click(screen.getByRole('button', { name: /^Áp dụng$/i }));

      // TÁC ĐỘNG HỆ THỐNG THỰC TẾ:
      // Tài khoản BaoNP (Premium) và Admin System (Premium) PHẢI HIỂN THỊ
      expect(screen.getByText('Nguyễn Phú Bảo')).toBeInTheDocument();
      expect(screen.getByText('phubao9as@gmail.com')).toBeInTheDocument();
      expect(screen.getByText('Admin System')).toBeInTheDocument();

      // Các tài khoản Basic (Đạt Quang) BẮT BUỘC BỊ ẨN KHỎI DANH SÁCH
      expect(screen.queryByText('Đạt Quang')).not.toBeInTheDocument();
      expect(screen.queryByText(/tadd1632004@gmail\.com/i)).not.toBeInTheDocument();
    });

    it('2.2. Lọc Gói Cơ bản (Basic): Hiển thị tài khoản Basic và ẩn tài khoản BaoNP Premium', async () => {
      renderWithProviders(<UserListPage />);

      await waitFor(() => {
        expect(screen.getByText('Nguyễn Phú Bảo')).toBeInTheDocument();
      });

      // Mở modal Lọc
      fireEvent.click(screen.getByRole('button', { name: /Bộ lọc/i }));

      // Chọn lọc Gói Cơ bản (Basic)
      const packageSelect = screen.getByTestId('filter-package');
      fireEvent.change(packageSelect, { target: { value: 'Basic' } });

      // Nhấn Áp dụng
      fireEvent.click(screen.getByRole('button', { name: /^Áp dụng$/i }));

      // TÁC ĐỘNG HỆ THỐNG THỰC TẾ:
      // Đạt Quang (Basic) PHẢI HIỂN THỊ
      expect(screen.getByText('Đạt Quang')).toBeInTheDocument();

      // BaoNP (Premium) BẮT BUỘC BỊ ẨN
      expect(screen.queryByText('Nguyễn Phú Bảo')).not.toBeInTheDocument();
      expect(screen.queryByText('Admin System')).not.toBeInTheDocument();
    });

    it('2.3. Nhấn "Đặt lại" (Reset): Khôi phục danh sách hiển thị đầy đủ cả Basic và Premium', async () => {
      renderWithProviders(<UserListPage />);

      await waitFor(() => {
        expect(screen.getByText('Nguyễn Phú Bảo')).toBeInTheDocument();
      });

      // Lọc Premium trước
      fireEvent.click(screen.getByRole('button', { name: /Bộ lọc/i }));
      fireEvent.change(screen.getByTestId('filter-package'), { target: { value: 'Premium' } });
      fireEvent.click(screen.getByRole('button', { name: /^Áp dụng$/i }));

      expect(screen.queryByText('Đạt Quang')).not.toBeInTheDocument();

      // Mở lại modal và nhấn "Đặt lại"
      fireEvent.click(screen.getByRole('button', { name: /Bộ lọc/i }));
      fireEvent.click(screen.getByRole('button', { name: /^Đặt lại$/i }));

      // TÁC ĐỘNG HỆ THỐNG: Cả BaoNP (Premium) và Đạt Quang (Basic) đều xuất hiện lại
      expect(screen.getByText('Nguyễn Phú Bảo')).toBeInTheDocument();
      expect(screen.getByText('Đạt Quang')).toBeInTheDocument();
    });

    it('2.4. Realtime Socket Sync: Người dùng Premium mới đăng ký được nạp đúng type vào state ngầm', async () => {
      renderWithProviders(<UserListPage />);

      await waitFor(() => {
        expect(screen.getByText('Nguyễn Phú Bảo')).toBeInTheDocument();
      });

      // Kích hoạt sự kiện Socket người dùng mới với gói Premium
      act(() => {
        if (socketHandlers['admin.user_registered']) {
          socketHandlers['admin.user_registered']({
            id: 999,
            idaccount: 999,
            fullname: 'Trần Đại Gia',
            username: 'daigia_vip',
            email: 'daigia@vip.com',
            phone: '0999888777',
            status: 'active',
            type: 'Premium',
            created_at: new Date().toISOString(),
          });
        }
      });

      // Người dùng mới xuất hiện trên giao diện
      expect(screen.getByText('Trần Đại Gia')).toBeInTheDocument();

      // Khi lọc Premium: Người dùng mới vẫn hiển thị chính xác
      fireEvent.click(screen.getByRole('button', { name: /Bộ lọc/i }));
      fireEvent.change(screen.getByTestId('filter-package'), { target: { value: 'Premium' } });
      fireEvent.click(screen.getByRole('button', { name: /^Áp dụng$/i }));

      expect(screen.getByText('Trần Đại Gia')).toBeInTheDocument();
      expect(screen.getByText('Nguyễn Phú Bảo')).toBeInTheDocument();
      expect(screen.queryByText('Đạt Quang')).not.toBeInTheDocument();
    });
  });
});
