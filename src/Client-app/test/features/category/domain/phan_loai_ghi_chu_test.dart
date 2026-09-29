/// B1 — Naive Bayes cục bộ gợi ý danh mục từ ghi chú. Mọi con số dưới đây TÍNH TAY
/// được: bộ mười mẫu, hai danh mục, xem khối chú thích của `muoiMau`.
library;

import 'package:flowmoney/features/bill/domain/bill_note.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/goal/domain/goal_history_direction.dart';
import 'package:flutter_test/flutter_test.dart';

MauGhiChu m(String c, String ghiChu, [int ngay = 1]) =>
    MauGhiChu(categoryId: c, amTiet: amTietCua(ghiChu), ngay: DateTime(2026, 9, ngay));

// Di chuyển (dc) 5 mẫu, S = 3+3+1+2+3 = 12; Ăn uống (au) 5 mẫu, S = 2+1+2+2+2 = 9.
// V = {grab di lam ve nha xang xe san bay cafe sang com trua an chieu} → |V| = 15.
final muoiMau = [
  m('dc', 'grab đi làm'), m('dc', 'grab về nhà'), m('dc', 'Grab'), m('dc', 'xăng xe'),
  m('dc', 'grab sân bay'),
  m('au', 'cafe sáng'), m('au', 'cafe'), m('au', 'cơm trưa'), m('au', 'ăn sáng'), m('au', 'cafe chiều'),
];
const hai = {'dc', 'au'};

