/// Lịch chi tiêu — heatmap theo ngày của trang Phân tích (#6 khảo sát lần hai,
/// 2026-09-16).
///
/// Ba thứ đắt nhất ở đây, cả ba hỏng **im lặng** — lưới vẫn vẽ, chỉ là vẽ sai:
///
///  1. **Thang màu neo vào TRUNG BÌNH, không vào MAX.** Lấy max thì một ngày
///     mua sắm lớn làm phẳng cả tháng: 29 ngày còn lại rơi hết về bậc nhạt nhất
///     và lưới trông như tháng không tiêu gì.
///  2. **Ngày không chi phải khác ngày chi rất ít.** Gộp chúng là "tháng không
///     tiêu gì" trông y hệt "tháng tiêu ít".
///  3. **Lưới bắt đầu thứ Hai** (quy ước VN) và số ô trống đầu tháng suy từ
///     `weekday` của ngày 1. Lệch một ô là **cả tháng lệch một cột**, mà nhìn
///     vẫn rất hợp lý.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/features/analytics/domain/lich_chi_tieu.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';

DongGiaoDich _gd(
  String id,
  DateTime ngay,
  double soTien, {
  String loai = 'chi',
  String ten = 'Ăn uống',
}) =>
    DongGiaoDich(
      id: id,
      ngay: ngay,
      soTien: soTien,
      loai: loai,
      categoryId: 'c1',
      tenDanhMuc: ten,
      mauHex: null,
      icon: null,
      walletId: 'w1',
      tenVi: 'Tiền mặt',
      tieuDe: ten,
    );

