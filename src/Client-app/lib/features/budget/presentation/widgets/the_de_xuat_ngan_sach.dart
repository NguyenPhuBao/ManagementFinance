import 'package:flutter/material.dart';

import '../../../../core/category/category_visuals.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/cua_so_nhin_lai.dart';
import '../../domain/de_xuat_ngan_sach.dart';

/// Thẻ "Chưa đặt ngân sách" trên trang Ngân sách — màn Stitch
/// `eb872aa9a0ba44ca8bf1c92d8d53186c`.
///
/// App vốn chỉ gợi ý *số tiền* **sau khi** người dùng đã tự chọn danh mục; thẻ
/// này là chỗ đầu tiên nó nói *"danh mục này bạn chi đều mà chưa đặt hạn mức"*.
///
/// ⚠️ **Widget không quyết định ẩn hay hiện.** `chonDeXuat` trả `null` khi
/// không có gì để gợi ý, và chỗ gọi (`BudgetTabsView`) không dựng thẻ. Cho
/// widget tự nhận một danh sách rỗng rồi tự trả `SizedBox.shrink()` là chép
/// luật ẩn ra chỗ thứ hai — và hai bản ấy sẽ lệch nhau vào ngày một bên đổi.
///
/// ⚠️ Dòng phụ *"Suy từ N ngày gần nhất"* chỉ hiện khi cửa sổ **ngắn hơn**
/// [kSoNgayNhinLai]. Hứa một mức "mỗi tháng" dựng từ hai tuần mà không nói gì
/// là bịa một lời hứa (bẫy 6 của spec); nhưng nói khi mẫu đã đủ dài thì câu ấy
/// chỉ còn là tiếng ồn.
class TheDeXuatNganSach extends StatelessWidget {
  final GoiDeXuat goi;

  /// Mở form tạo ngân sách đã điền sẵn danh mục và số tiền của dòng được bấm.
  final void Function(DeXuatNganSach) onTao;

  const TheDeXuatNganSach({
    super.key,
    required this.goi,
    required this.onTao,
  });

  bool get _mauNgan => goi.soNgayCuaSo < kSoNgayNhinLai;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('the-de-xuat-ngan-sach'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_circle_outline,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'CHƯA ĐẶT NGÂN SÁCH',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${goi.ds.length} nhóm',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (_mauNgan) ...[
            const SizedBox(height: 4),
            Text(
              'Suy từ ${goi.soNgayCuaSo} ngày gần nhất',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final d in goi.ds) _Dong(deXuat: d, onTao: () => onTao(d)),
        ],
      ),
    );
  }
}

class _Dong extends StatelessWidget {
  final DeXuatNganSach deXuat;
  final VoidCallback onTao;

  const _Dong({required this.deXuat, required this.onTao});

  @override
  Widget build(BuildContext context) {
    final mau = categoryColorFrom(deXuat.colour,
        fallback: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              // Nền nhạt cùng tông với màu danh mục, không phải màu đặc: dòng
              // này là gợi ý, không được nổi hơn thẻ ngân sách thật ngay dưới.
              color: mau.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(categoryIconFor(deXuat.icon), size: 18, color: mau),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deXuat.tenDanhMuc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  // "khoảng" chứ không phải một con số chắc chắn: đây là mức
                  // suy ra, không phải mức người dùng đặt.
                  'khoảng ${CurrencyFormatter.format(deXuat.mucThang)} '
                  'mỗi tháng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            key: ValueKey('de-xuat-tao-${deXuat.categoryId}'),
            onPressed: onTao,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Tạo',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
