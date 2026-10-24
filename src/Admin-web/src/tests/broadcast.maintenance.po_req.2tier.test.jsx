/**
 * 2-Tier Test Suite for Maintenance PO Requirements:
 * 1. Không có checkbox "Nâng cấp hệ thống" (Bảo trì chỉ chia 2 loại: Khẩn cấp và Định kỳ).
 * 2. Cột "Thao tác" ở cuối bảng Lịch Sử: Cho phép hủy phiên bảo trì định kỳ đã lên lịch trước 4 tiếng.
 */
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import BroadcastPage from '../pages/system/BroadcastPage';
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
      data: {
        active: false,
        isEmergency: true,
        reason: '',
        activatedBy: null,
        activatedAt: null,
        scheduled: null,
      },
    }),
    setMaintenanceStatus: vi.fn().mockResolvedValue({
      data: {
        active: true,
        isEmergency: true,
      },
    }),
    cancelScheduledMaintenance: vi.fn().mockResolvedValue({
      data: { cancelled: true, message: 'Đã hủy lịch bảo trì hệ thống' },
    }),
    verifySecurityAction: vi.fn().mockResolvedValue({ data: { verified: true } }),
    getMaintenanceHistory: vi.fn(),
  },
}));

vi.mock('../api/notification.api', () => ({
  default: {
    sendBroadcast: vi.fn().mockResolvedValue({ data: { success: true } }),
    broadcastToAll: vi.fn().mockResolvedValue({ data: { success: true } }),
    getBroadcastHistory: vi.fn().mockResolvedValue({ data: { data: [], pagination: { page: 1, limit: 5, total: 0, totalPages: 1 } } }),
  },
}));

describe('PO Requirements - Maintenance Types & Cancel Scheduled Before 4h (2-Tier)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const renderComponent = () => {
    return render(
      <BrowserRouter>
        <LanguageProvider>
          <BroadcastPage />
        </LanguageProvider>
      </BrowserRouter>
    );
  };

  it('Tier 1: Đảm bảo ĐÃ BỎ checkbox "Nâng cấp hệ thống", chỉ còn bảo trì khẩn cấp và định kỳ', async () => {
    adminApi.getMaintenanceHistory.mockResolvedValueOnce({
      data: { data: [], pagination: { page: 1, limit: 10, total: 0, totalPages: 0 } },
    });

    renderComponent();

    // 1. Tuyệt đối KHÔNG có checkbox hoặc text Nâng cấp hệ thống trong form lên lịch
    expect(screen.queryByLabelText(/Nâng cấp hệ thống/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Nâng cấp hệ thống \(System Upgrade\)/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Tách biệt việc bảo trì thông thường với việc nâng cấp phiên bản mới/i)).not.toBeInTheDocument();

    // 2. Chỉ có checkbox "Bảo trì khẩn cấp"
    const emergencyCheckbox = screen.getByRole('checkbox', { name: /Bảo trì khẩn cấp/i });
    expect(emergencyCheckbox).toBeInTheDocument();
    expect(emergencyCheckbox).not.toBeChecked();

    // 3. Form hiển thị thời điểm bắt đầu/kết thúc dành cho bảo trì định kỳ
    expect(screen.getByLabelText(/Thời điểm bắt đầu/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Thời điểm kết thúc/i)).toBeInTheDocument();
  });

  it('Tier 1 & Tier 2: Bảng lịch sử có cột Thao tác, chỉ cho phép hủy phiên trước 3 tiếng và kích hoạt API hủy thực tế (chỉ tạo đúng 2 lịch bảo trì)', async () => {
    const now = Date.now();
    // Phiên 1: Bắt đầu sau 4 tiếng (hợp lệ để hủy vì >= 3 tiếng)
    const validFutureDate = new Date(now + 4 * 3600 * 1000).toISOString();
    // Phiên 2: Bắt đầu sau 2 tiếng (không hợp lệ vì < 3 tiếng)
    const tooSoonDate = new Date(now + 2 * 3600 * 1000).toISOString();

    adminApi.getMaintenanceHistory.mockResolvedValueOnce({
      data: {
        data: [
          {
            id: 201,
            type: 'SCHEDULED',
            reason: 'Bảo trì máy chủ định kỳ hợp lệ (4h tới)',
            activated_by: 'admin_sys',
            started_at: validFutureDate,
            ended_at: null,
            scheduled_end_at: new Date(now + 5 * 3600 * 1000).toISOString(),
            status: 'SCHEDULED',
          },
          {
            id: 202,
            type: 'SCHEDULED',
            reason: 'Bảo trì máy chủ sắp diễn ra (2h tới)',
            activated_by: 'admin_sys',
            started_at: tooSoonDate,
            ended_at: null,
            scheduled_end_at: new Date(now + 3 * 3600 * 1000).toISOString(),
            status: 'SCHEDULED',
          },
        ],
        pagination: { page: 1, limit: 10, total: 2, totalPages: 1 },
      },
    });

    renderComponent();

    // Tier 1: Kiểm tra cột Thao tác xuất hiện trên thead
    const actionHeader = await screen.findByRole('columnheader', { name: /Thao tác/i });
    expect(actionHeader).toBeInTheDocument();

    // Chờ các dòng dữ liệu render xong (chỉ đúng 2 lịch bảo trì)
    expect(await screen.findByText('Bảo trì máy chủ định kỳ hợp lệ (4h tới)')).toBeInTheDocument();
    expect(await screen.findByText('Bảo trì máy chủ sắp diễn ra (2h tới)')).toBeInTheDocument();

    // Tier 1: Phiên 201 (>= 3 tiếng) phải có nút "Hủy"
    const cancelButtons = screen.getAllByRole('button', { name: /Hủy/i });
    expect(cancelButtons.length).toBe(1);

    // Phiên 202 (< 3 tiếng) phải bị khóa hiển thị "< 3h"
    expect(screen.getByText(/< 3h/i)).toBeInTheDocument();

    // Tier 2: Thao tác click nút Hủy phiên 201 và kiểm tra Tác động hệ thống (System Impact)
    // Giả lập confirm dialog
    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);

    fireEvent.click(cancelButtons[0]);

    // Kỳ vọng adminApi.cancelScheduledMaintenance được gọi với đúng ID = 201
    await waitFor(() => {
      expect(adminApi.cancelScheduledMaintenance).toHaveBeenCalledWith(201);
    });

    confirmSpy.mockRestore();
  });
});
