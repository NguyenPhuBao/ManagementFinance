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
};

module.exports = emailService;
