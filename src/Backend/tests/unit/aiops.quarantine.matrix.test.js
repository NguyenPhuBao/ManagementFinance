const test = require('node:test');
const assert = require('node:assert');
const { AIOpsQuarantine, hashIp } = require('../../modules/aiops/aiops.quarantine');

test('AIOps Quarantine Matrix Suite (IP & Account Pairs - 2-Tier Test)', async (t) => {
  // -------------------------------------------------------------
  // TẦNG 1: KHỞI TẠO & CẤU TRÚC BẢN GHI THEO CẶP (IP, TÀI KHOẢN)
  // -------------------------------------------------------------
  await t.test('1. Đăng ký cách ly cặp (IP, Tài khoản) mặc định ở mức Tạm khóa', () => {
    const q = new AIOpsQuarantine({ defaultDurationMs: 15 * 60 * 1000 });
    const record = q.quarantinePair({
      ip: '198.51.100.10',
      username: 'user_target',
      idaccount: 101,
      reason: 'Dò mật khẩu Brute-force lặp lại',
      durationMs: 15 * 60 * 1000,
    });

    assert.ok(record, 'Bản ghi cách ly cặp phải được tạo');
    assert.strictEqual(record.ipStatus, 'temporary', 'IP ban đầu phải ở trạng thái tạm khóa');
    assert.strictEqual(record.accountStatus, 'temporary', 'Tài khoản ban đầu phải ở trạng thái tạm khóa');
    assert.strictEqual(record.username, 'user_target');
    assert.strictEqual(record.idaccount, 101);
    assert.ok(record.maskedIp.includes('xx'), 'IP phải được che mờ theo chuẩn Data_Security.md');

    // Tầng 2: Hệ thống chặn kết nối IP qua Middleware
    const check = q.isQuarantined('198.51.100.10');
    assert.strictEqual(check.quarantined, true, 'IP phải bị chặn');
  });

  // -------------------------------------------------------------
  // TẦNG 2: 1 IP TẤN CÔNG NHIỀU TÀI KHOẢN & ĐỒNG BỘ MỞ/KHÓA IP
  // -------------------------------------------------------------
  await t.test('2. 1 IP liên kết nhiều Tài khoản: Mở khóa IP đồng bộ toàn bộ các dòng có cùng IP', async () => {
    const q = new AIOpsQuarantine();
    const attackerIp = '198.51.100.20';
    const attackerHash = hashIp(attackerIp);

    // Kịch bản: 1 IP tấn công cả tài khoản user1 và user2
    q.quarantinePair({ ip: attackerIp, username: 'user1', reason: 'Tấn công account 1' });
    q.quarantinePair({ ip: attackerIp, username: 'user2', reason: 'Tấn công account 2' });

    let list = q.getQuarantinedList();
    const rowsForIp = list.filter((r) => r.ipHash === attackerHash);
    assert.strictEqual(rowsForIp.length, 2, 'Phải có 2 bản ghi riêng biệt cho 2 cặp (IP, user1) và (IP, user2)');
    assert.strictEqual(rowsForIp[0].ipStatus, 'temporary');
    assert.strictEqual(rowsForIp[1].ipStatus, 'temporary');

    // Thao tác: Admin Mở khóa IP
    const unblockedCount = await q.unblockIp(attackerHash);
    assert.strictEqual(unblockedCount >= 2, true, 'Cả 2 dòng có cùng IP phải được cập nhật mở khóa');

    // Kiểm tra tác động thực tế (Tầng 2 System Impact)
    list = q.getQuarantinedList();
    const updatedRows = list.filter((r) => r.ipHash === attackerHash);
    assert.strictEqual(updatedRows[0].ipStatus, 'unlocked', 'Dòng 1: IP phải chuyển sang unlocked');
    assert.strictEqual(updatedRows[1].ipStatus, 'unlocked', 'Dòng 2: IP phải chuyển sang unlocked');
    // Tuy nhiên tài khoản user1 và user2 vẫn giữ trạng thái của tài khoản
    assert.strictEqual(updatedRows[0].accountStatus, 'temporary');
    assert.strictEqual(updatedRows[1].accountStatus, 'temporary');

    // Middleware cho phép IP này truy cập lại
    const checkIp = q.isQuarantined(attackerIp);
    assert.strictEqual(checkIp.quarantined, false, 'IP đã mở khóa không còn bị chặn');
  });

  await t.test('3. 1 IP liên kết nhiều Tài khoản: Khóa IP (permanentBanIp) chuyển sang tạm khóa 4h và đồng bộ toàn bộ các dòng có cùng IP', async () => {
    const q = new AIOpsQuarantine();
    const attackerIp = '198.51.100.25';
    const attackerHash = hashIp(attackerIp);

    q.quarantinePair({ ip: attackerIp, username: 'user1', reason: 'Tấn công account 1' });
    q.quarantinePair({ ip: attackerIp, username: 'user2', reason: 'Tấn công account 2' });

    // Admin thao tác Khóa IP (chuyển hóa thành tạm khóa 4 giờ theo chính sách PO)
    const count = await q.permanentBanIp(attackerHash);
    assert.strictEqual(count >= 2, true);

    const list = q.getQuarantinedList();
    const updatedRows = list.filter((r) => r.ipHash === attackerHash);
    assert.strictEqual(updatedRows[0].ipStatus, 'temporary', 'Dòng 1: IP chuyển sang temporary (4h)');
    assert.strictEqual(updatedRows[1].ipStatus, 'temporary', 'Dòng 2: IP chuyển sang temporary (4h)');
    assert.ok(updatedRows[0].ipExpiresAt !== null, 'Tạm khóa IP 4h bắt buộc có thời hạn hết hạn');
    assert.ok(updatedRows[0].ipRemainingMinutes > 230 && updatedRows[0].ipRemainingMinutes <= 240, 'Thời gian còn lại xấp xỉ 240 phút');
  });

  // -------------------------------------------------------------
  // TẦNG 2: 1 TÀI KHOẢN BỊ TẤN CÔNG TỪ NHIỀU IP & ĐỒNG BỘ MỞ/KHÓA TÀI KHOẢN
  // -------------------------------------------------------------
  await t.test('4. 1 Tài khoản bị tấn công từ nhiều IP: Mở khóa Tài khoản đồng bộ toàn bộ các dòng có cùng Tài khoản', async () => {
    const q = new AIOpsQuarantine();
    const targetUser = 'victim_finance';

    // Kịch bản: Tài khoản bị tấn công từ 2 IP khác nhau
    q.quarantinePair({ ip: '198.51.100.31', username: targetUser, reason: 'Probe from bot 1' });
    q.quarantinePair({ ip: '198.51.100.32', username: targetUser, reason: 'Probe from bot 2' });

    let list = q.getQuarantinedList();
    const userRows = list.filter((r) => r.username === targetUser);
    assert.strictEqual(userRows.length, 2, 'Phải có 2 dòng tương ứng 2 IP khác nhau');

    // Thao tác: Admin Mở khóa Tài khoản
    const unblockedCount = await q.unblockAccount(targetUser);
    assert.strictEqual(unblockedCount >= 2, true, 'Tất cả các dòng của tài khoản này phải được mở');

    list = q.getQuarantinedList();
    const updatedUserRows = list.filter((r) => r.username === targetUser);
    assert.strictEqual(updatedUserRows[0].accountStatus, 'unlocked', 'Dòng 1: Tài khoản phải chuyển sang unlocked');
    assert.strictEqual(updatedUserRows[1].accountStatus, 'unlocked', 'Dòng 2: Tài khoản phải chuyển sang unlocked');
    assert.strictEqual(updatedUserRows[0].accountExpiresAt, null, 'Mở khóa Tài khoản thì accountExpiresAt là null');
    assert.strictEqual(updatedUserRows[0].accountRemainingMinutes, null, 'Mở khóa Tài khoản thì accountRemainingMinutes là null');
  });

  await t.test('5. 1 Tài khoản bị tấn công từ nhiều IP: Khóa Tài khoản vĩnh viễn đồng bộ toàn bộ các dòng có cùng Tài khoản', async () => {
    const q = new AIOpsQuarantine();
    const targetUser = 'attacker_compromised_account';

    q.quarantinePair({ ip: '198.51.100.41', username: targetUser, reason: 'Bot 1' });
    q.quarantinePair({ ip: '198.51.100.42', username: targetUser, reason: 'Bot 2' });

    // Admin Khóa vĩnh viễn Tài khoản
    const banCount = await q.permanentBanAccount(targetUser);
    assert.strictEqual(banCount >= 2, true);

    const list = q.getQuarantinedList();
    const updatedUserRows = list.filter((r) => r.username === targetUser);
    assert.strictEqual(updatedUserRows[0].accountStatus, 'permanent', 'Dòng 1: Tài khoản phải permanent');
    assert.strictEqual(updatedUserRows[1].accountStatus, 'permanent', 'Dòng 2: Tài khoản phải permanent');
    assert.strictEqual(updatedUserRows[0].accountExpiresAt, null, 'Khóa TK vĩnh viễn thì accountExpiresAt là null');
    assert.strictEqual(updatedUserRows[0].accountRemainingMinutes, null, 'Khóa TK vĩnh viễn thì accountRemainingMinutes là null');
  });

  // -------------------------------------------------------------
  // TẦNG 2: PHÂN TÁCH ĐỘC LẬP THỜI GIAN CÒN LẠI IP & TÀI KHOẢN (REQUIREMENT PO)
  // -------------------------------------------------------------
  await t.test('6. Tách riêng thời gian còn lại: Mở/Phong tỏa đối tượng nào thì triệt tiêu thời gian của đối tượng đó', async () => {
    const q = new AIOpsQuarantine({ defaultDurationMs: 4 * 60 * 60 * 1000 });
    const ip = '198.51.100.99';
    const username = 'test_user_time';
    const hash = hashIp(ip);

    // Ban đầu cả IP và TK đều tạm khóa 4 giờ
    q.quarantinePair({ ip, username, reason: 'Test tách thời gian' });

    let list = q.getQuarantinedList();
    let row = list.find((r) => r.ipHash === hash);
    assert.ok(row.ipRemainingMinutes > 0, 'IP ban đầu phải có ipRemainingMinutes');
    assert.ok(row.accountRemainingMinutes > 0, 'TK ban đầu phải có accountRemainingMinutes');

    // Trường hợp 1: Admin Mở khóa IP -> Thời gian IP không còn, thời gian TK vẫn còn
    await q.unblockIp(hash);
    list = q.getQuarantinedList();
    row = list.find((r) => r.ipHash === hash);
    assert.strictEqual(row.ipStatus, 'unlocked');
    assert.strictEqual(row.ipRemainingMinutes, null, 'IP mở khóa thì không còn thời gian còn lại');
    assert.strictEqual(row.ipExpiresAt, null);
    assert.strictEqual(row.accountStatus, 'temporary');
    assert.ok(row.accountRemainingMinutes > 0, 'TK vẫn tạm khóa thì phải bảo toàn thời gian còn lại');

    // Trường hợp 2: Admin Phong tỏa TK vĩnh viễn -> Thời gian TK cũng không còn
    await q.permanentBanAccount(username);
    list = q.getQuarantinedList();
    row = list.find((r) => r.ipHash === hash);
    assert.strictEqual(row.accountStatus, 'permanent');
    assert.strictEqual(row.accountRemainingMinutes, null, 'TK phong tỏa vĩnh viễn không còn thời gian còn lại');
    assert.strictEqual(row.accountExpiresAt, null);
    assert.strictEqual(row.ipRemainingMinutes, null, 'IP đã mở khóa vẫn là null');
  });

  // -------------------------------------------------------------
  // TẦNG 2: TỰ ĐỘNG MỞ KHÓA KHI HẾT HẠN ĐẾM NGƯỢC (AUTO-EXPIRE REQUIREMENT)
  // -------------------------------------------------------------
  await t.test('7. Tự động mở khóa khi hết hạn đếm ngược: sweepExpiredQuarantines chuyển UNLOCKED và xóa thời gian còn lại', async () => {
    const q = new AIOpsQuarantine({ defaultDurationMs: 1000 });
    const ip = '198.51.100.222';
    const username = 'auto_expire_user';
    const hash = hashIp(ip);

    // Cách ly 1 giây
    q.quarantinePair({ ip, username, reason: 'Test auto expire', durationMs: 50 });

    // Cố ý set thời gian hết hạn về quá khứ
    const pair = q._pairs.get(`${hash}:::${username}`);
    assert.ok(pair);
    pair.ipExpiresAt = Date.now() - 1000;
    pair.accountExpiresAt = Date.now() - 1000;

    // Kích hoạt quét tự động hết hạn
    const hasChanged = await q.sweepExpiredQuarantines();
    assert.strictEqual(hasChanged, true, 'Phải ghi nhận có thay đổi giải phóng');

    // Kiểm tra danh sách hiển thị
    const list = q.getQuarantinedList();
    const row = list.find((r) => r.ipHash === hash);
    assert.strictEqual(row.ipStatus, 'unlocked', 'IP phải tự động mở khóa');
    assert.strictEqual(row.accountStatus, 'unlocked', 'TK phải tự động mở khóa');
    assert.strictEqual(row.ipRemainingMinutes, null, 'Thời gian IP còn lại phải là null');
    assert.strictEqual(row.accountRemainingMinutes, null, 'Thời gian TK còn lại phải là null');
    assert.strictEqual(row.ipExpiresAt, null);
    assert.strictEqual(row.accountExpiresAt, null);

    // Kiểm tra middleware: IP không còn bị chặn nữa
    const check = q.isQuarantined(ip);
    assert.strictEqual(check.quarantined, false, 'IP không còn bị chặn O(1)');
  });
});
