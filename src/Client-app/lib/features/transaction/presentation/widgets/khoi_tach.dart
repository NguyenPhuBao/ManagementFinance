/// A5 mục 11.2 — khối *"TÁCH THEO DANH MỤC"* trên form Thêm giao dịch (Stitch `01f8cdc6…`): danh mục chính nhận phần
/// còn lại (tự tính, không sửa tay), mỗi phần một dòng (chạm để sửa, ✕ để bỏ), *"+ Thêm phần"* cuối khối.
///
/// ⚠️ Kế hoạch khác Stitch có chủ ý: form chỉ lưu bằng ✓ (không nút *"Lưu N giao dịch"* ở đáy), nên chân khối nói
/// *"Sẽ lưu N giao dịch"*.
library;

import 'package:flutter/material.dart';

import '../../../../core/category/category_visuals.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/tach_giao_dich.dart';

class KhoiTach extends StatelessWidget {
  const KhoiTach({
    super.key,
    required this.chinh,
    required this.tong,
    required this.phan,
    required this.danhMuc,
    required this.onSua,
    required this.onBo,
    required this.onThem,
  });

  /// Danh mục đang chọn trên form — `null` khi chưa chọn.
  final Category? chinh;
  final double tong;
  final List<PhanTach> phan;

  /// Tra tên / màu theo id.
  final Map<String, Category> danhMuc;
  final void Function(PhanTach p) onSua;
  final void Function(PhanTach p) onBo;
  final VoidCallback onThem;

  @override
  Widget build(BuildContext context) {
    final con = conLai(tong, phan);
    return Container(
      key: const Key('khoi-tach'),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'TÁCH THEO DANH MỤC',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: AppColors.textSecondary),
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Tổng: ${CurrencyFormatter.format(tong)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _dong(
            key: const Key('tach-chinh'),
            ten: chinh?.name ?? 'Chọn danh mục chính',
            mau: chinh?.colour,
            phu: 'còn lại, tự tính',
            soTien: con,
            soKey: const Key('tach-con-lai'),
            amMau: con <= 0,
          ),
          for (final p in phan)
            InkWell(
              key: Key('tach-phan-${p.categoryId}'),
              onTap: () => onSua(p),
              child: _dong(
                ten: danhMuc[p.categoryId]?.name ?? 'Danh mục',
                mau: danhMuc[p.categoryId]?.colour,
                phu: p.monIds.isEmpty ? null : '${p.monIds.length} món',
                soTien: p.soTien,
                cuoi: IconButton(
                  key: Key('tach-bo-${p.categoryId}'),
                  tooltip: 'Bỏ phần',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                  onPressed: () => onBo(p),
                ),
              ),
            ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              TextButton.icon(
                key: const Key('tach-them-phan'),
                onPressed: onThem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm phần'),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Sẽ lưu ${phan.length + 1} giao dịch',
                  key: const Key('tach-so-giao-dich'),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dong({
    Key? key,
    required String ten,
    required String? mau,
    String? phu,
    required double soTien,
    Key? soKey,
    bool amMau = false,
    Widget? cuoi,
  }) =>
      Padding(
        key: key,
        padding: EdgeInsets.fromLTRB(0, 8, cuoi == null ? 8 : 0, 8),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: categoryColorFrom(mau), shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tên dài xuống dòng, KHÔNG cắt (họ lỗi G74: "…" làm mất thông tin ở 320 dp).
                  Text(ten,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.primary)),
                  if (phu != null)
                    Text(phu, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Số tiền tới 13 chữ số: co chữ, không cắt (bài học G51 / G74).
            Flexible(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  CurrencyFormatter.format(soTien),
                  key: soKey,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: amMau ? AppColors.expense : AppColors.primary,
                  ),
                ),
              ),
            ),
            if (cuoi != null) cuoi,
          ],
        ),
      );
}
