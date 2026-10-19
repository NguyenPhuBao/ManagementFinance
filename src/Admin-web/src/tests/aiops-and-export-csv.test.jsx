import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { exportToCsv, escapeCsvCell } from '../utils/csv-exporter.util';
import AIOpsPage from '../pages/system/AIOpsPage';
import AuditLogPage from '../pages/system/AuditLogPage';
import PaymentHistoryPage from '../pages/payments/PaymentHistoryPage';
import aiopsApi from '../api/aiops.api';
import adminApi from '../api/admin.api';
import paymentApi from '../api/payment.api';

vi.mock('../api/aiops.api', () => ({
  default: {
    getStatus: vi.fn(),
    getHistory: vi.fn(),
    getQuarantineList: vi.fn(),
    unblockQuarantine: vi.fn(),
    unblockIp: vi.fn(),
    permanentBanIp: vi.fn(),
    unblockAccount: vi.fn(),
    permanentBanAccount: vi.fn(),
    setScale: vi.fn(),
    calibrate: vi.fn(),
    getIncidents: vi.fn(),
    clearIncidents: vi.fn(),
    quarantineActor: vi.fn(),
    temporaryBlockAccount: vi.fn(),
    getVectorConfig: vi.fn(),
    toggleVector: vi.fn(),
    getForensics: vi.fn(),
  },
}));

vi.mock('../api/admin.api', () => ({
  default: {
    getMaintenanceStatus: vi.fn(),
    setMaintenanceStatus: vi.fn(),
    getAuditLogs: vi.fn(),
  },
}));

