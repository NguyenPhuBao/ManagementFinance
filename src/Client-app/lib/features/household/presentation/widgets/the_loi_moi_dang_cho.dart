import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/loi_moi.dart';
import '../../domain/cau_loi_nha.dart';
import '../../domain/vai_nha.dart';
import 'nha_minh/khung_the_nha.dart';

/// Thẻ *Lời mời đang chờ* (`01` mục 2.1, spec 12.3). Đang ở nhà ⇒ *Chấp nhận* khoá kèm câu theo vai. Admin tắt quyền tham
/// gia ⇒ khoá kèm câu trung tính, KHÔNG mời mua (spec 12.4). *Từ chối* luôn bấm được.
class TheLoiMoiDangCho extends StatelessWidget {
  const TheLoiMoiDangCho({
    super.key,
    required this.loiMoi,
    required this.dangONha,
    required this.laChu,
    required this.duocThamGia,
    required this.dangXuLy,
    required this.onChapNhan,
    required this.onTuChoi,
  });

  final LoiMoiToiEntity loiMoi;
  final bool dangONha;
  final bool laChu;
  final bool duocThamGia;
  final bool dangXuLy;
  final VoidCallback onChapNhan;
  final VoidCallback onTuChoi;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    // Chủ nhà không rời được (`duocLamViecNha(roiNha)` false) nên câu chung sẽ chỉ sai đường (spec 12.3, chốt 2026-11-01).
    final lyDo = dangONha
        ? (laChu ? cauLoiNha(LoaiLoiNha.chuPhaiChuyen) : 'Rời nhà hiện tại trước')
        : (duocThamGia ? null : cauLoiNha(LoaiLoiNha.tinhNangKhongMo));
    final han = loiMoi.hetHan;
    return KhungTheNha(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mail_outline, size: 18, color: AppColors.warning),
              const SizedBox(width: 6),
              Text('LỜI MỜI ĐANG CHỜ', style: chu.labelMedium?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(loiMoi.tenNha, style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${loiMoi.tenNguoiMoi} mời bạn với vai ${tenVai(loiMoi.vai)}', style: chu.bodyMedium),
          if (han != null) ...[
            const SizedBox(height: 2),
            Text('Hết hạn ${DateFormatter.formatDateTime(han.toLocal())}',
                style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: dangXuLy ? null : onTuChoi, child: const Text('Từ chối'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: (lyDo != null || dangXuLy) ? null : onChapNhan,
                  child: const Text('Chấp nhận'),
                ),
              ),
            ],
          ),
          if (lyDo != null) ...[
            const SizedBox(height: 6),
            Text(lyDo, style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
