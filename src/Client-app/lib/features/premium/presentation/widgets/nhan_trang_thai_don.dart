import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/trang_thai_don.dart';

/// Màu nhãn trạng thái đơn — MỘT định nghĩa cho Lịch sử mua và Chi tiết đơn (spec G94 2026-10-18 mục 5.6; Stitch
/// `04c4aa7d…`): đã trả xanh; còn chờ (thanh toán / xác nhận / hoàn tiền) cam; đã xong mà không kích hoạt (hoàn tiền,
/// huỷ, hết hạn) xám.
Color mauTrangThaiDon(TrangThaiDon t) => switch (t) {
      TrangThaiDon.paid => AppColors.income,
      TrangThaiDon.pending || TrangThaiDon.waitingConfirmation || TrangThaiDon.refundPending => AppColors.warning,
      TrangThaiDon.refunded || TrangThaiDon.cancelled || TrangThaiDon.expired => AppColors.textSecondary,
    };

/// Chữ trạng thái (`chuTrangThaiDon`) tô màu [mauTrangThaiDon]; [vien] = viên nền nhạt (đầu màn Chi tiết đơn).
class NhanTrangThaiDon extends StatelessWidget {
  const NhanTrangThaiDon(this.trangThai, {super.key, this.vien = false});

  final TrangThaiDon trangThai;
  final bool vien;

  @override
  Widget build(BuildContext context) {
    final mau = mauTrangThaiDon(trangThai);
    final chu = Text(
      chuTrangThaiDon(trangThai),
      style: TextStyle(fontSize: vien ? 12 : 11, fontWeight: FontWeight.w600, color: mau),
    );
    if (!vien) return chu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: chu,
    );
  }
}
