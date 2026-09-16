/// Mốc so sánh của hai thẻ tổng trang Phân tích (#2 khảo sát, 2026-09-16).
///
/// Trang này vốn chỉ so với **kỳ liền trước**. Chip thứ hai mở thêm mốc **cùng
/// kỳ năm trước**, và `nenSoSanh` là **định nghĩa duy nhất** của việc "chip nào
/// thì lấy con số nào, và gọi kỳ ấy là gì".
///
/// Có một hàm riêng thay vì hai nhánh `if` trong widget, vì cặp *số* và *nhãn*
/// phải đi cùng nhau: lấy số của năm trước mà in nhãn của kỳ trước thì thẻ nói
/// một câu hoàn toàn hợp lý và hoàn toàn sai — không exception, không log.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/analytics/domain/moc_so_sanh.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';

void main() {
  const kyTruoc = TongThuChi(thu: 100, chi: 40);
  const namTruoc = TongThuChi(thu: 200, chi: 80);
  final ky = Ky.thang(2026, 9);

  group('nenSoSanh chọn đúng CẶP số và nhãn', () {
    test('chip "kỳ trước" lấy số kỳ trước và tên kỳ liền trước', () {
      final n = nenSoSanh(
        moc: MocSoSanh.kyTruoc,
        ky: ky,
        kyTruoc: kyTruoc,
        namTruoc: namTruoc,
      );
      expect(n.nen, kyTruoc);
      expect(n.nhan, nhanKyTruoc(ky));
      expect(n.nhan, 'T8');
    });

    test('chip "cùng kỳ năm trước" lấy số năm trước và tên có năm', () {
      final n = nenSoSanh(
        moc: MocSoSanh.cungKyNamTruoc,
        ky: ky,
        kyTruoc: kyTruoc,
        namTruoc: namTruoc,
      );
      expect(
        n.nen,
        namTruoc,
        reason: 'lấy nhầm số kỳ trước thì thẻ vẫn hiện một phần trăm hợp lý',
      );
      expect(n.nhan, 'T9 2025');
    });

    test('nhãn kỳ trước KHÔNG mang năm, nhãn năm trước thì CÓ', () {
      final a = nenSoSanh(
        moc: MocSoSanh.kyTruoc,
        ky: ky,
        kyTruoc: kyTruoc,
        namTruoc: namTruoc,
      );
      final b = nenSoSanh(
        moc: MocSoSanh.cungKyNamTruoc,
        ky: ky,
        kyTruoc: kyTruoc,
        namTruoc: namTruoc,
      );
      expect(a.nhan.contains('2025'), isFalse);
      expect(
        b.nhan.contains('2025'),
        isTrue,
        reason: 'cả câu nói về năm ngoái — bỏ năm là bỏ chính thông tin cần đọc',
      );
    });
  });

  group('nhãn chip', () {
    test('hai chip, hai chữ khác nhau', () {
      expect(MocSoSanh.kyTruoc.nhanChip, 'So với kỳ trước');
      expect(MocSoSanh.cungKyNamTruoc.nhanChip, 'Cùng kỳ năm trước');
    });

    test('chip đầu là mặc định — người dùng cũ không thấy gì đổi', () {
      expect(MocSoSanh.values.first, MocSoSanh.kyTruoc);
    });
  });

  group('phần trăm suy từ nền, không suy từ chip', () {
    test('nền bằng 0 thì không có phần trăm — đừng bịa "tăng 100%"', () {
      final n = nenSoSanh(
        moc: MocSoSanh.cungKyNamTruoc,
        ky: ky,
        kyTruoc: kyTruoc,
        namTruoc: const TongThuChi(thu: 0, chi: 0),
      );
      expect(phanTramSoVoi(150, n.nen.thu), isNull);
    });

    test('tài khoản chưa có dữ liệu năm trước là ca THƯỜNG, không phải ca hiếm',
        () {
      // Tài khoản mới lập trong năm: mọi kỳ đều không có nền năm trước.
      for (final k in [
        Ky.thang(2026, 9),
        Ky.quy(2026, 3),
        Ky.tuan(DateTime(2026, 9, 16)),
      ]) {
        final n = nenSoSanh(
          moc: MocSoSanh.cungKyNamTruoc,
          ky: k,
          kyTruoc: kyTruoc,
          namTruoc: const TongThuChi(thu: 0, chi: 0),
        );
        expect(phanTramSoVoi(150, n.nen.thu), isNull);
        expect(phanTramSoVoi(60, n.nen.chi), isNull);
      }
    });
  });
}
