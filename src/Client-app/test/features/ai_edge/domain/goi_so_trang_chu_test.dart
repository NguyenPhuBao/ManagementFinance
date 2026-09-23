/// Gói số Trang chủ nhận ĐÚNG các con số trang đang hiện (thu/chi tháng của
/// `TheSoLieuThang`, tổng số dư của thẻ tài sản) chứ không tự cộng giao dịch —
/// để "số trên thẻ = số trong gói" (điều kiện 12).
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so_trang_chu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flutter_test/flutter_test.dart';

BudgetView _ns(String ten, double amount, double spent) => BudgetView(
      budget: BudgetEntity(
        id: 'b-$ten',
        idaccount: 7,
        categoryId: 'c-$ten',
        amount: amount,
        spent: spent,
        startDate: DateTime(2026, 9, 1),
        recurrence: true,
        timeRecurrence: BudgetRecurrence.month,
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: ten,
    );

void main() {
  final now = DateTime(2026, 9, 22);

  test('tháng chưa có giao dịch → thiếu dữ liệu', () {
    final nx = GoiSoTrangChu.tu(
            thu: 0, chi: 0, tongSoDu: 13054000, nganSach: const [], now: now)
        .mauCau();
    expect(nx.muc, MucNhanXet.thieuDuLieu);
    expect(nx.cau, 'Tháng này chưa có giao dịch.');
    expect(nx.theSoLieu, isEmpty);
  });

  test('thu > chi → câu thu / chi / còn lại, mức bình thường', () {
    final g = GoiSoTrangChu.tu(
        thu: 15000000,
        chi: 8200000,
        tongSoDu: 13054000,
        nganSach: const [],
        now: now);
    final nx = g.mauCau();
    expect(nx.muc, MucNhanXet.binhThuong);
    expect(nx.cau,
        'Tháng này thu 15.000.000 đ, chi 8.200.000 đ, còn lại 6.800.000 đ.');
    expect(g.man, 'trang_chu');
    expect(nx.theSoLieu.map((s) => s.nhan).toList(),
        ['Thu', 'Chi', 'Còn lại', 'Tổng số dư']);
  });

  test('chi > thu → cảnh báo, câu "chi vượt thu X" (số dương, không dấu trừ)',
      () {
    final nx = GoiSoTrangChu.tu(
            thu: 7000000,
            chi: 8200000,
            tongSoDu: 100,
            nganSach: const [],
            now: now)
        .mauCau();
    expect(nx.muc, MucNhanXet.canhBao);
    expect(nx.cau,
        'Tháng này thu 7.000.000 đ, chi 8.200.000 đ, chi vượt thu 1.200.000 đ.');
    expect(nx.cau, isNot(contains('-')));
  });

  test('thu == chi → còn lại 0 đ, KHÔNG mang dấu', () {
    final nx = GoiSoTrangChu.tu(
            thu: 5000000,
            chi: 5000000,
            tongSoDu: 100,
            nganSach: const [],
            now: now)
        .mauCau();
    expect(nx.cau, contains('còn lại 0 đ'));
    expect(nx.cau, isNot(contains('-0')));
  });

  test('có ngân sách → thêm vế ngân sách căng nhất (pickHomeBudget)', () {
    final nx = GoiSoTrangChu.tu(
      thu: 15000000,
      chi: 8200000,
      tongSoDu: 13054000,
      nganSach: [
        _ns('Ăn uống', 3000000, 2100000),
        _ns('Đi lại', 1000000, 300000)
      ],
      now: now,
    ).mauCau();
    expect(nx.cau, endsWith(' Ngân sách Ăn uống đã dùng 70,0%.'));
    expect(nx.theSoLieu.last.nhan, 'Ngân sách căng nhất');
  });

  test('tên ngân sách có chữ số: mẫu câu vẫn tự qua bộ kiểm số (bước 1c)', () {
    final g = GoiSoTrangChu.tu(
      thu: 15000000,
      chi: 8200000,
      tongSoDu: 13054000,
      nganSach: [_ns('Học phí K12', 3000000, 2100000)],
      now: now,
    );
    final cau = g.mauCau().cau;
    expect(cau, endsWith(' Ngân sách Học phí K12 đã dùng 70,0%.'));
    expect(
      kiemSo(cau, g),
      isTrue,
      reason: 'Tên ngân sách nằm ở tenNganSach chứ không trên SoLieu "Ngân sách '
          'căng nhất" — gói phải tự khai nó ở tenDoiTuong, nếu không "12" của '
          'tên bị đọc là một con số bịa.',
    );
  });

  test('mẫu câu tự qua bộ kiểm số ở mọi nhánh', () {
    for (final g in [
      GoiSoTrangChu.tu(
          thu: 15000000,
          chi: 8200000,
          tongSoDu: 13054000,
          nganSach: const [],
          now: now),
      GoiSoTrangChu.tu(
          thu: 7000000,
          chi: 8200000,
          tongSoDu: 100,
          nganSach: const [],
          now: now),
      GoiSoTrangChu.tu(
          thu: 5000000,
          chi: 5000000,
          tongSoDu: 100,
          nganSach: const [],
          now: now),
      GoiSoTrangChu.tu(
          thu: 1,
          chi: 1,
          tongSoDu: 0,
          nganSach: [_ns('A', 3000000, 2100000)],
          now: now),
      GoiSoTrangChu.tu(
          thu: 0, chi: 0, tongSoDu: 0, nganSach: const [], now: now),
    ]) {
      expect(kiemSo(g.mauCau().cau, g), isTrue, reason: g.mauCau().cau);
    }
  });
}
