import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/loi_moi.dart';
import '../../data/repositories/nha_repository.dart';
import '../../domain/cau_loi_nha.dart';
import '../../domain/ma_moi.dart';

class ThamGiaNhaState {
  const ThamGiaNhaState({this.ma = '', this.xemTruoc, this.dangXem = false, this.dangThamGia = false});

  /// Đã chuẩn hoá (`chuanHoaMaMoi`).
  final String ma;
  final XemTruocLoiMoi? xemTruoc;
  final bool dangXem;
  final bool dangThamGia;
}

/// Màn Tham gia (spec 5.3). Câu lỗi: `cauLoiNha`; `FEATURE_DISABLED` luôn câu trung tính (spec 12.4).
class ThamGiaNhaCubit extends Cubit<ThamGiaNhaState> {
  ThamGiaNhaCubit(this._repo) : super(const ThamGiaNhaState());

  final NhaRepository _repo;
  final _bao = StreamController<String>.broadcast();

  Stream<String> get canBao => _bao.stream;

  void doiMa(String s) {
    final ma = chuanHoaMaMoi(s);
    if (ma == state.ma) return;
    emit(ThamGiaNhaState(ma: ma));
  }

  Future<void> xem() async {
    final ma = state.ma;
    if (!maMoiHopLe(ma) || state.dangXem) return;
    emit(ThamGiaNhaState(ma: ma, dangXem: true));
    try {
      final x = await _repo.xemTruoc(ma);
      if (!isClosed && state.ma == ma) emit(ThamGiaNhaState(ma: ma, xemTruoc: x));
    } catch (e) {
      if (isClosed) return;
      _bao.add(cauLoiNha(loaiLoiNhaCua(e)));
      emit(ThamGiaNhaState(ma: state.ma));
    }
  }

  Future<bool> thamGia() async {
    final s = state;
    if (s.xemTruoc == null || s.dangThamGia) return false;
    emit(ThamGiaNhaState(ma: s.ma, xemTruoc: s.xemTruoc, dangThamGia: true));
    try {
      await _repo.thamGia(s.ma);
      return true;
    } catch (e) {
      if (!isClosed) {
        _bao.add(cauLoiNha(loaiLoiNhaCua(e)));
        emit(ThamGiaNhaState(ma: s.ma, xemTruoc: s.xemTruoc));
      }
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _bao.close();
    return super.close();
  }
}
