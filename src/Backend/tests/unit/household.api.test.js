const test = require('node:test');
const assert = require('node:assert/strict');

test('Household Module — Tầng 1: API Controller & Contract Verification Suite (16 Endpoints)', async (t) => {
  const householdService = require('../../modules/household/household.service');
  const householdController = require('../../modules/household/household.controller');

  // Helper tạo mock request & response
  function createMockContext({ user = { idaccount: 10, email: 'tuanan@flowmoney.io', permissions: ['household'] }, body = {}, params = {}, query = {} } = {}) {
    let statusCode = 200;
    let jsonBody = null;
    const req = { user, body, params, query, headers: {}, ip: '127.0.0.1' };
    const res = {
      status(code) {
        statusCode = code;
        return this;
      },
      json(data) {
        jsonBody = data;
        return this;
      },
    };
    return { req, res, getStatus: () => statusCode, getBody: () => jsonBody };
  }

  // ── [1] POST /api/households (Tạo nhà) ───────────────────
  await t.test('1. createHousehold: Trả về HTTP 201 và thông tin nhà khi người dùng có quyền household', async () => {
    const origCreate = householdService.createHousehold;
    householdService.createHousehold = async (idaccount, data) => ({
      household: {
        id: 1,
        name: data.name,
        status: 'Active',
        maxMembers: 6,
        ownerId: idaccount,
        createAt: new Date().toISOString(),
        maxSharedWallets: 10,
        contributionDueDay: 5,
      },
      myRole: 'Owner',
      members: [],
      formerMembers: [],
    });

    const { req, res, getStatus, getBody } = createMockContext({
      body: { name: 'Gia đình Tuấn An' },
    });

    try {
      await householdController.createHousehold(req, res);
      assert.strictEqual(getStatus(), 201);
      assert.strictEqual(getBody().success, true);
      assert.strictEqual(getBody().data.household.name, 'Gia đình Tuấn An');
      assert.strictEqual(getBody().data.myRole, 'Owner');
    } finally {
      householdService.createHousehold = origCreate;
    }
  });

  await t.test('1b. createHousehold: Trả về HTTP 400 khi tên nhà rỗng hoặc quá 100 ký tự', async () => {
    const { req, res, getStatus, getBody } = createMockContext({
      body: { name: '   ' },
    });

    await householdController.createHousehold(req, res);
    assert.strictEqual(getStatus(), 400);
    assert.strictEqual(getBody().success, false);
    assert.match(getBody().message, /tên nhà/i);
  });

  // ── [2] GET /api/households/me (Lấy thông tin nhà tôi) ────
  await t.test('2. getMyHousehold: Trả về HTTP 200 và household: null khi chưa ở nhà nào', async () => {
    const origGet = householdService.getMyHousehold;
    householdService.getMyHousehold = async () => null;

    const { req, res, getStatus, getBody } = createMockContext();

    try {
      await householdController.getMyHousehold(req, res);
      assert.strictEqual(getStatus(), 200);
      assert.strictEqual(getBody().success, true);
      assert.strictEqual(getBody().data.household, null);
    } finally {
      householdService.getMyHousehold = origGet;
    }
  });

  // ── [3] POST /api/households/invites (Tạo mã mời 8 ký tự) ─
  await t.test('3. createInviteCode: Trả về HTTP 201 với mã 8 ký tự và hạn 48 giờ', async () => {
    const origCreate = householdService.createInviteCode;
    const expiresAt = new Date(Date.now() + 48 * 3600 * 1000).toISOString();
    householdService.createInviteCode = async (idaccount, data) => ({
      code: 'ABCD2345',
      role: data.role,
      expiresAt,
    });

    const { req, res, getStatus, getBody } = createMockContext({
      body: { role: 'Member' },
    });

    try {
      await householdController.createInviteCode(req, res);
      assert.strictEqual(getStatus(), 201);
      assert.strictEqual(getBody().data.code, 'ABCD2345');
      assert.strictEqual(getBody().data.role, 'Member');
    } finally {
      householdService.createInviteCode = origCreate;
    }
  });

  // ── [4] GET /api/households/invites (Danh sách mã mời) ───
  await t.test('4. getHouseholdInvites: Trả về HTTP 200 danh sách mã mời và lời mời email', async () => {
    const origGet = householdService.getHouseholdInvites;
    householdService.getHouseholdInvites = async () => [
      { code: 'CODE1234', role: 'Member', email: null, status: 'Pending' },
      { code: 'CODE5678', role: 'Viewer', email: 'guest@flowmoney.io', status: 'Pending' },
    ];

    const { req, res, getStatus, getBody } = createMockContext();

    try {
      await householdController.getHouseholdInvites(req, res);
      assert.strictEqual(getStatus(), 200);
      assert.strictEqual(getBody().data.length, 2);
    } finally {
      householdService.getHouseholdInvites = origGet;
    }
  });

  // ── [5] DELETE /api/households/invites/:code (Hủy mã mời) ─
  await t.test('5. revokeInviteCode: Trả về HTTP 200 khi hủy mã thành công', async () => {
    const origRevoke = householdService.revokeInvite;
    householdService.revokeInvite = async () => true;

    const { req, res, getStatus, getBody } = createMockContext({
      params: { code: 'ABCD2345' },
    });

    try {
      await householdController.revokeInvite(req, res);
      assert.strictEqual(getStatus(), 200);
      assert.strictEqual(getBody().data.revoked, true);
    } finally {
      householdService.revokeInvite = origRevoke;
    }
  });

  // ── [6] GET /api/households/invites/:code (Xem trước mã) ─
  await t.test('6. previewInvite: Trả về HTTP 200 thông tin xem trước của nhà', async () => {
    const origPreview = householdService.previewInvite;
    householdService.previewInvite = async () => ({
      householdName: 'Gia đình Tuấn An',
      ownerName: 'Tuấn An',
      memberCount: 3,
      maxMembers: 6,
      role: 'Member',
      expiresAt: new Date().toISOString(),
    });

    const { req, res, getStatus, getBody } = createMockContext({
      params: { code: 'ABCD2345' },
    });

    try {
      await householdController.previewInvite(req, res);
      assert.strictEqual(getStatus(), 200);
      assert.strictEqual(getBody().data.householdName, 'Gia đình Tuấn An');
    } finally {
      householdService.previewInvite = origPreview;
    }
  });

  // ── [7] POST /api/households/join (Tham gia bằng mã) ─────
  await t.test('7. joinByCode: Trả về HTTP 200 và thông tin nhà sau khi vào thành công', async () => {
    const origJoin = householdService.joinByCode;
    householdService.joinByCode = async (idaccount, code) => ({
      household: {
        id: 1,
        name: 'Gia đình Tuấn An',
        status: 'Active',
        maxMembers: 6,
        ownerId: 1,
        createAt: new Date().toISOString(),
        maxSharedWallets: 10,
        contributionDueDay: 5,
      },
      myRole: 'Member',
      members: [],
      formerMembers: [],
    });

    const { req, res, getStatus, getBody } = createMockContext({
      body: { code: 'ABCD2345' },
    });

    try {
      await householdController.joinByCode(req, res);
      assert.strictEqual(getStatus(), 200);
      assert.strictEqual(getBody().data.myRole, 'Member');
    } finally {
      householdService.joinByCode = origJoin;
    }
  });

  // ── [8] PATCH /api/households/members/:idaccount (Đổi vai)
  await t.test('8. updateMemberRole: Trả về HTTP 200 sau khi đổi vai thành công', async () => {
    const origUpdate = householdService.updateMemberRole;
    householdService.updateMemberRole = async (ownerId, targetId, role) => ({
      targetIdaccount: targetId,
      newRole: role,
    });

    const { req, res, getStatus, getBody } = createMockContext({
      params: { idaccount: '25' },
      body: { role: 'Viewer' },
    });

    try {
      await householdController.updateMemberRole(req, res);
      assert.strictEqual(getStatus(), 200);
      assert.strictEqual(getBody().data.newRole, 'Viewer');
    } finally {
      householdService.updateMemberRole = origUpdate;
    }
  });

  // ── [9] POST /api/households/transfer-owner (Chuyển chủ) ──
  await t.test('9. transferOwner: Trả về HTTP 200 khi chuyển quyền Chủ nhà thành công', async () => {
    const origTransfer = householdService.transferOwner;
    householdService.transferOwner = async (ownerId, newOwnerId) => ({
      household: {
        id: 1,
        name: 'Gia đình Tuấn An',
        status: 'Active',
        maxMembers: 6,
        ownerId: newOwnerId,
        createAt: new Date().toISOString(),
        maxSharedWallets: 10,
        contributionDueDay: 5,
      },
      myRole: 'Member',
      members: [],
      formerMembers: [],
    });

    const { req, res, getStatus, getBody } = createMockContext({
      body: { idaccount: 25 },
    });

    try {
      await householdController.transferOwner(req, res);
      assert.strictEqual(getStatus(), 200);
      assert.strictEqual(getBody().data.household.ownerId, 25);
    } finally {
      householdService.transferOwner = origTransfer;
    }
  });

  // ── [10] DELETE /api/households/members/:idaccount (Mời ra)
  await t.test('10. removeMember: Trả về HTTP 200 sau khi mời thành viên ra khỏi nhà', async () => {
    const origRemove = householdService.removeMember;
    householdService.removeMember = async () => true;

    const { req, res, getStatus, getBody } = createMockContext({
      params: { idaccount: '25' },
    });

    try {
      await householdController.removeMember(req, res);
      assert.strictEqual(getStatus(), 200);
      assert.strictEqual(getBody().data.removed, true);
    } finally {
      householdService.removeMember = origRemove;
    }
  });

  // ── [11] POST /api/households/leave (Rời nhà) ─────────────
  await t.test('11. leaveHousehold: Thành viên rời nhà thành công trả về household: null', async () => {
    const origLeave = householdService.leaveHousehold;
    householdService.leaveHousehold = async () => true;

    const { req, res, getStatus, getBody } = createMockContext();

    try {
      await householdController.leaveHousehold(req, res);
      assert.strictEqual(getStatus(), 200);
      assert.strictEqual(getBody().data.household, null);
    } finally {
      householdService.leaveHousehold = origLeave;
    }
  });

  // ── [12] POST /api/households/dissolve (Giải tán nhà) ─────
  await t.test('12. dissolveHousehold: Chủ nhà giải tán nhà trả về dissolved: true', async () => {
    const origDissolve = householdService.dissolveHousehold;
    householdService.dissolveHousehold = async () => true;

    const { req, res, getStatus, getBody } = createMockContext();

    try {
      await householdController.dissolveHousehold(req, res);
      assert.strictEqual(getStatus(), 200);
      assert.strictEqual(getBody().data.dissolved, true);
    } finally {
      householdService.dissolveHousehold = origDissolve;
    }
  });

  // ── [13] POST /api/households/invites/email (Mời qua Email)
  await t.test('13. createEmailInvite: Luôn trả về HTTP 202 Accepted chống timing attack dò email', async () => {
    const origSend = householdService.createEmailInvite;
    const expiresAt = new Date(Date.now() + 7 * 86400 * 1000).toISOString();
    householdService.createEmailInvite = async () => ({
      sent: true,
      email: 'member@gmail.com',
      role: 'Member',
      expiresAt,
    });

    const { req, res, getStatus, getBody } = createMockContext({
      body: { email: 'member@gmail.com', role: 'Member' },
    });

    try {
      await householdController.createEmailInvite(req, res);
      assert.strictEqual(getStatus(), 202);
      assert.strictEqual(getBody().success, true);
      assert.strictEqual(getBody().data.sent, true);
      assert.strictEqual(getBody().data.email, 'member@gmail.com');
    } finally {
      householdService.createEmailInvite = origSend;
    }
  });

  // ── [14] GET /api/households/invitations (Lời mời của tôi) ─
  await t.test('14. getMyInvitations: Trả về HTTP 200 danh sách lời mời gửi tới email cá nhân', async () => {
    const origGet = householdService.getMyInvitations;
    householdService.getMyInvitations = async (idaccount, email) => [
      { code: 'MAIL1234', householdName: 'Gia đình Tuấn An', inviterName: 'Tuấn An', role: 'Member' },
    ];

    const { req, res, getStatus, getBody } = createMockContext();

    try {
      await householdController.getMyInvitations(req, res);
      assert.strictEqual(getStatus(), 200);
      assert.strictEqual(getBody().data.length, 1);
      assert.strictEqual(getBody().data[0].code, 'MAIL1234');
    } finally {
      householdService.getMyInvitations = origGet;
    }
  });

  // ── [15] POST /api/households/invitations/:code/accept ────
  await t.test('15. acceptEmailInvitation: Trả về HTTP 200 khi chấp nhận lời mời email', async () => {
    const origAccept = householdService.acceptEmailInvite;
    householdService.acceptEmailInvite = async (idaccount, code) => ({
      household: {
        id: 1,
        name: 'Gia đình Tuấn An',
        status: 'Active',
        maxMembers: 6,
        ownerId: 1,
        createAt: new Date().toISOString(),
        maxSharedWallets: 10,
        contributionDueDay: 5,
      },
      myRole: 'Member',
      members: [],
      formerMembers: [],
    });

    const { req, res, getStatus, getBody } = createMockContext({
      params: { code: 'MAIL1234' },
    });

    try {
      await householdController.acceptEmailInvite(req, res);
      assert.strictEqual(getStatus(), 200);
      assert.strictEqual(getBody().data.myRole, 'Member');
    } finally {
      householdService.acceptEmailInvite = origAccept;
    }
  });

  // ── [16] POST /api/households/invitations/:code/decline ───
  await t.test('16. declineEmailInvitation: Trả về HTTP 200 và declined: true khi từ chối lời mời', async () => {
    const origDecline = householdService.declineEmailInvite;
    householdService.declineEmailInvite = async (idaccount, code) => true;

    const { req, res, getStatus, getBody } = createMockContext({
      params: { code: 'MAIL1234' },
    });

    try {
      await householdController.declineEmailInvite(req, res);
      assert.strictEqual(getStatus(), 200);
      assert.strictEqual(getBody().data.declined, true);
    } finally {
      householdService.declineEmailInvite = origDecline;
    }
  });
});
