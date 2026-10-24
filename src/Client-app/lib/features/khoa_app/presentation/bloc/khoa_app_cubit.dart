import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/khoa_app_service.dart';
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
  })  : _service = service,
        _clock = clock ?? DateTime.now,
        super(const KhoaAppDangXet()) {
    _subVongDoi = vongDoi.listen(_khiVongDoi);
    _subPhien = phien.listen((id) => unawaited(nhanPhien(id)));
  }

  final KhoaAppService _service;
  final DateTime Function() _clock;
  late final StreamSubscription<AppLifecycleState> _subVongDoi;
  late final StreamSubscription<int?> _subPhien;

  int? _id;
  bool _daBietPhien = false;
  CauHinhKhoaApp? _cauHinh;
  DateTime? _roiLuc;
  int _lanKhoa = 0;

  Future<void> nhanPhien(int? id) async {
    // `verifySession` phát lại AuthSuccess cùng tài khoản — không phải mở lạnh, không khoá lại.
    if (_daBietPhien && id == _id) return;
    _daBietPhien = true;
    _id = id;
    _roiLuc = null;
    _cauHinh = null;
    if (id == null) {
      emit(const KhoaAppTat());
      return;
    }
    emit(const KhoaAppDangXet());
    final c = await _service.doc(id);
    if (isClosed || _id != id) return;
    _cauHinh = c;
    if (c == null) {
      emit(const KhoaAppMo(daBat: false));
      return;
    }
    _khoa(c);
  }

  /// Trang Khoá ứng dụng gọi sau mỗi thay đổi — đọc lại cấu hình, KHÔNG khoá.
  Future<void> napLai() async {
    final id = _id;
    if (id == null) return;
    final c = await _service.doc(id);
    if (isClosed || _id != id) return;
    _cauHinh = c;
    if (state is KhoaAppMo) emit(KhoaAppMo(daBat: c != null));
  }

  void _khoa(CauHinhKhoaApp c) {
    _lanKhoa++;
    emit(KhoaAppKhoa(coVanTay: c.vanTay != null, soLanSai: c.soLanSai, choDen: c.choDen, lanKhoa: _lanKhoa));
  }

  void _khiVongDoi(AppLifecycleState s) {
    final c = _cauHinh;
    if (s == AppLifecycleState.hidden || s == AppLifecycleState.paused) {
      // Mốc rời app = lần `hidden` / `paused` ĐẦU TIÊN; `inactive` (hộp vân tay, hộp quyền) không tính.
      if (c != null && state is KhoaAppMo) _roiLuc ??= _clock();
      return;
    }
    if (s == AppLifecycleState.resumed) {
      final roi = _roiLuc;
      _roiLuc = null;
      if (roi == null || c == null || state is! KhoaAppMo) return;
      if (canKhoaKhiQuayLai(roiLuc: roi, nay: _clock(), muc: c.tuKhoaSau)) {
        // Khoá NGAY bằng bản RAM (không để lọt khung nội dung), rồi làm tươi từ kho (P9).
        _khoa(c);
        final id = _id;
        if (id != null) unawaited(_lamTuoiKhoa(id, _lanKhoa));
      }
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
    _cauHinh = await _service.doc(id);
    if (!isClosed && _id == id) emit(const KhoaAppMo(daBat: true));
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
      LoiSinhTrac.tamKhoa => kCauVanTayTamKhoa,
      LoiSinhTrac.khongHoTro || LoiSinhTrac.loi => kCauVanTayHong,
    };
    if (cau == null) return;
    emit(KhoaAppKhoa(
      coVanTay: loi != LoiSinhTrac.voHieu,
      soLanSai: hien.soLanSai,
      choDen: hien.choDen,
      lanKhoa: hien.lanKhoa,
      lanKiem: hien.lanKiem,
      loiNhan: cau,
    ));
  }

  @override
  Future<void> close() async {
    await _subVongDoi.cancel();
    await _subPhien.cancel();
    return super.close();
  }
}
