import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/thu_tu_khoi_nguon.dart';
import '../../domain/thu_tu_khoi.dart';

class ThuTuKhoiState extends Equatable {
  const ThuTuKhoiState({this.thuTu = kThuTuCumMacDinh, this.deXuat});
  final List<CumKhoi> thuTu;
  final CumKhoi? deXuat;

  @override
  List<Object?> get props => [thuTu, deXuat];
}

/// Thứ tự khối + đề xuất của trang Phân tích. **Riêng**, không nhét vào
/// `AnalyticsCubit`: stream của cubit ấy phát lại sau mỗi chu kỳ đồng bộ
/// (bẫy 3.19 `ANALYTICS_FEATURE.md`).
///
/// ⚠️ Sau một thao tác, `deXuat` là `null` cho tới [napLai] — đề xuất chỉ
/// tính lúc trang vừa hiện ra (spec 2.2).
class ThuTuKhoiCubit extends Cubit<ThuTuKhoiState> {
  ThuTuKhoiCubit({required this.nguon, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(const ThuTuKhoiState());

  final ThuTuKhoiNguon nguon;
  final DateTime Function() _clock;
  int? _idaccount;

  Future<void> nap(int? idaccount) async {
    _idaccount = idaccount;
    if (idaccount == null) {
      if (!isClosed) emit(const ThuTuKhoiState());
      return;
    }
    final kq = await nguon.doc(idaccount, _clock());
    if (isClosed || _idaccount != idaccount) return;
    emit(ThuTuKhoiState(thuTu: kq.thuTu, deXuat: kq.deXuat));
  }

  Future<void> napLai() => nap(_idaccount);

  Future<void> duaLen(CumKhoi cum) => _ghi(kThuTuDuaLen, cum);
  Future<void> boQua(CumKhoi cum) => _ghi(kThuTuBoQua, cum);
  Future<void> veMacDinh() => _ghi(kThuTuVeMacDinh, null);

  Future<void> _ghi(String ketQua, CumKhoi? cum) async {
    final id = _idaccount;
    if (id == null) return;
    // Tắt thẻ ngay — người dùng vừa trả lời.
    if (!isClosed) emit(ThuTuKhoiState(thuTu: state.thuTu));
    await nguon.ghiPhanHoi(id, ketQua, cum, _clock());
    final kq = await nguon.doc(id, _clock());
    if (isClosed || _idaccount != id) return;
    emit(ThuTuKhoiState(thuTu: kq.thuTu));
  }

  Future<void> ghiGiay(DateTime ngay, Map<CumKhoi, int> giay) async {
    final id = _idaccount;
    if (id == null || giay.isEmpty) return;
    await nguon.congGiay(id, ngay, giay);
  }
}
