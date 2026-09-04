/// Dải báo kết nối chạy trên mọi màn hình.
///
/// Ba thứ nó nói, theo đúng thứ tự người dùng gặp:
///
/// 1. **Mất kết nối** — và quan trọng nhất là câu trấn an đi kèm: thay đổi vẫn
///    được lưu trên máy. Không có câu đó, người dùng sẽ ngừng nhập liệu vì sợ
///    mất, mà đó chính là thứ kiến trúc offline-first sinh ra để tránh.
/// 2. **Đã kết nối lại.**
/// 3. **Đã đồng bộ xong** — hoặc còn thay đổi chưa lên được.
///
/// **Cả ba đều tự ẩn sau vài giây**, kể cả dải mất kết nối. Bản đầu giữ dải mất
/// kết nối cho tới khi có mạng, với lập luận "trạng thái kéo dài thì phải hiển
/// thị kéo dài". Người dùng thử trên máy thật và yêu cầu đổi: một dải đứng mãi
/// trên đầu màn hình gây khó chịu hơn là hữu ích.
///
/// Cũng vì thế, thông báo đồng bộ **không nêu số lượng** — nói đủ ý là xong.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/network/connection_monitor.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/shared/widgets/connection_banner.dart';

void main() {
  const tuAn = Duration(milliseconds: 80);

  late StreamController<ConnectionEvent> ketNoi;
  late StreamController<SyncResult> dayLen;

  setUp(() {
    ketNoi = StreamController<ConnectionEvent>.broadcast();
    dayLen = StreamController<SyncResult>.broadcast();
  });

  tearDown(() async {
    await ketNoi.close();
    await dayLen.close();
  });

  Future<void> dung(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConnectionBanner(
          connectionEvents: ketNoi.stream,
          pushResults: dayLen.stream,
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

  SyncResult ketQua({required int thanhCong, int that = 0}) => SyncResult(
        totalOps: thanhCong + that,
        succeeded: thanhCong,
        failed: that,
      );

  testWidgets('bình thường thì không có dải nào', (tester) async {
    await dung(tester);

    expect(find.textContaining('kết nối'), findsNothing);
    expect(find.text('nội dung màn hình'), findsOneWidget,
        reason: 'Dải chỉ bọc quanh, không được thay thế nội dung màn hình.');
  });

  testWidgets('mất mạng thì hiện dải kèm câu trấn an', (tester) async {
    await dung(tester);
    ketNoi.add(ConnectionEvent.mat);
    await nhip(tester);

    expect(find.textContaining('Không có kết nối'), findsOneWidget);
    expect(find.textContaining('vẫn được lưu'), findsOneWidget,
        reason: 'Thiếu câu này người dùng sẽ ngừng nhập liệu vì sợ mất dữ '
            'liệu — đúng nỗi sợ mà offline-first sinh ra để xoá bỏ.');
  });

  testWidgets('dải mất kết nối cũng tự ẩn sau vài giây', (tester) async {
    await dung(tester);
    ketNoi.add(ConnectionEvent.mat);
    await nhip(tester);

    expect(find.textContaining('Không có kết nối'), findsOneWidget);

    await tester.pump(tuAn * 3);
    expect(find.textContaining('Không có kết nối'), findsNothing,
        reason: 'Người dùng yêu cầu mọi dải đều biến mất sau vài giây. Một dải '
            'đứng mãi trên đầu màn hình gây khó chịu hơn là hữu ích — thông tin '
            '"đang mất mạng" đã có sẵn ở thanh trạng thái của hệ điều hành.');
  });

  testWidgets('có mạng lại thì đổi sang dải khôi phục rồi tự ẩn',
      (tester) async {
    await dung(tester);
    ketNoi.add(ConnectionEvent.mat);
    await nhip(tester);
    ketNoi.add(ConnectionEvent.khoiPhuc);
    await nhip(tester);

    expect(find.textContaining('Đã kết nối lại'), findsOneWidget);
    expect(find.textContaining('Không có kết nối'), findsNothing,
        reason: 'Hai dải không được chồng lên nhau.');

    await tester.pump(tuAn * 2);
    expect(find.textContaining('Đã kết nối lại'), findsNothing,
        reason: 'Đây là sự kiện vừa xảy ra, không phải trạng thái — để mãi thì '
            'nó chiếm chỗ vô ích.');
  });

  testWidgets('đẩy thành công thì báo chung chung, KHÔNG nêu số', (tester) async {
    await dung(tester);
    dayLen.add(ketQua(thanhCong: 5));
    await nhip(tester);

    expect(find.textContaining('đồng bộ'), findsOneWidget);
    expect(find.textContaining('5'), findsNothing,
        reason: 'Người dùng không cần biết bao nhiêu bản ghi vừa lên server — '
            'con số ấy là chi tiết cài đặt, không phải điều họ quan tâm. Biết '
            '"đã xong" là đủ.');

    await tester.pump(tuAn * 2);
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

  testWidgets('không có thay đổi nào thì không hiện dải', (tester) async {
    await dung(tester);
    dayLen.add(ketQua(thanhCong: 0));
    await nhip(tester);

    expect(find.textContaining('đồng bộ'), findsNothing,
        reason: '"Đã đồng bộ 0 thay đổi" là câu vô nghĩa. SyncEngine đã không '
            'phát trong trường hợp này, nhưng dải cũng phải tự chống.');
  });

  group('thứ tự ưu tiên giữa các dải', () {
    testWidgets('dải "đã kết nối lại" KHÔNG được ghi đè dải đồng bộ',
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

    testWidgets('đồng bộ xong SAU thì vẫn ghi đè được dải khôi phục',
        (tester) async {
      await dung(tester);
      ketNoi.add(ConnectionEvent.khoiPhuc);
      await nhip(tester);
      dayLen.add(ketQua(thanhCong: 3));
      await nhip(tester);

      expect(find.textContaining('Đã đồng bộ'), findsOneWidget,
          reason: 'Chiều ngược lại thì tin mới cụ thể hơn, phải được hiện.');
    });

    testWidgets('mất mạng luôn thắng mọi dải khác', (tester) async {
      await dung(tester);
      dayLen.add(ketQua(thanhCong: 2));
      await nhip(tester);
      ketNoi.add(ConnectionEvent.mat);
      await nhip(tester);

      expect(find.textContaining('Không có kết nối'), findsOneWidget,
          reason: 'Mất mạng là trạng thái đang diễn ra, quan trọng hơn mọi tin '
              'về việc vừa xong.');
    });

    testWidgets('dải đồng bộ ẩn rồi thì khôi phục hiện được bình thường',
        (tester) async {
      await dung(tester);
      dayLen.add(ketQua(thanhCong: 2));
      await nhip(tester);
      await tester.pump(tuAn * 2);

      ketNoi.add(ConnectionEvent.khoiPhuc);
      await nhip(tester);

      expect(find.textContaining('Đã kết nối lại'), findsOneWidget,
          reason: 'Ưu tiên chỉ áp dụng khi dải đồng bộ CÒN đang hiện. Chặn '
              'vĩnh viễn là lần mất mạng sau không báo khôi phục được nữa.');
    });
  });

  testWidgets('dải KHÔNG được đè lên nội dung màn hình', (tester) async {
    await dung(tester);
    final truoc = tester.getTopLeft(find.text('nội dung màn hình')).dy;

    ketNoi.add(ConnectionEvent.mat);
    await nhip(tester);

    final dayDai = tester.getBottomLeft(find.byIcon(Icons.cloud_off_outlined)).dy;
    final sau = tester.getTopLeft(find.text('nội dung màn hình')).dy;

    expect(sau, greaterThanOrEqualTo(dayDai),
        reason: 'Dải nổi đè lên nội dung sẽ che mất thanh tiêu đề và nút chuông '
            'của trang bên dưới — quan sát được trên máy thật. Nội dung phải bị '
            'đẩy xuống, không phải bị che.');
    expect(sau, greaterThan(truoc),
        reason: 'Trước khi có dải thì nội dung nằm sát mép trên; có dải thì nó '
            'phải lùi xuống.');
  });

  testWidgets('dải ẩn rồi thì nội dung trở lại vị trí cũ', (tester) async {
    await dung(tester);
    final banDau = tester.getTopLeft(find.text('nội dung màn hình')).dy;

    ketNoi.add(ConnectionEvent.khoiPhuc);
    await nhip(tester);
    await tester.pump(tuAn * 2);

    expect(tester.getTopLeft(find.text('nội dung màn hình')).dy, banDau,
        reason: 'Dải biến mất mà nội dung vẫn bị đẩy xuống là để lại một khoảng '
            'trống không ai giải thích được.');
  });

  testWidgets('mất mạng lần nữa thì dải quay lại', (tester) async {
    await dung(tester);
    ketNoi.add(ConnectionEvent.mat);
    await nhip(tester);
    ketNoi.add(ConnectionEvent.khoiPhuc);
    await tester.pump(tuAn * 2);
    ketNoi.add(ConnectionEvent.mat);
    await nhip(tester);

    expect(find.textContaining('Không có kết nối'), findsOneWidget);
  });
}
