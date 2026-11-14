import React from 'react';
import { render, screen, fireEvent, waitFor, act, within } from '@testing-library/react';
import PaymentHistoryPage from '../pages/payments/PaymentHistoryPage';
import paymentApi from '../api/payment.api';
import adminApi from '../api/admin.api';
import { exportToCsv } from '../utils/csv-exporter.util';

const handlers = {};
const fakeSocket = {
  on: (event, fn) => {
    handlers[event] = handlers[event] || new Set();
    handlers[event].add(fn);
  },
  off: (event, fn) => handlers[event] && handlers[event].delete(fn),
};
const emit = (event, payload) => act(() => {
  (handlers[event] || []).forEach((fn) => fn(payload));
});

const notify = { info: vi.fn(), success: vi.fn(), error: vi.fn(), warning: vi.fn() };

vi.mock('../hooks/useSocket', () => ({ default: () => fakeSocket }));
vi.mock('../store/alert.context', () => ({ useAlertSafe: () => notify }));
vi.mock('../utils/csv-exporter.util', () => ({ exportToCsv: vi.fn() }));
vi.mock('../api/admin.api', () => ({ default: { verifySecurityAction: vi.fn() } }));
vi.mock('../api/payment.api', () => ({
  default: {
    getOrders: vi.fn(),
    getStats: vi.fn(),
    getOrderDetail: vi.fn(),
    getPackageTypes: vi.fn(),
    processRefund: vi.fn(),
    confirmUpgrade: vi.fn(),
    createSampleOrder: vi.fn(),
    deleteSampleOrders: vi.fn(),
  },
}));

const PAST = '2026-01-01T00:00:00Z';
const ORDERS = [
  { id: 'a', order_code: 1001, recognition_code: 'ABC123', package_type: 'Premium', amount: 49000, status: 'PAID', created_at: PAST, paid_at: PAST, account: { username: 'an', email: 'a@x.test', User: { fullname: 'Nguyễn An' } } },
  { id: 'b', order_code: 1002, package_type: 'Premium', amount: 49000, amount_received: 20000, status: 'REFUND_PENDING', created_at: PAST, account: { username: 'binh' } },
  { id: 'c', order_code: 1003, package_type: 'Premium', amount: 2000, amount_received: 0, status: 'PENDING', expired_at: PAST, created_at: PAST, is_template: true, account: { username: 'chau' } },
  { id: 'd', order_code: 1004, package_type: 'Premium', amount: 49000, amount_received: 70000, status: 'WAITING_CONFIRMATION', created_at: PAST, account: { username: 'dung' } },
];

const row = (code) => screen.getByRole('row', { name: new RegExp(`#${code}`) });
const lastOrdersCall = () => paymentApi.getOrders.mock.calls.at(-1)[0];

