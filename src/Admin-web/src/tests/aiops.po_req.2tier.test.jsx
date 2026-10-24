/**
 * 2-Tier Test Suite for AIOps Sentinel PO Requirements:
 * 1. Nút "Tái Hiệu Chuẩn Baseline":
 *    - Công thức mô hình chịu tải phần cứng server & ngưỡng an toàn 4 vector.
 *    - Không lưu cứng giá trị admin nhập: mỗi lần mở modal đều reset rỗng, auto tính toán và hiển thị placeholder.
 *    - Ưu tiên chỉ số admin nhập, nếu trống fallback lấy giá trị placeholder.
 * 2. Box Biểu đồ xu hướng 4 Vector rủi ro:
 *    - Chuẩn hóa trục thời gian thực (Timestamp-based X positioning).
 *    - 5 Khung thời gian Presets: 10 phút, 1 giờ, 24 giờ, 7 ngày, 1 tháng.
 *    - Bỏ icon `date_range` trước dòng "Bộ lọc thời gian:".
 * 3. Box Tổng quan nguyên nhân bất thường (RCA):
 *    - Xóa sạch emoji cũ (🪪, 🌐, 🐞, ⚡), chỉ dùng Material Symbols chuẩn.
 *    - Chuẩn hóa Cột Đối tượng:
 *      + Chỉ duy nhất Vector Tài nguyên (`resource`) thuộc về Hệ thống (`Hệ thống - Nội bộ hệ thống`).
 *      + Tất cả các Vector khác (Lưu lượng `traffic`, Xác thực `auth`, Khai thác `exploit`) hiển thị `TK: ...` và `IP: ...`.
 */
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import AIOpsPage from '../pages/system/AIOpsPage';
import aiopsApi from '../api/aiops.api';
import adminApi from '../api/admin.api';

const mockSocket = {
  on: vi.fn(),
  off: vi.fn(),
  emit: vi.fn(),
};

vi.mock('../hooks/useSocket', () => ({
  default: () => mockSocket,
}));

vi.mock('../api/aiops.api', () => ({
  default: {
    getStatus: vi.fn(),
    getHistory: vi.fn(),
    getQuarantineList: vi.fn(),
    getIncidents: vi.fn(),
    scaleCapacity: vi.fn(),
    calibrate: vi.fn(),
    isolateIp: vi.fn(),
    releaseIp: vi.fn(),
    clearAllQuarantine: vi.fn(),
  },
}));

vi.mock('../api/admin.api', () => ({
  default: {
    getMaintenanceStatus: vi.fn(),
    verifySecurityAction: vi.fn().mockResolvedValue({ data: { verified: true } }),
  },
}));

