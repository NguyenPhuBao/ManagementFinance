const test = require('node:test');
const assert = require('node:assert/strict');

test('AIOps Sentinel & Account Status — 2-Tier Verification Suite (Tasks 58.5, 58.6 & Đơn 43)', async (t) => {
  const { AIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
  const aiopsController = require('../../modules/aiops/aiops.controller');
  const { prisma } = require('../../config/db');
  const socket = require('../../core/socket');

  // ═════════════════════════════════════════════════════════════════════
  // TC1. Task 58.6 #1: Tài khoản PendingDelete không bị đổi trạng thái CSDL và KHÔNG bị phát force_logout
  // ═════════════════════════════════════════════════════════════════════
  await t.test('1. [Task 58.6 #1] AIOps cách ly tài khoản PendingDelete -> Không đổi status DB và Không phát force_logout', async () => {
    const aiops = new AIOpsQuarantine({ autoExpire: false });
    const origUpdateMany = prisma.account.updateMany;
    const origFindFirst = prisma.account.findFirst;
    const origFindUnique = prisma.account.findUnique;
    const origEmitForceLogout = socket.emitForceLogout;

    let forceLogoutEmitted = false;
    let emittedTargetId = null;
    let updateWhereExecuted = null;

    socket.emitForceLogout = (targetId, code, reason) => {
      forceLogoutEmitted = true;
      emittedTargetId = targetId;
    };

    // Giả lập tài khoản 502 đang ở trạng thái PendingDelete
    prisma.account.findFirst = async ({ where }) => {
      return { idaccount: 502, username: 'pending_user', status: 'PendingDelete', reason_inactive: null };
    };
    prisma.account.findUnique = async ({ where }) => {
      return { idaccount: 502, username: 'pending_user', status: 'PendingDelete', reason_inactive: null };
    };

    prisma.account.updateMany = async ({ where, data }) => {
      updateWhereExecuted = where;
      // Do where có điều kiện status: { not: 'PendingDelete' }, khớp 0 hàng
      return { count: 0 };
    };

    try {
      await aiops.quarantinePair({
        ip: '10.0.0.2',
        username: 'pending_user',
        idaccount: 502,
        reason: 'Brute force credential stuffing',
      });

      // Chờ microtask để async DB sync hoàn tất
      await new Promise((r) => setTimeout(r, 50));

      // Kiểm tra điều kiện WHERE bảo vệ PendingDelete
      assert.ok(updateWhereExecuted, 'Phải có truy vấn update CSDL');
      const andArr = updateWhereExecuted.AND;
      assert.ok(andArr.some(c => c.status === 'Active'), 'Khoá tự động chỉ được đụng hàng đang Active');

      // Tác động hệ thống Tầng 2: update khớp 0 hàng -> TUYỆT ĐỐI KHÔNG phát force_logout
      assert.strictEqual(forceLogoutEmitted, false, 'updateMany khớp 0 hàng tuyệt đối không được phát force_logout');
      assert.strictEqual(emittedTargetId, null);
    } finally {
      prisma.account.updateMany = origUpdateMany;
      prisma.account.findFirst = origFindFirst;
      prisma.account.findUnique = origFindUnique;
      socket.emitForceLogout = origEmitForceLogout;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC2. Task 58.6 #2: Username toàn chữ số (e.g. "123456") không nhầm lẫn với idaccount 123456
  // ═════════════════════════════════════════════════════════════════════
  await t.test('2. [Task 58.6 #2] Username toàn chữ số "123456" chỉ khóa đúng User A (idaccount 888), không khóa User B (idaccount 123456)', async () => {
    const aiops = new AIOpsQuarantine({ autoExpire: false });
    const origUpdateMany = prisma.account.updateMany;
    const origFindFirst = prisma.account.findFirst;
    const origFindUnique = prisma.account.findUnique;
    const origEmitForceLogout = socket.emitForceLogout;

    let loggedOutId = null;
    let targetAccountUpdated = null;

    socket.emitForceLogout = (targetId) => {
      loggedOutId = targetId;
    };

    // Database mock:
    // User A: username "123456", idaccount: 888
    // User B: username "bob_user", idaccount: 123456
    prisma.account.findFirst = async ({ where }) => {
      if (where.username === '123456') {
        return { idaccount: 888, username: '123456', status: 'Active' };
      }
      return null;
    };

    prisma.account.findUnique = async ({ where }) => {
      if (where.idaccount === 888) {
        return { idaccount: 888, username: '123456', status: 'Active' };
      }
      if (where.idaccount === 123456) {
        return { idaccount: 123456, username: 'bob_user', status: 'Active' };
      }
      return null;
    };

    prisma.account.updateMany = async ({ where, data }) => {
      targetAccountUpdated = where;
      return { count: 1 };
    };

    try {
      // Cách ly mục tiêu vi phạm là username "123456" (không truyền idaccount, hoặc truyền username chuỗi)
      await aiops.quarantinePair({
        ip: '10.0.0.3',
        username: '123456',
        reason: 'Failed logins threshold exceeded',
      });

      await new Promise((r) => setTimeout(r, 50));

      // Kiểm tra: Phải cập nhật đúng idaccount: 888 của User A
      assert.ok(targetAccountUpdated, 'Phải thực thi updateMany CSDL');
      const andArr = targetAccountUpdated.AND;
      assert.ok(andArr.some(c => c.idaccount === 888), 'Phải khóa tài khoản idaccount 888');
      assert.ok(!andArr.some(c => c.idaccount === 123456), 'TUYỆT ĐỐI KHÔNG được khóa tài khoản idaccount 123456');

      // Socket force_logout chỉ gửi cho User A (888), không gửi cho User B (123456)
      assert.strictEqual(loggedOutId, 888, 'Socket force_logout phải gửi tới idaccount 888');
    } finally {
      prisma.account.updateMany = origUpdateMany;
      prisma.account.findFirst = origFindFirst;
      prisma.account.findUnique = origFindUnique;
      socket.emitForceLogout = origEmitForceLogout;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC3. Task 58.5: Khóa do Admin thủ công KHÔNG bị AIOps quét mở khóa tự động
  // ═════════════════════════════════════════════════════════════════════
  await t.test('3. [Task 58.5] Tài khoản do Admin khóa thủ công không bị AIOps quét mở khóa tự động', async () => {
    const aiops = new AIOpsQuarantine({ autoExpire: false });
    const origUpdateMany = prisma.account.updateMany;
    const origFindFirst = prisma.account.findFirst;
    const origFindUnique = prisma.account.findUnique;

    let updateCalled = false;
    let updateWhere = null;

    prisma.account.findUnique = async () => ({
      idaccount: 999,
      username: 'admin_locked_user',
      status: 'Inactive',
      reason_inactive: 'Quản trị viên khóa do phát hiện gian lận thẻ',
    });

    prisma.account.updateMany = async ({ where, data }) => {
      updateCalled = true;
      updateWhere = where;
      return { count: 0 };
    };

    try {
      // Giả lập tài khoản 999 trong bộ nhớ cách ly của AIOps
      const rec = aiops.quarantinePair({
        ip: '10.0.0.4',
        username: 'admin_locked_user',
        idaccount: 999,
        reason: 'AIOps temporary lock',
      });
      // Đã hết hạn 15 phút
      rec.accountExpiresAt = Date.now() - 5000;

      // Lazy check kích hoạt auto-unlock
      aiops.isAccountQuarantined(999);
      await new Promise((r) => setTimeout(r, 50));

      assert.ok(updateCalled, 'Phải gọi updateMany để giải phóng hết hạn');
      const andArr = updateWhere.AND;
      // Phải có điều kiện loại trừ Admin / Quản trị viên
      const dauCond = andArr.find(c => c.reason_inactive?.startsWith);
      assert.ok(dauCond, 'Chỉ mở hàng mang dấu khoá tự động');
      assert.strictEqual(dauCond.reason_inactive.startsWith, '[AIOPS_AUTO_QUARANTINE]');
    } finally {
      prisma.account.updateMany = origUpdateMany;
      prisma.account.findFirst = origFindFirst;
      prisma.account.findUnique = origFindUnique;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC4. Task 58.5: Tài khoản tạm khóa bởi AIOps tự động mở khóa sau 15 phút
  // ═════════════════════════════════════════════════════════════════════
  await t.test('4. [Task 58.5] Tài khoản có tiền tố [AIOPS_AUTO_QUARANTINE] tự động mở khóa sau 15 phút', async () => {
    const aiops = new AIOpsQuarantine({ autoExpire: false });
    const origUpdateMany = prisma.account.updateMany;
    const origFindUnique = prisma.account.findUnique;

    let unlockedData = null;

    prisma.account.findUnique = async () => ({
      idaccount: 777,
      username: 'aiops_user',
      status: 'Inactive',
      reason_inactive: '[AIOPS_AUTO_QUARANTINE]: Tấn công dò mật khẩu Brute-Force',
    });

    prisma.account.updateMany = async ({ where, data }) => {
      unlockedData = data;
      return { count: 1 };
    };

    try {
      const rec = aiops.quarantinePair({
        ip: '10.0.0.5',
        username: 'aiops_user',
        idaccount: 777,
        reason: 'Tấn công dò mật khẩu Brute-Force',
      });
      rec.accountExpiresAt = Date.now() - 1000;

      const res = aiops.isAccountQuarantined(777);
      assert.strictEqual(res.quarantined, false, 'Sau khi hết hạn phải trả về quarantined = false');
      assert.strictEqual(rec.accountStatus, 'unlocked');

      await new Promise((r) => setTimeout(r, 50));

      assert.ok(unlockedData, 'CSDL phải được cập nhật');
      assert.strictEqual(unlockedData.status, 'Active');
      assert.strictEqual(unlockedData.reason_inactive, null);
    } finally {
      prisma.account.updateMany = origUpdateMany;
      prisma.account.findUnique = origFindUnique;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC5. Đơn 43 (A1): Admin mở khóa qua unblockAccount không bị trùng lặp khối updateMany
  // ═════════════════════════════════════════════════════════════════════
  await t.test('5. [Đơn 43 A1] Admin mở khóa qua unblockAccount API hoạt động sạch sẽ không bị duplicate updateMany', async () => {
    let unblockCalled = false;
    const { defaultAIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
    const origUnblock = defaultAIOpsQuarantine.unblockAccount;

    defaultAIOpsQuarantine.unblockAccount = async (target, options) => {
      unblockCalled = true;
      assert.strictEqual(target, 'target_user');
      assert.strictEqual(options.unblockedBy, 'admin_super');
      return 1;
    };

    const req = {
      body: { username: 'target_user' },
      user: { username: 'admin_super' },
    };

    let responseData = null;
    const res = {
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(data) {
        responseData = data;
        return this;
      },
    };

    try {
      await aiopsController.unblockAccount(req, res);

      assert.strictEqual(unblockCalled, true, 'unblockAccount của quarantine service phải được gọi');
      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(responseData.success, true);
      assert.strictEqual(responseData.data.count, 1);
    } finally {
      defaultAIOpsQuarantine.unblockAccount = origUnblock;
    }
  });
});

