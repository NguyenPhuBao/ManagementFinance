/**
 * Test Suite: Admin PIN Management & Audit Log Dual Columns (Rule 11 - 2-Tier Testing)
 * 
 * Kiểm thử 2 tầng:
 * - Tầng 1: Kiểm thử hiển thị & thao tác giao diện (SettingsModal PIN card, Dashboard & AuditLog dual columns).
 * - Tầng 2: Tác động hệ thống thực tế (Gọi API adminApi.changePin, format HTTP method badges, real-time socket mapping).
 */

import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import SettingsModal from '../components/layout/SettingsModal';
import DashboardPage from '../pages/dashboard/DashboardPage';
import AuditLogPage from '../pages/system/AuditLogPage';
import { SettingsProvider } from '../store/settings.context';
import { LanguageProvider } from '../store/language.context';
import { AlertProvider } from '../store/alert.context';
import adminApi from '../api/admin.api';
import { BrowserRouter } from 'react-router-dom';

vi.mock('../api/admin.api', () => ({
  default: {
    getTotalUsers: vi.fn().mockResolvedValue({ data: { total: 10 } }),
    getTotalCategories: vi.fn().mockResolvedValue({ data: { total: 50 } }),
    getUserToTime: vi.fn().mockResolvedValue({ data: { current: 2 } }),
    getDashboardStats: vi.fn().mockResolvedValue({ data: {} }),
    getRecentActivities: vi.fn().mockResolvedValue({
      data: {
        items: [
          {
            id: 'log-1',
            user: 'Admin Root',
            action: 'Đăng nhập hệ thống',
            request: 'POST /api/auth/login',
            reason: null,
            status: 'Pass',
            time: '14:30',
          },
        ],
        pagination: { total: 1, page: 1, limit: 10, totalPages: 1 },
      },
    }),
    getLoginStats: vi.fn().mockResolvedValue({ data: [] }),
    getRequestStats: vi.fn().mockResolvedValue({ data: [] }),
    getSystemHealth: vi.fn().mockResolvedValue({ data: {} }),
    getMaintenanceStatus: vi.fn().mockResolvedValue({ data: { active: false } }),
    getAuditLogs: vi.fn().mockResolvedValue({
      data: {
        items: [
          {
            id: 101,
            idlog: 101,
            idaccount: 1,
            username: 'administrator',
            action: '[AUTH] Đăng nhập hệ thống',
            request: 'POST /api/auth/login',
            req_status: 'Pass',
            reason: 'Thành công',
            time_req: '2026-10-19T10:00:00.000Z',
            time_res: '2026-10-19T10:00:00.050Z',
            ip: '127.0.0.1',
          },
        ],
        total: 1,
      },
    }),
    changePin: vi.fn().mockResolvedValue({ data: { message: 'Đổi mã PIN thành công' } }),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: () => ({
    connected: true,
    id: 'mock-socket-id',
    on: vi.fn(),
    off: vi.fn(),
    emit: vi.fn(),
  }),
}));

const renderWithProviders = (ui) => {
  return render(
    <BrowserRouter>
      <LanguageProvider>
        <AlertProvider>
          <SettingsProvider>{ui}</SettingsProvider>
        </AlertProvider>
      </LanguageProvider>
    </BrowserRouter>
  );
};

describe('Admin PIN Management & Dual Audit Columns Suite (2-Tier Testing)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  // =========================================================================
  // 1. Quản lý Mã PIN Bảo Mật Admin trong SettingsModal
  // =========================================================================
  describe('1. Admin Security PIN in SettingsModal', () => {
    it('1.1. Tầng 1: Hiển thị mục Mã PIN Bảo Mật Admin trong tab Bảo Mật & Thông Tin', async () => {
      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      // Switch to tab "Bảo Mật & Thông Tin"
      const systemTabBtn = screen.getByRole('button', { name: /Bảo Mật & Thông Tin/i });
      fireEvent.click(systemTabBtn);

      // Verify PIN Card rendering
      expect(screen.getByText('Mã PIN Bảo Mật Admin')).toBeInTheDocument();
      expect(screen.getByText('CSDL Bcrypt')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Đổi mã PIN/i })).toBeInTheDocument();
    });

    it('1.2. Tầng 1: Click "Đổi mã PIN" mở form nhập mật khẩu và mã PIN 6 số', async () => {
      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      fireEvent.click(screen.getByRole('button', { name: /Bảo Mật & Thông Tin/i }));
      fireEvent.click(screen.getByRole('button', { name: /Đổi mã PIN/i }));

      expect(screen.getByText(/Mật khẩu hiện tại \*/i)).toBeInTheDocument();
      expect(screen.getByText(/Mã PIN mới \(6 chữ số\) \*/i)).toBeInTheDocument();
      expect(screen.getByText(/Xác nhận mã PIN mới \*/i)).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Lưu mã PIN mới/i })).toBeInTheDocument();
    });

    it('1.3. Tầng 2: Gửi form đổi PIN hợp lệ gọi đúng adminApi.changePin với mật khẩu và 6 chữ số', async () => {
      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      fireEvent.click(screen.getByRole('button', { name: /Bảo Mật & Thông Tin/i }));
      fireEvent.click(screen.getByRole('button', { name: /Đổi mã PIN/i }));

      // Nhập mật khẩu hiện tại
      const passwordInput = screen.getByPlaceholderText('••••••••');
      fireEvent.change(passwordInput, { target: { value: 'AdminPass@123' } });

      // Nhập PIN mới 6 số
      const newPinInput = screen.getByPlaceholderText('6 chữ số mới');
      fireEvent.change(newPinInput, { target: { value: '654321' } });

      // Nhập xác nhận PIN mới
      const confirmPinInput = screen.getByPlaceholderText('Nhập lại 6 số');
      fireEvent.change(confirmPinInput, { target: { value: '654321' } });

      // Submit
      fireEvent.click(screen.getByRole('button', { name: /Lưu mã PIN mới/i }));

      await waitFor(() => {
        expect(adminApi.changePin).toHaveBeenCalledWith({
          password: 'AdminPass@123',
          newPin: '654321',
          oldPin: undefined,
        });
      });
    });

    it('1.4. Tầng 2: Chặn submit nếu mã PIN mới không đủ 6 chữ số', async () => {
      renderWithProviders(<SettingsModal isOpen={true} onClose={vi.fn()} />);

      fireEvent.click(screen.getByRole('button', { name: /Bảo Mật & Thông Tin/i }));
      fireEvent.click(screen.getByRole('button', { name: /Đổi mã PIN/i }));

      fireEvent.change(screen.getByPlaceholderText('••••••••'), { target: { value: 'AdminPass@123' } });
      fireEvent.change(screen.getByPlaceholderText('6 chữ số mới'), { target: { value: '123' } });
      fireEvent.change(screen.getByPlaceholderText('Nhập lại 6 số'), { target: { value: '123' } });

      fireEvent.click(screen.getByRole('button', { name: /Lưu mã PIN mới/i }));

      expect(screen.getByText('Mã PIN mới phải bao gồm đúng 6 chữ số')).toBeInTheDocument();
      expect(adminApi.changePin).not.toHaveBeenCalled();
    });
  });

  // =========================================================================
  // 2. Bảng Hoạt Động Gần Đây tại Dashboard (6 Cột: tách Hành Động & Yêu Cầu API)
  // =========================================================================
  describe('2. Dashboard Recent Activities 6 Columns', () => {
    it('2.1. Tầng 1: Render đầy đủ 6 cột trong bảng Hoạt động gần đây', async () => {
      renderWithProviders(<DashboardPage />);

      await waitFor(() => {
        expect(screen.getByText(/Người dùng/i, { selector: 'th' })).toBeInTheDocument();
        expect(screen.getByText(/Hành động/i, { selector: 'th' })).toBeInTheDocument();
        expect(screen.getByText(/Yêu cầu API/i, { selector: 'th' })).toBeInTheDocument();
        expect(screen.getByText(/Lý do/i, { selector: 'th' })).toBeInTheDocument();
        expect(screen.getByText(/Trạng thái/i, { selector: 'th' })).toBeInTheDocument();
        expect(screen.getByText(/Thời gian/i, { selector: 'th' })).toBeInTheDocument();
      });
    });

    it('2.2. Tầng 2: Tác động hiển thị - Cột YÊU CẦU API render badge method POST và endpoint', async () => {
      renderWithProviders(<DashboardPage />);

      await waitFor(() => {
        expect(screen.getByText('Admin Root')).toBeInTheDocument();
        expect(screen.getByText('Đăng nhập hệ thống')).toBeInTheDocument();
        // Method badge POST
        expect(screen.getByText('POST')).toBeInTheDocument();
        expect(screen.getByText('/api/auth/login')).toBeInTheDocument();
      });
    });
  });

  // =========================================================================
  // 3. Bảng Nhật Ký Kiểm Toán (AuditLogPage 8 Cột: tách Hành Động & Yêu Cầu API)
  // =========================================================================
  describe('3. AuditLogPage Dual Columns (8 Columns Table)', () => {
    it('3.1. Tầng 1: Render 8 cột độc lập có cả Hành động và Yêu cầu API', async () => {
      renderWithProviders(<AuditLogPage />);

      await waitFor(() => {
        expect(screen.getByText('ID')).toBeInTheDocument();
        expect(screen.getByText('Tài khoản')).toBeInTheDocument();
        expect(screen.getByText('Hành động')).toBeInTheDocument();
        expect(screen.getByText('Yêu cầu API')).toBeInTheDocument();
        expect(screen.getByText('Trạng thái')).toBeInTheDocument();
        expect(screen.getByText('Lý do')).toBeInTheDocument();
        expect(screen.getByText('Thời gian gửi')).toBeInTheDocument();
        expect(screen.getByText('Thời gian phản hồi')).toBeInTheDocument();
      });
    });

    it('3.2. Tầng 2: Tác động dữ liệu - Render phân tách rõ Action nghiệp vụ và Request HTTP badge', async () => {
      renderWithProviders(<AuditLogPage />);

      await waitFor(() => {
        // Cột Hành động: hiển thị tag [AUTH] và tên hành động
        expect(screen.getByText('[AUTH]')).toBeInTheDocument();
        expect(screen.getByText('Đăng nhập hệ thống')).toBeInTheDocument();

        // Cột Yêu cầu API: hiển thị badge HTTP POST và path
        expect(screen.getByText('POST')).toBeInTheDocument();
        expect(screen.getByText('/api/auth/login')).toBeInTheDocument();
      });
    });
  });
});
