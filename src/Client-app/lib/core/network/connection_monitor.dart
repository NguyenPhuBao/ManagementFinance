import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Hai sự kiện kết nối đáng nói với người dùng.
enum ConnectionEvent {
  /// Mất mạng, và đã mất đủ lâu để không phải là một cú nhấp nháy của sóng.
  mat,

  /// Có mạng trở lại **sau khi đã thật sự mất**.
  khoiPhuc,
}

/// Biến luồng thay đổi kết nối thô của hệ điều hành thành hai sự kiện trên.
///
/// ## Vì sao cần ngưỡng ổn định
///
/// `Connectivity.onConnectivityChanged` bắn rất nhiều: đi thang máy, qua hầm,
/// chuyển giữa Wi-Fi và 4G — mỗi cú đều là một sự kiện. Báo thẳng ra giao diện
/// thì banner nhấp nháy liên tục, và người dùng học được cách phớt lờ nó, kể cả
/// lúc mất mạng thật. Nên chỉ báo khi trạng thái **giữ nguyên** đủ lâu: mất
/// mạng nửa giây rồi có lại thì coi như chưa từng mất — với người dùng, đúng là
/// chưa từng.
///
/// ## Vì sao không nhét vào `SyncEngine`
///
/// `SyncEngine` cũng nghe `onConnectivityChanged`, nhưng để **quyết định lúc
/// nào đồng bộ** — một câu hỏi khác hẳn. Ở đó, phản ứng ngay với cú nhấp nháy
/// đầu tiên là đúng: đồng bộ sớm hơn thì tốt hơn. Ở đây, phản ứng ngay là sai.
/// Trộn hai mục đích vào một chỗ sẽ khiến một trong hai phải chịu thiệt.
class ConnectionMonitor {
  ConnectionMonitor({
    Connectivity? connectivity,
    this.onDinhSau = const Duration(seconds: 3),
  }) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Trạng thái phải giữ nguyên bao lâu thì mới được coi là thật.
  final Duration onDinhSau;

  final _controller = StreamController<ConnectionEvent>.broadcast();
  Stream<ConnectionEvent> get events => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _dongHoOnDinh;

  /// Trạng thái **đã được xác nhận** là ổn định, không phải trạng thái tức thời.
  bool _dangOnline = true;

  bool _daDispose = false;

  /// Bắt đầu theo dõi. Đọc trạng thái hiện tại trước để không báo "khôi phục"
  /// cho một sự cố chưa từng xảy ra.
  Future<void> start() async {
    if (_daDispose) return;

    try {
      _dangOnline = _coMang(await _connectivity.checkConnectivity());
    } catch (_) {
      // Không đọc được thì cứ coi là đang có mạng: báo nhầm "mất kết nối" lúc
      // mở app là ấn tượng đầu tiên rất tệ, còn im lặng thì không mất gì.
      _dangOnline = true;
    }

    await _sub?.cancel();
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      _xuLy(_coMang(results));
    });
  }

  void _xuLy(bool online) {
    if (_daDispose) return;

    // Trạng thái tức thời trùng với trạng thái đã xác nhận → không có gì đổi.
    // Huỷ luôn bộ đếm đang chờ: đây chính là cú "nhấp nháy rồi về như cũ".
    if (online == _dangOnline) {
      _dongHoOnDinh?.cancel();
      _dongHoOnDinh = null;
      return;
    }

    // Đổi trạng thái: chờ xem nó có giữ được không.
    _dongHoOnDinh?.cancel();
    _dongHoOnDinh = Timer(onDinhSau, () {
      if (_daDispose) return;
      _dangOnline = online;
      if (_controller.isClosed) return;
      _controller.add(online ? ConnectionEvent.khoiPhuc : ConnectionEvent.mat);
    });
  }

  static bool _coMang(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  void dispose() {
    _daDispose = true;
    _dongHoOnDinh?.cancel();
    _dongHoOnDinh = null;
    unawaited(_sub?.cancel());
    _sub = null;
    unawaited(_controller.close());
  }
}
