/// Dự án B — vệ sinh DỮ LIỆU của bộ định tuyến học (spec mục 5, 6).
///
/// Canh chừng điều gì:
/// - Bộ đo viết và commit TRƯỚC bộ huấn luyện, rồi KHOÁ. Sửa bộ đo sau khi đã
///   thấy kết quả là tự chấm mình — không exception nào báo, chỉ có con số đẹp
///   lên. Mã băm dưới đây biến mọi lần sửa thành một ca đỏ.
/// - Một câu nằm ở cả hai bộ là mô hình được chấm trên câu nó đã học.
library;

import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen_hoc.dart';
import 'package:flowmoney/features/ai_edge/domain/trong_so_dinh_tuyen.g.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/dinh_tuyen/du_lieu.dart';
import '../../../tool/dinh_tuyen/huan_luyen.dart';
import 'dinh_tuyen_72_cau_test.dart' show kBang72Cau;

/// Mã băm của `bo_do.tsv` tại commit đầu (2026-10-02). ĐỪNG cập nhật hằng này
/// để làm ca xanh: bộ đo đổi thì mọi số đo đã ghi mất nghĩa.
const String kBamBoDo = '5b6e8d5dbdebc371ffce5829873378dfc802c3c6f49a09d88b07f6c13422d544';

Map<String, int> _demNhan(List<MauDinhTuyen> mau) {
  final ra = <String, int>{};
  for (final m in mau) {
    ra[m.nhan] = (ra[m.nhan] ?? 0) + 1;
  }
  return ra;
}

