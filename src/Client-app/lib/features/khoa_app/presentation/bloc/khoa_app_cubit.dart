import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, VoidCallback;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/khoa_app_service.dart';
import '../../data/datasources/dong_ho_khoi_dong.dart';
import '../../data/datasources/kenh_sinh_trac.dart';
import '../../data/models/cau_hinh_khoa_app.dart';
import '../../domain/luat_khoa_app.dart';
import 'khoa_app_state.dart';

/// Trạng thái khoá của cả app (spec mục 4, 6). Dựng ở `main.dart` — nghe ĐÚNG `AuthBloc` của app (DI đăng ký nó là
/// factory). [phien] chỉ mang trạng thái phiên RÕ: id khi `AuthSuccess`, `null` khi `AuthUnauthenticated`.
class KhoaAppCubit extends Cubit<TrangThaiKhoaApp> {
  KhoaAppCubit({
    required KhoaAppService service,
    required Stream<AppLifecycleState> vongDoi,
    required Stream<int?> phien,
    DateTime Function()? clock,
    DongHoKhoiDong? dongHoKhoiDong,
    ValueListenable<bool>? dungYenOCongKhai,
    Duration vanAnToanRoi = const Duration(seconds: 3),
    VoidCallback? khiKhoaVuaTat,
  })  : _service = service,
        _khiKhoaVuaTat = khiKhoaVuaTat,
        _dungYenOCongKhai = dungYenOCongKhai,
        _vanAnToanRoi = vanAnToanRoi,
        _clock = clock ?? DateTime.now,
        _khoiDong = dongHoKhoiDong ?? docThoiGianKhoiDong,
        super(const KhoaAppDangXet()) {
    _subVongDoi = vongDoi.listen(_khiVongDoi);
    _subPhien = phien.listen((id) => unawaited(nhanPhien(id)));
  }

  final KhoaAppService _service;

  /// M11: tài khoản vừa đăng nhập bằng mật khẩu mà trước đó có khoá — `main.dart` nối với `baoNhanh`.
  final VoidCallback? _khiKhoaVuaTat;
  final DateTime Function() _clock;
  final DongHoKhoiDong _khoiDong;

  /// Router đã đứng yên ở route công khai (route trên cùng công khai ∧ hiệu ứng vào xong). `null` = không biết → mất phiên
  /// thì gỡ lớp phủ ngay như trước (chỉ test cũ; `main.dart` luôn truyền).
  final ValueListenable<bool>? _dungYenOCongKhai;
  final Duration _vanAnToanRoi;
  Timer? _henVanAnToan;
  late final StreamSubscription<AppLifecycleState> _subVongDoi;
  late final StreamSubscription<int?> _subPhien;

  int? _id;
  bool _daBietPhien = false;
  CauHinhKhoaApp? _cauHinh;
  DateTime? _roiLuc;
  Duration? _roiKhoiDong;
  int _lanKhoa = 0;

  Future<void> nhanPhien(int? id) async {
    // `verifySession` phát lại AuthSuccess cùng tài khoản — không phải mở lạnh, không khoá lại.
    if (_daBietPhien && id == _id) return;
    // Đang che (khoá, hoặc đang xét một phiên có tài khoản) mà mất phiên → phải giữ màn che tới khi router chuyển xong.
    final dangChe = state is KhoaAppKhoa || (state is KhoaAppDangXet && _id != null);
    _huyRoi();
    _daBietPhien = true;
    _id = id;
    _roiLuc = null;
    _roiKhoiDong = null;
    _cauHinh = null;
    if (id == null) {
      if (dangChe && _dungYenOCongKhai != null) {
        _batDauRoi();
      } else {
        emit(const KhoaAppTat());
      }
      return;
    }
    emit(const KhoaAppDangXet());
    final c = await _service.doc(id);
    if (isClosed || _id != id) return;
    _cauHinh = c;
    if (c == null) {
      emit(const KhoaAppMo(daBat: false));
      // M11: đăng nhập bằng mật khẩu vừa xoá khoá của CHÍNH tài khoản này — báo một dòng (cờ dùng một lần).
      if (_service.layVaXoaVuaTat(id)) _khiKhoaVuaTat?.call();
      return;
    }
    _khoa(c);
  }

