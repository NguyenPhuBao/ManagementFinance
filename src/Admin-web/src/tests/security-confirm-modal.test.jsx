import React from 'react';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import SecurityConfirmModal from '../components/common/SecurityConfirmModal';
import adminApi from '../api/admin.api';

vi.mock('../api/admin.api', () => ({
  default: {
    verifySecurityAction: vi.fn(),
  },
}));

describe('Task 3: SecurityConfirmModal (Re-Authentication PIN) 2-Tier Test', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('Tier 1: Hiển thị form nhập mã PIN 6 số, cảnh báo hành động chí mạng và nút xác nhận', () => {
    render(
      <SecurityConfirmModal
        isOpen={true}
        onClose={vi.fn()}
        onConfirm={vi.fn()}
        title="Xác thực Hoàn tiền Đơn hàng"
        description="Lệnh hoàn tiền sẽ tác động trực tiếp đến ngân quỹ tài chính."
        actionType="REFUND"
        targetLabel="#ORD-9999"
      />
    );

    expect(screen.getByText('Xác thực Hoàn tiền Đơn hàng')).toBeInTheDocument();
    expect(screen.getByText(/Lệnh hoàn tiền sẽ tác động trực tiếp/i)).toBeInTheDocument();
    expect(screen.getByText('#ORD-9999')).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/Nhập mã PIN 6 số/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Xác thực & Thực thi/i })).toBeDisabled();
  });

  it('Tier 2: Khi nhập đúng mã PIN, gọi API xác thực thành công và kích hoạt onConfirm callback', async () => {
    const handleConfirm = vi.fn().mockResolvedValue(true);
    const handleClose = vi.fn();

    adminApi.verifySecurityAction.mockResolvedValueOnce({
      data: { verified: true, action: 'REFUND' },
    });

    render(
      <SecurityConfirmModal
        isOpen={true}
        onClose={handleClose}
        onConfirm={handleConfirm}
        title="Xác thực Hoàn tiền Đơn hàng"
        description="Lệnh hoàn tiền sẽ tác động trực tiếp đến ngân quỹ tài chính."
        actionType="REFUND"
        targetLabel="#ORD-9999"
      />
    );

    const pinInput = screen.getByPlaceholderText(/Nhập mã PIN 6 số/i);
    fireEvent.change(pinInput, { target: { value: '123456' } });

    const submitBtn = screen.getByRole('button', { name: /Xác thực & Thực thi/i });
    expect(submitBtn).not.toBeDisabled();

    fireEvent.click(submitBtn);

    await waitFor(() => {
      expect(adminApi.verifySecurityAction).toHaveBeenCalledWith({
        pin: '123456',
        password: '',
        action: 'REFUND',
        targetId: '#ORD-9999',
      });
      expect(handleConfirm).toHaveBeenCalled();
      expect(handleClose).toHaveBeenCalled();
    });
  });

  it('Tier 2: Khi nhập sai mã PIN, hiển thị thông báo lỗi và KHÔNG kích hoạt onConfirm', async () => {
    const handleConfirm = vi.fn();

    adminApi.verifySecurityAction.mockRejectedValueOnce({
      response: { data: { message: 'Mã PIN bảo mật không chính xác!' } },
    });

    render(
      <SecurityConfirmModal
        isOpen={true}
        onClose={vi.fn()}
        onConfirm={handleConfirm}
        title="Xác thực Hoàn tiền"
        actionType="REFUND"
        targetLabel="#ORD-9999"
      />
    );

    const pinInput = screen.getByPlaceholderText(/Nhập mã PIN 6 số/i);
    fireEvent.change(pinInput, { target: { value: '000000' } });

    const submitBtn = screen.getByRole('button', { name: /Xác thực & Thực thi/i });
    fireEvent.click(submitBtn);

    await waitFor(() => {
      expect(screen.getByText('Mã PIN bảo mật không chính xác!')).toBeInTheDocument();
      expect(handleConfirm).not.toHaveBeenCalled();
    });
  });
});