void main() {
  group('docTsv', () {
    test('bỏ dòng trống và dòng chú thích', () {
      final m = docTsv('# chú thích\n\na\tcâu một\r\nb\tcâu hai\n');
      expect(m.map((x) => x.toString()), ['a\tcâu một', 'b\tcâu hai']);
    });

    test('cột thứ ba (tuỳ chọn): các tool KHÁC cũng trả lời đúng câu ấy, cách nhau dấu phẩy', () {
      final m = docTsv('a\tcâu một\tb, c\nb\tcâu hai\n');
      expect(m[0].chapNhan, {'b', 'c'});
      expect(m[1].chapNhan, isEmpty);
    });

    test('dòng thiếu TAB hoặc thiếu câu → FormatException', () {
      expect(() => docTsv('a câu không tab'), throwsFormatException);
      expect(() => docTsv('a\t  '), throwsFormatException);
    });
  });

  test('bamNoiDung không phụ thuộc kiểu xuống dòng (core.autocrlf)', () {
    expect(bamNoiDung('a\r\nb'), bamNoiDung('a\nb'));
    expect(bamNoiDung('a\nb'), isNot(bamNoiDung('a\nc')));
  });

  group('bộ đo', () {
    final mau = docTsv(docTep(kDuongBoDo));

    test('⭐ KHOÁ: nội dung không đổi kể từ commit đầu', () {
      expect(bamNoiDung(docTep(kDuongBoDo)), kBamBoDo,
          reason: 'bộ đo bị sửa sau khi khoá — số đo đã ghi không còn so được');
    });

    test('mọi nhãn thuộc mười nhãn', () {
      expect(mau.map((m) => m.nhan).toSet().difference(kMuoiNhan.toSet()), isEmpty);
    });

    test('hạn ngạch: 18 giao dịch · 12 không định tuyến · tám tool còn lại mỗi tool 4', () {
      final dem = _demNhan(mau);
      expect(mau, hasLength(62));
      expect(dem[kTenCongCuTruyVan], 18);
      expect(dem[kNhanKhongDinhTuyen], 12);
      for (final n in kMuoiNhan) {
        if (n == kTenCongCuTruyVan || n == kNhanKhongDinhTuyen) continue;
        expect(dem[n], 4, reason: n);
      }
    });

    test('không hai câu nào trùng nhau sau chuẩn hoá', () {
      final khoa = mau.map((m) => chuanHoaDinhTuyen(m.cau)).toList();
      expect(khoa.toSet(), hasLength(khoa.length));
    });

    test('bộ đo không mang cột chấp nhận — nhãn của nó là một tool duy nhất', () {
      expect(mau.where((m) => m.chapNhan.isNotEmpty), isEmpty);
    });
  });

  group('bộ huấn luyện', () {
    // `khuTrung` ném nếu một câu mang hai nhãn — chính lời gọi này là một ca canh.
    final mau = khuTrung(docTsv(docTep(kDuongBoHuanLuyen)));
    final dem = _demNhan(mau);

    test('mọi nhãn thuộc mười nhãn', () {
      expect(dem.keys.toSet().difference(kMuoiNhan.toSet()), isEmpty);
    });

    test('cột chấp nhận chỉ chứa nhãn tool hợp lệ, khác nhãn chính', () {
      for (final m in mau) {
        expect(m.chapNhan.difference(kMuoiNhan.toSet()), isEmpty, reason: m.cau);
        expect(m.chapNhan, isNot(contains(m.nhan)), reason: m.cau);
        expect(m.chapNhan, isNot(contains(kNhanKhongDinhTuyen)), reason: m.cau);
      }
    });

    test('đủ mẫu: mỗi nhãn ≥ 30 · giao dịch ≥ 100 · không định tuyến ≥ 60 (sau khử trùng)', () {
      for (final n in kMuoiNhan) {
        expect(dem[n] ?? 0, greaterThanOrEqualTo(30), reason: n);
      }
      expect(dem[kTenCongCuTruyVan], greaterThanOrEqualTo(100));
      expect(dem[kNhanKhongDinhTuyen], greaterThanOrEqualTo(60));
    });

    test('cả 72 câu đã đo có mặt với đúng nhãn của bảng', () {
      final nhanTheoCau = {for (final m in mau) chuanHoaDinhTuyen(m.cau): m.nhan};
      for (final e in kBang72Cau.entries) {
        expect(nhanTheoCau[chuanHoaDinhTuyen(e.value.$1)], e.value.$3, reason: '${e.key}: ${e.value.$1}');
      }
    });

    test('⭐ trọng số trong app KHÔNG cũ hơn bộ huấn luyện', () {
      expect(kBamBoHuanLuyen, bamNoiDung(docTep(kDuongBoHuanLuyen)),
          reason: 'bộ huấn luyện đã đổi mà chưa sinh lại trọng số — chạy '
              'flutter test test/tool/dinh_tuyen/huan_luyen_dinh_tuyen_test.dart --run-skipped');
    });

    test('trọng số: đủ mười nhãn, ngưỡng trong [0,60; 0,99], nhãn hành động có trong nhãn', () {
      expect(kTrongSoDinhTuyen.nhan.toSet(), kMuoiNhan.toSet());
      expect(kTrongSoDinhTuyen.nhan, hasLength(kMuoiNhan.length));
      expect(kNguongDinhTuyen, inInclusiveRange(0.60, 0.99));
      expect(kNhanMoHinhDuocDinhTuyen.difference(kTrongSoDinhTuyen.nhan.toSet()), isEmpty);
      expect(kNhanMoHinhDuocDinhTuyen, {kTenCongCuTruyVan},
          reason: 'người dùng chốt hướng 1 (2026-10-02): chỉ câu giao dịch');
    });

    test('⭐ không câu nào của bộ ĐO nằm trong bộ huấn luyện (sau chuẩn hoá)', () {
      final hoc = {for (final m in mau) chuanHoaDinhTuyen(m.cau)};
      final lot = [
        for (final m in docTsv(docTep(kDuongBoDo)))
          if (hoc.contains(chuanHoaDinhTuyen(m.cau))) m.cau,
      ];
      expect(lot, isEmpty, reason: 'mô hình sẽ được chấm trên câu nó đã học');
    });
  });
}
