/// Bộ điều phối MỘT lượt nền của tự chuyển tiền (spec 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 3.3).
library;

import 'package:flowmoney/core/nen/luot_nen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lich = (moc: DateTime(2026, 10, 11, 8), coTuDong: true);

  LuotNen dung(List<String> nhatKy, {int? id = 7, bool coToken = true, bool quetNem = false, bool lichNem = false}) =>
      LuotNen(
        docPhien: () async => id == null ? null : (idaccount: id, loaiPhien: 'Premium'),
        coToken: () async => coToken,
        datGoi: (i, loai) async => nhatKy.add('goi:$i:$loai'),
        datNhatKy: (i) => nhatKy.add('nhatKy:$i'),
        dongBo: (i) async => nhatKy.add('dongBo:$i'),
        quet: (i) async {
          if (quetNem) throw StateError('hỏng');
          nhatKy.add('quet:$i');
          return 0;
        },
        tinhLich: (i) async {
          if (lichNem) throw StateError('hỏng');
          return lich;
        },
      );

  test('thứ tự: gói → nhật ký → đồng bộ → quét → đồng bộ', () async {
    final nk = <String>[];
    expect(await dung(nk).chay(), lich);
    expect(nk, ['goi:7:Premium', 'nhatKy:7', 'dongBo:7', 'quet:7', 'dongBo:7'],
        reason: 'kéo về TRƯỚC khi quét: thấy máy kia đã trả / đã trích thì khỏi đua');
  });

  test('không phiên → không quét gì, lịch rỗng (Kotlin huỷ cả hai lượt)', () async {
    final nk = <String>[];
    expect(await dung(nk, id: null).chay(), (moc: null, coTuDong: false));
    expect(nk, isEmpty);
  });

  test('không token (đã đăng xuất) → như không phiên', () async {
    final nk = <String>[];
    expect(await dung(nk, coToken: false).chay(), (moc: null, coTuDong: false));
    expect(nk, isEmpty);
  });

  test('⭐ gói đặt TRƯỚC khi quét — thiếu là coQuyenNen trả true, Basic được tự trả ở nền', () async {
    final nk = <String>[];
    await dung(nk).chay();
    expect(nk.indexOf('goi:7:Premium'), lessThan(nk.indexOf('quet:7')));
  });

  test('quét ném lỗi → vẫn đồng bộ lần hai và vẫn trả lịch (worker không phải chờ hết 3 phút)', () async {
    final nk = <String>[];
    expect(await dung(nk, quetNem: true).chay(), lich);
    expect(nk.where((e) => e == 'dongBo:7'), hasLength(2));
  });

  test('tính lịch ném lỗi → giữ lượt định kỳ (không biết thì đừng huỷ)', () async {
    expect(await dung([], lichNem: true).chay(), (moc: null, coTuDong: true));
  });
}