void main() {
  group('amTietCua', () {
    test('bỏ dấu, chữ thường, giữ thứ tự; "cà phê" ≡ "ca phe"', () {
      expect(amTietCua('Cà  Phê sáng!'), ['ca', 'phe', 'sang']);
      expect(amTietCua('ca phe sang'), ['ca', 'phe', 'sang']);
    });
    test('bỏ âm tiết toàn chữ số, giữ âm tiết có chữ', () {
      expect(amTietCua('tiền điện tháng 9 2026 500k'), ['tien', 'dien', 'thang', '500k']);
    });
    test('rỗng / chỉ dấu câu → rỗng', () {
      expect(amTietCua('  ...  '), isEmpty);
    });
  });

  group('laGhiChuMay / mauHocTu', () {
    test('⭐ mọi ghi chú máy sinh bị loại — học chúng là dạy "thanh toán hóa đơn" là một danh mục', () {
      for (final g in [
        '${kGhiChuTraHoaDon}Tiền điện',
        '${kGhiChuNapMucTieu}MuaXe',
        '${kGhiChuRutMucTieu}MuaXe',
        'Tích lũy nhận từ Tiền mặt',
      ]) {
        expect(laGhiChuMay(loai: 'chi', categoryId: 'c', ghiChu: g), isTrue, reason: g);
      }
      expect(laGhiChuMay(loai: 'thu', categoryId: null, ghiChu: 'Điều chỉnh số dư'), isTrue);
      expect(laGhiChuMay(loai: 'thu', categoryId: null, ghiChu: 'Số dư ban đầu'), isTrue);
      expect(laGhiChuMay(loai: 'chi', categoryId: 'c', ghiChu: 'cafe'), isFalse);
    });
    test('bỏ: không danh mục, ghi chú rỗng, khoản chuyển, ghi chú chỉ toàn số; giữ phần còn lại', () {
      final ra = mauHocTu([
        (loai: 'chi', categoryId: null, ghiChu: 'cafe', ngay: DateTime(2026, 9, 1)),
        (loai: 'chi', categoryId: 'au', ghiChu: '   ', ngay: DateTime(2026, 9, 1)),
        (loai: 'transfer', categoryId: 'au', ghiChu: 'cafe', ngay: DateTime(2026, 9, 1)),
        (loai: 'chi', categoryId: 'au', ghiChu: '50000', ngay: DateTime(2026, 9, 1)),
        (loai: 'chi', categoryId: 'au', ghiChu: 'Cafe sáng', ngay: DateTime(2026, 9, 2)),
      ]);
      // ⚠️ Không so bản ghi chứa List: Dart so List theo danh tính, ca đỏ oan.
      expect(ra.single.categoryId, 'au');
      expect(ra.single.amTiet, ['cafe', 'sang']);
    });
  });

  group('BoPhanLoaiGhiChu.doan', () {
    final bo = BoPhanLoaiGhiChu.hoc(muoiMau);

    test('⭐ "grab tối" → Di chuyển, xác suất tính tay 0,8163', () {
      // P(grab|dc) = (4+1)/(12+15) = 5/27; P(grab|au) = (0+1)/(9+15) = 1/24; tiên nghiệm bằng nhau.
      // "toi" chưa gặp → bỏ qua. Hậu nghiệm dc = (5/27) / (5/27 + 1/24) = 0,81633.
      final d = bo.doan('grab tối', hopLe: hai)!;
      expect(d.categoryId, 'dc');
      expect(d.xacSuat, closeTo(0.81633, 1e-4));
      expect((d.cumBoDau, d.soLanCung, d.soLanTong), ('grab', 4, 4));
    });

    test('dưới ngưỡng 0,6 → null: "grab cafe" hậu nghiệm Ăn uống 0,503', () {
      // dc: (5/27)(1/27) = 0,006859; au: (1/24)(4/24) = 0,006944 → au = 0,5031.
      expect(bo.doan('grab cafe', hopLe: hai), isNull);
    });

    test('tổng mẫu < 10 → null (chín mẫu)', () {
      expect(BoPhanLoaiGhiChu.hoc(muoiMau.sublist(0, 9)).doan('grab', hopLe: hai), isNull);
    });

    test('danh mục đứng đầu < 3 mẫu → null (hậu nghiệm 0,83 — CHỈ chốt số mẫu chặn)', () {
      // "sửa phanh" thì hậu nghiệm chỉ 0,43 — bị ngưỡng xác suất chặn, ca không canh chốt số mẫu.
      final b = BoPhanLoaiGhiChu.hoc([...muoiMau, m('sx', 'sửa xe'), m('sx', 'sửa xe máy')]);
      expect(b.doan('sửa xe máy', hopLe: {...hai, 'sx'}), isNull);
    });

    test('không âm tiết nào đã gặp → null', () {
      expect(bo.doan('điện thoại', hopLe: hai), isNull);
    });

    test('hoà ở đỉnh → null', () {
      final hoa = BoPhanLoaiGhiChu.hoc([
        for (final t in ['mot', 'hai', 'ba', 'bon', 'nam']) m('p', 'chung $t'),
        for (final t in ['sau', 'bay', 'tam', 'chin', 'muoi']) m('q', 'chung $t'),
      ]);
      expect(hoa.doan('chung', hopLe: {'p', 'q'}), isNull);
    });

    test('⭐ hopLe chỉ LỌC ứng viên: Di chuyển bị xoá thì "grab" KHÔNG thành Ăn uống', () {
      // Tính trên mọi danh mục: au chỉ 0,18 → dưới ngưỡng. Và au không có bằng chứng nào cho "grab".
      expect(bo.doan('grab', hopLe: {'au'}), isNull);
    });

    test('⭐ hopLe chỉ lọc — "grab cafe" khi Di chuyển bị xoá: Ăn uống CÓ bằng chứng mà vẫn không lên', () {
      // Trên mọi danh mục Ăn uống chỉ 0,503 (ca dưới ngưỡng). Chấm điểm chỉ trên hopLe thì nó thành 100 %.
      expect(bo.doan('grab cafe', hopLe: {'au'}), isNull);
    });

    test('⭐ chốt bằng chứng: tiên nghiệm áp đảo KHÔNG phải bằng chứng', () {
      // au 12 mẫu "com" (S = 12), dc 1 mẫu "grab xe om" (S = 3), |V| = 4. Hỏi "grab":
      // au = (12/13)(1/16) = 0,0577; dc = (1/13)(2/7) = 0,0220 → au 0,724 ≥ 0,6, đủ mẫu —
      // nhưng Ăn uống chưa từng gặp "grab" nên không được đoán.
      final b = BoPhanLoaiGhiChu.hoc([
        for (var i = 0; i < 12; i++) m('au', 'cơm'),
        m('dc', 'grab xe ôm'),
      ]);
      expect(b.doan('grab', hopLe: hai), isNull);
    });

    test('danh mục có ĐÚNG 3 mẫu thì đủ (ngưỡng là "< 3")', () {
      // sx: (3/13)(4/26)(4/26) = 0,005462; dc 0,000855; au 0,000528 → sx 0,798.
      final b = BoPhanLoaiGhiChu.hoc([...muoiMau, m('sx', 'sửa xe'), m('sx', 'sửa xe máy'), m('sx', 'sửa xe đạp')]);
      expect(b.doan('sửa xe', hopLe: {...hai, 'sx'})?.categoryId, 'sx');
    });

    test('⭐ đếm NHỊ PHÂN: ghi chú "cafe cafe" là một lần bằng chứng, không phải hai', () {
      final lap = BoPhanLoaiGhiChu.hoc([
        for (final x in muoiMau) x.amTiet.join(' ') == 'cafe' ? m('au', 'cafe cafe') : x,
      ]);
      expect(lap.doan('cafe sáng', hopLe: hai)!.xacSuat,
          closeTo(bo.doan('cafe sáng', hopLe: hai)!.xacSuat, 1e-12));
    });

    test('tatCap chặn đúng cặp (cụm, danh mục)', () {
      expect(bo.doan('grab tối', hopLe: hai, tatCap: {('grab', 'dc')}), isNull);
      expect(bo.doan('grab tối', hopLe: hai, tatCap: {('grab', 'au')}), isNotNull);
    });
  });

  group('câu lý do', () {
    test('⭐ in CỤM có dấu người dùng đã gõ, đếm theo cụm: "cà phê" chứ không "phê"', () {
      final b = BoPhanLoaiGhiChu.hoc([
        ...muoiMau.where((x) => x.categoryId == 'dc'),
        m('au', 'cà phê sáng'), m('au', 'ca phe'), m('au', 'cà phê chiều'), m('au', 'cơm trưa'), m('au', 'ăn sáng'),
      ]);
      final d = b.doan('Cà phê muối', hopLe: hai)!;
      expect(d.cumBoDau, 'ca phe');
      expect((d.soLanCung, d.soLanTong), (3, 3));
      expect(cauLyDoHoc(d, ghiChuGoc: 'Cà phê muối', tenDanhMuc: 'Ăn uống'),
          'Bạn thường ghi “Cà phê” cho Ăn uống (3/3 lần).');
    });
    test('cụm mở rộng sang PHẢI: "trà sữa" — hai âm tiết dài bằng nhau, chọn âm đầu rồi nối phải', () {
      // au S = 2+4+2+2+2 = 12, |V| = 17: au = (4/29)(4/29) = 0,0190, dc = (1/29)(1/29) → au 0,94.
      final b = BoPhanLoaiGhiChu.hoc([
        ...muoiMau.where((x) => x.categoryId == 'dc'),
        m('au', 'trà sữa'), m('au', 'trà sữa trân châu'), m('au', 'trà sữa'), m('au', 'cơm trưa'), m('au', 'ăn sáng'),
      ]);
      final d = b.doan('trà sữa đào', hopLe: hai)!;
      expect(d.cumBoDau, 'tra sua');
      expect(cauLyDoHoc(d, ghiChuGoc: 'trà sữa đào', tenDanhMuc: 'Ăn uống'),
          'Bạn thường ghi “trà sữa” cho Ăn uống (3/3 lần).');
    });
    test('cụm không mở rộng khi phần mở rộng hiếm hơn: "cafe sáng" → "cafe"', () {
      final d = BoPhanLoaiGhiChu.hoc(muoiMau).doan('cafe sáng', hopLe: hai)!;
      expect(d.cumBoDau, 'cafe');
    });
    test('cauLyDoTuKhoa giữ nguyên câu cũ', () {
      expect(cauLyDoTuKhoa('cafe'), 'Khớp với “cafe” trong ghi chú.');
    });
  });

  group('tatCapTu — thôi gợi ý sau 2 lần bỏ qua, mở lại sau 3 mẫu mới', () {
    PhanHoiGoiY bq(String cum, String c, int ngay, {String nguon = 'hoc', String kq = 'bo_qua'}) => PhanHoiGoiY(
        nguon: nguon, amTietChinh: cum, goiYCategoryId: c, ketQua: kq, createdAt: DateTime(2026, 9, ngay));
    test('⭐ 2 lần bo_qua nguồn học → chặn; 1 lần → chưa', () {
      expect(tatCapTu([bq('grab', 'dc', 10), bq('grab', 'dc', 11)], muoiMau), {('grab', 'dc')});
      expect(tatCapTu([bq('grab', 'dc', 10)], muoiMau), isEmpty);
    });
    test('nguồn từ khoá và kết quả chon / khac không tính', () {
      expect(tatCapTu([bq('grab', 'dc', 10, nguon: 'tu_khoa'), bq('grab', 'dc', 11, nguon: 'tu_khoa')], muoiMau), isEmpty);
      expect(tatCapTu([bq('grab', 'dc', 10, kq: 'chon'), bq('grab', 'dc', 11, kq: 'khac')], muoiMau), isEmpty);
    });
    test('⭐ mở lại khi có 3 mẫu MỚI (ngày sau lần bo_qua cuối) chứa cụm cho đúng danh mục', () {
      final moi = [m('dc', 'grab tối', 12), m('dc', 'grab đón con', 13), m('dc', 'grab', 14)];
      expect(tatCapTu([bq('grab', 'dc', 10), bq('grab', 'dc', 11)], [...muoiMau, ...moi]), isEmpty);
      expect(tatCapTu([bq('grab', 'dc', 10), bq('grab', 'dc', 11)], [...muoiMau, ...moi.take(2)]), {('grab', 'dc')},
          reason: 'hai mẫu mới chưa đủ');
    });
    test('mẫu mới cho danh mục KHÁC không mở lại: ba lần "grab food" cho Ăn uống không phải bằng chứng cho Di chuyển', () {
      final khac = [m('au', 'grab food', 12), m('au', 'grab food trưa', 13), m('au', 'grab food tối', 14)];
      expect(tatCapTu([bq('grab', 'dc', 10), bq('grab', 'dc', 11)], [...muoiMau, ...khac]), {('grab', 'dc')});
    });
    test('mẫu cũ (trước lần bo_qua cuối) không tính vào mở lại', () {
      final cu = [m('dc', 'grab a', 5), m('dc', 'grab b', 6), m('dc', 'grab c', 7)];
      expect(tatCapTu([bq('grab', 'dc', 10), bq('grab', 'dc', 11)], [...muoiMau, ...cu]), {('grab', 'dc')});
    });
  });
}
