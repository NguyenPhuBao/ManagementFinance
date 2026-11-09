import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/bang_gop.dart';
import '../../domain/hoat_dong_nha.dart';
import 'avatar_chu_cai.dart';

/// Màu nhãn ô số của người đã rời (Stitch `6d63311f…`, `#8c8e87`): không trùng token nào của `AppColors`.
const _nhanDaRoi = Color(0xFF8C8E87);

/// Tab Bảng góp của Chi tiết ví chung (Stitch `6d63311f…`): mỗi người một thẻ, bốn ô *Góp tháng này · Góp từ trước tới nay · Đã
/// rút · Đã chi tháng này*. Không gọi `sl`: trang gom [the] (đã xếp thành viên đang ở trước, người đã rời sau) và truyền tên vào.
///
/// Không có huy hiệu *Đã góp* và dòng *Cập nhật tháng này* của Stitch (bảng ghi "có thể thừa", điều kiện không rõ).
class BangGopView extends StatelessWidget {
  const BangGopView({super.key, required this.the, required this.tenNguoi});

  /// [daRoi] là người không còn trong nhà: thẻ xám, có huy hiệu *Đã rời*.
  final List<({DongBangGop dong, bool daRoi})> the;
  final TenNguoi Function(int idaccount) tenNguoi;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    if (the.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('Chưa có ai góp vào ví này.', style: chu.bodyMedium?.copyWith(color: AppColors.textSecondary))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text('Thành viên ví (${the.length})',
              style: chu.labelMedium?.copyWith(fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        ),
        for (var i = 0; i < the.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _TheGop(dong: the[i].dong, daRoi: the[i].daRoi, ten: tenNguoi(the[i].dong.idaccount).ten),
        ],
      ],
    );
  }
}

class _TheGop extends StatelessWidget {
  const _TheGop({required this.dong, required this.daRoi, required this.ten});

  final DongBangGop dong;
  final bool daRoi;
  final String ten;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final id = dong.idaccount;
    return Container(
      key: Key('the-gop-$id'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: daRoi ? AppColors.surface.withValues(alpha: 0.8) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarChuCai(ten: ten, idaccount: id, co: 36, daRoi: daRoi),
              const SizedBox(width: 12),
              Expanded(
                child: Text(daRoi ? '$ten (đã rời)' : ten,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: chu.bodyMedium?.copyWith(
                        fontWeight: daRoi ? FontWeight.w500 : FontWeight.w600,
                        color: daRoi ? AppColors.textSecondary : AppColors.textPrimary)),
              ),
              if (daRoi) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(999)),
                  child: Text('Đã rời', style: chu.labelSmall?.copyWith(color: AppColors.textSecondary)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _O(khoa: 'o-gop-thang-$id', nhan: 'Góp tháng này', so: dong.gopThangNay, daRoi: daRoi)),
              const SizedBox(width: 12),
              Expanded(child: _O(khoa: 'o-gop-tong-$id', nhan: 'Góp từ trước tới nay', so: dong.gopTuTruoc, daRoi: daRoi)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _O(khoa: 'o-da-rut-$id', nhan: 'Đã rút', so: dong.daRut, daRoi: daRoi)),
              const SizedBox(width: 12),
              Expanded(child: _O(khoa: 'o-da-chi-$id', nhan: 'Đã chi tháng này', so: dong.chiThangNay, daRoi: daRoi)),
            ],
          ),
        ],
      ),
    );
  }
}

class _O extends StatelessWidget {
  const _O({required this.khoa, required this.nhan, required this.so, required this.daRoi});

  final String khoa;
  final String nhan;
  final double so;
  final bool daRoi;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return Column(
      key: Key(khoa),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nhan,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: chu.labelSmall?.copyWith(fontSize: 10.5, color: daRoi ? _nhanDaRoi : AppColors.textSecondary)),
        const SizedBox(height: 2),
        // 13 chữ số ở 13 px vẫn có thể rộng hơn nửa thẻ ở cỡ chữ lớn: co lại một dòng thay vì xuống dòng.
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(CurrencyFormatter.format(so),
                maxLines: 1,
                style: chu.bodySmall?.copyWith(
                    fontSize: 13,
                    fontWeight: daRoi ? FontWeight.w500 : FontWeight.w600,
                    color: daRoi ? AppColors.textSecondary : AppColors.textPrimary)),
          ),
        ),
      ],
    );
  }
}
