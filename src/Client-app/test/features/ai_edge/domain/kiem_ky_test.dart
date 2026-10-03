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
    // Đo Realme 2026-10-02 (dự án B, Task 8): hôm ấy là 02/10 mà hai câu dưới
    // đây được HIỆN — số đúng (của tháng 9 / của mọi thời gian), chữ kỳ sai.
    // Bản trước ghi "mọi thời gian / kỳ tự do → không xét" (ca cũ ở chỗ này);
    // người dùng duyệt đảo: kỳ của lượt ĐÃ BIẾT, chỉ là không phải chữ kỳ tương
    // đối, nên chữ kỳ tương đối trong câu là lệch — trừ kỳ tương đương.
    GoiSoTraCuu luot(String ky, List<SoLieu> tongHop, {List<String> tuongDuong = const []}) =>
        GoiSoTraCuu()
          ..them(
              'truy_van_giao_dich',
              KetQuaCongCu(
                  hang: const [], tongHop: tongHop, chuThem: {'ky': ky}, kyTuongDuong: tuongDuong));

    test('⭐ E2 nguyên văn: lượt KỲ TỰ DO (tháng 9) mà câu nói "Tháng này" → CHẶN', () {
      final g = luot('khoảng đã chọn', [soTien('Tổng chi', 6741000)], tuongDuong: const ['tháng trước']);
      const e2 = 'Tháng này bạn đã chi tổng cộng 6.741.000 đ.';
      expect(kiemKy(e2, [g]), isFalse);
      expect(kiemCauTraLoi(e2, [g]), isFalse);
    });

    test('⭐ C19 nguyên văn: lượt MỌI THỜI GIAN mà câu nói "trong tháng này" → CHẶN', () {
      final g = GoiSoTraCuu()
        ..them(
            'truy_van_giao_dich',
            KetQuaCongCu(hang: [
              HangSoLieu(ten: 'test', trangThai: 'khoản chi', canhBao: false,
                  soLieu: [soTien('Số tiền', 35000, ten: 'test')]),
            ], tongHop: [soTien('Tổng chi', 45000)], chuThem: const {'ky': 'mọi thời gian'}));
      expect(kiemKy('Các khoản chi cho giáo dục trong tháng này là: test: 35.000 đ.', [g]), isFalse);
      expect(kiemKy('Tháng này bạn chi 45.000 đ.', [g]), isFalse);
    });

    test('kỳ tự do: chữ kỳ TƯƠNG ĐƯƠNG thì qua — 02/10 hỏi "tháng 9" mà câu nói "tháng trước" là ĐÚNG', () {
      final g = luot('khoảng đã chọn', [soTien('Tổng chi', 6741000)], tuongDuong: const ['tháng trước']);
      expect(kiemKy('Tháng trước bạn đã chi tổng cộng 6.741.000 đ.', [g]), isTrue,
          reason: 'chắn oan đã vấp nhiều lần (bẫy 4.49, 4.50) — câu đúng không được chặn');
      expect(kiemKy('Hôm qua bạn đã chi tổng cộng 6.741.000 đ.', [g]), isFalse);
    });

    test('kỳ tự do / mọi thời gian: câu KHÔNG có chữ kỳ tương đối thì qua như cũ', () {
      for (final ky in ['mọi thời gian', 'khoảng đã chọn']) {
        final g = luot(ky, [soTien('Tổng chi', 6741000), soDem('Số giao dịch', 3)]);
        expect(kiemKy('Trong tháng 9, tổng chi của bạn là 6.741.000 đ.', [g]), isTrue, reason: ky);
        expect(kiemKy('Bạn có 3 giao dịch.', [g]), isTrue, reason: ky);
      }
    });

    test('kỳ tự do có so sánh: chữ kỳ của phép so vẫn qua', () {
      final g = GoiSoTraCuu()
        ..them(
            'truy_van_giao_dich',
            KetQuaCongCu(hang: const [], tongHop: [
              soTien('Tổng chi', 6741000),
              soTien('Tổng chi cùng kỳ năm trước', 0),
            ], chuThem: const {'ky': 'khoảng đã chọn', 'so_sanh_chi': 'chi nhiều hơn cùng kỳ năm trước'}));
      expect(kiemKy('Bạn chi 6.741.000 đ, trong khi năm trước chi 0 đ.', [g]), isTrue);
    });

    test('lượt KHÔNG khai kỳ, hoặc khai một chữ kỳ lạ → không xét (kỳ chưa biết thì cho qua)', () {
      final khong = GoiSoTraCuu()
        ..them('danh_sach_vi', KetQuaCongCu(hang: const [], tongHop: [soTien('Tổng số dư', 13004000)]));
      expect(kiemKy('Hôm nay tổng số dư của bạn là 13.004.000 đ.', [khong]), isTrue);
      final la = luot('ba mươi ngày tới', [soTien('Tổng cam kết', 500000)]);
      expect(kiemKy('Tháng này bạn phải trả 500.000 đ.', [la]), isTrue);
    });
  });
}
