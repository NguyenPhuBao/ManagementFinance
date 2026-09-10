import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import 'realtime_event.dart';
import 'realtime_socket.dart';
import 'socket_base_url.dart';

/// Bảng giãn cách giữa các lần nối lại.
///
/// Chạm trần thì giữ nguyên chứ không giãn tiếp: server hỏng cả ngày thì client
/// vẫn phải ngó lại mỗi phút, nếu không người dùng phải tự khởi động lại app.
const _bangKhoangCho = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
  Duration(seconds: 60),
];

/// Khoảng chờ trước lần thử kế tiếp, sau [lanThat] lần hỏng liên tiếp.
/// [lanThat] đếm từ 1.
Duration khoangChoLanThu(int lanThat) {
  if (lanThat < 1) return _bangKhoangCho.first;
  final i = lanThat - 1;
  return i < _bangKhoangCho.length ? _bangKhoangCho[i] : _bangKhoangCho.last;
}

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
    Connectivity? connectivity,
  })  : _kho = secureStorage,
        _apiBaseUrl = apiBaseUrl ?? AppConstants.baseUrl,
        _mang = connectivity ?? Connectivity(),
        _taoSocket = socketFactory ??
            (({required String url, required String token}) =>
                IoRealtimeSocket(url: url, token: token));

  final FlutterSecureStorage _kho;
  final String _apiBaseUrl;
  final RealtimeSocketFactory _taoSocket;
  final Connectivity _mang;

  final _controller = StreamController<RealtimeEvent>.broadcast();

  /// Sự kiện đã dịch sang enum. Không mang theo dữ liệu nào của payload.
  Stream<RealtimeEvent> get events => _controller.stream;

  RealtimeSocket? _socket;
  int? _idaccount;
  bool _daDung = true;
  Timer? _henNoiLai;
  int _soLanHong = 0;
  StreamSubscription<List<ConnectivityResult>>? _subMang;

  /// Có đang nối được hay không. Chỉ dùng để khỏi bắn thêm một lần nối khi
  /// mạng nhấp nháy lúc socket vẫn đang khoẻ.
  bool _dangNoi = false;

  /// Bật kênh sau khi đăng nhập thành công.
  ///
  /// [idaccount] không được gửi lên server — server tự suy room từ JWT. Nó ở
  /// đây để lớp này biết phiên nào đang sống, đúng quy tắc "danh tính chỉ đến
  /// từ phiên đăng nhập".
  Future<void> start({required int idaccount}) async {
    await stop();
    _daDung = false;
    _idaccount = idaccount;

    // Mạng về thì nối lại NGAY, đừng nằm chờ hết giãn cách.
    //
    // Đo trên máy ảo 2026-09-09: sau bốn lần hỏng, giãn cách đã lên 30 giây;
    // mạng về lúc 16:51:36 mà kênh im tới 16:52:02 mới nối. Giãn cách sinh ra
    // để khỏi dội vào một server đang hỏng, KHÔNG phải để phạt người dùng vừa
    // đi qua một cái hầm — và tín hiệu "vừa có mạng" nói rõ rằng lần hỏng
    // trước đó không còn nói gì về hiện tại.
    //
    // `SyncEngine.start()` nghe cùng luồng này với cùng lý do.
    await _subMang?.cancel();
    _subMang = _mang.onConnectivityChanged.listen((results) {
      final coMang = results.any((r) => r != ConnectivityResult.none);
      // Chỉ sự kiện CÓ mạng mới đáng nối lại; phản ứng với cả sự kiện mất mạng
      // là tự bắn thêm một lần nối chắc chắn hỏng.
      if (!coMang || _daDung || _dangNoi) return;
      debugPrint('[RealtimeChannel] Có mạng trở lại — nối lại ngay');
      _soLanHong = 0;
      _henNoiLai?.cancel();
      _henNoiLai = null;
      _socket?.dispose();
      _socket = null;
      unawaited(_noi());
    });

    await _noi();
  }

  /// Tắt kênh khi đăng xuất hoặc khi phiên chết.
  Future<void> stop() async {
    _daDung = true;
    _idaccount = null;
    // Huỷ hẹn giờ TRƯỚC: một lần nối lại nổ sau khi đăng xuất là nối lại bằng
    // token của người vừa rời đi.
    _henNoiLai?.cancel();
    _henNoiLai = null;
    _soLanHong = 0;
    _dangNoi = false;
    await _subMang?.cancel();
    _subMang = null;
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
        _dangNoi = true;
        // Nối được thì lịch sử hỏng cũ không còn nói gì về hiện tại. Không
        // reset thì một máy từng mất mạng lâu sẽ mãi chờ 60 giây cho mỗi lần
        // chớp mạng về sau.
        _soLanHong = 0;
      })
      ..onConnectError((e) {
        debugPrint('[RealtimeChannel] Nối hỏng: $e');
        _dangNoi = false;
        _datHenNoiLai();
      })
      ..onDisconnect((r) {
        debugPrint('[RealtimeChannel] Đứt kết nối: $r');
        _dangNoi = false;
        _datHenNoiLai();
      })
      ..connect();
  }

  void _datHenNoiLai() {
    if (_daDung) return;
    _henNoiLai?.cancel();
    _soLanHong++;
    final cho = khoangChoLanThu(_soLanHong);
    debugPrint('[RealtimeChannel] Thử nối lại sau ${cho.inSeconds}s '
        '(lần hỏng thứ $_soLanHong)');
    _henNoiLai = Timer(cho, () {
      // Socket cũ đã chết; bỏ hẳn nó đi rồi mới dựng cái mới, nếu không
      // handler của nó vẫn còn treo và mỗi lần đứt lại nhân đôi số hẹn giờ.
      _socket?.dispose();
      _socket = null;
      unawaited(_noi());
    });
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
