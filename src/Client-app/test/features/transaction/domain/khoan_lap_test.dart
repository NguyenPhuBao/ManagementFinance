/// Khoản chi lặp (B2) — nhận diện khoản người dùng ghi tay lặp theo tháng / tuần.
///
/// Spec: docs/superpowers/specs/2026-09-28-b2-khoan-lap-goi-y-hoa-don-design.md
/// mục 2. Ngưỡng 3 lần, tháng 25–34 ngày, tuần 6–8 ngày, số tiền lệch ≤ 10 % so
/// với trung vị chuỗi, lần gần nhất cách `now` ≤ 45 ngày (tháng) / 10 ngày (tuần).
library;

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/transaction/domain/khoan_lap.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _gd(
  DateTime ngay,
  double tien, {
  String note = 'Tiền nhà',
  String? cat = 'c-nha',
  String vi = 'v1',
  String type = 'chi',
  String? billId,
  String? goalId,
  bool xoa = false,
  String id = '',
}) =>
    Transaction(
      id: id.isEmpty ? '${ngay.toIso8601String()}-$tien-$note-$cat' : id,
      walletId: vi,
      idaccount: 10,
      categoryId: cat,
      amount: tien,
      type: type,
      status: 'completed',
      provider: 'Manual',
      note: note,
      date: ngay,
      images: '',
      goalId: goalId,
      billId: billId,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: ngay,
      isDeleted: xoa,
    );

