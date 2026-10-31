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

  /// Thế hệ lượt xem trước: tăng mỗi lần `xem()` bắt đầu và mỗi lần đổi mã. Lượt cũ về muộn (kể cả cùng mã, A → B → A) bị bỏ,
  /// không thì nó emit state cũ và xoá cờ `dangThamGia` của lượt đang chạy.
  int _theHeXem = 0;

  Stream<String> get canBao => _bao.stream;

  void doiMa(String s) {
    if (state.dangThamGia) return;
    final ma = chuanHoaMaMoi(s);
    if (ma == state.ma) return;
    _theHeXem++;
    emit(ThamGiaNhaState(ma: ma));
  }

  Future<void> xem() async {
    final ma = state.ma;
    if (!maMoiHopLe(ma) || state.dangXem || state.dangThamGia) return;
    final the = ++_theHeXem;
    emit(ThamGiaNhaState(ma: ma, xemTruoc: state.xemTruoc, dangXem: true));
    try {
      final x = await _repo.xemTruoc(ma);
      if (!isClosed && _theHeXem == the) emit(ThamGiaNhaState(ma: ma, xemTruoc: x));
    } catch (e) {
      if (isClosed || _theHeXem != the) return;
      final loai = loaiLoiNhaCua(e);
      if (!_bao.isClosed) _bao.add(cauLoiNha(loai));
      emit(ThamGiaNhaState(ma: ma, xemTruoc: loiThuLaiDuoc(loai) ? state.xemTruoc : null));
    }
  }

  Future<bool> thamGia() async {
    final s = state;
    if (s.xemTruoc == null || s.dangThamGia || s.dangXem) return false;
    emit(ThamGiaNhaState(ma: s.ma, xemTruoc: s.xemTruoc, dangThamGia: true));
    try {
      await _repo.thamGia(s.ma);
      return true;
    } catch (e) {
      if (!isClosed) {
        final loai = loaiLoiNhaCua(e);
        if (!_bao.isClosed) _bao.add(cauLoiNha(loai));
        emit(ThamGiaNhaState(ma: s.ma, xemTruoc: loiThuLaiDuoc(loai) ? s.xemTruoc : null));
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
