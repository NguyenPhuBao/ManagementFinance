const test = require('node:test');
const assert = require('node:assert/strict');

test('Household & AIOps v2 — 2-Tier System Impact & Security Suite (Tasks 57.1, 57.2, 57.4, 58.1, 58.5)', async (t) => {
  const householdService = require('../../modules/household/household.service');
  const householdRepository = require('../../modules/household/household.repository');
  const syncService = require('../../modules/sync/sync.service');
  const syncRepository = require('../../modules/sync/sync.repository');
  const { AIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
  const { prisma } = require('../../config/db');

  const ID_OWNER = 101;
  const ID_MEMBER = 102;
  const ID_VIEWER = 103;
  const ID_STRANGER = 104;

  // ═════════════════════════════════════════════════════════════════════
  // 1. Task 57.1: Single State Shape thống nhất cho các endpoint gia đình
  // ═════════════════════════════════════════════════════════════════════
  await t.test('1. [Task 57.1] getMyHousehold trả về chuẩn Single State Shape { household, myRole, members, formerMembers }', async () => {
    const origFindActiveMember = householdRepository.findActiveMemberByAccount;
    const origFindActiveMembers = householdRepository.findActiveMembersByHousehold;
    const origFindFormerMembers = householdRepository.findFormerMembersByHousehold;

    householdRepository.findActiveMemberByAccount = async (idaccount) => {
      if (idaccount === ID_OWNER) {
        return {
          idhousehold: 99,
          role: 'Owner',
          household: {
            idhousehold: 99,
            name: 'Gia đình Hạnh Phúc',
            status: 'Active',
            max_members: 6,
            max_shared_wallets: 10,
            contribution_due_day: 5,
            owner_idaccount: ID_OWNER,
            create_at: new Date('2026-10-01T00:00:00Z'),
          },
        };
      }
      return null;
    };

    householdRepository.findActiveMembersByHousehold = async () => [
      {
        idaccount: ID_OWNER,
        role: 'Owner',
        joined_at: new Date('2026-10-01T00:00:00Z'),
        account: {
          idaccount: ID_OWNER,
          username: 'owner_user',
          email: 'owner@flowmoney.vn',
          User: { fullname: 'Chủ Hộ Gia Đình' },
        },
      },
      {
        idaccount: ID_MEMBER,
        role: 'Member',
        joined_at: new Date('2026-10-05T00:00:00Z'),
        account: {
          idaccount: ID_MEMBER,
          username: 'member_user',
          email: 'member@flowmoney.vn',
          User: { fullname: 'Thành Viên Con' },
        },
      },
    ];

    householdRepository.findFormerMembersByHousehold = async () => [
      {
        idaccount: 199,
        role: 'Member',
        joined_at: new Date('2026-10-02T00:00:00Z'),
        left_at: new Date('2026-10-04T00:00:00Z'),
        account: {
          idaccount: 199,
          username: 'former_user',
          User: { fullname: 'Người Đã Rời Đi' },
        },
      },
    ];

    try {
      // Khi đã vào gia đình
      const state = await householdService.getMyHousehold(ID_OWNER);
      assert.ok(state.household);
      assert.strictEqual(state.household.id, 99);
      assert.strictEqual(state.household.name, 'Gia đình Hạnh Phúc');
      assert.strictEqual(state.household.maxMembers, 6);
      assert.strictEqual(state.household.maxSharedWallets, 10);
      assert.strictEqual(state.household.contributionDueDay, 5);
      assert.strictEqual(state.myRole, 'Owner');
      assert.strictEqual(state.members.length, 2);
      assert.strictEqual(state.formerMembers.length, 1);

      // Bảo vệ Data_Security: Không được trả về email người khác trong danh sách members
      assert.strictEqual(state.members[0].email, undefined);
      assert.strictEqual(state.members[0].displayName, 'Chủ Hộ Gia Đình');
      assert.strictEqual(state.members[1].displayName, 'Thành Viên Con');

      // Khi chưa vào gia đình
      const emptyState = await householdService.getMyHousehold(ID_STRANGER);
      assert.strictEqual(emptyState.household, null);
      assert.strictEqual(emptyState.myRole, null);
      assert.deepStrictEqual(emptyState.members, []);
      assert.deepStrictEqual(emptyState.formerMembers, []);
    } finally {
      householdRepository.findActiveMemberByAccount = origFindActiveMember;
      householdRepository.findActiveMembersByHousehold = origFindActiveMembers;
      householdRepository.findFormerMembersByHousehold = origFindFormerMembers;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // 2. Task 57.2: Preview & Join đối chiếu Caller Email truy vấn từ CSDL
  // ═════════════════════════════════════════════════════════════════════
  await t.test('2. [Task 57.2] previewInvite & joinByCode tra cứu Caller Email từ CSDL và chặn khi gửi cho email khác', async () => {
    const origFindInvite = householdRepository.findInviteByCode;
    const origFindAccount = prisma.account.findUnique;

    householdRepository.findInviteByCode = async (code) => {
      if (code === 'INVITE_TARGETED') {
        return {
          code: 'INVITE_TARGETED',
          idhousehold: 99,
          role: 'Member',
          email: 'recipient@flowmoney.vn',
          expires_at: new Date(Date.now() + 86400000),
          household: { status: 'Active', delete_at: null, name: 'Tổ Ấm' },
          creator: { username: 'chu_nha', User: { fullname: 'Chủ Nhà' } },
        };
      }
      return null;
    };

    // Caller có email khác với lời mời
    prisma.account.findUnique = async ({ where }) => {
      if (where.idaccount === ID_STRANGER) {
        return {
          idaccount: ID_STRANGER,
          email: 'stranger@flowmoney.vn',
        };
      }
      return null;
    };

    try {
      // previewInvite bị chặn
      await assert.rejects(
        async () => {
          await householdService.previewInvite({ idaccount: ID_STRANGER }, 'INVITE_TARGETED');
        },
        (err) => {
          assert.strictEqual(err.code, 'HOUSEHOLD_INVITE_WRONG_ACCOUNT');
          return true;
        }
      );

      // joinByCode bị chặn
      await assert.rejects(
        async () => {
          await householdService.joinByCode(ID_STRANGER, 'INVITE_TARGETED');
        },
        (err) => {
          assert.strictEqual(err.code, 'HOUSEHOLD_INVITE_WRONG_ACCOUNT');
          return true;
        }
      );
    } finally {
      householdRepository.findInviteByCode = origFindInvite;
      prisma.account.findUnique = origFindAccount;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // 3. Task 58.1: Sync chặn Member sửa ví chung hoặc tạo tx chuyển tiền
  // ═════════════════════════════════════════════════════════════════════
  await t.test('3. [Task 58.1] Member không được tạo hoặc sửa transaction transfer giữa 2 ví chung', async () => {
    const origFindHouse = householdRepository.findHouseholdAnyStatus;
    const origFindMember = householdRepository.findMember;
    const origFindUniqueAccount = prisma.account.findUnique;
    const origFindUniqueWallet = prisma.wallet.findUnique;

    householdRepository.findHouseholdAnyStatus = async (idhousehold) => ({
      idhousehold: Number(idhousehold),
      status: 'Active',
      owner_idaccount: ID_OWNER,
    });

    householdRepository.findMember = async (idhousehold, idaccount) => {
      if (Number(idaccount) === ID_MEMBER) {
        return { idhousehold: Number(idhousehold), idaccount: ID_MEMBER, role: 'Member', household: { status: 'Active' } };
      }
      return null;
    };

    prisma.account.findUnique = async ({ where }) => {
      if (where.idaccount === ID_OWNER) {
        return {
          idaccount: ID_OWNER,
          type: 'Premium',
          premium_expires_at: new Date(Date.now() + 864000000),
        };
      }
      return null;
    };

    // Ví W1 và W2 đều là ví chung gia đình 99
    prisma.wallet.findUnique = async ({ where }) => {
      return {
        idwallet: where.idwallet,
        idhousehold: 99,
        idaccount: ID_OWNER,
        delete_at: null,
      };
    };

    try {
      await assert.rejects(
        async () => {
          await syncService.enforceHouseholdPermission({
            entity: 'transaction',
            operation: 'create',
            payload: {
              idtran: '00000000-0000-4000-8000-000000000001',
              idaccount: ID_MEMBER,
              idhousehold: 99,
              idwallet: '11111111-1111-4111-8111-111111111111',
              to_idwallet: '22222222-2222-4222-8222-222222222222',
              type: 'Transfer',
              amount: 500000,
            },
            idaccount: ID_MEMBER,
            targetHhId: 99,
          });
        },
        (err) => {
          assert.strictEqual(err.code, 'HOUSEHOLD_ROLE_FORBIDDEN');
          return true;
        }
      );
    } finally {
      householdRepository.findHouseholdAnyStatus = origFindHouse;
      householdRepository.findMember = origFindMember;
      prisma.account.findUnique = origFindUniqueAccount;
      prisma.wallet.findUnique = origFindUniqueWallet;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // 4. Task 57.4: Sync chấp nhận record gia đình khi idaccount là creator gốc
  // ═════════════════════════════════════════════════════════════════════
  await t.test('4. [Task 57.4] Record gia đình bỏ qua check lệch token sở hữu cá nhân và ủy quyền cho enforceHouseholdPermission', async () => {
    let enforced = false;
    const origEnforce = syncService.enforceHouseholdPermission;
    syncService.enforceHouseholdPermission = async () => {
      enforced = true;
      return true;
    };

    // Hàng ĐÃ CÓ trên server: nếu không giả, ca này rơi vào nhánh hàng mới và không chứng minh gì
    const origGetTx = syncRepository.getTransactionById;
    syncRepository.getTransactionById = async () => ({
      idtran: '00000000-0000-4000-8000-000000000001',
      idaccount: ID_OWNER,
      idhousehold: 99,
    });

    const origUpsertTx = syncRepository.upsertTransaction;
    syncRepository.upsertTransaction = async (data, idaccount) => {
      // Bảo toàn idaccount của người tạo gốc
      assert.strictEqual(data.idaccount, ID_OWNER);
      return { ...data, server_update_at: new Date() };
    };

    try {
      // Member ID_MEMBER push bản ghi giao dịch gia đình được tạo bởi ID_OWNER
      const res = await syncService.processPush(ID_MEMBER, [
        {
          entity: 'transaction',
          operation: 'update',
          id: '00000000-0000-4000-8000-000000000001',
          clientUpdatedAt: new Date().toISOString(),
          payload: {
            idtran: '00000000-0000-4000-8000-000000000001',
            idaccount: ID_OWNER, // ID của người tạo ban đầu
            idhousehold: 99,
            idwallet: '11111111-1111-4111-8111-111111111111',
            amount: 250000,
            type: 'Expense',
          },
        },
      ]);

      assert.strictEqual(res.summary.synced, 1);
      assert.strictEqual(enforced, true);

      // Task 59.1: hàng MỚI mang idaccount của người khác bị từ chối, không ghi
      syncRepository.getTransactionById = async () => null;
      const hangMoi = await syncService.processPush(ID_MEMBER, [
        {
          localId: 'hang-moi',
          entity: 'transaction',
          operation: 'update',
          payload: {
            idtran: '00000000-0000-4000-8000-000000000002',
            idaccount: ID_OWNER,
            idhousehold: 99,
            idwallet: '11111111-1111-4111-8111-111111111111',
            amount: 250000,
            type: 'Expense',
          },
        },
      ]);
      assert.strictEqual(hangMoi.results[0].code, 'NOT_OWNER');
    } finally {
      syncService.enforceHouseholdPermission = origEnforce;
      syncRepository.upsertTransaction = origUpsertTx;
      syncRepository.getTransactionById = origGetTx;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // 5. Task 58.5: AIOps Sentinel Auto-Unlock sau 15 phút, bảo vệ Admin Lock
  // ═════════════════════════════════════════════════════════════════════
  await t.test('5. [Task 58.5] AIOps tự động mở khóa tài khoản sau 15 phút, nhưng không can thiệp khóa thủ công của Admin', async () => {
    const aiops = new AIOpsQuarantine({ autoExpire: false });
    const updatedAccountsInDb = [];

    // Mock prisma.account.updateMany
    const origUpdateMany = prisma.account.updateMany;
    prisma.account.updateMany = async ({ where, data }) => {
      updatedAccountsInDb.push({ where, data });
      return { count: 1 };
    };

    try {
      const now = Date.now();
      // 1. Tự động cách ly tài khoản qua Sentinel (15 phút)
      const autoRecord = aiops.quarantinePair({
        ip: '10.0.0.1',
        username: 'victim_user',
        idaccount: 501,
        reason: 'Brute force credential stuffing',
      });

      assert.strictEqual(autoRecord.accountStatus, 'temporary');
      // Thời hạn tài khoản cách ly đúng 15 phút (+- 500ms)
      assert.ok(Math.abs(autoRecord.accountExpiresAt - (now + 15 * 60 * 1000)) <= 500);

      // Kiểm tra DB sync có gắn tiền tố [AIOPS_AUTO_QUARANTINE]
      const lastDbUpdate = updatedAccountsInDb[updatedAccountsInDb.length - 1];
      assert.strictEqual(lastDbUpdate.data.status, 'Inactive');
      assert.ok(lastDbUpdate.data.reason_inactive.startsWith('[AIOPS_AUTO_QUARANTINE]'));

      // 2. Khi chưa hết 15 phút -> isAccountQuarantined trả về true
      const checkBeforeExpire = aiops.isAccountQuarantined(501);
      assert.strictEqual(checkBeforeExpire.quarantined, true);
      assert.strictEqual(checkBeforeExpire.status, 'temporary');

      // 3. Giả lập hết thời gian 15 phút (đã hết hạn)
      autoRecord.accountExpiresAt = now - 1000;

      // Lazy check tự động mở khóa
      const checkAfterExpire = aiops.isAccountQuarantined(501);
      assert.strictEqual(checkAfterExpire.quarantined, false);
      assert.strictEqual(autoRecord.accountStatus, 'unlocked');

      // 4. Kiểm tra điều kiện mở khóa CSDL có bảo vệ không mở khóa tài khoản do Admin khóa thủ công
      const unlockCall = updatedAccountsInDb[updatedAccountsInDb.length - 1];
      assert.strictEqual(unlockCall.data.status, 'Active');
      assert.strictEqual(unlockCall.data.reason_inactive, null);

      const andConditions = unlockCall.where.AND;
      assert.ok(andConditions.some(c => c.status === 'Inactive'));
      // Chỉ mở hàng mang dấu khoá tự động
      const onlyAIOpsCond = andConditions.find(c => c.reason_inactive?.startsWith);
      assert.ok(onlyAIOpsCond);
      assert.strictEqual(onlyAIOpsCond.reason_inactive.startsWith, '[AIOPS_AUTO_QUARANTINE]');
    } finally {
      prisma.account.updateMany = origUpdateMany;
    }
  });
});
