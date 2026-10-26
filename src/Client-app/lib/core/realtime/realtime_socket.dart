import 'dart:typed_data';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:web_socket/web_socket.dart' as ws;

/// Mặt cắt giữa `RealtimeChannel` và `socket_io_client`.
///
/// Tồn tại để bộ test dựng được kênh mà **không** cần mạng, không cần backend,
/// và không cần chính gói socket. Đây là tệp DUY NHẤT trong `lib/` import
/// `socket_io_client`.
abstract class RealtimeSocket {
  /// Nghe MỌI sự kiện do server gửi. Dùng `onAny` chứ không đăng ký từng tên:
  /// client chỉ quan tâm tới tên sự kiện, và cách này khiến việc "quên đăng ký
  /// một sự kiện" không thể xảy ra.
  void onAny(void Function(String event, dynamic data) handler);

  void onConnect(void Function() handler);
  void onConnectError(void Function(Object? error) handler);
  void onDisconnect(void Function(Object? reason) handler);

  void connect();
  void dispose();
}

typedef RealtimeSocketFactory = RealtimeSocket Function({
  required String url,
  required String token,
});

/// Bản cài đặt thật, mỏng đến mức không có gì để test.
///
/// Ba lựa chọn ở đây đều có lý do:
///
/// - `disableAutoConnect()` — phải đọc token bất đồng bộ xong mới nối.
/// - `disableReconnection()` — `RealtimeChannel` tự lo việc nối lại, vì mỗi lần
///   thử phải **đọc lại token**; cơ chế của thư viện dùng lại nguyên tham số
///   bắt tay cũ nên một token đã hết hạn sẽ bị thử lại vô hạn.
/// - `enableForceNew()` — ⚠️ `io.io()` cache `Manager` theo `scheme://host:port`
///   và **dùng lại options của lần dựng đầu**. Không có cờ này thì token mới
///   truyền vào `setAuth` có thể bị bỏ qua trong im lặng.
/// - `setWebSocketConnector(noiWebSocketDongEm)` — xem [WebSocketDongEm].
class IoRealtimeSocket implements RealtimeSocket {
  IoRealtimeSocket({required String url, required String token})
      : _socket = io.io(
          url,
          io.OptionBuilder()
              .setTransports(['websocket', 'polling'])
              .disableAutoConnect()
              .disableReconnection()
              .enableForceNew()
              .setAuth({'token': token})
              .setWebSocketConnector(noiWebSocketDongEm)
              .build(),
        );

  final io.Socket _socket;

  @override
  void onAny(void Function(String event, dynamic data) handler) {
    _socket.onAny((event, data) => handler(event, data));
  }

  @override
  void onConnect(void Function() handler) => _socket.onConnect((_) => handler());

  @override
  void onConnectError(void Function(Object? error) handler) =>
      _socket.onConnectError((e) => handler(e));

  @override
  void onDisconnect(void Function(Object? reason) handler) =>
      _socket.onDisconnect((r) => handler(r));

  @override
  void connect() => _socket.connect();

  @override
  void dispose() {
    _socket.dispose();
  }
}

/// Nối WebSocket như bộ nối mặc định của `socket_io_client`, rồi bọc bằng [WebSocketDongEm]. Không chuyển `headers`: kênh
/// không dùng `setExtraHeaders` (token đi trong gói `auth`), và `ws.WebSocket.connect` chạy được cả web.
Future<ws.WebSocket> noiWebSocketDongEm(Uri uri, {Iterable<String>? protocols, Map<String, String>? headers}) async =>
    WebSocketDongEm(await ws.WebSocket.connect(uri, protocols: protocols));

/// Kết nối mà `close()` không ném khi server đã đóng trước.
///
/// `socket_io_client` 3.1.6 (`WebSocketTransport.doClose`) gọi `_ws?.close()` KHÔNG `await`, không bắt lỗi; còn
/// `package:web_socket` 1.0.x ném `WebSocketConnectionClosed` từ `close()` khi khung đóng của server đã tới. Server cắt
/// socket bằng gói `41` + đóng liền (khoá tài khoản → `account.force_logout`) là đúng ca ấy → mỗi lần một dòng
/// *"Unhandled Exception: WebSocketConnectionClosed"* ở zone gốc (vô hại cho luồng — `disconnect` vẫn phát — nhưng làm
/// nhiễu log và mọi bộ bắt lỗi toàn cục sau này). Đã đóng thì "đóng lần nữa" là xong: nuốt đúng lỗi ấy, lỗi khác giữ.
class WebSocketDongEm implements ws.WebSocket {
  WebSocketDongEm(this._goc);

  final ws.WebSocket _goc;

  @override
  void sendText(String s) => _goc.sendText(s);

  @override
  void sendBytes(Uint8List b) => _goc.sendBytes(b);

  @override
  Future<void> close([int? code, String? reason]) async {
    try {
      await _goc.close(code, reason);
    } on ws.WebSocketConnectionClosed {
      // Server đã đóng trước — không còn gì để đóng.
    }
  }

  @override
  Stream<ws.WebSocketEvent> get events => _goc.events;

  @override
  String get protocol => _goc.protocol;
}
