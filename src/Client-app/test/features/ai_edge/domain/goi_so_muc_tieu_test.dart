/// Gói số Mục tiêu: số từ `GoalEntity` (`progress`, `remainingAmount`,
/// `daysLeft`, `isBehindSchedule`) — kỳ vọng tính bằng chính các getter ấy.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so_muc_tieu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flutter_test/flutter_test.dart';

GoalEntity _mt({
  String id = 'g1',
  String ten = 'Mua xe',
  double target = 50000000,
  double current = 22500000,
  DateTime? start,
  DateTime? den,
  bool xong = false,
  /// `false` để truyền `startDate: null` thật — mục tiêu do bản app cũ tạo.
  bool moc = true,
}) =>
    GoalEntity(
      id: id,
      idaccount: 7,
      name: ten,
      targetAmount: target,
      currentAmount: current,
      startDate: moc ? (start ?? DateTime(2026, 1, 1)) : null,
      targetDate: den ?? DateTime(2027, 1, 20),
      isCompleted: xong,
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  // 22/09/2026 → còn 120 ngày tới 20/01/2027; đã qua 264/384 ngày (68,75 %)
  // mà tiền mới 45 % → chậm kế hoạch. Khớp màn Stitch.
  final now = DateTime(2026, 9, 22);

  test('không mục tiêu đang theo đuổi → thiếu dữ liệu', () {
    final nx = GoiSoMucTieu.tu(const [], now: now).mauCau();
    expect(nx.muc, MucNhanXet.thieuDuLieu);
    expect(nx.cau, 'Chưa có mục tiêu nào đang theo đuổi.');
    expect(nx.theSoLieu, isEmpty);
    final chiXong = GoiSoMucTieu.tu([_mt(xong: true)], now: now);
    expect(chiXong.thieuDuLieu, isTrue,
        reason: 'mục tiêu đã hoàn thành không phải "đang theo đuổi"');
  });

  test('chậm kế hoạch: tiến độ, còn thiếu, còn N ngày; chậm kế hoạch', () {
    final g = _mt();
    final goi = GoiSoMucTieu.tu([g], now: now);
    final nx = goi.mauCau();
    expect(g.isBehindSchedule(now), isTrue);
    expect(nx.muc, MucNhanXet.canhBao);
    // Vế cuối thêm 2026-09-21 (chặng 1.4): `duBaoHoanThanh` nói mục tiêu này
    // cần **323 ngày** nữa theo nhịp thật, trong khi hạn chỉ còn 120 — đó mới
    // là thứ "chậm kế hoạch" thực sự có nghĩa là gì.
    expect(
        nx.cau,
        'Mua xe: 45,0%, còn thiếu 27.500.000 đ, còn ${g.daysLeft(now)} ngày; '
        'chậm kế hoạch. Theo nhịp hiện tại cần thêm 323 ngày.');
    expect(goi.man, 'muc_tieu');
    expect(nx.theSoLieu.map((s) => s.nhan).toList(),
        ['Tiến độ', 'Còn thiếu', 'Còn', 'Theo nhịp hiện tại']);
  });

  test('đúng kế hoạch → bình thường, câu nói "đúng kế hoạch"', () {
    final g = _mt(current: 40000000);
    final nx = GoiSoMucTieu.tu([g], now: now).mauCau();
    expect(g.isBehindSchedule(now), isFalse);
    expect(nx.muc, MucNhanXet.binhThuong);
    expect(nx.cau, endsWith('; đúng kế hoạch.'));
  });

  test('quá hạn (daysLeft âm) → không in vế còn ngày, câu "đã quá hạn"', () {
    final g = _mt(den: DateTime(2026, 9, 1));
    final nx = GoiSoMucTieu.tu([g], now: now).mauCau();
    expect(nx.cau, isNot(contains('còn -')));
    // ⚠️ Kỳ vọng cũ là `isNot(contains(' ngày'))` — một phép đo GIÁN TIẾP, và
    // nó hết đúng từ chặng 1.4: câu nay kết thúc bằng "cần thêm 323 ngày",
    // một con số khác hẳn về nghĩa. Ý định thật của ca này là *không in vế
    // "còn N ngày"*, nên nay đòi đúng điều ấy.
    expect(nx.cau, isNot(matches(RegExp(r'còn -?\d+ ngày'))));
    expect(nx.cau, contains('; đã quá hạn.'));
    expect(nx.muc, MucNhanXet.canhBao);
    expect(nx.theSoLieu.map((s) => s.nhan), isNot(contains('Còn')));
  });

  test('nhiều mục tiêu → lấy phần tử ĐẦU của danh sách đang theo đuổi', () {
    final a = _mt(id: 'a', ten: 'Đi Nhật');
    final b = _mt(id: 'b', ten: 'Mua xe');
    expect(GoiSoMucTieu.tu([_mt(id: 'z', xong: true), a, b], now: now).ten,
        'Đi Nhật');
  });

  test('mẫu câu tự qua bộ kiểm số ở mọi nhánh', () {
    for (final ds in [
      [_mt()],
      [_mt(current: 40000000)],
      [_mt(den: DateTime(2026, 9, 1))],
      [_mt(target: 1234567, current: 111111)],
      <GoalEntity>[],
    ]) {
      final g = GoiSoMucTieu.tu(ds, now: now);
      expect(kiemSo(g.mauCau().cau, g), isTrue, reason: g.mauCau().cau);
    }
  });

  // ── Dự báo theo nhịp thật (chặng 1.4) ───────────────────────────────────
  //
  // `duBaoHoanThanh` đã tính sẵn từ lâu mà **không có một chỗ gọi nào** trong
  // `lib/`. Nó khác `isBehindSchedule` ở chỗ trả lời *chậm bao nhiêu*, chứ
  // không chỉ *có chậm không*.
  group('dự báo theo nhịp hiện tại', () {
    test('chậm kế hoạch: thêm thẻ số liệu và một vế trong câu', () {
      final goi = GoiSoMucTieu.tu([_mt()], now: now);
      final s = {for (final x in goi.soLieu) x.nhan: x.soTho};
      expect(s['Theo nhịp hiện tại'], 323);
      expect(goi.mauCau().cau, contains('Theo nhịp hiện tại cần thêm'));
    });

    test('ĐÚNG kế hoạch thì im — vế ấy chỉ là tiếng ồn', () {
      // 40/50 triệu ở mốc 68,75 % thời gian → vượt kế hoạch.
      final goi = GoiSoMucTieu.tu([_mt(current: 40000000)], now: now);
      expect(goi.mauCau().cau, isNot(contains('Theo nhịp hiện tại')));
      expect(goi.soLieu.map((e) => e.nhan),
          isNot(contains('Theo nhịp hiện tại')),
          reason: 'không dựng thẻ cho con số câu không nhắc tới');
    });

    test('thiếu mốc gốc → im, KHÔNG đoán một ngày nào', () {
      // Mục tiêu do bản app cũ tạo không có `startDate`.
      final goi = GoiSoMucTieu.tu([_mt(start: null, moc: false)], now: now);
      expect(goi.soLieu.map((e) => e.nhan),
          isNot(contains('Theo nhịp hiện tại')));
      expect(goi.mauCau().cau, isNot(contains('Theo nhịp hiện tại')));
    });

    test('chưa tích đồng nào → im (tốc độ 0 cho ngày ở vô cực)', () {
      final goi = GoiSoMucTieu.tu([_mt(current: 0)], now: now);
      expect(goi.soLieu.map((e) => e.nhan),
          isNot(contains('Theo nhịp hiện tại')));
    });

    test('mẫu câu có vế dự báo vẫn tự qua bộ kiểm số', () {
      final goi = GoiSoMucTieu.tu([_mt()], now: now);
      final cau = goi.mauCau().cau;
      expect(kiemSo(cau, goi), isTrue, reason: cau);
    });
  });
}
