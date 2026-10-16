const nodemailer = require('nodemailer');
const { Resend } = require('resend');
const config = require('../config');
const logger = require('./logger');

// Khởi tạo transporter cho SMTP fallback
let smtpTransporter = null;
function getSmtpTransporter() {
  if (!smtpTransporter && config.smtp && config.smtp.user) {
    smtpTransporter = nodemailer.createTransport({
      host: config.smtp.host,
      port: config.smtp.port,
      secure: config.smtp.port === 465,
      auth: {
        user: config.smtp.user,
        pass: config.smtp.pass,
      },
      // Giới hạn timeout cho SMTP socket để chống treo nghẽn trên môi trường Cloud
      connectionTimeout: 5000,
      greetingTimeout: 5000,
      socketTimeout: 7000,
    });
  }
  return smtpTransporter;
}

// Khởi tạo Resend client
let resendClient = null;
function getResendClient() {
  if (!resendClient && config.resend && config.resend.apiKey) {
    resendClient = new Resend(config.resend.apiKey);
  }
  return resendClient;
}

/**
 * Bọc timeout cho Promise (Fail-safe, ngăn chặn treo quá 30s)
 */
function withTimeout(promise, ms, errorMsg) {
  let timer;
  const timeoutPromise = new Promise((_, reject) => {
    timer = setTimeout(() => {
      reject(new Error(errorMsg || `Thao tác quá thời gian chờ (${ms}ms)`));
    }, ms);
  });

  return Promise.race([promise, timeoutPromise]).finally(() => {
    clearTimeout(timer);
  });
}

const emailService = {
  /**
   * Phương thức gửi email cốt lõi đa kênh (Resend HTTP REST API -> SMTP -> Mock)
   */
  async sendMail({ from, to, subject, html }) {
    const resend = getResendClient();

    // 1. Ưu tiên 1: Dùng Resend HTTP REST API (Cổng 443 HTTPS - Không bị chặn trên Cloud)
    if (resend) {
      try {
        const sender = from || config.resend.from || 'FlowMoney <onboarding@resend.dev>';
        const recipients = Array.isArray(to) ? to : [to];

        const sendPromise = resend.emails.send({
          from: sender,
          to: recipients,
          subject,
          html,
        });

        // Bọc timeout 8s cho HTTP API call
        const response = await withTimeout(
          sendPromise,
          8000,
          'Resend API không phản hồi trong 8s'
        );

        if (response.error) {
          throw new Error(response.error.message || 'Lỗi gửi email qua Resend');
        }

        logger.info('Email sent successfully via Resend API', {
          id: response.data?.id,
          to,
          subject,
        });
        return { success: true, provider: 'resend', id: response.data?.id };
      } catch (err) {
        logger.error('Failed to send email via Resend API, attempting fallback', {
          error: err.message,
          to,
        });
      }
    }

    // 2. Ưu tiên 2: Dùng Nodemailer SMTP (Chạy trên local hoặc server mở port SMTP)
    const hasSmtpConfig =
      config.smtp.user &&
      config.smtp.user !== 'your-email@gmail.com' &&
      config.smtp.pass;

    if (hasSmtpConfig) {
      try {
        const transporter = getSmtpTransporter();
        const mailOptions = {
          from: from || config.smtp.from,
          to,
          subject,
          html,
        };

        // Bọc timeout 7s để chống treo lơ lửng trên Render Free
        await withTimeout(
          transporter.sendMail(mailOptions),
          7000,
          'Kết nối SMTP quá thời gian (Render có thể đang chặn port 587)'
        );

        logger.info('Email sent successfully via SMTP', { to, subject });
        return { success: true, provider: 'smtp' };
      } catch (err) {
        logger.error('Failed to send email via SMTP', {
          error: err.message,
          to,
        });
        throw new Error('Không thể gửi email. Vui lòng thử lại sau.');
      }
    }

    // 3. Ưu tiên 3: Mock email (Khi không có cấu hình thật, môi trường dev/test)
    logger.info(`[MOCK EMAIL] To: ${to} | Subject: ${subject}`);
    return { success: true, provider: 'mock' };
  },

  /**
   * Gửi OTP xác thực (Đăng ký, Quên mật khẩu, Đổi email)
   */
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

    return await this.sendMail({
      to: email,
      subject,
      html,
    });
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

    return await this.sendMail({
      to: email,
      subject: title,
      html,
    });
  },
};

module.exports = emailService;
