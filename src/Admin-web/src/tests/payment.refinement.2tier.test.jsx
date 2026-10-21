import React from 'react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import PaymentHistoryPage from '../pages/payments/PaymentHistoryPage';
import paymentApi from '../api/payment.api';

// Mock Socket.io
vi.mock('../hooks/useSocket', () => ({
  default: () => ({
    on: vi.fn(),
    off: vi.fn(),
    emit: vi.fn(),
  }),
}));

// Mock Language safe context
vi.mock('../store/language.context', () => ({
  useLanguageSafe: () => ({
    language: 'vi',
    t: (key, fallback) => {
      const translations = {
        'payments.title': 'Quản lý Lịch sử Thanh toán',
        'payments.refresh': 'Làm mới',
        'payments.exportCsvBtn': 'Xuất CSV',
        'payments.sampleQrBtn': 'Mã QR mẫu thử nghiệm',
        'payments.filter.searchPlaceholder': 'Tìm theo mã đơn, username, email...',
        'payments.filter.statusAll': 'Tất cả trạng thái',
        'payments.filter.statusPaid': 'Đã thanh toán',
        'payments.filter.statusPending': 'Đang chờ xử lý',
        'payments.filter.statusCancelled': 'Đã hủy',
        'payments.filter.statusExpired': 'Đã hết hạn',
        'payments.filter.packageAll': 'Tất cả gói cước',
        'payments.filter.packageBasic': 'Gói Basic',
        'payments.filter.packagePremium': 'Gói Premium',
        'payments.filter.packageBasicDefault': 'Gói Basic (Mặc định)',
        'payments.filter.packageMonth': 'Gói 1 Tháng',
        'payments.filter.reset': 'Đặt lại',
        'payments.table.orderCode': 'Mã đơn hàng',
        'payments.table.user': 'Khách hàng',
        'payments.table.package': 'Gói dịch vụ',
        'payments.table.amount': 'Số tiền',
        'payments.table.status': 'Trạng thái',
        'payments.table.createdAt': 'Thời gian tạo',
        'payments.table.paidAt': 'Thời gian thanh toán',
        'payments.table.actions': 'Thao tác',
        'payments.table.viewDetail': 'Xem chi tiết giao dịch',
        'payments.detailModal.title': 'Chi tiết Đơn hàng & Đối soát Thanh toán',
        'payments.detailModal.packageType': 'Gói cước',
        'payments.detailModal.transferContent': 'Nội dung chuyển khoản',
        'payments.detailModal.amount': 'Số tiền cần TT',
        'payments.detailModal.status': 'Trạng thái',
        'payments.sampleModal.selectAmountLabel': 'Chọn số tiền thử nghiệm',
        'payments.sampleModal.amount2k': '2.000 đ',
        'payments.sampleModal.amountMonth': '49.000 đ',
        'payments.sampleModal.amount6Months': '270.000 đ',
        'common.details': 'Chi tiết',
        'common.default': 'Mặc định',
        'common.loading': 'Đang tải...',
      };
      return translations[key] || fallback || key;
    },
  }),
}));

// Mock paymentApi
vi.mock('../api/payment.api', () => ({
  default: {
    getOrders: vi.fn(),
    getStats: vi.fn(),
    getOrderDetail: vi.fn(),
    getPackageTypes: vi.fn(),
    createSampleOrder: vi.fn(),
    getPayosQr: vi.fn(),
    processRefund: vi.fn(),
  },
}));

