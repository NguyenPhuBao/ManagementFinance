import React from 'react';
import { render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { LanguageProvider } from '../store/language.context';
import axiosClient from '../api/axios-client';
import routes from '../router/routes.jsx';
import PaymentResultPage from '../pages/payment/PaymentResultPage';

vi.mock('../api/axios-client', () => ({
  default: { get: vi.fn(), post: vi.fn(), put: vi.fn(), patch: vi.fn(), delete: vi.fn() },
}));

const open = (url) => render(
  <LanguageProvider>
    <MemoryRouter initialEntries={[url]}>
      <Routes>
        <Route path="/payment/success" element={<PaymentResultPage outcome="success" />} />
        <Route path="/payment/cancel" element={<PaymentResultPage outcome="cancel" />} />
      </Routes>
    </MemoryRouter>
  </LanguageProvider>
);

beforeEach(() => {
  localStorage.clear();
  Object.values(axiosClient).forEach((fn) => fn.mockReset());
});

describe('Trang kết quả thanh toán (công khai)', () => {
  it('hai đường dẫn PayOS trả về là route công khai, không cần đăng nhập', () => {
    const byPath = Object.fromEntries(routes.map((r) => [r.path, r]));
    expect(byPath['/payment/success']?.public).toBe(true);
    expect(byPath['/payment/cancel']?.public).toBe(true);
  });

  it('PAID: báo thành công, hiện mã đơn, hướng dẫn quay lại ứng dụng; không gọi API', () => {
    open('/payment/success?code=00&id=abc&cancel=false&status=PAID&orderCode=123456');
    expect(screen.getByRole('heading', { level: 1, name: 'Thanh toán thành công' })).toBeInTheDocument();
    expect(screen.getByText('123456')).toBeInTheDocument();
    expect(screen.getByText(/quay lại ứng dụng FlowMoney/)).toBeInTheDocument();
    expect(screen.getByText('FlowMoney')).toBeInTheDocument();
    expect(screen.queryByText('FlowMoney Admin')).not.toBeInTheDocument();
    Object.values(axiosClient).forEach((fn) => expect(fn).not.toHaveBeenCalled());
  });

  it('chưa PAID (PENDING / PROCESSING): báo đang xác nhận, không khẳng định thành công', () => {
    open('/payment/success?code=00&cancel=false&status=PENDING&orderCode=77');
    expect(screen.getByRole('heading', { level: 1, name: 'Đang xác nhận thanh toán' })).toBeInTheDocument();
    expect(screen.queryByText('Thanh toán thành công')).not.toBeInTheDocument();
  });

  it('trang hủy: báo đã hủy, chưa bị trừ tiền', () => {
    open('/payment/cancel?code=00&cancel=true&status=CANCELLED&orderCode=88');
    expect(screen.getByRole('heading', { level: 1, name: 'Đã hủy thanh toán' })).toBeInTheDocument();
    expect(screen.getByText('88')).toBeInTheDocument();
  });

  it('PayOS gửi cancel=true về trang thành công: vẫn báo đã hủy', () => {
    open('/payment/success?cancel=true&status=CANCELLED&orderCode=99');
    expect(screen.getByRole('heading', { level: 1, name: 'Đã hủy thanh toán' })).toBeInTheDocument();
  });

  it('mã đơn không phải số thì không hiển thị (chặn chèn nội dung qua đường dẫn)', () => {
    open('/payment/success?status=PAID&orderCode=%3Cb%3Ehack%3C%2Fb%3E');
    expect(screen.queryByText(/hack/)).not.toBeInTheDocument();
    expect(screen.queryByText('Mã đơn')).not.toBeInTheDocument();
  });
});
