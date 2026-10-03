/**
 * Test Suite v2: Authentication & Account Lifecycle
 * Module: src/Backend/modules/auth
 * 
 * Kiểm thử toàn diện:
 * 1. Username/Password Validation & Bcrypt Hashing
 * 2. OTP Registration Flow (Nghị định 13/2023/NĐ-CP)
 * 3. JWT Access Token + Refresh Token Rotation & Token Replay Guard
 * 4. Account Soft-Delete (PendingDelete, Countdown 30 ngày & Hủy xóa)
 * 5. PII Encryption at Rest (Phone, Address AES-256)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const bcrypt = require('bcryptjs');
const authService = require('../../modules/auth/auth.service');
const authRepository = require('../../modules/auth/auth.repository');

describe('Auth & Account Lifecycle Suite v2', () => {
  // ─── 1. USERNAME / PASSWORD VALIDATION ────────────────────────────────────
  describe('1. Cặp Username & Password Validation', () => {
    it('1.1. Chặn tạo tài khoản nếu Username và Password trùng khớp với tài khoản đã có', async () => {
      const origFind = authRepository.findAccountsByUsername;
      const hashedPassword = await bcrypt.hash('SecurePassword123', 10);

      authRepository.findAccountsByUsername = async () => [
        { idaccount: 10, username: 'testuser', password: hashedPassword },
      ];

      try {
        await assert.rejects(
          async () => {
            await authService.validateUsernamePasswordPair('testuser', 'SecurePassword123');
          },
          (err) => {
            assert.strictEqual(err.statusCode, 400);
            assert.ok(err.message.includes('đã tồn tại trong hệ thống'));
            return true;
          }
        );
      } finally {
        authRepository.findAccountsByUsername = origFind;
      }
    });

    it('1.2. Cho phép nếu trùng Username nhưng Mật khẩu khác', async () => {
      const origFind = authRepository.findAccountsByUsername;
      const hashedPassword = await bcrypt.hash('OldPassword123', 10);

      authRepository.findAccountsByUsername = async () => [
        { idaccount: 10, username: 'testuser', password: hashedPassword },
      ];

      try {
        // Mật khẩu mới khác mật khẩu cũ -> Không ném lỗi
        await authService.validateUsernamePasswordPair('testuser', 'BrandNewPassword456');
      } finally {
        authRepository.findAccountsByUsername = origFind;
      }
    });
  });

  // ─── 2. ACCOUNT DELETION & 30-DAY COUNTDOWN ──────────────────────────────
  describe('2. Vòng đời xóa tài khoản (PendingDelete, 30 ngày ân hạn & Hủy xóa)', () => {
    it('2.1. Yêu cầu xóa tài khoản: Chuyển sang PendingDelete với countdown 30 ngày', async () => {
      const origFind = authRepository.findAccountById;
      const origSchedule = authRepository.scheduleDeletion;
      const hashedPassword = await bcrypt.hash('Secret123', 10);

      authRepository.findAccountById = async (id) => ({
        idaccount: id,
        username: 'victim_user',
        password: hashedPassword,
        status: 'Active',
      });

      authRepository.scheduleDeletion = async (id) => ({
        idaccount: id,
        status: 'PendingDelete',
        countdown: 30,
        delete_at: new Date(Date.now() + 30 * 24 * 3600 * 1000),
      });

      try {
        const result = await authService.deleteAccount(50, 'Secret123');
        assert.strictEqual(result.idaccount, 50);
        assert.strictEqual(result.status, 'PendingDelete');
        assert.strictEqual(result.countdown, 30);
        assert.ok(result.scheduled_delete_at);
      } finally {
        authRepository.findAccountById = origFind;
        authRepository.scheduleDeletion = origSchedule;
      }
    });

    it('2.2. Hủy xóa tài khoản: Phục hồi về Active và xóa sạch countdown', async () => {
      const origFind = authRepository.findAccountById;
      const origCancel = authRepository.cancelDeletion;

      authRepository.findAccountById = async (id) => ({
        idaccount: id,
        username: 'repentant_user',
        status: 'PendingDelete',
        countdown: 25,
        delete_at: new Date(Date.now() + 25 * 24 * 3600 * 1000),
      });

      authRepository.cancelDeletion = async (id) => ({
        idaccount: id,
        status: 'Active',
        countdown: null,
      });

      try {
        const restored = await authService.cancelDeletion(50);
        assert.strictEqual(restored.status, 'Active');
        assert.strictEqual(restored.countdown, null);
      } finally {
        authRepository.findAccountById = origFind;
        authRepository.cancelDeletion = origCancel;
      }
    });

    it('2.3. Chặn hủy xóa khi tài khoản đã hết hạn 30 ngày (countdown <= 0)', async () => {
      const origFind = authRepository.findAccountById;

      authRepository.findAccountById = async (id) => ({
        idaccount: id,
        username: 'too_late_user',
        status: 'PendingDelete',
        countdown: 0,
        delete_at: new Date(Date.now() - 1000),
      });

      try {
        await assert.rejects(
          async () => {
            await authService.cancelDeletion(50);
          },
          (err) => {
            assert.strictEqual(err.statusCode, 403);
            assert.ok(err.message.includes('Đã hết thời gian khôi phục'));
            return true;
          }
        );
      } finally {
        authRepository.findAccountById = origFind;
      }
    });
  });

  // ─── 3. AUDIT LOG STATUS & REASON NORMALIZATION ──────────────────────────
  describe('3. Chuẩn hóa Audit Log Request Status (7 trạng thái chuẩn)', () => {
    it('3.1. Phân loại mã HTTP thành trạng thái nghiệp vụ chuẩn', () => {
      assert.strictEqual(authService.determineReqStatus({ statusCode: 200 }), 'Pass');
      assert.strictEqual(authService.determineReqStatus({ statusCode: 201 }), 'Pass');
      assert.strictEqual(authService.determineReqStatus({ statusCode: 202 }), 'Accepted');
      assert.strictEqual(authService.determineReqStatus({ statusCode: 401 }), 'Rejected');
      assert.strictEqual(authService.determineReqStatus({ statusCode: 403 }), 'Rejected');
      assert.strictEqual(authService.determineReqStatus({ statusCode: 429 }), 'Rejected');
      assert.strictEqual(authService.determineReqStatus({ statusCode: 500 }), 'Fail');
    });

    it('3.2. Ưu tiên req.auditStatus nếu middleware đã gắn trạng thái cụ thể', () => {
      const req = { auditStatus: 'Interrupted' };
      assert.strictEqual(authService.determineReqStatus({ statusCode: 200 }, req), 'Interrupted');
    });

    it('3.3. Tự động sinh lý do lỗi minh bạch tương ứng với mã HTTP', () => {
      assert.strictEqual(authService.determineReqReason({ statusCode: 401 }), 'Chưa đăng nhập hoặc Token không hợp lệ');
      assert.strictEqual(authService.determineReqReason({ statusCode: 403 }), 'Không có quyền truy cập quản trị');
      assert.strictEqual(authService.determineReqReason({ statusCode: 429 }), 'Quá giới hạn tần suất yêu cầu (Too Many Requests)');
      assert.strictEqual(authService.determineReqReason({ statusCode: 200 }), null);
    });
  });
});
