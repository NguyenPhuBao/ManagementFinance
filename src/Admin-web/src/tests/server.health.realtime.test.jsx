/**
 * Test: ServerHealthPanel Realtime Hardware Metrics (2-Tier: UI Rendering & System Impact)
 * Đảm bảo chỉ số CPU Cores và RAM Capacity đo thực tế từ host, không gán cứng, không bị tụt về 0/100 MB khi nhận socket stream.
 */
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, act } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import ServerHealthPanel from '../components/common/ServerHealthPanel';
import { LanguageProvider } from '../store/language.context';
import adminApi from '../api/admin.api';

const mockSocket = {
  on: vi.fn(),
  off: vi.fn(),
  emit: vi.fn(),
};

vi.mock('../hooks/useSocket', () => ({
  default: () => mockSocket,
}));

vi.mock('../api/admin.api', () => ({
  default: {
    getMaintenanceStatus: vi.fn().mockResolvedValue({
      data: { active: false, reason: '', activatedBy: null, activatedAt: null },
    }),
    getSystemHealth: vi.fn().mockResolvedValue({
      data: {
        cpu: { percent: 12, cores: 16 },
        ram: { percent: 89, usedMb: 6995, totalMb: 7860, freeMb: 865, rssMb: 120 },
        eventLoop: { lagMs: 4, overloaded: false },
        uptime: { uptimeFormatted: '2d 5h', uptimePercent: 99.95, startedAt: '2026-10-09T00:00:00Z', slaWindowDays: 30 },
        dbPool: {
          clientActive: 1,
          clientLimit: 16,
          adminActive: 0,
          adminReserved: 4,
          maxConnections: 20,
        },
        loadShedding: { shedCount24h: 0 },
      },
    }),
    setMaintenanceStatus: vi.fn().mockResolvedValue({ data: { success: true } }),
  },
}));

describe('ServerHealthPanel - Real Host Hardware & Realtime Stream', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const renderPanel = () => {
    return render(
      <BrowserRouter>
        <LanguageProvider>
          <ServerHealthPanel />
        </LanguageProvider>
      </BrowserRouter>
    );
  };

  it('1. Renders initial host hardware metrics: 16 CPU cores & 7,860 MB RAM', async () => {
    renderPanel();

    // CPU gauge hiển thị % và số core máy thật
    expect(await screen.findByText('(16 cores)')).toBeInTheDocument();

    // RAM gauge hiển thị 6,995/7,860 MB (89%) và dung lượng GB thật
    expect(await screen.findByText('6,995/7,860 MB (89%)')).toBeInTheDocument();
    expect(screen.getByText('(7.7 GB)')).toBeInTheDocument();

    // Tuyệt đối không được xuất hiện 0/100 MB giả lập
    expect(screen.queryByText('0/100 MB (0%)')).not.toBeInTheDocument();
  });

  it('2. Keeps real RAM metrics intact when receiving realtime socket stream (does not drop to 0/100 MB)', async () => {
    renderPanel();
    expect(await screen.findByText('(16 cores)')).toBeInTheDocument();

    const metricsCall = mockSocket.on.mock.calls.find((call) => call[0] === 'admin.metrics_stream');
    const metricsCallback = metricsCall?.[1];
    expect(metricsCallback).toBeDefined();

    // Giả lập socket stream 3s gửi nhịp tim mới từ SystemHardwareMonitor
    await act(async () => {
      metricsCallback({
        cpuPercent: 22,
        cpuCores: 16,
        ramPercent: 87,
        ramUsedMb: 6838,
        ramTotalMb: 7860,
        ramFreeMb: 1022,
        ramRssMb: 125,
        eventLoopLagMs: 6,
        uptimeSeconds: 190800,
        uptimeFormatted: '2d 5h 0m 0s',
      });
    });

    // Sau khi socket stream cập nhật, RAM gauge phải hiển thị giá trị mới chính xác
    expect(await screen.findByText('6,838/7,860 MB (87%)')).toBeInTheDocument();
    expect(screen.getByText('(7.7 GB)')).toBeInTheDocument();
    expect(screen.getByText('(16 cores)')).toBeInTheDocument();

    // Tuyệt đối không bị rớt về 0/100 MB
    expect(screen.queryByText('0/100 MB (0%)')).not.toBeInTheDocument();
  });

  it('3. Preserves total RAM and cores if socket stream omits total values (fallback preservation)', async () => {
    renderPanel();
    expect(await screen.findByText('(16 cores)')).toBeInTheDocument();

    const metricsCall = mockSocket.on.mock.calls.find((call) => call[0] === 'admin.metrics_stream');
    const metricsCallback = metricsCall?.[1];

    // Giả lập payload cũ chỉ gửi percent và rssMb
    await act(async () => {
      metricsCallback({
        cpuPercent: 30,
        ramPercent: 85,
        ramRssMb: 130,
        eventLoopLagMs: 8,
        uptimeSeconds: 191000,
        uptimeFormatted: '2d 5h 3m 20s',
      });
    });

    // Giữ nguyên tổng RAM và số cores từ state trước đó
    expect(screen.getByText('(16 cores)')).toBeInTheDocument();
    expect(screen.getByText('(7.7 GB)')).toBeInTheDocument();
  });
});
