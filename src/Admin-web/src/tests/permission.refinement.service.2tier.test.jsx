import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import PermissionManagementPage from '../pages/system/PermissionManagementPage';
import Sidebar from '../components/layout/Sidebar';
import { LanguageProvider } from '../store/language.context';
import { AlertProvider } from '../store/alert.context';
import adminApi from '../api/admin.api';

// Mock API và Socket
vi.mock('../api/admin.api', () => ({
  default: {
    getPermissions: vi.fn(),
    updatePermissions: vi.fn(),
    resetPermissionsDefault: vi.fn(),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: () => ({
    connected: true,
    emit: vi.fn(),
    on: vi.fn(),
    off: vi.fn(),
  }),
}));

vi.mock('../store/auth.context', () => ({
  useAuthContext: () => ({
    logout: vi.fn(),
    user: { username: 'superadmin' },
  }),
}));

const mockFeatures = [
  {
    id: 'anomaly_spending_insights',
    name: 'Cảnh báo Chi tiêu Bất thường',
    type: 'TOGGLE',
    category_group: 'Trí tuệ nhân tạo',
    description: 'Phát hiện và cảnh báo các khoản chi tiêu đột biến bất thường so với lịch sử',
    default_downgrade_policy: 'LOCK_FEATURE',
    scope_schema: {},
  },
  {
    id: 'wallets',
    name: 'Quản lý Ví tiền & Tài sản',
    type: 'LIMIT',
    category_group: 'Tài nguyên',
    description: 'Số lượng ví tiền hoạt động tối đa mà tài khoản có thể khởi tạo',
    default_downgrade_policy: 'BLOCK_CREATE',
    scope_schema: { max_wallets: 3 },
  },
  {
    id: 'ai_assistant',
    name: 'Trợ lý Tài chính AI Copilot',
    type: 'TOGGLE',
    category_group: 'Trí tuệ nhân tạo',
    description: 'Tương tác đối thoại hỏi đáp tài chính thông minh sử dụng Gemini Pro',
    default_downgrade_policy: 'LOCK_FEATURE',
    scope_schema: {},
  },
];

const mockPermissions = {
  Basic: {
    anomaly_spending_insights: {
      is_enabled: false,
      limit_value: null,
      downgrade_policy: 'LOCK_FEATURE',
      scope_config: {},
    },
    wallets: {
      is_enabled: true,
      limit_value: 3,
      downgrade_policy: 'BLOCK_CREATE',
      scope_config: { max_wallets: 3 },
    },
    ai_assistant: {
      is_enabled: false,
      limit_value: null,
      downgrade_policy: 'LOCK_FEATURE',
      scope_config: {},
    },
  },
  Premium: {
    anomaly_spending_insights: {
      is_enabled: true,
      limit_value: null,
      downgrade_policy: 'LOCK_FEATURE',
      scope_config: {},
    },
    wallets: {
      is_enabled: true,
      limit_value: null,
      downgrade_policy: 'BLOCK_CREATE',
      scope_config: { max_wallets: -1 },
    },
    ai_assistant: {
      is_enabled: true,
      limit_value: null,
      downgrade_policy: 'LOCK_FEATURE',
      scope_config: {},
    },
  },
};

const renderWithProviders = (ui) => {
  return render(
    <MemoryRouter>
      <LanguageProvider>
        <AlertProvider>
          {ui}
        </AlertProvider>
      </LanguageProvider>
    </MemoryRouter>
  );
};

describe('Phân Quyền Dịch Vụ — 2-Tier Testing Architecture (Rule 11)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
    localStorage.setItem('admin_lang', 'vi');

    adminApi.getPermissions.mockResolvedValue({
      features: mockFeatures,
      permissions: mockPermissions,
      total_features: mockFeatures.length,
      groups: ['Tài nguyên', 'Trí tuệ nhân tạo'],
    });

    adminApi.updatePermissions.mockResolvedValue({
      success: true,
      count: 1,
      message: 'Cập nhật phân quyền dịch vụ thành công',
    });
  });

  // ==========================================
  // 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN
  // ==========================================
  describe('🧱 TẦNG 1: Kiểm thử hiển thị & Thao tác giao diện (UI Rendering & Interaction)', () => {
    it('1.1. Sidebar menu hiển thị chính xác tên "Phân quyền dịch vụ"', () => {
      renderWithProviders(<Sidebar collapsed={false} onToggle={vi.fn()} />);
      
      expect(screen.getByText('Phân quyền dịch vụ')).toBeInTheDocument();
      expect(screen.queryByText('Phân Quyền Gói Cước')).not.toBeInTheDocument();
      expect(screen.queryByText('Phân quyền gói cước')).not.toBeInTheDocument();
    });

    it('1.2. Header trang: Đổi tên thành "Phân quyền dịch vụ", bỏ icon admin_panel_settings, bỏ subtitle, tab "Tất cả", bỏ nút "Làm mới"', async () => {
      renderWithProviders(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Cảnh báo Chi tiêu Bất thường')).toBeInTheDocument();
      });

      // 1. Tiêu đề hiển thị "Phân quyền dịch vụ"
      expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Phân quyền dịch vụ');
      expect(screen.queryByText(/Phân Quyền Gói Cước — Ma Trận Phân Quyền Động/i)).not.toBeInTheDocument();

      // 2. Không còn icon admin_panel_settings
      expect(screen.queryByText('admin_panel_settings')).not.toBeInTheDocument();

      // 3. Không còn dòng mô tả phụ subtitle
      expect(
        screen.queryByText(/Thiết lập hạn mức tài nguyên \(LIMIT\) và bật\/tắt chức năng/i)
      ).not.toBeInTheDocument();

      // 4. Tab lọc chế độ xem ALL đổi tên thành "Tất cả"
      const allTab = screen.getByTestId('tab-viewmode-all');
      expect(allTab).toHaveTextContent('Tất cả');
      expect(allTab).not.toHaveTextContent('Đối Chiếu 2 Gói');

      // 5. Nút Làm mới (btn-refresh) đã được gỡ bỏ hoàn toàn
      expect(screen.queryByTestId('btn-refresh')).not.toBeInTheDocument();
      expect(screen.queryByText('Làm Mới')).not.toBeInTheDocument();
      expect(screen.queryByText('Làm mới')).not.toBeInTheDocument();
    });

    it('1.3. Cột "Tính Năng & Mã Định Danh": Bỏ mã định danh slug và bỏ dòng ghi chú mô tả, chỉ hiển thị tên & badge loại', async () => {
      renderWithProviders(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Cảnh báo Chi tiêu Bất thường')).toBeInTheDocument();
      });

      // Hiển thị đầy đủ tên tính năng f.name
      expect(screen.getByText('Cảnh báo Chi tiêu Bất thường')).toBeInTheDocument();
      expect(screen.getByText('Quản lý Ví tiền & Tài sản')).toBeInTheDocument();
      expect(screen.getByText('Trợ lý Tài chính AI Copilot')).toBeInTheDocument();

      // Hiển thị badge LIMIT và TOGGLE
      expect(screen.getAllByText('LIMIT').length).toBeGreaterThan(0);
      expect(screen.getAllByText('TOGGLE').length).toBeGreaterThan(0);

      // BỎ MÃ ĐỊNH DANH f.id
      expect(screen.queryByText('anomaly_spending_insights')).not.toBeInTheDocument();
      expect(screen.queryByText('wallets')).not.toBeInTheDocument();
      expect(screen.queryByText('ai_assistant')).not.toBeInTheDocument();

      // BỎ DÒNG GHI CHÚ MÔ TẢ f.description
      expect(
        screen.queryByText('Phát hiện và cảnh báo các khoản chi tiêu đột biến bất thường so với lịch sử')
      ).not.toBeInTheDocument();
      expect(
        screen.queryByText('Số lượng ví tiền hoạt động tối đa mà tài khoản có thể khởi tạo')
      ).not.toBeInTheDocument();
      expect(
        screen.queryByText('Tương tác đối thoại hỏi đáp tài chính thông minh sử dụng Gemini Pro')
      ).not.toBeInTheDocument();
    });
  });

  // ==========================================
  // ⚡ TẦNG 2: KIỂM THỬ HOẠT ĐỘNG THỰC TẾ & TÁC ĐỘNG HỆ THỐNG
  // ==========================================
  describe('⚡ TẦNG 2: Kiểm thử hoạt động thực tế & Tác động hệ thống (System Impact Verification)', () => {
    it('2.1. Tác động tìm kiếm ngầm (Hidden Identifier Matching): Tìm kiếm bằng slug f.id vẫn lọc chính xác dù UI không hiển thị f.id', async () => {
      renderWithProviders(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Cảnh báo Chi tiêu Bất thường')).toBeInTheDocument();
      });

      const searchInput = screen.getByTestId('input-search-features');

      // Nhập 'anomaly' (slug f.id) vào ô tìm kiếm
      fireEvent.change(searchInput, { target: { value: 'anomaly' } });

      // Tính năng tương ứng vẫn xuất hiện trên DOM
      expect(screen.getByText('Cảnh báo Chi tiêu Bất thường')).toBeInTheDocument();

      // Các tính năng khác không khớp bị loại bỏ khỏi bảng
      expect(screen.queryByText('Quản lý Ví tiền & Tài sản')).not.toBeInTheDocument();
      expect(screen.queryByText('Trợ lý Tài chính AI Copilot')).not.toBeInTheDocument();
    });

    it('2.2. Tác động chuyển đổi Tab xem: Tab "Tất cả" hiển thị cả 2 gói gộp; chuyển tab "Gói Basic" lọc đúng gói tương ứng', async () => {
      renderWithProviders(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Cảnh báo Chi tiêu Bất thường')).toBeInTheDocument();
      });

      // Mặc định ở chế độ 'Tất cả' (viewMode = ALL): Có cả badge BASIC và PREMIUM
      expect(screen.getAllByText('BASIC').length).toBeGreaterThan(0);
      expect(screen.getAllByText('PREMIUM').length).toBeGreaterThan(0);

      // Chuyển sang Tab "Gói Basic"
      const basicTab = screen.getByTestId('tab-viewmode-basic');
      fireEvent.click(basicTab);

      // DOM chỉ còn badge BASIC, không còn badge PREMIUM
      expect(screen.getAllByText('BASIC').length).toBeGreaterThan(0);
      expect(screen.queryByText('PREMIUM')).not.toBeInTheDocument();

      // Chuyển lại Tab "Tất cả"
      const allTab = screen.getByTestId('tab-viewmode-all');
      fireEvent.click(allTab);

      // Lại hiển thị cả 2 gói
      expect(screen.getAllByText('BASIC').length).toBeGreaterThan(0);
      expect(screen.getAllByText('PREMIUM').length).toBeGreaterThan(0);
    });

    it('2.3. Tác động Lưu Phân Quyền & Gọi API thực tế: Thay đổi toggle, lưu và gọi updatePermissions đúng payload', async () => {
      renderWithProviders(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Cảnh báo Chi tiêu Bất thường')).toBeInTheDocument();
      });

      // Ở hàng Gói Basic, bấm bật toggle tính năng anomaly_spending_insights
      const toggleBasic = screen.getByLabelText('Toggle anomaly_spending_insights Basic');
      expect(toggleBasic).toBeInTheDocument();
      fireEvent.click(toggleBasic);

      // Nút Lưu thay đổi được kích hoạt (enabled)
      const saveBtn = screen.getByTestId('btn-save-permissions');
      expect(saveBtn).not.toBeDisabled();

      // Nhấn Lưu Thay Đổi
      fireEvent.click(saveBtn);

      // Modal xác nhận xuất hiện
      await waitFor(() => {
        expect(screen.getByTestId('modal-confirm-save')).toBeInTheDocument();
      });

      // Bấm Xác Nhận Lưu
      const confirmBtn = screen.getByTestId('btn-confirm-save');
      fireEvent.click(confirmBtn);

      // Kiểm tra API được gọi đúng tham số
      await waitFor(() => {
        expect(adminApi.updatePermissions).toHaveBeenCalledTimes(1);
      });

      const calledUpdates = adminApi.updatePermissions.mock.calls[0][0];
      expect(Array.isArray(calledUpdates)).toBe(true);
      expect(calledUpdates[0].feature_id).toBe('anomaly_spending_insights');
      expect(calledUpdates[0].account_type).toBe('Basic');
      expect(calledUpdates[0].is_enabled).toBe(true);
    });
  });
});
