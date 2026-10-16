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
    getPackageTypes: vi.fn(),
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
      is_template: false,
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
      is_template: true,
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
      is_template: false,
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
    paymentApi.getPackageTypes.mockResolvedValue({
      data: [
        { id: 'Basic', name: 'Gói Basic', isDefault: true },
        { id: 'Premium', name: 'Gói Premium', isDefault: false },
      ],
    });
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
      data: {
        success: true,
        data: {
          id: 'sample-ord-9999',
          order_code: 9999,
          status: 'PENDING',
          package_type: 'PREMIUM_1_MONTH',
          amount: 49000,
          recognition_code: 'TST123',
          qr_url: 'https://img.vietqr.io/image/970422-2512070399999-compact2.png',
          transfer_content: 'TST123',
          bank_info: {
            bankName: 'MB Bank (Quân Đội)',
            accountNumber: '2512070399999',
            accountName: 'NGUYEN PHU BAO',
          },
        },
      },
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

      // Kiểm tra badge Mẫu
      expect(screen.getByText('Mẫu')).toBeInTheDocument();

      // Kiểm tra badge trạng thái
      expect(screen.getAllByText(/Đã thanh toán/i).length).toBeGreaterThanOrEqual(1);
      expect(screen.getAllByText(/Đang chờ xử lý/i).length).toBeGreaterThanOrEqual(1);
      expect(screen.getAllByText(/Cần hoàn trả/i).length).toBeGreaterThanOrEqual(1);

      // Nút Hoàn tiền cho đơn REFUND_PENDING (enabled) và đơn khác (disabled)
      const refundBtns = screen.getAllByTitle(/Hoàn tiền|Chỉ khả dụng khi đơn hàng cần hoàn trả/i);
      expect(refundBtns.length).toBe(3);
      expect(refundBtns[0]).toBeDisabled();
      expect(refundBtns[1]).toBeDisabled();
      expect(refundBtns[2]).not.toBeDisabled();
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

    it('1.4. Click nút "Mã QR mẫu thử nghiệm" mở modal Sandbox ban đầu chưa có QR, nhấn "Tạo đơn Pending & Sinh mã QR" hiển thị mã QR và đếm ngược', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText(/Lịch sử thanh toán/i)).toBeInTheDocument();
      });

      const qrBtn = screen.getByTitle(/Mã QR mẫu thử nghiệm/i);
      fireEvent.click(qrBtn);

      await waitFor(() => {
        expect(screen.getByText(/Mô phỏng Giao dịch Client-app \(Admin Sandbox\)/i)).toBeInTheDocument();
        expect(screen.getByText(/Chưa kích hoạt đơn kiểm thử nào/i)).toBeInTheDocument();
      });

      // Nhấn nút Tạo đơn Pending & Sinh mã QR
      const createPendingBtn = screen.getByRole('button', { name: /\+ Tạo đơn Pending & Sinh mã QR/i });
      fireEvent.click(createPendingBtn);

      await waitFor(() => {
        // Kiểm tra mã nhận diện 6 ký tự từ đơn hàng vừa tạo
        expect(screen.getAllByText('TST123').length).toBeGreaterThanOrEqual(1);
        // Kiểm tra 10 phút đếm ngược (định dạng mm:ss)
        expect(screen.getByText(/10:00|09:59/)).toBeInTheDocument();
        // Kiểm tra ảnh QR
        const qrImg = screen.getByAltText(/Mã QR Kênh Thanh Toán PayOS MB Bank/i);
        expect(qrImg).toBeInTheDocument();
      });

      // Xác nhận 3 nút giả lập webhook cũ không còn tồn tại
      expect(screen.queryByText(/Giả lập Chuyển đúng tiền/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Giả lập Chuyển thừa tiền/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Giả lập Chuyển thiếu tiền/i)).not.toBeInTheDocument();
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
      expect(screen.getByText(/Tải lên ảnh minh chứng/i)).toBeInTheDocument();

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

    it('2.6. Mở modal Sandbox ban đầu chưa có QR, nhấn Tạo đơn Pending mới sinh QR và reload danh sách', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText(/Lịch sử thanh toán/i)).toBeInTheDocument();
      });

      // Mở modal sandbox
      const qrBtn = screen.getByTitle(/Mã QR mẫu thử nghiệm/i);
      fireEvent.click(qrBtn);

      // Ban đầu CHƯA CÓ QR, hiển thị empty state
      await waitFor(() => {
        expect(screen.getByText(/Chưa kích hoạt đơn kiểm thử nào/i)).toBeInTheDocument();
      });

      // Nhấn nút Tạo đơn Pending & Sinh mã QR
      const createPendingBtn = screen.getByRole('button', { name: /\+ Tạo đơn Pending & Sinh mã QR/i });
      fireEvent.click(createPendingBtn);

      await waitFor(() => {
        expect(paymentApi.createSampleOrder).toHaveBeenCalledWith({
          simulateWebhook: false,
          status: 'PENDING',
          packageType: 'PREMIUM_1_MONTH',
          amount: 49000,
        });
        // Sau khi tạo đơn, hiển thị mã đơn và STK MB Bank
        expect(screen.getByText(/#9999/)).toBeInTheDocument();
        expect(screen.getByText('2512070399999')).toBeInTheDocument();
        // Tự động reload danh sách
        expect(paymentApi.getOrders).toHaveBeenCalled();
      });
    });

    it('2.7. Xem chi tiết đơn hàng (Modal Chi tiết): Đơn đã PAID xóa mã QR và hiển thị banner hoàn tất; Đơn PENDING hiển thị mã QR', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText('#1001')).toBeInTheDocument();
      });

      // Click xem chi tiết đơn #1001 (PAID)
      const detailButtons = screen.getAllByTitle(/Xem chi tiết/i);
      fireEvent.click(detailButtons[0]);

      await waitFor(() => {
        expect(paymentApi.getOrderDetail).toHaveBeenCalledWith('ord-uuid-1');
        expect(screen.getByText(/Đã thanh toán thành công/i)).toBeInTheDocument();
        expect(screen.queryByAltText(/VietQR MB Bank/i)).not.toBeInTheDocument();
      });

      // Đóng modal
      const closeButtons = screen.getAllByRole('button');
      const closeBtn = closeButtons.find(b => b.innerHTML.includes('close'));
      if (closeBtn) fireEvent.click(closeBtn);

      // Mock getOrderDetail cho đơn #1002 (PENDING còn hạn)
      paymentApi.getOrderDetail.mockResolvedValueOnce({
        id: 'ord-uuid-2',
        order_code: 1002,
        package_type: 'PREMIUM_6_MONTHS',
        amount: 270000,
        amount_received: 0,
        recognition_code: 'XYZ123',
        status: 'PENDING',
        qr_url: 'https://img.vietqr.io/image/test-qr.png',
        created_at: new Date().toISOString(),
        expired_at: new Date(Date.now() + 600000).toISOString(),
      });

      // Click xem chi tiết đơn #1002 (PENDING)
      fireEvent.click(detailButtons[1]);

      await waitFor(() => {
        expect(screen.getByText(/Mã QR Thanh toán VietQR \(MB Bank\)/i)).toBeInTheDocument();
        expect(screen.getByAltText(/VietQR MB Bank/i)).toBeInTheDocument();
        expect(screen.getByText(/Thời gian còn lại/i)).toBeInTheDocument();
      });
    });

    it('2.7b. Đơn hàng EXPIRED: Modal chi tiết và Bảng ngoài đồng bộ hiển thị "Đã hết hạn", xóa QR hoàn toàn', async () => {
      paymentApi.getOrders.mockResolvedValue({
        data: {
          success: true,
          data: {
            items: [
              {
                id: 'ord-uuid-expired',
                order_code: 9999,
                package_type: 'PREMIUM_1_MONTH',
                amount: 49000,
                status: 'PENDING',
                created_at: new Date(Date.now() - 3600000).toISOString(),
                expired_at: new Date(Date.now() - 3000000).toISOString(),
                account: { username: 'testuser', email: 'test@example.com' },
              },
            ],
            total: 1,
            page: 1,
            limit: 10,
          },
        },
      });

      paymentApi.getOrderDetail.mockResolvedValue({
        data: {
          success: true,
          data: {
            id: 'ord-uuid-expired',
            order_code: 9999,
            package_type: 'PREMIUM_1_MONTH',
            amount: 49000,
            status: 'EXPIRED',
            qr_url: null,
            created_at: new Date(Date.now() - 3600000).toISOString(),
            expired_at: new Date(Date.now() - 3000000).toISOString(),
            account: { username: 'testuser', email: 'test@example.com' },
          },
        },
      });

      render(<PaymentHistoryPage />);

      // Bảng ngoài hiển thị "Đã hết hạn" (đồng bộ)
      await waitFor(() => {
        expect(screen.getByText('#9999')).toBeInTheDocument();
        expect(screen.getAllByText(/Đã hết hạn/i).length).toBeGreaterThanOrEqual(2);
      });

      // Mở modal chi tiết
      const detailBtn = screen.getByTitle(/Xem chi tiết/i);
      fireEvent.click(detailBtn);

      await waitFor(() => {
        // Modal bên trong cũng hiển thị banner "Đơn hàng đã hết hạn thanh toán"
        expect(screen.getByText(/Đơn hàng đã hết hạn thanh toán/i)).toBeInTheDocument();
        // Huy hiệu trạng thái trong modal cũng là "Đã hết hạn"
        expect(screen.getAllByText(/Đã hết hạn/i).length).toBeGreaterThanOrEqual(3);
        // Không có ảnh QR
        expect(screen.queryByAltText(/VietQR MB Bank/i)).not.toBeInTheDocument();
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
          expect.any(FormData)
        );
        expect(screen.getByText(/Đã hoàn tiền và cập nhật trạng thái đơn hàng thành công!/i)).toBeInTheDocument();
      });
    });

    it('2.9. Checkbox "Loại bỏ mẫu" kích hoạt gọi API getOrders và getStats kèm tham số excludeTemplate', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(screen.getByText('#1001')).toBeInTheDocument();
      });

      const checkbox = screen.getByLabelText(/Loại bỏ mẫu/i);
      expect(checkbox).not.toBeChecked();

      fireEvent.click(checkbox);
      expect(checkbox).toBeChecked();

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalledWith(
          expect.objectContaining({ excludeTemplate: 'true', page: 1 })
        );
        expect(paymentApi.getStats).toHaveBeenCalledWith(
          expect.objectContaining({ excludeTemplate: 'true' })
        );
      });
    });

    it('2.10. Dropdown Gói cước nạp danh sách từ getPackageTypes và kích hoạt lọc theo gói', async () => {
      render(<PaymentHistoryPage />);

      await waitFor(() => {
        expect(paymentApi.getPackageTypes).toHaveBeenCalled();
        expect(screen.getByText(/Basic \(Mặc định\)/i)).toBeInTheDocument();
      });

      const select = screen.getByDisplayValue(/Tất cả gói cước/i);
      fireEvent.change(select, { target: { value: 'Premium' } });

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalledWith(
          expect.objectContaining({ packageType: 'Premium', page: 1 })
        );
      });
    });
  });
});
