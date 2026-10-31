import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/loi_moi.dart';
import '../../data/repositories/nha_repository.dart';
import '../../domain/cau_loi_nha.dart';
import '../../domain/vai_nha.dart';

class MoiThanhVienState {
  const MoiThanhVienState({
    this.ds = const [],
    this.daNap = false,
    this.maVuaTao,
    this.emailVuaGui,
    this.dangTaoMa = false,
    this.dangGuiEmail = false,
  });

  final List<MaMoiEntity> ds;
  final bool daNap;
  final MaMoiEntity? maVuaTao;
  final String? emailVuaGui;
  final bool dangTaoMa;
  final bool dangGuiEmail;
}

/// Màn Mời (`01` mục 2.1). Trần và vai do trang đọc từ `NhaCubit`; cubit này chỉ giữ danh sách lời mời và hai thao tác tạo.
class MoiThanhVienCubit extends Cubit<MoiThanhVienState> {
  MoiThanhVienCubit(this._repo, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now,
        super(const MoiThanhVienState());

  final NhaRepository _repo;
  final DateTime Function() _now;
  final _bao = StreamController<String>.broadcast();

  Stream<String> get canBao => _bao.stream;

  /// Lời mời còn hiệu lực cũng chiếm chỗ — đầu vào của `conChoMoi`.
  int get soConHieuLuc => state.ds.where((m) => m.conHieuLucLuc(_now())).length;

  void _phat({
    List<MaMoiEntity>? ds,
    bool? daNap,
    MaMoiEntity? maVuaTao,
    bool boMa = false,
    String? emailVuaGui,
    bool? dangTaoMa,
    bool? dangGuiEmail,
  }) {
    if (isClosed) return;
    final s = state;
    emit(MoiThanhVienState(
      ds: ds ?? s.ds,
      daNap: daNap ?? s.daNap,
      maVuaTao: boMa ? null : (maVuaTao ?? s.maVuaTao),
      emailVuaGui: emailVuaGui ?? s.emailVuaGui,
      dangTaoMa: dangTaoMa ?? s.dangTaoMa,
      dangGuiEmail: dangGuiEmail ?? s.dangGuiEmail,
    ));
  }

  void _baoLoi(Object e) {
    if (!_bao.isClosed) _bao.add(cauLoiNha(loaiLoiNhaCua(e)));
  }

  Future<void> nap() async {
    try {
      final ds = await _repo.dsMaMoi();
      _phat(ds: ds, daNap: true);
    } catch (e) {
      _baoLoi(e);
      _phat(daNap: true);
    }
  }

  Future<void> taoMa(VaiNha vai) async {
    if (state.dangTaoMa) return;
    _phat(dangTaoMa: true);
    try {
      final m = await _repo.taoMaMoi(vai);
      _phat(maVuaTao: m, dangTaoMa: false);
      await nap();
    } catch (e) {
      _baoLoi(e);
      _phat(dangTaoMa: false);
    }
  }

  Future<void> guiEmail(String email, VaiNha vai) async {
    if (state.dangGuiEmail) return;
    final sach = email.trim().toLowerCase();
    _phat(dangGuiEmail: true);
    try {
      await _repo.moiQuaEmail(sach, vai);
      _phat(emailVuaGui: sach, dangGuiEmail: false);
      await nap();
    } catch (e) {
      _baoLoi(e);
      _phat(dangGuiEmail: false);
    }
  }

  Future<void> huy(String ma) async {
    try {
      await _repo.huyMaMoi(ma);
      _phat(boMa: state.maVuaTao?.ma == ma);
      await nap();
    } catch (e) {
      _baoLoi(e);
    }
  }

  @override
  Future<void> close() async {
    await _bao.close();
    return super.close();
  }
}
