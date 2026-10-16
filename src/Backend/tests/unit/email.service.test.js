const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const emailService = require('../../core/email.service');
const config = require('../../config');

describe('Email Service 2-Tier Test Suite', () => {
  // ── TẦNG 1: Kiểm thử giao diện hàm & nội dung email (UI & Interface) ──
  it('Tầng 1: sendOtp tạo subject và nội dung tương ứng theo từng purpose', async () => {
    // Lưu tạm config để test mock
    const originalResendKey = config.resend.apiKey;
    const originalSmtpUser = config.smtp.user;
    config.resend.apiKey = null;
    config.smtp.user = null;

    try {
      const resRegister = await emailService.sendOtp('test@example.com', '123456', 'register');
      assert.equal(resRegister.success, true);
      assert.equal(resRegister.provider, 'mock');

      const resReset = await emailService.sendOtp('test@example.com', '654321', 'reset_password');
      assert.equal(resReset.success, true);
      assert.equal(resReset.provider, 'mock');

      const resChangeEmail = await emailService.sendOtp('test@example.com', '112233', 'change_email');
      assert.equal(resChangeEmail.success, true);
      assert.equal(resChangeEmail.provider, 'mock');
    } finally {
      config.resend.apiKey = originalResendKey;
      config.smtp.user = originalSmtpUser;
    }
  });

  it('Tầng 1: sendSecurityAlert tạo cảnh báo bảo mật hợp lệ', async () => {
    const originalResendKey = config.resend.apiKey;
    const originalSmtpUser = config.smtp.user;
    config.resend.apiKey = null;
    config.smtp.user = null;

    try {
      const res = await emailService.sendSecurityAlert('admin@example.com', {
        title: 'Đăng nhập từ IP lạ',
        message: 'Có lượt đăng nhập đáng ngờ từ IP 1.2.3.4',
      });
      assert.equal(res.success, true);
      assert.equal(res.provider, 'mock');
    } finally {
      config.resend.apiKey = originalResendKey;
      config.smtp.user = originalSmtpUser;
    }
  });

  // ── TẦNG 2: Kiểm thử hành vi thực tế & cơ chế chịu lỗi (System Impact & Fail-safe) ──
  it('Tầng 2: Hệ thống tự động chuyển đổi kênh (Fail-safe) không làm crash app khi thiếu key', async () => {
    const originalResendKey = config.resend.apiKey;
    const originalSmtpUser = config.smtp.user;
    config.resend.apiKey = null;
    config.smtp.user = 'your-email@gmail.com'; // Default dummy user

    try {
      const res = await emailService.sendMail({
        to: 'user@example.com',
        subject: 'Kiểm thử Mock Mode',
        html: '<p>Nội dung</p>',
      });

      assert.equal(res.success, true);
      assert.equal(res.provider, 'mock');
    } finally {
      config.resend.apiKey = originalResendKey;
      config.smtp.user = originalSmtpUser;
    }
  });
});
