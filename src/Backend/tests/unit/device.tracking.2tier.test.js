/**
 * 2-Tier Test Suite: Device History Tracking & Diff Check Engine
 * Tuân thủ Rule 11 (2-Tier Testing Architecture)
 * 
 * Tầng 1: Kiểm thử trích xuất thông tin Client (Header, User-Agent, IP Masking theo NĐ 13/2023/NĐ-CP, Throttle Cache).
 * Tầng 2: Kiểm thử tác động CSDL thực tế:
 *         - Cùng IP & Cùng Thiết bị: UPDATE last_active_at (Không tạo dòng rác).
 *         - Đổi IP hoặc Đổi Thiết bị: INSERT dòng mới, bảo toàn 100% lịch sử cũ (Append-only).
 */

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const {
  extractClientInfo,
  trackDeviceAccess,
  getDeviceHistory,
  clearCache,
} = require('../../modules/auth/device-history.service');
const { prisma } = require('../../config/db');

describe('2-Tier Test Suite: Device & IP Tracking Engine', () => {
  // Mock Database State để kiểm thử biến đổi trạng thái CSDL thực tế (Tầng 2)
  let mockHistoryRows = [];
  let autoIncrementId = 1;

  // Lưu trữ original prisma methods
  const originalFindFirst = prisma.account_device_history.findFirst;
  const originalCreate = prisma.account_device_history.create;
  const originalUpdate = prisma.account_device_history.update;
  const originalFindMany = prisma.account_device_history.findMany;

  beforeEach(() => {
    clearCache();
    mockHistoryRows = [];
    autoIncrementId = 1;

    // Giả lập Prisma client tác động lên bộ nhớ đại diện CSDL
    prisma.account_device_history.findFirst = async ({ where, orderBy }) => {
      let filtered = mockHistoryRows.filter(r => r.idaccount === where.idaccount);
      if (orderBy && orderBy.last_active_at === 'desc') {
        filtered.sort((a, b) => new Date(b.last_active_at) - new Date(a.last_active_at));
      }
      return filtered[0] || null;
    };

    prisma.account_device_history.create = async ({ data }) => {
      const newRecord = {
        id: BigInt(autoIncrementId++),
        idaccount: data.idaccount,
        device_name: data.device_name,
        ip_address: data.ip_address,
        user_agent: data.user_agent || null,
        first_seen_at: data.first_seen_at || new Date(),
        last_active_at: data.last_active_at || new Date(),
      };
      mockHistoryRows.push(newRecord);
      return newRecord;
    };

    prisma.account_device_history.update = async ({ where, data }) => {
      const idx = mockHistoryRows.findIndex(r => String(r.id) === String(where.id));
      if (idx === -1) throw new Error('Record not found');
      mockHistoryRows[idx] = {
        ...mockHistoryRows[idx],
        ...data,
      };
      return mockHistoryRows[idx];
    };

    prisma.account_device_history.findMany = async ({ where, orderBy, take }) => {
      let filtered = mockHistoryRows.filter(r => r.idaccount === where.idaccount);
      if (orderBy && orderBy.last_active_at === 'desc') {
        filtered.sort((a, b) => new Date(b.last_active_at) - new Date(a.last_active_at));
      }
      if (take) filtered = filtered.slice(0, take);
      return filtered;
    };
  });

  // =========================================================================
  // 🧱 TẦNG 1: KIỂM THỬ TRÍCH XUẤT THÔNG TIN VÀ HỢP ĐỒNG GIAO DIỆN (UI/Contract)
  // =========================================================================
  describe('🧱 TẦNG 1: Trích xuất thông tin, Che mờ IP & Throttle Protection', () => {
    it('1.1. Phải trích xuất đúng DeviceName từ header x-device-name và che mờ IP chuẩn Nghị định 13/2023/NĐ-CP', () => {
      const mockReq = {
        headers: {
          'x-device-name': 'Samsung Galaxy S24 Ultra',
          'x-forwarded-for': '113.161.45.12, 10.0.0.1',
          'user-agent': 'Mozilla/5.0 (Android; Mobile)',
        },
      };

      const info = extractClientInfo(mockReq);
      assert.strictEqual(info.deviceName, 'Samsung Galaxy S24 Ultra');
      assert.strictEqual(info.maskedIp, '113.161.xx.xx', 'IP phải được che mờ theo NĐ 13/2023/NĐ-CP');
      assert.strictEqual(info.userAgent, 'Mozilla/5.0 (Android; Mobile)');
    });

    it('1.2. Fallback sang req.ip và Unknown Device khi không có header tùy biến', () => {
      const mockReq = {
        headers: {},
        ip: '14.162.100.5',
      };

      const info = extractClientInfo(mockReq);
      assert.strictEqual(info.deviceName, 'Unknown Device');
      assert.strictEqual(info.maskedIp, '14.162.xx.xx');
    });

    it('1.3. Throttle Cache: Bỏ qua query DB nếu cùng 1 client gửi request liên tiếp trong 60 giây', async () => {
      const idaccount = 101;
      const req = {
        headers: {
          'x-device-name': 'iPhone 15 Pro',
          'x-forwarded-for': '42.112.89.20',
        },
      };

      // Lần 1: Chưa có trong cache -> Thực thi CSDL và lưu vào throttle cache
      const res1 = await trackDeviceAccess(idaccount, req);
      assert.strictEqual(res1.action, 'INSERTED');
      assert.strictEqual(mockHistoryRows.length, 1);

      // Lần 2: Gửi ngay sau đó cùng IP và Device -> Trả về THROTTLED, không chạm DB
      const res2 = await trackDeviceAccess(idaccount, req);
      assert.strictEqual(res2.action, 'THROTTLED');
      assert.strictEqual(res2.skipped, true);
      assert.strictEqual(mockHistoryRows.length, 1, 'Số dòng DB không thay đổi');
    });
  });

  // =========================================================================
  // ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ & BẢO TOÀN DỮ LIỆU CSDL (System Impact)
  // =========================================================================
  describe('⚡ TẦNG 2: Kiểm thử biến đổi trạng thái CSDL thực tế (Diff Check Logic)', () => {
    it('2.1. Đăng nhập lần đầu: Phải INSERT 1 dòng mới vào bảng account_device_history', async () => {
      const idaccount = 200;
      const req = {
        headers: {
          'x-device-name': 'Xiaomi 14 Ultra',
          'x-forwarded-for': '113.161.77.88',
        },
      };

      const result = await trackDeviceAccess(idaccount, req, {}, { skipThrottle: true });
      assert.strictEqual(result.action, 'INSERTED');
      assert.strictEqual(mockHistoryRows.length, 1);
      assert.strictEqual(mockHistoryRows[0].device_name, 'Xiaomi 14 Ultra');
      assert.strictEqual(mockHistoryRows[0].ip_address, '113.161.xx.xx');
      assert.ok(mockHistoryRows[0].first_seen_at);
      assert.ok(mockHistoryRows[0].last_active_at);
    });

    it('2.2. Tiếp tục sử dụng với CÙNG IP và CÙNG Thiết bị: Phải UPDATE last_active_at, KHÔNG tạo dòng mới', async () => {
      const idaccount = 200;
      const req = {
        headers: {
          'x-device-name': 'Xiaomi 14 Ultra',
          'x-forwarded-for': '113.161.77.88',
        },
      };

      // Bước 1: Khởi tạo bản ghi cũ lúc 1 tiếng trước
      const pastTime = new Date(Date.now() - 3600 * 1000);
      mockHistoryRows.push({
        id: BigInt(1),
        idaccount: 200,
        device_name: 'Xiaomi 14 Ultra',
        ip_address: '113.161.xx.xx',
        user_agent: 'App-Client',
        first_seen_at: pastTime,
        last_active_at: pastTime,
      });

      // Bước 2: User truy cập lại app lúc 10:30 với cùng IP và thiết bị
      const result = await trackDeviceAccess(idaccount, req, {}, { skipThrottle: true });

      // Khẳng định nghiệp vụ:
      assert.strictEqual(result.action, 'UPDATED', 'Hành động phải là UPDATE dữ liệu');
      assert.strictEqual(mockHistoryRows.length, 1, 'Tuyệt đối KHÔNG tạo thêm dòng mới khi IP và Device không đổi');
      assert.strictEqual(mockHistoryRows[0].first_seen_at.toISOString(), pastTime.toISOString(), 'first_seen_at phải giữ nguyên');
      assert.ok(new Date(mockHistoryRows[0].last_active_at) > pastTime, 'last_active_at phải được cập nhật thời gian mới');
    });

    it('2.3. Thay đổi IP (chuyển Wi-Fi -> 4G): Phải INSERT dòng mới, BẢO TOÀN dấu vết cũ', async () => {
      const idaccount = 200;

      // Bản ghi cũ: IP Wi-Fi
      mockHistoryRows.push({
        id: BigInt(1),
        idaccount: 200,
        device_name: 'Xiaomi 14 Ultra',
        ip_address: '113.161.xx.xx', // Wi-Fi nhà
        user_agent: 'App-Client',
        first_seen_at: new Date('2026-10-23T08:00:00Z'),
        last_active_at: new Date('2026-10-23T09:00:00Z'),
      });

      // User ra ngoài đường bật 4G Viettel (IP: 171.244.12.34)
      const req4G = {
        headers: {
          'x-device-name': 'Xiaomi 14 Ultra', // Cùng máy
          'x-forwarded-for': '171.244.12.34',  // Khác IP
        },
      };

      const result = await trackDeviceAccess(idaccount, req4G, {}, { skipThrottle: true });

      // Khẳng định nghiệp vụ:
      assert.strictEqual(result.action, 'INSERTED', 'Hành động phải là INSERT dòng mới');
      assert.strictEqual(mockHistoryRows.length, 2, 'CSDL phải có 2 dòng lịch sử (Append-only)');
      assert.strictEqual(mockHistoryRows[0].ip_address, '113.161.xx.xx', 'Dòng cũ vẫn tồn tại nguyên vẹn');
      assert.strictEqual(mockHistoryRows[1].ip_address, '171.244.xx.xx', 'Dòng mới mang IP 4G');
    });

    it('2.4. Đổi Thiết bị (Đăng nhập trên iPad): Phải INSERT dòng mới, BẢO TOÀN dấu vết thiết bị cũ', async () => {
      const idaccount = 200;

      // Bản ghi cũ: Điện thoại
      mockHistoryRows.push({
        id: BigInt(1),
        idaccount: 200,
        device_name: 'Xiaomi 14 Ultra',
        ip_address: '113.161.xx.xx',
        user_agent: 'App-Phone',
        first_seen_at: new Date('2026-10-23T08:00:00Z'),
        last_active_at: new Date('2026-10-23T09:00:00Z'),
      });

      // User mượn iPad vào cùng mạng Wi-Fi
      const reqTablet = {
        headers: {
          'x-device-name': 'iPad Pro M2',  // Khác thiết bị
          'x-forwarded-for': '113.161.77.88', // Cùng subnet Wi-Fi
        },
      };

      const result = await trackDeviceAccess(idaccount, reqTablet, {}, { skipThrottle: true });

      // Khẳng định nghiệp vụ:
      assert.strictEqual(result.action, 'INSERTED');
      assert.strictEqual(mockHistoryRows.length, 2);
      assert.strictEqual(mockHistoryRows[0].device_name, 'Xiaomi 14 Ultra');
      assert.strictEqual(mockHistoryRows[1].device_name, 'iPad Pro M2');
    });

    it('2.5. Truy vấn danh sách lịch sử getDeviceHistory phải trả về đúng thứ tự mới nhất trước', async () => {
      const idaccount = 300;
      mockHistoryRows.push(
        {
          id: BigInt(1),
          idaccount: 300,
          device_name: 'Device A',
          ip_address: '1.1.xx.xx',
          last_active_at: new Date('2026-10-23T07:00:00Z'),
        },
        {
          id: BigInt(2),
          idaccount: 300,
          device_name: 'Device B',
          ip_address: '2.2.xx.xx',
          last_active_at: new Date('2026-10-23T11:00:00Z'),
        }
      );

      const history = await getDeviceHistory(idaccount);
      assert.strictEqual(history.length, 2);
      assert.strictEqual(history[0].device_name, 'Device B', 'Bản ghi 11:00 phải đứng đầu');
      assert.strictEqual(history[1].device_name, 'Device A', 'Bản ghi 07:00 phải đứng sau');
    });
  });
});
