import React from 'react';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import ServerHealthPanel from '../components/common/ServerHealthPanel';
import adminApi from '../api/admin.api';

vi.mock('../api/admin.api', () => ({
  default: {
    getMaintenanceStatus: vi.fn(),
    getSystemHealth: vi.fn(),
    setMaintenanceStatus: vi.fn(),
  },
}));

vi.mock('../hooks/useSocket', () => ({
  default: () => null,
}));

describe('Task 2: Server Health Environment Quota (Cloud vs Host) 2-Tier Test', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    adminApi.getMaintenanceStatus.mockResolvedValue({
      data: { active: false, reason: '', activatedBy: null, activatedAt: null },
    });
  });

  it('Tier 1 & Tier 2: Khi chạy trên Cloud, hiển thị đúng badge Cloud Container và Quota tài nguyên thực tế', async () => {
    // Giả lập Backend trả về thông số máy chủ Cloud Container với 1 vCPU và 512 MB RAM quota
    adminApi.getSystemHealth.mockResolvedValueOnce({
      data: {
        environment: {
          mode: 'cloud',
          provider: 'Render Cloud',
          isContainer: true,
          source: 'cgroup_v2',
        },
        cpu: { cores: 1, percent: 25 },
        ram: { usedMb: 256, totalMb: 512, freeMb: 256, percent: 50, rssMb: 120 },
        eventLoop: { lagMs: 4, overloaded: false },
        dbPool: { clientActive: 2, clientLimit: 16, adminActive: 1, maxConnections: 20 },
        maintenance: { active: false },
        uptime: {
          uptimeSeconds: 86400,
          uptimeFormatted: '1 ngày',
          startedAt: new Date().toISOString(),
          uptimePercent: 99.98,
          slaWindowDays: 30,
        },
      },
    });

    render(<ServerHealthPanel />);

    // ==========================================
    // 🧱 TẦNG 1: HIỂN THỊ ĐẦY ĐỦ CÁC THÀNH PHẦN
    // ==========================================
    expect(await screen.findByText(/Sức Khỏe Máy Chủ/i)).toBeInTheDocument();

    // ==========================================
    // ⚡ TẦNG 2: TÁC ĐỘNG HỆ THỐNG & ĐÚNG QUOTA
    // ==========================================
    // Phải hiển thị badge nhà cung cấp Cloud
    await waitFor(() => {
      expect(screen.getByText('Render Cloud')).toBeInTheDocument();
      // CPU hiển thị đúng 1 vCPU quota thay vì cores host
      expect(screen.getByText(/\(1 vCPU\)/i)).toBeInTheDocument();
      // RAM hiển thị đúng 512 MB và nhãn Quota
      expect(screen.getAllByText(/512 MB/i).length).toBeGreaterThanOrEqual(1);
      expect(screen.getByText(/Quota/i)).toBeInTheDocument();
    });
  });
});
