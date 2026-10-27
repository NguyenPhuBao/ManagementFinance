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

describe('AIOps 16 Fixes & Quarantine Matrix 2-Tier Test Suite', () => {
  const mockStatus = {
    threatScore: 15,
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
    sample: {
      cpuPercent: 25,
      cpuCores: 8,
      ramPercent: 65,
      ramUsedMb: 5200,
      ramTotalMb: 8000,
      eventLoopLagMs: 8,
      requestsPerMin: 150,
      failedLogins: 0,
      tokenReuseAttacks: 0,
      malformedRequests: 0,
      distinctIpsCount: 12,
    },
    anomalies: [],
    recommendedAction: null,
  };

  const mockQuarantineMatrix = [
    {
      hash: 'pair_1',
      ipHash: 'ip_hash_aaa',
      maskedIp: '113.161.xx.xx',
      ipStatus: 'temp',
      username: 'user_alpha',
      idaccount: 'acc_001',
      accountStatus: 'temp',
      reason: 'Brute-force login attack',
      bannedAt: new Date().toISOString(),
      remainingMinutes: 28,
    },
    {
      hash: 'pair_2',
      ipHash: 'ip_hash_aaa',
      maskedIp: '113.161.xx.xx',
      ipStatus: 'temp',
      username: 'user_beta',
      idaccount: 'acc_002',
      accountStatus: 'temp',
      reason: 'Brute-force login attack on same IP',
      bannedAt: new Date().toISOString(),
      remainingMinutes: 28,
    },
    {
      hash: 'pair_3',
      ipHash: 'ip_hash_bbb',
      maskedIp: '42.112.xx.xx',
      ipStatus: 'temp',
      username: 'user_alpha',
      idaccount: 'acc_001',
      accountStatus: 'temp',
      reason: 'Token reuse across multiple IPs',
      bannedAt: new Date().toISOString(),
      remainingMinutes: 25,
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
    window.confirm = vi.fn(() => true);
    aiopsApi.getStatus.mockResolvedValue({ data: mockStatus });
    aiopsApi.getHistory.mockResolvedValue({ data: [] });
    aiopsApi.getQuarantineList.mockResolvedValue({ data: mockQuarantineMatrix });
    aiopsApi.getVectorConfig.mockResolvedValue({ data: { auth: true, traffic: true, exploit: true, resource: true } });
    aiopsApi.getIncidents.mockResolvedValue({ data: [] });
    adminApi.getMaintenanceStatus.mockResolvedValue({ data: { active: false } });
  });

  // ==========================================
  // TẦNG 1: KIỂM THỬ HIỂN THỊ & GIAO DIỆN MỚI
  // ==========================================
  describe('🧱 TẦNG 1: UI Rendering & Clean Layout Verification (15 Fixes)', () => {
    it('1. Đã bỏ dòng subtitle tại Header AIOps', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText(/AIOps Sentinel — Giám Sát.*Phòng Vệ Tự Động/i)).toBeInTheDocument();
      });
      expect(screen.queryByText(/Học baseline trực tuyến, tự động phát hiện xâm nhập & chặn đứng nguồn request bất thường từ Client-app/i)).not.toBeInTheDocument();
    });

    it('2 & 3 & 5. Đã bỏ subtitle Scaler, nhãn "Mẫu chọn nhanh:", và dòng (Target Concurrency Scaler)', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText('Quy Mô Người Dùng Mục Tiêu & Mô Hình Chịu Tải')).toBeInTheDocument();
      });
      // Không còn (Target Concurrency Scaler)
      expect(screen.queryByText(/\(Target Concurrency Scaler\)/i)).not.toBeInTheDocument();
      // Không còn subtitle Scaler
      expect(screen.queryByText(/Admin cập nhật số lượng người dùng đồng thời kỳ vọng/i)).not.toBeInTheDocument();
      // Không còn nhãn "Mẫu chọn nhanh:"
      expect(screen.queryByText(/Mẫu chọn nhanh:/i)).not.toBeInTheDocument();
    });

    it('4. Đã bỏ dòng "Quy mô đang áp dụng: 100 CCU" tại card Số người dùng đồng thời', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByPlaceholderText(/VD: 1000, 2000/i)).toBeInTheDocument();
      });
      // Thẻ input không còn dòng con "Quy mô đang áp dụng: ..."
      expect(screen.queryByText(/Quy mô đang áp dụng:\s*100\s*CCU/i)).not.toBeInTheDocument();
    });

    it('6. Các mẫu chọn nhanh: 500 Người, 1.000 Người, 5.000 Người, 10.000 Người (không có dấu ngoặc)', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByRole('button', { name: '500 Người' })).toBeInTheDocument();
        expect(screen.getByRole('button', { name: '1.000 Người' })).toBeInTheDocument();
        expect(screen.getByRole('button', { name: '5.000 Người' })).toBeInTheDocument();
        expect(screen.getByRole('button', { name: '10.000 Người' })).toBeInTheDocument();
      });
      // Không còn (Chuẩn), (Cao điểm), (Lớn)
      expect(screen.queryByText(/1,000 Người \(Chuẩn\)/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/2,000 Người \(Cao điểm\)/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/5,000 Người \(Lớn\)/i)).not.toBeInTheDocument();
    });

    it('7 & 8. [PO Updated] Đã loại bỏ hoàn toàn Box Threat Score và chú thích thang điểm để tập trung vào 4 Vector', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText('Tín Hiệu Xâm Nhập & Tấn Công')).toBeInTheDocument();
      });
      // Xác nhận không còn Box Threat Score và các chú thích thang điểm
      expect(screen.queryByText('Hệ Số Đe Dọa (Threat Score)')).not.toBeInTheDocument();
      expect(screen.queryByText('0-59: An toàn')).not.toBeInTheDocument();
      expect(screen.queryByText('60-79: Tăng cao')).not.toBeInTheDocument();
      expect(screen.queryByText('80-89: Cảnh báo')).not.toBeInTheDocument();
      expect(screen.queryByText('90+: Nguy cấp')).not.toBeInTheDocument();
      expect(screen.queryByText(/Công thức tổng hợp:/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/max\(Vectơ\) \+ Bonus kết hợp/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Phòng vệ Sentinel:/i)).not.toBeInTheDocument();
    });

    it('9 & 10. Tín hiệu xâm nhập: "Tần suất: 10 Giây" và bỏ 4 dòng chú thích phụ', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText('Tần suất: 10 Giây')).toBeInTheDocument();
      });
      expect(screen.queryByText(/Cửa sổ 10 giây/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Brute-Force Auth \(Auto-ban ≥ 5\)/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Token Hijacking \(Auto-ban\)/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Injection \(Auto-ban ≥ 3\)/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/IP Entropy \(Zero PII\)/i)).not.toBeInTheDocument();
    });

    it('11 & 12. Sức chịu tải: Bỏ Node.js Engine & CPU/Lag subtext; RAM format dung lượng trên, nguy cơ % dưới', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText(/5,200 \/ 8,000 MB/)).toBeInTheDocument();
        expect(screen.getByText('Nguy cơ Memory Leak: 65%')).toBeInTheDocument();
      });
      expect(screen.queryByText(/Node\.js Engine/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Trễ vòng lặp sự kiện/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Tải đa nhân xử lý/i)).not.toBeInTheDocument();
    });

    it('13 & 14. 4 Vectơ: Bỏ subtitle, bỏ badge 4 sub-scores, bỏ box trạng thái cạnh toggle, bỏ hoàn toàn box log phòng vệ', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText('1. Xác Thực & Danh Tính')).toBeInTheDocument();
        expect(screen.getByText('2. Lưu Lượng & DoS')).toBeInTheDocument();
        expect(screen.getByText('3. Khai Thác Lỗ Hổng')).toBeInTheDocument();
        expect(screen.getByText('4. Sức Khỏe Tài Nguyên')).toBeInTheDocument();
      });
      expect(screen.queryByText(/Tách biệt hoàn toàn cơ chế tính điểm và biện pháp phòng vệ/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/4 Sub-scores độc lập \[0 - 100\]/i)).not.toBeInTheDocument();
      expect(screen.queryByText('Chỉ đo lường')).not.toBeInTheDocument();
      expect(screen.queryByText(/Chỉ cô lập IP Brute-Force/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Kích hoạt Rate-Limit theo trần quy mô/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Cắt kết nối HTTP 403 tức thì với IP mang injection payload/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Load Shedding & cảnh báo máy chủ/i)).not.toBeInTheDocument();
    });

    it('15. Bảng đổi tên thành "Nguồn theo dõi đặc biệt" và bỏ subtitle', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText('Nguồn theo dõi đặc biệt')).toBeInTheDocument();
      });
      expect(screen.queryByText(/Các nguồn IP có hành vi tấn công DoS\/DDoS, Brute-Force, hoặc SQLi/i)).not.toBeInTheDocument();
    });
  });

  // ==========================================
  // TẦNG 2: KIỂM THỬ HOẠT ĐỘNG THỰC TẾ & TÁC ĐỘNG HỆ THỐNG
  // ==========================================
  describe('⚡ TẦNG 2: Quarantine Matrix Behavioral & System Impact Verification (Mục 16)', () => {
    it('16.1. Bảng hiển thị đầy đủ các cặp (IP, Tài khoản) với định dạng Masked IP chuẩn xxx.xxx', async () => {
      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getAllByText('113.161.xxx.xxx').length).toBe(2);
        expect(screen.getAllByText('42.112.xxx.xxx').length).toBe(1);
        expect(screen.getAllByText('user_alpha').length).toBe(2);
        expect(screen.getAllByText('user_beta').length).toBe(1);
      });
    });

    it('16.2. Mở khóa IP: Gọi unblockIp và đồng bộ trạng thái hiển thị nút "Tạm khóa IP" trên TẤT CẢ các dòng có cùng IP', async () => {
      aiopsApi.unblockIp.mockResolvedValueOnce({ success: true, message: 'Đã mở khóa IP thành công' });

      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getAllByRole('button', { name: /Mở khóa IP/i }).length).toBeGreaterThan(0);
      });

      const unblockIpButtons = screen.getAllByRole('button', { name: /Mở khóa IP/i });
      fireEvent.click(unblockIpButtons[0]);

      await waitFor(() => {
        expect(aiopsApi.unblockIp).toHaveBeenCalledWith({ ipHash: 'ip_hash_aaa' });
        // Cả 2 dòng mang ip_hash_aaa phải được đồng bộ sang 'unlocked', hiển thị nút Tạm khóa IP
        expect(screen.getAllByRole('button', { name: /Tạm khóa IP/i }).length).toBeGreaterThanOrEqual(2);
      });
    });

    it('16.3. Khóa IP: Gọi permanentBanIp và chuyển sang tạm khóa 4 giờ, đồng bộ trên TẤT CẢ các dòng có cùng IP', async () => {
      aiopsApi.permanentBanIp.mockResolvedValueOnce({ success: true, message: 'Đã tạm khóa IP trong 4 giờ thành công.' });

      render(<AIOpsPage />);
      await waitFor(() => {
        const banButtons = screen.getAllByRole('button', { name: /Tạm khóa IP \(4h\)/i });
        expect(banButtons.length).toBeGreaterThan(0);
      });

      const banIpButtons = screen.getAllByRole('button', { name: /Tạm khóa IP \(4h\)/i });
      fireEvent.click(banIpButtons[0]);

      await waitFor(() => {
        expect(aiopsApi.permanentBanIp).toHaveBeenCalledWith({ ipHash: 'ip_hash_aaa' });
        expect(screen.getAllByText('4 giờ').length).toBeGreaterThanOrEqual(2);
      });
    });

    it('16.4. Mở khóa Tài khoản: Gọi unblockAccount và đồng bộ trạng thái hiển thị nút "Tạm khóa TK" trên TẤT CẢ các dòng có cùng Tài khoản', async () => {
      aiopsApi.unblockAccount.mockResolvedValueOnce({ success: true, message: 'Đã mở khóa tài khoản thành công' });

      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getAllByRole('button', { name: /Mở khóa TK/i }).length).toBeGreaterThan(0);
      });

      const unblockAccButtons = screen.getAllByRole('button', { name: /Mở khóa TK/i });
      // Click mở khóa tài khoản user_alpha (dòng 0)
      fireEvent.click(unblockAccButtons[0]);

      await waitFor(() => {
        expect(aiopsApi.unblockAccount).toHaveBeenCalledWith({ username: 'user_alpha', idaccount: 'acc_001' });
        // user_alpha xuất hiện ở cả dòng 1 và dòng 3, cả 2 dòng đều phải được đồng bộ sang 'unlocked', hiển thị nút Tạm khóa TK
        expect(screen.getAllByRole('button', { name: /Tạm khóa TK/i }).length).toBeGreaterThanOrEqual(2);
      });
    });

    it('16.5. Khóa Tài khoản vĩnh viễn: Gọi permanentBanAccount và đồng bộ hiển thị "Tài khoản đã bị phong tỏa" trên TẤT CẢ các dòng có cùng Tài khoản', async () => {
      aiopsApi.permanentBanAccount.mockResolvedValueOnce({ success: true, message: 'Đã khóa vĩnh viễn tài khoản thành công' });

      render(<AIOpsPage />);
      await waitFor(() => {
        const banAccs = screen.getAllByRole('button', { name: /Phong tỏa TK/i });
        expect(banAccs.length).toBeGreaterThan(0);
      });

      const banAccButtons = screen.getAllByRole('button', { name: /Phong tỏa TK/i });
      // Click khóa vĩnh viễn tài khoản user_alpha (dòng 0)
      fireEvent.click(banAccButtons[0]);

      await waitFor(() => {
        expect(aiopsApi.permanentBanAccount).toHaveBeenCalledWith({ username: 'user_alpha', idaccount: 'acc_001' });
        expect(screen.getAllByText('Tài khoản đã bị phong tỏa').length).toBeGreaterThanOrEqual(2);
      });
    });

    it('16.6. TK và IP đã bị phong tỏa: Không hiển thị nút nào, chỉ hiển thị text nhãn', async () => {
      const permanentQuarantineData = [
        {
          hash: 'pair_perm_1',
          ipHash: 'ip_hash_perm',
          maskedIp: '192.168.xxx.xxx',
          ipStatus: 'permanent',
          username: 'user_perm',
          idaccount: 'acc_perm',
          accountStatus: 'permanent',
          reason: 'SQL Injection detected',
          bannedAt: new Date().toISOString(),
          remainingMinutes: null,
        },
      ];
      aiopsApi.getQuarantineList.mockResolvedValueOnce({ data: permanentQuarantineData });

      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText('IP đã bị phong tỏa')).toBeInTheDocument();
        expect(screen.getByText('Tài khoản đã bị phong tỏa')).toBeInTheDocument();
      });

      // Tuyệt đối không còn hiển thị nút "Mở khóa IP" hay "Mở khóa TK"
      expect(screen.queryByRole('button', { name: /Mở khóa IP/i })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: /Mở khóa TK/i })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: /Phong tỏa IP/i })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: /Phong tỏa TK/i })).not.toBeInTheDocument();
    });

    it('16.7. Số lượng dòng hiển thị chính xác theo bộ lọc phân trang (5 dòng/trang hiển thị đúng 5 dòng)', async () => {
      // Mock danh sách 10 bản ghi cùng ipHash (mô phỏng đúng môi trường thực tế)
      const tenQuarantineItems = Array.from({ length: 10 }, (_, i) => ({
        id: `pair_item_${i}`,
        hash: 'same_ip_hash',
        ipHash: 'same_ip_hash',
        maskedIp: '192.168.xxx.xxx',
        ipStatus: 'permanent',
        username: `user_${i}`,
        idaccount: `acc_${i}`,
        accountStatus: 'permanent',
        reason: 'SQL Injection detected',
        bannedAt: new Date(Date.now() - i * 60000).toISOString(),
        remainingMinutes: null,
      }));
      aiopsApi.getQuarantineList.mockResolvedValueOnce({ data: tenQuarantineItems });

      render(<AIOpsPage />);
      // Ban đầu mặc định 5 dòng/trang -> hiển thị đúng 5 dòng
      await waitFor(() => {
        const rows = screen.getAllByText('Tài khoản đã bị phong tỏa');
        expect(rows.length).toBe(5);
      });

      // Đổi bộ lọc phân trang sang 10 dòng/trang
      const select = screen.getByRole('combobox');
      fireEvent.change(select, { target: { value: '10' } });

      // Phải render chính xác đúng 10 dòng, không bị xung đột key React
      await waitFor(() => {
        const rows = screen.getAllByText('Tài khoản đã bị phong tỏa');
        expect(rows.length).toBe(10);
      });
    });

    it('16.8. Thời gian còn lại tách riêng IP và TK thành 2 dòng; Mở khóa hoặc Phong tỏa thì hiển thị --', async () => {
      const mixedQuarantineData = [
        {
          id: 'row_1',
          hash: 'hash_1',
          ipHash: 'ip_hash_1',
          maskedIp: '192.168.xxx.xxx',
          ipStatus: 'temporary',
          ipRemainingMinutes: 240,
          username: 'user_active_block',
          idaccount: 'acc_01',
          accountStatus: 'unlocked',
          accountRemainingMinutes: null,
          reason: 'Test IP temp only',
          bannedAt: new Date().toISOString(),
        },
        {
          id: 'row_2',
          hash: 'hash_2',
          ipHash: 'ip_hash_2',
          maskedIp: '192.168.xxx.xxx',
          ipStatus: 'unlocked',
          ipRemainingMinutes: null,
          username: 'user_account_block',
          idaccount: 'acc_02',
          accountStatus: 'temporary',
          accountRemainingMinutes: 120,
          reason: 'Test Account temp only',
          bannedAt: new Date().toISOString(),
        },
        {
          id: 'row_3',
          hash: 'hash_3',
          ipHash: 'ip_hash_3',
          maskedIp: '192.168.xxx.xxx',
          ipStatus: 'permanent',
          ipRemainingMinutes: null,
          username: 'user_both_perm',
          idaccount: 'acc_03',
          accountStatus: 'permanent',
          accountRemainingMinutes: null,
          reason: 'Test both permanent',
          bannedAt: new Date().toISOString(),
        },
      ];

      aiopsApi.getQuarantineList.mockResolvedValueOnce({ data: mixedQuarantineData });

      render(<AIOpsPage />);
      await waitFor(() => {
        // Dòng 1: IP tạm khóa 240 phút (4 giờ), TK đã mở khóa -> hiển thị IP: 4 giờ và TK: --
        expect(screen.getByText('user_active_block')).toBeInTheDocument();
        expect(screen.getByText('4 giờ')).toBeInTheDocument();
      });

      // Dòng 2: IP đã mở khóa -> IP: --, TK tạm khóa 120 phút (2 giờ) -> TK: 2 giờ
      expect(screen.getByText('user_account_block')).toBeInTheDocument();
      expect(screen.getByText('2 giờ')).toBeInTheDocument();

      // Kiểm tra có các nhãn IP: -- và TK: -- cho các đối tượng đã mở hoặc phong tỏa
      const dashes = screen.getAllByText(/^(IP|TK): --$/);
      expect(dashes.length).toBeGreaterThanOrEqual(3);
    });

    it('16.9. Tự động mở khóa khi thời gian đếm ngược hoàn thành (hết hạn đếm ngược -> auto unlocked)', async () => {
      const pastTime = new Date(Date.now() - 10 * 60000).toISOString(); // 10 phút trước
      const expiredQuarantineData = [
        {
          id: 'row_expired',
          hash: 'hash_exp',
          ipHash: 'ip_hash_exp',
          maskedIp: '192.168.xxx.xxx',
          ipStatus: 'temporary',
          ipExpiresAt: pastTime,
          ipRemainingMinutes: 0,
          username: 'user_expired_countdown',
          idaccount: 'acc_exp',
          accountStatus: 'temporary',
          accountExpiresAt: pastTime,
          accountRemainingMinutes: 0,
          reason: 'Đã hoàn thành thời gian tạm khóa',
          bannedAt: new Date(Date.now() - 5 * 3600000).toISOString(),
        },
      ];

      aiopsApi.getQuarantineList.mockResolvedValueOnce({ data: expiredQuarantineData });

      render(<AIOpsPage />);
      await waitFor(() => {
        expect(screen.getByText('user_expired_countdown')).toBeInTheDocument();
      });

      // 1. Cột Thời gian còn lại phải tự động triệt tiêu hiển thị IP: -- và TK: --
      expect(screen.getByText('IP: --')).toBeInTheDocument();
      expect(screen.getByText('TK: --')).toBeInTheDocument();

      // 2. Thao tác IP phải tự động chuyển sang nút "Tạm khóa IP" (vì IP đã được auto mở khóa)
      expect(screen.getByText('Tạm khóa IP')).toBeInTheDocument();

      // 3. Thao tác TK phải tự động chuyển sang nút "Tạm khóa TK" (vì TK đã được auto mở khóa)
      expect(screen.getByText('Tạm khóa TK')).toBeInTheDocument();
    });
  });
});
