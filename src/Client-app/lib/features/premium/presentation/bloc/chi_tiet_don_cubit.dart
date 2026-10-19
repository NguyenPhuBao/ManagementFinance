import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/dong_lich_su.dart';
import '../../data/repositories/don_thanh_toan_repository.dart';
import '../../data/repositories/goi_repository.dart';
import '../../domain/cau_loi_thanh_toan.dart';
import '../../domain/trang_thai_don.dart';

sealed class ChiTietDonState {
  const ChiTietDonState();
}

class ChiTietDonDangNap extends ChiTietDonState {
  const ChiTietDonDangNap();
}

class ChiTietDonLoi extends ChiTietDonState {
  const ChiTietDonLoi(this.cau);

  final String cau;
}

class ChiTietDonKhongThay extends ChiTietDonState {
  const ChiTietDonKhongThay();
}

class ChiTietDonCo extends ChiTietDonState {
  const ChiTietDonCo(this.don, {this.dangGui = false, this.vuaKichHoat = false});

  final DongLichSu don;

  /// Đang gửi `confirm-upgrade` — hai nút khoá.
  final bool dangGui;

  /// Vừa *Đồng ý* thành công trong màn này và server đã ghi PAID → thân "Đã kích hoạt Premium" + *Xong*.
  final bool vuaKichHoat;
}

/// Màn Chi tiết đơn (spec G94 2026-10-18 mục 5.5) — nạp đơn theo mã, xác nhận chuyển thừa. Không import UI Flutter; câu
/// báo một lần đi qua [canBao] để trang gọi `baoNhanh`.
class ChiTietDonCubit extends Cubit<ChiTietDonState> {
  ChiTietDonCubit({
    required this.orderCode,
    required DonThanhToanRepository repo,
    required GoiRepository goi,
  })  : _repo = repo,
        _goi = goi,
        super(const ChiTietDonDangNap());

  final int orderCode;
  final DonThanhToanRepository _repo;
  final GoiRepository _goi;
  final _bao = StreamController<String>.broadcast();
  bool _dangNap = false;

  Stream<String> get canBao => _bao.stream;

  Future<void> nap() async {
    if (_dangNap) return;
    _dangNap = true;
    try {
      final d = await _repo.timDon(orderCode);
      if (isClosed) return;
      final vua = switch (state) {
        ChiTietDonCo(:final vuaKichHoat) => vuaKichHoat,
        _ => false,
      };
      emit(d == null
          ? const ChiTietDonKhongThay()
          : ChiTietDonCo(d, vuaKichHoat: vua && d.trangThai == TrangThaiDon.paid));
    } catch (e) {
      if (isClosed) return;
      final cau = cauLoiThanhToan(loaiLoiCua(e), cauTuChoi: 'Không tải được đơn này. Thử lại sau.');
      if (state is ChiTietDonCo) {
        _bao.add(cau);
      } else {
        emit(ChiTietDonLoi(cau));
      }
    } finally {
      _dangNap = false;
    }
  }

  Future<void> dongY() => _xacNhan(true);

  Future<void> tuChoi() => _xacNhan(false);

  Future<void> _xacNhan(bool accept) async {
    final s = state;
    if (s is! ChiTietDonCo || s.dangGui) return;
    emit(ChiTietDonCo(s.don, dangGui: true));
    try {
      await _repo.xacNhan(orderCode: orderCode, accept: accept);
      if (accept) await _goi.lamMoi();
      if (isClosed) return;
      emit(ChiTietDonCo(s.don, vuaKichHoat: accept));
      await nap();
    } catch (e) {
      if (isClosed) return;
      final loai = loaiLoiCua(e);
      _bao.add(cauLoiThanhToan(loai, cauTuChoi: 'Không xác nhận được đơn này. Thử lại sau.'));
      emit(ChiTietDonCo(s.don));
      // 4xx: đơn đã đổi trạng thái (xác nhận ở máy khác, đã sang chờ hoàn tiền) → màn đi theo server.
      if (loai == LoaiLoiThanhToan.biTuChoi) await nap();
    }
  }

  @override
  Future<void> close() async {
    await _bao.close();
    return super.close();
  }
}
