/// Thẻ gợi ý danh mục và dòng đề xuất từ khoá của màn Thêm giao dịch — tách từ `_buildSuggestionCard` /
/// `_buildDeXuatTuKhoa` ngày 2026-10-10 (spec bịt điểm rò mục 5.2). Ghi phản hồi và đổi trạng thái ở lại trang.
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../../category/data/models/category_suggestion.dart';
import '../../../../category/domain/de_xuat_tu_khoa.dart';

/// Dòng đề xuất thêm / chuyển từ khoá (spec 2026-09-30, màn Stitch `8ca1338e…`).
class DongDeXuatTuKhoa extends StatelessWidget {
  const DongDeXuatTuKhoa({
    super.key,
    required this.daThem,
    required this.deXuat,
    required this.onChapNhan,
    required this.onBoQua,
  });

  final String? daThem;
  final ({DeXuatTuKhoa dx, String tenDanhMuc, String? tenCu})? deXuat;
  final VoidCallback onChapNhan;
  final VoidCallback onBoQua;

  @override
  Widget build(BuildContext context) {
    final daThem = this.daThem;
    final d = deXuat;
    const dam = TextStyle(fontWeight: FontWeight.w700);
    return Container(
      key: const Key('de-xuat-tu-khoa'),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: daThem != null || d == null
          ? Row(children: [
              const Icon(Icons.check_circle, color: AppColors.income, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(daThem ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ),
              ),
            ])
          : Row(children: [
              Icon(d.tenCu == null ? Icons.add_circle : Icons.sync, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  d.tenCu == null
                      ? TextSpan(children: [
                          const TextSpan(text: 'Thêm '),
                          TextSpan(text: '‘${d.dx.tuKhoa}’', style: dam),
                          const TextSpan(text: ' làm từ khoá của '),
                          TextSpan(text: d.tenDanhMuc, style: dam),
                          const TextSpan(text: '?'),
                        ])
                      : TextSpan(children: [
                          TextSpan(text: '‘${d.dx.tuKhoa}’', style: dam),
                          const TextSpan(text: ' đang là từ khoá của '),
                          TextSpan(text: d.tenCu, style: dam),
                          const TextSpan(text: ' — chuyển sang '),
                          TextSpan(text: d.tenDanhMuc, style: dam),
                          const TextSpan(text: '?'),
                        ]),
                  style: const TextStyle(fontSize: 13, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              // ⚠️ `minimumSize` hữu hạn BẮT BUỘC (bẫy 4.11): theme ép ElevatedButton rộng vô hạn.
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: onChapNhan,
                child: Text(d.tenCu == null ? 'Thêm' : 'Chuyển'),
              ),
              IconButton(
                tooltip: 'Bỏ qua đề xuất',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onBoQua,
              ),
            ]),
    );
  }
}

class TheGoiYDanhMuc extends StatelessWidget {
  const TheGoiYDanhMuc({
    super.key,
    required this.suggestion,
    required this.onBoQua,
    required this.onChon,
  });

  final CategorySuggestion suggestion;
  final VoidCallback onBoQua;
  final VoidCallback onChon;

  @override
  Widget build(BuildContext context) {
    return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gợi ý danh mục',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(
              suggestion.category.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            // Lý do theo NGUỒN: học → "Bạn thường ghi “grab” cho Di chuyển (6/7 lần)."; từ khoá → câu cũ.
            Text(
              suggestion.lyDo,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            // `Wrap` chứ không `Row` + `Spacer`: đủ chỗ thì hai nút nằm hai đầu một hàng y như trước; chật (màn 360 dp
            // với cỡ chữ lớn) thì nút sau XUỐNG DÒNG thay vì tràn sọc vàng. Từ dự án C thẻ này hiện cả khi 16 phím số
            // đang mở — tức thường xuyên hơn hẳn. `SizedBox` rộng hết cỡ để `spaceBetween` có chỗ mà giãn: `Wrap` trong
            // `Column` căn trái tự co theo nội dung, hai nút sẽ dính vào nhau.
            SizedBox(
              width: double.infinity,
              child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: onBoQua,
                  child: const Text('Bỏ qua'),
                ),
                // ⚠️ `minimumSize` hữu hạn BẮT BUỘC: theme của app ép mọi ElevatedButton rộng vô hạn, nút trần trong
                // `Row` làm trắng cả vùng form mà không một dòng log nào (bẫy 4.11). Lỗi có từ trước B1 — nghiệm thu
                // máy ảo 2026-09-29 mới lộ, vì mọi widget test cũ dựng MaterialApp trần.
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: onChon,
                  child: const Text('Chọn danh mục này'),
                ),
              ],
              ),
            ),
          ],
        ),
      );
  }
}
