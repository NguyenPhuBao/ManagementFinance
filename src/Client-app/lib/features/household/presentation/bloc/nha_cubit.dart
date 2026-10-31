import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/loi_moi.dart';
import '../../data/models/nha_cua_toi.dart';
import '../../data/repositories/nha_repository.dart';
import '../../domain/cau_loi_nha.dart';
import '../../domain/vai_nha.dart';

class NhaState {
  const NhaState({required this.nha, required this.loiMoi, this.daNap = false, this.dangXuLy = false});

  final NhaCuaToi nha;
  final List<LoiMoiToiEntity> loiMoi;

  /// Kho đã nạp xong: trước đó trang chưa biết có nhà hay không, hiện "chưa có nhà" là nói sai (khuôn G92).
  final bool daNap;

  /// Một thao tác đang chạy: các nút ghi khoá.
  final bool dangXuLy;

  NhaState copyWith({NhaCuaToi? nha, List<LoiMoiToiEntity>? loiMoi, bool? daNap, bool? dangXuLy}) => NhaState(
        nha: nha ?? this.nha,
        loiMoi: loiMoi ?? this.loiMoi,
        daNap: daNap ?? this.daNap,
        dangXuLy: dangXuLy ?? this.dangXuLy,
      );
}

/// Trạng thái nhà + lời mời cho các trang của mảng (spec 12.6). Mỗi trang một cubit, chung một `NhaRepository`. Không import
/// UI Flutter; câu báo một lần đi qua [canBao] để trang gọi `baoNhanh`.
class NhaCubit extends Cubit<NhaState> {
  NhaCubit(this._repo) : super(NhaState(nha: _repo.hienTai, loiMoi: _repo.loiMoiToi)) {
    _subNha = _repo.theoDoi.listen((t) {
      if (!isClosed) emit(state.copyWith(nha: t));
    });
    _subLoiMoi = _repo.theoDoiLoiMoi.listen((ds) {
      if (!isClosed) emit(state.copyWith(loiMoi: ds));
    });
  }

  final NhaRepository _repo;
  late final StreamSubscription<NhaCuaToi> _subNha;
  late final StreamSubscription<List<LoiMoiToiEntity>> _subLoiMoi;
  final _bao = StreamController<String>.broadcast();

  Stream<String> get canBao => _bao.stream;

  /// Để dòng thành viên gắn nhãn *Bạn*. Từ phiên, không suy từ dữ liệu nhà.
  int? get idToi => _repo.idaccount;

  Future<void> moTrang() async {
    await _repo.choNapKho();
    if (isClosed) return;
    emit(state.copyWith(nha: _repo.hienTai, loiMoi: _repo.loiMoiToi, daNap: true));
    unawaited(_repo.lamMoi());
  }

  Future<bool> _lam(Future<void> Function() viec, {String? cauKhiTatQuyen}) async {
    if (state.dangXuLy) return false;
    emit(state.copyWith(dangXuLy: true));
    try {
      await viec();
      return true;
    } catch (e) {
      final loai = loaiLoiNhaCua(e);
      _bao.add(loai == LoaiLoiNha.tinhNangKhongMo && cauKhiTatQuyen != null ? cauKhiTatQuyen : cauLoiNha(loai));
      return false;
    } finally {
      if (!isClosed) emit(state.copyWith(dangXuLy: false));
    }
  }

  Future<bool> taoNha(String ten, {String? cauKhiTatQuyen}) =>
      _lam(() => _repo.taoNha(ten), cauKhiTatQuyen: cauKhiTatQuyen);
  Future<bool> roiNha() => _lam(_repo.roiNha);
  Future<bool> giaiTan() => _lam(_repo.giaiTan);
  Future<bool> doiVai(int id, VaiNha vai) => _lam(() => _repo.doiVai(id, vai));
  Future<bool> chuyenChu(int id) => _lam(() => _repo.chuyenChu(id));
  Future<bool> moiRa(int id) => _lam(() => _repo.moiRa(id));
  Future<bool> chapNhan(String ma) => _lam(() => _repo.chapNhanLoiMoi(ma));
  Future<bool> tuChoi(String ma) => _lam(() => _repo.tuChoiLoiMoi(ma));

  @override
  Future<void> close() async {
    await _subNha.cancel();
    await _subLoiMoi.cancel();
    await _bao.close();
    return super.close();
  }
}
