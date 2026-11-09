import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../category/data/models/category_entity.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../transaction/presentation/pages/add_transaction_page.dart' show EditTransactionArgs;
import '../../../wallet/data/models/wallet_entity.dart';
import '../../../wallet/data/repositories/wallet_repository.dart';
import '../../application/gop_quy_service.dart';
import '../../application/thao_tac_khoan_nha.dart';
import '../../data/models/nha_cua_toi.dart';
import '../../domain/cau_xoa_khoan_gop.dart';
import '../../domain/hoat_dong_nha.dart';
import '../../domain/loai_khoan_nha.dart';
import 'sheet_khoan_nha.dart';
import 'tra_ten_nha.dart';

/// Chạm một khoản của nhà: mở sheet chi tiết, rồi Sửa / Xoá theo `quyenKhoanNha` (đợt 1B Task 6 + 7). MỘT định nghĩa cho
/// Hoạt động và Chi tiết ví chung — hai màn không được chép lại.
///
/// ⚠️ Route `/nha/khoan` KHÔNG tự xét quyền sửa, nên nút Sửa của sheet là chốt duy nhất cho Thành viên (khoản chuyển mở form
/// sẽ không chip nào sáng). Khoản cặp sửa qua `/nha/gop?ma=` (Task 8).
///
/// [conSong] là `mounted` của trang gọi: sau mỗi `await` không dùng `context` khi trang đã đóng. Các nguồn `null` → `sl<…>()`,
/// chỉ chạm khi cần.
Future<void> moKhoanNha(
  BuildContext context, {
  required bool Function() conSong,
  required TransactionEntity khoan,
  required NhaCuaToi nha,
  required int? idToi,
  required DateTime bayGio,
  required List<WalletEntity> vi,
  required List<CategoryEntity> danhMuc,
  ThaoTacKhoanNha? thaoTac,
  GopQuyService? gopQuy,
  WalletRepository? viRieng,
}) async {
  final t = khoan;
  final quyen = quyenKhoanNha(t, vai: nha.vai, trangThai: nha.nha?.trangThai, idToi: idToi);
  final dich = t.walletTransfer;
  final hanhDong = await moSheetKhoanNha(
    context,
    khoan: t,
    nguoi: tenNguoiNha(nha, t.idaccount),
    nhanNgay: nhanNhomNgay(t.date, bayGio),
    viHienThi: phanLoaiKhoanNha(t) == LoaiKhoanNha.chuyen && dich != null
        ? '${tenViChungTheoId(vi, t.walletId)} → ${tenViChungTheoId(vi, dich)}'
        : tenViChungTheoId(vi, t.walletId),
    tenDanhMuc: tenDanhMucKhoan(danhMuc, t),
    quyen: quyen,
  );
  if (hanhDong == null || !conSong() || !context.mounted) return;
  switch (hanhDong) {
    case HanhDongKhoanNha.sua:
      final maCap = t.fundPairId;
      if (maCap != null) {
        // Chiều theo nửa của nhà (góp là `thu`, rút là `chi`) — cùng luật `phanLoaiKhoanNha`, không tự viết ở đây.
        final che = phanLoaiKhoanNha(t) == LoaiKhoanNha.rutNha ? 'rut' : 'gop';
        unawaited(context.push('/nha/gop?ma=${Uri.encodeQueryComponent(maCap)}&che=$che'));
        return;
      }
      CategoryEntity? dm;
      for (final c in danhMuc) {
        if (c.id == t.categoryId) dm = c;
      }
      // Thiếu `category` là cubit `danhMuc == null` và lưu sửa báo *Vui lòng chọn danh mục*.
      unawaited(context.push('/nha/khoan', extra: EditTransactionArgs(transaction: t, category: dm)));
    case HanhDongKhoanNha.xoa:
      await _xoa(context, conSong, t, nha, idToi, vi, thaoTac, gopQuy, viRieng);
  }
}

Future<void> _xoa(
  BuildContext context,
  bool Function() conSong,
  TransactionEntity t,
  NhaCuaToi nha,
  int? idToi,
  List<WalletEntity> vi,
  ThaoTacKhoanNha? thaoTac,
  GopQuyService? gopQuy,
  WalletRepository? viRieng,
) async {
  final maCap = t.fundPairId;
  if (maCap == null) {
    if (!await ConfirmDialog.show(context,
        title: 'Xoá khoản này?',
        message: 'Khoản sẽ bị xoá khỏi nhà và số dư ví chung được tính lại.',
        confirmText: 'Xoá',
        cancelText: 'Huỷ')) {
      return;
    }
  } else {
    final cau = await _cauXoaCap(t, maCap, nha, idToi, vi, gopQuy, viRieng);
    if (cau == null || !conSong() || !context.mounted) return;
    // Hàng của nhà: góp là `thu`, rút là `chi` (`phanLoaiKhoanNha`).
    final gop = phanLoaiKhoanNha(t) == LoaiKhoanNha.gopNha;
    if (!await hoiXoaKhoanGop(context, tieuDe: gop ? 'Xoá khoản góp?' : 'Xoá khoản rút?', cau: cau)) return;
  }
  if (!conSong()) return;
  try {
    await (thaoTac ?? sl<ThaoTacKhoanNha>()).xoa(t);
    baoNhanh('Đã xoá khoản.');
  } on CacheException catch (e) {
    baoNhanh(e.message, loai: LoaiThongBao.loi);
  } catch (_) {
    baoNhanh('Không xoá được khoản này. Thử lại sau.', loai: LoaiThongBao.loi);
  }
}

/// Câu hộp xoá khoản cặp, đọc nửa kia của cặp trên máy này. `null` khi đọc hỏng (đã báo).
Future<String?> _cauXoaCap(
  TransactionEntity t,
  String maCap,
  NhaCuaToi nha,
  int? idToi,
  List<WalletEntity> vi,
  GopQuyService? gopQuy,
  WalletRepository? viRieng,
) async {
  try {
    final cap = await (gopQuy ?? sl<GopQuyService>()).docCap(maCap);
    final nuaNha = cap.nha ?? t;
    final rieng = cap.rieng;
    String? tenViRieng;
    String? tenNguoiKhac;
    var nguoiDaRoi = false;
    if (rieng != null) {
      final v = await (viRieng ?? sl<WalletRepository>()).getById(rieng.walletId);
      tenViRieng = v?.name ?? 'ví riêng';
    } else if (t.idaccount != idToi) {
      // Chủ xoá hộ: nửa riêng nằm trên máy người ghi, máy này không có.
      final nguoi = tenNguoiNha(nha, t.idaccount);
      tenNguoiKhac = nguoi.ten;
      nguoiDaRoi = nguoi.daRoi;
    }
    return cauXoaKhoanGop(
      gop: nuaNha.type == 'thu',
      tenQuy: tenViChungTheoId(vi, nuaNha.walletId),
      soTien: t.amount,
      tenViRieng: tenViRieng,
      tenNguoiKhac: tenNguoiKhac,
      nguoiDaRoi: nguoiDaRoi,
    );
  } catch (_) {
    baoNhanh('Không đọc được khoản này. Thử lại sau.', loai: LoaiThongBao.loi);
    return null;
  }
}
