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

  const mockIncidents = [
    {
      id: 'inc_test_001',
      code: 'ANOMALY_AUTH_FAIL_SURGE',
      vector: 'auth',
      severity: 'HIGH',
      message: 'Đột biến 28 lần đăng nhập thất bại liên tiếp',
      status: 'ACTIVE',
      actor_type: 'USER',
      actor_identity: '113.161.xx.xx',
      actor_hash: 'a1b2c3d4e5f6',
      user_id: 'usr_888',
      username: 'attacker_victim',
      user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      target_endpoint: '/api/v1/auth/login',
      metric_current: 28,
      metric_baseline: 3,
      metric_unit: 'lần/phút',
      mitigation_taken: 'Quarantine Shield Activated',
      root_cause_diagnosis: 'Phát hiện chuỗi đăng nhập brute-force từ IP 113.161.xx.xx',
      hits: 4,
      first_detected_at: new Date(Date.now() - 300000).toISOString(),
      last_seen_at: new Date().toISOString(),
    },
    {
      id: 'inc_test_002',
      code: 'ANOMALY_TRAFFIC_SPIKE',
      vector: 'traffic',
      severity: 'MEDIUM',
      message: 'Lưu lượng truy cập vượt ngưỡng dự báo',
      status: 'MITIGATED',
      actor_type: 'IP',
      actor_identity: '42.112.xx.xx',
      actor_hash: 'd4e5f6a1b2c3',
      target_endpoint: '/api/v1/transactions',
      metric_current: 450,
      metric_baseline: 100,
      metric_unit: 'req/min',
      mitigation_taken: 'Adaptive Rate Limit',
      root_cause_diagnosis: 'Lưu lượng đột biến vượt 4.5x ngưỡng an toàn',
      hits: 1,
      first_detected_at: new Date(Date.now() - 600000).toISOString(),
      last_seen_at: new Date(Date.now() - 500000).toISOString(),
      mitigated_at: new Date(Date.now() - 400000).toISOString(),
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
    window.confirm = vi.fn(() => true);
    useSocket.mockReturnValue(mockSocket);
    aiopsApi.getStatus.mockResolvedValue({ data: mockStatus });
    aiopsApi.getHistory.mockResolvedValue({ data: [] });
    aiopsApi.getQuarantineList.mockResolvedValue({ data: mockQuarantine });
    aiopsApi.getIncidents.mockResolvedValue({
      data: {
        incidents: mockIncidents,
        total: 2,
        page: 1,
        limit: 10,
        totalPages: 1,
      },
    });
    adminApi.getMaintenanceStatus.mockResolvedValue({ data: { active: false, scheduled: null } });
    aiopsApi.clearIncidents.mockResolvedValue({ data: { success: true } });
    aiopsApi.getVectorConfig.mockResolvedValue({
      data: { auth: true, traffic: true, exploit: true, resource: true },
    });
    aiopsApi.toggleVector.mockResolvedValue({
      data: { success: true, vectorConfig: { auth: true, traffic: true, exploit: true, resource: true } },
    });
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

  it('5.6. Hiển thị bảng Root Cause Analysis (RCA) từ CSDL với đầy đủ actor identity và phân trang', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(aiopsApi.getIncidents).toHaveBeenCalled();
      expect(screen.getByText(/2 sự cố ghi nhận trong CSDL/)).toBeInTheDocument();
      expect(screen.getByText('113.161.xx.xx')).toBeInTheDocument();
      expect(screen.getByText('42.112.xx.xx')).toBeInTheDocument();
      expect(screen.getByText(/attacker_victim/)).toBeInTheDocument();
      expect(screen.getByText(/ANOMALY_AUTH_FAIL_SURGE/)).toBeInTheDocument();
      expect(screen.getByText(/ANOMALY_TRAFFIC_SPIKE/)).toBeInTheDocument();
      expect(screen.getByText(/ĐANG DIỄN RA/)).toBeInTheDocument();
      expect(screen.getByText(/ĐÃ GIẢM THIỂU/)).toBeInTheDocument();
      expect(screen.getByText(/1 - 2 of 2 sự cố ghi nhận/)).toBeInTheDocument();
    });
  });

  it('5.7. Bộ lọc Vector gọi lại getIncidents với đúng tham số lọc', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText('2 sự cố ghi nhận trong CSDL')).toBeInTheDocument();
    });

    const authBtn = screen.getByRole('button', { name: /🛡️ Xác thực/i });
    fireEvent.click(authBtn);

    await waitFor(() => {
      expect(aiopsApi.getIncidents).toHaveBeenCalledWith(
        expect.objectContaining({
          vector: 'auth',
          page: 1,
        })
      );
    });
  });

  it('5.8. Lắng nghe sự kiện Socket.io admin.anomaly_detected để bổ sung sự cố mới theo thời gian thực', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText('2 sự cố ghi nhận trong CSDL')).toBeInTheDocument();
    });

    const anomalyHandler = socketListeners['admin.anomaly_detected'];
    expect(anomalyHandler).toBeDefined();

    const newIncident = {
      id: 'inc_test_003',
      code: 'ANOMALY_SQLI_PROBE',
      vector: 'exploit',
      severity: 'HIGH',
      message: 'Phát hiện payload SQL Injection nghi vấn',
      status: 'ACTIVE',
      actor_type: 'IP',
      actor_identity: '1.2.xx.xx',
      actor_hash: '998877665544',
      target_endpoint: '/api/v1/users',
      metric_current: 12,
      metric_baseline: 0,
      metric_unit: 'lần',
      mitigation_taken: 'Blocked by Shield',
      root_cause_diagnosis: 'Tấn công khai thác thăm dò lỗ hổng SQLi',
      hits: 1,
      first_detected_at: new Date().toISOString(),
      last_seen_at: new Date().toISOString(),
    };

    act(() => {
      anomalyHandler(newIncident);
    });

    await waitFor(() => {
      expect(screen.getByText('ANOMALY_SQLI_PROBE')).toBeInTheDocument();
      expect(screen.getByText('1.2.xx.xx')).toBeInTheDocument();
    });
  });

  it('5.9. Làm sạch CSDL sự cố (Clear Incidents) qua ConfirmModal và gọi aiopsApi.clearIncidents', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText('2 sự cố ghi nhận trong CSDL')).toBeInTheDocument();
    });

    const clearBtn = screen.getByRole('button', { name: /Làm sạch CSDL/i });
    fireEvent.click(clearBtn);

    await waitFor(() => {
      expect(screen.getByText('Làm sạch Toàn bộ Nhật ký Sự cố CSDL')).toBeInTheDocument();
    });

    const confirmClearBtn = screen.getByRole('button', { name: /Xác nhận Xóa CSDL/i });
    fireEvent.click(confirmClearBtn);

    await waitFor(() => {
      expect(aiopsApi.clearIncidents).toHaveBeenCalled();
    });
  });

  it('5.10. Lưu cứng quy mô người dùng đồng thời (Target Concurrency) trong localStorage và đồng bộ từ CSDL', async () => {
    aiopsApi.setScale.mockResolvedValueOnce({
      success: true,
      targetConcurrency: 2500,
      expectedBaselineRPM: 25000,
      message: 'Đã cập nhật quy mô hệ thống lên 2500 người dùng thành công!',
    });

    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText(/Quy Mô Người Dùng Mục Tiêu/i)).toBeInTheDocument();
    });

    const input = screen.getByPlaceholderText(/VD: 1000, 2000/i);
    fireEvent.change(input, { target: { value: '2500' } });

    const applyBtn = screen.getByRole('button', { name: /Áp Dụng/i });
    fireEvent.click(applyBtn);

    await waitFor(() => {
      expect(aiopsApi.setScale).toHaveBeenCalledWith(2500);
      expect(window.localStorage.getItem('aiops_target_concurrency')).toBe('2500');
      expect(screen.getByText('2.500')).toBeInTheDocument();
    });
  });

  it('5.11. Cho phép Admin bấm nút "Phong Tỏa IP" trên bảng RCA, mở ConfirmModal và gọi aiopsApi.quarantineActor', async () => {
    aiopsApi.quarantineActor.mockResolvedValueOnce({
      success: true,
      data: {
        hash: '112233445566',
        maskedIp: '113.161.xx.xx',
        reason: 'Admin chủ động phong tỏa từ nhật ký RCA',
        bannedAt: new Date().toISOString(),
        expiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
        hits: 1,
      },
      message: 'Đã phong tỏa nguồn IP 113.161.xx.xx thành công trong 15 phút',
    });

    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText('2 sự cố ghi nhận trong CSDL')).toBeInTheDocument();
    });

    // Tìm các nút "Phong Tỏa IP" trên bảng RCA
    const quarantineButtons = screen.getAllByRole('button', { name: /Phong Tỏa IP/i });
    expect(quarantineButtons.length).toBeGreaterThan(0);

    // Bấm nút "Phong Tỏa IP" của sự cố đầu tiên
    fireEvent.click(quarantineButtons[0]);

    // Modal xác nhận xuất hiện
    await waitFor(() => {
      expect(screen.getByText('Xác nhận Phong Tỏa Nguồn IP (Active Quarantine)')).toBeInTheDocument();
      expect(screen.getByText(/Bạn có chắc chắn muốn kích hoạt Khiên Chắn Active Quarantine/i)).toBeInTheDocument();
    });

    // Xác nhận phong tỏa
    const confirmQuarantineBtn = screen.getByRole('button', { name: /Xác Nhận Phong Tỏa/i });
    fireEvent.click(confirmQuarantineBtn);

    await waitFor(() => {
      expect(aiopsApi.quarantineActor).toHaveBeenCalledWith(
        expect.objectContaining({
          hash: 'a1b2c3d4e5f6',
          maskedIp: '113.161.xx.xx',
          durationMinutes: 15,
        })
      );
    });
  });

  it('5.12. Hiển thị thẻ Tình Trạng Hệ Thống phía trên Target Concurrency Scaler với Badge xanh lá nhạt', async () => {
    adminApi.getMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: false,
        scheduled: null,
      },
    });

    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText('Tình Trạng Hệ Thống:')).toBeInTheDocument();
      expect(screen.getByText('Đang hoạt động')).toBeInTheDocument();
    });
  });

  it('5.13. Cập nhật thẻ Tình Trạng Hệ Thống sang "Đang bảo trì" khi nhận Socket admin.maintenance_changed', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText('Tình Trạng Hệ Thống:')).toBeInTheDocument();
    });

    const mHandler = socketListeners['admin.maintenance_changed'];
    expect(mHandler).toBeDefined();

    act(() => {
      mHandler({
        active: true,
        isEmergency: true,
        reason: 'Bảo trì khẩn cấp nâng cấp cụm DB',
        activatedBy: 'SecurityOps',
        activatedAt: new Date().toISOString(),
      });
    });

    await waitFor(() => {
      expect(screen.getByText('Đang bảo trì')).toBeInTheDocument();
      expect(screen.getByText(/Bảo trì khẩn cấp nâng cấp cụm DB/i)).toBeInTheDocument();
      expect(screen.getByText('Điều Hành Bảo Trì')).toBeInTheDocument();
    });
  });

  it('5.14. Bật/Tắt từng vector: Click toggle mở ConfirmModal xác nhận, bấm xác nhận gọi API toggleVector và cập nhật UI', async () => {
    aiopsApi.toggleVector.mockResolvedValueOnce({
      data: {
        success: true,
        vectorConfig: { auth: false, traffic: true, exploit: true, resource: true },
      },
    });

    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByTestId('toggle-vector-auth')).toBeInTheDocument();
    });

    // 1. Click toggle switch của Vector 1 (Xác thực)
    const toggleAuth = screen.getByTestId('toggle-vector-auth');
    fireEvent.click(toggleAuth);

    // 2. Kiểm tra Popup xác nhận (ConfirmModal) hiển thị
    await waitFor(() => {
      expect(screen.getByText('Xác nhận TẮT Vector')).toBeInTheDocument();
      expect(screen.getByText(/Hệ thống VẪN TIẾP TỤC ĐO LƯỜNG thông số để bạn quan sát/i)).toBeInTheDocument();
    });

    // 3. Bấm nút Xác nhận TẮT trên modal
    const confirmBtn = screen.getByRole('button', { name: /Xác nhận TẮT/i });
    fireEvent.click(confirmBtn);

    // 4. Verify API toggleVector được gọi chính xác
    await waitFor(() => {
      expect(aiopsApi.toggleVector).toHaveBeenCalledWith('auth', false);
    });
  });

  it('5.15. Khi Vector bị TẮT: Vẫn đo lường hiển thị sub-score nhưng hiển thị badge chỉ đo lường và tắt phòng vệ', async () => {
    aiopsApi.getVectorConfig.mockResolvedValueOnce({
      data: { auth: true, traffic: true, exploit: false, resource: true },
    });

    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText(/3\. Khai Thác Lỗ Hổng/i)).toBeInTheDocument();
    });

    // Vẫn hiển thị điểm đo lường của vector
    expect(screen.getAllByText('0').length).toBeGreaterThan(0);

    // Hiển thị badge chỉ đo lường
    expect(
      screen.getByText(/Chế độ chỉ đo lường — Bỏ qua khỏi Threat Score/i)
    ).toBeInTheDocument();
    expect(
      screen.getByText(/Đã tắt phòng vệ — Chỉ đo lường/i)
    ).toBeInTheDocument();
  });

  it('5.16. Bộ select thời gian quan sát xu hướng 4 Vector (Presets: realtime, day, month, year) gọi getHistory', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByTestId('preset-day')).toBeInTheDocument();
    });

    // Click Day (24 giờ qua)
    fireEvent.click(screen.getByTestId('preset-day'));
    await waitFor(() => {
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: 'day' });
    });

    // Click Month (30 ngày qua)
    fireEvent.click(screen.getByTestId('preset-month'));
    await waitFor(() => {
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: 'month' });
    });

    // Click Year (12 tháng qua)
    fireEvent.click(screen.getByTestId('preset-year'));
    await waitFor(() => {
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: 'year' });
    });
  });

  it('5.17. Bộ lọc chọn chính xác và Quy tắc ưu tiên cốt lõi: Ưu tiên bộ lọc chọn chính xác thay vì bộ select nếu cả 2 được áp dụng', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByTestId('apply-custom-range-btn')).toBeInTheDocument();
    });

    // Chọn Preset Day trước
    fireEvent.click(screen.getByTestId('preset-day'));
    await waitFor(() => {
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: 'day' });
    });

    // Nhập bộ lọc chi tiết chính xác (Từ ngày đến ngày)
    const fromInput = screen.getByTestId('filter-from-date');
    const toInput = screen.getByTestId('filter-to-date');
    fireEvent.change(fromInput, { target: { value: '2026-09-01' } });
    fireEvent.change(toInput, { target: { value: '2026-10-04' } });

    // Bấm Lọc Chính Xác
    const applyBtn = screen.getByTestId('apply-custom-range-btn');
    fireEvent.click(applyBtn);

    // Verify PO Rule: Ưu tiên bộ lọc chính xác, params gửi { from, to } thay vì { range: 'day' }
    await waitFor(() => {
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ from: '2026-09-01', to: '2026-10-04' });
      expect(screen.getByText(/ĐANG ƯU TIÊN BỘ LỌC CHÍNH XÁC/i)).toBeInTheDocument();
      expect(screen.getByText(/Bộ select nhanh đang tạm thời bị bỏ qua/i)).toBeInTheDocument();
    });

    // Bấm xóa bộ lọc chính xác -> quay lại preset Day
    const clearBtn = screen.getByTestId('clear-custom-range-btn');
    fireEvent.click(clearBtn);

    await waitFor(() => {
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: 'day' });
    });
  });

  it('5.18. Đồng bộ cấu hình vector realtime khi nhận Socket admin.vector_config_changed', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByTestId('toggle-vector-traffic')).toBeInTheDocument();
    });

    const vConfigHandler = socketListeners['admin.vector_config_changed'];
    expect(vConfigHandler).toBeDefined();

    act(() => {
      vConfigHandler({ auth: true, traffic: false, exploit: true, resource: true });
    });

    await waitFor(() => {
      const toggleTraffic = screen.getByTestId('toggle-vector-traffic');
      expect(toggleTraffic.getAttribute('aria-checked')).toBe('false');
    });
  });
});

