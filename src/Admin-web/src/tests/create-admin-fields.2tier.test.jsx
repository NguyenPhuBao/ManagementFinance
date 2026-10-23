import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import SettingsModal from '../components/layout/SettingsModal';
import adminApi from '../api/admin.api';
import { SettingsProvider } from '../store/settings.context';
import { AuthProvider } from '../store/auth.context';
import { LanguageProvider } from '../store/language.context';
import { AlertProvider } from '../store/alert.context';
import { MemoryRouter } from 'react-router-dom';

vi.mock('../api/admin.api', () => ({
  default: {
    createAdmin: vi.fn(),
    changePin: vi.fn(),
    changePassword: vi.fn(),
    verifySecurityAction: vi.fn(),
    getSystemHealth: vi.fn().mockResolvedValue({
      data: {
        server: { status: 'ONLINE', uptime: 3600, nodeVersion: 'v20.0.0', platform: 'linux' },
        database: { status: 'CONNECTED', responseTimeMs: 15, poolSize: 10 },
        memory: { usedMb: 250, totalMb: 1024, usagePercent: 25 },
        cpu: { usagePercent: 12 },
      },
    }),
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

const renderSettingsModal = () => {
  return render(
    <MemoryRouter>
      <LanguageProvider>
        <AlertProvider>
          <AuthProvider>
            <SettingsProvider>
              <SettingsModal isOpen={true} onClose={vi.fn()} />
            </SettingsProvider>
          </AuthProvider>
        </AlertProvider>
      </LanguageProvider>
    </MemoryRouter>
  );
};

describe('Admin Provisioning (Cấp Tài Khoản Admin) — 2-Tier Architecture Test Suite', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
  });

  // =========================================================================
  // 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC TẠI GIAO DIỆN (UI Rendering & Interaction)
  // =========================================================================
  describe('🧱 TẦNG 1: UI Rendering & Form Validation Controls', () => {
    it('1.1. Render đầy đủ 6 controls theo layout Grid 2 cột: FullName, Username, Email, Country code, Phone, Address', async () => {
      renderSettingsModal();

      // Mở Tab Quản trị hệ thống & Mở modal Cấp tài khoản Admin
      fireEvent.click(screen.getByTestId('settings-tab-admin_mgmt'));
      fireEvent.click(screen.getByTestId('open-create-admin-btn'));

      // Kiểm tra tiêu đề modal
      expect(screen.getByText('Cấp Tài Khoản Admin')).toBeInTheDocument();
      expect(screen.getByText('Bước 1/2: Nhập thông tin quản trị viên')).toBeInTheDocument();

      // Kiểm tra 6 trường dữ liệu
      const fullNameInput = screen.getByTestId('create-admin-fullname');
      const usernameInput = screen.getByTestId('create-admin-username');
      const emailInput = screen.getByTestId('create-admin-email');
      const countryCodeInput = screen.getByTestId('create-admin-country-code');
      const phoneInput = screen.getByTestId('create-admin-phone');
      const addressInput = screen.getByTestId('create-admin-address');

      expect(fullNameInput).toBeInTheDocument();
      expect(fullNameInput).toHaveAttribute('required');
      expect(fullNameInput).toHaveAttribute('placeholder', 'VD: Nguyễn Văn Quản Trị');

      expect(usernameInput).toBeInTheDocument();
      expect(usernameInput).toHaveAttribute('required');
      expect(usernameInput).toHaveAttribute('placeholder', 'VD: admin_finance_2');

      expect(emailInput).toBeInTheDocument();
      expect(emailInput).toHaveAttribute('required');
      expect(emailInput).toHaveAttribute('placeholder', 'admin2@domain.com');

      expect(countryCodeInput).toBeInTheDocument();
      expect(countryCodeInput).toHaveValue('+84');
      expect(countryCodeInput).toHaveAttribute('maxLength', '4');

      expect(phoneInput).toBeInTheDocument();
      expect(phoneInput).toHaveAttribute('required');
      expect(phoneInput).toHaveAttribute('placeholder', 'VD: 0912345678');

      expect(addressInput).toBeInTheDocument();
      expect(addressInput).not.toHaveAttribute('required');

      // Kiểm tra nút chuyển bước
      expect(screen.getByTestId('btn-next-create-admin')).toBeInTheDocument();
    });

    it('1.2. Validation: Chặn chuyển bước và thông báo lỗi khi bỏ trống FullName', async () => {
      renderSettingsModal();
      fireEvent.click(screen.getByTestId('settings-tab-admin_mgmt'));
      fireEvent.click(screen.getByTestId('open-create-admin-btn'));

      // Bỏ trống FullName, nhập các trường khác
      fireEvent.change(screen.getByTestId('create-admin-username'), { target: { value: 'admin_test' } });
      fireEvent.change(screen.getByTestId('create-admin-email'), { target: { value: 'admin@test.com' } });
      fireEvent.change(screen.getByTestId('create-admin-phone'), { target: { value: '0901234567' } });

      fireEvent.click(screen.getByTestId('btn-next-create-admin'));

      expect(screen.getByText(/Họ và tên quản trị viên phải có ít nhất 2 ký tự/i)).toBeInTheDocument();
      expect(screen.queryByTestId('create-admin-pin-auth')).not.toBeInTheDocument();
    });

    it('1.3. Validation: Chặn chuyển bước và thông báo lỗi khi bỏ trống hoặc nhập sai định dạng Phone', async () => {
      renderSettingsModal();
      fireEvent.click(screen.getByTestId('settings-tab-admin_mgmt'));
      fireEvent.click(screen.getByTestId('open-create-admin-btn'));

      fireEvent.change(screen.getByTestId('create-admin-fullname'), { target: { value: 'Nguyễn Văn A' } });
      fireEvent.change(screen.getByTestId('create-admin-username'), { target: { value: 'admin_test' } });
      fireEvent.change(screen.getByTestId('create-admin-email'), { target: { value: 'admin@test.com' } });

      // Trường hợp 1: Phone trống
      fireEvent.change(screen.getByTestId('create-admin-phone'), { target: { value: '' } });
      fireEvent.click(screen.getByTestId('btn-next-create-admin'));
      expect(screen.getByText(/Vui lòng nhập số điện thoại quản trị viên/i)).toBeInTheDocument();

      // Trường hợp 2: Phone quá ngắn hoặc không phải số hợp lệ
      fireEvent.change(screen.getByTestId('create-admin-phone'), { target: { value: '1234' } });
      fireEvent.click(screen.getByTestId('btn-next-create-admin'));
      expect(screen.getByText(/Số điện thoại không đúng định dạng/i)).toBeInTheDocument();
    });
  });

  // =========================================================================
  // ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ & XÁC THỰC NGHIỆP VỤ (System Impact)
  // =========================================================================
  describe('⚡ TẦNG 2: Real System Impact, Multi-Step Flow & API Payload Verification', () => {
    it('2.1. Nhập thông tin hợp lệ -> Chuyển sang Bước 2/2 hiển thị đúng bản tóm tắt 6 trường thông tin', async () => {
      renderSettingsModal();
      fireEvent.click(screen.getByTestId('settings-tab-admin_mgmt'));
      fireEvent.click(screen.getByTestId('open-create-admin-btn'));

      fireEvent.change(screen.getByTestId('create-admin-fullname'), { target: { value: 'Trần Thị Quản Trị' } });
      fireEvent.change(screen.getByTestId('create-admin-username'), { target: { value: 'tran_admin' } });
      fireEvent.change(screen.getByTestId('create-admin-email'), { target: { value: 'tran_admin@finance.local' } });
      fireEvent.change(screen.getByTestId('create-admin-country-code'), { target: { value: '+84' } });
      fireEvent.change(screen.getByTestId('create-admin-phone'), { target: { value: '0988776655' } });
      fireEvent.change(screen.getByTestId('create-admin-address'), { target: { value: '789 Lê Lợi, Quận 1, TP.HCM' } });

      fireEvent.click(screen.getByTestId('btn-next-create-admin'));

      // Xác nhận chuyển sang Bước 2/2
      expect(screen.getByText('Bước 2/2: Xác thực mã PIN phê duyệt')).toBeInTheDocument();
      expect(screen.getByText('Trần Thị Quản Trị')).toBeInTheDocument();
      expect(screen.getByText('tran_admin')).toBeInTheDocument();
      expect(screen.getByText('tran_admin@finance.local')).toBeInTheDocument();
      expect(screen.getByText('+84 0988776655')).toBeInTheDocument();
      expect(screen.getByText('789 Lê Lợi, Quận 1, TP.HCM')).toBeInTheDocument();
      expect(screen.getByTestId('create-admin-pin-auth')).toBeInTheDocument();
    });

    it('2.2. Nhập mã PIN và xác nhận -> Gọi API adminApi.createAdmin với đầy đủ 6 trường dữ liệu và mã PIN', async () => {
      adminApi.createAdmin.mockResolvedValueOnce({
        data: {
          success: true,
          message: 'Cấp tài khoản quản trị viên thành công',
          data: {
            idaccount: 105,
            username: 'tran_admin',
            email: 'tran_admin@finance.local',
            fullname: 'Trần Thị Quản Trị',
            phone: '0988776655',
            country_code: '+84',
            is_first_login: true,
          },
        },
      });

      renderSettingsModal();
      fireEvent.click(screen.getByTestId('settings-tab-admin_mgmt'));
      fireEvent.click(screen.getByTestId('open-create-admin-btn'));

      // Bước 1: Nhập thông tin
      fireEvent.change(screen.getByTestId('create-admin-fullname'), { target: { value: 'Trần Thị Quản Trị' } });
      fireEvent.change(screen.getByTestId('create-admin-username'), { target: { value: 'tran_admin' } });
      fireEvent.change(screen.getByTestId('create-admin-email'), { target: { value: 'tran_admin@finance.local' } });
      fireEvent.change(screen.getByTestId('create-admin-country-code'), { target: { value: '+84' } });
      fireEvent.change(screen.getByTestId('create-admin-phone'), { target: { value: '0988776655' } });
      fireEvent.change(screen.getByTestId('create-admin-address'), { target: { value: '789 Lê Lợi, Quận 1, TP.HCM' } });
      fireEvent.click(screen.getByTestId('btn-next-create-admin'));

      // Bước 2: Nhập PIN
      await waitFor(() => {
        expect(screen.getByTestId('create-admin-pin-auth')).toBeInTheDocument();
      });
      fireEvent.change(screen.getByTestId('create-admin-pin-auth'), { target: { value: '654321' } });
      fireEvent.click(screen.getByTestId('submit-create-admin-btn'));

      // Xác thực API payload
      await waitFor(() => {
        expect(adminApi.createAdmin).toHaveBeenCalledTimes(1);
        expect(adminApi.createAdmin).toHaveBeenCalledWith({
          fullName: 'Trần Thị Quản Trị',
          username: 'tran_admin',
          email: 'tran_admin@finance.local',
          phone: '0988776655',
          address: '789 Lê Lợi, Quận 1, TP.HCM',
          countryCode: '+84',
          pin: '654321',
        });
      });

      // Bước 3: Xác thực hiển thị kết quả thành công và mật khẩu/PIN khởi đầu 123456
      await waitFor(() => {
        expect(screen.getByText(/Cấp Tài Khoản Admin Thành Công!/i)).toBeInTheDocument();
        expect(screen.getByText('Trần Thị Quản Trị')).toBeInTheDocument();
        expect(screen.getByText('tran_admin')).toBeInTheDocument();
        expect(screen.getByText('tran_admin@finance.local')).toBeInTheDocument();
        expect(screen.getByText('+84 0988776655')).toBeInTheDocument();
        expect(screen.getAllByText('123456').length).toBeGreaterThanOrEqual(2);
      });

      // Đóng modal hoàn tất
      fireEvent.click(screen.getByTestId('btn-finish-create-admin'));
      await waitFor(() => {
        expect(screen.queryByText(/Cấp Tài Khoản Admin Thành Công!/i)).not.toBeInTheDocument();
      });
    });
  });
});
