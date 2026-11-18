import '../../data/models/yeu_cau_ban_sao.dart';

/// Trạng thái trang "Dữ liệu của tôi". `daNap` tách "chưa đọc" khỏi "đọc rồi, chưa từng yêu cầu" (`yeuCau == null`).
class DuLieuCuaToiState {
  const DuLieuCuaToiState({
    this.daNap = false,
    this.dangNap = false,
    this.khongDocDuoc = false,
    this.yeuCau,
    this.dangGui = false,
    this.dangTai,
  });

  final bool daNap;
  final bool dangNap;
  final bool khongDocDuoc;
  final YeuCauBanSao? yeuCau;
  final bool dangGui;

  /// `json` / `csv` đang tải, hoặc `null`.
  final String? dangTai;

  DuLieuCuaToiState copyWith({
    bool? daNap,
    bool? dangNap,
    bool? khongDocDuoc,
    YeuCauBanSao? Function()? yeuCau,
    bool? dangGui,
    String? Function()? dangTai,
  }) =>
      DuLieuCuaToiState(
        daNap: daNap ?? this.daNap,
        dangNap: dangNap ?? this.dangNap,
        khongDocDuoc: khongDocDuoc ?? this.khongDocDuoc,
        yeuCau: yeuCau == null ? this.yeuCau : yeuCau(),
        dangGui: dangGui ?? this.dangGui,
        dangTai: dangTai == null ? this.dangTai : dangTai(),
      );
}

/// Câu trang đưa vào `baoNhanh` (cubit không import UI).
class ThongDiep {
  const ThongDiep(this.cau, {this.loi = false});
  final String cau;
  final bool loi;
}
