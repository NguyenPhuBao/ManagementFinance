import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import AIOpsPage from '../pages/system/AIOpsPage';
import aiopsApi from '../api/aiops.api';
import adminApi from '../api/admin.api';

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
    getVectorConfig: vi.fn(),
    toggleVector: vi.fn(),
  },
}));

vi.mock('../api/admin.api', () => ({
  default: {
    getMaintenanceStatus: vi.fn(),
    setMaintenanceStatus: vi.fn(),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: vi.fn(() => ({
    connected: true,
    on: vi.fn(),
    off: vi.fn(),
  })),
}));

describe('AIOps Object Column (TK & IP) and Quarantine IP 2-Tier Test Suite', () => {
  const mockStatus = {
    threatScore: 35,
    status: 'NORMAL',
    targetConcurrency: 1000,
    windowSeconds: 10,
    currentClientIp: '192.168.1.100',
    vectorScores: {
      auth: 40,
      traffic: 30,
      exploit: 20,
      resource: 10,
    },
    vectorDefenses: {},
    sample: {
      cpuPercent: 35,
      cpuCores: 8,
      ramPercent: 55,
      eventLoopLagMs: 8,
      requestsPerMin: 150,
      failedLogins: 0,
      tokenReuseAttacks: 0,
      malformedRequests: 0,
    },
    anomalies: [],
    recommendedAction: null,
  };

  const mockIncidents = [
    {
      id: 'inc_real_user_001',
      code: 'AUTH_BRUTE_FORCE',
      vector: 'auth',
      severity: 'HIGH',
      message: 'Đăng nhập sai dồn dập',
      status: 'ACTIVE',
      actor_type: 'IP_SOURCE',
      actor_identity: '113.161.72.10',
      actor_hash: 'hash_real_user',
      user_id: 105,
      username: 'attacker_victim_real',
      hits: 5,
      first_detected_at: new Date(Date.now() - 120000).toISOString(),
      last_seen_at: new Date().toISOString(),
    },
    {
      id: 'inc_mockup_cleanup_002',
      code: 'TRAFFIC_ANOMALY_FLOOD',
      vector: 'traffic',
      severity: 'HIGH',
      message: 'Lưu lượng tăng vọt',
      status: 'MITIGATED',
      actor_type: 'IP_SOURCE',
      actor_identity: '1 địa chỉ IP tập trung', // Dữ liệu cũ cần tự động chuẩn hóa
      actor_hash: 'hash_traffic_cluster',
      hits: 3,
      first_detected_at: new Date(Date.now() - 300000).toISOString(),
      last_seen_at: new Date(Date.now() - 100000).toISOString(),
    },
    {
      id: 'inc_system_resource_003',
      code: 'RESOURCE_RAM_EXHAUSTION',
      vector: 'resource',
      severity: 'HIGH',
      message: 'RAM tiêu thụ 95%',
      status: 'MITIGATED',
      actor_type: 'SYSTEM_INTERNAL',
      actor_identity: 'Hạ tầng máy chủ',
      actor_hash: 'system_core',
      hits: 1,
      first_detected_at: new Date(Date.now() - 600000).toISOString(),
      last_seen_at: new Date(Date.now() - 500000).toISOString(),
    },
  ];

  const mockQuarantineList = [
    {
      id: 'q_pair_1',
      ipHash: 'hash_user_test',
      maskedIp: 'xx.xx.xx.xx', // Dữ liệu cũ cần sanitize về 192.168.xxx.xxx
      username: 'user_controller_test',
      vector: 'auth',
      ipStatus: 'temporary',
      accountStatus: 'temporary',
      reason: 'SQL Injection detected',
      bannedAt: new Date(Date.now() - 60000).toISOString(),
      remainingMinutes: 240,
    },
    {
      id: 'q_pair_2',
      ipHash: 'hash_real_ip',
      maskedIp: '113.161.xx.xx', // IP thật định dạng chuẩn
      username: 'user_real_ip',
      vector: 'auth',
      ipStatus: 'temporary',
      accountStatus: 'temporary',
      reason: 'Brute-Force Attack',
      bannedAt: new Date(Date.now() - 120000).toISOString(),
      remainingMinutes: 200,
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
    aiopsApi.getStatus.mockResolvedValue({ data: mockStatus });
    aiopsApi.getHistory.mockResolvedValue({ data: [] });
    aiopsApi.getVectorConfig.mockResolvedValue({ data: { auth: true, traffic: true, exploit: true, resource: true } });
    aiopsApi.getIncidents.mockResolvedValue({ data: { incidents: mockIncidents, total: 3 } });
    aiopsApi.getQuarantineList.mockResolvedValue({ data: mockQuarantineList });
    adminApi.getMaintenanceStatus.mockResolvedValue({ data: { is_active: false } });
  });

  // ─────────────────────────────────────────────────────────────
  // 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC (UI RENDERING & INTERACTION)
  // ─────────────────────────────────────────────────────────────
  describe('🧱 TẦNG 1: UI Rendering & Clean Masking Verification', () => {
    it('1.1. Bảng RCA > Cột Đối tượng hiển thị đúng username tài khoản thật (TK: attacker_victim_real)', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        expect(screen.getByText('attacker_victim_real')).toBeInTheDocument();
      });

      // Hiển thị nhãn TK: trước username
      const tkLabels = screen.getAllByText('TK:');
      expect(tkLabels.length).toBeGreaterThanOrEqual(1);
    });

    it('1.2. Bảng RCA > Cột Đối tượng hiển thị IP thực đã che mờ dạng a.b.xxx.xxx (113.161.xxx.xxx)', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        const elements = screen.getAllByText('113.161.xxx.xxx');
        expect(elements.length).toBeGreaterThanOrEqual(1);
      });
    });

    it('1.3. Bảng RCA > Loại bỏ hoàn toàn chuỗi mockup "1 địa chỉ IP tập trung", tự động chuẩn hóa về 192.168.xxx.xxx', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        // Chuỗi mockup "1 địa chỉ IP tập trung" tuyệt đối không được hiển thị ở cột IP
        expect(screen.queryByText('1 địa chỉ IP tập trung')).not.toBeInTheDocument();
        // Thay vào đó hiển thị IP chuẩn 192.168.xxx.xxx
        expect(screen.getAllByText('192.168.xxx.xxx').length).toBeGreaterThanOrEqual(1);
      });
    });

    it('1.4. Bảng RCA > Sự cố tài nguyên hệ thống nội bộ hiển thị "Hệ thống" và "Nội bộ hệ thống"', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        expect(screen.getAllByText('Hệ thống').length).toBeGreaterThanOrEqual(1);
        expect(screen.getAllByText('Nội bộ hệ thống').length).toBeGreaterThanOrEqual(1);
      });
    });

    it('1.5. Bảng Quarantine > Cột Địa chỉ IP không bao giờ hiển thị "xx.xx.xxx.xxx", tự động chuẩn hóa về 192.168.xxx.xxx', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        // Tuyệt đối không hiển thị xx.xx.xxx.xxx
        expect(screen.queryByText('xx.xx.xxx.xxx')).not.toBeInTheDocument();
        // Bản ghi 1 hiển thị chuẩn 192.168.xxx.xxx
        expect(screen.getAllByText('192.168.xxx.xxx').length).toBeGreaterThanOrEqual(1);
        // Bản ghi 2 hiển thị 113.161.xxx.xxx
        expect(screen.getAllByText('113.161.xxx.xxx').length).toBeGreaterThanOrEqual(1);
        // Cột tài khoản hiển thị đúng username
        expect(screen.getByText('user_controller_test')).toBeInTheDocument();
      });
    });

    it('1.6. Bảng RCA > Cột Tình trạng đã loại bỏ hoàn toàn dòng chữ "Gần nhất:" kể cả khi có nhiều lần lặp lại', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        expect(screen.queryByText(/Gần nhất:/i)).not.toBeInTheDocument();
      });
    });
  });

  // ─────────────────────────────────────────────────────────────
  // ⚡ TẦNG 2: KIỂM THỬ HOẠT ĐỘNG THỰC TẾ & TÁC ĐỘNG HỆ THỐNG (SYSTEM IMPACT)
  // ─────────────────────────────────────────────────────────────
  describe('⚡ TẦNG 2: Real System Impact & Behavioral Verification', () => {
    it('2.1. Thao tác Phong Tỏa IP từ RCA Modal hiển thị chính xác IP che mờ chuẩn (không phải xx.xx.xx.xx)', async () => {
      aiopsApi.quarantineActor.mockResolvedValueOnce({
        success: true,
        data: { maskedIp: '113.161.xxx.xxx', hash: 'hash_real_user' },
        message: 'Đã phong tỏa nguồn IP 113.161.xxx.xxx thành công trong 15 phút',
      });

      render(<AIOpsPage />);

      // Chờ bảng RCA nạp xong và nút Phong Tỏa IP xuất hiện
      await waitFor(() => {
        expect(screen.getByTitle('Phong Tỏa IP 113.161.xxx.xxx')).toBeInTheDocument();
      });

      // Nhấn nút Phong Tỏa IP trên dòng sự cố thực
      const quarantineBtn = screen.getByTitle('Phong Tỏa IP 113.161.xxx.xxx');
      fireEvent.click(quarantineBtn);

      // Modal xác nhận xuất hiện và chứa IP chuẩn 113.161.xxx.xxx (không phải xx.xx.xx.xx)
      await waitFor(() => {
        const dialog = screen.getByRole('dialog');
        expect(dialog).toBeInTheDocument();
        expect(dialog).toHaveTextContent('113.161.xxx.xxx');
        expect(dialog).not.toHaveTextContent('xx.xx.xx.xx');
      });

      // Nhấn xác nhận phong tỏa
      const confirmBtn = screen.getByRole('button', { name: /Xác Nhận Phong Tỏa/i });
      fireEvent.click(confirmBtn);

      // Xác nhận API quarantineActor được gọi với đúng thông tin hệ thống thực
      await waitFor(() => {
        expect(aiopsApi.quarantineActor).toHaveBeenCalledWith(
          expect.objectContaining({
            hash: 'hash_real_user',
            vector: 'auth',
          })
        );
      });
    });
  });
});
