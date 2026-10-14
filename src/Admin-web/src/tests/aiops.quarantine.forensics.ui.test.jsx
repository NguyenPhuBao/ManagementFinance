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
    getForensics: vi.fn(),
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

describe('AIOps Security Forensics & N-N Incident Link 2-Tier Test Suite (Task 5)', () => {
  const mockStatus = {
    threatScore: 20,
    status: 'NORMAL',
    targetConcurrency: 1000,
    windowSeconds: 10,
    vectorScores: { auth: 10, traffic: 15, exploit: 5, resource: 20 },
    vectorDefenses: {},
    sample: { cpuPercent: 25, cpuCores: 8, ramPercent: 65, ramUsedMb: 5200, ramTotalMb: 8000, rpm: 250, eventLoopLagMs: 2 },
    anomalies: [],
    currentClientIp: '127.0.0.1',
  };

  const mockQuarantineList = [
    {
      id: 'hash_test_123:::target_victim',
      hash: 'hash_test_123',
      ipHash: 'hash_test_123',
      maskedIp: '198.51.xx.xx',
      username: 'target_victim',
      idaccount: 101,
      ipStatus: 'temporary',
      accountStatus: 'temporary',
      reason: 'SQL Injection detected on login route',
      bannedAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 900000).toISOString(),
      remainingMinutes: 15,
      hits: 3,
    },
  ];

  const mockForensicData = {
    total: 2,
    page: 1,
    limit: 10,
    incidents: [
      {
        id: 1,
        incident_code: 'INC-20261012-TEST01',
        detected_at: new Date().toISOString(),
        ip_hash: 'hash_test_123',
        username: 'target_victim',
        reason: 'SQL Injection attempt detected',
      },
      {
        id: 2,
        incident_code: 'INC-20261012-TEST02',
        detected_at: new Date().toISOString(),
        ip_hash: 'hash_test_123',
        username: 'victim_account_2',
        reason: 'Brute-force credential stuffing',
      },
    ],
  };

  beforeEach(() => {
    vi.clearAllMocks();
    aiopsApi.getStatus.mockResolvedValue({ data: mockStatus });
    aiopsApi.getHistory.mockResolvedValue({ data: [] });
    aiopsApi.getQuarantineList.mockResolvedValue({ data: mockQuarantineList });
    aiopsApi.getIncidents.mockResolvedValue({ data: { list: [], total: 0 } });
    aiopsApi.getVectorConfig.mockResolvedValue({ data: { auth: true, traffic: true, exploit: true, resource: true } });
    adminApi.getMaintenanceStatus.mockResolvedValue({ data: { active: false } });
    aiopsApi.getForensics.mockResolvedValue({ data: mockForensicData });
  });

  it('TẦNG 1: Hiển thị icon điều tra trên bảng Quarantine Matrix và mở Modal khi click', async () => {
    render(<AIOpsPage />);

    // Đợi render xong dữ liệu
    await waitFor(() => {
      expect(screen.getByText('198.51.xxx.xxx')).toBeInTheDocument();
    });

    // Nút điều tra IP phải xuất hiện trên giao diện ở cột Thao tác
    const forensicsBtn = screen.getByTestId(/forensics-(action-)?btn-hash_test_123/);
    expect(forensicsBtn).toBeInTheDocument();

    // Click mở Modal điều tra
    fireEvent.click(forensicsBtn);

    // Modal xuất hiện và render đầy đủ thông tin
    await waitFor(() => {
      expect(screen.getByTestId('forensics-modal')).toBeInTheDocument();
      expect(screen.getByText(/Hồ Sơ Điều Tra An Ninh/i)).toBeInTheDocument();
      expect(screen.getByText('INC-20261012-TEST01')).toBeInTheDocument();
      expect(screen.getByText('victim_account_2')).toBeInTheDocument();
    });
  });

  it('TẦNG 2: Tác động hệ thống - Gọi đúng API Forensics N-N và hỗ trợ lọc chéo IP / Tài khoản', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText('198.51.xxx.xxx')).toBeInTheDocument();
    });

    const forensicsBtn = screen.getByTestId(/forensics-(action-)?btn-hash_test_123/);
    fireEvent.click(forensicsBtn);

    // Kiểm tra System Impact: aiopsApi.getForensics phải được gọi với tham số ipHash và limit mặc định là 5
    await waitFor(() => {
      expect(aiopsApi.getForensics).toHaveBeenCalledWith(
        expect.objectContaining({
          ipHash: 'hash_test_123',
          page: 1,
          limit: 5,
        })
      );
    });

    // Thử click chuyển tab lọc "Theo TK này"
    const userFilterBtn = screen.getByText('Theo TK này');
    expect(userFilterBtn).toBeInTheDocument();
    fireEvent.click(userFilterBtn);

    // Hệ thống kích hoạt API call mới lọc theo username
    await waitFor(() => {
      expect(aiopsApi.getForensics).toHaveBeenCalledWith(
        expect.objectContaining({
          username: 'target_victim',
          page: 1,
        })
      );
    });

    // Nút Đóng Modal đóng modal thành công
    const closeBtn = screen.getByRole('button', { name: /Đóng/i });
    fireEvent.click(closeBtn);

    await waitFor(() => {
      expect(screen.queryByTestId('forensics-modal')).not.toBeInTheDocument();
    });
  });
});