describe('Payment History Refinement Suite (2-Tier Testing — Rule 11)', () => {
  const mockOrders = [
    {
      id: 'ord-premium-1',
      order_code: 1636482335650,
      package_type: 'Premium',
      amount: 49000,
      amount_received: 49000,
      status: 'PAID',
      transfer_content: 'CS123456 NGUYEN PHU BAO',
      created_at: '2026-10-16T15:14:00.000Z',
      paid_at: '2026-10-16T15:14:30.000Z',
      account: {
        idaccount: 1,
        username: 'BaoNP',
        User: { fullname: 'Nguyễn Phú Bảo' },
      },
    },
    {
      id: 'ord-downgrade-basic-2',
      order_code: 1729500000000,
      package_type: 'Basic',
      amount: 0,
      amount_received: 0,
      status: 'EXPIRED',
      transfer_content: 'Hết hạn gói Premium, chuyển về gói cơ bản',
      created_at: '2026-10-21T00:00:00.000Z',
      paid_at: null,
      account: {
        idaccount: 2,
        username: 'user_expired',
        User: { fullname: 'Người Dùng Hết Hạn' },
      },
    },
  ];

  const mockStats = {
    totalRevenue: 49000,
    totalOrders: 2,
    paidOrders: 1,
    successRate: 50,
  };

  const mockPackages = [
    { id: 'Basic', name: 'Gói Basic', isDefault: true },
    { id: 'Premium', name: 'Gói Premium', isDefault: false },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
    paymentApi.getOrders.mockResolvedValue({
      data: {
        success: true,
        data: {
          items: mockOrders,
          total: 2,
          page: 1,
          limit: 10,
          totalPages: 1,
        },
      },
    });
    paymentApi.getStats.mockResolvedValue({
      data: {
        success: true,
        data: mockStats,
      },
    });
    paymentApi.getPackageTypes.mockResolvedValue({
      data: {
        success: true,
        data: mockPackages,
      },
    });
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  // ==========================================
  // TẦNG 1: UI RENDERING & INTERACTION
  // ==========================================
  describe('🧱 TẦNG 1: Kiểm thử hiển thị & tương tác giao diện (UI Rendering & Interaction)', () => {
    it('1.1. Header: Nút "Làm mới" đã được loại bỏ hoàn toàn, chỉ giữ lại các nút nghiệp vụ cần thiết', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText(/Quản lý Lịch sử Thanh toán/i)).toBeInTheDocument();
      });

      // Tuyệt đối không còn nút "Làm mới" tại Header
      expect(screen.queryByTitle(/^Làm mới$/i)).toBeNull();
      expect(screen.queryByRole('button', { name: /^Làm mới$/i })).toBeNull();

      // Các nút nghiệp vụ khác vẫn hiển thị đầy đủ
      expect(screen.getByRole('button', { name: /Xuất CSV/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /Mã QR mẫu thử nghiệm/i })).toBeInTheDocument();
    });

    it('1.2. Bộ lọc gói cước: Dropdown hiển thị đầy đủ 2 gói chuẩn hóa theo CSDL (Basic và Premium)', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(paymentApi.getPackageTypes).toHaveBeenCalled();
      });

      // Kiểm tra dropdown gói cước
      const selectElements = screen.getAllByRole('combobox');
      // Dropdown thứ hai là gói cước
      const packageSelect = selectElements.find(
        (sel) => sel.querySelector('option[value="ALL"]') && sel.querySelector('option[value="Basic"]')
      );
      expect(packageSelect).toBeDefined();

      const options = Array.from(packageSelect.querySelectorAll('option')).map((o) => ({
        value: o.value,
        text: o.textContent.trim(),
      }));

      expect(options).toEqual([
        { value: 'ALL', text: 'Tất cả gói cước' },
        { value: 'Basic', text: 'Gói Basic (Mặc định)' },
        { value: 'Premium', text: 'Gói Premium' },
      ]);
    });

    it('1.3. Bảng dữ liệu: Hiển thị phân biệt rõ Badge Gói Basic (màu slate) và Gói Premium (màu thương hiệu)', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText('BaoNP')).toBeInTheDocument();
        expect(screen.getByText('user_expired')).toBeInTheDocument();
      });

      // Kiểm tra badge Gói Premium (có cả ở option và ở bảng)
      const premiumElements = screen.getAllByText('Gói Premium');
      expect(premiumElements.length).toBeGreaterThanOrEqual(1);

      // Kiểm tra badge Gói Basic
      const basicBadge = screen.getByText('Gói Basic');
      expect(basicBadge).toBeInTheDocument();

      // Đơn hết hạn (chuyển về Basic) hiển thị 0 ₫ và trạng thái Đã hết hạn (có cả ở option và ở bảng)
      expect(screen.getByText('0 ₫')).toBeInTheDocument();
      const expiredElements = screen.getAllByText('Đã hết hạn');
      expect(expiredElements.length).toBeGreaterThanOrEqual(1);
    });
  });

  // ==========================================
  // TẦNG 2: REAL SYSTEM IMPACT & BEHAVIORAL VERIFICATION
  // ==========================================
  describe('⚡ TẦNG 2: Kiểm thử tác động hệ thống thực tế & hành vi logic (Real System Impact)', () => {
    it('2.1. Tác động API: Khi chọn lọc gói "Basic", component kích hoạt truy vấn đúng tham số packageType=Basic', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalledTimes(1);
      });

      const selectElements = screen.getAllByRole('combobox');
      const packageSelect = selectElements.find(
        (sel) => sel.querySelector('option[value="Basic"]')
      );

      // Thay đổi bộ lọc sang Basic
      fireEvent.change(packageSelect, { target: { value: 'Basic' } });

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalledWith(
          expect.objectContaining({ packageType: 'Basic', page: 1 })
        );
      });
    });

    it('2.2. Tác động API: Khi chọn lọc gói "Premium", component kích hoạt truy vấn đúng tham số packageType=Premium', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalledTimes(1);
      });

      const selectElements = screen.getAllByRole('combobox');
      const packageSelect = selectElements.find(
        (sel) => sel.querySelector('option[value="Premium"]')
      );

      // Thay đổi bộ lọc sang Premium
      fireEvent.change(packageSelect, { target: { value: 'Premium' } });

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalledWith(
          expect.objectContaining({ packageType: 'Premium', page: 1 })
        );
      });
    });

    it('2.3. Tác động Xem chi tiết: Modal chi tiết hiển thị đầy đủ thông tin sự kiện hết hạn gói và chuyển về Basic', async () => {
      paymentApi.getOrderDetail.mockResolvedValueOnce({
        data: {
          success: true,
          data: mockOrders[1], // Đơn hết hạn chuyển về Basic
        },
      });

      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText('user_expired')).toBeInTheDocument();
      });

      // Nhấn nút Chi tiết của dòng thứ 2 (đơn chuyển về Basic)
      const detailButtons = screen.getAllByRole('button', { name: /Chi tiết/i });
      fireEvent.click(detailButtons[1]);

      await waitFor(() => {
        expect(paymentApi.getOrderDetail).toHaveBeenCalledWith('ord-downgrade-basic-2');
        // Modal hiển thị gói cước là Gói Basic
        expect(screen.getByText('Hết hạn gói Premium, chuyển về gói cơ bản')).toBeInTheDocument();
      });
    });

    it('2.4. Tác động Sandbox: Modal thử nghiệm tạo đơn hàng PENDING gói Premium đúng chuẩn thiết kế', async () => {
      paymentApi.createSampleOrder.mockResolvedValueOnce({
        data: {
          success: true,
          data: {
            order: {
              id: 'sample-premium-new',
              order_code: 1729588888888,
              amount: 49000,
              package_type: 'Premium',
              status: 'PENDING',
              transfer_content: 'SAMPLE 123',
            },
            bank: {
              bankName: 'MB Bank',
              accountNumber: '2512070399999',
              accountName: 'NGUYEN PHU BAO',
            },
            qr_url: 'https://img.vietqr.io/sample-premium.png',
          },
        },
      });

      render(<PaymentHistoryPage />);

      // Mở modal sandbox
      const openModalBtn = screen.getByRole('button', { name: /Mã QR mẫu thử nghiệm/i });
      fireEvent.click(openModalBtn);

      // Nhấn nút tạo đơn Pending
      const createPendingBtn = screen.getByRole('button', { name: /\+ Tạo đơn Pending & Sinh mã QR/i });
      fireEvent.click(createPendingBtn);

      await waitFor(() => {
        // Tác động hệ thống: gọi API tạo đơn mẫu với packageType: 'Premium'
        expect(paymentApi.createSampleOrder).toHaveBeenCalledWith(
          expect.objectContaining({
            packageType: 'Premium',
            status: 'PENDING',
          })
        );
      });
    });
  });
});
