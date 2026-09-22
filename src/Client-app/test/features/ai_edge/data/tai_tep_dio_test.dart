/// Mắt xích mà `mo_hinh_tai_ve_test.dart` **không** chứng minh được.
///
/// Ca ở tệp kia dùng một hàm tải giả, nên nó chỉ nói *"tín hiệu huỷ tới được
/// bên tải"*. Câu hỏi thật — *"byte có NGỪNG CHẢY về máy không"* — chỉ trả lời
/// được bằng một lượt tải thật. Ở đây là một server **cục bộ** phát byte chậm
/// và gần như không bao giờ hết: không cần mạng, không cần máy ảo, tất định.
///
/// ⚠️ **Phải là `ServerSocket` thô, KHÔNG phải `HttpServer`.** Đã thử bản
/// `HttpServer` trước và nó **báo sai**: `HttpResponse.flush()` về trơn tru
/// trên cả một kết nối đã chết, nên phép đếm "server gửi thêm bao nhiêu gói"
/// vẫn tăng đều sau khi huỷ (đo được 194 gói ≈ 13 MB trong 2,4 giây) và làm
/// người đọc tưởng phép huỷ hỏng. Với socket thô thì `onDone` của luồng đọc
/// báo đúng lúc đầu kia gửi FIN, và phép đếm mới nói thật: **thêm 0 gói**.
///
/// ⚠️ Vì sao tệp này tồn tại: bản đầu của tính năng để `huy()` đặt một cờ rồi
/// vẫn `await` cho tới khi tải xong **trọn 2,41 GB** — người dùng bấm Huỷ trên
/// dữ liệu di động vẫn mất chừng ấy dung lượng, im lặng. Không ca test nào với
/// tới được, vì phép tải khi ấy là một closure nằm trong
/// `injection_container.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/ai_edge/data/mo_hinh_tai_ve.dart';
import 'package:flowmoney/features/ai_edge/data/tai_tep_dio.dart';

const int _coGoi = 64 * 1024;

/// Server phát `soGoi` gói, mỗi gói cách nhau [nghi], và **đếm được** đã gửi
/// bao nhiêu — đó là phép đo chính của tệp này.
class _MayPhat {
  _MayPhat(this._srv, this.soGoi);

  final ServerSocket _srv;
  final int soGoi;

  int daGui = 0;
  bool peerDaDong = false;

  static Future<_MayPhat> mo({
    required int soGoi,
    Duration nghi = const Duration(milliseconds: 10),
  }) async {
    final srv = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final m = _MayPhat(srv, soGoi);
    srv.listen((sock) async {
      sock.listen(
        (_) {},
        onError: (_) => m.peerDaDong = true,
        onDone: () => m.peerDaDong = true,
      );
      sock.add(utf8.encode(
        'HTTP/1.1 200 OK\r\nContent-Length: ${soGoi * _coGoi}\r\n\r\n',
      ));
      try {
        for (var i = 0; i < soGoi; i++) {
          if (m.peerDaDong) break;
          sock.add(List.filled(_coGoi, 7));
          await sock.flush();
          m.daGui++;
          await Future<void>.delayed(nghi);
        }
        await sock.close();
      } catch (_) {
        m.peerDaDong = true;
      }
    });
    return m;
  }

  String get url => 'http://${_srv.address.address}:${_srv.port}/mo-hinh';

  Future<void> dong() => _srv.close();
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('taitep'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('⚠️ huỷ thì BYTE NGỪNG CHẢY, không chỉ là thôi đọc', () async {
    // 2000 gói × 10 ms = 20 giây nếu chạy hết.
    final may = await _MayPhat.mo(soGoi: 2000);
    addTearDown(may.dong);

    final dich = File('${tmp.path}/tai.bin');
    final dauHuy = DauHuy();
    final batDau = DateTime.now();
    final luot = taiTepQuaDio(may.url, dich, (_) {}, dauHuy);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    final lucHuy = may.daGui;
    expect(lucHuy, greaterThan(0), reason: 'Phải đang tải thật rồi mới huỷ.');
    dauHuy.huy();

    await expectLater(luot, throwsA(isA<DioException>()));
    expect(DateTime.now().difference(batDau).inMilliseconds, lessThan(3000),
        reason: 'Lượt này mất 20 giây nếu chạy hết — về sớm nghĩa là đã cắt.');

    await Future<void>.delayed(const Duration(seconds: 1));
    expect(may.daGui - lucHuy, lessThanOrEqualTo(1),
        reason: 'Đây mới là phép đo thật của lỗi: bấm Huỷ rồi thì đầu phát '
            'không được gửi thêm gì nữa. Một gói đang bay thì chấp nhận; cứ '
            'gửi tiếp là người dùng vẫn mất 2,41 GB họ tưởng đã chặn.');
    expect(may.peerDaDong, isTrue,
        reason: 'Đầu phát phải thấy kết nối đóng (FIN), không phải chỉ im.');
  });

  test('không huỷ thì tải xong, đủ byte và tiến độ chạm 1.0', () async {
    final may =
        await _MayPhat.mo(soGoi: 20, nghi: const Duration(milliseconds: 2));
    addTearDown(may.dong);

    final dich = File('${tmp.path}/du.bin');
    var tienDoCuoi = 0.0;
    await taiTepQuaDio(may.url, dich, (p) => tienDoCuoi = p, DauHuy());

    expect(dich.lengthSync(), 20 * _coGoi);
    expect(tienDoCuoi, closeTo(1.0, 0.0001),
        reason: 'Tiến độ phải chạm 1.0, nếu không thanh tiến độ đứng ở 99% '
            'trong khi tệp đã đủ.');
  });

  test('huỷ TRƯỚC khi bắt đầu thì không tải gì cả', () async {
    final may = await _MayPhat.mo(soGoi: 2000);
    addTearDown(may.dong);

    final dich = File('${tmp.path}/som.bin');
    await expectLater(
      taiTepQuaDio(may.url, dich, (_) {}, DauHuy()..huy()),
      throwsA(isA<DioException>()),
    );
  });
}
