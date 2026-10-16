import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import PaymentHistoryPage from '../pages/payments/PaymentHistoryPage';
import paymentApi from '../api/payment.api';

vi.mock('../hooks/useSocket', () => ({
  default: () => ({
    on: vi.fn(),
    off: vi.fn(),
    emit: vi.fn(),
  }),
}));

vi.mock('../api/payment.api', () => ({
  default: {
    getOrders: vi.fn(),
    getStats: vi.fn(),
    getOrderDetail: vi.fn(),
    createSampleOrder: vi.fn(),
    deleteSampleOrders: vi.fn(),
    getPayosQr: vi.fn(),
    simulateWebhook: vi.fn(),
    confirmUpgrade: vi.fn(),
    processRefund: vi.fn(),
  },
}));

describe('Admin-web Payment Suite — PaymentHistoryPage (2-Tier Testing)', () => {
  const mockStats = {
    totalRevenue: 490000,
    totalOrders: 10,
    paidOrders: 8,
    pendingOrders: 1,
    cancelledOrders: 1,
    expiredOrders: 0,
    successRate: 80,
  };

  const mockPayosQr = {
    orderCode: 26101501,
    amount: 49000,
    recognitionCode: 'A8K9M2',
    packageType: 'PREMIUM_1_MONTH',
    bin: '970422',
    bankName: 'MB Bank (Quân Đội)',
    accountNumber: '2512070399999',
    accountName: 'NGUYEN PHU BAO',
    description: 'PFM 26101501',
    checkoutUrl: 'https://pay.payos.vn/web/test-link',
    paymentLinkId: 'sample-link-26101501',
    qrUrl: 'https://img.vietqr.io/image/970422-2512070399999-compact2.png?amount=49000&addInfo=PFM%2026101501&accountName=NGUYEN%20PHU%20BAO',
    qrCode: '00020101021238570010A00000072701270006970422011325120703999990208QRIBFTTA53037045405490005802VN62160812PFM 261015016304ABCD',
  };

  const mockOrders = [
    {
      id: 'ord-uuid-1',
      order_code: 1001,
      package_type: 'PREMIUM_1_MONTH',
      amount: 49000,
      currency: 'VND',
      status: 'PAID',
      created_at: '2026-10-15T08:00:00.000Z',
      paid_at: '2026-10-15T08:05:00.000Z',
      account: {
        idaccount: 15,
        username: 'nguyenvana',
        email: 'vana@example.com',
        type: 'Premium',
        status: 'Active',
        User: { fullname: 'Nguyễn Văn A' },
      },
    },
    {
      id: 'ord-uuid-2',
      order_code: 1002,
      package_type: 'PREMIUM_6_MONTHS',
      amount: 270000,
      currency: 'VND',
      status: 'PENDING',
      created_at: '2026-10-15T09:00:00.000Z',
      paid_at: null,
      account: {
        idaccount: 16,
        username: 'tranthib',
        email: 'thib@example.com',
        type: 'Basic',
        status: 'Active',
        User: { fullname: 'Trần Thị B' },
      },
    },
    {
      id: 'ord-uuid-3',
      order_code: 1003,
      package_type: 'PREMIUM_1_MONTH',
      amount: 49000,
      amount_received: 20000,
      recognition_code: 'B7X2Y1',
      currency: 'VND',
      status: 'REFUND_PENDING',
      created_at: '2026-10-15T10:00:00.000Z',
      paid_at: null,
      account: {
        idaccount: 17,
        username: 'levanc',
        email: 'vanc@example.com',
        type: 'Basic',
        status: 'Active',
        User: { fullname: 'Lê Văn C' },
      },
    },
  ];

  const mockOrderDetail = {
    id: 'ord-uuid-1',
    order_code: 1001,
    package_type: 'PREMIUM_1_MONTH',
    amount: 49000,
    amount_received: 49000,
    recognition_code: 'A8K9M2',
    currency: 'VND',
    status: 'PAID',
    payment_link_id: 'payos-link-abc-123',
    created_at: '2026-10-15T08:00:00.000Z',
    paid_at: '2026-10-15T08:05:00.000Z',
    account: {
      idaccount: 15,
      username: 'nguyenvana',
      email: 'vana@example.com',
      type: 'Premium',
      status: 'Active',
      User: { fullname: 'Nguyễn Văn A' },
    },
    payment_transaction: [
      {
        id: 'tx-1',
        payos_transaction_id: 'bank-ref-9988',
        amount: 49000,
        bank_code: 'MBBANK',
        transaction_time: '2026-10-15T08:05:00.000Z',
        signature_verified: true,
      },
    ],
  };

  beforeEach(() => {
    vi.clearAllMocks();
    paymentApi.getStats.mockResolvedValue({
      data: { success: true, data: mockStats },
    });
    paymentApi.getOrders.mockResolvedValue({
      data: { success: true, data: { items: mockOrders, total: 3, page: 1, limit: 10 } },
    });
    paymentApi.getOrderDetail.mockResolvedValue({
      data: { success: true, data: mockOrderDetail },
    });
    paymentApi.createSampleOrder.mockResolvedValue({
      data: { success: true, data: { order_code: 9999, status: 'PAID' } },
    });
    paymentApi.deleteSampleOrders.mockResolvedValue({
      data: { success: true, data: { deletedCount: 1 } },
    });
    paymentApi.getPayosQr.mockResolvedValue({
      data: { success: true, data: mockPayosQr },
    });
    paymentApi.simulateWebhook.mockResolvedValue({
      data: {
        success: true,
        data: {
          orderCode: 26101501,
          status: 'PAID',
          amountReceived: 49000,
          expectedAmount: 49000,
        },
      },
    });
    paymentApi.confirmUpgrade.mockResolvedValue({
      data: { success: true, message: 'Thành công' },
    });
    paymentApi.processRefund.mockResolvedValue({
      data: { success: true, message: 'Hoàn tiền thành công' },
    });
  });

  // ==========================================
  // TẦNG 1: UI RENDERING & COMPONENT CONTROLS
  // ==========================================
  describe('Tầng 1: Hiển thị & Thao tác tại giao diện (UI Rendering & Interaction)', () => {
    it('1.1. Render đầy đủ tiêu đề, 4 thẻ KPI thống kê doanh thu và đơn hàng', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText(/Lịch sử thanh toán/i)).toBeInTheDocument();
      });

      // Kiểm tra 4 thẻ KPI
      expect(screen.getByText(/Doanh thu thực nhận/i)).toBeInTheDocument();
      expect(screen.getByText('490.000 ₫')).toBeInTheDocument();
      expect(screen.getByText(/Tổng số đơn hàng/i)).toBeInTheDocument();
      expect(screen.getByText('10')).toBeInTheDocument();
      expect(screen.getByText(/Thanh toán thành công/i)).toBeInTheDocument();
      expect(screen.getByText('8')).toBeInTheDocument();
      expect(screen.getByText(/Tỷ lệ thành công/i)).toBeInTheDocument();
      expect(screen.getByText('80%')).toBeInTheDocument();
    });

    it('1.2. Render đầy đủ bảng danh sách đơn hàng với badges trạng thái chuẩn', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText('#1001')).toBeInTheDocument();
        expect(screen.getByText('#1002')).toBeInTheDocument();
        expect(screen.getByText('#1003')).toBeInTheDocument();
      });

      // Kiểm tra tên người dùng và số tiền
      expect(screen.getByText('nguyenvana')).toBeInTheDocument();
      expect(screen.getByText('tranthib')).toBeInTheDocument();
      expect(screen.getByText('levanc')).toBeInTheDocument();

      // Kiểm tra badge trạng thái
      expect(screen.getAllByText(/Đã thanh toán/i).length).toBeGreaterThanOrEqual(1);
      expect(screen.getAllByText(/Đang chờ xử lý/i).length).toBeGreaterThanOrEqual(1);
      expect(screen.getAllByText(/Cần hoàn trả/i).length).toBeGreaterThanOrEqual(1);

      // Nút Hoàn tiền cho đơn REFUND_PENDING
      expect(screen.getByTitle(/Hoàn tiền/i)).toBeInTheDocument();
    });

    it('1.3. Click nút "Chi tiết" mở Modal hiển thị thông tin đối soát giao dịch', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText('#1001')).toBeInTheDocument();
      });

      const detailButtons = screen.getAllByTitle(/Xem chi tiết giao dịch/i);
      expect(detailButtons.length).toBeGreaterThan(0);

      fireEvent.click(detailButtons[0]);

      await waitFor(() => {
        expect(screen.getByText(/Chi tiết Đơn hàng & Đối soát/i)).toBeInTheDocument();
      });

      // Kiểm tra thông tin trong modal
      expect(screen.getByText('payos-link-abc-123')).toBeInTheDocument();
      expect(screen.getByText('MBBANK')).toBeInTheDocument();
      expect(screen.getByText('bank-ref-9988')).toBeInTheDocument();
      expect(screen.getByText(/Hợp lệ \(Đã xác thực\)/i)).toBeInTheDocument();

      // Đóng modal
      const closeButtons = screen.getAllByRole('button', { name: /Đóng/i });
      fireEvent.click(closeButtons[closeButtons.length - 1]);

      await waitFor(() => {
        expect(screen.queryByText(/Chi tiết Đơn hàng & Đối soát/i)).not.toBeInTheDocument();
      });
    });

    it('1.4. Click nút "Mã QR mẫu thử nghiệm" mở modal Sandbox hiển thị mã QR, 6 ký tự nhận diện và đồng hồ đếm ngược', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText(/Lịch sử thanh toán/i)).toBeInTheDocument();
      });

      const qrBtn = screen.getByTitle(/Mã QR mẫu thử nghiệm/i);
      fireEvent.click(qrBtn);

      await waitFor(() => {
        expect(screen.getByText(/Mô phỏng Giao dịch Client-app \(Admin Sandbox\)/i)).toBeInTheDocument();
      });

      // Kiểm tra mã nhận diện 6 ký tự
      expect(screen.getByText('A8K9M2')).toBeInTheDocument();

      // Kiểm tra 10 phút đếm ngược (định dạng mm:ss)
      expect(screen.getByText(/10:00|09:59/)).toBeInTheDocument();

      // Kiểm tra ảnh QR
      const qrImg = screen.getByAltText(/Mã QR Kênh Thanh Toán PayOS MB Bank/i);
      expect(qrImg).toBeInTheDocument();

      // Kiểm tra các nút hành động mô phỏng
      expect(screen.getByText(/Giả lập Chuyển đúng tiền \(49k\)/i)).toBeInTheDocument();
      expect(screen.getByText(/Giả lập Chuyển thừa tiền \(70k\)/i)).toBeInTheDocument();
      expect(screen.getByText(/Giả lập Chuyển thiếu tiền \(20k\)/i)).toBeInTheDocument();
    });

    it('1.5. Click nút "Hoàn tiền" trên dòng đơn hàng REFUND_PENDING mở modal Hoàn tiền', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText('#1003')).toBeInTheDocument();
      });

      const refundBtn = screen.getByTitle(/Hoàn tiền/i);
      fireEvent.click(refundBtn);

      await waitFor(() => {
        expect(screen.getByText(/Xử lý Hoàn tiền cho Khách hàng/i)).toBeInTheDocument();
      });

      // Kiểm tra form nhập liệu
      expect(screen.getByText(/Số tiền thực tế hoàn trả/i)).toBeInTheDocument();
      expect(screen.getByText(/Lý do hoàn trả/i)).toBeInTheDocument();
      expect(screen.getByText(/Đường dẫn ảnh minh chứng/i)).toBeInTheDocument();

      // Nút hủy đóng modal
      const cancelBtn = screen.getByRole('button', { name: /Hủy bỏ/i });
      fireEvent.click(cancelBtn);

      await waitFor(() => {
        expect(screen.queryByText(/Xử lý Hoàn tiền cho Khách hàng/i)).not.toBeInTheDocument();
      });
    });
  });

  // ==========================================
  // TẦNG 2: SYSTEM IMPACT & API BEHAVIOR
  // ==========================================
  describe('Tầng 2: Kiểm thử hoạt động thực tế & tác động hệ thống (System Impact)', () => {
    it('2.1. Thao tác chọn Dropdown trạng thái kích hoạt gọi API paymentApi.getOrders với tham số status', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalledWith(
          expect.objectContaining({ page: 1, limit: 10 })
        );
      });

      // Lọc theo trạng thái PAID
      const statusSelect = screen.getByDisplayValue(/Tất cả trạng thái/i);
      fireEvent.change(statusSelect, { target: { value: 'PAID' } });

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalledWith(
          expect.objectContaining({ status: 'PAID', page: 1 })
        );
      });
    });

    it('2.2. Nhập tìm kiếm kích hoạt gọi API paymentApi.getOrders với tham số search', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalled();
      });

      const searchInput = screen.getByPlaceholderText(/Tìm theo mã đơn, username, email/i);
      fireEvent.change(searchInput, { target: { value: 'nguyenvana' } });

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalledWith(
          expect.objectContaining({ search: 'nguyenvana', page: 1 })
        );
      });
    });

    it('2.3. Chọn khoảng ngày kích hoạt cập nhật cả getStats và getOrders với fromDate/toDate', async () => {
      const { container } = render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(paymentApi.getStats).toHaveBeenCalled();
      });

      const dateInputs = container.querySelectorAll('input[type="date"]');
      expect(dateInputs.length).toBe(2);

      fireEvent.change(dateInputs[0], { target: { value: '2026-10-01' } });
      fireEvent.change(dateInputs[1], { target: { value: '2026-10-15' } });

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalledWith(
          expect.objectContaining({ fromDate: '2026-10-01', toDate: '2026-10-15' })
        );
        expect(paymentApi.getStats).toHaveBeenCalledWith(
          expect.objectContaining({ fromDate: '2026-10-01', toDate: '2026-10-15' })
        );
      });
    });

    it('2.4. Nút "Làm mới" kích hoạt tải lại toàn bộ dữ liệu thực tế và hiển thị toast phản hồi', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalledTimes(1);
        expect(paymentApi.getStats).toHaveBeenCalledTimes(1);
      });

      const refreshBtn = screen.getByTitle(/Làm mới/i);
      fireEvent.click(refreshBtn);

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalledTimes(2);
        expect(paymentApi.getStats).toHaveBeenCalledTimes(2);
        expect(screen.getByText(/Đã làm mới dữ liệu thanh toán thành công/i)).toBeInTheDocument();
      });
    });

    it('2.5. Nút "Đặt lại" xóa sạch các bộ lọc và gọi lại API với giá trị mặc định', async () => {
      render(<PaymentHistoryPage />);

      const searchInput = screen.getByPlaceholderText(/Tìm theo mã đơn, username, email/i);
      fireEvent.change(searchInput, { target: { value: 'test' } });

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalledWith(
          expect.objectContaining({ search: 'test' })
        );
      });

      const resetBtn = screen.getByText(/Đặt lại/i);
      fireEvent.click(resetBtn);

      await waitFor(() => {
        expect(searchInput.value).toBe('');
        expect(paymentApi.getOrders).toHaveBeenCalledWith(
          expect.not.objectContaining({ search: 'test' })
        );
      });
    });

    it('2.6. Thao tác click Giả lập Chuyển đúng tiền (49k) gọi paymentApi.simulateWebhook', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText(/Lịch sử thanh toán/i)).toBeInTheDocument();
      });

      // Mở modal sandbox
      const qrBtn = screen.getByTitle(/Mã QR mẫu thử nghiệm/i);
      fireEvent.click(qrBtn);

      await waitFor(() => {
        expect(screen.getByText(/Giả lập Chuyển đúng tiền \(49k\)/i)).toBeInTheDocument();
      });

      const exactBtn = screen.getByText(/Giả lập Chuyển đúng tiền \(49k\)/i);
      fireEvent.click(exactBtn);

      await waitFor(() => {
        expect(paymentApi.simulateWebhook).toHaveBeenCalledWith({
          orderCode: 26101501,
          amount: 49000,
          recognitionCode: 'A8K9M2',
        });
      });
    });

    it('2.7. Thao tác click Giả lập Chuyển thừa tiền (70k) hiển thị prompt xác nhận và gọi paymentApi.confirmUpgrade', async () => {
      paymentApi.simulateWebhook.mockResolvedValueOnce({
        data: {
          success: true,
          data: {
            orderCode: 26101501,
            status: 'WAITING_CONFIRMATION',
            amountReceived: 70000,
            expectedAmount: 49000,
          },
        },
      });

      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText(/Lịch sử thanh toán/i)).toBeInTheDocument();
      });

      const qrBtn = screen.getByTitle(/Mã QR mẫu thử nghiệm/i);
      fireEvent.click(qrBtn);

      await waitFor(() => {
        expect(screen.getByText(/Giả lập Chuyển thừa tiền \(70k\)/i)).toBeInTheDocument();
      });

      const overpaidBtn = screen.getByText(/Giả lập Chuyển thừa tiền \(70k\)/i);
      fireEvent.click(overpaidBtn);

      await waitFor(() => {
        expect(screen.getByText(/Phát hiện chuyển thừa tiền!/i)).toBeInTheDocument();
      });

      // Bấm nút Đồng ý kích hoạt
      const acceptBtn = screen.getByText(/Đồng ý kích hoạt/i);
      fireEvent.click(acceptBtn);

      await waitFor(() => {
        expect(paymentApi.confirmUpgrade).toHaveBeenCalledWith({
          orderCode: 26101501,
          accept: true,
        });
      });
    });

    it('2.8. Điền và submit form hoàn tiền gọi paymentApi.processRefund và cập nhật danh sách', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText('#1003')).toBeInTheDocument();
      });

      const refundBtn = screen.getByTitle(/Hoàn tiền/i);
      fireEvent.click(refundBtn);

      await waitFor(() => {
        expect(screen.getByText(/Xử lý Hoàn tiền cho Khách hàng/i)).toBeInTheDocument();
      });

      // Submit form
      const submitBtn = screen.getByRole('button', { name: /Xác nhận Đã hoàn tiền/i });
      fireEvent.click(submitBtn);

      await waitFor(() => {
        expect(paymentApi.processRefund).toHaveBeenCalledWith(
          'ord-uuid-3',
          expect.objectContaining({
            refunded_amount: 20000,
            refund_reason: expect.any(String),
          })
        );
        expect(screen.getByText(/Đã hoàn tiền và cập nhật trạng thái đơn hàng thành công!/i)).toBeInTheDocument();
      });
    });
  });
});
