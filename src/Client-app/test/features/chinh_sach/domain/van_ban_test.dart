import 'package:flowmoney/features/chinh_sach/domain/van_ban.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hai văn bản, đúng thứ tự, tra theo mã; mã lạ → null', () {
    expect(danhSachVanBan.map((v) => v.ma), ['dieu-khoan', 'bao-mat']);
    expect(vanBanTheoMa('bao-mat')!.tenNgan, 'Chính sách bảo mật');
    expect(vanBanTheoMa('dieu-khoan')!.tenNgan, 'Điều khoản sử dụng');
    expect(vanBanTheoMa('x'), isNull);
    expect(vanBanTheoMa(null), isNull);
  });

  test('mỗi văn bản: phiên bản 1.0, hiệu lực 16/11/2026, ≥ 10 mục, không mục / khối rỗng', () {
    for (final v in danhSachVanBan) {
      expect(v.phienBan, '1.0');
      expect(v.ngayHieuLuc, DateTime(2026, 11, 16));
      expect(v.muc.length, greaterThanOrEqualTo(10), reason: v.ma);
      expect(v.moDau.trim(), isNotEmpty);
      for (final m in v.muc) {
        expect(m.tieuDe.trim(), isNotEmpty);
        expect(m.khoi, isNotEmpty, reason: '${v.ma} / ${m.tieuDe}');
        for (final k in m.khoi) {
          expect(k.chu.trim(), isNotEmpty);
          expect(k.chu.contains('**'), isFalse, reason: 'dấu ** của tệp nháp phải bỏ');
        }
      }
    }
  });

  test('số mục khớp văn bản đã duyệt: Điều khoản 14, Chính sách 13', () {
    expect(vanBanTheoMa('dieu-khoan')!.muc.length, 14);
    expect(vanBanTheoMa('bao-mat')!.muc.length, 13);
  });

  test('không văn bản nào hứa "đồng ý lại" (app không hỏi lại), cả hai có email liên hệ', () {
    for (final v in danhSachVanBan) {
      final toan = [v.moDau, for (final m in v.muc) for (final k in m.khoi) k.chu].join('\n');
      expect(toan.toLowerCase().contains('đồng ý lại'), isFalse, reason: v.ma);
      expect(toan.contains('phubao12as@gmail.com'), isTrue, reason: v.ma);
    }
  });
}
