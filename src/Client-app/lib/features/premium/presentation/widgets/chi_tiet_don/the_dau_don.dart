import 'package:flutter/material.dart';
import '../../../../../core/utils/date_formatter.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/dong_lich_su.dart';
import '../nhan_trang_thai_don.dart';

/// Thẻ đầu màn Chi tiết đơn — biểu tượng gói tô màu trạng thái, tên gói, viên trạng thái; dòng phụ *mã đơn · giờ tạo*
/// xuống hàng riêng rộng hết thẻ (bố cục Stitch `d3b59018…`; màn `408de0af…` để dòng phụ cạnh viên trạng thái — ở 320 dp
/// cột ấy chỉ còn ~120 dp, nên mọi trạng thái dùng bố cục `d3b59018…`).
class TheDauDon extends StatelessWidget {
  const TheDauDon(this.don, {super.key});

  final DongLichSu don;

  @override
  Widget build(BuildContext context) {
    final mau = mauTrangThaiDon(don.trangThai);
    final tao = don.taoLuc;
    final phu = tao == null
        ? 'Mã đơn #${don.orderCode}'
        : 'Mã đơn #${don.orderCode} · Tạo lúc ${DateFormatter.formatTimeDate(tao.toLocal())}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: mau.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.workspace_premium, size: 20, color: mau),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Gói Premium 30 ngày',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 8),
              NhanTrangThaiDon(don.trangThai, vien: true),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Text(phu, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
