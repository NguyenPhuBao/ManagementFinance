import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_container.dart';
import '../domain/chuyen_huong_theo_goi.dart';
import '../domain/tran_goi.dart';
import 'dem_dang_hoat_dong.dart';
import 'goi_repository.dart';

/// Cửa chặn DUY NHẤT của trần Basic (spec Premium 2026-10-06 mục 7.1): gắn vào
/// `redirect` của `/wallets/add` · `/budget/rules` · `/goals/add`, nên mọi lối
/// vào form (nút +, thẻ *Chưa đặt ngân sách*, lệnh tạo C3, deeplink) đều qua
/// đây. Premium → qua không đếm (rẻ); Basic → đếm → `conTaoDuoc` →
/// `chuyenHuongTheoGoi` (đường sửa `?id=` tự cho qua). Đếm ném → qua: một lỗi
/// đọc CSDL không được biến thành một màn Nâng cấp sai chỗ.
Future<String?> chanTheoGoi(
  Uri uri,
  LoaiTran loai, {
  required GoiRepository goi,
  required NguonDemDangHoatDong dem,
  DateTime Function()? clock,
}) async {
  final now = (clock ?? DateTime.now)();
  final id = goi.idaccount;
  if (id == null) return null;
  final trangThai = goi.hienTai;
  if (trangThai.laPremium(now)) return null;
  try {
    final dangCo = await dem.dem(loai, id);
    return chuyenHuongTheoGoi(
      uri,
      conTaoDuoc(loai: loai, dangCo: dangCo, goi: trangThai, now: now),
    );
  } catch (e) {
    debugPrint('[Premium] đếm $loai hỏng, cho qua: ${e.runtimeType}');
    return null;
  }
}

/// `redirect` cho `GoRoute`. Đọc `sl` LÚC CHẠY, không lúc dựng router: router
/// dựng trước khi phiên có, và test đăng ký bản giả rồi mới điều hướng.
FutureOr<String?> Function(BuildContext, GoRouterState) redirectTaoTheoGoi(
        LoaiTran loai) =>
    (_, state) => chanTheoGoi(
          state.uri,
          loai,
          goi: sl<GoiRepository>(),
          dem: sl<NguonDemDangHoatDong>(),
        );
