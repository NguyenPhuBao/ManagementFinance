import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/loi_moi.dart';
import '../../domain/cau_loi_nha.dart';
import '../../domain/vai_nha.dart';
import 'khung_the_nha.dart';

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
    // Admin tắt quyền thắng: rời nhà không mở khoá được, chỉ làm mất dữ liệu nhà trên máy. Chủ nhà không rời được
    // (`duocLamViecNha(roiNha)` false) nên câu chung sẽ chỉ sai đường (spec 12.3, chốt 2026-11-01).
    final lyDo = !duocThamGia
        ? cauLoiNha(LoaiLoiNha.tinhNangKhongMo)
        : dangONha
            ? (laChu ? cauLoiNha(LoaiLoiNha.chuPhaiChuyen) : 'Rời nhà hiện tại trước')
            : null;
    final han = loiMoi.hetHan;
    return KhungTheNha(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mail_outline, size: 18, color: AppColors.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text('LỜI MỜI ĐANG CHỜ',
                    style: chu.labelMedium?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
              ),
              // Chấm cam báo có lời mời chưa xử lý (Stitch `nha_thanh_vien`).
              Container(
                key: const Key('cham-loi-moi'),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(loiMoi.tenNha, style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${loiMoi.tenNguoiMoi} mời bạn với vai ${tenVai(loiMoi.vai)}', style: chu.bodyMedium),
          if (han != null) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('Hết hạn ${DateFormatter.formatDateTime(han.toLocal())}',
                  style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ]),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: dangXuLy ? null : onTuChoi, child: const Text('Từ chối'))),
              const SizedBox(width: 12),
              Expanded(
                // Nửa thẻ ở 360 dp hẹp hơn đệm mặc định + ổ khoá + chữ (Realme: "Chấp nh…"): bớt đệm, co chữ thay vì cắt.
                child: FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: (lyDo != null || dangXuLy) ? null : onChapNhan,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (lyDo != null) ...[const Icon(Icons.lock_outline, size: 18), const SizedBox(width: 6)],
                      const Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Chấp nhận', maxLines: 1))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (lyDo != null) ...[
            const SizedBox(height: 6),
            // Câu lý do nằm dưới nút Chấp nhận (nửa phải), canh giữa dưới nút — Stitch `nha_thanh_vien`.
            Row(children: [
              const Expanded(child: SizedBox.shrink()),
              const SizedBox(width: 12),
              Expanded(
                child: Text(lyDo,
                    key: const Key('ly-do-khoa-chap-nhan'),
                    textAlign: TextAlign.center,
                    style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
