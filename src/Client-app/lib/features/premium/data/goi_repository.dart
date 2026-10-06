import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;

import '../../../core/realtime/realtime_event.dart';
import '../domain/trang_thai_goi.dart';
import 'goi_store.dart';
import 'payment_api.dart';

/// Phiên đăng nhập nhìn từ mảng gói: mã tài khoản + `type` của `/auth/*`.
/// Dịch từ `AuthState` ở `presentation/phien_goi_tu_auth.dart` — repository
/// không biết `AuthBloc`.
typedef PhienGoi = ({int idaccount, String? loaiPhien});

/// Nguồn sự thật phía client về gói của tài khoản đang đăng nhập (spec Premium
/// 2026-10-06 mục 6.3).
///
/// - [lamMoi] **không bao giờ ném**: hỏng (mạng, 401, 5xx, `P2022` thời dev
///   chưa áp migration 19) thì giữ trạng thái đang có.
/// - Kho thắng `type` của phiên khi cả hai có (giới hạn 15.2 của spec).
/// - Hai [lamMoi] chồng nhau dùng chung một `Future`.
/// - Ba nguồn làm mới nối ở `main.dart` (6.4): phiên · `resumed` giãn 5 phút ·
///   socket `account.upgraded` ngay (tín hiệu, không đọc payload).
class GoiRepository {
  GoiRepository({
    required PaymentApi api,
    required GoiStore kho,
    DateTime Function()? clock,
  })  : _api = api,
        _kho = kho,
        _now = clock ?? DateTime.now {
    _hienTai = TrangThaiGoi.basicMacDinh(_now());
  }

  final PaymentApi _api;
  final GoiStore _kho;
  final DateTime Function() _now;
  final _controller = StreamController<TrangThaiGoi>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];

  late TrangThaiGoi _hienTai;
  int? _idaccount;
  Future<void>? _dangLamMoi;

  TrangThaiGoi get hienTai => _hienTai;
  Stream<TrangThaiGoi> get theoDoi => _controller.stream;
  int? get idaccount => _idaccount;

  void _phat(TrangThaiGoi t) {
    _hienTai = t;
    if (!_controller.isClosed) _controller.add(t);
  }

  /// Mở phiên: nạp kho; kho trống → `type` của phiên. Không gọi mạng ở đây.
  Future<void> datTaiKhoan(int idaccount, {String? loaiPhien}) async {
    _idaccount = idaccount;
    final kho = await _kho.doc(idaccount);
    if (_idaccount != idaccount) return; // phiên đã đổi trong lúc chờ
    _phat(kho ?? trangThaiTuLoaiPhien(loaiPhien, nhanLuc: _now()));
  }

  /// Đăng xuất: RAM về Basic, kho GIỮ (tài khoản khác dùng khoá khác).
  void xoaPhien() {
    _idaccount = null;
    _phat(TrangThaiGoi.basicMacDinh(_now()));
  }

  Future<void> lamMoi() {
    final dang = _dangLamMoi;
    if (dang != null) return dang;
    final f = _lamMoiThat().whenComplete(() => _dangLamMoi = null);
    _dangLamMoi = f;
    return f;
  }

  Future<void> _lamMoiThat() async {
    final id = _idaccount;
    if (id == null) return;
    try {
      final json = await _api.thongTinGoi();
      if (_idaccount != id) return;
      final moi = trangThaiTuJson(json, nhanLuc: _now());
      await _kho.ghi(id, moi);
      _phat(moi);
    } catch (e) {
      debugPrint('[Premium] lamMoi hỏng, giữ trạng thái cũ: ${e.runtimeType}');
    }
  }

  /// Làm mới nếu lượt trước đã cách quá [gian] (spec 6.4 — `resumed`).
  Future<void> lamMoiNeuCu(Duration gian) {
    if (_idaccount == null) return Future.value();
    if (_now().difference(_hienTai.nhanLuc) < gian) return Future.value();
    return lamMoi();
  }

  /// `AuthSuccess` → `datTaiKhoan` + `lamMoi`; `null` → `xoaPhien`. Cùng tài
  /// khoản phát lại (AuthSuccess re-emit) thì bỏ qua — không phải lý do hỏi lại.
  void noiPhien(Stream<PhienGoi?> phien) {
    _subs.add(phien.listen((p) async {
      if (p == null) {
        if (_idaccount != null) xoaPhien();
        return;
      }
      if (p.idaccount == _idaccount) return;
      await datTaiKhoan(p.idaccount, loaiPhien: p.loaiPhien);
      await lamMoi();
    }));
  }

  void noiVongDoi(
    Stream<AppLifecycleState> vongDoi, {
    Duration gian = const Duration(minutes: 5),
  }) {
    _subs.add(vongDoi.listen((s) {
      if (s == AppLifecycleState.resumed) unawaited(lamMoiNeuCu(gian));
    }));
  }

  /// `account.upgraded` là TÍN HIỆU — không đọc payload, hỏi lại API ngay.
  void noiSuKien(Stream<RealtimeEvent> suKien) {
    _subs.add(suKien.listen((e) {
      if (e == RealtimeEvent.taiKhoanNangCap) unawaited(lamMoi());
    }));
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _controller.close();
  }
}
