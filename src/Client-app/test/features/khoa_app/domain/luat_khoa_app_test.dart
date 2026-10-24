import 'package:flowmoney/features/khoa_app/domain/luat_khoa_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mặc định 30 giây; tên lạ hoặc null đọc về mặc định', () {
    expect(TuKhoaSau.macDinh, TuKhoaSau.giay30);
    expect(TuKhoaSau.tuTen('phut5'), TuKhoaSau.phut5);
    expect(TuKhoaSau.tuTen('la'), TuKhoaSau.giay30);
    expect(TuKhoaSau.tuTen(null), TuKhoaSau.giay30);
  });

  test('nhãn bốn mức đúng chữ trên Stitch', () {
    expect(TuKhoaSau.values.map((m) => m.nhan).toList(),
        ['Ngay khi rời app', '30 giây', '1 phút', '5 phút']);
  });

  group('canKhoaKhiQuayLai', () {
    final roi = DateTime(2026, 10, 24, 20);
    test('Ngay: khoá kể cả quay lại sau 0 giây', () {
      expect(canKhoaKhiQuayLai(roiLuc: roi, nay: roi, muc: TuKhoaSau.ngay), isTrue);
    });
    test('30 giây: 29 s không khoá, 30 s khoá', () {
      expect(canKhoaKhiQuayLai(roiLuc: roi, nay: roi.add(const Duration(seconds: 29)), muc: TuKhoaSau.giay30),
          isFalse);
      expect(canKhoaKhiQuayLai(roiLuc: roi, nay: roi.add(const Duration(seconds: 30)), muc: TuKhoaSau.giay30),
          isTrue, reason: 'biên dùng >=: đúng mốc là khoá');
    });
    test('đồng hồ lùi (người dùng chỉnh giờ) → khoá', () {
      expect(canKhoaKhiQuayLai(roiLuc: roi, nay: roi.subtract(const Duration(hours: 1)), muc: TuKhoaSau.phut5),
          isTrue, reason: 'không biết đã ở nền bao lâu thì nghiêng về an toàn');
    });
  });

  test('thoiGianCho: ca biên 4 / 5 / 6 / 7 / 8 / 20', () {
    expect(thoiGianCho(4), isNull);
    expect(thoiGianCho(5), const Duration(seconds: 30));
    expect(thoiGianCho(6), const Duration(minutes: 1));
    expect(thoiGianCho(7), const Duration(minutes: 5));
    expect(thoiGianCho(8), const Duration(minutes: 15));
    expect(thoiGianCho(20), const Duration(minutes: 15));
  });

  test('maPinHopLe: đúng 6 chữ số ASCII', () {
    expect(maPinHopLe('012345'), isTrue);
    expect(maPinHopLe('12345'), isFalse);
    expect(maPinHopLe('1234567'), isFalse);
    expect(maPinHopLe('12a456'), isFalse);
    expect(maPinHopLe('１２３４５６'), isFalse, reason: 'chữ số toàn khổ không phải ASCII');
  });
}
