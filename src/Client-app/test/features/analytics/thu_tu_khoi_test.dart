/// Luật thuần của thứ tự khối trang Phân tích (dự án C việc ba). Spec
/// 2026-10-05-du-an-c-thu-tu-khoi-phan-tich-design.md mục 3.
library;

import 'package:flowmoney/features/analytics/domain/thu_tu_khoi.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 20, 9);

/// Một ngày `truoc` ngày trước hôm nay (`_now`).
DateTime _ngay(int truoc) => DateTime(2026, 10, 20 - truoc);

/// Một ngày mà [thang] xem lâu nhất (30 giây) và cụm đầu trang `dongTien`
/// được nhìn 5 giây — đúng dáng thật: mở trang là thấy cụm đầu.
List<GiayXem> _ngayThang(int truoc, CumKhoi thang, {int giay = 30, int dau = 5}) => [
      GiayXem(ngay: _ngay(truoc), cum: CumKhoi.dongTien, giay: dau),
      GiayXem(ngay: _ngay(truoc), cum: thang, giay: giay),
    ];

CumKhoi? _deXuat(List<GiayXem> g, {List<PhanHoiThuTu> ph = const [], List<CumKhoi>? thuTu}) =>
    deXuatDuaLen(giayXem: g, phanHoi: ph, thuTu: thuTu ?? thuTuTu(ph), now: _now);

