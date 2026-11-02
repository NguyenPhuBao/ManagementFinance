import 'package:flutter/material.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../category/presentation/widgets/category_visuals.dart';
import '../../../../goal/data/models/goal_entity.dart';
import '../../../../wallet/data/models/wallet_entity.dart';
import '../../../../wallet/domain/wallet_status.dart';
import '../../../../wallet/domain/wallet_type.dart';
import '../../../domain/muc_tieu_chung.dart';
import '../khung_the_nha.dart';
import '../tien_do_muc_tieu.dart';

/// Màu chữ phụ của Stitch `d2a8c9bb…` (`on-surface-variant`): không trùng token nào của `AppColors`.
const _chuPhu = Color(0xFF454743);

/// Khối VÍ CHUNG của Nhà mình (Stitch `d2a8c9bb…` 1.3): tổng quỹ, mỗi ví một dòng, nút Tạo ví chung. Không gọi `sl` — trang
/// truyền dữ liệu và hành động vào.
///
/// - [onTao] `null` = người xem không quản lý được ví chung (Thành viên, Chỉ xem, nhà chỉ xem): KHÔNG có nút. Có [onTao] mà
///   [coTheTao] `false` (đủ trần) thì nút tắt kèm câu [lyDoKhoa].
/// - [onChamVi] `null` = dòng ví không chạm được và không chevron: chi tiết ví chưa có route (Task 7 truyền vào).
class KhoiViChung extends StatelessWidget {
  const KhoiViChung({
    super.key,
    required this.vi,
    required this.tongQuy,
    required this.coTheTao,
    this.lyDoKhoa,
    this.onTao,
    this.onChamVi,
    this.mucTieu = const {},
    this.dongHo,
  });

  final List<WalletEntity> vi;

  /// Mục tiêu chung theo id ví (đợt 2): ví có mục tiêu thì dòng ví có thêm thanh tiến độ, kể cả ví lưu trữ.
  final Map<String, GoalEntity> mucTieu;

  /// Đồng hồ tiêm được cho trạng thái quá hạn; `null` → giờ máy.
  final DateTime Function()? dongHo;
  final double tongQuy;
  final bool coTheTao;
  final String? lyDoKhoa;
  final VoidCallback? onTao;
  final void Function(String id)? onChamVi;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('VÍ CHUNG',
              style: chu.labelMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
        KhungTheNha(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TỔNG QUỸ CHUNG',
                  style: chu.labelSmall?.copyWith(color: _chuPhu, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              // 13 chữ số ở 28 px rộng hơn thẻ: co lại một dòng thay vì xuống dòng (Text xuống dòng không báo tràn).
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(CurrencyFormatter.formatSoThoi(tongQuy.round()),
                          maxLines: 1,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(width: 6),
                      const Text('đ',
                          maxLines: 1,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.outlineVariant),
              if (vi.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Chưa có ví chung nào.', style: chu.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                )
              else
                for (var i = 0; i < vi.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.outlineVariant),
                  _DongVi(vi: vi[i], onCham: onChamVi, mucTieu: mucTieu[vi[i].id], bayGio: (dongHo ?? DateTime.now)()),
                ],
              if (onTao != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: coTheTao ? onTao : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Icon(Icons.add, size: 18), SizedBox(width: 6), Text('Tạo ví chung')],
                    ),
                  ),
                ),
                if (!coTheTao && lyDoKhoa != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(lyDoKhoa!,
                        key: const Key('ly-do-khoa-tao-vi-chung'),
                        textAlign: TextAlign.center,
                        style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DongVi extends StatelessWidget {
  const _DongVi({required this.vi, required this.onCham, required this.mucTieu, required this.bayGio});

  final WalletEntity vi;
  final void Function(String id)? onCham;
  final GoalEntity? mucTieu;
  final DateTime bayGio;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final mau = categoryColorFrom(vi.colour);
    final luuTru = !WalletStatus.laHoatDong(vi.status);
    final loai = WalletType.tuKhoa(vi.type).nhan;
    final cham = onCham;
    return Opacity(
      opacity: luuTru ? 0.6 : 1,
      child: InkWell(
        key: Key('dong-vi-${vi.id}'),
        onTap: cham == null ? null : () => cham(vi.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
            builder: (context, c) {
              final tran = c.maxWidth * 0.6;
              return Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: mau.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(categoryIconFor(vi.icon), size: 20, color: mau),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vi.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: chu.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    Text(luuTru ? '$loai · Đã lưu trữ' : loai,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: chu.labelSmall?.copyWith(color: _chuPhu)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Số tiền KHÔNG flex: đứng sát mép phải theo bề rộng tự nhiên, tên (`Expanded`) nhận phần còn lại. Chỉ chặn trần
              // 60 % dòng để số 13 chữ số co lại (FittedBox) thay vì đè hết tên.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: tran),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(CurrencyFormatter.format(vi.balance),
                      maxLines: 1, style: chu.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
              if (cham != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
              ],
            ],
              );
            },
              ),
              if (mucTieu case final muc?)
                // Thụt 48: ô tròn 36 + khe 12, thẳng với cột tên.
                Padding(
                  padding: const EdgeInsets.only(left: 48, top: 10),
                  child: TienDoGon(tienDo: tienDoMucTieuChung(mucTieu: muc, soDuVi: vi.balance, now: bayGio)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
