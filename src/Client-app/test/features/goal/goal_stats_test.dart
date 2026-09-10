/// Số liệu tổng hợp và chuỗi kỳ nạp liên tiếp — thêm 2026-09-09.
///
/// Vì sao tầng thuần: cả ba con số đọc từ lịch sử đã có, không cần dữ liệu
/// mới — nhưng **chuỗi liên tiếp** là phép chia thời gian thành kỳ, tức đúng
/// vùng mà tháng ngắn và năm nhuận làm sai **im lặng**.
///
/// Kỳ được cắt bằng `mocThuN` neo vào `startDate` — **cùng** phép bước kỳ mà
/// bộ trích tự động dùng, và cùng khuôn với `advancePeriodFrom` bên ngân sách
/// lẫn `anchorDay` bên hoá đơn. Dựng bản thứ tư ở đây là tự chuốc bốn luật
/// lệch nhau về cùng một câu hỏi "kỳ này là từ ngày nào tới ngày nào".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/domain/goal_history_filter.dart';
import 'package:flowmoney/features/goal/domain/goal_stats.dart';

void main() {
  KhoanTichLuy k(DateTime ngay, {double soTien = 100000, bool rut = false}) =>
      KhoanTichLuy(
        ngay: ngay,
        soTien: soTien,
        laKhoanRut: rut,
        laTuDong: false,
      );

  group('thongKeMucTieu — hai con số đếm được', () {
    test('không có khoản gửi nào thì không có thống kê', () {
      expect(
        thongKeMucTieu(
          khoan: [k(DateTime(2026, 8, 1), rut: true)],
          ngayBatDau: DateTime(2026, 6, 15),
          chuKy: 'Month',
          now: DateTime(2026, 9, 9),
        ),
        isNull,
        reason: 'Chỉ có khoản rút thì "trung bình mỗi lần nạp" là phép chia '
            'cho 0. Thẻ phải biến mất, không phải hiện "0 lần · 0 đ".',
      );
    });

    test('số lần nạp KHÔNG đếm khoản rút', () {
      final tk = thongKeMucTieu(
        khoan: [
          k(DateTime(2026, 8, 1)),
          k(DateTime(2026, 8, 5), rut: true),
          k(DateTime(2026, 8, 9)),
        ],
        ngayBatDau: DateTime(2026, 6, 15),
        chuKy: 'Month',
        now: DateTime(2026, 9, 9),
      )!;

      expect(
        tk.soLanNap,
        2,
        reason: 'Ba con số của thẻ đều nói về thói quen **bỏ tiền vào**. Đếm '
            'cả lần rút là trộn hai chiều tiền vào một con số.',
      );
    });

    test('trung bình mỗi lần chia trên số lần NẠP, không phải số hàng', () {
      final tk = thongKeMucTieu(
        khoan: [
          k(DateTime(2026, 8, 1), soTien: 300000),
          k(DateTime(2026, 8, 5), soTien: 999999, rut: true),
          k(DateTime(2026, 8, 9), soTien: 100000),
        ],
        ngayBatDau: DateTime(2026, 6, 15),
        chuKy: 'Month',
        now: DateTime(2026, 9, 9),
      )!;

      expect(
        tk.trungBinhMoiLan,
        200000,
        reason: 'Chia cho 3 hàng ra 133.333 — một con số không ứng với bất kỳ '
            'thao tác nào người dùng từng làm.',
      );
    });
  });

  group('thongKeMucTieu — chuỗi kỳ liên tiếp', () {
    // Mốc gốc 15/06/2026, chu kỳ tháng: k0 [15/06, 15/07), k1 [15/07, 15/08),
    // k2 [15/08, 15/09), k3 [15/09, 15/10). Hôm nay 09/09 nằm ở k2.
    int? chuoi(List<DateTime> ngayNap, {DateTime? now}) => thongKeMucTieu(
          khoan: [for (final d in ngayNap) k(d)],
          ngayBatDau: DateTime(2026, 6, 15),
          chuKy: 'Month',
          now: now ?? DateTime(2026, 9, 9),
        )?.chuoiKy;

    test('ba kỳ liền nhau đều có nạp thì chuỗi là 3', () {
      expect(
        chuoi([DateTime(2026, 6, 20), DateTime(2026, 7, 20), DateTime(2026, 8, 20)]),
        3,
      );
    });

    test('nhiều khoản trong CÙNG một kỳ vẫn chỉ tính một kỳ', () {
      expect(
        chuoi([
          DateTime(2026, 8, 16),
          DateTime(2026, 8, 20),
          DateTime(2026, 8, 28),
        ]),
        1,
        reason: 'Chuỗi đếm KỲ chứ không đếm khoản. Nạp ba lần trong một tháng '
            'là một tháng có nạp, không phải ba tháng liên tiếp.',
      );
    });

    test('kỳ hiện tại chưa nạp thì KHÔNG phá chuỗi', () {
      expect(
        chuoi([DateTime(2026, 6, 20), DateTime(2026, 7, 20)]),
        2,
        reason: 'Kỳ hiện tại đang dở, chưa hết hạn để nói là đứt. Không có '
            'luật này thì mỗi đầu kỳ chuỗi của mọi người tụt về 0 và con số '
            'hết nghĩa ngay ngày đầu tiên người dùng nhìn nó.',
      );
    });

    test('kỳ rỗng ở GIỮA thì cắt chuỗi', () {
      expect(
        chuoi([DateTime(2026, 6, 20), DateTime(2026, 8, 20)]),
        1,
        reason: 'Kỳ 07 rỗng nên chỉ còn kỳ hiện tại. Đếm cả kỳ 06 là nói dối '
            'về sự liên tục — đúng thứ duy nhất mà chữ "liên tiếp" hứa.',
      );
    });

    test('không nạp kỳ nào gần đây thì chuỗi bằng 0', () {
      expect(
        chuoi([DateTime(2026, 6, 20)], now: DateTime(2026, 9, 9)),
        0,
        reason: 'Kỳ hiện tại rỗng, kỳ trước cũng rỗng — chuỗi đã đứt thật.',
      );
    });

    test('khoản RÚT không phá chuỗi', () {
      final tk = thongKeMucTieu(
        khoan: [
          k(DateTime(2026, 7, 20)),
          k(DateTime(2026, 8, 20)),
          k(DateTime(2026, 8, 25), rut: true),
        ],
        ngayBatDau: DateTime(2026, 6, 15),
        chuKy: 'Month',
        now: DateTime(2026, 9, 9),
      )!;

      expect(
        tk.chuoiKy,
        2,
        reason: 'Chuỗi nói về thói quen bỏ tiền vào. Rút một lần rồi vẫn nạp '
            'đều thì thói quen ấy không đứt.',
      );
    });

    test('khoản ghi TRƯỚC mốc gốc không tính vào chuỗi', () {
      final tk = thongKeMucTieu(
        khoan: [
          k(DateTime(2026, 5, 1)),
          k(DateTime(2026, 8, 20)),
        ],
        ngayBatDau: DateTime(2026, 6, 15),
        chuKy: 'Month',
        now: DateTime(2026, 9, 9),
      )!;

      expect(
        tk.chuoiKy,
        1,
        reason: 'Kỳ đầu tiên bắt đầu ở mốc gốc; không có kỳ số âm để khoản cũ '
            'thuộc về. Nhưng nó vẫn là một lần nạp thật.',
      );
      expect(tk.soLanNap, 2);
    });

    test('không có mốc gốc thì không có chuỗi, hai số kia vẫn còn', () {
      final tk = thongKeMucTieu(
        khoan: [k(DateTime(2026, 8, 20), soTien: 500000)],
        ngayBatDau: null,
        chuKy: 'Month',
        now: DateTime(2026, 9, 9),
      )!;

      expect(
        tk.chuoiKy,
        isNull,
        reason: 'Không có mốc gốc thì không cắt được kỳ. Cùng kỷ luật im lặng '
            'với isBehindSchedule — nhưng giấu cả thẻ là vứt luôn hai con số '
            'app biết chắc.',
      );
      expect(tk.soLanNap, 1);
      expect(tk.trungBinhMoiLan, 500000);
    });

    test('chu kỳ trống quy về THÁNG, đúng lựa chọn của mocKeTiep', () {
      expect(
        thongKeMucTieu(
          khoan: [
            k(DateTime(2026, 7, 20)),
            k(DateTime(2026, 8, 20)),
          ],
          ngayBatDau: DateTime(2026, 6, 15),
          chuKy: null,
          now: DateTime(2026, 9, 9),
        )!.chuoiKy,
        2,
        reason: 'mocKeTiep đã chọn quy chu kỳ lạ/trống về tháng để trang chi '
            'tiết không nói hai điều khác nhau về cùng một mục tiêu. Chọn '
            'khác ở đây là tạo ra điều thứ hai ấy.',
      );
    });
  });

  group('thongKeMucTieu — tháng ngắn và năm nhuận', () {
    test('năm nhuận: kỳ thứ hai bắt đầu 29/02 chứ không phải 02/03', () {
      // Mốc gốc 31/01/2024 (năm nhuận).
      //   Đúng:      k0 [31/01, 29/02), k1 [29/02, 31/03)
      //   Cộng thô:  k0 [31/01, 02/03), k1 [02/03, 31/03)
      //     — vì DateTime(2024, 2, 31) KHÔNG ném lỗi, Dart chuẩn hoá nó
      //       thành 02/03.
      //
      // Khoản 01/03 là chỗ hai cách đọc tách nhau: đúng thì nó thuộc k1,
      // cộng thô thì nó vẫn nằm trong k0 và k1 hoá rỗng.
      final tk = thongKeMucTieu(
        khoan: [
          k(DateTime(2024, 2, 5)), // k0 theo cả hai cách
          k(DateTime(2024, 3, 1)), // k1 nếu cắt đúng; k0 nếu cộng thô
        ],
        ngayBatDau: DateTime(2024, 1, 31),
        chuKy: 'Month',
        now: DateTime(2024, 3, 15),
      )!;

      expect(
        tk.chuoiKy,
        2,
        reason: 'Cộng tháng kiểu thô dồn cả hai khoản vào một kỳ và trả về 1. '
            'mocThuN kẹp 31/01 + 1 tháng về 29/02 theo lịch thật — phép đếm '
            'chuỗi phải đi qua nó chứ đừng tự cộng.',
      );
    });

    test('tháng ngắn: kỳ thứ hai bắt đầu 28/02 chứ không phải 03/03', () {
      // Mốc gốc 31/01/2026 (tháng 2 có 28 ngày).
      //   Đúng:      k0 [31/01, 28/02), k1 [28/02, 31/03)
      //   Cộng thô:  k0 [31/01, 03/03), k1 [03/03, 31/03)
      //
      // Khoản 01/03 lại là chỗ hai cách đọc tách nhau.
      final tk = thongKeMucTieu(
        khoan: [
          k(DateTime(2026, 2, 5)), // k0 theo cả hai cách
          k(DateTime(2026, 3, 1)), // k1 nếu cắt đúng; k0 nếu cộng thô
        ],
        ngayBatDau: DateTime(2026, 1, 31),
        chuKy: 'Month',
        now: DateTime(2026, 3, 15),
      )!;

      expect(
        tk.chuoiKy,
        2,
        reason: 'Neo vào mốc GỐC nên ngày 31 quay lại được ở tháng đủ dài. '
            'Bước dồn từ kết quả đã kẹp thì nhịp tụt xuống 28 vĩnh viễn, và '
            'khoản 01/03 rơi nhầm về kỳ trước.',
      );
    });
  });

  group('tenDonViKy', () {
    test('mỗi chu kỳ có một danh từ riêng', () {
      expect(tenDonViKy('Day'), 'ngày');
      expect(tenDonViKy('Week'), 'tuần');
      expect(tenDonViKy('Month'), 'tháng');
      expect(tenDonViKy('Quarter'), 'quý');
      expect(tenDonViKy('Year'), 'năm');
    });

    test('chu kỳ trống hoặc lạ đọc là tháng', () {
      expect(
        tenDonViKy(null),
        'tháng',
        reason: 'Cùng lựa chọn với mocKeTiep. Nhãn nói "quý" trong khi phép '
            'đếm cắt theo tháng là một con số không ai kiểm lại được.',
      );
      expect(tenDonViKy('Fortnight'), 'tháng');
    });
  });
}
