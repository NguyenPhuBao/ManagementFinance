const test = require('node:test');
const assert = require('node:assert/strict');

test('Household Group 1 Completion — 2-Tier Verification Suite (Tasks 57.6, 58.3, 57.7, 57.8)', async (t) => {
  const householdService = require('../../modules/household/household.service');
  const householdRepository = require('../../modules/household/household.repository');
  const { prisma } = require('../../config/db');

  const ID_OWNER = 201;
  const ID_MEMBER = 202;
  const ID_VIEWER = 203;
  const ID_STRANGER = 204;
  const ID_HOUSEHOLD = 88;

  // ═════════════════════════════════════════════════════════════════════
  // 1. Task 57.6: Xóa mềm 5 bảng dữ liệu chung & Thu hồi mã mời
  // ═════════════════════════════════════════════════════════════════════
  await t.test('1. [Tier 2 - Task 57.6] dissolveHousehold xóa mềm toàn bộ 5 bảng thực thể chung và thu hồi mã mời pending', async () => {
    let transactionOperations = [];
    const origTransaction = prisma.$transaction;

    prisma.$transaction = async (ops) => {
      transactionOperations = ops;
      return ops;
    };

    // Mock Prisma updateMany and update
    const origHouseholdUpdate = prisma.household.update;
    const origMemberUpdateMany = prisma.household_member.updateMany;
    const origInviteUpdateMany = prisma.household_invite.updateMany;
    const origWalletUpdateMany = prisma.wallet.updateMany;
    const origTxUpdateMany = prisma.transaction.updateMany;
    const origBudgetUpdateMany = prisma.budget.updateMany;
    const origGoalUpdateMany = prisma.goal.updateMany;
    const origCategoryUpdateMany = prisma.category.updateMany;

    let updatedHousehold = null;
    let updatedMember = null;
    let updatedInvite = null;
    let updatedWallet = null;
    let updatedTx = null;
    let updatedBudget = null;
    let updatedGoal = null;
    let updatedCategory = null;

    prisma.household.update = (args) => { updatedHousehold = args; return args; };
    prisma.household_member.updateMany = (args) => { updatedMember = args; return { count: 2 }; };
    prisma.household_invite.updateMany = (args) => { updatedInvite = args; return { count: 3 }; };
    prisma.wallet.updateMany = (args) => { updatedWallet = args; return { count: 2 }; };
    prisma.transaction.updateMany = (args) => { updatedTx = args; return { count: 5 }; };
    prisma.budget.updateMany = (args) => { updatedBudget = args; return { count: 1 }; };
    prisma.goal.updateMany = (args) => { updatedGoal = args; return { count: 1 }; };
    prisma.category.updateMany = (args) => { updatedCategory = args; return { count: 4 }; };

    try {
      await householdRepository.dissolveHousehold(ID_HOUSEHOLD);

      // Thẩm tra: Phải được thực thi trong 1 transaction duy nhất gồm 8 operations
      assert.strictEqual(transactionOperations.length, 8);

      // 1. household: status Dissolved + delete_at
      assert.strictEqual(updatedHousehold.where.idhousehold, ID_HOUSEHOLD);
      assert.strictEqual(updatedHousehold.data.status, 'Dissolved');
      assert.ok(updatedHousehold.data.delete_at);
      assert.ok(updatedHousehold.data.update_at);

      // 2. household_member: left_at
      assert.strictEqual(updatedMember.where.idhousehold, ID_HOUSEHOLD);
      assert.strictEqual(updatedMember.where.left_at, null);
      assert.ok(updatedMember.data.left_at);

      // 3. household_invite: revoked_at
      assert.strictEqual(updatedInvite.where.idhousehold, ID_HOUSEHOLD);
      assert.strictEqual(updatedInvite.where.used_at, null);
      assert.strictEqual(updatedInvite.where.revoked_at, null);
      assert.strictEqual(updatedInvite.where.declined_at, null);
      assert.ok(updatedInvite.data.revoked_at);

      // 4-8. 5 bảng thực thể chung mang idhousehold đều có delete_at và update_at
      assert.strictEqual(updatedWallet.where.idhousehold, ID_HOUSEHOLD);
      assert.ok(updatedWallet.data.delete_at);
      assert.ok(updatedWallet.data.update_at);

      assert.strictEqual(updatedTx.where.idhousehold, ID_HOUSEHOLD);
      assert.ok(updatedTx.data.delete_at);
      assert.ok(updatedTx.data.update_at);

      assert.strictEqual(updatedBudget.where.idhousehold, ID_HOUSEHOLD);
      assert.ok(updatedBudget.data.delete_at);
      assert.ok(updatedBudget.data.update_at);

      assert.strictEqual(updatedGoal.where.idhousehold, ID_HOUSEHOLD);
      assert.ok(updatedGoal.data.delete_at);
      assert.ok(updatedGoal.data.update_at);

      assert.strictEqual(updatedCategory.where.idhousehold, ID_HOUSEHOLD);
      assert.ok(updatedCategory.data.delete_at);
      assert.ok(updatedCategory.data.update_at);
    } finally {
      prisma.$transaction = origTransaction;
      prisma.household.update = origHouseholdUpdate;
      prisma.household_member.updateMany = origMemberUpdateMany;
      prisma.household_invite.updateMany = origInviteUpdateMany;
      prisma.wallet.updateMany = origWalletUpdateMany;
      prisma.transaction.updateMany = origTxUpdateMany;
      prisma.budget.updateMany = origBudgetUpdateMany;
      prisma.goal.updateMany = origGoalUpdateMany;
      prisma.category.updateMany = origCategoryUpdateMany;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // 2. Task 58.3: Socket HOUSEHOLD_DISSOLVED phát tới tất cả thành viên
  // ═════════════════════════════════════════════════════════════════════
  await t.test('2. [Tier 2 - Task 58.3] dissolveHousehold lấy danh sách thành viên trước khi gắn left_at và phát socket tới từng phòng tài khoản', async () => {
    const origFindActiveMember = householdRepository.findActiveMemberByAccount;
    const origFindActiveMembers = householdRepository.findActiveMembersByHousehold;
    const origDissolve = householdRepository.dissolveHousehold;
    const origEmit = householdService.emitHouseholdChanged;

    householdRepository.findActiveMemberByAccount = async (idaccount) => ({
      idhousehold: ID_HOUSEHOLD,
      idaccount: ID_OWNER,
      role: 'Owner',
    });

    householdRepository.findActiveMembersByHousehold = async (idhousehold) => [
      { idaccount: ID_OWNER, role: 'Owner' },
      { idaccount: ID_MEMBER, role: 'Member' },
      { idaccount: ID_VIEWER, role: 'Viewer' },
    ];

    householdRepository.dissolveHousehold = async () => true;

    let emittedEvent = null;
    let extraRecipientsReceived = null;

    householdService.emitHouseholdChanged = async (idhousehold, evt, payload, extraRecipients) => {
      emittedEvent = { idhousehold, evt, payload };
      extraRecipientsReceived = extraRecipients;
    };

    try {
      const res = await householdService.dissolveHousehold(ID_OWNER);
      assert.strictEqual(res, true);

      // Thẩm tra Socket:
      assert.ok(emittedEvent);
      assert.strictEqual(emittedEvent.evt, 'HOUSEHOLD_DISSOLVED');
      assert.strictEqual(emittedEvent.payload.dissolvedBy, ID_OWNER);

      // extraRecipients phải bao gồm đầy đủ cả 3 thành viên: ID_OWNER, ID_MEMBER, ID_VIEWER
      assert.ok(Array.isArray(extraRecipientsReceived));
      assert.strictEqual(extraRecipientsReceived.length, 3);
      assert.ok(extraRecipientsReceived.includes(ID_OWNER));
      assert.ok(extraRecipientsReceived.includes(ID_MEMBER));
      assert.ok(extraRecipientsReceived.includes(ID_VIEWER));
    } finally {
      householdRepository.findActiveMemberByAccount = origFindActiveMember;
      householdRepository.findActiveMembersByHousehold = origFindActiveMembers;
      householdRepository.dissolveHousehold = origDissolve;
      householdService.emitHouseholdChanged = origEmit;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // 3. Task 57.7: Chuẩn hóa ma trận mã lỗi HTTP (410 Expired, 409 Declined, 404 Invalid)
  // ═════════════════════════════════════════════════════════════════════
  await t.test('3. [Tier 1 & 2 - Task 57.7] previewInvite & joinByCode ném đúng mã lỗi chuẩn RESTful', async () => {
    const origFindInvite = householdRepository.findInviteByCode;
    const origFindMember = householdRepository.findActiveMemberByAccount;

    householdRepository.findActiveMemberByAccount = async () => null;

    try {
      // 3.1. Mã mời hết hạn -> ném HTTP 410 HOUSEHOLD_INVITE_EXPIRED
      householdRepository.findInviteByCode = async () => ({
        code: 'EXPIRED1',
        idhousehold: ID_HOUSEHOLD,
        expires_at: new Date(Date.now() - 3600000), // đã hết hạn 1h trước
        household: { status: 'Active', delete_at: null },
      });

      await assert.rejects(
        async () => { await householdService.previewInvite({ idaccount: ID_STRANGER }, 'EXPIRED1'); },
        (err) => {
          assert.strictEqual(err.statusCode, 410);
          assert.strictEqual(err.code, 'HOUSEHOLD_INVITE_EXPIRED');
          return true;
        }
      );

      await assert.rejects(
        async () => { await householdService.joinByCode(ID_STRANGER, 'EXPIRED1'); },
        (err) => {
          assert.strictEqual(err.statusCode, 410);
          assert.strictEqual(err.code, 'HOUSEHOLD_INVITE_EXPIRED');
          return true;
        }
      );

      // 3.2. Lời mời đã bị từ chối -> ném HTTP 409 HOUSEHOLD_INVITE_DECLINED
      householdRepository.findInviteByCode = async () => ({
        code: 'DECLINED',
        idhousehold: ID_HOUSEHOLD,
        declined_at: new Date('2026-10-25T10:00:00Z'),
        expires_at: new Date(Date.now() + 86400000),
        household: { status: 'Active', delete_at: null },
      });

      await assert.rejects(
        async () => { await householdService.previewInvite({ idaccount: ID_STRANGER }, 'DECLINED'); },
        (err) => {
          assert.strictEqual(err.statusCode, 409);
          assert.strictEqual(err.code, 'HOUSEHOLD_INVITE_DECLINED');
          return true;
        }
      );

      await assert.rejects(
        async () => { await householdService.joinByCode(ID_STRANGER, 'DECLINED'); },
        (err) => {
          assert.strictEqual(err.statusCode, 409);
          assert.strictEqual(err.code, 'HOUSEHOLD_INVITE_DECLINED');
          return true;
        }
      );

      // 3.3. Nhà đã giải tán hoặc không tồn tại -> ném HTTP 404 HOUSEHOLD_INVITE_INVALID
      householdRepository.findInviteByCode = async () => ({
        code: 'DISSOLVE',
        idhousehold: ID_HOUSEHOLD,
        expires_at: new Date(Date.now() + 86400000),
        household: { status: 'Dissolved', delete_at: new Date() },
      });

      await assert.rejects(
        async () => { await householdService.previewInvite({ idaccount: ID_STRANGER }, 'DISSOLVE'); },
        (err) => {
          assert.strictEqual(err.statusCode, 404);
          assert.strictEqual(err.code, 'HOUSEHOLD_INVITE_INVALID');
          return true;
        }
      );
    } finally {
      householdRepository.findInviteByCode = origFindInvite;
      householdRepository.findActiveMemberByAccount = origFindMember;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // 4. Task 57.8: Hoàn thiện các tình huống biên API nhà
  // ═════════════════════════════════════════════════════════════════════
  await t.test('4. [Tier 2 - Task 57.8 #1] createEmailInvite cho người đã là thành viên trả HTTP 202 và không chiếm quota', async () => {
    const origFindActiveMember = householdRepository.findActiveMemberByAccount;
    const origFindActiveMembers = householdRepository.findActiveMembersByHousehold;
    const origCountActiveMembers = householdRepository.countActiveMembers;
    const origCountActiveInvites = householdRepository.countActiveInvites;

    householdRepository.findActiveMemberByAccount = async () => ({
      idhousehold: ID_HOUSEHOLD,
      role: 'Owner',
      household: { status: 'Active', max_members: 6 },
    });

    // Nhà đã có thành viên member@flowmoney.vn
    householdRepository.findActiveMembersByHousehold = async () => [
      { idaccount: ID_OWNER, role: 'Owner', account: { email: 'owner@flowmoney.vn' } },
      { idaccount: ID_MEMBER, role: 'Member', account: { email: 'member@flowmoney.vn' } },
    ];

    // Giả lập nhà ĐÃ ĐẦY (6 thành viên)
    householdRepository.countActiveMembers = async () => 6;
    householdRepository.countActiveInvites = async () => 0;

    try {
      // Mời người đã là thành viên: Vẫn trả 202 sent: true, không bị chặn bởi HOUSEHOLD_FULL
      const res = await householdService.createEmailInvite(ID_OWNER, {
        email: 'member@flowmoney.vn',
        role: 'Member',
      });

      assert.strictEqual(res.sent, true);
      assert.strictEqual(res.email, 'member@flowmoney.vn');
    } finally {
      householdRepository.findActiveMemberByAccount = origFindActiveMember;
      householdRepository.findActiveMembersByHousehold = origFindActiveMembers;
      householdRepository.countActiveMembers = origCountActiveMembers;
      householdRepository.countActiveInvites = origCountActiveInvites;
    }
  });

  await t.test('4b. [Tier 2 - Task 57.8 #3] Atomic Update trong joinByCode ngăn chặn race-condition 2 người dùng chung 1 mã mời', async () => {
    const origFindMember = householdRepository.findActiveMemberByAccount;
    const origFindInvite = householdRepository.findInviteByCode;
    const origCount = householdRepository.countActiveMembers;
    const origTransaction = prisma.$transaction;

    householdRepository.findActiveMemberByAccount = async () => null;
    householdRepository.findInviteByCode = async () => ({
      code: 'SINGLE_USE',
      idhousehold: ID_HOUSEHOLD,
      role: 'Member',
      expires_at: new Date(Date.now() + 86400000),
      household: { status: 'Active', delete_at: null, max_members: 6 },
    });
    householdRepository.countActiveMembers = async () => 1;

    // Giả lập request thứ 2 đến khi mã vừa bị dùng xong (updateMany trả về count: 0)
    prisma.$transaction = async (fn) => {
      const mockTx = {
        household_invite: {
          updateMany: async () => ({ count: 0 }), // 0 bản ghi được update vì đã bị dùng
        },
      };
      return fn(mockTx);
    };

    try {
      await assert.rejects(
        async () => { await householdService.joinByCode(ID_STRANGER, 'SINGLE_USE'); },
        (err) => {
          assert.strictEqual(err.statusCode, 409);
          assert.strictEqual(err.code, 'HOUSEHOLD_INVITE_USED');
          return true;
        }
      );
    } finally {
      householdRepository.findActiveMemberByAccount = origFindMember;
      householdRepository.findInviteByCode = origFindInvite;
      householdRepository.countActiveMembers = origCount;
      prisma.$transaction = origTransaction;
    }
  });

  await t.test('4c. [Tier 1 & 2 - Task 57.8 #7] createEmailInvite validate email dài quá 100 ký tự ném 400 INVALID_EMAIL', async () => {
    const longEmail = 'a'.repeat(95) + '@flowmoney.vn'; // 109 ký tự

    await assert.rejects(
      async () => { await householdService.createEmailInvite(ID_OWNER, { email: longEmail }); },
      (err) => {
        assert.strictEqual(err.statusCode, 400);
        assert.strictEqual(err.code, 'INVALID_EMAIL');
        return true;
      }
    );
  });
});