void main() {
  group('lichChiTieuCua gom theo ngày', () {
    test('cộng dồn nhiều khoản cùng ngày, đếm số khoản, giữ khoản lớn nhất', () {
      final m = lichChiTieuCua([
        _gd('a', DateTime(2026, 9, 11, 8), 100000),
        _gd('b', DateTime(2026, 9, 11, 19), 200000, ten: 'Mua sắm'),
        _gd('c', DateTime(2026, 9, 11, 22), 50000),
        _gd('d', DateTime(2026, 9, 12), 70000),
      ]);

      final ngay11 = m[DateTime(2026, 9, 11)]!;
      expect(ngay11.tongChi, 350000);
      expect(ngay11.soKhoan, 3);
      expect(
        ngay11.lonNhat?.tenDanhMuc,
        'Mua sắm',
        reason: 'thẻ tóm tắt nói "Lớn nhất: …" nên phải là khoản lớn nhất của '
            'NGÀY ấy, không phải khoản đầu tiên gặp',
      );
      expect(m[DateTime(2026, 9, 12)]!.tongChi, 70000);
    });

    test('khoá là ngày đã CẮT GIỜ — hai khoản khác giờ vẫn cùng một ô', () {
      final m = lichChiTieuCua([
        _gd('a', DateTime(2026, 9, 11, 0, 1), 10),
        _gd('b', DateTime(2026, 9, 11, 23, 59), 20),
      ]);
      expect(m.length, 1);
      expect(m.keys.single, DateTime(2026, 9, 11));
    });

    test('chỉ đếm khoản CHI — thu và transfer không lên lịch', () {
      final m = lichChiTieuCua([
        _gd('a', DateTime(2026, 9, 11), 100, loai: 'thu'),
        _gd('b', DateTime(2026, 9, 11), 200, loai: 'transfer'),
        _gd('c', DateTime(2026, 9, 11), 300),
      ]);
      expect(m[DateTime(2026, 9, 11)]!.tongChi, 300);
      expect(
        m[DateTime(2026, 9, 11)]!.soKhoan,
        1,
        reason: 'đếm cả thu/transfer là ô đậm lên vì một ngày CHUYỂN VÍ',
      );
    });

    test('ngày không có khoản chi nào thì KHÔNG có khoá', () {
      final m = lichChiTieuCua([_gd('a', DateTime(2026, 9, 11), 100)]);
      expect(
        m[DateTime(2026, 9, 12)],
        isNull,
        reason: 'ô trống và ô 0 đồng là hai thứ khác nhau ở tầng dưới cùng',
      );
    });
  });

  group('bacNhiet neo vào TRUNG BÌNH', () {
    const tb = 100000.0;

    test('không chi là bậc 0, tách hẳn khỏi chi rất ít', () {
      expect(bacNhiet(0, trungBinh: tb), 0);
      expect(
        bacNhiet(1, trungBinh: tb),
        greaterThan(0),
        reason: 'một đồng vẫn là có tiêu; gộp vào bậc 0 là "tháng không tiêu '
            'gì" trông y hệt "tháng tiêu ít"',
      );
    });

    test('bốn bậc theo bội của trung bình', () {
      expect(bacNhiet(40000, trungBinh: tb), 1); // ≤ 0,5×
      expect(bacNhiet(90000, trungBinh: tb), 2); // ≤ 1×
      expect(bacNhiet(180000, trungBinh: tb), 3); // ≤ 2×
      expect(bacNhiet(500000, trungBinh: tb), 4); // > 2×
    });

    test('⚠️ một ngày rất lớn KHÔNG làm phẳng các ngày còn lại', () {
      // Tháng có 29 ngày quanh mức trung bình và một ngày gấp 30 lần. Neo vào
      // MAX thì 29 ngày ấy đều rơi về bậc 1; neo vào trung bình thì chúng vẫn
      // trải ra.
      const tbThang = 200000.0;
      final bac = [
        bacNhiet(100000, trungBinh: tbThang),
        bacNhiet(200000, trungBinh: tbThang),
        bacNhiet(400000, trungBinh: tbThang),
        bacNhiet(6000000, trungBinh: tbThang),
      ];
      expect(
        bac.toSet().length,
        4,
        reason: 'bốn mức chi khác nhau phải ra bốn bậc khác nhau; neo vào max '
            'thì ba mức đầu dính chung một bậc',
      );
    });

    test('trung bình bằng 0 thì mọi ngày CÓ chi đều là bậc cao nhất', () {
      // Xảy ra khi kỳ không có khoản chi nào — nhưng vẫn có thể có một ô lẻ do
      // dữ liệu lệch biên. Chia cho 0 ra Infinity, và Infinity so sánh được.
      expect(bacNhiet(0, trungBinh: 0), 0);
      expect(
        bacNhiet(1, trungBinh: 0),
        4,
        reason: 'không được ném, và không được trả bậc 0 cho một ngày có tiêu',
      );
    });
  });

  group('oLich — lưới bắt đầu thứ Hai', () {
    test('tháng 9/2026 bắt đầu thứ Ba nên có ĐÚNG một ô trống đầu lưới', () {
      final o = oLich(Ky.thang(2026, 9));
      expect(o.first, isNull);
      expect(o[1], DateTime(2026, 9, 1));
      expect(
        o.takeWhile((d) => d == null).length,
        1,
        reason: 'lệch một ô là cả tháng lệch một cột, mà nhìn vẫn rất hợp lý',
      );
      expect(o.last, DateTime(2026, 9, 30));
      expect(o.whereType<DateTime>().length, 30);
    });

    test('tháng bắt đầu thứ Hai thì KHÔNG có ô trống nào', () {
      // 01/06/2026 là thứ Hai.
      final o = oLich(Ky.thang(2026, 6));
      expect(o.first, DateTime(2026, 6, 1));
      expect(o.whereType<DateTime>().length, 30);
    });

    test('tháng bắt đầu Chủ nhật có SÁU ô trống — nhiều nhất có thể', () {
      // 01/11/2026 là Chủ nhật; Chủ nhật đứng CUỐI hàng theo quy ước VN.
      final o = oLich(Ky.thang(2026, 11));
      expect(o.takeWhile((d) => d == null).length, 6);
      expect(o[6], DateTime(2026, 11, 1));
    });

    test('tháng 2 năm nhuận có 29 ô, năm thường có 28', () {
      expect(oLich(Ky.thang(2028, 2)).whereType<DateTime>().length, 29);
      expect(oLich(Ky.thang(2027, 2)).whereType<DateTime>().length, 28);
    });

    test('tháng 12 không tràn sang năm sau', () {
      final o = oLich(Ky.thang(2026, 12));
      expect(o.whereType<DateTime>().length, 31);
      expect(o.last, DateTime(2026, 12, 31));
    });
  });

  group('nhanNgayLich', () {
    test('tên thứ tiếng Việt, Chủ nhật KHÔNG gọi là "Thứ Tám"', () {
      // 14/09/2026 là thứ Hai, 20/09 là Chủ nhật.
      expect(nhanNgayLich(DateTime(2026, 9, 14)), 'Thứ Hai 14/09');
      expect(nhanNgayLich(DateTime(2026, 9, 15)), 'Thứ Ba 15/09');
      expect(nhanNgayLich(DateTime(2026, 9, 20)), 'Chủ nhật 20/09');
    });

    test('ngày và tháng luôn hai chữ số', () {
      expect(nhanNgayLich(DateTime(2026, 9, 1)), 'Thứ Ba 01/09');
    });
  });
}
