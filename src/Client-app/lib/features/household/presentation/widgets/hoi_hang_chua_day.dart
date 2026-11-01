import 'package:flutter/material.dart';

import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../domain/cau_loi_nha.dart';
import '../../domain/hang_chua_day.dart';
import '../bloc/nha_cubit.dart';
import 'hop_xac_nhan_nha.dart';

/// Rời nhà / Giải tán có hỏi lại khi còn hàng chưa đẩy (spec gia đình 2026-11-01 mục 7.3, đợt 1B Task 4). [viec] là
/// `cubit.roiNha` / `cubit.giaiTan`: lượt đầu không [boQua]; `_lam` của cubit KHÔNG toast cho `hangChuaDay` nên chỗ này tự quyết.
///
/// Hàng còn → đếm lại cho hộp ([moTa]); người dùng chọn [nhanLam] thì gọi lại với `boQua: true`. "Vẫn rời nhà" chạy
/// `dayVaCho` lần hai (trần 30 s): chấp nhận, không phải treo. Trả `true` khi đã làm xong.
Future<bool> lamCoHoiHangChuaDay(
  BuildContext context, {
  required NhaCubit cubit,
  required Future<bool> Function({bool boQua}) viec,
  required Future<HangChuaDayNha> Function() moTa,
  required String nhanLam,
  bool giaiTan = false,
}) async {
  if (await viec()) return true;
  if (!cubit.vuaGapHangChuaDay || !context.mounted) return false;
  final hang = await moTa();
  // Đếm lại ra rỗng: lượt bù vừa đẩy xong, chỉ cần làm lại. Vẫn vướng thì `_lam` không toast cho `hangChuaDay`: phải tự báo.
  if (hang.rong) {
    if (await viec()) return true;
    if (cubit.vuaGapHangChuaDay) baoNhanh(cauLoiNha(LoaiLoiNha.hangChuaDay), loai: LoaiThongBao.loi);
    return false;
  }
  if (!context.mounted) return false;
  if (!await hoiHangChuaDay(context, hang, nhanLam: nhanLam, giaiTan: giaiTan)) return false;
  return viec(boQua: true);
}
