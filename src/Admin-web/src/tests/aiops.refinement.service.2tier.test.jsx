import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import AIOpsPage from '../pages/system/AIOpsPage';
import aiopsApi from '../api/aiops.api';
import adminApi from '../api/admin.api';
import { LanguageProvider } from '../store/language.context';
import { AlertProvider } from '../store/alert.context';

// Mock AIOps API
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

// Mock Admin API
vi.mock('../api/admin.api', () => ({
  default: {
    getMaintenanceStatus: vi.fn(),
    setMaintenanceStatus: vi.fn(),
  },
}));

// Mock Socket.io
vi.mock('../hooks/useSocket', () => ({
  default: vi.fn(() => ({
    connected: true,
    on: vi.fn(),
    off: vi.fn(),
  })),
}));

// Mock Auth Context
vi.mock('../store/auth.context', () => ({
  useAuthContext: () => ({
    user: { username: 'superadmin', role: 'SUPER_ADMIN' },
  }),
}));

describe('AIOps Sentinel Refinement 2-Tier Test Suite (Rule 11)', () => {
  const mockStatus = {
    threatScore: 25,
    status: 'NORMAL',
    targetConcurrency: 1000,
    windowSeconds: 10,
    vectorScores: {
      auth: 10,
      traffic: 15,
      exploit: 5,
      resource: 20,
    },
    vectorDefenses: {},
    vectorConfig: {
      auth: true,
      traffic: true,
      exploit: true,
      resource: true,
    },
    customThresholds: {
      authFailureThreshold: 15,
      trafficSpikeRps: 50,
      exploitLimit: 5,
      resourceCpuPercent: 85,
      resourceMemoryPercent: 85,
      eventLoopLagMs: 100,
    },
    sample: {
      cpuPercent: 25,
      cpuCores: 8,
      ramPercent: 65,
      ramUsedMb: 5200,
      ramTotalMb: 8000,
      eventLoopLagMs: 8,
      requestsPerMin: 150,
      failedLogins: 2,
      tokenReuseAttacks: 0,
      malformedRequests: 0,
      distinctIpsCount: 12,
    },
    anomalies: [],
    recommendedAction: null,
  };

  const mockHistoryData = [
    { timestamp: '2026-10-23T08:00:00Z', authScore: 10, trafficScore: 15, exploitScore: 5, resourceScore: 20 },
    { timestamp: '2026-10-23T08:05:00Z', authScore: 12, trafficScore: 18, exploitScore: 5, resourceScore: 22 },
  ];

  const mockIncidentsData = {
    incidents: [
      {
        id: 'inc-traffic-01',
        first_detected_at: '2026-10-23T08:00:00Z',
        last_seen_at: '2026-10-23T08:05:00Z',
        status: 'ACTIVE',
        hits: 3,
        vector: 'traffic',
        actor_type: 'IP_SOURCE',
        actor_identity: '113.161.12.34',
        metric_current: 250,
        metric_baseline: 50,
        metric_unit: 'RPM',
        message: 'Lưu lượng RPS tăng đột biến',
        mitigation_taken: 'Throttling',
      },
      {
        id: 'inc-auth-02',
        first_detected_at: '2026-10-23T08:01:00Z',
        last_seen_at: '2026-10-23T08:06:00Z',
        status: 'ACTIVE',
        hits: 5,
        vector: 'auth',
        actor_type: 'USER_ACCOUNT',
        actor_identity: '42.112.55.88',
        actor_hash: 'hash_auth_attacker',
        username: 'victim_account',
        user_id: 101,
        metric_current: 18,
        metric_baseline: 5,
        metric_unit: 'lần/phút',
        message: 'Dò mật khẩu Brute Force',
        mitigation_taken: 'Cách ly IP',
      },
    ],
    total: 2,
    page: 1,
    limit: 10,
  };

  const mockQuarantineList = [
    {
      hash: 'quar-01',
      ipHash: 'ip_hash_01',
      maskedIp: '113.161.xx.xx',
      ipStatus: 'temporary',
      username: 'bad_actor',
      idaccount: 'acc-999',
      accountStatus: 'temporary',
      reason: 'Brute-force attack',
      bannedAt: new Date().toISOString(),
      remainingMinutes: 25,
      vector: 'auth',
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
    aiopsApi.getStatus.mockResolvedValue(mockStatus);
    aiopsApi.getHistory.mockResolvedValue(mockHistoryData);
    aiopsApi.getIncidents.mockResolvedValue(mockIncidentsData);
    aiopsApi.getQuarantineList.mockResolvedValue(mockQuarantineList);
    aiopsApi.calibrate.mockResolvedValue({
      success: true,
      baseline: { safeRps: 120 },
      customThresholds: mockStatus.customThresholds,
    });
    aiopsApi.toggleVector.mockResolvedValue({ success: true, enabled: false });
    aiopsApi.getVectorConfig.mockResolvedValue({
      auth: true,
      traffic: true,
      exploit: true,
      resource: true,
    });
    adminApi.getMaintenanceStatus.mockResolvedValue({ maintenance: false });
  });

  const renderComponent = () =>
    render(
      <LanguageProvider>
        <AlertProvider>
          <AIOpsPage />
        </AlertProvider>
      </LanguageProvider>
    );

  // ================================================================
  // 🧱 TẦNG 1: UI RENDERING & CLEAN AESTHETICS VERIFICATION
  // ================================================================
  describe('Tier 1: UI Rendering & Clean Aesthetics Verification', () => {
    it('1.1. Header: Không còn icon "security", không còn chữ "Máy Học", không có nút "Làm mới"', async () => {
      renderComponent();
      await waitFor(() => expect(aiopsApi.getStatus).toHaveBeenCalled());

      // Header title chỉ còn "AIOps Sentinel"
      const mainHeader = screen.getByRole('heading', { level: 1 });
      expect(mainHeader.textContent).toContain('AIOps Sentinel');
      expect(mainHeader.textContent).not.toContain('Máy Học');

      // Không còn icon security trong header
      const headerContainer = mainHeader.closest('div');
      expect(headerContainer.querySelector('span.material-symbols-outlined')).toBeNull();

      // Không còn nút "Làm mới" trong Header
      const headerActions = mainHeader.closest('.flex-col').querySelector('.flex.items-center.gap-2\\.5');
      expect(headerActions ? headerActions.textContent : '').not.toContain('Làm mới');
      expect(screen.queryByTestId('btn-refresh-aiops')).toBeNull();

      // Nút "Tái Hiệu Chuẩn Baseline" vẫn hiển thị đầy đủ
      expect(screen.getByRole('button', { name: /tái hiệu chuẩn baseline/i })).toBeInTheDocument();
    });

    it('1.2. Box Tình Trạng Hệ Thống: Đã bị loại bỏ hoàn toàn khỏi DOM', async () => {
      renderComponent();
      await waitFor(() => expect(aiopsApi.getStatus).toHaveBeenCalled());

      // Xác nhận không còn cụm từ hoặc box "Tình trạng hệ thống"
      expect(screen.queryByText(/tình trạng hệ thống/i)).toBeNull();
      expect(screen.queryByTestId('system-health-box')).toBeNull();
    });

    it('1.3. Box Quy Mô Người Dùng: Bỏ icon "group" và bỏ 3 dòng text công thức thô', async () => {
      renderComponent();
      await waitFor(() => expect(aiopsApi.getStatus).toHaveBeenCalled());

      // Box quy mô người dùng
      expect(screen.getByText(/quy mô người dùng/i)).toBeInTheDocument();

      // Không còn các công thức thô dạng (CCU * RPS), (CCU * 0.1), (0.005%)
      expect(screen.queryByText(/\(CCU\s*\*\s*RPS\)/i)).toBeNull();
      expect(screen.queryByText(/\(CCU\s*\*\s*0\.1\)/i)).toBeNull();
      expect(screen.queryByText(/0\.005%/i)).toBeNull();
    });

    it('1.4. Box 4 Vectơ Rủi Ro: Tiêu đề là "4 Vectơ Rủi Ro", không có icon "hub"', async () => {
      renderComponent();
      await waitFor(() => expect(aiopsApi.getStatus).toHaveBeenCalled());

      const vectorHeading = screen.getByRole('heading', { name: /^4 Vectơ Rủi Ro$/i });
      expect(vectorHeading).toBeInTheDocument();

      // Không có icon hub trong heading
      expect(vectorHeading.querySelector('.material-symbols-outlined')).toBeNull();
    });

    it('1.5. Box Biểu Đồ Xu Hướng: Bỏ icon "show_chart" và icon "schedule", có đủ 5 presets thời gian', async () => {
      renderComponent();
      await waitFor(() => expect(aiopsApi.getStatus).toHaveBeenCalled());

      // Heading biểu đồ không có icon show_chart
      const chartHeading = screen.getByRole('heading', { name: /biểu đồ xu hướng 4 vectơ rủi ro/i });
      expect(chartHeading.querySelector('.material-symbols-outlined')).toBeNull();

      // Tiêu đề bộ chọn thời gian không có icon schedule
      const obsLabel = screen.getByText(/bộ chọn thời gian quan sát:/i);
      expect(obsLabel.parentElement.querySelector('span.material-symbols-outlined')).toBeNull();

      // Kiểm tra 5 nút presets
      expect(screen.getByTestId('preset-10m')).toBeInTheDocument();
      expect(screen.getByTestId('preset-1h')).toBeInTheDocument();
      expect(screen.getByTestId('preset-24h')).toBeInTheDocument();
      expect(screen.getByTestId('preset-7d')).toBeInTheDocument();
      expect(screen.getByTestId('preset-30d')).toBeInTheDocument();
    });

    it('1.6. Box RCA: Bỏ icon "troubleshoot", hiển thị đúng icon chuẩn 4 Vector và phân biệt Cột Đối tượng (Traffic vs Khác)', async () => {
      renderComponent();
      await waitFor(() => expect(aiopsApi.getIncidents).toHaveBeenCalled());

      // Tiêu đề RCA không có icon troubleshoot
      const rcaHeading = screen.getByRole('heading', { name: /tổng quan nguyên nhân bất thường/i });
      expect(rcaHeading.querySelector('.material-symbols-outlined')).toBeNull();

      // Cột Đối tượng của Traffic: dòng 1 là "Hệ thống", dòng 2 là "Lưu lượng mạng"
      expect(screen.getByText('Lưu lượng mạng')).toBeInTheDocument();

      // Cột Đối tượng của Auth: có tiền tố "TK:" và "IP:"
      expect(screen.getAllByText('TK:').length).toBeGreaterThan(0);
      expect(screen.getAllByText('IP:').length).toBeGreaterThan(0);
      expect(screen.getByText('victim_account')).toBeInTheDocument();
    });

    it('1.7. Box Nguồn Theo Dõi Đặc Biệt: Bỏ icon "shield_with_heart", subtitle và count đối tượng', async () => {
      renderComponent();
      await waitFor(() => expect(aiopsApi.getQuarantineList).toHaveBeenCalled());

      // Heading không có icon shield_with_heart
      const quarHeading = screen.getByRole('heading', { name: /nguồn theo dõi đặc biệt/i });
      expect(quarHeading.parentElement.querySelector('span.material-symbols-outlined')).toBeNull();

      // Không còn subtitle
      expect(screen.queryByText(/danh sách ip & tài khoản bị phong tỏa hoặc cách ly giám sát/i)).toBeNull();

      // Không còn text đếm "Hiển thị ... đối tượng"
      expect(screen.queryByText(/hiển thị \d+ \/ \d+ đối tượng/i)).toBeNull();
    });
  });

  // ================================================================
  // ⚡ TẦNG 2: REAL SYSTEM IMPACT & BEHAVIORAL VERIFICATION
  // ================================================================
  describe('Tier 2: Real System Impact & Behavioral Verification', () => {
    it('2.1. System Impact: Modal Tái Hiệu Chuẩn cho phép nhập 6 Custom Thresholds và gửi API chính xác', async () => {
      renderComponent();
      await waitFor(() => expect(aiopsApi.getStatus).toHaveBeenCalled());

      // Mở modal hiệu chuẩn
      const btnOpenCalibrate = screen.getByRole('button', { name: /tái hiệu chuẩn baseline/i });
      fireEvent.click(btnOpenCalibrate);

      // Modal hiển thị với form Custom Thresholds
      expect(screen.getByText(/Tùy Chỉnh Ngưỡng An Toàn Mong Muốn/i)).toBeInTheDocument();

      // Tương tác nhập các thông số tùy chỉnh
      const inputAuth = screen.getByTestId('input-auth-failure-threshold');
      const inputTraffic = screen.getByTestId('input-traffic-spike-rps');
      const inputExploit = screen.getByTestId('input-exploit-limit');
      const inputCpu = screen.getByTestId('input-resource-cpu-percent');
      const inputMem = screen.getByTestId('input-resource-memory-percent');
      const inputLag = screen.getByTestId('input-event-loop-lag-ms');

      fireEvent.change(inputAuth, { target: { value: '25' } });
      fireEvent.change(inputTraffic, { target: { value: '80' } });
      fireEvent.change(inputExploit, { target: { value: '10' } });
      fireEvent.change(inputCpu, { target: { value: '90' } });
      fireEvent.change(inputMem, { target: { value: '88' } });
      fireEvent.change(inputLag, { target: { value: '150' } });

      // Nhấn Xác nhận & Hiệu chuẩn
      const btnConfirm = screen.getByRole('button', { name: /xác nhận/i });
      fireEvent.click(btnConfirm);

      // System Impact Assertion: API calibrate PHẢI được gọi kèm customThresholds chuẩn xác
      await waitFor(() => {
        expect(aiopsApi.calibrate).toHaveBeenCalledTimes(1);
        expect(aiopsApi.calibrate).toHaveBeenCalledWith(
          expect.objectContaining({
            targetConcurrency: 1000,
            customThresholds: expect.objectContaining({
              authFailureThreshold: 25,
              trafficSpikeRps: 80,
              exploitLimit: 10,
              resourceCpuPercent: 90,
              resourceMemoryPercent: 88,
              eventLoopLagMs: 150,
            }),
          })
        );
      });
    });

    it('2.2. System Impact: Chọn preset thời gian kích hoạt getHistory với đúng preset khung giờ', async () => {
      renderComponent();
      await waitFor(() => expect(aiopsApi.getHistory).toHaveBeenCalled());

      // Ban đầu mặc định gọi getHistory
      expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '10m' });

      // Click chọn preset 24 giờ qua
      const preset24hBtn = screen.getByTestId('preset-24h');
      fireEvent.click(preset24hBtn);

      // System Impact Assertion: API getHistory PHẢI được gọi lại với tham số '24h'
      await waitFor(() => {
        expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '24h' });
      });

      // Click chọn preset 7 ngày qua
      const preset7dBtn = screen.getByTestId('preset-7d');
      fireEvent.click(preset7dBtn);

      // System Impact Assertion: API getHistory PHẢI được gọi lại với tham số '7d'
      await waitFor(() => {
        expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '7d' });
      });
    });

    it('2.3. System Impact: Tắt Vector hiển thị đúng "Bỏ qua khỏi Threat Score" (không tiền tố)', async () => {
      // Giả lập getVectorConfig với vector auth đã bị tắt (isEnabled = false)
      aiopsApi.getVectorConfig.mockResolvedValueOnce({
        auth: false,
        traffic: true,
        exploit: true,
        resource: true,
      });

      renderComponent();
      await waitFor(() => expect(aiopsApi.getStatus).toHaveBeenCalled());

      // System Impact Assertion: Giao diện phải hiển thị text "Bỏ qua khỏi Threat Score"
      const measureText = screen.getByText('Bỏ qua khỏi Threat Score');
      expect(measureText).toBeInTheDocument();
      expect(measureText.textContent).not.toContain('Chế độ chỉ đo lường — ');
    });
  });
});
