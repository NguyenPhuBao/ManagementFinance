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

describe('AIOps Trend Chart & RCA Table 2-Tier Test Suite', () => {
  const mockStatus = {
    threatScore: 20,
    status: 'NORMAL',
    targetConcurrency: 1000,
    windowSeconds: 10,
    currentClientIp: '127.0.0.1',
    vectorScores: {
      auth: 5,
      traffic: 10,
      exploit: 0,
      resource: 15,
    },
    vectorDefenses: {},
    sample: {
      cpuPercent: 30,
      cpuCores: 8,
      ramPercent: 60,
      ramUsedMb: 4800,
      ramTotalMb: 8000,
      eventLoopLagMs: 5,
      requestsPerMin: 120,
      failedLogins: 0,
      tokenReuseAttacks: 0,
      malformedRequests: 0,
      distinctIpsCount: 10,
    },
    anomalies: [],
    recommendedAction: null,
  };

  const mockHistoryData = [
    {
      timestamp: '2026-10-12T20:00:00.000Z',
      threatScore: 10,
      vectors: { auth: 2, traffic: 5, exploit: 0, resource: 12 },
    },
    {
      timestamp: '2026-10-12T20:05:00.000Z',
      threatScore: 18,
      vectors: { auth: 4, traffic: 8, exploit: 0, resource: 15 },
    },
  ];

  const mockIncidentsResponse = {
    incidents: [
      {
        id: 101,
        code: 'MEMORY_EXHAUSTION',
        vector: 'resource',
        severity: 'HIGH',
        first_detected_at: '2026-10-12T20:00:00.000Z',
        last_seen_at: '2026-10-12T20:10:00.000Z',
        status: 'ACTIVE',
        hits: 2,
        metric_current: 92,
        metric_baseline: 50,
        metric_unit: '% RAM',
        message: 'Bộ nhớ RAM tiêu thụ đã chạm 92% — Nguy cơ rò rỉ bộ nhớ (Memory Leak) hoặc sập tiến trình (OOM).',
        root_cause_diagnosis: 'Bộ nhớ RAM đã vượt ngưỡng nguy hiểm (92% > 92%).',
        mitigation_taken: 'Cảnh báo tài nguyên hệ thống phát ra tới Quản trị viên để chuẩn bị mở rộng hạ tầng.',
        actor: {
          identity: '127.0.0.1',
          type: 'SYSTEM_INTERNAL',
          username: null,
        },
      },
      {
        id: 102,
        code: 'BRUTE_FORCE_AUTH',
        vector: 'auth',
        severity: 'HIGH',
        first_detected_at: '2026-10-12T20:05:00.000Z',
        last_seen_at: '2026-10-12T20:05:00.000Z',
        status: 'ACTIVE',
        hits: 1,
        metric_current: 45,
        metric_baseline: 5,
        metric_unit: 'req/phút',
        message: 'Phát hiện chuỗi đăng nhập thất bại vượt ngưỡng bảo mật.',
        root_cause_diagnosis: 'Tấn công dò quét từ điển mật khẩu.',
        mitigation_taken: 'Kích hoạt khóa tạm thời IP 15 phút.',
        actor: {
          identity: '203.113.15.22',
          ipHash: 'hash_attacker_203',
          type: 'IP_SOURCE',
          username: 'victim_account',
        },
      },
    ],
    total: 2,
    page: 1,
    pageSize: 10,
    totalPages: 1,
  };

  beforeEach(() => {
    vi.clearAllMocks();
    aiopsApi.getStatus.mockResolvedValue(mockStatus);
    aiopsApi.getHistory.mockResolvedValue(mockHistoryData);
    aiopsApi.getQuarantineList.mockResolvedValue([]);
    aiopsApi.getIncidents.mockResolvedValue(mockIncidentsResponse);
    aiopsApi.getVectorConfig.mockResolvedValue({});
    adminApi.getMaintenanceStatus.mockResolvedValue({
      active: false,
      isEmergency: false,
      reason: '',
    });
  });

  // =========================================================================
  // 🧱 TẦNG 1: KIỂM THỬ GIAO DIỆN & HIỂN THỊ (UI RENDERING & CONTROLS)
  // =========================================================================
  describe('Tier 1: UI Rendering & Structure Verifications', () => {
    it('1.1 & 1.2: should render clean chart title without old descriptions and header stretched', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        expect(aiopsApi.getStatus).toHaveBeenCalled();
      });

      // 1.1: Tiêu đề duy nhất "Biểu Đồ Xu Hướng 4 Vectơ Rủi Ro"
      expect(screen.getByText('Biểu Đồ Xu Hướng 4 Vectơ Rủi Ro')).toBeInTheDocument();

      // Bỏ text cũ
      expect(screen.queryByText(/Tách biệt đường cong riêng cho từng vectơ/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Độc Lập Thời Gian Thực/i)).not.toBeInTheDocument();
    });

    it('1.3: should render 5 updated time presets and exclude Year preset', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        expect(aiopsApi.getStatus).toHaveBeenCalled();
      });

      // 5 Presets mới
      expect(screen.getByRole('button', { name: /^10 phút qua$/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /1 giờ qua/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /24 giờ qua/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /7 ngày qua/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /1 tháng qua/i })).toBeInTheDocument();

      // Không còn preset Năm
      expect(screen.queryByRole('button', { name: /Năm \(12 tháng qua\)/i })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: /12 tháng qua/i })).not.toBeInTheDocument();
    });

    it('1.4: should render Time Filter with datetime inputs and search button', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        expect(aiopsApi.getStatus).toHaveBeenCalled();
      });

      // 1.4: Tên "Bộ lọc thời gian:"
      expect(screen.getByText(/Bộ lọc thời gian:/i)).toBeInTheDocument();
      expect(screen.queryByText(/Bộ lọc chính xác:/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Ngày - tháng - năm/i)).not.toBeInTheDocument();

      // Nút Lọc với text "Lọc" và icon kính lúp search
      const filterBtn = screen.getByTestId('apply-custom-range-btn');
      expect(filterBtn).toBeInTheDocument();
      expect(filterBtn).toHaveTextContent('Lọc');
      expect(filterBtn).toHaveTextContent('search');
    });

    it('1.5 & 1.7: should omit threshold texts from legend and omit footer text', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        expect(aiopsApi.getStatus).toHaveBeenCalled();
      });

      // 1.5: Không còn text Ngưỡng Khẩn cấp (85) trong legend
      expect(screen.queryByText(/Ngưỡng Khẩn cấp \(85\)/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Ngưỡng Cảnh báo \(70\)/i)).not.toBeInTheDocument();

      // 1.7: Không còn footer Trục X: Ngày... hay Nguyên tắc: Phòng vệ được kích hoạt độc lập
      expect(screen.queryByText(/Trục X: Ngày/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Phòng vệ được kích hoạt độc lập theo từng vectơ/i)).not.toBeInTheDocument();
    });

    it('2.1, 2.2, 2.3 & 2.5: should render RCA section title, incident count, and omit Clean DB button', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        expect(aiopsApi.getIncidents).toHaveBeenCalled();
      });

      // 2.1: Tiêu đề "Tổng quan nguyên nhân bất thường"
      expect(screen.getByText('Tổng quan nguyên nhân bất thường')).toBeInTheDocument();
      expect(screen.queryByText(/Bóc Tách & Phân Tích Nguyên Nhân Bất Thường \(Root Cause Analysis - RCA\)/i)).not.toBeInTheDocument();

      // 2.2: Bỏ mô tả lưu trữ PostgreSQL tuân thủ luật an ninh mạng
      expect(screen.queryByText(/Nhật ký sự cố lưu trữ bền vững trong CSDL \(PostgreSQL\)/i)).not.toBeInTheDocument();

      // 2.3: Box hiển thị "2 sự cố"
      const incidentBadges = screen.getAllByText(/2 sự cố/i);
      expect(incidentBadges.length).toBeGreaterThanOrEqual(1);
      expect(screen.queryByText(/2 sự cố ghi nhận trong CSDL/i)).not.toBeInTheDocument();

      // 2.5: Tuyệt đối không có nút "Làm sạch CSDL"
      expect(screen.queryByRole('button', { name: /Làm sạch CSDL/i })).not.toBeInTheDocument();
    });

    it('2.6 - 2.12: should render RCA table with exactly 7 columns and expected cells', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        expect(screen.getByText('Tổng quan nguyên nhân bất thường')).toBeInTheDocument();
      });

      // 7 Cột bảng RCA
      expect(screen.getByRole('columnheader', { name: /Tình trạng/i })).toBeInTheDocument();
      expect(screen.getByRole('columnheader', { name: /Đối tượng/i })).toBeInTheDocument();
      expect(screen.getByRole('columnheader', { name: /Vector/i })).toBeInTheDocument();
      expect(screen.getByRole('columnheader', { name: /Chỉ số/i })).toBeInTheDocument();
      expect(screen.getByRole('columnheader', { name: /Nguyên nhân/i })).toBeInTheDocument();
      expect(screen.getByRole('columnheader', { name: /Xử lý/i })).toBeInTheDocument();
      expect(screen.getByRole('columnheader', { name: /Phòng vệ/i })).toBeInTheDocument();

      // Cột Đối tượng: hiển thị TK phía trên và IP phía dưới (IP bắt buộc che mờ chuẩn PO)
      expect(screen.getByText(/Hệ thống nội bộ/i)).toBeInTheDocument();
      expect(screen.getByText(/victim_account/i)).toBeInTheDocument();
      expect(screen.getByText(/203\.113\.xxx\.xxx/i)).toBeInTheDocument();

      // Cột Vector: chỉ có badge resource / auth, không có code MEMORY_EXHAUSTION hay badge HIGH
      expect(screen.queryByText('MEMORY_EXHAUSTION')).not.toBeInTheDocument();
      expect(screen.queryByText('BRUTE_FORCE_AUTH')).not.toBeInTheDocument();

      // Cột Nguyên nhân: chỉ có message chính, không có box psychology
      expect(screen.getByText(/Bộ nhớ RAM tiêu thụ đã chạm 92%/i)).toBeInTheDocument();
      expect(screen.queryByText('psychology')).not.toBeInTheDocument();

      // Cột Xử lý: hiển thị mitigation
      expect(screen.getByText(/Cảnh báo tài nguyên hệ thống phát ra tới Quản trị viên/i)).toBeInTheDocument();
      expect(screen.getByText(/Kích hoạt khóa tạm thời IP 15 phút/i)).toBeInTheDocument();

      // Cột Phòng vệ:
      // - Với nội bộ / protected actor: hiển thị chữ thuần, không phải nút bấm, không box button
      const internalLabels = screen.getAllByText(/Nội bộ hệ thống/i);
      expect(internalLabels.length).toBeGreaterThanOrEqual(1);
      expect(screen.queryByText(/An toàn tuyệt đối/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Sentinel giám sát/i)).not.toBeInTheDocument();

      // - Với attacker: có nút "Phong Tỏa IP"
      expect(screen.getByRole('button', { name: /Phong Tỏa IP/i })).toBeInTheDocument();
    });

    it('2.13: Empty state RCA: khi không có sự cố, chỉ hiển thị "Không tìm thấy sự cố", không có nút xóa bộ lọc hay icon lớn', async () => {
      aiopsApi.getIncidents.mockResolvedValue({
        incidents: [],
        total: 0,
        page: 1,
        pageSize: 10,
        totalPages: 1,
      });

      render(<AIOpsPage />);

      await waitFor(() => {
        expect(screen.getByText('Tổng quan nguyên nhân bất thường')).toBeInTheDocument();
      });

      // Hiển thị text chuẩn gọn gàng
      expect(screen.getByText('Không tìm thấy sự cố')).toBeInTheDocument();

      // Không còn icon verified to lớn hay nút xóa bộ lọc hay text rườm rà
      expect(screen.queryByText(/Xóa bộ lọc để xem toàn bộ sự cố trong CSDL/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Tất cả 12 thông số hệ thống đang hoạt động ổn định/i)).not.toBeInTheDocument();
    });
  });

  // =========================================================================
  // ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG & ĐỒNG BỘ (SYSTEM IMPACT & BEHAVIOR)
  // =========================================================================
  describe('Tier 2: Real System Impact & Dynamic Filter Synchronization', () => {
    it('should query getHistory and getIncidents with matching range preset when user clicks presets', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '10m' });
        expect(aiopsApi.getIncidents).toHaveBeenCalledWith(expect.objectContaining({ range: '10m' }));
      });

      // Click "1 giờ qua"
      const btn1h = screen.getByRole('button', { name: /1 giờ qua/i });
      fireEvent.click(btn1h);

      await waitFor(() => {
        // Tác động hệ thống: gọi API getHistory và getIncidents với range '1h'
        expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '1h' });
        expect(aiopsApi.getIncidents).toHaveBeenCalledWith(expect.objectContaining({ range: '1h' }));
      });

      // Click "24 giờ qua"
      const btn24h = screen.getByRole('button', { name: /24 giờ qua/i });
      fireEvent.click(btn24h);

      await waitFor(() => {
        expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '24h' });
        expect(aiopsApi.getIncidents).toHaveBeenCalledWith(expect.objectContaining({ range: '24h' }));
      });

      // Click "7 ngày qua"
      const btn7d = screen.getByRole('button', { name: /7 ngày qua/i });
      fireEvent.click(btn7d);

      await waitFor(() => {
        expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '7d' });
        expect(aiopsApi.getIncidents).toHaveBeenCalledWith(expect.objectContaining({ range: '7d' }));
      });

      // Click "1 tháng qua"
      const btn30d = screen.getByRole('button', { name: /1 tháng qua/i });
      fireEvent.click(btn30d);

      await waitFor(() => {
        expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '30d' });
        expect(aiopsApi.getIncidents).toHaveBeenCalledWith(expect.objectContaining({ range: '30d' }));
      });
    });

    it('should prioritize custom time filter and pass exact from/to to both Chart and RCA APIs', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        expect(aiopsApi.getHistory).toHaveBeenCalled();
      });

      // Tìm inputs datetime-local
      const inputs = document.querySelectorAll('input[type="datetime-local"]');
      expect(inputs.length).toBe(2);

      const fromInput = inputs[0];
      const toInput = inputs[1];

      fireEvent.change(fromInput, { target: { value: '2026-10-12T10:00' } });
      fireEvent.change(toInput, { target: { value: '2026-10-12T18:00' } });

      // Click nút Lọc
      const filterBtn = screen.getByTestId('apply-custom-range-btn');
      fireEvent.click(filterBtn);

      await waitFor(() => {
        // Tác động hệ thống: gọi API getHistory và getIncidents với chính xác from và to
        expect(aiopsApi.getHistory).toHaveBeenCalledWith(expect.objectContaining({
          from: '2026-10-12T10:00',
          to: '2026-10-12T18:00',
        }));
        expect(aiopsApi.getIncidents).toHaveBeenCalledWith(expect.objectContaining({
          from: '2026-10-12T10:00',
          to: '2026-10-12T18:00',
        }));
      });

      // Thông báo ưu tiên bộ lọc thời gian xuất hiện
      expect(screen.getByText(/ĐANG ƯU TIÊN BỘ LỌC THỜI GIAN/i)).toBeInTheDocument();
    });

    it('should clear custom time filter and restore preset synchronization', async () => {
      render(<AIOpsPage />);

      await waitFor(() => {
        expect(aiopsApi.getHistory).toHaveBeenCalled();
      });

      const inputs = document.querySelectorAll('input[type="datetime-local"]');
      fireEvent.change(inputs[0], { target: { value: '2026-10-12T10:00' } });
      fireEvent.change(inputs[1], { target: { value: '2026-10-12T18:00' } });

      const filterBtn = screen.getByTestId('apply-custom-range-btn');
      fireEvent.click(filterBtn);

      await waitFor(() => {
        expect(screen.getByText(/ĐANG ƯU TIÊN BỘ LỌC THỜI GIAN/i)).toBeInTheDocument();
      });

      // Click "Dùng lại bộ chọn" hoặc "Bỏ bộ lọc thời gian"
      const restoreBtn = screen.getByRole('button', { name: /Dùng lại bộ chọn/i });
      fireEvent.click(restoreBtn);

      await waitFor(() => {
        // Trở về preset 10m mặc định
        expect(aiopsApi.getHistory).toHaveBeenCalledWith({ range: '10m' });
        expect(aiopsApi.getIncidents).toHaveBeenCalledWith(expect.objectContaining({ range: '10m' }));
      });

      expect(screen.queryByText(/ĐANG ƯU TIÊN BỘ LỌC THỜI GIAN/i)).not.toBeInTheDocument();
    });
  });
});