void main() {
  group('ghiChuChuanHoa / tenHienThi', () {
    test('bỏ dấu, chữ thường, bỏ từ có chữ số và chữ tháng / t đứng trước', () {
      expect(ghiChuChuanHoa('Tiền nhà T9'), 'tien nha');
      expect(ghiChuChuanHoa('tiền nhà tháng 10'), 'tien nha');
      expect(ghiChuChuanHoa('Tien nha 11/2026'), 'tien nha');
      expect(ghiChuChuanHoa('  Netflix  '), 'netflix');
      expect(ghiChuChuanHoa('12/9'), '', reason: 'chỉ có số → rỗng → không xét');
    });
    test('tenHienThi giữ dấu và chữ hoa, bỏ cùng những từ ấy', () {
      expect(tenHienThi('Tiền nhà T9'), 'Tiền nhà');
      expect(tenHienThi('tiền nhà tháng 10'), 'tiền nhà');
    });
  });

  test('ba lần cách một tháng → một khoản lặp tháng', () {
    final now = DateTime(2026, 11, 20);
    final r = timKhoanLap([
      _gd(DateTime(2026, 9, 5), 3000000, note: 'Tiền nhà T9'),
      _gd(DateTime(2026, 10, 5), 3000000, note: 'tiền nhà tháng 10'),
      _gd(DateTime(2026, 11, 5), 3100000, note: 'Tiền nhà T11'),
    ], now: now);
    expect(r, hasLength(1),
        reason: 'ba cách viết ghi chú khác nhau phải về cùng một nhóm');
    expect(r.single.chuKy, kBillCycleMonth);
    expect(r.single.soLan, 3);
    expect(r.single.soTien, 3100000, reason: 'số tiền lần gần nhất');
    expect(r.single.ten, 'Tiền nhà');
    expect(r.single.ngayGoc, 5);
    expect(r.single.khoaNhom, 'tien nha|c-nha');
    expect(r.single.ngayGanNhat, DateTime(2026, 11, 5));
  });

  List<Transaction> baThang({double t3 = 3000000, String note = 'Tiền nhà'}) => [
        _gd(DateTime(2026, 9, 5), 3000000, note: note),
        _gd(DateTime(2026, 10, 5), 3000000, note: note),
        _gd(DateTime(2026, 11, 5), t3, note: note),
      ];
  final now = DateTime(2026, 11, 20);

  test('hai lần → không (ngưỡng 3, người dùng chốt)', () {
    expect(timKhoanLap(baThang().sublist(1), now: now), isEmpty);
  });

  test('ba lần cách 7 ngày → khoản lặp tuần, ngayGoc null', () {
    final r = timKhoanLap([
      _gd(DateTime(2026, 11, 3), 50000, note: 'Gửi xe'),
      _gd(DateTime(2026, 11, 10), 50000, note: 'Gửi xe'),
      _gd(DateTime(2026, 11, 17), 50000, note: 'Gửi xe'),
    ], now: now);
    expect(r.single.chuKy, kBillCycleWeek);
    expect(r.single.ngayGoc, isNull, reason: 'tuần không có ngày trong tháng');
  });

  test('một khoảng cách 40 ngày → chuỗi cắt ở đó; còn 2 lần sau chỗ cắt → không', () {
    final r = timKhoanLap([
      _gd(DateTime(2026, 8, 1), 3000000),
      _gd(DateTime(2026, 9, 10), 3000000), // cách 40 ngày — phá chuỗi
      _gd(DateTime(2026, 10, 10), 3000000),
      _gd(DateTime(2026, 11, 10), 3000000),
    ], now: now);
    expect(r.single.soLan, 3,
        reason: 'chuỗi đi lùi từ lần gần nhất, dừng ở khoảng 40 ngày');
    final r2 = timKhoanLap([
      _gd(DateTime(2026, 8, 1), 3000000),
      _gd(DateTime(2026, 9, 10), 3000000),
      _gd(DateTime(2026, 11, 10), 3000000), // cách 61 ngày
    ], now: now);
    expect(r2, isEmpty);
  });

  test('số tiền lệch 11 % so với trung vị → không; 9 % → có', () {
    expect(timKhoanLap(baThang(t3: 3330000), now: now), isEmpty,
        reason: 'trung vị 3.000.000, 3.330.000 lệch 11 %');
    expect(timKhoanLap(baThang(t3: 3270000), now: now), hasLength(1));
  });

  test('lần gần nhất cách now 46 ngày → không (đã ngừng)', () {
    expect(timKhoanLap(baThang(), now: DateTime(2026, 12, 21)), isEmpty);
    expect(timKhoanLap(baThang(), now: DateTime(2026, 12, 20)), hasLength(1),
        reason: '45 ngày vẫn tính');
  });

  test('loại: billId · goalId · transfer · điều chỉnh số dư · ghi chú rỗng · ngày tương lai · đã xoá',
      () {
    List<Transaction> voi(Transaction Function(DateTime) f) =>
        [f(DateTime(2026, 9, 5)), f(DateTime(2026, 10, 5)), f(DateTime(2026, 11, 5))];
    expect(timKhoanLap(voi((d) => _gd(d, 100000)), now: now), hasLength(1),
        reason: 'đối chứng: cùng ba khoản, không bị loại thì ra một nhóm');
    expect(timKhoanLap(voi((d) => _gd(d, 100000, billId: 'b1')), now: now), isEmpty,
        reason: 'đã là hoá đơn');
    expect(timKhoanLap(voi((d) => _gd(d, 100000, goalId: 'g1')), now: now), isEmpty,
        reason: 'trích mục tiêu');
    expect(timKhoanLap(voi((d) => _gd(d, 100000, type: 'transfer')), now: now), isEmpty);
    expect(
        timKhoanLap(voi((d) => _gd(d, 100000, note: 'Điều chỉnh số dư', cat: null)),
            now: now),
        isEmpty,
        reason: 'khoản bù của đối soát không phải chi tiêu (khoanVaoThongKe)');
    expect(timKhoanLap(voi((d) => _gd(d, 100000, note: '   ')), now: now), isEmpty);
    expect(timKhoanLap(voi((d) => _gd(d, 100000, xoa: true)), now: now), isEmpty);
    expect(timKhoanLap(voi((d) => _gd(d, 100000)), now: DateTime(2026, 11, 4)), isEmpty,
        reason: 'lần 5/11 ở TƯƠNG LAI so với now → bị loại, còn hai lần');
  });

  test('hai khoản CÙNG NGÀY cùng nhóm gộp làm một lần, cộng tiền', () {
    final r = timKhoanLap([
      ...baThang(),
      _gd(DateTime(2026, 11, 5, 20), 50000, id: 'them'),
    ], now: now);
    expect(r.single.soLan, 3, reason: 'một khoản ghi làm hai dòng không phải hai kỳ');
    expect(r.single.soTien, 3050000);
  });

  test('khác danh mục → hai nhóm khác nhau', () {
    final r = timKhoanLap([
      ...baThang(),
      for (final d in [DateTime(2026, 9, 6), DateTime(2026, 10, 6), DateTime(2026, 11, 6)])
        _gd(d, 200000, cat: 'c-khac'),
    ], now: now);
    expect(r, hasLength(2));
  });

  test('ví hay dùng nhất; hoà thì ví của lần gần nhất', () {
    final r = timKhoanLap([
      _gd(DateTime(2026, 9, 5), 3000000, vi: 'vA'),
      _gd(DateTime(2026, 10, 5), 3000000, vi: 'vA'),
      _gd(DateTime(2026, 11, 5), 3000000, vi: 'vB'),
    ], now: now);
    expect(r.single.walletId, 'vA');
    final r2 = timKhoanLap([
      _gd(DateTime(2026, 8, 5), 3000000, vi: 'vA'),
      _gd(DateTime(2026, 9, 5), 3000000, vi: 'vA'),
      _gd(DateTime(2026, 10, 5), 3000000, vi: 'vB'),
      _gd(DateTime(2026, 11, 5), 3000000, vi: 'vB'),
    ], now: now);
    expect(r2.single.walletId, 'vB', reason: 'hoà 2–2 → ví của lần gần nhất');
  });

  group('ngày gốc — tháng ngắn và năm nhuận', () {
    test('31/12/2026 → 31/1/2027 → 28/2/2027 (năm thường) → ngày gốc 31', () {
      final r = timKhoanLap([
        _gd(DateTime(2026, 12, 31), 100000),
        _gd(DateTime(2027, 1, 31), 100000),
        _gd(DateTime(2027, 2, 28), 100000),
      ], now: DateTime(2027, 3, 10));
      expect(r.single.ngayGoc, 31,
          reason: '28/2 là ngày cuối tháng → lấy ngày lớn nhất của chuỗi');
    });
    test('31/12/2027 → 31/1/2028 → 29/2/2028 (năm nhuận) → ngày gốc 31', () {
      final r = timKhoanLap([
        _gd(DateTime(2027, 12, 31), 100000),
        _gd(DateTime(2028, 1, 31), 100000),
        _gd(DateTime(2028, 2, 29), 100000),
      ], now: DateTime(2028, 3, 10));
      expect(r.single.ngayGoc, 31);
    });
    test('28/2/2028 năm nhuận KHÔNG phải ngày cuối tháng → ngày gốc 28', () {
      final r = timKhoanLap([
        _gd(DateTime(2027, 12, 28), 100000),
        _gd(DateTime(2028, 1, 28), 100000),
        _gd(DateTime(2028, 2, 28), 100000),
      ], now: DateTime(2028, 3, 10));
      expect(r.single.ngayGoc, 28,
          reason: 'tháng 2/2028 có 29 ngày — 28 là ngày thường, không kéo lên');
    });
    test('30/9 → 31/10 → 30/11 (tháng 30 ngày) → ngày gốc 31', () {
      final r = timKhoanLap([
        _gd(DateTime(2026, 9, 30), 100000),
        _gd(DateTime(2026, 10, 31), 100000),
        _gd(DateTime(2026, 11, 30), 100000),
      ], now: DateTime(2026, 12, 5));
      expect(r.single.ngayGoc, 31);
    });
    test('5/9 → 5/10 → 5/11 → ngày gốc 5 (không phải ngày cuối tháng)', () {
      expect(timKhoanLap(baThang(), now: now).single.ngayGoc, 5);
    });
  });

  test('khoaNhomCua trả null cho khoản không đủ điều kiện, khoá cho khoản đủ', () {
    expect(khoaNhomCua(_gd(DateTime(2026, 11, 5), 1, note: 'Tiền nhà T11'), now: now),
        'tien nha|c-nha');
    expect(khoaNhomCua(_gd(DateTime(2026, 11, 5), 1, billId: 'b'), now: now), isNull);
    expect(khoaNhomCua(_gd(DateTime(2026, 11, 5), 1, cat: null), now: now), 'tien nha|',
        reason: 'không danh mục vẫn là một nhóm (chỉ ghi chú rỗng mới bị loại)');
    expect(phanGhiChuCuaKhoa('tien nha|c-nha'), 'tien nha');
  });
}
