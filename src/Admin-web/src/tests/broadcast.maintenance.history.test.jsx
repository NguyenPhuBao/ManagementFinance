/**
 * Test: BroadcastPage Emergency Maintenance & History Table (2-Tier: UI Rendering & System Impact)
 * Kiểm tra:
 * 1. Đã xóa bỏ checkbox thừa, bảo trì tức thì luôn là KHẨN CẤP với nút bấm ĐỎ "Bật Bảo Trì Khẩn Cấp".
 * 2. Render đầy đủ Bảng Lịch Sử Bảo Trì từ CSDL PostgreSQL, hiển thị cột Người kích hoạt, Thời gian, Thời lượng, Trạng thái.
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
        reason: 'Khắc phục sự cố khẩn cấp',
        activatedBy: 'admin_test',
        activatedAt: new Date().toISOString(),
      },
    }),
    cancelScheduledMaintenance: vi.fn().mockResolvedValue({ data: { cancelled: true } }),
    getMaintenanceHistory: vi.fn().mockResolvedValue({
      data: {
        data: [
          {
            id: 101,
            type: 'EMERGENCY',
            reason: 'Nâng cấp máy chủ cơ sở dữ liệu khẩn cấp',
            activated_by: 'super_admin',
            started_at: '2026-10-10T10:00:00.000Z',
            ended_at: '2026-10-10T10:25:00.000Z',
            status: 'COMPLETED',
          },
          {
            id: 102,
            type: 'SCHEDULED',
            reason: 'Bảo trì định kỳ tuần 41',
            activated_by: 'devops_lead',
            started_at: '2026-10-11T01:00:00.000Z',
            ended_at: null,
            status: 'ONGOING',
          },
        ],
        pagination: { page: 1, limit: 10, total: 2, totalPages: 1 },
      },
    }),
  },
}));

vi.mock('../api/notification.api', () => ({
  default: {
    sendBroadcast: vi.fn().mockResolvedValue({ data: { success: true } }),
  },
}));

describe('BroadcastPage - Emergency Maintenance & History Journal Suite', () => {
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

  it('1. KHÔNG còn checkbox thừa và hiển thị NÚT ĐỎ "Bật Bảo Trì Khẩn Cấp"', async () => {
    renderComponent();

    // Xác nhận tiêu đề là Bảo trì khẩn cấp
    expect(await screen.findByText('Kích Hoạt Bảo Trì Khẩn Cấp')).toBeInTheDocument();

    // Tuyệt đối không còn checkbox thừa
    expect(screen.queryByRole('checkbox', { name: /Bảo trì khẩn cấp/i })).not.toBeInTheDocument();

    // Nút kích hoạt phải có màu đỏ và text chuẩn
    const emergencyBtn = screen.getByRole('button', { name: /Bật Bảo Trì Khẩn Cấp/i });
    expect(emergencyBtn).toBeInTheDocument();
    expect(emergencyBtn.className).toContain('bg-red-600');
  });

  it('2. Render đầy đủ Bảng Lịch Sử Bảo Trì với cột Người kích hoạt và dữ liệu từ CSDL', async () => {
    renderComponent();

    // Tiêu đề bảng
    expect(await screen.findByText('Lịch Sử Các Phiên Bảo Trì Hệ Thống')).toBeInTheDocument();

    // Các tiêu đề cột
    expect(screen.getByText('Người kích hoạt')).toBeInTheDocument();
    expect(screen.getByText('Loại bảo trì')).toBeInTheDocument();
    expect(screen.getByText('Thời lượng')).toBeInTheDocument();
    expect(screen.getByText('Trạng thái')).toBeInTheDocument();

    // Dữ liệu dòng 1 (Khẩn cấp, hoàn thành)
    expect(screen.getByText('super_admin')).toBeInTheDocument();
    expect(screen.getByText('Nâng cấp máy chủ cơ sở dữ liệu khẩn cấp')).toBeInTheDocument();
    expect(screen.getAllByText('Đã hoàn thành').length).toBeGreaterThanOrEqual(1);

    // Dữ liệu dòng 2 (Theo lịch, đang diễn ra)
    expect(screen.getByText('devops_lead')).toBeInTheDocument();
    expect(screen.getByText('Bảo trì định kỳ tuần 41')).toBeInTheDocument();
    expect(screen.getAllByText('Đang diễn ra').length).toBeGreaterThanOrEqual(1);
  });

  it('3. Khi bấm Bật Bảo Trì Khẩn Cấp, gửi payload với isEmergency = true lên server', async () => {
    renderComponent();

    const inputReason = screen.getByPlaceholderText(/Nâng cấp cụm máy chủ và tối ưu hóa hệ thống khẩn cấp/i);
    fireEvent.change(inputReason, { target: { value: 'Sự cố nghẽn mạng khẩn cấp' } });

    const emergencyBtn = screen.getByRole('button', { name: /Bật Bảo Trì Khẩn Cấp/i });
    fireEvent.click(emergencyBtn);

    await waitFor(() => {
      expect(adminApi.setMaintenanceStatus).toHaveBeenCalledWith({
        active: true,
        reason: 'Sự cố nghẽn mạng khẩn cấp',
        isEmergency: true,
      });
    });
  });
});
