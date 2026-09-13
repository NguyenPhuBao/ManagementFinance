/// Toast nổi chạy trên mọi màn hình.
///
/// Ba thứ nó nói, theo đúng thứ tự người dùng gặp:
///
/// 1. **Mất kết nối** — và quan trọng nhất là câu trấn an đi kèm: thay đổi vẫn
///    được lưu trên máy. Không có câu đó, người dùng sẽ ngừng nhập liệu vì sợ
///    mất, mà đó chính là thứ kiến trúc offline-first sinh ra để tránh.
/// 2. **Đã kết nối lại.**
/// 3. **Đã đồng bộ xong** — hoặc còn thay đổi chưa lên được.
///
/// **Cả ba đều tự ẩn sau vài giây**, kể cả toast mất kết nối. Bản đầu giữ dải
/// mất kết nối cho tới khi có mạng, với lập luận "trạng thái kéo dài thì phải
/// hiển thị kéo dài". Người dùng thử trên máy thật và yêu cầu đổi: một dải đứng
/// mãi trên đầu màn hình gây khó chịu hơn là hữu ích.
///
/// Cũng vì thế, thông báo đồng bộ **không nêu số lượng** — nói đủ ý là xong.
///
/// ## Đổi hình thức, 2026-09-09
///
/// Bản trước là một **dải đặc màu kín chiều ngang** nằm trong `Column`, tức nó
/// đẩy cả trang xuống mỗi lần xuất hiện. Người dùng yêu cầu làm gọn hơn, nên
/// nay là một **viên nổi ở đáy**. Hai test về bố cục trong tệp này đã bị **đảo
/// ngược có chủ đích** — xem `reason:` của chúng.
///
/// ⚠️ Nội dung được giữ lại tới hết hiệu ứng ra, nên mọi phép chờ toast biến
/// mất phải cộng thêm `thoiGianHieuUngToast`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/network/connection_monitor.dart';
import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/shared/widgets/app_toast.dart';

