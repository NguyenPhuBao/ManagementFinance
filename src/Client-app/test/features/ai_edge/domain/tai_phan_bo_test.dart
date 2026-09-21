/// Tầng 2 — thâm hụt, nguồn bù, kế hoạch tái phân bổ (spec mục 3.1). Mọi mốc
/// đặt ở kỳ tháng 9/2026, `now` = 21/09 00:00 → đã qua 20/30 ngày, nên dự
/// phóng = spent × 30 / 20 = spent × 1,5 — số đẹp để đọc ca test bằng mắt.
library;

import 'package:flowmoney/features/ai_edge/domain/tai_phan_bo.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 21);

BudgetView _v(
  String id, {
  required double amount,
  required double spent,
  String? categoryId = 'auto',
  String? ten,
  DateTime? start,
}) =>
    BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: categoryId == 'auto' ? 'c-$id' : categoryId,
        amount: amount,
        spent: spent,
        startDate: start ?? DateTime(2026, 9, 1),
        recurrence: true,
        timeRecurrence: BudgetRecurrence.month,
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: ten ?? id,
    );

/// Ngân sách có dự phóng đúng [duPhong] ở mốc 20/30 ngày.
BudgetView _duPhong(String id,
        {required double amount, required double duPhong, DateTime? start}) =>
    _v(id, amount: amount, spent: duPhong * 20 / 30, ten: id, start: start);

KeHoachTaiPhanBo? _kh(
  List<BudgetView> ds, {
  Set<String> coDinh = const {},
  double thuNhapMoiThang = 0,
  Map<String, double?> tb = const {},
  List<PhanHoiCu> phanHoi = const [],
}) =>
    taiPhanBoCua(
      dangChay: ds,
      now: _now,
      coDinh: coDinh,
      thuNhapMoiThang: thuNhapMoiThang,
      mucThangTheoNganSach: tb,
      phanHoi: phanHoi,
    );