  /// C1: mất phiên khi đang che. Điều kiện gỡ phải thoả NGAY nếu router đã đứng yên ở route công khai (Quên PIN → Đăng xuất:
  /// router sang `/login` từ lúc `AuthLoading`); chưa thì chờ tín hiệu. Van an toàn: tín hiệu không bao giờ tới (router không
  /// lên route công khai) thì sau [_vanAnToanRoi] vẫn gỡ — màn che vĩnh viễn tệ hơn một khung lộ.
  void _batDauRoi() {
    final tinHieu = _dungYenOCongKhai!;
    if (tinHieu.value) {
      emit(const KhoaAppTat());
      return;
    }
    emit(const KhoaAppDangRoi());
    tinHieu.addListener(_khiRouterDungYen);
    _henVanAnToan = Timer(_vanAnToanRoi, _xongRoi);
  }

  void _khiRouterDungYen() {
    if (_dungYenOCongKhai?.value ?? false) _xongRoi();
  }

  void _xongRoi() {
    if (isClosed || state is! KhoaAppDangRoi) return;
    _huyRoi();
    emit(const KhoaAppTat());
  }

  void _huyRoi() {
    _henVanAnToan?.cancel();
    _henVanAnToan = null;
    _dungYenOCongKhai?.removeListener(_khiRouterDungYen);
  }

  /// Trang Khoá ứng dụng gọi sau mỗi thay đổi — đọc lại cấu hình, KHÔNG khoá.
  Future<void> napLai() async {
    final id = _id;
    if (id == null) return;
    final CauHinhKhoaApp? c;
    try {
      c = await _service.docNghiemNgat(id);
    } catch (_) {
      return; // đọc hỏng tạm thời: giữ cấu hình trong RAM — gán null là tắt tự khoá cả phiên
    }
    if (isClosed || _id != id) return;
    _cauHinh = c;
    final hien = state;
    // Giữ `che`: napLai về muộn lúc app đang xuống nền mà gỡ che là khung cuối lại mang nội dung (F1).
    if (hien is KhoaAppMo) emit(KhoaAppMo(daBat: c != null, che: hien.che));
  }

  void _khoa(CauHinhKhoaApp c) {
    _lanKhoa++;
    emit(KhoaAppKhoa(coVanTay: c.vanTay != null, soLanSai: c.soLanSai, choDen: c.choDen, lanKhoa: _lanKhoa));
  }

  void _khiVongDoi(AppLifecycleState s) {
    final c = _cauHinh;
    if (s == AppLifecycleState.inactive) {
      // F1: che NGAY khi mất tiêu điểm — `hidden` / `paused` tới khi Flutter đã tắt vẽ khung, mà khung cuối trước khi app rời
      // màn được engine vẽ lại lên surface mới TRƯỚC khi Dart nhận `resumed` (đo Realme: lộ ~1 khung số dư). Cái giá: kéo
      // thanh thông báo / hộp vân tay cũng che (người dùng chọn). Không tính là rời app — mốc rời chỉ đặt ở `hidden` / `paused`.
      final hien = state;
      if (c != null && hien is KhoaAppMo && !hien.che) emit(KhoaAppMo(daBat: hien.daBat, che: true));
      return;
    }
    if (s == AppLifecycleState.hidden || s == AppLifecycleState.paused) {
      // Mốc rời app = lần `hidden` / `paused` ĐẦU TIÊN; `inactive` (hộp vân tay, hộp quyền) không tính.
      if (c != null && state is KhoaAppMo && _roiLuc == null) {
        // Ghi CẢ hai mốc: giờ tường (chỉnh được) và đồng hồ khởi động (không chỉnh được, tính cả lúc máy ngủ).
        _roiLuc = _clock();
        _roiKhoiDong = _khoiDong();
      }
      return;
    }
    if (s == AppLifecycleState.resumed) {
      final roi = _roiLuc;
      final roiKd = _roiKhoiDong;
      _roiLuc = null;
      _roiKhoiDong = null;
      final hien = state;
      if (hien is! KhoaAppMo) return;
      if (roi != null && c != null) {
        final kd = _khoiDong();
        final oNenKd = roiKd != null && kd != null ? kd - roiKd : null;
        if (canKhoaKhiQuayLai(roiLuc: roi, nay: _clock(), muc: c.tuKhoaSau, oNenTheoKhoiDong: oNenKd)) {
          // Khoá NGAY bằng bản RAM (không để lọt khung nội dung), rồi làm tươi từ kho (P9).
          _khoa(c);
          final id = _id;
          if (id != null) unawaited(_lamTuoiKhoa(id, _lanKhoa));
          return;
        }
      }
      if (hien.che) emit(KhoaAppMo(daBat: hien.daBat));
    }
  }

