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
        thuNhapMoiThang: 0,
        mucThangTheoNganSach: const {},
        phanHoi: const [],
      );
      expect(kh, isNotNull);
      final g = GoiSoNganSach.tu(ds, now: now21, keHoach: kh);
      final nx = g.mauCau();
      expect(nx.cau, contains(kh!.cauTomTat));
      expect(kiemSo(nx.cau, g), isTrue, reason: nx.cau);
    }
  });

  test(
      'tên ngân sách THÂM HỤT có chữ số, nằm ngoài danh sách có tên: mẫu câu '
      'vẫn tự qua bộ kiểm số (bước 1c)', () {
    // 21/09: đã qua 20/30 ngày nên dự phóng = đã chi × 1,5. Thu nhập 0 → ngưỡng
    // thâm hụt là sàn 50.000 đ.
    final now21 = DateTime(2026, 9, 21);
    final ds = [
      // 99 % — căng nhất, là ngân sách được nhận xét. Hụt 48.500 < 50.000.
      _ns(id: 'a', ten: 'Giáo dục', amount: 100000, spent: 99000),
      // 75 % — tỉ lệ THẤP nhất, nhưng hụt 125.000: khoản duy nhất vượt ngưỡng.
      _ns(id: 'b', ten: 'Tiền nhà T9', amount: 1000000, spent: 750000),
      // 95 % — hụt 42.500 < 50.000; ba ngân sách này chiếm cả ba suất tên.
      _ns(id: 'c', ten: 'Ăn uống', amount: 100000, spent: 95000),
      _ns(id: 'd', ten: 'Di chuyển', amount: 100000, spent: 95000),
      _ns(id: 'e', ten: 'Mua sắm', amount: 100000, spent: 95000),
    ];
    final kh = taiPhanBoCua(
      dangChay: ds,
      now: now21,
      coDinh: const {},
      thuNhapMoiThang: 0,
      mucThangTheoNganSach: const {},
      phanHoi: const [],
    );
    // Hai tiền đề — ca này chỉ canh được điều nó nói khi cả hai đúng.
    expect(kh!.thieu.displayName, 'Tiền nhà T9');
    final g = GoiSoNganSach.tu(ds, now: now21, keHoach: kh);
    expect(g.soLieu.where((s) => s.ten == 'Tiền nhà T9'), isEmpty,
        reason: 'tên ngân sách thâm hụt không được nằm trên SoLieu nào, nếu '
            'không getter mặc định đã phủ nó và ca này không canh gì');

    final cau = g.mauCau().cau;
    expect(cau, contains('Tiền nhà T9 dự kiến vượt'));
    expect(
      kiemSo(cau, g),
      isTrue,
      reason: 'Câu tóm tắt kế hoạch nêu tên ngân sách thâm hụt — thứ có thể '
          'khác ngân sách căng nhất và nằm ngoài danh sách có tên. Gói phải tự '
          'khai tên ấy ở tenDoiTuong.',
    );
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

  group('danh sách ngân sách có TÊN (chặng 4a)', () {
    // Đúng bốn ngân sách của tài khoản 10 ngày 2026-09-22 (bảng đo mục 5.6).
    List<BudgetView> bonNganSach() => [
          _ns(id: 'b1', ten: 'Giáo dục', amount: 50000, spent: 45000),
          _ns(id: 'b2', ten: 'Ăn uống', amount: 500000, spent: 50000),
          _ns(id: 'b3', ten: 'Di chuyển', amount: 450000, spent: 355000),
          _ns(id: 'b4', ten: 'Mua sắm', amount: 850000, spent: 60000),
        ];

    test('mỗi ngân sách góp một mục Tỉ lệ mang TÊN của nó', () {
      final g = GoiSoNganSach.tu(bonNganSach(), now: now);
      final tenCoTiLe = [
        for (final s in g.soLieu)
          if (s.nhan == 'Tỉ lệ' && s.ten != null) s.ten,
      ];
      expect(
        tenCoTiLe,
        containsAll(<String>['Giáo dục', 'Ăn uống', 'Di chuyển', 'Mua sắm']),
        reason: 'Câu 3 của bảng đo — "ngân sách nào sắp hết" — nhận về '
            '"Ngân sách căng nhất là 90,0%" vì gói không mang tên nào.',
      );
    });

    test('căng nhất đứng ĐẦU danh sách', () {
      final g = GoiSoNganSach.tu(bonNganSach(), now: now);
      final coTen = g.soLieu.where((s) => s.ten != null).toList();
      expect(coTen.first.ten, 'Giáo dục',
          reason: 'Mô hình đọc từ trên xuống và hay lấy mục đầu khi phải '
              'chọn một.');
    });

    test('không vượt trần kToiDaMucMoiGoi ngân sách', () {
      final sau = [
        ...bonNganSach(),
        _ns(id: 'b5', ten: 'Giải trí', amount: 100000, spent: 10000),
        _ns(id: 'b6', ten: 'Sức khoẻ', amount: 200000, spent: 20000),
      ];
      final g = GoiSoNganSach.tu(sau, now: now);
      final soMucCoTen = g.soLieu.where((s) => s.ten != null).length;
      expect(soMucCoTen, lessThanOrEqualTo(kToiDaMucMoiGoi),
          reason: 'Prompt đã 1.700 ký tự; trần là thứ giữ nó không phình.');
    });

    test('mẫu câu KHÔNG đổi — sáu khối Nhận xét vẫn nói về MỘT ngân sách', () {
      final g = GoiSoNganSach.tu(bonNganSach(), now: now);
      expect(g.mauCau().cau, contains('Giáo dục'));
      expect(g.mauCau().cau, isNot(contains('Mua sắm')),
          reason: 'Khối Nhận xét là lối B — mẫu câu, một đối tượng. Lát này '
              'chỉ mở rộng gói cho HỎI ĐÁP, không đụng sáu khối ấy.');
    });

    test('⭐ mẫu câu nêu tỉ lệ của CHÍNH ngân sách nó nói tới', () {
      final g = GoiSoNganSach.tu(bonNganSach(), now: now);
      expect(
        g.mauCau().cau,
        contains('90,0%'),
        reason: 'Mẫu câu tra mục theo nhãn qua `chuoiTheoNhan`. Nếu bảng tra '
            'lấy giá trị CUỐI khi trùng khoá (khuôn `{for … x.nhan: x.chuoi}` '
            'cũ) thì — vì bốn ngân sách cùng mang nhãn "Tỉ lệ" và danh sách '
            'đứng cuối — câu nhận xét về Giáo dục in tỉ lệ của Mua sắm (7,1%): '
            'sai im lặng, và ca "contains(Giáo dục)" ở trên vẫn xanh.',
      );
      expect(g.mauCau().cau, isNot(contains('7,1%')));
    });

    test('mục của ngân sách căng nhất vẫn giữ nguyên, không mất nhãn nào', () {
      final g = GoiSoNganSach.tu(bonNganSach(), now: now);
      final nhan = g.soLieu.map((s) => s.nhan).toSet();
      expect(nhan, containsAll(<String>['Đã chi', 'Hạn mức', 'Tỉ lệ', 'Còn']),
          reason: 'Thêm danh sách không được làm mất mục nào của gói cũ — '
              'mẫu câu tra theo nhãn và sẽ in "null" nếu thiếu.');
    });
  });
}
