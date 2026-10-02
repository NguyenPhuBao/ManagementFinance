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
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/dinh_tuyen/du_lieu.dart';

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
  });
}
