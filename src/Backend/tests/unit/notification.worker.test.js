/**
 * Unit Test — Notification Background Worker & Jobs (TDD Red -> Green -> Refactor)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const { processNotificationJob } = require('../../workers/notification.worker');
const notificationJobs = require('../../modules/notification/notification.jobs');

describe('Notification Worker & BullMQ Jobs — Xử lý tác vụ nền bất đồng bộ', () => {
  it('1. processNotificationJob xử lý job send-email (cảnh báo bảo mật)', async () => {
    let emailSent = null;

    const mockEmailService = {
      sendSecurityAlert: async (email, data) => {
        emailSent = { email, data };
        return true;
      },
    };

    const job = {
      id: 'job_email_1',
      name: 'send-email',
      data: {
        to: 'user@example.com',
        type: 'PASSWORD_CHANGED',
        payload: {
          title: 'Mật khẩu đã được thay đổi',
          message: 'Mật khẩu tài khoản của bạn vừa được thay đổi lúc 11:30.',
        },
      },
    };

    const result = await processNotificationJob(job, { emailService: mockEmailService });

    assert.strictEqual(result.success, true);
    assert.ok(emailSent, 'Email phải được gọi gửi');
    assert.strictEqual(emailSent.email, 'user@example.com');
    assert.strictEqual(emailSent.data.title, 'Mật khẩu đã được thay đổi');
  });

  it('2. processNotificationJob xử lý lỗi gracefully khi thiếu thông tin email người nhận', async () => {
    const job = {
      id: 'job_invalid',
      name: 'send-email',
      data: {
        to: '', // thiếu email
      },
    };

    await assert.rejects(
      async () => {
        await processNotificationJob(job, { emailService: {} });
      },
      {
        message: /Email recipient is required/,
      }
    );
  });

  it('3. processNotificationJob xử lý job push-socket (thông báo realtime trì hoãn)', async () => {
    let socketDispatched = null;

    const mockSocket = {
      emitBankTransaction: (idaccount, payload) => {
        socketDispatched = { idaccount, payload };
      },
      emitAdminNotification: () => {},
    };

    const job = {
      id: 'job_socket_1',
      name: 'send-socket',
      data: {
        idaccount: 99,
        event: 'bank_transaction',
        payload: { title: 'Thông báo trễ' },
      },
    };

    const result = await processNotificationJob(job, { socket: mockSocket });
    assert.strictEqual(result.success, true);
    assert.strictEqual(socketDispatched.idaccount, 99);
  });
});
