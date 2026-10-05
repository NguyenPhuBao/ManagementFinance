/// Bộ đếm giây xem của trang Phân tích — spec 3.1, kế hoạch "làm rõ" 5.
library;

import 'package:flowmoney/features/analytics/domain/bo_dem_giay.dart';
import 'package:flowmoney/features/analytics/domain/thu_tu_khoi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 20, 9);
  DateTime giay(int s) => t0.add(Duration(seconds: s));

  /// Chạy nhịp 1..n, cùng vị trí cuộn, gom mọi lượt ghi + phần còn lại.
  Map<CumKhoi, int> chay(BoDemGiay bo, int n, {CumKhoi? cum = CumKhoi.coCau, double viTri = 0}) {
    final tong = <CumKhoi, int>{};
    void cong(LuotGhi? l) => l?.giay.forEach((k, v) => tong[k] = (tong[k] ?? 0) + v);
    for (var s = 1; s <= n; s++) {
      cong(bo.nhip(luc: giay(s), viTri: viTri, cum: cum));
    }
    cong(bo.xa());
    return tong;
  }

  test('nhịp đầu sau batDau không cộng; đứng yên thì mỗi nhịp một giây', () {
    final bo = BoDemGiay()..batDau(t0);
    expect(chay(bo, 20), {CumKhoi.coCau: 19});
  });

  test('cuộn (vị trí đổi) thì nhịp ấy không cộng', () {
    final bo = BoDemGiay()..batDau(t0);
    bo.nhip(luc: giay(1), viTri: 0, cum: CumKhoi.coCau);
    bo.nhip(luc: giay(2), viTri: 0, cum: CumKhoi.coCau); // +1
    bo.nhip(luc: giay(3), viTri: 120, cum: CumKhoi.coCau); // cuộn: 0
    bo.nhip(luc: giay(4), viTri: 120, cum: CumKhoi.coCau); // +1
    expect(bo.xa()!.giay, {CumKhoi.coCau: 2});
  });

  test('quá 60 giây không tương tác thì thôi cộng; chạm lại thì cộng tiếp', () {
    final bo = BoDemGiay()..batDau(t0);
    expect(chay(bo, 70), {CumKhoi.coCau: 59}, reason: 'nhịp 2..60');
    bo.tuongTac(giay(70));
    bo.nhip(luc: giay(71), viTri: 0, cum: CumKhoi.coCau);
    expect(bo.xa()!.giay, {CumKhoi.coCau: 1});
  });

  test('không cụm nào trên màn → không cộng', () {
    final bo = BoDemGiay()..batDau(t0);
    expect(chay(bo, 10, cum: null), isEmpty);
  });

  test('đủ 15 nhịp có giây chưa ghi thì trả lượt ghi', () {
    final bo = BoDemGiay()..batDau(t0);
    LuotGhi? l;
    for (var s = 1; s <= 16; s++) {
      final r = bo.nhip(luc: giay(s), viTri: 0, cum: CumKhoi.tong);
      if (s < 16) expect(r, isNull, reason: 'nhịp $s');
      l = r;
    }
    expect(l!.giay, {CumKhoi.tong: 15});
    expect(l.ngay, DateTime(2026, 10, 20));
  });

  test('qua nửa đêm: giây của ngày cũ ghi riêng, đúng ngày cũ', () {
    final dem = DateTime(2026, 10, 20, 23, 59, 50);
    final bo = BoDemGiay()..batDau(dem);
    LuotGhi? cu;
    for (var s = 1; s <= 12; s++) {
      final r = bo.nhip(luc: dem.add(Duration(seconds: s)), viTri: 0, cum: CumKhoi.tong);
      cu ??= r;
    }
    expect(cu!.ngay, DateTime(2026, 10, 20));
    // Nhịp s = 23:59:50 + s giây: s=1 không cộng (vừa batDau), s=2..9 là
    // 23:59:52..59 → 8 giây; s=10 là 00:00:00 ngày 21 → trả lượt cũ rồi cộng.
    expect(cu.giay, {CumKhoi.tong: 8}, reason: 'nhịp 2..9 thuộc 20/10');
    final moi = bo.xa()!;
    expect(moi.ngay, DateTime(2026, 10, 21));
    expect(moi.giay, {CumKhoi.tong: 3}, reason: 'nhịp 10..12');
  });

  test('xa() khi không có gì → null', () => expect(BoDemGiay().xa(), isNull));
}
