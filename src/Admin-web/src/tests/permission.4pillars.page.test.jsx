import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import PermissionManagementPage from '../pages/system/PermissionManagementPage';
import adminApi from '../api/admin.api';

let socketCallback = null;

vi.mock('../api/admin.api', () => ({
  default: {
    getPermissions: vi.fn(),
    updatePermissions: vi.fn(),
    resetPermissionsDefault: vi.fn(),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: () => ({
    on: vi.fn((event, cb) => {
      if (event === 'account.permissions_updated') {
        socketCallback = cb;
      }
    }),
    off: vi.fn(),
  }),
}));

const mockAlert = {
  success: vi.fn(),
  error: vi.fn(),
  info: vi.fn(),
  warning: vi.fn(),
};

vi.mock('../store/alert.context', () => ({
  useAlertSafe: () => mockAlert,
}));

describe('Admin-web 4 Pillars Permission Suite — 2-Tier Testing (Rule 11 Compliance)', () => {
  const mockFeatures = [
    {
      id: 'wallets',
      name: 'Quản lý Ví tiền & Tài sản',
      type: 'LIMIT',
      category_group: 'Quản lý Ví & Tài sản',
      description: 'Số lượng ví tiền hoạt động tối đa có thể quản lý',
      default_downgrade_policy: 'BLOCK_CREATE',
      scope_schema: { max_active_wallets: 'number' },
    },
    {
      id: 'export_reports',
      name: 'Xuất Dữ liệu & Báo cáo',
      type: 'TOGGLE',
      category_group: 'Báo cáo & Phân tích',
      description: 'Xuất báo cáo tài chính dạng Excel/PDF/CSV',
      default_downgrade_policy: 'LOCK_FEATURE',
      scope_schema: { formats: ['csv', 'excel', 'pdf'] },
    },
    {
      id: 'ai_assistant',
      name: 'Trợ lý Tài chính AI Copilot',
      type: 'TOGGLE',
      category_group: 'Trí tuệ nhân tạo & Edge AI',
      description: 'Cố vấn tài chính thông minh qua Gemini',
      default_downgrade_policy: 'LOCK_FEATURE',
      scope_schema: { daily_quota: 50 },
    },
  ];

  const mockPermissions = {
    Basic: {
      wallets: {
        is_enabled: true,
        limit_value: 3,
        scope_config: { max_active_wallets: 3 },
        downgrade_policy: 'BLOCK_CREATE',
      },
      export_reports: {
        is_enabled: false,
        limit_value: null,
        scope_config: { formats: ['csv'] },
        downgrade_policy: 'LOCK_FEATURE',
      },
      ai_assistant: {
        is_enabled: false,
        limit_value: null,
        scope_config: {},
        downgrade_policy: 'LOCK_FEATURE',
      },
    },
    Premium: {
      wallets: {
        is_enabled: true,
        limit_value: null,
        scope_config: { max_active_wallets: 999 },
        downgrade_policy: 'BLOCK_CREATE',
      },
      export_reports: {
        is_enabled: true,
        limit_value: null,
        scope_config: { formats: ['csv', 'excel', 'pdf'] },
        downgrade_policy: 'LOCK_FEATURE',
      },
      ai_assistant: {
        is_enabled: true,
        limit_value: null,
        scope_config: { daily_quota: 50 },
        downgrade_policy: 'LOCK_FEATURE',
      },
    },
  };

  beforeEach(() => {
    vi.clearAllMocks();
    socketCallback = null;
    adminApi.getPermissions.mockResolvedValue({
      data: {
        features: mockFeatures,
        permissions: mockPermissions,
      },
    });
    adminApi.updatePermissions.mockResolvedValue({
      success: true,
      data: { updatedCount: 1 },
    });
    adminApi.resetPermissionsDefault.mockResolvedValue({
      success: true,
      message: 'Reset default permissions successfully',
    });
  });

  // ========================================================
  // TẦNG 1: HIỂN THỊ & THAO TÁC GIAO DIỆN (UI RENDERING & INTERACTION)
  // ========================================================
  describe('🧱 TẦNG 1: Kiểm thử hiển thị bảng mật độ cao & tương tác giao diện', () => {
    it('1.1. Render đầy đủ Toolbar tối giản, thanh Realtime và bảng ma trận không dùng card cồng kềnh', async () => {
      render(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Quản lý Ví tiền & Tài sản')).toBeInTheDocument();
      });

      // Kiểm tra các cột trong bảng ma trận
      expect(screen.getByText('Xuất Dữ liệu & Báo cáo')).toBeInTheDocument();
      expect(screen.getByText('Trợ lý Tài chính AI Copilot')).toBeInTheDocument();

      // Kiểm tra slug id dạng code
      expect(screen.getByText('wallets')).toBeInTheDocument();
      expect(screen.getByText('export_reports')).toBeInTheDocument();
      expect(screen.getByText('ai_assistant')).toBeInTheDocument();

      // Kiểm tra badges
      const limitBadges = screen.getAllByText('LIMIT');
      expect(limitBadges.length).toBeGreaterThan(0);
      const toggleBadges = screen.getAllByText('TOGGLE');
      expect(toggleBadges.length).toBeGreaterThan(0);
    });

    it('1.2. Thao tác tìm kiếm và lọc phân hệ làm thay đổi danh sách hiển thị', async () => {
      render(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Quản lý Ví tiền & Tài sản')).toBeInTheDocument();
      });

      // Tìm kiếm từ khóa 'ai_assistant' qua data-testid
      const searchInput = screen.getByTestId('input-search-features');
      fireEvent.change(searchInput, { target: { value: 'ai_assistant' } });

      expect(screen.queryByText('Quản lý Ví tiền & Tài sản')).not.toBeInTheDocument();
      expect(screen.getByText('Trợ lý Tài chính AI Copilot')).toBeInTheDocument();

      // Xóa tìm kiếm
      fireEvent.change(searchInput, { target: { value: '' } });
      expect(screen.getByText('Quản lý Ví tiền & Tài sản')).toBeInTheDocument();
    });

    it('1.3. Mở Drawer Inspector Trụ 3 & 4 khi bấm nút Scope & Policy', async () => {
      render(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Quản lý Ví tiền & Tài sản')).toBeInTheDocument();
      });

      // Tìm các nút cấu hình Scope & Policy
      const scopeButtons = screen.getAllByTitle(/Cấu hình Trụ 3 & 4/i);
      expect(scopeButtons.length).toBeGreaterThan(0);

      // Bấm nút cấu hình của tính năng đầu tiên (wallets - Basic)
      fireEvent.click(scopeButtons[0]);

      // Drawer mở ra
      await waitFor(() => {
        expect(screen.getByText('Cấu Hình Chuyên Sâu (Trụ 3 & 4)')).toBeInTheDocument();
        expect(screen.getByTestId('select-downgrade-policy')).toBeInTheDocument();
        expect(screen.getByTestId('textarea-scope-json')).toBeInTheDocument();
      });

      // Đóng Drawer bằng btn-close-drawer
      const closeBtn = screen.getByTestId('btn-close-drawer');
      fireEvent.click(closeBtn);

      await waitFor(() => {
        expect(screen.queryByText('Cấu Hình Chuyên Sâu (Trụ 3 & 4)')).not.toBeInTheDocument();
      });
    });

    it('1.4. Chỉnh sửa Scope & Policy trong Drawer và bấm Áp dụng cập nhật vào bản nháp', async () => {
      render(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Quản lý Ví tiền & Tài sản')).toBeInTheDocument();
      });

      const scopeButtons = screen.getAllByTitle(/Cấu hình Trụ 3 & 4/i);
      fireEvent.click(scopeButtons[0]);

      await waitFor(() => {
        expect(screen.getByTestId('select-downgrade-policy')).toBeInTheDocument();
      });

      // Sửa chính sách hạ cấp sang READ_ONLY
      const policySelect = screen.getByTestId('select-downgrade-policy');
      fireEvent.change(policySelect, { target: { value: 'READ_ONLY' } });

      // Bấm "Áp dụng vào bản nháp"
      const applyBtn = screen.getByTestId('btn-apply-drawer');
      fireEvent.click(applyBtn);

      // Chờ Drawer đóng
      await waitFor(() => {
        expect(screen.queryByText('Cấu Hình Chuyên Sâu (Trụ 3 & 4)')).not.toBeInTheDocument();
      });

      // Nút Lưu thay đổi được kích hoạt (enabled)
      const saveBtn = screen.getByTestId('btn-save-permissions');
      expect(saveBtn).not.toBeDisabled();
    });

    it('1.5. Chuyển đổi View Mode giữa Đối Chiếu 2 Gói, Gói Basic và Gói Premium', async () => {
      render(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Quản lý Ví tiền & Tài sản')).toBeInTheDocument();
      });

      // Mặc định là viewMode = ALL: có cả badge BASIC và PREMIUM
      expect(screen.getAllByText('BASIC').length).toBeGreaterThan(0);
      expect(screen.getAllByText('PREMIUM').length).toBeGreaterThan(0);

      // Chuyển sang Tab Gói Basic
      const basicTabBtn = screen.getByTestId('tab-viewmode-basic');
      fireEvent.click(basicTabBtn);

      // Bây giờ chỉ còn badge BASIC, không còn badge PREMIUM
      expect(screen.getAllByText('BASIC').length).toBeGreaterThan(0);
      expect(screen.queryByText('PREMIUM')).not.toBeInTheDocument();

      // Chuyển sang Tab Gói Premium
      const premTabBtn = screen.getByTestId('tab-viewmode-premium');
      fireEvent.click(premTabBtn);

      expect(screen.getAllByText('PREMIUM').length).toBeGreaterThan(0);
      expect(screen.queryByText('BASIC')).not.toBeInTheDocument();

      // Quay lại Tab Đối Chiếu 2 Gói
      const allTabBtn = screen.getByTestId('tab-viewmode-all');
      fireEvent.click(allTabBtn);

      expect(screen.getAllByText('BASIC').length).toBeGreaterThan(0);
      expect(screen.getAllByText('PREMIUM').length).toBeGreaterThan(0);
    });
  });

  // ========================================================
  // TẦNG 2: TÁC ĐỘNG HỆ THỐNG THỰC TẾ (REAL SYSTEM IMPACT - RULE 11)
  // ========================================================
  describe('⚡ TẦNG 2: Tác động hệ thống thực sự (API, 4 Pillars Payload, Socket Realtime)', () => {
    it('2.1. Nút Lưu Thay Đổi gọi đúng PUT /admin/permissions mang trọn vẹn 4 trụ cột', async () => {
      render(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Quản lý Ví tiền & Tài sản')).toBeInTheDocument();
      });

      // Mở Drawer tính năng xuất báo cáo cho Basic (index 2)
      const scopeButtons = screen.getAllByTitle(/Cấu hình Trụ 3 & 4/i);
      fireEvent.click(scopeButtons[2]);

      await waitFor(() => {
        expect(screen.getByTestId('select-downgrade-policy')).toBeInTheDocument();
      });

      // Đổi policy sang GRACE_PERIOD_3D
      const policySelect = screen.getByTestId('select-downgrade-policy');
      fireEvent.change(policySelect, { target: { value: 'GRACE_PERIOD_3D' } });

      // Đổi Scope JSON
      const jsonTextarea = screen.getByTestId('textarea-scope-json');
      fireEvent.change(jsonTextarea, {
        target: { value: JSON.stringify({ formats: ['csv', 'excel'] }) },
      });

      // Áp dụng vào bản nháp
      const applyBtn = screen.getByTestId('btn-apply-drawer');
      fireEvent.click(applyBtn);

      // Chờ drawer đóng và pendingUpdates cập nhật
      await waitFor(() => {
        expect(screen.queryByText('Cấu Hình Chuyên Sâu (Trụ 3 & 4)')).not.toBeInTheDocument();
      });

      // Bấm nút Lưu thay đổi
      const saveBtn = screen.getByTestId('btn-save-permissions');
      await waitFor(() => {
        expect(saveBtn).not.toBeDisabled();
      });
      fireEvent.click(saveBtn);

      // Modal xác nhận xuất hiện
      await waitFor(() => {
        expect(screen.getByTestId('modal-confirm-save')).toBeInTheDocument();
      });

      // Bấm Xác Nhận Lưu Ngay trong modal qua data-testid
      const confirmSaveBtn = screen.getByTestId('btn-confirm-save');
      fireEvent.click(confirmSaveBtn);

      // SYSTEM IMPACT: Kiểm tra API được gọi với đầy đủ 4 trụ cột
      await waitFor(() => {
        expect(adminApi.updatePermissions).toHaveBeenCalledTimes(1);
        const calledPayload = adminApi.updatePermissions.mock.calls[0][0];
        expect(Array.isArray(calledPayload)).toBe(true);

        const updatedExport = calledPayload.find(
          (item) => item.feature_id === 'export_reports' && item.account_type === 'Basic'
        );
        expect(updatedExport).toBeDefined();
        // Trụ 1: is_enabled
        expect(updatedExport).toHaveProperty('is_enabled');
        // Trụ 2: limit_value
        expect(updatedExport).toHaveProperty('limit_value');
        // Trụ 3: scope_config
        expect(updatedExport.scope_config).toEqual({ formats: ['csv', 'excel'] });
        // Trụ 4: downgrade_policy
        expect(updatedExport.downgrade_policy).toBe('GRACE_PERIOD_3D');
      });

      // Toast thông báo thành công
      expect(mockAlert.success).toHaveBeenCalled();
    });

    it('2.2. Khôi Phục Mặc Định gọi đúng POST /admin/permissions/reset và cập nhật lại ma trận', async () => {
      render(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Quản lý Ví tiền & Tài sản')).toBeInTheDocument();
      });

      // Bấm nút Khôi Phục Mặc Định trên Toolbar
      const resetDefaultBtn = screen.getByTestId('btn-reset-default');
      fireEvent.click(resetDefaultBtn);

      // Modal xác nhận khôi phục mở ra
      await waitFor(() => {
        expect(screen.getByTestId('modal-confirm-reset')).toBeInTheDocument();
      });

      // Bấm nút Xác Nhận Khôi Phục
      const confirmResetBtn = screen.getByTestId('btn-confirm-reset');
      fireEvent.click(confirmResetBtn);

      // SYSTEM IMPACT: Gọi đúng API reset và sau đó gọi lại getPermissions
      await waitFor(() => {
        expect(adminApi.resetPermissionsDefault).toHaveBeenCalledTimes(1);
        expect(adminApi.getPermissions).toHaveBeenCalledTimes(2); // 1 lần ban đầu + 1 lần sau reset
      });

      expect(mockAlert.success).toHaveBeenCalled();
    });

    it('2.3. Nhận sự kiện Socket.IO account.permissions_updated kích hoạt làm mới ma trận thời gian thực', async () => {
      render(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Quản lý Ví tiền & Tài sản')).toBeInTheDocument();
      });

      expect(adminApi.getPermissions).toHaveBeenCalledTimes(1);
      expect(socketCallback).toBeTypeOf('function');

      // Giả lập sự kiện Socket.IO phát sóng từ Backend khi admin khác thay đổi cấu hình
      socketCallback({ account_types: ['Basic', 'Premium'] });

      // SYSTEM IMPACT: Trang tự động gọi lại getPermissions để đồng bộ dữ liệu mới nhất
      await waitFor(() => {
        expect(adminApi.getPermissions).toHaveBeenCalledTimes(2);
      });
    });

    it('2.4. Chỉnh sửa Downgrade Policy trực tiếp từ dropdown trên dòng bảng ma trận ghi nhận dirty và lưu thành công', async () => {
      render(<PermissionManagementPage />);

      await waitFor(() => {
        expect(screen.getByText('Quản lý Ví tiền & Tài sản')).toBeInTheDocument();
      });

      // Tìm select policy của wallets Basic bằng aria-label
      const policySelect = screen.getByLabelText('Policy wallets Basic');
      expect(policySelect).toBeInTheDocument();
      expect(policySelect.value).toBe('BLOCK_CREATE');

      // Thay đổi sang LOCK_FEATURE trực tiếp trên bảng
      fireEvent.change(policySelect, { target: { value: 'LOCK_FEATURE' } });
      expect(policySelect.value).toBe('LOCK_FEATURE');

      // Nút Lưu thay đổi được kích hoạt
      const saveBtn = screen.getByTestId('btn-save-permissions');
      await waitFor(() => {
        expect(saveBtn).not.toBeDisabled();
      });
      fireEvent.click(saveBtn);

      // Modal xác nhận lưu xuất hiện
      await waitFor(() => {
        expect(screen.getByTestId('modal-confirm-save')).toBeInTheDocument();
      });

      // Bấm Xác nhận lưu
      const confirmSaveBtn = screen.getByTestId('btn-confirm-save');
      fireEvent.click(confirmSaveBtn);

      // SYSTEM IMPACT: Kiểm tra API nhận đúng downgrade_policy đã thay đổi
      await waitFor(() => {
        expect(adminApi.updatePermissions).toHaveBeenCalled();
        const calledPayload = adminApi.updatePermissions.mock.calls[0][0];
        const updatedWallet = calledPayload.find(
          (item) => item.feature_id === 'wallets' && item.account_type === 'Basic'
        );
        expect(updatedWallet).toBeDefined();
        expect(updatedWallet.downgrade_policy).toBe('LOCK_FEATURE');
      });

      expect(mockAlert.success).toHaveBeenCalled();
    });
  });
});

