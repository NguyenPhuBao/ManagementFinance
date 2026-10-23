import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act, within } from '@testing-library/react';
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

  it('5.3. Gỡ chặn IP trong danh sách cách ly gọi unblockIp với ipHash', async () => {
    window.confirm = vi.fn(() => true);
    aiopsApi.unblockIp.mockResolvedValueOnce({ success: true });

    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText('xxx.xxx.12.34')).toBeInTheDocument();
    });

    const unblockBtn = screen.getByRole('button', { name: /Mở khóa IP/i });
    fireEvent.click(unblockBtn);

    await waitFor(() => {
      expect(aiopsApi.unblockIp).toHaveBeenCalledWith({ ipHash: 'iphash_123456789' });
    });
  });

  it('5.4. Phòng vệ đa vectơ: Khi Vector Exploit vượt ngưỡng nguy cơ, bảo đảm an toàn thông tin và không để lộ cơ chế phòng vệ nội bộ', async () => {
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
      expect(screen.getByText('3. Khai Thác Lỗ Hổng')).toBeInTheDocument();
      // Bảo đảm KHÔNG để lộ cơ chế phòng vệ nội bộ Sentinel trên UI theo mục 8 & 14
      expect(screen.queryByText(/Phòng vệ Sentinel:/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Công thức tổng hợp:/i)).not.toBeInTheDocument();
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
      expect(screen.getAllByText(/2 sự cố/i).length).toBeGreaterThanOrEqual(1);
      expect(screen.getByText('113.161.xxx.xxx')).toBeInTheDocument();
      expect(screen.getByText('Lưu lượng mạng')).toBeInTheDocument();
      expect(screen.getByText(/attacker_victim/)).toBeInTheDocument();
      expect(screen.getByText(/ĐANG DIỄN RA/)).toBeInTheDocument();
      expect(screen.getByText(/ĐÃ GIẢM THIỂU/)).toBeInTheDocument();
    });
  });

  it('5.7. Bộ lọc Vector gọi lại getIncidents với đúng tham số lọc', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getAllByText(/2 sự cố/i).length).toBeGreaterThanOrEqual(1);
    });

    const authBtn = screen.getByRole('button', { name: /🛡️\s*Xác thực/i });
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
      expect(screen.getAllByText(/2 sự cố/i).length).toBeGreaterThanOrEqual(1);
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
      expect(screen.getByText('Phát hiện payload SQL Injection nghi vấn')).toBeInTheDocument();
      expect(screen.getByText('1.2.xxx.xxx')).toBeInTheDocument();
    });
  });

  it('5.9. [Security Rule 2.5] Tuyệt đối KHÔNG có nút Làm sạch CSDL để bảo vệ tính toàn vẹn dữ liệu truy vết', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getAllByText(/2 sự cố/i).length).toBeGreaterThanOrEqual(1);
    });

    // Tuyệt đối không có nút "Làm sạch CSDL"
    expect(screen.queryByRole('button', { name: /Làm sạch CSDL/i })).toBeNull();
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
      expect(screen.getByDisplayValue('2500')).toBeInTheDocument();
    });
  });

  it('5.11. Cho phép Admin bấm nút "Phong Tỏa IP" trên bảng RCA, mở ConfirmModal và gọi aiopsApi.quarantineActor', async () => {
    aiopsApi.getQuarantineList.mockResolvedValueOnce([]);
    aiopsApi.quarantineActor.mockResolvedValueOnce({
      success: true,
      data: {
        hash: '112233445566',
        maskedIp: '113.161.xxx.xxx',
        reason: 'Admin chủ động phong tỏa từ nhật ký RCA',
        bannedAt: new Date().toISOString(),
        expiresAt: new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString(),
        hits: 1,
      },
      message: 'Đã phong tỏa nguồn IP 113.161.xxx.xxx thành công trong 4 giờ',
    });

    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getAllByText(/2 sự cố/i).length).toBeGreaterThanOrEqual(1);
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
          durationMinutes: 240,
        })
      );
    });
  });

  it('5.12. Box Tình Trạng Hệ Thống đã được loại bỏ hoàn toàn khỏi giao diện theo yêu cầu PO', async () => {
    adminApi.getMaintenanceStatus.mockResolvedValueOnce({
      data: {
        active: false,
        scheduled: null,
      },
    });

    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.queryByText('Tình Trạng Hệ Thống:')).toBeNull();
    });
  });

  it('5.13. Không còn hiển thị thẻ Tình Trạng Hệ Thống khi nhận Socket admin.maintenance_changed', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.queryByText('Tình Trạng Hệ Thống:')).toBeNull();
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
      expect(screen.queryByText('Tình Trạng Hệ Thống:')).toBeNull();
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
      screen.getByText(/Bỏ qua khỏi Threat Score/i)
    ).toBeInTheDocument();
    expect(
      screen.getByText(/Đã tắt phòng vệ — Chỉ đo lường/i)
    ).toBeInTheDocument();
  });

  it('5.16. Bộ select thời gian quan sát xu hướng 4 Vector (Presets: 10m, 1h, 24h, 7d, 30d) gọi getHistory', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByTestId('preset-24h')).toBeInTheDocument();
    });

    // Click 1 giờ qua
    fireEvent.click(screen.getByTestId('preset-1h'));
    await waitFor(() => {
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '1h' });
    });

    // Click 24 giờ qua
    fireEvent.click(screen.getByTestId('preset-24h'));
    await waitFor(() => {
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '24h' });
    });

    // Click 7 ngày qua
    fireEvent.click(screen.getByTestId('preset-7d'));
    await waitFor(() => {
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '7d' });
    });

    // Click 1 tháng qua
    fireEvent.click(screen.getByTestId('preset-30d'));
    await waitFor(() => {
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '30d' });
    });
  });

  it('5.17. Bộ lọc thời gian và Quy tắc ưu tiên cốt lõi: Ưu tiên bộ lọc thời gian thay vì bộ select nếu cả 2 được áp dụng', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByTestId('apply-custom-range-btn')).toBeInTheDocument();
    });

    // Chọn Preset 24h trước
    fireEvent.click(screen.getByTestId('preset-24h'));
    await waitFor(() => {
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '24h' });
    });

    // Nhập bộ lọc thời gian (datetime-local Từ ngày đến ngày)
    const fromInput = screen.getByTestId('filter-from-date');
    const toInput = screen.getByTestId('filter-to-date');
    fireEvent.change(fromInput, { target: { value: '2026-09-01T10:00' } });
    fireEvent.change(toInput, { target: { value: '2026-10-04T18:00' } });

    // Bấm Lọc
    const applyBtn = screen.getByTestId('apply-custom-range-btn');
    fireEvent.click(applyBtn);

    // Verify PO Rule: Ưu tiên bộ lọc thời gian, params gửi { from, to } thay vì { range: '24h' }
    await waitFor(() => {
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ from: '2026-09-01T10:00', to: '2026-10-04T18:00' });
      expect(screen.getByText(/ĐANG ƯU TIÊN BỘ LỌC THỜI GIAN/i)).toBeInTheDocument();
    });

    // Bấm xóa bộ lọc thời gian -> quay lại preset 24h
    const clearBtn = screen.getByTestId('clear-custom-range-btn');
    fireEvent.click(clearBtn);

    await waitFor(() => {
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '24h' });
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

  it('5.19. Nút "Làm Mới" bên cạnh nút "Lọc" reset input và trả về preset mặc định', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByTestId('refresh-custom-range-btn')).toBeInTheDocument();
    });

    const fromInput = screen.getByTestId('filter-from-date');
    const toInput = screen.getByTestId('filter-to-date');
    fireEvent.change(fromInput, { target: { value: '2026-09-01T10:00' } });
    fireEvent.change(toInput, { target: { value: '2026-10-04T18:00' } });
    expect(fromInput.value).toBe('2026-09-01T10:00');
    expect(toInput.value).toBe('2026-10-04T18:00');

    // Bấm Làm Mới
    const refreshBtn = screen.getByTestId('refresh-custom-range-btn');
    fireEvent.click(refreshBtn);

    await waitFor(() => {
      expect(fromInput.value).toBe('');
      expect(toInput.value).toBe('');
    });
  });

  it('5.20. Biểu đồ xu hướng không chứa chữ thừa _toggle_drop_down và đã dọn dẹp footer theo Rule 1.7', async () => {
    render(<AIOpsPage />);

    await waitFor(() => {
      expect(screen.getByText('Biểu Đồ Xu Hướng 4 Vectơ Rủi Ro')).toBeInTheDocument();
    });

    // Không được chứa chuỗi lỗi ligature _toggle_drop_down
    expect(screen.queryByText(/_toggle_drop_down/i)).toBeNull();

    // Đã bỏ footer Trục X: Ngày... và Nguyên tắc: Phòng vệ được kích hoạt độc lập
    expect(screen.queryByText(/Trục X: Ngày/i)).toBeNull();
    expect(screen.queryByText(/Phòng vệ được kích hoạt độc lập theo từng vectơ/i)).toBeNull();
  });

  it('5.21. Kiểm thử 2 Tầng (2-Tier Verification): Tắt Vector Resource lập tức hạ Threat Score và cập nhật UI sang trạng thái An toàn', async () => {
    aiopsApi.toggleVector.mockResolvedValueOnce({
      data: {
        success: true,
        vector: 'resource',
        enabled: false,
        vectorConfig: { auth: true, traffic: true, exploit: true, resource: false },
        currentStatus: {
          threatScore: 5,
          status: 'NORMAL',
          vectorScores: { auth: 0, traffic: 0, exploit: 0, resource: 85 },
          vectorDefenses: {
            resource: { disabled: true, status: 'NORMAL', defenseAction: 'MONITOR' },
          },
          anomalies: [],
          recommendedAction: null,
        },
      },
    });

    render(<AIOpsPage />);

    // Tầng 1: Đảm bảo giao diện nạp xong dữ liệu và hiển thị toggle vector Resource
    await waitFor(() => expect(aiopsApi.getStatus).toHaveBeenCalled());
    const toggleResource = await screen.findByTestId('toggle-vector-resource');
    expect(toggleResource).toBeInTheDocument();

    // Thao tác: Bấm vào toggle của Vector 4 (Resource)
    fireEvent.click(toggleResource);

    // Xác nhận Modal mở ra
    await waitFor(() => {
      expect(screen.getByText('Xác nhận TẮT Vector')).toBeInTheDocument();
    });

    // Click nút xác nhận trong Modal
    const dialog = screen.getByRole('dialog', { name: /Xác nhận TẮT Vector/i });
    const confirmBtn = within(dialog).getByRole('button', { name: /Xác nhận TẮT/i });
    fireEvent.click(confirmBtn);

    // Tầng 2: Kiểm tra System Impact & Behavioral Verification
    await waitFor(() => {
      // 1. API được gọi đúng tham số
      expect(aiopsApi.toggleVector).toHaveBeenCalledWith('resource', false);
      // 2. Toggle state chuyển sang false
      expect(toggleResource.getAttribute('aria-checked')).toBe('false');
      // 3. Threat Score giảm xuống 5/100 (NORMAL)
      expect(screen.getByTestId('threat-score-value')).toHaveTextContent('5');
      expect(screen.getByText('/ 100')).toBeInTheDocument();
      // 4. Modal đóng hoàn toàn
      expect(screen.queryByText('Xác nhận TẮT Vector')).toBeNull();
    });
  });

  it('8. [Regression Test] Biểu đồ Lịch sử render trơn tru với mẫu dữ liệu có Resource Vector mà không gặp lỗi ReferenceError', async () => {
    // Giả lập lịch sử chứa nhiều mẫu dữ liệu khác nhau (có/không có vectorScores)
    aiopsApi.getHistory.mockResolvedValueOnce([
      {
        timestamp: '2026-10-10T06:00:00.000Z',
        threatScore: 45,
        vectorScores: { auth: 20, traffic: 30, exploit: 10, resource: 45 },
        cpuPercent: 40,
        ramPercent: 45,
      },
      {
        timestamp: '2026-10-10T06:01:00.000Z',
        threatScore: 85,
        // Thiếu vectorScores để kiểm tra fallback từ cpuPercent/ramPercent
        cpuPercent: 85,
        ramPercent: 70,
        failedLogins: 5,
        requestsPerMin: 600,
        malformedRequests: 2,
      },
    ]);

    expect(() => {
      render(<AIOpsPage />);
    }).not.toThrow();

    // Tầng 1: Đảm bảo giao diện tải xong và hiển thị tiêu đề trang & biểu đồ
    await waitFor(() => {
      expect(screen.getByText(/AIOps Sentinel/i)).toBeInTheDocument();
    });

    // Tầng 2: Kiểm tra các thành phần biểu đồ và ngưỡng an toàn render đầy đủ không crash
    expect(screen.getByText(/Trần Max/i)).toBeInTheDocument();
  });

  it('9. [2-Tier Test] Bảng RCA hiển thị chính xác Actor Role, bảo vệ Localhost và không có nút Phong Tỏa IP với đối tượng nội bộ', async () => {
    aiopsApi.getQuarantineList.mockResolvedValue([]);
    aiopsApi.getIncidents.mockResolvedValue({
      data: {
        total: 2,
        page: 1,
        limit: 10,
        totalPages: 1,
        incidents: [
          {
            id: 'inc_mem_1',
            code: 'MEMORY_EXHAUSTION',
            vector: 'resource',
            severity: 'HIGH',
            message: 'RAM vượt ngưỡng 92%',
            status: 'ACTIVE',
            actor: {
              type: 'SYSTEM_INTERNAL',
              identity: 'Hạ tầng máy chủ (Node.js & Database)',
              ipHash: 'system_core',
              username: 'System Core Engine',
              role: 'System',
            },
            current: 95,
            baseline: 50,
            unit: '% RAM',
          },
          {
            id: 'inc_traffic_admin',
            code: 'AUTH_ANOMALY_FLOOD',
            vector: 'auth',
            severity: 'HIGH',
            message: 'Lưu lượng cao từ máy local',
            status: 'ACTIVE',
            actor: {
              type: 'AUTHENTICATED_USER',
              identity: '127.0.0.1',
              ipHash: 'loopback_hash',
              userId: 1,
              username: 'admin_master',
              role: 'Admin',
            },
            current: 414,
            baseline: 57,
            unit: 'req/phút',
          },
        ],
      },
    });

    render(<AIOpsPage />);

    // Tầng 1: UI Rendering — Hiển thị đúng Tên tài khoản, IP, và Huy hiệu bảo vệ
    await waitFor(() => {
      // 1. Dòng 1 sự cố RAM: hiển thị tài khoản "Hệ thống"
      expect(screen.getAllByText('Hệ thống').length).toBeGreaterThanOrEqual(1);

      // 2. Dòng 2 sự cố Admin local: hiển thị TK admin_master
      expect(screen.getByText('admin_master')).toBeInTheDocument();

      // 3. Cả 2 dòng sự cố nội bộ / loopback đều hiển thị nhãn an toàn được bảo vệ
      const protectedBadges = screen.getAllByText(/Nội bộ hệ thống|IP Được bảo vệ/i);
      expect(protectedBadges.length).toBeGreaterThanOrEqual(1);
    });

    // Tầng 2: System Impact & Security Verification
    // Tuyệt đối KHÔNG xuất hiện nút đỏ "Phong Tỏa IP" đối với 2 sự cố này
    expect(screen.queryByRole('button', { name: /Phong Tỏa IP/i })).toBeNull();
  });

  test('10. (2-Tier Test) Dynamic Admin Session IP Protection — Tự nhận diện và bảo vệ IP Admin khi đổi vị trí hoặc mạng', async () => {
    aiopsApi.getQuarantineList.mockResolvedValue([]);
    // Giả lập Admin đăng nhập từ một mạng khác (ví dụ IP công ty hoặc 4G 192.168.1.88)
    aiopsApi.getStatus.mockResolvedValue({
      success: true,
      data: {
        threatScore: 25,
        status: 'NORMAL',
        targetConcurrency: 1000,
        currentClientIp: '192.168.1.88',
        isClientProtected: true,
        vectorScores: { auth: 10, traffic: 15, exploit: 0, resource: 20 },
      },
    });

    aiopsApi.getIncidents.mockResolvedValue({
      success: true,
      data: {
        total: 1,
        page: 1,
        totalPages: 1,
        incidents: [
          {
            id: 'inc-dynamic-remote-admin',
            code: 'ANOMALY_AUTH_BURST',
            vector: 'auth',
            severity: 'MEDIUM',
            message: 'Tải lưu lượng lớn từ máy Admin văn phòng',
            status: 'ACTIVE',
            hits: 1,
            first_detected_at: new Date().toISOString(),
            actor: {
              type: 'IP_SOURCE',
              identity: '192.168.1.88',
              ipHash: 'hash_dynamic_admin',
              userId: 1,
              username: 'office_admin',
              role: 'Admin',
            },
            current: 250,
            baseline: 100,
            unit: 'req/phút',
          },
        ],
      },
    });

    render(<AIOpsPage />);

    // Tầng 1: UI Rendering — Giao diện tự động nhận diện IP máy bạn và hiển thị huy hiệu đặc quyền
    await waitFor(() => {
      // Nhận diện tài khoản
      expect(screen.getByText('office_admin')).toBeInTheDocument();

      // Cột 2 & Cột 7: Hiển thị Máy bạn và IP Máy bạn
      expect(screen.getAllByText(/Máy bạn/i).length).toBeGreaterThanOrEqual(1);
    });

    // Tầng 2: System Impact & Security Verification
    // Nút "Phong Tỏa IP" hoàn toàn bị ẩn để ngăn chặn thảm họa tự khóa IP của chính mình
    expect(screen.queryByRole('button', { name: /Phong Tỏa IP/i })).toBeNull();
  });
});

