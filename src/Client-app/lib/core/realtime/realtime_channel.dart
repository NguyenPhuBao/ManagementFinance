import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/buoc_dang_xuat.dart';
import '../constants/app_constants.dart';
import 'realtime_event.dart';
import 'realtime_socket.dart';
import 'socket_base_url.dart';
import 'tin_he_thong.dart';

/// Tên sự kiện cưỡng chế đăng xuất, đúng chuỗi backend phát ở
/// `emitForceLogout` (`core/socket.js`). Cố ý KHÔNG nằm trong `realtimeEventFromName`: nó
/// không phải tin "server vừa có dữ liệu mới" và không được đánh thức đồng bộ.
const _tenBuocDangXuat = 'account.force_logout';

/// Tin admin phát (`emitSystemBroadcast` ở `core/socket.js`) — ngoại lệ hộp đen thứ hai, payload đọc qua
/// `docTinHeThong` (spec 2026-10-26). Không nằm trong `realtimeEventFromName`: không đánh thức đồng bộ.
const _tenTinHeThong = 'system.broadcast';

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
/// và `SyncEngine` từng hơn 1.600 dòng một tệp (tách 2026-10-19).
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

  /// Sự kiện cưỡng chế đăng xuất — **luồng riêng**, cố ý không trộn vào [events].
  ///
  /// [events] mang cam kết "client không đọc trường nào của payload", vì một
  /// tên sự kiện đi qua EventBus không bảo đảm một hình dạng payload.
  /// `account.force_logout` thì chỉ phát từ MỘT hàm (`emitForceLogout` ở `core/socket.js`),
  /// nên đọc payload ở đây an toàn — và để cam kết kia không bị nới theo, nó đi
  /// cửa riêng (spec cưỡng chế đăng xuất §3.2).
  /// Từ G89 (2026-10-20) luồng này còn mang lời từ chối BẮT TAY vì tài khoản (`connect_error` có `code`).
  final _buocDangXuatController =
      StreamController<ThongBaoBuocDangXuat>.broadcast();

  Stream<ThongBaoBuocDangXuat> get buocDangXuat =>
      _buocDangXuatController.stream;

  /// Tin admin gõ tay — **luồng riêng** như [buocDangXuat], cùng lý do: [events] không đọc payload.
  final _tinHeThongController = StreamController<TinHeThongNhan>.broadcast();

  Stream<TinHeThongNhan> get tinHeThong => _tinHeThongController.stream;

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
        final tuChoi = tuLoiBatTaySocket(e);
        if (tuChoi != null && _khiBiTuChoiBatTay(tuChoi)) return;
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

  /// Server từ chối bắt tay vì TÀI KHOẢN (bị khoá / đã xoá — spec G89 mục 5): thử lại là gõ cửa bằng đúng danh tính vừa bị
  /// từ chối, mỗi 60 giây, mãi. Dừng hẳn tới lần `start()` sau và đưa lời ấy lên [buocDangXuat] — cùng đường
  /// `account.force_logout`. Trả `false` khi bỏ qua (lời nói về tài khoản khác — khuôn `force_logout`) để nơi gọi giãn cách
  /// như một lần nối hỏng thường.
  bool _khiBiTuChoiBatTay(ThongBaoBuocDangXuat t) {
    if (_daDung) return true;
    if (t.idaccount != null && t.idaccount != _idaccount) {
      debugPrint('[RealtimeChannel] Bỏ qua lời từ chối bắt tay của tài khoản khác: ${t.idaccount}');
      return false;
    }
    debugPrint('[RealtimeChannel] Bắt tay bị từ chối: ${t.lyDo.name} — dừng nối lại');
    // `stop()` đặt `_daDung` và huỷ hẹn giờ TRƯỚC `await` đầu tiên — bộ nghe mạng lẫn hẹn nối lại đều gác bằng cờ ấy. Socket
    // bị dispose sau `await`, tức ngoài callback của chính nó.
    unawaited(stop());
    if (!_buocDangXuatController.isClosed) _buocDangXuatController.add(t);
    return true;
  }

  void _khiCoSuKien(String ten, dynamic payload) {
    if (_daDung) return;

    // Bắt TRƯỚC `realtimeEventFromName`: sự kiện này không nằm trong
    // `RealtimeEvent`, không đánh thức đồng bộ, và là một trong HAI chỗ trong
    // lớp này được đọc payload (§3.2) — cùng `system.broadcast` ngay dưới.
    if (ten == _tenBuocDangXuat) {
      final thongBao = tuSuKienSocket(payload);
      // Gói tin của tài khoản khác: không xảy ra khi room đúng, nhưng nếu xảy
      // ra thì nó đá nhầm người đang đăng nhập ra (đăng xuất kèm hộp thoại).
      // Thiếu id thì vẫn nhận — socket này đã xác thực bằng JWT của chính phiên
      // đang chạy, nên room do server chọn mới là chốt thật.
      if (thongBao.idaccount != null && thongBao.idaccount != _idaccount) {
        debugPrint('[RealtimeChannel] Bỏ qua force_logout của tài khoản khác: '
            '${thongBao.idaccount}');
        return;
      }
      debugPrint('[RealtimeChannel] Bị buộc đăng xuất: ${thongBao.lyDo.name}');
      if (!_buocDangXuatController.isClosed) {
        _buocDangXuatController.add(thongBao);
      }
      return;
    }

    // Tin admin gõ tay (spec 2026-10-26 mục 3.1): payload đọc qua MỘT hàm thuần; tin bảo trì tự động / payload hỏng → im.
    // Kèm tài khoản của phiên đang nối — bộ nhận ghi hàng theo nó (danh tính chỉ từ phiên). Chỉ log `id` (quét 38).
    if (ten == _tenTinHeThong) {
      final id = _idaccount;
      final tin = docTinHeThong(payload);
      if (id == null || tin == null) return;
      debugPrint('[RealtimeChannel] Tin hệ thống ${tin.id}');
      if (!_tinHeThongController.isClosed) _tinHeThongController.add((idaccount: id, tin: tin));
      return;
    }

    // Từ đây trở xuống payload KHÔNG được đọc — chỉ dùng *tên* sự kiện. Xem
    // chú thích đầu `realtime_event.dart`.
    if (_controller.isClosed) return;
    final suKien = realtimeEventFromName(ten);
    if (suKien == null) {
      debugPrint('[RealtimeChannel] Bỏ qua sự kiện lạ: $ten');
      return;
    }
    _controller.add(suKien);
  }
}
