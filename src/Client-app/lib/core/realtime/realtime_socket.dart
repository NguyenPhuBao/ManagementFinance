import 'package:socket_io_client/socket_io_client.dart' as io;

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