vi.mock('../api/payment.api', () => ({
  default: {
    getPackageTypes: vi.fn(),
    getStats: vi.fn(),
    getOrders: vi.fn(),
    getHistory: vi.fn(),
    refundOrder: vi.fn(),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: vi.fn(() => ({
    connected: true,
    on: vi.fn(),
    off: vi.fn(),
  })),
}));

describe('Task 7: 2-Tier Testing Architecture - AIOps Quarantine & Export CSV', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  /* ======================================================== */
  /* TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ & LOGIC (TIER 2) */
  /* ======================================================== */
  describe('Tier 2: System Impact & Real Logic Verification', () => {
    it('2.1. Utility exportToCsv: tạo file chuẩn UTF-8 BOM (\\uFEFF) và escape chuỗi an toàn RFC 4180', async () => {
      // Escape cell logic
      expect(escapeCsvCell('Normal text')).toBe('"Normal text"');
      expect(escapeCsvCell('Text, with comma')).toBe('"Text, with comma"');
      expect(escapeCsvCell('Text with "quotes"')).toBe('"Text with ""quotes"""');
      expect(escapeCsvCell(null)).toBe('""');

      // Export CSV Blob generation
      let capturedBlob = null;
      const originalCreateObjectURL = window.URL.createObjectURL;
      const originalRevokeObjectURL = window.URL.revokeObjectURL;

      window.URL.createObjectURL = vi.fn((blob) => {
        capturedBlob = blob;
        return 'blob:mock-url';
      });
      window.URL.revokeObjectURL = vi.fn();

      const blob = exportToCsv({
        filename: 'test_audit_report.csv',
        headers: ['Mã', 'Hành động', 'Trạng thái'],
        rows: [
          ['#1', 'Đăng nhập [AUTH]', 'Pass'],
          ['#2', 'Hoàn tiền, [PAYMENT]', 'Fail'],
        ],
      });

      expect(blob).toBeDefined();
      expect(blob.type).toBe('text/csv;charset=utf-8;');

      // Đọc byte nhị phân của Blob để kiểm tra UTF-8 BOM (\uFEFF -> EF BB BF)
      const buffer = await blob.arrayBuffer();
      const bytes = new Uint8Array(buffer);
      expect(bytes[0]).toBe(0xEF); // Byte 1 của UTF-8 BOM
      expect(bytes[1]).toBe(0xBB); // Byte 2 của UTF-8 BOM
      expect(bytes[2]).toBe(0xBF); // Byte 3 của UTF-8 BOM

      const text = await blob.text();
      expect(text).toContain('"Mã","Hành động","Trạng thái"');
      expect(text).toContain('"Đăng nhập [AUTH]"');
      expect(text).toContain('"Hoàn tiền, [PAYMENT]"');

      window.URL.createObjectURL = originalCreateObjectURL;
      window.URL.revokeObjectURL = originalRevokeObjectURL;
    });

    it('2.2. AIOps Quarantine Table: Lọc theo IP cô lập chính xác dòng khớp, loại trừ dòng không khớp', async () => {
      aiopsApi.getStatus.mockResolvedValue({
        threatScore: 0,
        status: 'NORMAL',
        vectorScores: { auth: 0, traffic: 0, exploit: 0, resource: 0 },
        sample: { cpuPercent: 10, ramPercent: 30 },
      });
      aiopsApi.getHistory.mockResolvedValue([]);
      aiopsApi.getQuarantineList.mockResolvedValue([
        {
          id: 'pair-1',
          maskedIp: '113.161.xxx.xxx',
          ip: '113.161.45.88',
          username: 'attacker_one',
          reason: 'Brute-force attack',
          ipStatus: 'temporary',
          remainingMinutes: 120,
        },
        {
          id: 'pair-2',
          maskedIp: '42.112.xxx.xxx',
          ip: '42.112.99.10',
          username: 'suspicious_two',
          reason: 'DDoS flood',
          ipStatus: 'temporary',
          remainingMinutes: 180,
        },
      ]);
      aiopsApi.getIncidents.mockResolvedValue({ incidents: [], total: 0 });

      render(<AIOpsPage />);

      await waitFor(() => {
        expect(screen.getByText('attacker_one')).toBeInTheDocument();
        expect(screen.getByText('suspicious_two')).toBeInTheDocument();
      });

      // Nhập bộ lọc IP: '113.161'
      const ipFilterInput = screen.getByTestId('quarantine-ip-filter-input');
      fireEvent.change(ipFilterInput, { target: { value: '113.161' } });

      // Tác động thực tế: Chỉ còn dòng 'attacker_one', dòng 'suspicious_two' bị ẩn
      await waitFor(() => {
        expect(screen.getByText('attacker_one')).toBeInTheDocument();
        expect(screen.queryByText('suspicious_two')).not.toBeInTheDocument();
      });

      // Nhấn Xóa lọc -> phục hồi hiển thị cả 2
      const clearBtn = screen.getByTestId('clear-quarantine-filter-btn');
      fireEvent.click(clearBtn);

      await waitFor(() => {
        expect(screen.getByText('attacker_one')).toBeInTheDocument();
        expect(screen.getByText('suspicious_two')).toBeInTheDocument();
      });
    });

    it('2.3. AIOps Manual Quarantine: Gọi đúng API quarantineActor khi admin nhập tay IP', async () => {
      aiopsApi.getStatus.mockResolvedValue({
        threatScore: 0,
        status: 'NORMAL',
        vectorScores: { auth: 0, traffic: 0, exploit: 0, resource: 0 },
        sample: { cpuPercent: 10, ramPercent: 30 },
      });
      aiopsApi.getHistory.mockResolvedValue([]);
      aiopsApi.getQuarantineList.mockResolvedValue([]);
      aiopsApi.getIncidents.mockResolvedValue({ incidents: [], total: 0 });
      aiopsApi.quarantineActor.mockResolvedValue({
        success: true,
        message: 'Đã phong tỏa IP thành công',
        data: { ip: '203.113.152.12', maskedIp: '203.113.xxx.xxx', remainingMinutes: 240 },
      });

      render(<AIOpsPage />);

      // Mở modal tạm khóa thủ công
      const openModalBtn = await screen.findByRole('button', { name: /Tạm khóa thủ công/i });
      fireEvent.click(openModalBtn);

      // Điền IP và lý do
      const ipInput = screen.getByTestId('manual-quarantine-ip-input');
      fireEvent.change(ipInput, { target: { value: '203.113.152.12' } });

      const reasonInput = screen.getByTestId('manual-quarantine-reason-input');
      fireEvent.change(reasonInput, { target: { value: 'Nghi vấn tấn công SQLi qua Audit Log' } });

      // Submit form
      const submitBtn = screen.getByTestId('submit-manual-quarantine-btn');
      fireEvent.click(submitBtn);

      // Tác động hệ thống: API quarantineActor PHẢI được gọi đúng thông số
      await waitFor(() => {
        expect(aiopsApi.quarantineActor).toHaveBeenCalledWith(
          expect.objectContaining({
            ip: '203.113.152.12',
            reason: 'Nghi vấn tấn công SQLi qua Audit Log',
            durationMinutes: 240,
            vector: 'auth',
          })
        );
      });
    });
  });

  /* ======================================================== */
  /* TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN (TIER 1) */
  /* ======================================================== */
  describe('Tier 1: UI Rendering & Interaction Verification', () => {
    it('1.1. AuditLogPage: Hiển thị đầy đủ nút Xuất CSV và click không throw error', async () => {
      adminApi.getAuditLogs.mockResolvedValue({
        data: {
          items: [
            {
              id: 101,
              username: 'admin',
              request: 'Đăng nhập quản trị viên',
              req_status: 'Pass',
              time_req: '2026-10-19T08:00:00Z',
              ip: '127.0.0.1',
            },
          ],
          total: 1,
        },
      });

      render(<AuditLogPage />);

      const exportBtn = await screen.findByRole('button', { name: /Xuất CSV/i });
      expect(exportBtn).toBeInTheDocument();

      // Click nút xuất CSV
      fireEvent.click(exportBtn);

      // Đảm bảo API lấy log phục vụ xuất CSV được gọi
      await waitFor(() => {
        expect(adminApi.getAuditLogs).toHaveBeenCalled();
      });
    });

    it('1.2. PaymentHistoryPage: Hiển thị đầy đủ nút Xuất CSV và click không throw error', async () => {
      paymentApi.getPackageTypes.mockResolvedValue({ data: [] });
      paymentApi.getStats.mockResolvedValue({ totalRevenue: 1000000, totalOrders: 5, paidOrders: 5, successRate: 100 });
      paymentApi.getOrders.mockResolvedValue({
        data: {
          items: [
            {
              idorder: 501,
              order_code: 'ORD-501',
              amount: 50000,
              status: 'PAID',
              payment_gateway: 'PayOS',
              package_name: 'Premium 1 Tháng',
            },
          ],
          total: 1,
        },
      });

      render(<PaymentHistoryPage />);

      const exportBtn = await screen.findByRole('button', { name: /Xuất CSV/i });
      expect(exportBtn).toBeInTheDocument();

      fireEvent.click(exportBtn);

      await waitFor(() => {
        expect(paymentApi.getOrders).toHaveBeenCalled();
      });
    });

    it('1.3. AIOpsPage: Chuyển đổi giữa chế độ tạm khóa IP và tạm khóa Tài khoản trong Modal', async () => {
      aiopsApi.getStatus.mockResolvedValue({
        threatScore: 0,
        status: 'NORMAL',
        vectorScores: { auth: 0, traffic: 0, exploit: 0, resource: 0 },
        sample: { cpuPercent: 10, ramPercent: 30 },
      });
      aiopsApi.getHistory.mockResolvedValue([]);
      aiopsApi.getQuarantineList.mockResolvedValue([]);
      aiopsApi.getIncidents.mockResolvedValue({ incidents: [], total: 0 });

      render(<AIOpsPage />);

      const openModalBtn = await screen.findByRole('button', { name: /Tạm khóa thủ công/i });
      fireEvent.click(openModalBtn);

      // Mặc định là IP
      expect(screen.getByTestId('manual-quarantine-ip-input')).toBeInTheDocument();

      // Click chuyển sang "Tài khoản"
      const accountTabBtn = screen.getByRole('button', { name: /Tài khoản/i });
      fireEvent.click(accountTabBtn);

      // Ô nhập tài khoản xuất hiện, ô IP ẩn đi
      expect(screen.getByTestId('manual-quarantine-account-input')).toBeInTheDocument();
      expect(screen.queryByTestId('manual-quarantine-ip-input')).not.toBeInTheDocument();
    });
  });
});
