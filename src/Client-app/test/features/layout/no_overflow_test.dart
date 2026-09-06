/// Ba hàng bố cục từng **tràn** trên điện thoại thật.
///
/// Cả ba cùng một hình mẫu hỏng: một `Text` **không co được** đặt cạnh một
/// phần tử bề rộng cố định. Chữ dài bao nhiêu thì `Text` chiếm bấy nhiêu, phần
/// còn lại bị đẩy ra ngoài khung và Flutter vẽ sọc vàng-đen lên giao diện.
///
/// Vì sao không ai thấy trước đó: bộ kiểm thử tự động của dự án chạy Chrome ở
/// **1280px**, rộng gấp ba lần chỗ các hàng này bắt đầu tràn. Chỉ khi chạy trên
/// máy ảo Android (**411dp**) mới lộ ra. Đó là lý do các test dưới đây dựng
/// widget trong khung hẹp **có chủ ý** thay vì để `pumpWidget` dùng bề rộng
/// mặc định 800px của môi trường test.
///
/// Ba bề rộng được chọn: 320dp (máy nhỏ như iPhone SE đời đầu), 360dp (cỡ phổ
/// biến nhất của Android), 411dp (chính là emulator đã tìm ra lỗi).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/bill/presentation/widgets/bill_status_header.dart';
import 'package:flowmoney/features/home/presentation/widgets/home_action_buttons.dart';
import 'package:flowmoney/features/wallet/presentation/widgets/bank_header_row.dart';

/// Các bề rộng logic cần chịu được.
const beRong = <double>[320, 360, 411];

/// Dựng [child] trong một khung rộng đúng [width] và trả về ngoại lệ bố cục
/// nếu có.
///
/// `tester.takeException()` là đường duy nhất bắt được lỗi tràn: Flutter báo nó
/// qua `FlutterError.reportError` chứ không ném ra chỗ gọi, nên một test chỉ
/// `pumpWidget` rồi `expect(find...)` sẽ **xanh** ngay cả khi giao diện đang
/// đầy sọc cảnh báo.
Future<Object?> dungTrongKhung(
  WidgetTester tester,
  Widget child,
  double width,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  ));
  return tester.takeException();
}

void main() {
  group('thẻ hoá đơn — tên dài không được đẩy chip trạng thái ra ngoài', () {
    for (final w in beRong) {
      testWidgets('rộng ${w.toInt()}dp', (tester) async {
        final loi = await dungTrongKhung(
          tester,
          const BillStatusHeader(
            // Đúng tên đã làm tràn trên máy thật.
            title: 'Kiem thu hoa don 2026-09-04',
            subtitle: 'Hạn 04/10/2026',
            status: 'CHƯA THANH TOÁN',
            statusColor: Color(0xFF46464C),
            statusBg: Color(0xFFE8E8E4),
            titleColor: Color(0xFF00020D),
          ),
          w,
        );

        expect(loi, isNull,
            reason: 'Tràn ở ${w.toInt()}dp. Tên hoá đơn do người dùng đặt nên '
                'dài bao nhiêu cũng được — phần chữ phải co lại, không được '
                'đẩy chip trạng thái ra khỏi thẻ.');
      });
    }

    testWidgets('tên rất dài vẫn không tràn', (tester) async {
      final loi = await dungTrongKhung(
        tester,
        const BillStatusHeader(
          title: 'Hoá đơn tiền điện tháng chín năm hai nghìn không trăm hai '
              'mươi sáu của căn hộ số 12 toà nhà A',
          subtitle: 'Hạn 04/10/2026',
          status: 'CHƯA THANH TOÁN',
          statusColor: Color(0xFF46464C),
          statusBg: Color(0xFFE8E8E4),
          titleColor: Color(0xFF00020D),
        ),
        320,
      );

      expect(loi, isNull,
          reason: 'Không có giới hạn độ dài nào ở ô nhập tên hoá đơn, nên bố '
              'cục phải chịu được tên dài tuỳ ý.');
    });

    testWidgets('trạng thái đã thanh toán có thêm icon vẫn không tràn',
        (tester) async {
      final loi = await dungTrongKhung(
        tester,
        const BillStatusHeader(
          title: 'Kiem thu hoa don 2026-09-04',
          subtitle: 'Hạn 04/10/2026',
          status: 'ĐÃ THANH TOÁN',
          statusColor: Color(0xFF217128),
          statusBg: Color(0xFFA0F399),
          titleColor: Color(0xFF46464C),
          isPaid: true,
        ),
        320,
      );

      expect(loi, isNull,
          reason: 'Nhánh đã thanh toán thêm một icon 14px vào chip, tức là chip '
              'rộng hơn nhánh chưa thanh toán — nếu chỉ test một nhánh thì bỏ '
              'sót đúng nhánh chật hơn.');
    });
  });

  group('hai nút trang chủ', () {
    for (final w in beRong) {
      testWidgets('rộng ${w.toInt()}dp', (tester) async {
        final loi = await dungTrongKhung(
          tester,
          HomeActionButtons(onAdd: () {}, onReport: () {}),
          w,
        );

        expect(loi, isNull,
            reason: 'Tràn ở ${w.toInt()}dp. Hai nút chia đôi màn hình, và nhãn '
                '"Thêm giao dịch" cộng icon vượt phần của nó ở màn hẹp.');
      });
    }
  });

  group('thẻ ngân hàng ở trang liên kết', () {
    for (final w in beRong) {
      testWidgets('rộng ${w.toInt()}dp', (tester) async {
        final loi = await dungTrongKhung(
          tester,
          const BankHeaderRow(
            bankName: 'Ngân hàng Techcombank',
            statusText: 'Đang kết nối API',
            chipText: 'Cổng API an toàn',
          ),
          w,
        );

        expect(loi, isNull,
            reason: 'Tràn ở ${w.toInt()}dp — đây là chỗ tràn nặng nhất tìm '
                'được trên máy thật (21px).');
      });
    }

    testWidgets('tên ngân hàng dài vẫn không tràn', (tester) async {
      final loi = await dungTrongKhung(
        tester,
        const BankHeaderRow(
          bankName: 'Ngân hàng Thương mại Cổ phần Kỹ Thương Việt Nam',
          statusText: 'Đang kết nối API',
          chipText: 'Cổng API an toàn',
        ),
        360,
      );

      expect(loi, isNull,
          reason: 'Tên đầy đủ của ngân hàng dài hơn hẳn tên rút gọn, và danh '
              'sách ngân hàng sẽ còn thêm.');
    });
  });
}
