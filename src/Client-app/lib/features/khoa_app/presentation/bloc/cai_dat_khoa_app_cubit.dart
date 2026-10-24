import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/khoa_app_service.dart';
import '../../data/datasources/kenh_sinh_trac.dart';
import '../../domain/luat_khoa_app.dart';
import 'khoa_app_state.dart';

class CaiDatKhoaApp {
  const CaiDatKhoaApp({
    this.dangTai = true,
    this.daBat = false,
    this.tuKhoaSau = TuKhoaSau.macDinh,
    this.coVanTay = false,
    this.may = TrangThaiSinhTrac.khong,
    this.loiNhan,
    this.dangLam = false,
  });

  final bool dangTai;
  final bool daBat;
  final TuKhoaSau tuKhoaSau;
  final bool coVanTay;
  final TrangThaiSinhTrac may;
  final String? loiNhan;

  /// Một thao tác đang chạy — lời gọi chồng bị bỏ qua, công tắc tắt (tránh hai `SinhTrac.bat` song song).
  final bool dangLam;
}

class CaiDatKhoaAppCubit extends Cubit<CaiDatKhoaApp> {
  CaiDatKhoaAppCubit({required KhoaAppService service, required int idaccount, Future<void> Function()? khiDoi})
      : _sv = service,
        _id = idaccount,
        _khiDoi = khiDoi,
        super(const CaiDatKhoaApp());

  final KhoaAppService _sv;
  final int _id;
  final Future<void> Function()? _khiDoi;

  Future<void> napLai({String? loiNhan}) async {
    try {
      final c = await _sv.doc(_id);
      final may = await _sv.trangThaiMay();
      if (isClosed) return;
      emit(CaiDatKhoaApp(
        dangTai: false,
        daBat: c != null,
        tuKhoaSau: c?.tuKhoaSau ?? TuKhoaSau.macDinh,
        coVanTay: c?.vanTay != null,
        may: may,
        loiNhan: loiNhan,
      ));
    } catch (_) {
      if (isClosed) return;
      emit(CaiDatKhoaApp(
        dangTai: false,
        daBat: state.daBat,
        tuKhoaSau: state.tuKhoaSau,
        coVanTay: state.coVanTay,
        may: state.may,
        loiNhan: kCauKhoAppKhongLuu,
      ));
    }
  }

  bool _dangLam = false;

  /// Chạy [viec] một mình: đang có thao tác khác thì bỏ qua; state mang `dangLam` trong lúc chạy.
  Future<void> _mot(Future<void> Function() viec) async {
    if (_dangLam || state.dangLam) return;
    _dangLam = true;
    emit(CaiDatKhoaApp(
      dangTai: state.dangTai,
      daBat: state.daBat,
      tuKhoaSau: state.tuKhoaSau,
      coVanTay: state.coVanTay,
      may: state.may,
      dangLam: true,
    ));
    try {
      await viec();
    } finally {
      _dangLam = false;
    }
  }

  Future<void> _sau({String? loiNhan}) async {
    try {
      await _khiDoi?.call();
    } catch (_) {
      // Lớp khoá toàn app đọc lại hỏng — trang vẫn đọc lại kho của mình bên dưới.
    }
    await napLai(loiNhan: loiNhan);
  }

  /// Chạy một thay đổi; kho hỏng → báo câu, không để lỗi thoát ra.
  Future<void> _lam(Future<String?> Function() viec) => _mot(() async {
        String? loi;
        try {
          loi = await viec();
        } catch (_) {
          loi = kCauKhoAppKhongLuu;
        }
        await _sau(loiNhan: loi);
      });

  Future<void> batVanTay() => _lam(() async {
        final loi = await _sv.batVanTay(_id);
        return switch (loi) {
          null || LoiSinhTrac.huy => null,
          LoiSinhTrac.tamKhoa => 'Vân tay tạm bị khoá — thử lại sau',
          _ => 'Không bật được vân tay — thử lại',
        };
      });

  Future<void> tatVanTay() => _lam(() async {
        await _sv.tatVanTay(_id);
        return null;
      });

  Future<void> datTuKhoaSau(TuKhoaSau m) => _lam(() async {
        await _sv.datTuKhoaSau(_id, m);
        return null;
      });

  /// Sau khi trang đặt / đổi / tắt PIN pop(true).
  Future<void> sauDatPin() => _mot(_sau);
}
