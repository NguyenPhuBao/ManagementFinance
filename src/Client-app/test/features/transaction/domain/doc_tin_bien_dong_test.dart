/// D1 — bộ đọc tin biến động số dư (spec `2026-09-28-d1-doc-bien-dong-so-du-design.md` §3.1).
///
/// Mẫu là **năm tin thật** ở `docs/AI/Classify.md` §4.3 (backend chụp 2026-09-02, duyệt làm baseline
/// ở đơn `CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md` mục 5 câu 3). Số tài khoản, tên, mã giao dịch trong
/// mẫu là của backend đã công bố trong tài liệu ấy — không phải dữ liệu người dùng.
///
/// ⚠️ Vietcombank, MoMo, ZaloPay, SMS **chưa có mẫu** → chưa có khuôn (Task 1 thu trên máy thật).
library;

import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';
import 'package:flutter_test/flutter_test.dart';

final _luc = DateTime(2026, 9, 2, 10, 53);

TinBienDong? doc(String nguon, String tieuDe, String noiDung) =>
    docTinBienDong(nguon: nguon, tieuDe: tieuDe, noiDung: noiDung, luc: _luc);

void main() {
  group('BIDV (SmartBanking) — mẫu 1', () {
    const nd = 'Thời gian giao dịch: 10:52 02/09/2026 Tài khoản thanh toán: 5111012066 '
        'Số tiền GD: -1,199,000 VND Số dư cuối: 110 VND '
        'Nội dung giao dịch: CASHINMOMO_0355281276_144878879528 Mã giao dịch: 055104Tm-8BoOcczKT';
    test('⭐ trừ tiền: số tiền, chiều chi, giờ trong tin, đuôi TK, mã GD, nội dung', () {
      final t = doc(kNguonBidv, 'Thông báo BIDV', nd)!;
      expect(t.soTien, 1199000);
      expect(t.chieu, 'chi');
      expect(t.thoiGian, DateTime(2026, 9, 2, 10, 52), reason: 'giờ TRONG tin, không phải giờ thông báo');
      expect(t.duoiTaiKhoan, '2066');
      expect(t.maGiaoDich, '055104Tm-8BoOcczKT');
      expect(t.noiDung, 'CASHINMOMO_0355281276_144878879528');
      expect(t.nguon, kNguonBidv);
    });
    test('cộng tiền (dấu +) → thu', () {
      final t = doc(kNguonBidv, 'Thông báo BIDV', nd.replaceFirst('-1,199,000', '+500,000'))!;
      expect((t.soTien, t.chieu), (500000.0, 'thu'));
    });
  });

  group('MB Bank — mẫu 2, 3, 4', () {
    const tieuDe = 'Thông báo biến động số dư';
    test('⭐ nhận tiền: năm hai chữ số 26 → 2026, đuôi TK từ dạng mask, mã GD sau "Ma GD"', () {
      final t = doc(kNguonMb, tieuDe,
          'TK 25xxx999|GD: +1,200,000VND 02/09/26 15:33 |SD: 1,200,007VND|TU: NGUYEN PHU BAO - 5111012066'
          '|ND: NGUYEN PHU BAO Chuyen tien- Ma GD ACSP/ 9l191181')!;
      expect(t.soTien, 1200000);
      expect(t.chieu, 'thu');
      expect(t.thoiGian, DateTime(2026, 9, 2, 15, 33));
      expect(t.duoiTaiKhoan, '999');
      expect(t.maGiaoDich, 'ACSP/ 9l191181');
      expect(t.noiDung, 'NGUYEN PHU BAO Chuyen tien- Ma GD ACSP/ 9l191181');
    });
    test('trừ tiền, không "Ma GD" → maGiaoDich null', () {
      final t = doc(kNguonMb, tieuDe,
          'TK 25xxx999|GD: -1,200,000VND 02/09/26 15:29 |SD: 7VND|DEN: NGUYEN PHU BAO - 51110001012066'
          '|ND: Bien dong so du mbbank bidv')!;
      expect((t.soTien, t.chieu), (1200000.0, 'chi'));
      expect(t.maGiaoDich, isNull);
      expect(t.noiDung, 'Bien dong so du mbbank bidv');
    });
    test('mẫu 4: không có TU/DEN, nội dung là chuỗi MOMO-CASHOUT', () {
      final t = doc(kNguonMb, tieuDe,
          'TK 25xxx999|GD: +1,000,000VND 02/09/26 11:02 |SD: 1,200,007VND'
          '|ND: MOMO-CASHOUT-0355281276-OQCOeloMiFpw-144880413722')!;
      expect(t.soTien, 1000000);
      expect(t.thoiGian, DateTime(2026, 9, 2, 11, 2));
      expect(t.noiDung, 'MOMO-CASHOUT-0355281276-OQCOeloMiFpw-144880413722');
    });
  });

  group('Techcombank — mẫu 5', () {
    test('⭐ số tiền ở TIÊU ĐỀ "+ VND 208,080", giờ có giây, mã GD là dãy số cuối', () {
      final t = doc(kNguonTcb, '+ VND 208,080',
          'Tài khoản: 5555047777777 Số dư: VND 218,042 '
          'RUT VI MOMO 040204008977 208080 VND 02/09/2026 10:57:56 144879146167')!;
      expect(t.soTien, 208080);
      expect(t.chieu, 'thu');
      expect(t.thoiGian, DateTime(2026, 9, 2, 10, 57, 56));
      expect(t.duoiTaiKhoan, '7777');
      expect(t.maGiaoDich, '144879146167');
      expect(t.noiDung, 'RUT VI MOMO 040204008977 208080 VND 02/09/2026 10:57:56 144879146167');
    });
    test('trừ tiền "- VND 45,000" → chi; tiêu đề và nội dung gộp làm một vẫn đọc được', () {
      final t = doc(kNguonTcb, '',
          '- VND 45,000 Tài khoản: 5555047777777 Số dư: VND 173,042 PHO 24 02/09/2026 12:01:00 144879999999')!;
      expect((t.soTien, t.chieu, t.maGiaoDich), (45000.0, 'chi', '144879999999'));
    });
  });

  group('không đọc', () {
    test('OTP / mã xác thực → null dù có số kèm dấu (Kotlin đã lọc, đây là lớp thứ hai)', () {
      expect(doc(kNguonMb, 'MB Bank', 'Ma OTP cua ban la 482913. Khong chia se. GD: -1,000VND'), isNull);
      expect(doc(kNguonBidv, 'BIDV', 'Mã xác thực: 123456 Số tiền GD: -1,000 VND'), isNull);
    });
    test('quảng cáo có số → null (không khớp khuôn nguồn)', () {
      expect(doc(kNguonBidv, 'Ưu đãi', 'Giảm ngay 50,000 VND khi thanh toán qua QR từ 02/09/2026'), isNull);
      expect(doc(kNguonTcb, 'Techcombank', 'Nhận ngay 100,000 VND khi mở thẻ'), isNull);
      expect(doc(kNguonTcb, 'Ưu đãi', 'Hoàn tiền VND 100,000 cho thẻ mới kích hoạt'), isNull,
          reason: '"VND 100,000" KHÔNG có dấu ± phía trước — khuôn Techcombank đòi dấu, nếu không một '
              'tin quảng cáo thành một khoản chi 100.000 đ chờ ghi (bản sai bỏ dấu phải đỏ ở đây)');
    });
    test('nguồn chưa có khuôn (Vietcombank, MoMo, ZaloPay, SMS) → null, không ném', () {
      for (final n in [kNguonVcb, kNguonMomo, kNguonZalopay, kNguonSms, 'App lạ']) {
        expect(doc(n, 'x', 'GD: -1,000VND 02/09/26 15:33'), isNull, reason: n);
      }
    });
    test('không có giờ trong tin → lấy giờ thông báo', () {
      final t = doc(kNguonBidv, 'Thông báo BIDV',
          'Tài khoản thanh toán: 5111012066 Số tiền GD: -20,000 VND Số dư cuối: 90 VND '
          'Nội dung giao dịch: GUI XE Mã giao dịch: ABC')!;
      expect(t.thoiGian, _luc);
    });
  });

  test('kNguonBienDong có đủ BẢY nguồn của danh sách trắng (spec §2), đúng chữ cho màn xin đồng ý', () {
    expect(kNguonBienDong, [kNguonMb, kNguonVcb, kNguonTcb, kNguonBidv, kNguonSms, kNguonMomo, kNguonZalopay]);
    expect(kNguonBienDong, hasLength(7));
  });
}
