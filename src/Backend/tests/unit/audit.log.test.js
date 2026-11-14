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

  it('5. Middleware trích xuất clientIp an toàn và ghi audit log không quăng ReferenceError', (t, done) => {
    const originalRecord = authService.recordAuditLog;
    let recordedData = null;
    authService.recordAuditLog = async (data) => {
      recordedData = data;
      return { idlog: 999 };
    };

    const req = new EventEmitter();
    req.method = 'POST';
    req.url = '/api/v1/wallets';
    req.baseUrl = '';
    req.path = '/api/v1/wallets';
    req.headers = { 'x-forwarded-for': '6.6.6.6' };
    req.ip = '203.162.0.1';
    req.user = { idaccount: 10, username: 'testuser' };

    const res = new EventEmitter();
    res.statusCode = 201;
    res.writableEnded = true;

    auditLogMiddleware(req, res, () => {});
    res.emit('finish');

    setTimeout(() => {
      authService.recordAuditLog = originalRecord;
      assert.ok(recordedData, 'recordAuditLog phải được gọi');
      assert.equal(recordedData.ip, '203.162.0.1', 'IP lấy từ req.ip (trust proxy), bỏ qua x-forwarded-for do client gửi');
      assert.equal(recordedData.idaccount, 10);
      done();
    }, 50);
  });

  it('6. GET /api/admin/system/maintenance bị bỏ qua để tránh spam CSDL qua polling định kỳ', (t, done) => {
    let called = false;
    const originalRecord = authService.recordAuditLog;
    authService.recordAuditLog = async () => {
      called = true;
    };

    const req = new EventEmitter();
    req.method = 'GET';
    req.url = '/api/admin/system/maintenance';
    req.baseUrl = '';
    req.path = '/api/admin/system/maintenance';
    req.user = { idaccount: 1 };

    const res = new EventEmitter();
    res.statusCode = 200;
    res.writableEnded = true;

    auditLogMiddleware(req, res, () => {});
    res.emit('finish');

    setTimeout(() => {
      authService.recordAuditLog = originalRecord;
      assert.equal(called, false, 'Polling GET bảo trì không được ghi audit log');
      done();
    }, 50);
  });

  it('7. [Tầng 2 - Real-time Security] Request nặc danh không có targetId vẫn phát Socket event audit_activity lên Dashboard', (t, done) => {
    const socketModule = require('../../core/socket');
    const authRepository = require('../../modules/auth/auth.repository');
    const origEmit = socketModule.emitAuditActivity;
    const origFind = authRepository.findAccountByUsernameOrEmail;
    let emittedData = null;

    socketModule.emitAuditActivity = (data) => {
      emittedData = data;
    };
    authRepository.findAccountByUsernameOrEmail = async () => null;

    const req = new EventEmitter();
    req.method = 'POST';
    req.url = '/api/v1/auth/login';
    req.baseUrl = '';
    req.path = '/api/v1/auth/login';
    req.headers = {};
    req.ip = '1.2.3.4';
    req.body = { username: 'unknown_hacker' };

    const res = new EventEmitter();
    res.statusCode = 401;
    res.writableEnded = true;

    auditLogMiddleware(req, res, () => {});
    res.emit('finish');

    setTimeout(() => {
      socketModule.emitAuditActivity = origEmit;
      authRepository.findAccountByUsernameOrEmail = origFind;
      assert.ok(emittedData, 'Phải phát Socket event audit_activity');
      assert.equal(emittedData.status, 'Rejected');
      assert.equal(emittedData.username, 'unknown_hacker');
      assert.equal(emittedData.ip, '1.2.xx.xx', 'Admin-web chỉ nhận IP đã che');
      assert.ok(emittedData.timeReq, 'Phải có timeReq');
      done();
    }, 60);
  });

  const runAiops = (method, path, actionName) => new Promise((resolve) => {
    const calls = [];
    const originalRecord = authService.recordAuditLog;
    authService.recordAuditLog = async (...args) => { calls.push(args); };
    const req = new EventEmitter();
    req.method = method;
    req.url = path;
    req.baseUrl = '';
    req.path = path;
    req.user = { idaccount: 1 };
    if (actionName) req.auditActionName = actionName;
    const res = new EventEmitter();
    res.statusCode = 200;
    res.writableEnded = true;
    auditLogMiddleware(req, res, () => {});
    res.emit('finish');
    setTimeout(() => { authService.recordAuditLog = originalRecord; resolve(calls); }, 50);
  });

  it('8. Thao tác AIOps của admin (POST / DELETE) được ghi nhật ký, kể cả xem IP đầy đủ; GET polling AIOps vẫn bỏ qua', async () => {
    const reveal = await runAiops('POST', '/api/admin/aiops/quarantine/abc/reveal-ip', 'Xem IP đầy đủ của nguồn bị cô lập (abc)');
    assert.equal(reveal.length, 1, 'xem IP đầy đủ phải vào nhật ký');
    assert.ok(JSON.stringify(reveal[0]).includes('Xem IP đầy đủ'), 'đúng tên hành động');
    const unblock = await runAiops('DELETE', '/api/admin/aiops/quarantine/abc');
    assert.equal(unblock.length, 1, 'gỡ chặn phải vào nhật ký');
    const ban = await runAiops('POST', '/api/admin/aiops/quarantine/permanent-account');
    assert.equal(ban.length, 1, 'cấm vĩnh viễn phải vào nhật ký');
    const poll = await runAiops('GET', '/api/admin/aiops/status');
    assert.equal(poll.length, 0, 'GET polling AIOps không ghi');
  });

  it('9. recordAuditLog phát audit_activity với IP đã che (người đã đăng nhập)', async () => {
    const socketModule = require('../../core/socket');
    const authRepository = require('../../modules/auth/auth.repository');
    const origEmit = socketModule.emitAuditActivity;
    const origCreate = authRepository.createAuditLog;
    let emitted = null;
    socketModule.emitAuditActivity = (d) => { emitted = d; };
    authRepository.createAuditLog = async (d) => ({ idlog: 1, ...d, time_req: new Date(), time_res: new Date() });
    try {
      await authService.recordAuditLog({ idaccount: 5, request: 'GET /api/sync/pull', action: 'Đồng bộ', req_status: 'Pass', time_req: new Date(), time_res: new Date(), ip: '113.161.45.12' });
      assert.ok(emitted, 'phải phát audit_activity');
      assert.equal(emitted.ip, '113.161.xx.xx');
      assert.ok(!JSON.stringify(emitted).includes('113.161.45.12'));
    } finally {
      socketModule.emitAuditActivity = origEmit;
      authRepository.createAuditLog = origCreate;
    }
  });
});
