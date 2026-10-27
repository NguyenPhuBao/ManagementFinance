import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../domain/chuyen_huong_theo_goi.dart';
import '../../domain/quyen_tinh_nang.dart';
import '../../domain/tran_goi.dart';
import '../../domain/hang_goi.dart';
import '../../data/dem_dang_hoat_dong.dart';
import '../../data/repositories/goi_repository.dart';

/// Cửa chặn DUY NHẤT của trần Basic (spec Premium 2026-10-06 mục 7.1): gắn vào
/// `redirect` của `/wallets/add` · `/budget/rules` · `/goals/add`, nên mọi lối
/// vào form (nút +, thẻ *Chưa đặt ngân sách*, lệnh tạo C3, deeplink) đều qua
/// đây. Trần hiệu lực không giới hạn → qua không đếm (rẻ); có số (Basic, hoặc
/// Premium có trần cột Premium — B1) → đếm → `conTaoDuoc` → `chuyenHuongTheoGoi` (đường sửa `?id=` tự cho qua). Đếm ném → qua: một lỗi
/// đọc CSDL không được biến thành một màn Nâng cấp sai chỗ.
///
/// Chờ kho gói của phiên nạp xong TRƯỚC khi đọc (G92): router chạy lại
/// `redirect` khi `AuthSuccess` tới, đúng lúc tài khoản vừa gán mà kho chưa
/// trả lời — đọc ngay là thấy Basic mặc định, Premium mở lạnh deeplink
/// `/goals/add` rơi vào `/premium`.
Future<String?> chanTheoGoi(
  Uri uri,
  LoaiTran loai, {
  required GoiRepository goi,
  required NguonDemDangHoatDong dem,
  DateTime Function()? clock,
}) async {
  await goi.choNapKho();
  final now = (clock ?? DateTime.now)();
  final id = goi.idaccount;
  if (id == null) return null;
  final trangThai = goi.hienTai;
  // Trần không giới hạn (Premium thường gặp) → qua, KHÔNG đếm: không trả giá một lượt đọc CSDL cho kết quả chắc chắn. Bản
  // trước tắt theo "Premium → qua" — từ B1 trần cột Premium cũng áp, nên phép tắt theo TRẦN, không theo gói.
  if (tranHieuLuc(trangThai, now).cua(loai) == null) return null;
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

/// Cửa chặn route theo QUYỀN bật/tắt (spec phân quyền 2026-10-08 mục 4.3) — hiện chỉ `/export-report`. Không có
/// quyền → `/premium?quyen=<maServer>`; chưa có phiên → qua (không đoán khi chưa biết tài khoản). Chờ kho như
/// [chanTheoGoi] (G92) — ở đây chiều hỏng là ngược lại: Basic mặc định không mang khoá nào nên quyền rơi về *mở*.
Future<String?> chanTheoQuyen(
  MaQuyen ma, {
  required GoiRepository goi,
  DateTime Function()? clock,
}) async {
  await goi.choNapKho();
  if (goi.idaccount == null) return null;
  return duocDung(ma, goi.hienTai, (clock ?? DateTime.now)())
      ? null
      : '/premium?quyen=${ma.maServer}';
}

/// `redirect` cho `GoRoute`, đọc `sl` LÚC CHẠY như [redirectTaoTheoGoi].
FutureOr<String?> Function(BuildContext, GoRouterState) redirectTheoQuyen(
        MaQuyen ma) =>
    (_, __) => chanTheoQuyen(ma, goi: sl<GoiRepository>());