void main() {
  const tuAn = Duration(milliseconds: 80);

  late StreamController<ConnectionEvent> ketNoi;
  late StreamController<SyncResult> dayLen;
  late StreamController<RealtimeEvent> realtime;

  setUp(() {
    ketNoi = StreamController<ConnectionEvent>.broadcast();
    dayLen = StreamController<SyncResult>.broadcast();
    realtime = StreamController<RealtimeEvent>.broadcast();
  });

  tearDown(() async {
    await ketNoi.close();
    await dayLen.close();
    await realtime.close();
  });

  Future<void> dung(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppToast(
          connectionEvents: ketNoi.stream,
          pushResults: dayLen.stream,
          realtimeEvents: realtime.stream,
          tuAnSau: tuAn,
          child: const Text('nội dung màn hình'),
        ),
      ),
    ));
    await tester.pump();
  }

  /// Stream đẩy sự kiện qua microtask, nên một `pump()` chưa chắc đã thấy —
  /// nhịp đầu chạy listener, nhịp sau vẽ lại khung hình.
  Future<void> nhip(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  /// Chờ cho toast biến mất HẲN: hết thời gian tự ẩn, rồi hết hiệu ứng ra.
  ///
  /// Nội dung cố ý được giữ lại suốt hiệu ứng ra — bỏ nó đi ngay thì toast biến
  /// mất phụt. Cái giá là `find.text` vẫn thấy chữ trong khoảng ấy, nên test
  /// phải chờ đủ cả hai chặng.
  Future<void> choTanHan(WidgetTester tester) async {
    await tester.pump(tuAn * 2);
    await tester.pump(thoiGianHieuUngToast);
    await tester.pump();
  }

  SyncResult ketQua({required int thanhCong, int that = 0}) => SyncResult(
        totalOps: thanhCong + that,
        succeeded: thanhCong,
        failed: that,
      );

  testWidgets('bình thường thì không có toast nào', (tester) async {
    await dung(tester);

    expect(find.textContaining('kết nối'), findsNothing);
    expect(find.text('nội dung màn hình'), findsOneWidget,
        reason: 'Toast chỉ bọc quanh, không được thay thế nội dung màn hình.');
  });

  testWidgets('mất mạng thì hiện toast kèm câu trấn an', (tester) async {
    await dung(tester);
    ketNoi.add(ConnectionEvent.mat);
    await nhip(tester);

    expect(find.textContaining('Không có kết nối'), findsOneWidget);
    expect(find.textContaining('vẫn được lưu'), findsOneWidget,
        reason: 'Thiếu câu này người dùng sẽ ngừng nhập liệu vì sợ mất dữ '
            'liệu — đúng nỗi sợ mà offline-first sinh ra để xoá bỏ.');
  });

  testWidgets('toast mất kết nối cũng tự ẩn sau vài giây', (tester) async {
    await dung(tester);
    ketNoi.add(ConnectionEvent.mat);
    await nhip(tester);

    expect(find.textContaining('Không có kết nối'), findsOneWidget);

    await choTanHan(tester);
    expect(find.textContaining('Không có kết nối'), findsNothing,
        reason: 'Người dùng yêu cầu mọi toast đều biến mất sau vài giây. Một '
            'dải đứng mãi trên màn hình gây khó chịu hơn là hữu ích — thông tin '
            '"đang mất mạng" đã có sẵn ở thanh trạng thái của hệ điều hành.');
  });

  testWidgets('có mạng lại thì đổi sang toast khôi phục rồi tự ẩn',
      (tester) async {
    await dung(tester);
    ketNoi.add(ConnectionEvent.mat);
    await nhip(tester);
    ketNoi.add(ConnectionEvent.khoiPhuc);
    await nhip(tester);

    expect(find.textContaining('Đã kết nối lại'), findsOneWidget);
    expect(find.textContaining('Không có kết nối'), findsNothing,
        reason: 'Hai toast không được chồng lên nhau.');

    await choTanHan(tester);
    expect(find.textContaining('Đã kết nối lại'), findsNothing,
        reason: 'Đây là sự kiện vừa xảy ra, không phải trạng thái — để mãi thì '
            'nó chiếm chỗ vô ích.');
  });

  testWidgets('đẩy thành công thì báo chung chung, KHÔNG nêu số',
      (tester) async {
    await dung(tester);
    dayLen.add(ketQua(thanhCong: 5));
    await nhip(tester);

    expect(find.textContaining('đồng bộ'), findsOneWidget);
    expect(find.textContaining('5'), findsNothing,
        reason: 'Người dùng không cần biết bao nhiêu bản ghi vừa lên server — '
            'con số ấy là chi tiết cài đặt, không phải điều họ quan tâm. Biết '
            '"đã xong" là đủ.');

    await choTanHan(tester);
    expect(find.textContaining('đồng bộ'), findsNothing);
  });

  testWidgets('còn thay đổi chưa lên được thì vẫn phải phân biệt được',
      (tester) async {
    await dung(tester);
    dayLen.add(ketQua(thanhCong: 2, that: 3));
    await nhip(tester);

    expect(find.textContaining('chưa lên được'), findsOneWidget,
        reason: 'Không nêu số lượng, nhưng người dùng vẫn phải phân biệt được '
            '"đã xong" với "còn kẹt lại" — gộp hai trạng thái ấy vào một câu là '
            'để họ tưởng dữ liệu đã an toàn.');
    expect(find.textContaining('3'), findsNothing);
  });

  testWidgets('không có thay đổi nào thì không hiện toast', (tester) async {
    await dung(tester);
    dayLen.add(ketQua(thanhCong: 0));
    await nhip(tester);

    expect(find.textContaining('đồng bộ'), findsNothing,
        reason: '"Đã đồng bộ 0 thay đổi" là câu vô nghĩa. SyncEngine đã không '
            'phát trong trường hợp này, nhưng toast cũng phải tự chống.');
  });

  group('thứ tự ưu tiên giữa các toast', () {
    testWidgets('toast "đã kết nối lại" KHÔNG được ghi đè toast đồng bộ',
        (tester) async {
      await dung(tester);
      // Đúng thứ tự quan sát được trên máy thật: SyncEngine phản ứng ngay khi
      // mạng về và đẩy xong sau ~0,4 giây, còn ConnectionMonitor phải chờ hết
      // ngưỡng ổn định (3 giây) mới báo "đã kết nối lại".
      dayLen.add(ketQua(thanhCong: 2));
      await nhip(tester);
      ketNoi.add(ConnectionEvent.khoiPhuc);
      await nhip(tester);

      expect(find.textContaining('Đã đồng bộ'), findsOneWidget,
          reason: '"Đã đồng bộ xong" trả lời câu người dùng thật sự lo: dữ '
              'liệu ghi lúc mất mạng đã an toàn chưa. "Đã kết nối lại" không '
              'trả lời câu đó, nên để nó ghi đè là nuốt mất thứ đáng nói.');
      expect(find.textContaining('Đã kết nối lại'), findsNothing);
    });

    testWidgets('đồng bộ xong SAU thì vẫn ghi đè được toast khôi phục',
        (tester) async {
      await dung(tester);
      ketNoi.add(ConnectionEvent.khoiPhuc);
      await nhip(tester);
      dayLen.add(ketQua(thanhCong: 3));
      await nhip(tester);

      expect(find.textContaining('Đã đồng bộ'), findsOneWidget,
          reason: 'Chiều ngược lại thì tin mới cụ thể hơn, phải được hiện.');
    });

    testWidgets('mất mạng luôn thắng mọi toast khác', (tester) async {
      await dung(tester);
      dayLen.add(ketQua(thanhCong: 2));
      await nhip(tester);
      ketNoi.add(ConnectionEvent.mat);
      await nhip(tester);

      expect(find.textContaining('Không có kết nối'), findsOneWidget,
          reason: 'Mất mạng là trạng thái đang diễn ra, quan trọng hơn mọi tin '
              'về việc vừa xong.');
    });

    testWidgets('toast đồng bộ ẩn rồi thì khôi phục hiện được bình thường',
        (tester) async {
      await dung(tester);
      dayLen.add(ketQua(thanhCong: 2));
      await nhip(tester);
      await choTanHan(tester);

      ketNoi.add(ConnectionEvent.khoiPhuc);
      await nhip(tester);

      expect(find.textContaining('Đã kết nối lại'), findsOneWidget,
          reason: 'Ưu tiên chỉ áp dụng khi toast đồng bộ CÒN đang hiện. Chặn '
              'vĩnh viễn là lần mất mạng sau không báo khôi phục được nữa.');
    });
  });

  group('sự kiện thời gian thực', () {
    testWidgets('giao dịch ngân hàng hiện đúng câu, không kèm số',
        (tester) async {
      await dung(tester);
      realtime.add(RealtimeEvent.giaoDichNganHang);
      await nhip(tester);

      expect(find.text('Vừa có giao dịch mới từ ngân hàng'), findsOneWidget);
    });

    testWidgets('hoá đơn trùng hiện câu cảnh báo', (tester) async {
      await dung(tester);
      realtime.add(RealtimeEvent.ocrTrung);
      await nhip(tester);

      expect(
          find.text('Hoá đơn này đã được ghi nhận trước đó'), findsOneWidget);
    });

    testWidgets('đồng bộ xong ở máy khác KHÔNG hiện toast nào', (tester) async {
      await dung(tester);
      realtime.add(RealtimeEvent.dongBoXong);
      await nhip(tester);

      expect(find.byType(Icon), findsNothing,
          reason: 'sync.completed chỉ kéo dữ liệu về, im lặng. Máy vừa đẩy '
              'cũng nhận lại sự kiện này nên toast "máy khác vừa đổi" sẽ hiện '
              'sai trên chính máy vừa ghi, sau MỖI lần ghi. Mọi toast của '
              'widget này đều có icon, nên không icon = không toast.');
      expect(find.text('nội dung màn hình'), findsOneWidget);
    });

    testWidgets('toast realtime cũng tự ẩn', (tester) async {
      await dung(tester);
      realtime.add(RealtimeEvent.ocrXong);
      await nhip(tester);
      expect(find.text('Đã bóc tách xong hoá đơn'), findsOneWidget);

      await choTanHan(tester);
      expect(find.text('Đã bóc tách xong hoá đơn'), findsNothing);
    });

    testWidgets('realtime ghi đè được toast kết nối', (tester) async {
      await dung(tester);
      ketNoi.add(ConnectionEvent.khoiPhuc);
      await nhip(tester);
      realtime.add(RealtimeEvent.giaoDichNganHang);
      await nhip(tester);

      expect(find.text('Vừa có giao dịch mới từ ngân hàng'), findsOneWidget,
          reason: 'Realtime xếp trên trạng thái kết nối: nó nói về một việc vừa '
              'xảy ra với tiền của người dùng.');
      expect(find.textContaining('Đã kết nối lại'), findsNothing);
    });

    testWidgets('realtime KHÔNG ghi đè kết quả đồng bộ đang hiện',
        (tester) async {
      await dung(tester);
      dayLen.add(ketQua(thanhCong: 2));
      await nhip(tester);
      realtime.add(RealtimeEvent.giaoDichNganHang);
      await nhip(tester);

      expect(find.textContaining('Đã đồng bộ'), findsOneWidget,
          reason: 'Thứ tự ưu tiên: đồng bộ > realtime > kết nối. Toast đồng bộ '
              'trả lời câu người dùng thật sự lo — dữ liệu vừa ghi đã an toàn '
              'chưa.');
      expect(find.text('Vừa có giao dịch mới từ ngân hàng'), findsNothing);
    });

    testWidgets('sự kiện bị nuốt KHÔNG được xếp hàng hiện sau', (tester) async {
      await dung(tester);
      dayLen.add(ketQua(thanhCong: 2));
      await nhip(tester);
      realtime.add(RealtimeEvent.giaoDichNganHang);
      await nhip(tester);

      // Toast đồng bộ hết hạn và biến mất.
      await choTanHan(tester);

      expect(find.text('Vừa có giao dịch mới từ ngân hàng'), findsNothing,
          reason: 'Thông báo tạm thời trễ vài giây là thông báo sai ngữ cảnh: '
              'người dùng đã chuyển sang việc khác. Bỏ hẳn, không xếp hàng.');
    });

    testWidgets('toast đồng bộ ẩn rồi thì realtime hiện được bình thường',
        (tester) async {
      await dung(tester);
      dayLen.add(ketQua(thanhCong: 2));
      await nhip(tester);
      await choTanHan(tester);

      realtime.add(RealtimeEvent.ocrXong);
      await nhip(tester);

      expect(find.text('Đã bóc tách xong hoá đơn'), findsOneWidget,
          reason: 'Ưu tiên chỉ áp dụng khi toast đồng bộ CÒN đang hiện. Chặn '
              'vĩnh viễn là sự kiện realtime về sau không bao giờ hiện được '
              'nữa.');
    });

    testWidgets('mất kết nối vẫn thắng realtime', (tester) async {
      await dung(tester);
      realtime.add(RealtimeEvent.giaoDichNganHang);
      await nhip(tester);
      ketNoi.add(ConnectionEvent.mat);
      await nhip(tester);

      expect(find.textContaining('Không có kết nối'), findsOneWidget,
          reason: 'Mất mạng là trạng thái đang diễn ra và nói về an toàn dữ '
              'liệu, nên nó xếp ngang bậc đồng bộ chứ không phải bậc kết nối.');
    });
  });

  group('bố cục', () {
    testWidgets('toast nổi ĐÈ lên nội dung, và nằm ở nửa dưới màn hình',
        (tester) async {
      await dung(tester);
      final truoc = tester.getTopLeft(find.text('nội dung màn hình')).dy;

      ketNoi.add(ConnectionEvent.mat);
      await nhip(tester);

      final sau = tester.getTopLeft(find.text('nội dung màn hình')).dy;
      expect(sau, truoc,
          reason: 'Đây là ĐẢO NGƯỢC có chủ đích của quyết định cũ. Bản trước '
              'đặt dải trong Column để nó đẩy nội dung xuống, vì dải nổi Ở ĐỈNH '
              'che mất thanh tiêu đề và nút chuông — quan sát được trên máy '
              'thật. Đặt ở ĐÁY thì lý lẽ ấy không còn áp dụng: không có gì quan '
              'trọng nằm dưới đó, nên nổi đè là đúng, và đổi lại là trang không '
              'bị giật một cú mỗi lần có thông báo.');

      final hopToast =
          tester.getRect(find.byIcon(Icons.cloud_off_outlined));
      final khungApp = tester.getRect(find.byType(AppToast));
      expect(hopToast.center.dy, greaterThan(khungApp.center.dy),
          reason: 'Toast phải nằm ở nửa dưới. Trôi lên nửa trên là quay lại '
              'đúng chỗ hỏng cũ — che thanh tiêu đề.');
    });

    testWidgets('nội dung KHÔNG nhúc nhích dù toast hiện hay ẩn',
        (tester) async {
      await dung(tester);
      final banDau = tester.getTopLeft(find.text('nội dung màn hình')).dy;

      ketNoi.add(ConnectionEvent.khoiPhuc);
      await nhip(tester);
      expect(tester.getTopLeft(find.text('nội dung màn hình')).dy, banDau);

      await choTanHan(tester);
      expect(tester.getTopLeft(find.text('nội dung màn hình')).dy, banDau,
          reason: 'Toast nổi không được chạm vào bố cục trang, ở cả hai chiều. '
              'Bản dải cũ đẩy nội dung xuống rồi kéo lên — mỗi thông báo là một '
              'cú giật.');
    });

    testWidgets('viên thu gọn theo nội dung, không kéo hết bề ngang',
        (tester) async {
      await dung(tester);
      ketNoi.add(ConnectionEvent.khoiPhuc);
      await nhip(tester);
      await tester.pump(thoiGianHieuUngToast);

      final vien = tester.getRect(find.byIcon(Icons.cloud_done_outlined));
      final khungApp = tester.getRect(find.byType(AppToast));
      // Viên ôm lấy nội dung nên mép trái của nó phải nằm sâu trong màn hình,
      // không dính mép. Đo qua huy hiệu tròn bên trái là đủ.
      expect(vien.left, greaterThan(khungApp.width * 0.2),
          reason: 'Câu "Đã kết nối lại" rất ngắn, nên viên phải hẹp và nằm giữa. '
              'Kéo hết bề ngang là quay lại đúng cái dải người dùng không '
              'thích.');
    });

    testWidgets('câu dài không làm tràn bố cục ở màn hẹp', (tester) async {
      tester.view.physicalSize = const Size(411, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await dung(tester);
      ketNoi.add(ConnectionEvent.mat);
      await nhip(tester);
      await tester.pump(thoiGianHieuUngToast);

      expect(tester.takeException(), isNull,
          reason: 'Điện thoại thật rộng 411dp, còn bộ test mặc định 800dp. '
              'Flutter báo tràn qua FlutterError.reportError chứ KHÔNG ném ra '
              'chỗ gọi, nên một test chỉ pumpWidget + find sẽ xanh ngay cả khi '
              'màn hình đầy sọc cảnh báo.');
    });
  });

  testWidgets('mất mạng lần nữa thì toast quay lại', (tester) async {
    await dung(tester);
    ketNoi.add(ConnectionEvent.mat);
    await nhip(tester);
    ketNoi.add(ConnectionEvent.khoiPhuc);
    await choTanHan(tester);
    ketNoi.add(ConnectionEvent.mat);
    await nhip(tester);

    expect(find.textContaining('Không có kết nối'), findsOneWidget);
  });
}
