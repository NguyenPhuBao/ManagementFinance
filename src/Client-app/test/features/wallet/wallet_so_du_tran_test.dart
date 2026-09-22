/// Ô "Số dư ban đầu" không được tràn bố cục ở khổ điện thoại thật.
///
/// Canh chừng điều gì: con số ở ô này dựng bằng `TextField` cỡ **40** bọc
/// trong `IntrinsicWidth`, tức nó lấy đúng bề rộng tự nhiên của chuỗi và
/// **không co**. Ở 411dp, một số dư 13 chữ số (`9.999.999.999.999`) tràn khỏi
/// thẻ — đo trên máy ảo 2026-09-18: **70 pixel**.
///
/// ⚠️ Vì sao bộ test thường không thấy: `flutter test` chạy ở **1280px**, rộng
/// gấp ba điện thoại thật, nên mọi chuỗi đều vừa. Và Flutter báo tràn qua
/// `FlutterError.reportError`, **không ném ra chỗ gọi** — một ca chỉ
/// `pumpWidget` rồi `expect(find...)` sẽ xanh ngay cả khi màn hình đầy sọc
/// vàng. Đó là bẫy số 1 trong "Ba loại lỗi `flutter test` KHÔNG bắt được".
///
/// Lỗi này **có sẵn từ trước**, nhưng tới 2026-09-18 nó mới thành một trạng
/// thái đạt tới được một cách **hợp lệ**: cùng ngày, `GioiHanSoChuSo` đặt trần
/// đúng 13 chữ số cho khớp `numeric(15,2)` của cột `Balance`. Trước đó gõ bao
/// nhiêu cũng được nên tràn chỉ là hệ quả của một con số vô nghĩa; nay con số
/// lớn nhất mà app **cho phép** vẫn vỡ bố cục.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/utils/currency_formatter.dart';
import 'package:flowmoney/core/utils/gioi_han_do_dai.dart';
import 'package:flowmoney/features/wallet/presentation/widgets/o_so_du_vi.dart';

