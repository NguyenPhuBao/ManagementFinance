import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/don_thanh_toan.dart';

/// Hỏi trạng thái đơn theo nhịp (spec Premium 2026-10-06 mục 9.3). Hỏi hỏng →
/// im, lượt sau thử — không giãn cách, màn sống tối đa 30 phút. Ai bật / tắt là
/// việc của màn (ba vế "đang hiện" như `TheoDoiXem`). Lượt đang chờ chưa về
/// thì nhịp kế không hỏi chồng.
class BoHoiTrangThaiDon {
  BoHoiTrangThaiDon({
    required this.hoi,
    required this.khiCo,
    this.nhip = const Duration(seconds: 3),
  });

  final Future<TrangThaiDon> Function() hoi;
  final void Function(TrangThaiDon) khiCo;
  final Duration nhip;

  Timer? _timer;
  bool _dangHoi = false;

  bool get dangChay => _timer != null;

  void batDau() {
    if (_timer != null) return;
    _timer = Timer.periodic(nhip, (_) => hoiNgay());
  }

  void dung() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> hoiNgay() async {
    if (_dangHoi) return;
    _dangHoi = true;
    try {
      khiCo(await hoi());
    } catch (e) {
      debugPrint('[Premium] hỏi trạng thái đơn hỏng: ${e.runtimeType}');
    } finally {
      _dangHoi = false;
    }
  }
}
