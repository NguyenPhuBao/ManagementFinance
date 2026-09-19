/// Gói số Ngân sách: mọi con số lấy từ `budgetPaceOf` và `BudgetEntity` —
/// ca test tính kỳ vọng bằng CHÍNH hàm ấy chứ không ghi cứng, để test không
/// thành bản định nghĩa thứ hai của nhịp chi.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so_ngan_sach.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flowmoney/features/ai_edge/domain/tai_phan_bo.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/budget_pace.dart';
import 'package:flutter_test/flutter_test.dart';

BudgetView _ns({
  String id = 'b1',
  String ten = 'Giáo dục',
  required double amount,
  required double spent,
  DateTime? start,
}) {
  final s = start ?? DateTime(2026, 9, 1);
  return BudgetView(
    budget: BudgetEntity(
      id: id,
      idaccount: 7,
      categoryId: 'c-$id',
      amount: amount,
      spent: spent,
      startDate: s,
      recurrence: true,
      timeRecurrence: BudgetRecurrence.month,
      updatedAt: s,
    ),
    categoryName: ten,
  );
}

void main() {
  // 22/09 00:00: còn đúng 9 ngày tới 01/10 — số đẹp, khớp màn Stitch.
  final now = DateTime(2026, 9, 22);

  test('không ngân sách → thiếu dữ liệu, câu thật, không thẻ', () {
    final g = GoiSoNganSach.tu(const [], now: now);
    expect(g.thieuDuLieu, isTrue);
    final nx = g.mauCau();
    expect(nx.muc, MucNhanXet.thieuDuLieu);
    expect(nx.cau, 'Chưa có ngân sách nào đang chạy để nhận xét.');
    expect(nx.theSoLieu, isEmpty);
    expect(g.man, 'ngan_sach');
  });

  test(
      'giữa kỳ: câu nêu đã dùng / hạn mức (tỉ lệ), còn N ngày, nên chi mỗi ngày',
      () {
    final v = _ns(amount: 3000000, spent: 2100000);
    final g = GoiSoNganSach.tu([v], now: now);
    final nhip = budgetPaceOf(v.budget, now);

    expect(g.thieuDuLieu, isFalse);
    final nx = g.mauCau();
    expect(nx.muc, MucNhanXet.binhThuong);
    expect(nx.cau, contains('Giáo dục'));
    expect(nx.cau, contains('2.100.000 đ / 3.000.000 đ (70,0%)'));
    expect(nx.cau, contains('còn ${nhip.daysLeft} ngày'));
    expect(nx.cau, contains('nên chi tối đa 100.000 đ mỗi ngày'),
        reason: '900.000 còn lại / 9 ngày — số từ budgetPaceOf');
    expect(nx.theSoLieu.map((s) => s.nhan).toList(),
        ['Đã chi', 'Hạn mức', 'Tỉ lệ', 'Còn', 'Mỗi ngày']);
  });

  test('đã vượt hạn mức → cảnh báo, câu nói "đã vượt", không có vế mỗi ngày',
      () {
    final v = _ns(amount: 3000000, spent: 3400000);
    final nx = GoiSoNganSach.tu([v], now: now).mauCau();
    expect(nx.muc, MucNhanXet.canhBao);
    expect(nx.cau, contains('đã vượt hạn mức'));
    expect(nx.cau, isNot(contains('mỗi ngày')));
    expect(nx.theSoLieu.map((s) => s.nhan), isNot(contains('Mỗi ngày')));
  });

  test('nhiều ngân sách → nhận xét ngân sách CĂNG nhất (pickHomeBudget)', () {
    final thap = _ns(id: 'a', ten: 'Ăn uống', amount: 5000000, spent: 500000);
    final cao = _ns(id: 'b', ten: 'Đi lại', amount: 1000000, spent: 800000);
    final g = GoiSoNganSach.tu([thap, cao], now: now);
    expect(g.ten, 'Đi lại');
  });

  test('mẫu câu tự qua được bộ kiểm số (nếu không, P3 rơi về câu bị chặn)', () {
    for (final v in [
      _ns(amount: 3000000, spent: 2100000),
      _ns(amount: 3000000, spent: 3400000),
      _ns(amount: 1234567, spent: 987654),
    ]) {
      final g = GoiSoNganSach.tu([v], now: now);
      expect(kiemSo(g.mauCau().cau, g), isTrue,
          reason: 'câu: ${g.mauCau().cau}');
    }
  });

  test('có kế hoạch → câu nối thêm tóm tắt và vẫn qua bộ kiểm số', () {
    final thieu =
        _ns(id: 'an', ten: 'Ăn uống', amount: 3000000, spent: 2400000);
    final gt = _ns(
        id: 'gt', ten: 'Giải trí', amount: 2000000, spent: 800000 * 20 / 30);
    final ms = _ns(
        id: 'ms', ten: 'Mua sắm', amount: 3000000, spent: 1000000 * 20 / 30);
    final now21 = DateTime(2026, 9, 21);
    for (final ds in [
      [thieu, gt, ms],
      [thieu, gt],
      [thieu],
    ]) {
      final kh = taiPhanBoCua(
        dangChay: ds,
        now: now21,
        coDinh: const {},
        thuNhap3Thang: 0,
        tb3ThangTheoNganSach: const {},
        phanHoi: const [],
      );
      expect(kh, isNotNull);
      final g = GoiSoNganSach.tu(ds, now: now21, keHoach: kh);
      final nx = g.mauCau();
      expect(nx.cau, contains(kh!.cauTomTat));
      expect(kiemSo(nx.cau, g), isTrue, reason: nx.cau);
    }
  });

  test('cùng số → cùng dấu vân; đổi số đã chi → khác', () {
    final a =
        GoiSoNganSach.tu([_ns(amount: 3000000, spent: 2100000)], now: now);
    final b =
        GoiSoNganSach.tu([_ns(amount: 3000000, spent: 2100000)], now: now);
    final c =
        GoiSoNganSach.tu([_ns(amount: 3000000, spent: 2200000)], now: now);
    expect(a.dauVan, b.dauVan);
    expect(a.dauVan, isNot(c.dauVan));
  });
}