void main() {
  /// Dựng lại **đúng** cụm "số + đ" của màn Thêm/Sửa ví, ở khổ hẹp có chủ ý.
  ///
  /// Tách widget ra thay vì mở cả trang: trang thật cần `AuthBloc`, service
  /// locator và CSDL, mà thứ cần đo ở đây chỉ là một hàng hai phần tử.
  Widget cum(String soDu, {double rong = 320}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: rong,
              child: OSoDuVi(controller: TextEditingController(text: soDu)),
            ),
          ),
        ),
      );

  testWidgets('số dư 13 chữ số KHÔNG tràn bố cục ở khổ hẹp', (t) async {
    // 9.999.999.999.999 — số lớn nhất mà `GioiHanSoChuSo` cho gõ, và cũng là
    // số lớn nhất `numeric(15,2)` chứa được.
    final soDuLonNhat = CurrencyFormatter.formatSoThoi(9999999999999);
    expect(soDuLonNhat.replaceAll('.', '').length, kSoChuSoToiDaSoTien,
        reason: 'Ca này phải đo đúng cái trần mà bộ lọc đặt ra.');

    await t.pumpWidget(cum(soDuLonNhat));
    await t.pumpAndSettle();

    expect(t.takeException(), isNull,
        reason: 'Flutter báo tràn qua `FlutterError.reportError` chứ không ném '
            'ra chỗ gọi, nên `takeException` là cách DUY NHẤT bắt được nó '
            'trong widget test. Đo trên máy ảo 411dp: tràn 70 pixel.');
  });

  testWidgets('số dư ngắn vẫn hiện nguyên vẹn, không bị co vô cớ', (t) async {
    await t.pumpWidget(cum('1.000.000'));
    await t.pumpAndSettle();

    expect(find.text('1.000.000'), findsOneWidget);
    expect(find.text('đ'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  // ⚠️ Ba ca dưới đo **thẳng giá trị trả về** của `coChuSoDu`, không đo bề
  // rộng. Lý do: thứ chặn tràn là `Flexible` chứ không phải bậc thang cỡ chữ —
  // đo được bằng bản sai ngày 2026-09-18, khi ép cỡ chữ về 40 cố định mà hai ca
  // bố cục ở trên **vẫn xanh**. Bậc thang lo một việc khác: giữ con số đọc được
  // hết thay vì bị cuộn khuất trong ô. Một phép đo bố cục sẽ không canh nổi nó.
  group('coChuSoDu — bậc thang giữ số dài vẫn đọc được', () {
    test('số ngắn giữ nguyên cỡ lớn nhất', () {
      expect(coChuSoDu('0'.length), 40);
      expect(coChuSoDu('999.999.999'.length), 40);
    });

    test('số càng dài cỡ chữ càng nhỏ, không bao giờ tăng lại', () {
      var truoc = coChuSoDu(1);
      for (var n = 2; n <= 20; n++) {
        final nay = coChuSoDu(n);
        expect(nay, lessThanOrEqualTo(truoc),
            reason: 'Bậc thang phải đơn điệu giảm: một chuỗi dài hơn mà được '
                'cỡ chữ lớn hơn là cách chắc chắn nhất để vỡ đúng chỗ vừa vá.');
        truoc = nay;
      }
    });

    test('trần của numeric(15,2) rơi vào bậc nhỏ nhất', () {
      // 9.999.999.999.999 — 13 chữ số cộng 4 dấu chấm.
      final daiNhat = CurrencyFormatter.formatSoThoi(9999999999999);
      expect(daiNhat.length, 17);
      expect(coChuSoDu(daiNhat.length), 24,
          reason: 'Đây là chuỗi dài nhất mà `GioiHanSoChuSo` cho phép, nên nó '
              'phải nằm gọn trong bậc cuối chứ không rơi ra ngoài bảng.');
    });
  });

  testWidgets('cỡ chữ co lại NGAY khi người dùng gõ, không đợi dựng lại',
      (t) async {
    // ⚠️ Lỗi này máy ảo bắt được còn ba ca trên thì không: chúng dựng widget
    // với chuỗi có sẵn rồi đo một lần, nên `coChuSoDu` chạy đúng. Trên máy
    // thật người dùng **gõ vào ô**, và một `StatelessWidget` đọc
    // `controller.text` lúc build sẽ không bao giờ dựng lại — số dài giữ
    // nguyên cỡ 40 rồi bị cuộn khuất mất chữ số đầu. Bố cục vẫn lành nhờ
    // `Flexible`, nên không có sọc vàng nào để nhìn thấy.
    final dk = TextEditingController();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 320, child: OSoDuVi(controller: dk)),
        ),
      ),
    ));

    double coHienTai() =>
        t.widget<TextField>(find.byType(TextField)).style!.fontSize!;

    expect(coHienTai(), 40, reason: 'Ô rỗng thì dùng cỡ lớn nhất.');

    await t.enterText(find.byType(TextField), '9999999999999');
    await t.pump();

    expect(coHienTai(), lessThan(40),
        reason: 'Gõ 13 chữ số vào thì cỡ chữ phải co ngay. Đứng yên ở 40 nghĩa '
            'là widget không nghe `controller` — đúng lỗi đo được trên máy ảo '
            'ngày 2026-09-18.');
  });

  testWidgets('ô vẫn nhận bộ lọc chữ số và trần 13 chữ số', (t) async {
    await t.pumpWidget(cum(''));
    await t.pumpAndSettle();

    final o = t.widget<TextField>(find.byType(TextField));
    expect(o.inputFormatters, isNotNull);
    expect(
      o.inputFormatters!.any((f) => f is GioiHanSoChuSo),
      isTrue,
      reason: 'Gộp ô này thành một widget dùng chung mà đánh rơi bộ lọc là mở '
          'lại đúng vòng lặp đẩy vô hạn của `numeric(15,2)`.',
    );
    expect(
      o.inputFormatters!.any((f) => f is FilteringTextInputFormatter),
      isTrue,
    );
  });
}