const renderPage = async () => {
  render(<PaymentHistoryPage />);
  await screen.findByRole('row', { name: /#1001/ });
};

beforeEach(() => {
  Object.keys(handlers).forEach((k) => delete handlers[k]);
  paymentApi.getOrders.mockReset().mockResolvedValue({ data: { items: ORDERS.map((o) => ({ ...o })), total: 4 } });
  paymentApi.getStats.mockReset().mockResolvedValue({ data: { totalRevenue: 98000, totalOrders: 4, paidOrders: 1, successRate: 25 } });
  paymentApi.getPackageTypes.mockReset().mockResolvedValue({ data: ['Basic', 'Premium'] });
  paymentApi.getOrderDetail.mockReset().mockImplementation((id) =>
    Promise.resolve({ data: { ...ORDERS.find((o) => o.id === id), payment_transaction: [{ id: 't1', bank_code: 'MB', amount: 49000, payos_transaction_id: 'FT999', signature_verified: true }] } })
  );
  paymentApi.processRefund.mockReset().mockResolvedValue({ success: true });
  paymentApi.confirmUpgrade.mockReset().mockResolvedValue({ success: true });
  paymentApi.createSampleOrder.mockReset().mockResolvedValue({
    success: true,
    data: { order_code: 2001, qr_url: 'https://qr.test/2001.png', recognition_code: 'QWE789', amount: 2000, bank_info: { bankName: 'MB', accountNumber: '0123', accountName: 'FLOWMONEY' } },
  });
  paymentApi.deleteSampleOrders.mockReset().mockResolvedValue({ success: true, data: { deletedCount: 3 } });
  adminApi.verifySecurityAction.mockReset().mockResolvedValue({ success: true });
  exportToCsv.mockReset();
});

describe('Hiển thị', () => {
  it('tải số liệu (loại đơn mẫu) và danh sách; 4 thẻ số liệu đúng', async () => {
    await renderPage();
    expect(paymentApi.getStats).toHaveBeenCalledWith({ excludeTemplate: 'true' });
    expect(paymentApi.getOrders).toHaveBeenCalledWith({ page: 1, limit: 10 });
    expect(screen.getByRole('heading', { level: 1, name: 'Lịch sử thanh toán' })).toBeInTheDocument();
    const card = (label) => screen.getByText(label, { selector: 'div' }).parentElement;
    expect(card('Doanh thu thực nhận')).toHaveTextContent('98.000 ₫');
    expect(card('Tổng đơn hàng')).toHaveTextContent('4');
    expect(card('Tỷ lệ thành công')).toHaveTextContent('25%');
  });

  it('trạng thái hiển thị đúng; đơn chờ đã quá hạn hiện Hết hạn; đơn mẫu có nhãn Mẫu', async () => {
    await renderPage();
    expect(within(row(1001)).getByText('Đã thanh toán')).toHaveAttribute('data-tone', 'success');
    expect(within(row(1003)).getByText('Hết hạn')).toBeInTheDocument();
    expect(within(row(1003)).getByText('Mẫu')).toBeInTheDocument();
    expect(within(row(1003)).queryByText('0')).not.toBeInTheDocument();
    expect(within(row(1002)).getByText(/Thực nhận/)).toHaveTextContent('20.000');
    expect(within(row(1001)).queryByRole('button', { name: 'Hoàn tiền' })).not.toBeInTheDocument();
    expect(within(row(1002)).getByRole('button', { name: 'Hoàn tiền' })).toBeInTheDocument();
  });
});

describe('Bộ lọc', () => {
  it('trạng thái, gói, ngày, ẩn đơn mẫu và tìm kiếm đều gửi lên máy chủ; đặt lại xóa hết', async () => {
    await renderPage();
    fireEvent.change(screen.getByLabelText('Trạng thái'), { target: { value: 'PAID' } });
    fireEvent.change(screen.getByLabelText('Gói cước'), { target: { value: 'Premium' } });
    fireEvent.change(screen.getByLabelText('Từ ngày'), { target: { value: '2026-11-01' } });
    fireEvent.click(screen.getByLabelText('Ẩn đơn mẫu'));
    fireEvent.change(screen.getByLabelText('Tìm đơn hàng'), { target: { value: 'binh' } });
    await waitFor(() =>
      expect(lastOrdersCall()).toEqual({ page: 1, limit: 10, search: 'binh', status: 'PAID', packageType: 'Premium', fromDate: '2026-11-01', excludeTemplate: 'true' })
    );
    expect(paymentApi.getStats).toHaveBeenLastCalledWith({ fromDate: '2026-11-01', excludeTemplate: 'true' });
    fireEvent.click(screen.getByRole('button', { name: 'Đặt lại' }));
    await waitFor(() => expect(lastOrdersCall()).toEqual({ page: 1, limit: 10 }));
  });
});

describe('Chi tiết, nâng cấp, hoàn tiền', () => {
  it('xem chi tiết tải đơn theo id, hiện khách hàng và giao dịch webhook', async () => {
    await renderPage();
    fireEvent.click(within(row(1001)).getByRole('button', { name: 'Xem chi tiết' }));
    const dialog = await screen.findByRole('dialog', { name: 'Chi tiết đơn hàng' });
    expect(paymentApi.getOrderDetail).toHaveBeenCalledWith('a');
    expect(await within(dialog).findByText('Nguyễn An')).toBeInTheDocument();
    expect(within(dialog).getByText('FT999')).toBeInTheDocument();
  });

  it('đơn chuyển thừa: đồng ý kích hoạt gọi confirmUpgrade', async () => {
    await renderPage();
    fireEvent.click(within(row(1004)).getByRole('button', { name: 'Xem chi tiết' }));
    const dialog = await screen.findByRole('dialog', { name: 'Chi tiết đơn hàng' });
    fireEvent.click(await within(dialog).findByRole('button', { name: 'Đồng ý kích hoạt' }));
    await waitFor(() => expect(paymentApi.confirmUpgrade).toHaveBeenCalledWith({ orderCode: 1004, accept: true }));
  });

  it('hoàn tiền: điền sẵn số tiền thực nhận, qua PIN rồi mới gửi processRefund', async () => {
    await renderPage();
    fireEvent.click(within(row(1002)).getByRole('button', { name: 'Hoàn tiền' }));
    const dialog = screen.getByRole('dialog', { name: 'Hoàn tiền đơn hàng' });
    expect(within(dialog).getByLabelText('Số tiền hoàn (VNĐ)')).toHaveValue(20000);
    fireEvent.change(within(dialog).getByLabelText('Lý do'), { target: { value: 'Chuyển thiếu tiền' } });
    fireEvent.change(within(dialog).getByLabelText('Hoặc đường dẫn ảnh'), { target: { value: 'https://proof.test/a.png' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Tiếp tục' }));
    expect(paymentApi.processRefund).not.toHaveBeenCalled();
    const pin = screen.getByRole('dialog', { name: 'Xác nhận hoàn tiền' });
    fireEvent.change(within(pin).getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(within(pin).getByRole('button', { name: 'Hoàn tiền' }));
    await waitFor(() => expect(paymentApi.processRefund).toHaveBeenCalledTimes(1));
    const [id, form] = paymentApi.processRefund.mock.calls[0];
    expect(id).toBe('b');
    expect(form.get('refunded_amount')).toBe('20000');
    expect(form.get('refund_reason')).toBe('Chuyển thiếu tiền');
    expect(form.get('refund_proof')).toBe('https://proof.test/a.png');
    expect(adminApi.verifySecurityAction).toHaveBeenCalledWith(expect.objectContaining({ action: 'REFUND_ORDER', targetId: '#1002' }));
  });

  it('ảnh minh chứng tải lên máy chủ được mở theo địa chỉ máy chủ API, không trỏ localhost:5000', async () => {
    paymentApi.getOrderDetail.mockResolvedValueOnce({ data: { ...ORDERS[1], status: 'REFUNDED', refund_proof: '/assets/Refunds/p.png', refunded_at: PAST } });
    await renderPage();
    fireEvent.click(within(row(1002)).getByRole('button', { name: 'Xem chi tiết' }));
    const dialog = await screen.findByRole('dialog', { name: 'Chi tiết đơn hàng' });
    const link = await within(dialog).findByRole('link', { name: /p\.png/ });
    expect(link.getAttribute('href')).not.toContain('localhost:5000');
    expect(link.getAttribute('href').endsWith('/assets/Refunds/p.png')).toBe(true);
  });
});

describe('Xuất CSV, đơn thử, realtime', () => {
  it('xuất CSV lấy toàn bộ đơn theo bộ lọc rồi ghi tệp', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('button', { name: 'Xuất CSV' }));
    await waitFor(() => expect(exportToCsv).toHaveBeenCalledTimes(1));
    expect(lastOrdersCall()).toEqual({ page: 1, limit: 4 });
    expect(exportToCsv.mock.calls[0][0].rows).toHaveLength(4);
  });

  it('tạo đơn thử với mức 2.000 ₫ rồi hiện mã QR và mã nhận diện', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('button', { name: 'Tạo đơn thử' }));
    const dialog = screen.getByRole('dialog', { name: 'Tạo đơn thử nghiệm' });
    fireEvent.click(within(dialog).getByRole('button', { name: /2\.000/ }));
    fireEvent.click(within(dialog).getByRole('button', { name: 'Tạo đơn chờ thanh toán' }));
    await waitFor(() =>
      expect(paymentApi.createSampleOrder).toHaveBeenCalledWith({ simulateWebhook: false, status: 'PENDING', packageType: 'Premium', amount: 2000 })
    );
    expect(await within(dialog).findByRole('img', { name: /QR/ })).toHaveAttribute('src', 'https://qr.test/2001.png');
    expect(within(dialog).getAllByText('QWE789').length).toBeGreaterThan(0);
  });

  it('xóa đơn mẫu: mở hộp xác nhận, bấm Hủy thì không gọi API', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('button', { name: 'Xóa đơn mẫu' }));
    const dialog = screen.getByRole('dialog', { name: 'Xóa đơn mẫu' });
    expect(within(dialog).getByText(/không khôi phục/)).toBeInTheDocument();
    fireEvent.click(within(dialog).getByRole('button', { name: 'Hủy bỏ' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(paymentApi.deleteSampleOrders).not.toHaveBeenCalled();
  });

  it('xóa đơn mẫu: xác nhận gọi deleteSampleOrders một lần, đóng hộp rồi tải lại danh sách và số liệu', async () => {
    await renderPage();
    const ordersBefore = paymentApi.getOrders.mock.calls.length;
    const statsBefore = paymentApi.getStats.mock.calls.length;
    fireEvent.click(screen.getByRole('button', { name: 'Xóa đơn mẫu' }));
    const dialog = screen.getByRole('dialog', { name: 'Xóa đơn mẫu' });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Xóa' }));
    await waitFor(() => expect(paymentApi.deleteSampleOrders).toHaveBeenCalledTimes(1));
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(paymentApi.getOrders.mock.calls.length).toBeGreaterThan(ordersBefore);
    expect(paymentApi.getStats.mock.calls.length).toBeGreaterThan(statsBefore);
  });

  it('sự kiện payment.success tải lại danh sách và số liệu', async () => {
    await renderPage();
    const before = paymentApi.getOrders.mock.calls.length;
    emit('payment.success', { orderCode: 1003 });
    await waitFor(() => expect(paymentApi.getOrders.mock.calls.length).toBeGreaterThan(before));
  });

  it.each([
    ['payment.order_created', { orderCode: 1005 }],
    ['payment.status_changed', { orderCode: 1002, status: 'EXPIRED' }],
    ['payment.order_expired', { count: 2 }],
    ['payment.order_cancelled', { orderCode: 1002, status: 'CANCELLED' }],
    ['payment.refund_pending', { orderCode: 1004, amount: 70000 }],
    ['payment.refunded', { orderId: 'd', status: 'REFUNDED' }],
    ['payment.amount_mismatch', { orderCode: 1004, type: 'OVERPAID' }],
  ])('sự kiện %s (Backend gửi admin_room) tải lại danh sách và số liệu', async (event, payload) => {
    await renderPage();
    const orders = paymentApi.getOrders.mock.calls.length;
    const stats = paymentApi.getStats.mock.calls.length;
    emit(event, payload);
    await waitFor(() => expect(paymentApi.getOrders.mock.calls.length).toBeGreaterThan(orders));
    expect(paymentApi.getStats.mock.calls.length).toBeGreaterThan(stats);
  });

  it('chênh lệch số tiền báo đúng loại; cần hoàn tiền có thông báo', async () => {
    await renderPage();
    notify.info.mockClear();
    emit('payment.amount_mismatch', { orderCode: 1004, type: 'OVERPAID' });
    expect(notify.info).toHaveBeenLastCalledWith('Đơn #1004 chuyển thừa tiền, chờ xác nhận.');
    emit('payment.amount_mismatch', { orderCode: 1006, type: 'UNDERPAID' });
    expect(notify.info).toHaveBeenLastCalledWith('Đơn #1006 chuyển thiếu tiền, chuyển sang hoàn tiền.');
    emit('payment.refund_pending', { orderCode: 1007, amount: 50000 });
    expect(notify.info).toHaveBeenLastCalledWith('Đơn #1007 cần hoàn tiền.');
  });

  it('không nghe hai sự kiện chỉ gửi cho người dùng (không bao giờ tới admin)', async () => {
    await renderPage();
    expect(handlers['payment.overpaid_confirmation']?.size || 0).toBe(0);
    expect(handlers['payment.underpaid_warning']?.size || 0).toBe(0);
  });
});
