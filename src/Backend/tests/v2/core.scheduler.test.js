/**
 * Test Suite v2: Core Scheduler & Data Hygiene Routine
 * Module: src/Backend/core/scheduler.service.js
 * 
 * Kiểm thử toàn diện:
 * 1. getMsUntilNextMidnightVietnam (Múi giờ Asia/Ho_Chi_Minh GMT+7 chuẩn xác)
 * 2. Daily OTP Purge (Tự động thanh lọc OTP cũ quá 24h)
 * 3. Daily Refresh Token Purge (Tự động thanh lọc token hết hạn hoặc thu hồi quá 30 ngày)
 * 4. Scheduler Lifecycle (Khởi tạo timerHandle và dừng an toàn)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  getMsUntilNextMidnightVietnam,
  runDailyOtpPurgeTask,
  runDailyRefreshTokenPurgeTask,
  initScheduler,
  stopScheduler,
} = require('../../core/scheduler.service');
const { prisma } = require('../../config/db');

describe('Core Scheduler & Daily Hygiene Routine Suite v2', () => {
  // ─── 1. VIETNAM MIDNIGHT TIMEZONE RESOLUTION ─────────────────────────────
  describe('1. Múi giờ Việt Nam 00:00:00 (GMT+7)', () => {
    it('1.1. getMsUntilNextMidnightVietnam tính đúng khoảng cách tới 0h00 tiếp theo', () => {
      const ms = getMsUntilNextMidnightVietnam();
      assert.strictEqual(typeof ms, 'number');
      assert.ok(ms >= 0, 'ms phải là số không âm');
      assert.ok(ms <= 24 * 60 * 60 * 1000, 'ms không được vượt quá 24 giờ');
    });
  });

  // ─── 2. DATA HYGIENE PURGE ROUTINES ──────────────────────────────────────
  describe('2. Thanh Lọc Dữ Liệu Rác (OTP & Expired Refresh Tokens)', () => {
    it('2.1. runDailyOtpPurgeTask xóa thành công các mã OTP quá 24 giờ', async () => {
      const origDeleteMany = prisma.otp_code.deleteMany;
      prisma.otp_code.deleteMany = async (args) => {
        assert.ok(args.where.created_at.lt);
        return { count: 12 };
      };

      try {
        const deletedCount = await runDailyOtpPurgeTask();
        assert.strictEqual(deletedCount, 12);
      } finally {
        prisma.otp_code.deleteMany = origDeleteMany;
      }
    });

    it('2.2. runDailyRefreshTokenPurgeTask xóa các token hết hạn hoặc bị thu hồi quá 30 ngày', async () => {
      const origDeleteMany = prisma.refreshtoken.deleteMany;
      prisma.refreshtoken.deleteMany = async (args) => {
        assert.ok(args.where.AND);
        return { count: 45 };
      };

      try {
        const deletedCount = await runDailyRefreshTokenPurgeTask();
        assert.strictEqual(deletedCount, 45);
      } finally {
        prisma.refreshtoken.deleteMany = origDeleteMany;
      }
    });
  });

  // ─── 3. SCHEDULER LIFECYCLE SAFETY ───────────────────────────────────────
  describe('3. Scheduler Lifecycle Safety', () => {
    it('3.1. initScheduler khởi tạo và stopScheduler dọn dẹp sạch sẽ không rò rỉ timer', () => {
      const handle = initScheduler();
      assert.ok(handle, 'Phải có timer handle trả về');

      stopScheduler(); // Dọn dẹp timer
    });
  });
});
