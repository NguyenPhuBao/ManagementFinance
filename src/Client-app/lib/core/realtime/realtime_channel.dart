import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import 'realtime_event.dart';
import 'realtime_socket.dart';
import 'socket_base_url.dart';

/// Kết nối thời gian thực tới backend.
///
/// ## Vì sao không nằm trong `SyncEngine`
///
/// Cùng lý lẽ đã ghi trong `lib/core/network/connection_monitor.dart`: hai câu
/// hỏi khác nhau. `SyncEngine` trả lời *khi nào thì đồng bộ*; lớp này chỉ thuật
/// lại *server vừa nói gì*. Trộn vào một chỗ thì một trong hai phải chịu thiệt,
/// và `sync_engine.dart` đã hơn 1.600 dòng.
///
/// Lớp này **không tự gọi** `SyncEngine`. Nó chỉ phát ra [events]; việc nối
/// [events] vào `syncNow()` và vào toast do `main.dart` làm. Nhờ vậy nó test
/// được mà không cần dựng cả engine đồng bộ.
class RealtimeChannel {
  RealtimeChannel({
    required FlutterSecureStorage secureStorage,
    String? apiBaseUrl,
    RealtimeSocketFactory? socketFactory,
  })  : _kho = secureStorage,
        _apiBaseUrl = apiBaseUrl ?? AppConstants.baseUrl,
        _taoSocket = socketFactory ??
            (({required String url, required String token}) =>
                IoRealtimeSocket(url: url, token: token));

  final FlutterSecureStorage _kho;
  final String _apiBaseUrl;
  final RealtimeSocketFactory _taoSocket;

  final _controller = StreamController<RealtimeEvent>.broadcast();

  /// Sự kiện đã dịch sang enum. Không mang theo dữ liệu nào của payload.
  Stream<RealtimeEvent> get events => _controller.stream;

  RealtimeSocket? _socket;
  int? _idaccount;
  bool _daDung = true;

  /// Bật kênh sau khi đăng nhập thành công.
  ///
  /// [idaccount] không được gửi lên server — server tự suy room từ JWT. Nó ở
  /// đây để lớp này biết phiên nào đang sống, đúng quy tắc "danh tính chỉ đến
  /// từ phiên đăng nhập".
  Future<void> start({required int idaccount}) async {
    await stop();
    _daDung = false;
    _idaccount = idaccount;
    await _noi();
  }

  /// Tắt kênh khi đăng xuất hoặc khi phiên chết.
  Future<void> stop() async {
    _daDung = true;
    _idaccount = null;
    _socket?.dispose();
    _socket = null;
  }

  Future<void> _noi() async {
    if (_daDung) return;

    // Đọc token NGAY LÚC NỐI, không phải lúc dựng đối tượng: `AuthInterceptor`
    // có thể vừa làm mới nó.
    final token = await _kho.read(key: AppConstants.accessTokenKey);
    if (token == null || token.isEmpty) {
      debugPrint('[RealtimeChannel] Chưa có token — chưa nối');
      return;
    }
    if (_daDung) return; // `stop()` có thể đã chạy trong lúc đọc kho

    final socket = _taoSocket(
      url: socketBaseUrlFrom(_apiBaseUrl),
      token: token,
    );
    _socket = socket;

    socket
      ..onAny(_khiCoSuKien)
      ..onConnect(() {
        debugPrint('[RealtimeChannel] Đã nối (idaccount=$_idaccount)');
      })
      ..onConnectError((e) {
        debugPrint('[RealtimeChannel] Nối hỏng: $e');
      })
      ..onDisconnect((r) {
        debugPrint('[RealtimeChannel] Đứt kết nối: $r');
      })
      ..connect();
  }

  void _khiCoSuKien(String ten, dynamic _) {
    // Tham số thứ hai cố ý bỏ tên: payload KHÔNG được đọc. Xem chú thích đầu
    // `realtime_event.dart`.
    if (_daDung || _controller.isClosed) return;
    final suKien = realtimeEventFromName(ten);
    if (suKien == null) {
      debugPrint('[RealtimeChannel] Bỏ qua sự kiện lạ: $ten');
      return;
    }
    _controller.add(suKien);
  }
}
