/// Lớp chắn thứ sáu `kiemKy` (G5 (b) cổng F, spec 2026-09-28 §3): chữ kỳ tương
/// đối của vế không thuộc kỳ của nguồn số → chặn. E21 nguyên văn là ca chính.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so_trang_chu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_cau_tra_loi.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_ky.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 28, 10);
  final trangChu = GoiSoTrangChu.tu(
      thu: 15135000, chi: 2241000, tongSoDu: 13004000, nganSach: const [], now: now);

  group('chuKyTrong / laChuKyTuongDoi', () {
    test('có dấu, không dấu, "năm ngoái" quy về "năm trước"; "tháng 9" không phải chữ kỳ tương đối', () {
      expect(chuKyTrong('Thu hôm nay là 15.135.000 đ'), {'hom nay'});
      expect(chuKyTrong('Nam nay bạn có 2 khoản thu'), {'nam nay'});
      expect(chuKyTrong('so với năm ngoái'), {'nam truoc'});
      expect(chuKyTrong('Trong tháng 9, tổng chi'), isEmpty);
      expect(chuKyTrong('chi nhiều hơn tháng trước'), {'thang truoc'});
      expect(laChuKyTuongDoi('tháng này'), isTrue);
      expect(laChuKyTuongDoi('mọi thời gian'), isFalse);
      expect(laChuKyTuongDoi('khoảng đã chọn'), isFalse);
    });
  });

  group('kiemKy — gói Trang chủ (bậc 1)', () {
    const e21 = 'Thu hôm nay là 15.135.000 đ, Chi hôm nay là 2.241.000 đ, còn lại là 12.894.000 đ.';
    test('⭐ E21 nguyên văn → CHẶN, kể cả qua kiemCauTraLoi', () {
      expect(kiemKy(e21, [trangChu]), isFalse);
      expect(kiemCauTraLoi(e21, [trangChu]), isFalse, reason: 'kiemCauTraLoi phải gọi lớp thứ sáu');
    });
    test('kyCua: thu / chi / còn lại là tháng này; tổng số dư là số hiện tại', () {
      final s = {for (final x in trangChu.soLieu) x.nhan: x};
      expect(trangChu.kyCua(s['Thu']!), {'tháng này'});
      expect(trangChu.kyCua(s['Còn lại']!), {'tháng này'});
      expect(trangChu.kyCua(s['Tổng số dư']!), isNull);
    });
    test('qua: đúng kỳ; không chữ kỳ; số HIỆN TẠI (tổng số dư) không xét kỳ', () {
      expect(kiemKy('Tháng này bạn thu 15.135.000 đ.', [trangChu]), isTrue);
      expect(kiemKy('Tổng thu 15.135.000 đ.', [trangChu]), isTrue);
      expect(kiemKy('Hôm nay tổng số dư của bạn là 13.004.000 đ.', [trangChu]), isTrue);
    });
  });

  group('kiemKy — gói tra cứu (theo lượt)', () {
    test('lượt tháng này: "hôm nay" → chặn; "tháng này" → qua', () {
      final g = GoiSoTraCuu()
        ..them('truy_van_giao_dich',
            KetQuaCongCu(hang: const [], tongHop: [soTien('Tổng chi', 2241000)], chuThem: const {'ky': 'tháng này'}));
      expect(kiemKy('Hôm nay bạn chi 2.241.000 đ.', [g]), isFalse);
      expect(kiemKy('Tháng này bạn chi 2.241.000 đ.', [g]), isTrue);
    });
    test('E13: lượt có so sánh mang cả kỳ đem ra so', () {
      final g = GoiSoTraCuu()
        ..them(
            'truy_van_giao_dich',
            KetQuaCongCu(hang: const [], tongHop: [
              soTien('Tổng chi', 2241000),
              soTien('Tổng chi tháng trước', 0),
            ], chuThem: const {'ky': 'tháng này', 'so_sanh_chi': 'chi nhiều hơn tháng trước'}));
      expect(kiemKy('Tháng này bạn chi 2.241.000 đ, trong khi tháng trước bạn chi 0 đ.', [g]), isTrue);
    });
    test('lượt mọi thời gian / kỳ tự do → không xét', () {
      for (final ky in ['mọi thời gian', 'khoảng đã chọn']) {
        final g = GoiSoTraCuu()
          ..them('truy_van_giao_dich',
              KetQuaCongCu(hang: const [], tongHop: [soDem('Số giao dịch', 3)], chuThem: {'ky': ky}));
        expect(kiemKy('Tháng này bạn nạp 3 giao dịch.', [g]), isTrue, reason: ky);
      }
    });
  });
}
