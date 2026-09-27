const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const EventEmitter = require('events');
const authService = require('../../modules/auth/auth.service');
const auditLogMiddleware = require('../../middleware/audit-log.middleware');

describe('AuditLog Middleware & Service Logic Tests', () => {
  it('1. Đăng nhập thành công (HTTP 200 POST) với req.destroyed=true phải ghi nhận Pass (Thành công), KHÔNG ĐƯỢC ghi nhận Interrupted', (t, done) => {
    const req = new EventEmitter();
    req.method = 'POST';
    req.url = '/api/auth/login';
    req.baseUrl = '';
    req.path = '/api/auth/login';
    req.destroyed = true; // Mô phỏng Node.js đánh dấu req.destroyed sau khi đọc xong body
    req.aborted = false;
    req.user = { idaccount: 1, username: 'admin', fullname: 'Administrator' };

    const res = new EventEmitter();
    res.statusCode = 200;
    res.writableEnded = true;
    res.finished = true;

    auditLogMiddleware(req, res, () => {});

    // Khi response kết thúc bình thường
    res.emit('finish');

    const status = authService.determineReqStatus(res, req);
    const reason = authService.determineReqReason(res, req);
    const action = authService.formatActionName(req.method, req.path, req);

    assert.equal(status, 'Pass', 'Trạng thái đăng nhập thành công phải là Pass');
    assert.equal(reason, null, 'Lý do phải là null (không có lỗi ngắt quãng)');
    assert.equal(action, 'Đăng nhập hệ thống');
    done();
  });

  it('2. Request thực sự bị ngắt kết nối giữa chừng (res.writableEnded=false khi socket close) phải ghi nhận Interrupted', (t, done) => {
    const req = new EventEmitter();
    req.method = 'POST';
    req.url = '/api/ai/chatbot/chat/stream';
    req.path = '/api/ai/chatbot/chat/stream';
    req.aborted = true;

    const res = new EventEmitter();
    res.statusCode = 200;
    res.writableEnded = false;
    res.finished = false;

    auditLogMiddleware(req, res, () => {});

    // Socket bị ngắt kết nối trước khi res kết thúc
    res.emit('close');

    const status = authService.determineReqStatus(res, req);
    const reason = authService.determineReqReason(res, req);

    assert.equal(status, 'Interrupted', 'Trạng thái ngắt kết nối phải là Interrupted');
    assert.equal(reason, 'Yêu cầu bị ngắt kết nối giữa chừng');
    done();
  });

  it('3. Hành động Làm mới hội thoại AI (/api/ai/chatbot/reset) phải khớp tên hành động và có status Pass', () => {
    const req = {
      method: 'POST',
      url: '/api/ai/chatbot/reset',
      path: '/api/ai/chatbot/reset',
    };
    const res = { statusCode: 200 };

    const action = authService.formatActionName(req.method, req.path, req);
    const status = authService.determineReqStatus(res, req);

    assert.equal(action, 'Làm mới hội thoại AI');
    assert.equal(status, 'Pass');
  });

  it('4. Khi client chủ động hủy stream chat, req.auditReason tùy chỉnh phải được bảo toàn thay vì câu mặc định', () => {
    const req = {
      auditStatus: 'Interrupted',
      auditReason: 'Người dùng dừng phản hồi hoặc đổi khung chat mới',
    };
    const res = { statusCode: 200 };

    const reason = authService.determineReqReason(res, req);
    assert.equal(reason, 'Người dùng dừng phản hồi hoặc đổi khung chat mới');
  });
});
