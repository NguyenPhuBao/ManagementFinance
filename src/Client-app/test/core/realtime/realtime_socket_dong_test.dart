/// `IoRealtimeSocket` khi SERVER cắt socket (khoá tài khoản → `account.force_logout`, admin ngắt): `socket_io_client` 3.1.6
/// nhận gói `41` (server disconnect) → `Manager.close` → `WebSocketTransport.doClose` gọi `_ws?.close()` KHÔNG `await`,
/// không bắt lỗi; mà `package:web_socket` ném `WebSocketConnectionClosed` (trong Future) khi khung đóng của server đã tới
/// trước → *"Unhandled Exception: WebSocketConnectionClosed"* lọt ra zone gốc (quan sát trên Realme 2026-10-25, buổi 2b).
///
/// Máy chủ Engine.IO v4 giả trên loopback, chỉ đủ để bắt tay: gói mở `0{…}`, nhận `40…` → trả `40{…}`, rồi cắt bằng `41` +
/// khung đóng trong một lần ghi (cùng khuôn `socket.disconnect(true)` của server Node). I/O thật — `test()` thường, không
/// widget test.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha1;

import 'package:flowmoney/core/realtime/realtime_socket.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket/web_socket.dart' as ws;

/// Máy chủ WebSocket viết tay trên `ServerSocket` thô — để gửi khung `41` và khung ĐÓNG trong CÙNG một lần ghi (cùng một
/// lần đọc phía client, như hai gói nhỏ đi chung một đoạn TCP trên mạng thật). `HttpServer` + `WebSocket` của `dart:io` ghi
/// hai khung ở hai lần, client xử lý xong `41` trước khi thấy khung đóng — kịch bản ấy KHÔNG tái hiện lỗi (đã thử: xanh cả
/// khi chưa bọc).
class _MayChuEio {
  _MayChuEio._(this._server);

  final ServerSocket _server;
  final List<Socket> _ketNoi = [];

  int get cong => _server.port;

  static List<int> _khung(int opcode, List<int> duLieu) {
    assert(duLieu.length < 126);
    return [0x80 | opcode, duLieu.length, ...duLieu];
  }

  static List<int> _chu(String s) => _khung(0x1, utf8.encode(s));

  static Future<_MayChuEio> mo() async {
    final may = _MayChuEio._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));
    may._server.listen((sock) {
      may._ketNoi.add(sock);
      final dem = <int>[];
      var daBatTay = false;
      sock.listen((b) {
        dem.addAll(b);
        if (!daBatTay) {
          final yc = latin1.decode(dem);
          final het = yc.indexOf('\r\n\r\n');
          if (het < 0) return;
          final key = RegExp(r'Sec-WebSocket-Key: *(\S+)', caseSensitive: false).firstMatch(yc)!.group(1)!;
          final chapNhan = base64.encode(sha1.convert(utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11')).bytes);
          sock.add(latin1.encode('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
              'Sec-WebSocket-Accept: $chapNhan\r\n\r\n'));
          sock.add(_chu('0{"sid":"s1","upgrades":[],"pingInterval":25000,"pingTimeout":20000,"maxPayload":1000000}'));
          dem.removeRange(0, het + 4); // latin1: một ký tự một byte
          daBatTay = true;
        }
        // Khung của client (có mặt nạ, dài < 126): chỉ cần nhận ra gói CONNECT `40…` để trả `40{…}`.
        while (dem.length >= 6) {
          final dai = dem[1] & 0x7f;
          if (dem.length < 6 + dai) return;
          final matNa = dem.sublist(2, 6);
          final noiDung = [for (var i = 0; i < dai; i++) dem[6 + i] ^ matNa[i % 4]];
          final opcode = dem[0] & 0x0f;
          dem.removeRange(0, 6 + dai);
          if (opcode == 0x1 && utf8.decode(noiDung).startsWith('40')) sock.add(_chu('40{"sid":"n1"}'));
          if (opcode == 0x8) sock.destroy();
        }
      }, onError: (_) {});
    });
    return may;
  }

  /// `41` (server disconnect) + khung đóng 1000 trong MỘT lần ghi — cùng khuôn `socket.disconnect(true)` của server Node.
  void catTuServer() {
    for (final s in _ketNoi) {
      s.add([..._chu('41'), ..._khung(0x8, [0x03, 0xE8])]);
    }
  }

  Future<void> dong() async {
    for (final s in _ketNoi) {
      s.destroy();
    }
    await _server.close();
  }
}

void main() {
  test('server cắt socket (41 + đóng liền) → không lỗi WebSocketConnectionClosed nào lọt ra zone', () async {
    const soLan = 5; // lặp vài lượt: thứ tự hai khung trên loopback gần như luôn cùng một lần đọc
    final loi = <Object>[];
    final xong = Completer<void>();
    runZonedGuarded(() async {
      for (var i = 0; i < soLan; i++) {
        final may = await _MayChuEio.mo();
        final s = IoRealtimeSocket(url: 'http://127.0.0.1:${may.cong}', token: 't');
        final daNoi = Completer<void>();
        final daNgat = Completer<void>();
        s.onConnect(() {
          if (!daNoi.isCompleted) daNoi.complete();
        });
        s.onDisconnect((_) {
          if (!daNgat.isCompleted) daNgat.complete();
        });
        s.connect();
        await daNoi.future.timeout(const Duration(seconds: 5));
        may.catTuServer();
        await daNgat.future.timeout(const Duration(seconds: 5));
        // Future `close()` hỏng (nếu có) nổ ở lượt sự kiện sau — chờ cho nó kịp nổ.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        s.dispose();
        await may.dong();
      }
      xong.complete();
    }, (e, _) {
      loi.add(e);
      if (e is! ws.WebSocketConnectionClosed && !xong.isCompleted) xong.completeError(e);
    });
    await xong.future.timeout(const Duration(seconds: 30));
    expect(loi.whereType<ws.WebSocketConnectionClosed>(), isEmpty,
        reason: 'doClose của socket_io_client gọi close() không await — kết nối phải được bọc để close() lần hai im lặng');
    expect(loi, isEmpty);
  });

  test('WebSocketDongEm: close() sau khi server đã đóng KHÔNG ném; bản gốc thì ném (canh hành vi thư viện)', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async => (await WebSocketTransformer.upgrade(req)).close());
    final uri = Uri.parse('ws://127.0.0.1:${server.port}');

    final goc = await ws.WebSocket.connect(uri);
    await goc.events.drain<void>();
    await expectLater(goc.close(), throwsA(isA<ws.WebSocketConnectionClosed>()),
        reason: 'nếu thư viện thôi ném ở đây thì lớp bọc không còn cần — xét gỡ');

    final boc = WebSocketDongEm(await ws.WebSocket.connect(uri));
    await boc.events.drain<void>();
    await boc.close();
    await server.close(force: true);
  });
}
