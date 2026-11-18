import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/realtime/realtime_event.dart';
import '../../data/repositories/ban_sao_du_lieu_repository.dart';
import '../../domain/loi_ban_sao.dart';
import '../../domain/trang_thai_ban_sao.dart';
import 'du_lieu_cua_toi_state.dart';

export 'du_lieu_cua_toi_state.dart';

/// Trang "Dữ liệu của tôi" (spec 2026-11-16 mục 2). Trả [ThongDiep] cho trang hiện bằng `baoNhanh`.
class DuLieuCuaToiCubit extends Cubit<DuLieuCuaToiState> {
  DuLieuCuaToiCubit({required this.repo, Stream<RealtimeEvent>? suKien}) : super(const DuLieuCuaToiState()) {
    _sub = suKien?.listen((e) {
      if (e == RealtimeEvent.banSaoDuLieuSanSang) unawaited(nap());
    });
  }

  final BanSaoDuLieuRepository repo;
  StreamSubscription<RealtimeEvent>? _sub;

  /// Đọc trạng thái. Đã có dữ liệu thì đọc NGẦM (không bật vòng xoay).
  Future<void> nap() async {
    if (!state.daNap) emit(state.copyWith(dangNap: true));
    try {
      final y = await repo.layMoiNhat();
      if (isClosed) return;
      emit(state.copyWith(daNap: true, dangNap: false, khongDocDuoc: false, yeuCau: () => y));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(dangNap: false, khongDocDuoc: true));
    }
  }

  Future<ThongDiep?> yeuCau() async {
    if (state.dangGui || state.yeuCau?.trangThai == TrangThaiBanSao.dangTao) return null;
    emit(state.copyWith(dangGui: true));
    try {
      final y = await repo.yeuCau();
      if (isClosed) return null;
      emit(state.copyWith(dangGui: false, khongDocDuoc: false, daNap: true, yeuCau: () => y));
      return ThongDiep('Đã gửi tới email ${y.email ?? 'của bạn'}, tệp sẵn sàng sau ít phút');
    } catch (e) {
      if (isClosed) return null;
      emit(state.copyWith(dangGui: false));
      // Repository luôn ném LoiBanSao cho lỗi API (`loiBanSaoTu` ở datasource); thứ khác → khac.
      final loi = e is LoiBanSao ? e : const LoiBanSao(LoaiLoiBanSao.khac);
      switch (loi.loai) {
        case LoaiLoiBanSao.daGioiHan:
          unawaited(nap());
          final cho = loi.choThem;
          return ThongDiep(
              cho == null ? 'Bạn đã yêu cầu trong 24 giờ qua' : 'Bạn có thể yêu cầu lại sau ${chuChoYeuCauLai(cho)}',
              loi: true);
        case LoaiLoiBanSao.matMang:
          return const ThongDiep('Cần kết nối mạng để gửi yêu cầu', loi: true);
        default:
          return const ThongDiep('Không gửi được yêu cầu, hãy thử lại sau', loi: true);
      }
    }
  }

  Future<ThongDiep?> tai(String dinhDang) async {
    final y = state.yeuCau;
    if (state.dangTai != null || y == null || y.trangThai != TrangThaiBanSao.sanSang) return null;
    emit(state.copyWith(dangTai: () => dinhDang));
    try {
      final noi = await repo.taiVaLuu(y.id, dinhDang);
      if (isClosed) return null;
      emit(state.copyWith(dangTai: () => null));
      return noi == null ? null : ThongDiep('Đã lưu $noi');
    } catch (e) {
      if (isClosed) return null;
      emit(state.copyWith(dangTai: () => null));
      if (e is! LoiBanSao) return const ThongDiep('Không lưu được tệp', loi: true);
      switch (e.loai) {
        case LoaiLoiBanSao.hetHan:
          unawaited(nap());
          return const ThongDiep('Tệp đã hết hạn, hãy yêu cầu lại', loi: true);
        case LoaiLoiBanSao.chuaXong:
        case LoaiLoiBanSao.khongCo:
          unawaited(nap());
          return const ThongDiep('Tệp chưa sẵn sàng', loi: true);
        case LoaiLoiBanSao.matMang:
          return const ThongDiep('Cần kết nối mạng để tải tệp', loi: true);
        default:
          return const ThongDiep('Không tải được tệp, hãy thử lại sau', loi: true);
      }
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