  /// P9: `soLanSai` / `choDen` ở kho có thể mới hơn bản RAM (nhập sai ở trang Đổi / Tắt PIN rồi thoát).
  Future<void> _lamTuoiKhoa(int id, int lanKhoa) async {
    final c = await _service.doc(id);
    if (isClosed || _id != id || c == null) return;
    final hien = state;
    if (hien is! KhoaAppKhoa || hien.lanKhoa != lanKhoa || hien.dangKiem) return;
    _cauHinh = c;
    if (hien.soLanSai == c.soLanSai && hien.choDen == c.choDen) return;
    emit(KhoaAppKhoa(
      coVanTay: hien.coVanTay,
      soLanSai: c.soLanSai,
      choDen: c.choDen,
      loiNhan: hien.loiNhan,
      lanKhoa: hien.lanKhoa,
      lanKiem: hien.lanKiem,
    ));
  }

  Future<void> _mo(int id) async {
    CauHinhKhoaApp? moi = _cauHinh;
    try {
      moi = await _service.docNghiemNgat(id);
    } catch (_) {
      // Đọc hỏng ngay sau mở khoá: giữ cấu hình trong RAM để lần rời app kế vẫn tự khoá.
    }
    if (isClosed || _id != id) return;
    _cauHinh = moi;
    emit(KhoaAppMo(daBat: _cauHinh != null));
  }

  Future<void> nhapPin(String pin) async {
    final s = state;
    final id = _id;
    if (s is! KhoaAppKhoa || id == null || s.dangKiem) return;
    emit(KhoaAppKhoa(
      coVanTay: s.coVanTay,
      soLanSai: s.soLanSai,
      choDen: s.choDen,
      dangKiem: true,
      lanKhoa: s.lanKhoa,
      lanKiem: s.lanKiem,
    ));
    final KetQuaKiemPin kq;
    try {
      kq = await _service.kiemPin(id, pin);
    } catch (_) {
      if (!isClosed && _id == id) {
        emit(KhoaAppKhoa(
          coVanTay: s.coVanTay,
          soLanSai: s.soLanSai,
          choDen: s.choDen,
          lanKhoa: s.lanKhoa,
          lanKiem: s.lanKiem + 1,
          loiNhan: kCauKhongKiemDuoc,
        ));
      }
      return;
    }
    if (isClosed || _id != id) return;
    if (kq.dung) return _mo(id);
    emit(KhoaAppKhoa(
      coVanTay: s.coVanTay,
      soLanSai: kq.soLanSai,
      choDen: kq.choDen,
      lanKhoa: s.lanKhoa,
      lanKiem: s.lanKiem + 1,
      loiNhan: kq.dangCho ? null : kCauSaiPin,
    ));
  }

  Future<void> moBangVanTay() async {
    final s = state;
    final id = _id;
    if (s is! KhoaAppKhoa || id == null || !s.coVanTay || s.dangKiem) return;
    LoiSinhTrac? loi;
    try {
      loi = await _service.moBangVanTay(id);
    } catch (_) {
      // Kho hỏng (tatVanTay / ghi ném) — xử lý như lỗi vân tay chung, vẫn ở màn khoá.
      loi = LoiSinhTrac.loi;
    }
    if (isClosed || _id != id) return;
    final hien = state;
    if (hien is! KhoaAppKhoa) return;
    if (loi == null) return _mo(id);
    final cau = switch (loi) {
      LoiSinhTrac.huy => null,
      LoiSinhTrac.voHieu => kCauVanTayDaDoi,
      LoiSinhTrac.matKhoa => kCauVanTayDaTat,
      LoiSinhTrac.tamKhoa => kCauVanTayTamKhoa,
      LoiSinhTrac.khongHoTro || LoiSinhTrac.loi => kCauVanTayHong,
    };
    if (cau == null) return;
    emit(KhoaAppKhoa(
      coVanTay: loi != LoiSinhTrac.voHieu && loi != LoiSinhTrac.matKhoa,
      soLanSai: hien.soLanSai,
      choDen: hien.choDen,
      lanKhoa: hien.lanKhoa,
      lanKiem: hien.lanKiem,
      loiNhan: cau,
    ));
  }

  @override
  Future<void> close() async {
    _huyRoi();
    await _subVongDoi.cancel();
    await _subPhien.cancel();
    return super.close();
  }
}
