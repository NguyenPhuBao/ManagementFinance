/// Cửa xuống phía Android để **lưu tệp vào thư mục Tải về**.
///
/// Canh chừng điều gì: đây là ranh giới giữa Dart và Kotlin, nơi sai sót không
/// bao giờ là lỗi biên dịch — gõ nhầm tên kênh, nhầm tên tham số, hay quên
/// nhánh "máy không hỗ trợ" đều chỉ hiện ra thành *"bấm Tải xuống mà chẳng
/// thấy gì"*. Bộ test không chạy được mã Kotlin, nhưng **hợp đồng gọi** thì
/// kiểm được.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/analytics/data/luu_tep_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> daGoi;
  Object? traVe;
  Object? nem;

  setUp(() {
    daGoi = [];
    traVe = 'Tải về/BaoCao.pdf';
    nem = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LuuTepPlatform.kenh, (call) async {
      daGoi.add(call);
      if (nem != null) throw nem!;
      return traVe;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LuuTepPlatform.kenh, null);
  });

  final bytes = Uint8List.fromList([1, 2, 3]);

  test('gọi đúng tên phương thức và đủ ba tham số', () async {
    final duong = await const LuuTepPlatform().luuVaoTaiVe(
      ten: 'BaoCao.pdf',
      mime: 'application/pdf',
      bytes: bytes,
    );

    expect(duong, 'Tải về/BaoCao.pdf');
    expect(daGoi.single.method, 'luuVaoTaiVe');
    final args = daGoi.single.arguments as Map;
    expect(args['ten'], 'BaoCao.pdf');
    expect(args['mime'], 'application/pdf',
        reason: 'MediaStore dùng MIME để xếp tệp vào đúng loại; gửi sai thì '
            'tệp vẫn lưu nhưng máy mở bằng ứng dụng khác.');
    expect(args['bytes'], bytes);
  });

  test('máy không hỗ trợ thì trả null chứ không ném — để bên gọi lùi phương án',
      () async {
    nem = PlatformException(code: 'khong_ho_tro');

    final duong = await const LuuTepPlatform().luuVaoTaiVe(
      ten: 'BaoCao.csv',
      mime: 'text/csv',
      bytes: bytes,
    );

    expect(duong, isNull,
        reason: 'Android 9 trở xuống không có MediaStore.Downloads. Ném lỗi ở '
            'đây là người dùng thấy màn báo lỗi trong khi vẫn còn đường lùi '
            '(sheet chia sẻ) chạy tốt.');
  });

  test('nền tảng không có kênh (web, desktop) cũng trả null', () async {
    nem = MissingPluginException('no impl');

    final duong = await const LuuTepPlatform()
        .luuVaoTaiVe(ten: 'a.csv', mime: 'text/csv', bytes: bytes);

    expect(duong, isNull);
  });

  test('lỗi ghi tệp THẬT thì ném lên, không nuốt', () async {
    nem = PlatformException(code: 'loi_ghi', message: 'hết chỗ trống');

    expect(
      () => const LuuTepPlatform()
          .luuVaoTaiVe(ten: 'a.pdf', mime: 'application/pdf', bytes: bytes),
      throwsA(isA<PlatformException>()),
      reason: 'Hết dung lượng là chuyện người dùng cần biết. Gộp nó vào nhánh '
          '"không hỗ trợ" là im lặng nuốt một lỗi thật.',
    );
  });
}