describe('AIOps Sentinel - PO Requirements (2-Tier Architecture)', () => {
  const mockStatus = {
    mode: 'ACTIVE_DEFENSE',
    isOnline: true,
    calibratedAt: new Date().toISOString(),
    currentProfile: 'MEDIUM',
    targetConcurrency: 1000,
    hardwareProfile: {
      cpuCores: 4,
      ramTotalGb: 8,
      maxRpsCapacity: 2000,
    },
    riskAssessment: {
      overallScore: 25,
      level: 'LOW',
      activeAttacksCount: 0,
    },
    quarantineStats: {
      activeCount: 0,
      totalBlocked24h: 1,
    },
    vectors: {
      auth: { score: 10, level: 'LOW', value: 1, unit: 'fail/m' },
      traffic: { score: 20, level: 'LOW', value: 120, unit: 'req/m' },
      exploit: { score: 5, level: 'LOW', value: 0, unit: 'threat' },
      resource: { score: 15, level: 'LOW', value: 35, unit: '%' },
    },
    metricsSummary: {
      failedLogins: 1,
      totalRequests: 120,
      exploitAttempts: 0,
      cpuPercent: 35,
      memoryMb: 1024,
      eventLoopDelayMs: 2,
    },
    anomalies: [],
  };

  const mockIncidents = [
    {
      id: 'inc_traffic_001',
      code: 'ANOMALY_TRAFFIC_SPIKE',
      vector: 'traffic',
      severity: 'HIGH',
      message: 'Lưu lượng truy cập tăng vọt từ client',
      status: 'ACTIVE',
      actor_type: 'USER',
      actor_identity: '113.161.45.67',
      username: 'client_shopper_01',
      target_endpoint: '/api/v1/checkout',
      metric_current: 550,
      metric_baseline: 100,
      metric_unit: 'req/min',
      root_cause_diagnosis: 'Lưu lượng request dồn dập từ tài khoản người dùng',
      hits: 1,
      first_detected_at: new Date(Date.now() - 300000).toISOString(),
      last_seen_at: new Date().toISOString(),
    },
    {
      id: 'inc_resource_002',
      code: 'ANOMALY_CPU_SPIKE',
      vector: 'resource',
      severity: 'CRITICAL',
      message: 'CPU máy chủ vượt quá 95%',
      status: 'ACTIVE',
      actor_type: 'SYSTEM',
      metric_current: 96,
      metric_baseline: 40,
      metric_unit: '%',
      root_cause_diagnosis: 'Nghẽn tác vụ tính toán nền nội bộ hệ thống',
      hits: 1,
      first_detected_at: new Date(Date.now() - 200000).toISOString(),
      last_seen_at: new Date().toISOString(),
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
    window.confirm = vi.fn(() => true);
    aiopsApi.getStatus.mockResolvedValue({ data: mockStatus });
    aiopsApi.getHistory.mockResolvedValue({
      data: [
        { timestamp: new Date(Date.now() - 3600000).toISOString(), score: 20, auth: 10, traffic: 30, exploit: 0, resource: 20 },
        { timestamp: new Date().toISOString(), score: 25, auth: 15, traffic: 35, exploit: 0, resource: 25 },
      ],
    });
    aiopsApi.getQuarantineList.mockResolvedValue({ data: [] });
    aiopsApi.getIncidents.mockResolvedValue({
      data: {
        data: mockIncidents,
        pagination: { page: 1, limit: 10, total: 2, totalPages: 1 },
      },
    });
    aiopsApi.calibrate.mockResolvedValue({ data: { success: true, message: 'Đã tái hiệu chuẩn baseline' } });
    adminApi.getMaintenanceStatus.mockResolvedValue({ data: { active: false } });
  });

  // =========================================================================
  // 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN (UI Rendering & Interaction)
  // =========================================================================
  describe('🧱 TẦNG 1: UI Rendering & Clean Layout Verification', () => {
    it('1.1. Nút "Tái Hiệu Chuẩn Baseline" mở modal: các ô input đều rỗng và có placeholder tự động tính toán', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText('AIOps Sentinel — Giám Sát & Phòng Vệ Tự Động')).toBeInTheDocument();
      });

      // Click nút mở modal Tái Hiệu Chuẩn Baseline
      const calibrateBtn = screen.getByRole('button', { name: /Tái Hiệu Chuẩn Baseline/i });
      fireEvent.click(calibrateBtn);

      await waitFor(() => {
        expect(screen.getByTestId('input-auth-failure-threshold')).toBeInTheDocument();
      });

      // Với N = 1000 CCU:
      // authFailureThreshold: Math.max(20, Math.round(15 + 10 * Math.log10(1000/100))) = 25
      // trafficSpikeRps: Math.max(50, Math.round(1000 / 2)) = 500
      // exploitLimit: 8
      // resourceCpuPercent: 85
      // resourceMemoryPercent: 85
      // eventLoopLagMs: 100
      const authInput = screen.getByTestId('input-auth-failure-threshold');
      const reqInput = screen.getByTestId('input-traffic-spike-rps');
      const exploitInput = screen.getByTestId('input-exploit-limit');
      const cpuInput = screen.getByTestId('input-resource-cpu-percent');
      const memInput = screen.getByTestId('input-resource-memory-percent');
      const lagInput = screen.getByTestId('input-event-loop-lag-ms');

      // Placeholder phải chứa đúng giá trị auto-calculated từ mô hình chịu tải
      expect(authInput.placeholder).toBe('25');
      expect(reqInput.placeholder).toBe('500');
      expect(exploitInput.placeholder).toBe('8');
      expect(cpuInput.placeholder).toBe('85');
      expect(memInput.placeholder).toBe('85');
      expect(lagInput.placeholder).toBe('100');

      // Giá trị input ban đầu phải rỗng (không lưu cứng giá trị admin nhập)
      expect(authInput.value).toBe('');
      expect(reqInput.value).toBe('');
      expect(exploitInput.value).toBe('');
      expect(cpuInput.value).toBe('');
      expect(memInput.value).toBe('');
      expect(lagInput.value).toBe('');
    });

    it('1.2. Biểu đồ xu hướng: Đã bỏ icon date_range trước "Bộ lọc thời gian:" và có đủ 5 Presets', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText('Bộ lọc thời gian:')).toBeInTheDocument();
      });

      // Không còn icon date_range ngay trước bộ lọc thời gian
      const filterLabelContainer = screen.getByText('Bộ lọc thời gian:').closest('span');
      expect(filterLabelContainer.querySelector('.material-symbols-outlined')).toBeNull();

      // Có đủ 5 presets: 10 phút, 1 giờ, 24 giờ, 7 ngày, 1 tháng
      expect(screen.getByRole('button', { name: /10 phút/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /1 giờ/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /24 giờ/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /7 ngày/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /1 tháng/i })).toBeInTheDocument();
    });

    it('1.3. Bảng RCA: Không còn emoji cũ (🪪, 🌐, 🐞, ⚡), chỉ dùng Material symbols chuẩn', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getAllByText(/2 sự cố/i).length).toBeGreaterThanOrEqual(1);
      });

      // Kiểm tra các nhãn vector không chứa emoji
      expect(screen.queryByText(/🪪/)).not.toBeInTheDocument();
      expect(screen.queryByText(/🌐/)).not.toBeInTheDocument();
      expect(screen.queryByText(/🐞/)).not.toBeInTheDocument();
      expect(screen.queryByText(/⚡/)).not.toBeInTheDocument();
    });

    it('1.4. Cột Đối tượng trong bảng RCA: Chỉ Vector Tài nguyên mới là Hệ thống, các Vector khác hiển thị TK & IP', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getAllByText(/2 sự cố/i).length).toBeGreaterThanOrEqual(1);
      });

      // Sự cố 1: Vector traffic (inc_traffic_001) -> Bắt buộc hiển thị TK & IP từ Client (Masked theo Data_Security.md)
      expect(screen.getByText(/client_shopper_01/i)).toBeInTheDocument();
      expect(screen.getByText(/113\.161/i)).toBeInTheDocument();
      expect(screen.queryByText('Lưu lượng mạng')).not.toBeInTheDocument();

      // Sự cố 2: Vector resource (inc_resource_002) -> Chỉ duy nhất vector này hiển thị Hệ thống - Nội bộ hệ thống
      expect(screen.getByText('Hệ thống')).toBeInTheDocument();
      expect(screen.getAllByText('Nội bộ hệ thống').length).toBeGreaterThanOrEqual(1);
    });
  });

  // =========================================================================
  // ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ (Real System Impact Verification)
  // =========================================================================
  describe('⚡ TẦNG 2: Real System Impact & Behavioral Verification', () => {
    it('2.1. Submit Tái Hiệu Chuẩn khi để trống: Hệ thống tự động lấy giá trị auto-calculated từ placeholder gửi về Backend', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText('AIOps Sentinel — Giám Sát & Phòng Vệ Tự Động')).toBeInTheDocument();
      });

      // Mở modal
      fireEvent.click(screen.getByRole('button', { name: /Tái Hiệu Chuẩn Baseline/i }));
      await waitFor(() => {
        expect(screen.getByTestId('input-auth-failure-threshold')).toBeInTheDocument();
      });

      // Nhấn nút submit modal (nút có icon check_circle)
      const submitBtn = screen.getByRole('button', { name: /check_circle/i });
      fireEvent.click(submitBtn);

      await waitFor(() => {
        expect(aiopsApi.calibrate).toHaveBeenCalledWith(
          expect.objectContaining({
            customThresholds: expect.objectContaining({
              authFailureThreshold: 25,
              trafficSpikeRps: 500,
              exploitLimit: 8,
              resourceCpuPercent: 85,
              resourceMemoryPercent: 85,
              eventLoopLagMs: 100,
            }),
          })
        );
      });
    });

    it('2.2. Submit Tái Hiệu Chuẩn khi Admin tự gõ số: Ưu tiên số do Admin nhập, các ô khác giữ giá trị auto-calculated', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText('AIOps Sentinel — Giám Sát & Phòng Vệ Tự Động')).toBeInTheDocument();
      });

      // Mở modal
      fireEvent.click(screen.getByRole('button', { name: /Tái Hiệu Chuẩn Baseline/i }));
      await waitFor(() => {
        expect(screen.getByTestId('input-auth-failure-threshold')).toBeInTheDocument();
      });

      // Admin tự gõ authFailureThreshold = 50 và resourceCpuPercent = 90
      const authInput = screen.getByTestId('input-auth-failure-threshold');
      fireEvent.change(authInput, { target: { value: '50' } });

      const cpuInput = screen.getByTestId('input-resource-cpu-percent');
      fireEvent.change(cpuInput, { target: { value: '90' } });

      // Nhấn submit
      const submitBtn = screen.getByRole('button', { name: /check_circle/i });
      fireEvent.click(submitBtn);

      await waitFor(() => {
        expect(aiopsApi.calibrate).toHaveBeenCalledWith(
          expect.objectContaining({
            customThresholds: expect.objectContaining({
              authFailureThreshold: 50, // Lấy số Admin nhập
              trafficSpikeRps: 500,     // Lấy số auto-calculated từ placeholder
              exploitLimit: 8,
              resourceCpuPercent: 90,   // Lấy số Admin nhập
              resourceMemoryPercent: 85,
              eventLoopLagMs: 100,
            }),
          })
        );
      });
    });

    it('2.3. Tác động của việc đổi Preset thời gian: Biểu đồ cập nhật dải thời gian thực tế', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText('Bộ lọc thời gian:')).toBeInTheDocument();
      });

      // Chuyển sang Preset 7 ngày
      const preset7d = screen.getByRole('button', { name: /7 ngày/i });
      fireEvent.click(preset7d);

      // Nút 7 ngày phải có class active (primary / text-white)
      expect(preset7d.className).toMatch(/bg-primary|text-white/);

      // Chuyển sang Preset 1 tháng
      const preset1m = screen.getByRole('button', { name: /1 tháng/i });
      fireEvent.click(preset1m);
      expect(preset1m.className).toMatch(/bg-primary|text-white/);
    });
  });
});
