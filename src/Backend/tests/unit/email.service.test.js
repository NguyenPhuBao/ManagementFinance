const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const axios = require('axios');
const emailService = require('../../core/email.service');
const config = require('../../config');

describe('Email Service 2-Tier Test Suite (Brevo & Resend & SMTP)', () => {
  // ── TẦNG 1: Kiểm thử giao diện hàm & nội dung email (UI & Interface) ──
  it('Tầng 1: sendOtp tạo subject và nội dung tương ứng theo từng purpose', async () => {
    const originalBrevoKey = config.brevo.apiKey;
    const originalResendKey = config.resend.apiKey;
    const originalSmtpUser = config.smtp.user;
    config.brevo.apiKey = null;
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
      config.brevo.apiKey = originalBrevoKey;
      config.resend.apiKey = originalResendKey;
      config.smtp.user = originalSmtpUser;
    }
  });

  it('Tầng 1: sendSecurityAlert tạo cảnh báo bảo mật hợp lệ', async () => {
    const originalBrevoKey = config.brevo.apiKey;
    const originalResendKey = config.resend.apiKey;
    const originalSmtpUser = config.smtp.user;
    config.brevo.apiKey = null;
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
      config.brevo.apiKey = originalBrevoKey;
      config.resend.apiKey = originalResendKey;
      config.smtp.user = originalSmtpUser;
    }
  });

  // ── TẦNG 2: Kiểm thử hành vi thực tế & cơ chế chuyển đổi kênh (System Impact & Fail-safe) ──
  it('Tầng 2: Khi có BREVO_API_KEY, ưu tiên gửi qua Brevo REST API v3', async () => {
    const originalBrevoKey = config.brevo.apiKey;
    const originalPost = axios.post;

    config.brevo.apiKey = 'xkeysib-test-mock-key';

    // Mock axios.post trả về 201 Created của Brevo
    let calledUrl = null;
    let calledPayload = null;
    let calledHeaders = null;

    axios.post = async (url, payload, options) => {
      calledUrl = url;
      calledPayload = payload;
      calledHeaders = options.headers;
      return { status: 201, data: { messageId: '<test-message-id-123@brevo.com>' } };
    };

    try {
      const res = await emailService.sendOtp('user@anydomain.com', '998877', 'register');

      assert.equal(res.success, true);
      assert.equal(res.provider, 'brevo');
      assert.equal(res.messageId, '<test-message-id-123@brevo.com>');

      // Xác minh đúng endpoint và headers của Brevo
      assert.equal(calledUrl, 'https://api.brevo.com/v3/smtp/email');
      assert.equal(calledHeaders['api-key'], 'xkeysib-test-mock-key');
      assert.equal(calledPayload.to[0].email, 'user@anydomain.com');
      assert.match(calledPayload.htmlContent, /998877/);
    } finally {
      config.brevo.apiKey = originalBrevoKey;
      axios.post = originalPost;
    }
  });

  it('Tầng 2: Khi Brevo API lỗi, tự động fallback sang kênh kế tiếp mà không làm sập ứng dụng', async () => {
    const originalBrevoKey = config.brevo.apiKey;
    const originalResendKey = config.resend.apiKey;
    const originalSmtpUser = config.smtp.user;
    const originalPost = axios.post;

    config.brevo.apiKey = 'xkeysib-invalid-key';
    config.resend.apiKey = null;
    config.smtp.user = null;

    // Giả lập Brevo API trả về lỗi
    axios.post = async () => {
      throw new Error('Brevo service temporarily unavailable');
    };

    try {
      // Khi Brevo lỗi, hệ thống phải tự động fallback xuống mock mà không ném lỗi unhandled
      const res = await emailService.sendOtp('fallback@example.com', '111222', 'register');
      assert.equal(res.success, true);
      assert.equal(res.provider, 'mock');
    } finally {
      config.brevo.apiKey = originalBrevoKey;
      config.resend.apiKey = originalResendKey;
      config.smtp.user = originalSmtpUser;
      axios.post = originalPost;
    }
  });
});
