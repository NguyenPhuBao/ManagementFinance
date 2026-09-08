/// Lọc và tổng kết lịch sử tích luỹ — thêm 2026-09-08.
///
/// Vì sao cần: danh sách vốn hiện **toàn bộ** không có trần
/// (`itemCount: txs.length`). Với 11 khoản thì cuộn hết trong 2 cú vuốt, nhưng
/// một mục tiêu trích hàng ngày chạy hai năm là **730 dòng** — và chúng được
/// dựng bằng `shrinkWrap` + `NeverScrollableScrollPhysics`, tức **dựng hết
/// cùng lúc, không ảo hoá**, trên một trang nay vẽ lại mỗi lượt đồng bộ.
///
/// ⚠️ **Không có bộ lọc "tay / tự động"**, và đó là giới hạn của *dữ liệu* chứ
/// không phải của giao diện: `GoalAutoDepositRunner` gọi đúng `depositToGoal`
/// với đúng tiền tố ghi chú của khoản nạp tay, nên hai loại **giống hệt nhau**
/// trên mọi cột. Sự giống nhau ấy có chủ ý (mục 3.12) — nhờ nó mà
/// `laKhoanRutKhoiMucTieu` đọc đúng chiều cho cả hai. Muốn phân biệt thì phải
/// thêm cột, và **đổi tiền tố ghi chú là cách sai**: nó đâm thẳng vào bẫy 4.2.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/domain/goal_history_filter.dart';

void main() {
  final now = DateTime(2026, 9, 8, 12);

  KhoanTichLuy k({
    required DateTime ngay,
    double soTien = 100000,
    bool rut = false,
  }) =>
      KhoanTichLuy(ngay: ngay, soTien: soTien, laKhoanRut: rut);

  final dsMau = [
    k(ngay: DateTime(2026, 9, 7), soTien: 100000),
    k(ngay: DateTime(2026, 9, 1), soTien: 500000, rut: true),
    k(ngay: DateTime(2026, 7, 1), soTien: 200000),
    k(ngay: DateTime(2025, 12, 1), soTien: 300000),
  ];

  group('locKhoan — chiều tiền', () {
    test('mặc định giữ nguyên tất cả', () {
      expect(locKhoan(dsMau, now: now).length, 4);
    });

    test('chỉ khoản đã gửi', () {
      final ra = locKhoan(dsMau, chieu: LocChieu.daGui, now: now);
      expect(ra.length, 3);
      expect(ra.every((x) => !x.laKhoanRut), isTrue);
    });

    test('chỉ khoản đã rút', () {
      final ra = locKhoan(dsMau, chieu: LocChieu.daRut, now: now);
      expect(ra.map((x) => x.soTien), [500000],
          reason: 'Khoản rút hiếm, nhưng khi người dùng đi tìm thì chính là đi '
              'tìm nó — "tôi đã rút bao nhiêu ra khỏi mục tiêu này rồi?".');
    });
  });

  group('locKhoan — khoảng thời gian', () {
    test('30 ngày gần nhất', () {
      final ra = locKhoan(dsMau, khoang: LocKhoang.ngay30, now: now);
      expect(ra.length, 2, reason: '07/09 và 01/09 nằm trong 30 ngày.');
    });

    test('ba tháng gần nhất', () {
      final ra = locKhoan(dsMau, khoang: LocKhoang.thang3, now: now);
      expect(ra.length, 3, reason: 'Thêm 01/07.');
    });

    test('năm nay cắt theo NĂM DƯƠNG LỊCH, không phải 365 ngày', () {
      final ra = locKhoan(dsMau, khoang: LocKhoang.namNay, now: now);
      expect(ra.length, 3,
          reason: 'Khoản 01/12/2025 cách hôm nay hơn 9 tháng nhưng vẫn nằm '
              'trong 365 ngày. "Năm nay" mà lại gồm cả tháng 12 năm ngoái là '
              'một câu nói dối nhỏ mà người dùng phát hiện ngay khi cộng lại.');
    });

    test('ngày biên được giữ TRỌN, kể cả khoản lúc rạng sáng', () {
      // `now` là 08/09 lúc 12:00, nên mốc 30 ngày rơi vào 09/08.
      final ds = [
        k(ngay: DateTime(2026, 8, 9, 0, 1)), // rạng sáng ngày biên
        k(ngay: DateTime(2026, 8, 8, 23, 59)), // sát trước ngày biên
      ];

      final ra = locKhoan(ds, khoang: LocKhoang.ngay30, now: now);

      expect(ra.length, 1, reason: 'Đúng một khoản lọt.');
      expect(ra.single.ngay.day, 9,
          reason: 'Cả hai đầu của phép so phải được chuẩn hoá về NGÀY. Nếu mốc '
              'giữ nguyên giờ (12:00 của 09/08) thì khoản lúc 00:01 cùng ngày '
              'bị loại — người dùng lọc "30 ngày" và mất một khoản chỉ vì họ '
              'mở app buổi chiều. Ca này lọt qua bản test đầu tiên viết cho '
              'nó, phát hiện 2026-09-08 bằng cách dựng bản sai có chủ ý.');
    });
  });

  group('locKhoan — hai bộ lọc cùng lúc', () {
    test('giao nhau chứ không phải hợp nhau', () {
      final ra = locKhoan(
        dsMau,
        chieu: LocChieu.daGui,
        khoang: LocKhoang.ngay30,
        now: now,
      );
      expect(ra.map((x) => x.soTien), [100000]);
    });

    test('không đổi thứ tự của danh sách vào', () {
      final ra = locKhoan(dsMau, chieu: LocChieu.daGui, now: now);
      expect(ra.map((x) => x.ngay), [
        DateTime(2026, 9, 7),
        DateTime(2026, 7, 1),
        DateTime(2025, 12, 1),
      ], reason: 'Thứ tự do truy vấn quyết định (`date desc`). Sắp lại ở đây '
          'là bản sao thứ hai của một quyết định đã nằm ở tầng dữ liệu.');
    });
  });

  group('tongKet', () {
    test('đếm và cộng riêng hai chiều', () {
      final t = tongKet(dsMau);
      expect(t.soKhoan, 4);
      expect(t.daGui, 600000, reason: '100k + 200k + 300k.');
      expect(t.daRut, 500000);
    });

    test('danh sách rỗng ra số 0, không ném', () {
      final t = tongKet(const []);
      expect(t.soKhoan, 0);
      expect(t.daGui, 0);
      expect(t.daRut, 0);
    });

    test('tổng kết tính trên danh sách ĐÃ LỌC', () {
      final t = tongKet(locKhoan(dsMau, chieu: LocChieu.daGui, now: now));
      expect(t.daRut, 0,
          reason: 'Dòng tổng nằm ngay trên dải chip nên nó phải nói về đúng '
              'thứ đang hiện. Tổng của cả danh sách trong khi màn hình lọc còn '
              'ba dòng là hai con số cãi nhau trên cùng một màn hình.');
    });
  });
}