void main() {
  group('duPhongCua', () {
    test('đã qua ≥ 5 ngày: spent × daysTotal / daysElapsed', () {
      final v = _v('a', amount: 3000000, spent: 2000000);
      expect(duPhongCua(v, now: _now, mucThang: null), closeTo(3000000, 1));
    });
    test('dưới 5 ngày và có mức tháng: spent + mức × phần kỳ còn lại', () {
      final v = _v('a', amount: 3000000, spent: 500000);
      final now = DateTime(2026, 9, 4); // đã qua 3 ngày, còn 27
      expect(duPhongCua(v, now: now, mucThang: 3000000),
          closeTo(500000 + 3000000 * 27 / 30, 1));
    });
    test('dưới 5 ngày và KHÔNG có mức tháng → null (chỉ báo khi đã vượt)', () {
      final v = _v('a', amount: 3000000, spent: 500000);
      expect(duPhongCua(v, now: DateTime(2026, 9, 4), mucThang: null), isNull);
    });
  });

  group('ngưỡng thâm hụt kép (B2)', () {
    test('8,3 % hạn mức → không kế hoạch dù tuyệt đối 250.000', () {
      expect(_kh([_duPhong('a', amount: 3000000, duPhong: 3250000)]), isNull);
    });
    test('40.000 đ → không kế hoạch dù bằng 13 % hạn mức', () {
      expect(_kh([_duPhong('a', amount: 300000, duPhong: 340000)]), isNull);
    });
    test('không ngân sách nào thâm hụt → null', () {
      expect(_kh([_duPhong('a', amount: 3000000, duPhong: 2000000)]), isNull);
    });
  });

  group('nguồn bù', () {
    final anUong =
        _duPhong('an', amount: 3000000, duPhong: 3600000); // hụt 600k
    final giaiTri = _duPhong('gt', amount: 2000000, duPhong: 800000); // dư 1,2M
    final muaSam = _duPhong('ms', amount: 3000000, duPhong: 1000000); // dư 2M

    test('xếp theo dư địa giảm dần, cắt tối đa 25 % dư địa, đủ thì dừng', () {
      final kh = _kh([anUong, giaiTri, muaSam])!;
      expect(kh.thieu.budget.id, 'an');
      expect(kh.thamHut, closeTo(600000, 1));
      expect(kh.dong.map((d) => d.nguon.budget.id).toList(), ['ms', 'gt']);
      expect(kh.dong.map((d) => d.soTien).toList(), [500000, 100000]);
      expect(kh.trangThai, TrangThaiKeHoach.duNguonBu);
      expect(kh.tongCat, 600000);
      expect(kh.soThieu, 0);
      expect(
          kh.cauTomTat, 'an dự kiến vượt 600.000 đ. Bớt từ 2 ngân sách khác?');
    });

    test('cờ Cố định thắng dư địa lớn: Mua sắm bị loại', () {
      final kh = _kh([anUong, giaiTri, muaSam], coDinh: {'c-ms'})!;
      expect(kh.dong.map((d) => d.nguon.budget.id).toList(), ['gt']);
      expect(kh.trangThai, TrangThaiKeHoach.thieuNguonBu);
    });

    test('dư địa dưới 100.000 không được chọn', () {
      final nho = _duPhong('nho', amount: 1000000, duPhong: 950000);
      final kh = _kh([anUong, nho])!;
      expect(kh.dong, isEmpty);
      expect(kh.trangThai, TrangThaiKeHoach.thieuNguonBu);
      expect(kh.soThieu, closeTo(600000, 1));
    });

    // Ngân sách phải tồn tại từ trước để CÓ hai kỳ liền trước: bắt đầu 01/09
    // thì `recentPeriods` chỉ trả một kỳ và luật không bao giờ kích hoạt.
    final muaSamCu = _duPhong('ms',
        amount: 3000000, duPhong: 1000000, start: DateTime(2026, 6, 1));

    test('đã bị cắt hai kỳ liền trước → trần 15 %', () {
      final ph = [
        PhanHoiCu(
            donorBudgetId: 'ms',
            action: 'accepted',
            periodFrom: DateTime(2026, 8, 1)),
        PhanHoiCu(
            donorBudgetId: 'ms',
            action: 'modified',
            periodFrom: DateTime(2026, 7, 1)),
      ];
      expect(daBiCatHaiKyLienTruoc(muaSam.budget, ph, _now), isFalse,
          reason: 'ngân sách mới tạo tháng này chưa có kỳ trước nào');
      expect(daBiCatHaiKyLienTruoc(muaSamCu.budget, ph, _now), isTrue);
      final kh = _kh([anUong, giaiTri, muaSamCu], phanHoi: ph)!;
      // Mua sắm: 15 % × 2M = 300k; Giải trí: 25 % × 1,2M = 300k → đủ 600k.
      expect(kh.dong.map((d) => d.soTien).toList(), [300000, 300000]);
    });

    test('chỉ một kỳ bị cắt, hoặc bị từ chối → vẫn trần 25 %', () {
      final motKy = [
        PhanHoiCu(
            donorBudgetId: 'ms',
            action: 'accepted',
            periodFrom: DateTime(2026, 8, 1)),
      ];
      final tuChoi = [
        PhanHoiCu(
            donorBudgetId: 'ms',
            action: 'rejected',
            periodFrom: DateTime(2026, 8, 1)),
        PhanHoiCu(
            donorBudgetId: 'ms',
            action: 'rejected',
            periodFrom: DateTime(2026, 7, 1)),
      ];
      expect(daBiCatHaiKyLienTruoc(muaSamCu.budget, motKy, _now), isFalse);
      expect(daBiCatHaiKyLienTruoc(muaSamCu.budget, tuChoi, _now), isFalse);
    });

    test('làm tròn 10.000: 25 % của 1.234.567 → 310.000', () {
      expect(lamTronBuoc(308641.75, 10000), 310000);
      final le =
          _duPhong('le', amount: 2234567, duPhong: 1000000); // dư 1.234.567
      final hutLon = _duPhong('h', amount: 2000000, duPhong: 7000000); // hụt 5M
      final kh = _kh([hutLon, le])!;
      expect(kh.dong.single.soTien, 310000);
    });

    test('ngưỡng có nghĩa: max(1 % thu nhập, 50.000) — dòng nhỏ hơn bị bỏ', () {
      expect(nguongCoNghia(20000000), 200000);
      expect(nguongCoNghia(0), 50000);
      final nho = _duPhong('nho',
          amount: 1000000, duPhong: 600000); // dư 400k → cắt 100k
      final kh = _kh([anUong, nho], thuNhapMoiThang: 20000000)!;
      expect(kh.dong, isEmpty, reason: '100.000 < ngưỡng 200.000');
    });

    test('cạn nguồn bù: trạng thái thiếu, số thiếu, câu tóm tắt', () {
      final kh = _kh([anUong, giaiTri])!;
      expect(kh.dong.single.soTien, 300000);
      expect(kh.trangThai, TrangThaiKeHoach.thieuNguonBu);
      expect(kh.soThieu, closeTo(300000, 1));
      expect(kh.cauTomTat, contains('thiếu 300.000 đ'));
    });

    test('hai ngân sách thâm hụt → kế hoạch cho cái hụt LỚN hơn', () {
      final hutNho = _duPhong('n', amount: 1000000, duPhong: 1200000); // 200k
      final kh = _kh([hutNho, anUong, muaSam])!;
      expect(kh.thieu.budget.id, 'an');
    });

    test('categoryId null bị bỏ qua ở cả hai vai', () {
      final tong = _v('tong', amount: 1000000, spent: 900000, categoryId: null);
      final hut = _v('hut', amount: 1000000, spent: 900000, categoryId: null);
      expect(_kh([hut]), isNull);
      final kh = _kh([anUong, tong, giaiTri])!;
      expect(kh.dong.map((d) => d.nguon.budget.id), isNot(contains('tong')));
    });

    test('ngân sách thiếu không tự làm nguồn bù cho chính nó', () {
      final kh = _kh([anUong, giaiTri])!;
      expect(kh.dong.map((d) => d.nguon.budget.id), isNot(contains('an')));
    });
  });

  // ── Neo ba ngưỡng tuyệt đối theo thu nhập (mục 11.5 (1)) ─────────────────
  //
  // Trước lượt này, luật tái phân bổ có sáu ngưỡng mà chỉ **một**
  // (`nguongCoNghia`) neo theo người dùng. Người thu nhập 5 triệu và người 50
  // triệu dùng chung ngưỡng thâm hụt 50.000 đ — với người thứ hai, app dựng cả
  // một kế hoạch cắt giảm cho tiền lẻ.
  //
  // ⚠️ Hai hằng **tỉ lệ** (`kTranCat`, `kTranCatDaBiCat`) KHÔNG neo: chúng vốn
  // không phụ thuộc quy mô thu nhập, neo chúng là làm hỏng thứ đang đúng.
  group('neo ngưỡng theo thu nhập', () {
    test('thu nhập 0: cả ba trả về đúng hằng cũ, tức hành vi hôm nay', () {
      expect(nguongThamHutTuyetDoi(0), kNguongThamHutTuyetDoi);
      expect(duDiaToiThieu(0), kDuDiaToiThieu);
      expect(buocLamTron(0), kBuocLamTron);
    });

    test('5 triệu/tháng là điểm xoay — vẫn đúng bằng hằng cũ', () {
      expect(nguongThamHutTuyetDoi(5000000), 50000);
      expect(duDiaToiThieu(5000000), 100000);
      expect(buocLamTron(5000000), 10000);
    });

    test('50 triệu/tháng: cả ba giãn ra, giữ nguyên tỉ lệ với nhau', () {
      expect(nguongThamHutTuyetDoi(50000000), 500000);
      expect(duDiaToiThieu(50000000), 1000000);
      expect(buocLamTron(50000000), 100000);
    });

    test('bước làm tròn bám họ 1·2·2,5·5 nên số đề xuất vẫn TRÒN', () {
      // 0,2 % của 12 triệu = 24.000 — một bội số xấu, người đọc sẽ thấy
      // 24.000 / 48.000 / 72.000. Họ 1·2·2,5·5 kéo nó lên 25.000.
      expect(buocLamTron(12000000), 25000);
      expect(buocLamTron(8000000), 20000, reason: '16.000 → 20.000');
    });

    // ⚠️ `duDiaToiThieu` cố ý KHÔNG có ca hành vi, và đó là **phát hiện** chứ
    // không phải thiếu sót: luật C4 đã bị C5 (`nguongCoNghia`) nuốt trọn. Nguồn
    // bị C4 loại có dư địa < 2 % thu nhập, nên phần cắt 25 % của nó < 0,5 % thu
    // nhập — dưới ngưỡng có nghĩa 1 %, tức C5 đã loại nó từ trước. Đúng cả ở
    // thu nhập 0 (sàn 100.000 so với 50.000): dư địa 100.000 cho phần cắt
    // 25.000, vẫn dưới 50.000.
    //
    // Biết được là nhờ **bản sai có chủ ý**: ca hành vi đầu tiên viết cho C4
    // đòi "danh sách rỗng" và **vẫn xanh** khi chưa neo gì cả, vì C5 tự lo việc
    // ấy. Cùng họ bẫy G43 — ca test phải đòi KẾT QUẢ, không chỉ đòi vắng mặt
    // thứ mình nghĩ tới.
    test('dư địa tối thiểu vẫn giãn theo thu nhập dù C5 đã nuốt luật C4', () {
      expect(duDiaToiThieu(2500000), 100000, reason: '2 % = 50.000, sàn thắng');
      expect(duDiaToiThieu(20000000), 400000);
    });

    test('thâm hụt tiền lẻ thôi được báo khi thu nhập cao', () {
      final hut = _duPhong('an', amount: 500000, duPhong: 600000); // hụt 100k
      final nguon = _duPhong('ng', amount: 5000000, duPhong: 1000000);

      expect(_kh([hut, nguon], thuNhapMoiThang: 0), isNotNull,
          reason: '100.000 ≥ sàn 50.000');
      expect(_kh([hut, nguon], thuNhapMoiThang: 50000000), isNull,
          reason: '100.000 < ngưỡng 500.000 của thu nhập 50 triệu');
    });

    test('bước làm tròn giãn theo thu nhập: cùng dư địa, hai số khác nhau', () {
      final hut = _duPhong('an', amount: 3000000, duPhong: 8000000);
      final le = _duPhong('le', amount: 2234567, duPhong: 1000000); // dư 1.234.567

      expect(_kh([hut, le], thuNhapMoiThang: 0)!.dong.single.soTien, 310000,
          reason: '25 % = 308.641,75, bước 10.000');
      expect(_kh([hut, le], thuNhapMoiThang: 12000000)!.dong.single.soTien, 300000,
          reason: 'cùng 308.641,75 nhưng bước 25.000');
    });
  });
}
