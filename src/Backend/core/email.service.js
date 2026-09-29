const nodemailer = require('nodemailer');
const config = require('../config');
const logger = require('./logger');

const transporter = nodemailer.createTransport({
  host: config.smtp.host,
  port: config.smtp.port,
  secure: config.smtp.port === 465, // true nếu port 465, false cho 587
  auth: {
    user: config.smtp.user,
    pass: config.smtp.pass,
  },
});

const emailService = {
  async sendOtp(email, otp, purpose) {
    let subject = 'Mã OTP xác thực — FlowMoney';
    if (purpose === 'register') {
      subject = 'Mã OTP xác thực đăng ký tài khoản — FlowMoney';
    } else if (purpose === 'reset_password') {
      subject = 'Mã OTP khôi phục mật khẩu — FlowMoney';
    } else if (purpose === 'change_email') {
      subject = 'Mã OTP xác nhận đổi email — FlowMoney';
    }

    const html = `
      <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:24px;border:1px solid #e0e0e0;border-radius:8px;">
        <h2 style="color:#1565C0;">FlowMoney</h2>
        <p>Xin chào,</p>
        <p>Mã OTP của bạn là:</p>
        <div style="font-size:36px;font-weight:bold;letter-spacing:12px;color:#1565C0;text-align:center;padding:16px 0;">
          ${otp}
        </div>
        <p>Mã này có hiệu lực trong <strong>10 phút</strong>. Vui lòng không chia sẻ mã này với bất kỳ ai.</p>
        <p style="color:#999;font-size:12px;">Nếu bạn không yêu cầu hành động này, vui lòng bỏ qua email này.</p>
      </div>
    `;

    try {
      // Bỏ qua việc gửi email thật nếu chưa có cấu hình SMTP thật (tránh crash)
      if (config.smtp.user === 'your-email@gmail.com' || !config.smtp.user) {
        logger.info(`[MOCK EMAIL] To: ${email} | Subject: ${subject} | OTP: ${otp}`);
        return;
      }

      await transporter.sendMail({
        from: config.smtp.from,
        to: email,
        subject,
        html,
      });
      logger.info('OTP email sent', { email, purpose });
    } catch (err) {
      logger.error('Failed to send OTP email', { email, error: err.message });
      throw new Error('Không thể gửi email. Vui lòng thử lại sau.');
    }
  },

  /**
   * Gửi email cảnh báo bảo mật tài khoản
   */
  async sendSecurityAlert(email, alertData = {}) {
    const title = alertData.title || 'Cảnh báo bảo mật tài khoản — FlowMoney';
    const message = alertData.message || 'Chúng tôi phát hiện hành động quan trọng trên tài khoản của bạn.';
    const timeStr = alertData.time || new Date().toLocaleString('vi-VN');

    const html = `
      <div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px;border:1px solid #e0e0e0;border-radius:8px;">
        <h2 style="color:#d32f2f;">FlowMoney — Cảnh Báo Bảo Mật</h2>
        <p>Xin chào,</p>
        <p><strong>${title}</strong></p>
        <div style="background-color:#fff3e0;border-left:4px solid #ff9800;padding:12px;margin:16px 0;">
          <p style="margin:0;color:#e65100;">${message}</p>
          <p style="margin:8px 0 0 0;font-size:12px;color:#757575;">Thời gian: ${timeStr}</p>
        </div>
        <p style="color:#616161;font-size:13px;">Nếu bạn không thực hiện thao tác này, vui lòng đăng nhập ngay lập tức để đổi mật khẩu hoặc liên hệ quản trị viên.</p>
        <hr style="border:none;border-top:1px solid #eee;margin:20px 0;" />
        <p style="color:#9e9e9e;font-size:11px;">Đây là email tự động, vui lòng không trả lời thư này.</p>
      </div>
    `;

    try {
      if (config.smtp.user === 'your-email@gmail.com' || !config.smtp.user) {
        logger.info(`[MOCK SECURITY EMAIL] To: ${email} | Title: ${title}`);
        return { success: true, mock: true };
      }

      await transporter.sendMail({
        from: config.smtp.from,
        to: email,
        subject: title,
        html,
      });
      logger.info('Security alert email sent', { email, title });
      return { success: true };
    } catch (err) {
      logger.error('Failed to send security alert email', { email, error: err.message });
      throw new Error('Không thể gửi email cảnh báo bảo mật.');
    }
  },
};

module.exports = emailService;