void main() {
  group('CumKhoi', () {
    test('thứ tự mặc định đúng thứ tự trang hôm nay', () {
      expect(kThuTuCumMacDinh.map((c) => c.ma), [
        'dong_tien', 'tong', 'du_bao', 'xu_huong', 'chi_theo_ngay',
        'co_cau', 'theo_vi', 'top_chi', 'vay_no',
      ]);
    });
    test('mã lạ → null, không ném', () {
      expect(cumTuMa('co_cau'), CumKhoi.coCau);
      expect(cumTuMa('khoi_moi_chua_co'), isNull);
    });
    test('maNgay / ngayTuMa đi hai chiều, đệm số 0', () {
      expect(maNgay(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
      expect(ngayTuMa('2026-03-05'), DateTime(2026, 3, 5));
      expect(ngayTuMa('hong'), isNull);
    });
  });

  group('cumDangXem', () {
    test('cụm giao khung nhìn nhiều nhất thắng', () {
      final k = [
        const KhungCum(CumKhoi.tong, 0, 300),
        const KhungCum(CumKhoi.coCau, 300, 900),
      ];
      expect(cumDangXem(k, 200, 800), CumKhoi.coCau, reason: '100 px vs 500 px');
    });
    test('hoà → cụm đứng trên', () {
      final k = [
        const KhungCum(CumKhoi.coCau, 500, 1000),
        const KhungCum(CumKhoi.tong, 0, 500),
      ];
      expect(cumDangXem(k, 250, 750), CumKhoi.tong);
    });
    test('không cụm nào giao (hoặc cụm cao 0) → null', () {
      expect(cumDangXem([const KhungCum(CumKhoi.tong, 900, 900)], 0, 800), isNull);
      expect(cumDangXem(const [], 0, 800), isNull);
    });
  });

  group('thuTuTu', () {
    test('không phản hồi → mặc định', () => expect(thuTuTu(const []), kThuTuCumMacDinh));
    test('đưa lên hai lần: cụm mới nhất đứng đầu, cụm cũ thứ hai, còn lại giữ thứ tự', () {
      final t = thuTuTu([
        // Cố ý KHÔNG theo thứ tự thời gian — hàm phải tự xếp theo `luc`.
        PhanHoiThuTu(ketQua: kThuTuDuaLen, cum: CumKhoi.topChi, luc: DateTime(2026, 10, 2)),
        PhanHoiThuTu(ketQua: kThuTuDuaLen, cum: CumKhoi.coCau, luc: DateTime(2026, 10, 1)),
      ]);
      expect(t.take(3), [CumKhoi.topChi, CumKhoi.coCau, CumKhoi.dongTien]);
      expect(t, hasLength(9));
    });
    test('về mặc định xoá mọi lần đưa lên trước nó; bỏ qua không đổi thứ tự', () {
      final t = thuTuTu([
        PhanHoiThuTu(ketQua: kThuTuDuaLen, cum: CumKhoi.coCau, luc: DateTime(2026, 10, 1)),
        PhanHoiThuTu(ketQua: kThuTuVeMacDinh, luc: DateTime(2026, 10, 2)),
        PhanHoiThuTu(ketQua: kThuTuBoQua, cum: CumKhoi.topChi, luc: DateTime(2026, 10, 3)),
      ]);
      expect(t, kThuTuCumMacDinh);
    });
  });

  group('deXuatDuaLen', () {
    test('5 ngày, cụm thắng 3/5 (đúng 60 %) → đề xuất', () {
      final g = [
        for (final d in [1, 2, 3]) ..._ngayThang(d, CumKhoi.coCau),
        for (final d in [4, 5]) ..._ngayThang(d, CumKhoi.dongTien, giay: 1, dau: 40),
      ];
      expect(_deXuat(g), CumKhoi.coCau);
    });
    test('4 ngày → im (chưa đủ để nói)', () {
      final g = [for (final d in [1, 2, 3, 4]) ..._ngayThang(d, CumKhoi.coCau)];
      expect(_deXuat(g), isNull);
    });
    test('thắng 2/5 → im', () {
      final g = [
        for (final d in [1, 2]) ..._ngayThang(d, CumKhoi.coCau),
        for (final d in [3, 4, 5]) ..._ngayThang(d, CumKhoi.dongTien, giay: 1, dau: 40),
      ];
      expect(_deXuat(g), isNull);
    });
    test('ngày dưới 10 giây không tính', () {
      final g = [
        for (final d in [1, 2, 3, 4]) ..._ngayThang(d, CumKhoi.coCau),
        ..._ngayThang(5, CumKhoi.coCau, giay: 6, dau: 3), // 9 giây
      ];
      expect(_deXuat(g), isNull);
    });
    test('⚠️ HÔM NAY không tính', () {
      final g = [
        for (final d in [1, 2, 3, 4]) ..._ngayThang(d, CumKhoi.coCau),
        ..._ngayThang(0, CumKhoi.coCau),
      ];
      expect(_deXuat(g), isNull,
          reason: 'cụm thắng của ngày đang dở còn đổi — spec 3.2');
    });
    test('ngoài 30 ngày không tính (30 ngày trước vẫn tính)', () {
      final trong = [for (final d in [1, 2, 3, 30]) ..._ngayThang(d, CumKhoi.coCau)];
      expect(_deXuat([...trong, ..._ngayThang(31, CumKhoi.coCau)]), isNull);
      expect(_deXuat([...trong, ..._ngayThang(29, CumKhoi.coCau)]), CumKhoi.coCau);
    });
    test('cụm đã đứng đầu → im', () {
      final g = [for (final d in [1, 2, 3, 4, 5]) ..._ngayThang(d, CumKhoi.coCau)];
      final ph = [PhanHoiThuTu(ketQua: kThuTuDuaLen, cum: CumKhoi.coCau, luc: DateTime(2026, 9, 1))];
      expect(_deXuat(g, ph: ph), isNull);
    });
    test('cụm đứng trước không có giây nào (luôn ẩn) → im', () {
      final g = [
        for (final d in [1, 2, 3, 4, 5]) GiayXem(ngay: _ngay(d), cum: CumKhoi.coCau, giay: 30),
      ];
      expect(_deXuat(g), isNull, reason: 'spec 3.3 điều 3');
    });
    test('hoà giây → cụm đứng trước thắng ngày ấy', () {
      final g = [for (final d in [1, 2, 3, 4, 5]) ..._ngayThang(d, CumKhoi.coCau, giay: 20, dau: 20)];
      expect(_deXuat(g), isNull);
    });
    test('sau Bỏ qua: ngày cũ không tính, cần 5 ngày MỚI', () {
      final ph = [PhanHoiThuTu(ketQua: kThuTuBoQua, cum: CumKhoi.coCau, luc: _ngay(15).add(const Duration(hours: 20)))];
      final cu = [for (final d in [20, 19, 18, 17, 16]) ..._ngayThang(d, CumKhoi.coCau)];
      expect(_deXuat(cu, ph: ph), isNull);
      final moi4 = [for (final d in [14, 13, 12, 11]) ..._ngayThang(d, CumKhoi.coCau)];
      expect(_deXuat([...cu, ...moi4], ph: ph), isNull);
      expect(_deXuat([...cu, ...moi4, ..._ngayThang(10, CumKhoi.coCau)], ph: ph), CumKhoi.coCau);
    });
    test('ngày bấm Bỏ qua cũng không tính (chỉ ngày SAU)', () {
      final ph = [PhanHoiThuTu(ketQua: kThuTuBoQua, cum: CumKhoi.coCau, luc: _ngay(5).add(const Duration(hours: 8)))];
      final g = [for (final d in [5, 4, 3, 2, 1]) ..._ngayThang(d, CumKhoi.coCau)];
      expect(_deXuat(g, ph: ph), isNull);
    });
    test('sau Về mặc định → im với mọi cụm', () {
      final g = [for (final d in [10, 9, 8, 7, 6]) ..._ngayThang(d, CumKhoi.coCau)];
      final ph = [PhanHoiThuTu(ketQua: kThuTuVeMacDinh, luc: _ngay(5))];
      expect(_deXuat(g, ph: ph), isNull);
    });
    test('hai cụm cùng đạt → tỉ lệ thắng cao hơn', () {
      final ph = [PhanHoiThuTu(ketQua: kThuTuBoQua, cum: CumKhoi.coCau, luc: _ngay(12))];
      final g = [
        for (final d in [20, 19, 18, 17, 16, 15, 14, 13]) ..._ngayThang(d, CumKhoi.chiTheoNgay),
        for (final d in [11, 10, 9, 8, 7]) ..._ngayThang(d, CumKhoi.coCau),
      ];
      // chiTheoNgay: 8/13 ≈ 61,5 % · coCau (chỉ ngày sau 12): 5/5 = 100 %.
      expect(_deXuat(g, ph: ph), CumKhoi.coCau);
    });
  });
}
