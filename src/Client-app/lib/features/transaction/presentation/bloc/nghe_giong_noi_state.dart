// lib/features/transaction/presentation/bloc/nghe_giong_noi_state.dart
/// Trạng thái micro của ô Nhập nhanh (C4, spec 2026-10-12 §2.1). Không `Equatable` (nếp `ThemGiaoDichState`).
library;

import '../../domain/chon_loi_nghe.dart';

enum TrangThaiNghe { cho, dangNghe, dangGhi, dangChep }

class NgheGiongNoiState {
  const NgheGiongNoiState({
    this.trangThai = TrangThaiNghe.cho,
    this.chuTam = '',
    this.giay = 0,
    this.cauXong,
    this.soLanXong = 0,
    this.thongBao,
    this.soLanThongBao = 0,
  });

  final TrangThaiNghe trangThai;

  /// Chữ đang nghe (lối Android) — trang chép vào ô Nhập nhanh.
  final String chuTam;

  /// Số giây đã ghi (lối Gemma).
  final int giay;

  /// Câu vừa xong — trang đặt vào ô rồi Điền khi [soLanXong] đổi.
  final String? cauXong;
  final int soLanXong;

  /// Thông báo cần hiện — trang hiện khi [soLanThongBao] đổi.
  final ThongBaoNghe? thongBao;
  final int soLanThongBao;

  /// Micro đang thu (nút thành ■).
  bool get dangThu => trangThai == TrangThaiNghe.dangNghe || trangThai == TrangThaiNghe.dangGhi;

  NgheGiongNoiState copyWith({
    TrangThaiNghe? trangThai,
    String? chuTam,
    int? giay,
    String? cauXong,
    int? soLanXong,
    ThongBaoNghe? thongBao,
    int? soLanThongBao,
  }) =>
      NgheGiongNoiState(
        trangThai: trangThai ?? this.trangThai,
        chuTam: chuTam ?? this.chuTam,
        giay: giay ?? this.giay,
        cauXong: cauXong ?? this.cauXong,
        soLanXong: soLanXong ?? this.soLanXong,
        thongBao: thongBao ?? this.thongBao,
        soLanThongBao: soLanThongBao ?? this.soLanThongBao,
      );
}
