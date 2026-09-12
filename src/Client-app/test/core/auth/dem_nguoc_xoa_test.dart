/// Số ngày chờ xoá còn lại — spec cưỡng chế đăng xuất §4.2 và §7.1.
library;

import 'package:flowmoney/core/auth/dem_nguoc_xoa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ngayVN', () {
    test('16:59Z là 23:59 giờ VN (cùng ngày), 17:01Z đã sang ngày mới', () {
      expect(ngayVN(DateTime.utc(2026, 9, 11, 16, 59)), DateTime.utc(2026, 9, 11));
      expect(ngayVN(DateTime.utc(2026, 9, 11, 17, 1)), DateTime.utc(2026, 9, 12));
    });
  });

  group('soNgayConLai', () {
    test('cùng ngày nhận → đúng countdown', () {
      expect(
          soNgayConLai(
              countdown: 30,
              nhanLuc: DateTime.utc(2026, 9, 11, 2),
              now: DateTime.utc(2026, 9, 11, 15)),
          30);
    });

    test('qua 00:00 giờ VN thì trừ một ngày, dù mới cách hai phút', () {
      expect(
          soNgayConLai(
              countdown: 30,
              nhanLuc: DateTime.utc(2026, 9, 11, 16, 59),
              now: DateTime.utc(2026, 9, 11, 17, 1)),
          29,
          reason: 'Backend trừ Countdown lúc 00:00 giờ Việt Nam, không theo 24 giờ trôi qua.');
    });

    test('cuối tháng 30 ngày và 31 ngày', () {
      expect(
          soNgayConLai(
              countdown: 30,
              nhanLuc: DateTime.utc(2026, 9, 30, 3),
              now: DateTime.utc(2026, 10, 1, 3)),
          29);
      expect(
          soNgayConLai(
              countdown: 30,
              nhanLuc: DateTime.utc(2026, 10, 31, 3),
              now: DateTime.utc(2026, 11, 1, 3)),
          29);
    });

    test('28/02 → 01/03: năm 2026 cách 1 ngày, năm nhuận 2028 cách 2 ngày', () {
      expect(
          soNgayConLai(
              countdown: 30,
              nhanLuc: DateTime.utc(2026, 2, 28, 3),
              now: DateTime.utc(2026, 3, 1, 3)),
          29);
      expect(
          soNgayConLai(
              countdown: 30,
              nhanLuc: DateTime.utc(2028, 2, 28, 3),
              now: DateTime.utc(2028, 3, 1, 3)),
          28);
    });

    test('qua năm', () {
      expect(
          soNgayConLai(
              countdown: 30,
              nhanLuc: DateTime.utc(2026, 12, 31, 3),
              now: DateTime.utc(2027, 1, 2, 3)),
          28);
    });

    test('đồng hồ máy lùi (now trước mốc nhận) → không vượt countdown', () {
      expect(
          soNgayConLai(
              countdown: 30,
              nhanLuc: DateTime.utc(2026, 9, 11, 3),
              now: DateTime.utc(2026, 9, 5, 3)),
          30);
    });

    test('quá hạn → 0, không âm', () {
      expect(
          soNgayConLai(
              countdown: 30,
              nhanLuc: DateTime.utc(2026, 9, 1, 3),
              now: DateTime.utc(2026, 11, 1, 3)),
          0);
    });

    test('thiếu countdown hoặc mốc nhận → null', () {
      expect(
          soNgayConLai(
              countdown: null,
              nhanLuc: DateTime.utc(2026, 9, 11),
              now: DateTime.utc(2026, 9, 11)),
          isNull);
      expect(
          soNgayConLai(countdown: 30, nhanLuc: null, now: DateTime.utc(2026, 9, 11)),
          isNull);
    });
  });

  group('ngayXoaVinhVien', () {
    test('rơi sang tháng sau', () {
      expect(ngayXoaVinhVien(countdown: 30, nhanLuc: DateTime.utc(2026, 9, 11, 3)),
          DateTime.utc(2026, 10, 11));
    });

    test('rơi sang năm sau, tính theo ngày giờ VN của mốc nhận', () {
      // 16:30Z ngày 15/12 = 23:30 giờ VN ngày 15/12
      expect(ngayXoaVinhVien(countdown: 30, nhanLuc: DateTime.utc(2026, 12, 15, 16, 30)),
          DateTime.utc(2027, 1, 14));
      // 17:30Z ngày 15/12 = 00:30 giờ VN ngày 16/12
      expect(ngayXoaVinhVien(countdown: 30, nhanLuc: DateTime.utc(2026, 12, 15, 17, 30)),
          DateTime.utc(2027, 1, 15));
    });

    test('năm nhuận 2028: 20/02 + 10 ngày là 01/03', () {
      expect(ngayXoaVinhVien(countdown: 10, nhanLuc: DateTime.utc(2028, 2, 20, 3)),
          DateTime.utc(2028, 3, 1));
    });

    test('thiếu dữ liệu → null', () {
      expect(ngayXoaVinhVien(countdown: null, nhanLuc: DateTime.utc(2026, 9, 11)), isNull);
    });
  });
}
