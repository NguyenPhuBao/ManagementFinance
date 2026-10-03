import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import AIOpsPage from '../pages/system/AIOpsPage';
import aiopsApi from '../api/aiops.api';
import adminApi from '../api/admin.api';
import useSocket from '../hooks/useSocket';

vi.mock('../api/aiops.api', () => ({
  default: {
    getStatus: vi.fn(),
    getHistory: vi.fn(),
    getQuarantineList: vi.fn(),
    unblockQuarantine: vi.fn(),
    setScale: vi.fn(),
    calibrate: vi.fn(),
  },
}));

vi.mock('../api/admin.api', () => ({
  default: {
    setMaintenanceStatus: vi.fn(),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: vi.fn(),
}));

describe('Admin-web AIOps Suite — AIOpsPage (4-Vector Risk & Quarantine Shield)', () => {
  const socketListeners = {};
  const mockSocket = {
    connected: true,
    on: vi.fn((event, cb) => {
      socketListeners[event] = cb;
    }),
    off: vi.fn((event) => {
      delete socketListeners[event];
    }),
  };

  const mockStatus = {
    threatScore: 25,
    status: 'NORMAL',
    targetConcurrency: 1000,
    vectorScores: {
      auth: 10,
      traffic: 15,
      exploit: 0,
      resource: 25,
    },
    vectorDefenses: {
      auth: { defenseState: 'NORMAL' },
      traffic: { defenseState: 'NORMAL' },
      exploit: { defenseState: 'NORMAL' },
      resource: { defenseState: 'NORMAL' },
    },
    sample: {
      cpuPercent: 30,
      ramPercent: 45,
      eventLoopLagMs: 12,
      requestsPerMin: 120,
      failedLogins: 0,
      tokenReuseAttacks: 0,
      malformedRequests: 0,
    },
    anomalies: [],
    recommendedAction: null,
  };

  const mockQuarantine = [
    {
      hash: 'iphash_123456789',
      maskedIp: 'xxx.xxx.12.34',
      reason: 'SQLi Attempt on /api/v1/auth/login',
      vector: 'exploit',
      expireAt: new Date(Date.now() + 1800000).toISOString(),
      createdAt: new Date().toISOString(),
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
    window.confirm = vi.fn(() => true);
    useSocket.mockReturnValue(mockSocket);
    aiopsApi.getStatus.mockResolvedValue({ data: mockStatus });
    aiopsApi.getHistory.mockResolvedValue({ data: [] });
    aiopsApi.getQuarantineList.mockResolvedValue({ data: mockQuarantine });
  });

  it('5.1. Tải và hiển thị 4 Vectơ Rủi Ro Độc Lập cùng Threat Score Gauge', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(aiopsApi.getStatus).toHaveBeenCalledTimes(1);
      expect(screen.getByText('Hệ Số Đe Dọa (Threat Score)')).toBeInTheDocument();
      expect(screen.getByText('BÌNH THƯỜNG (NORMAL)')).toBeInTheDocument();
      // 4 tab riêng biệt
      expect(screen.getByText('1. Xác Thực')).toBeInTheDocument();
      expect(screen.getByText('2. Lưu Lượng')).toBeInTheDocument();
      expect(screen.getByText('3. Khai Thác')).toBeInTheDocument();
      expect(screen.getByText('4. Tài Nguyên')).toBeInTheDocument();
    });
  });

  it('5.2. Hiển thị danh sách Quarantine Shield với IP được Masking bảo mật (Zero Raw IP)', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText('xxx.xxx.12.34')).toBeInTheDocument();
      expect(screen.getByText('SQLi Attempt on /api/v1/auth/login')).toBeInTheDocument();
    });
  });

  it('5.3. Gỡ chặn IP trong danh sách cách ly gọi unblockQuarantine với hash', async () => {
    aiopsApi.unblockQuarantine.mockResolvedValueOnce({ data: { success: true } });

    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText('xxx.xxx.12.34')).toBeInTheDocument();
    });

    const unblockBtn = screen.getByRole('button', { name: /Gỡ Chặn/i });
    fireEvent.click(unblockBtn);

    await waitFor(() => {
      expect(aiopsApi.unblockQuarantine).toHaveBeenCalledWith('iphash_123456789');
    });
  });

  it('5.4. Phòng vệ đa vectơ: Khi Vector Exploit vượt ngưỡng nguy cơ, tự động kích hoạt thông điệp phòng vệ riêng', async () => {
    aiopsApi.getStatus.mockResolvedValueOnce({
      data: {
        ...mockStatus,
        threatScore: 85,
        status: 'WARNING',
        vectorScores: {
          auth: 10,
          traffic: 20,
          exploit: 85,
          resource: 25,
        },
      },
    });

    render(<AIOpsPage />);

    await waitFor(() => {
      expect(
        screen.getByText(/\[KHAI THÁC\] PHÁT HIỆN INJECTION\/TRAVERSAL/i)
      ).toBeInTheDocument();
    });
  });

  it('5.5. Cập nhật nhịp tim phân tích rủi ro thời gian thực qua Socket admin.metrics_stream', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText('Hệ Số Đe Dọa (Threat Score)')).toBeInTheDocument();
    });

    const streamHandler = socketListeners['admin.metrics_stream'];
    expect(streamHandler).toBeDefined();

    act(() => {
      streamHandler({
        threatScore: 92,
        threatStatus: 'CRITICAL',
        vectorScores: { auth: 95, traffic: 30, exploit: 10, resource: 40 },
        timestamp: new Date().toISOString(),
      });
    });

    await waitFor(() => {
      expect(screen.getByText('NGUY CẤP (CRITICAL)')).toBeInTheDocument();
    });
  });
});
