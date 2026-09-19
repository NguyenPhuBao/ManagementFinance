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
}) =>
    GoalEntity(
      id: id,
      idaccount: 7,
      name: ten,
      targetAmount: target,
      currentAmount: current,
      startDate: start ?? DateTime(2026, 1, 1),
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
    expect(nx.cau,
        'Mua xe: 45,0%, còn thiếu 27.500.000 đ, còn ${g.daysLeft(now)} ngày; chậm kế hoạch.');
    expect(goi.man, 'muc_tieu');
    expect(nx.theSoLieu.map((s) => s.nhan).toList(),
        ['Tiến độ', 'Còn thiếu', 'Còn']);
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
    expect(nx.cau, isNot(contains(' ngày')));
    expect(nx.cau, endsWith('; đã quá hạn.'));
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
}
