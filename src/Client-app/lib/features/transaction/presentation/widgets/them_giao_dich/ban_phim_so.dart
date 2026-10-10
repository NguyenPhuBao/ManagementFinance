/// Bàn phím 16 phím của màn Thêm giao dịch — tách từ `_buildNumericKeyboard` / `_buildKeyContent` ngày 2026-10-10 (spec bịt
/// điểm rò mục 5.2). Phím ✓ là nút lưu; phép gõ nằm ở `domain/ban_phim_so_tien.dart`, widget chỉ báo phím.
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/ban_phim_so_tien.dart';

class BanPhimSo extends StatelessWidget {
  const BanPhimSo({super.key, required this.isSubmitting, required this.onKey, required this.onLuu});

  final bool isSubmitting;
  final ValueChanged<String> onKey;
  final VoidCallback onLuu;

  @override
  Widget build(BuildContext context) {
    final keys = [
      '7',
      '8',
      '9',
      'backspace',
      '4',
      '5',
      '6',
      '+',
      '1',
      '2',
      '3',
      '-',
      // Ô này từng là phím `.` — bỏ vì nó sinh số lẻ mà đường lưu đọc sai gấp
      // mười, và app làm tròn về đồng chẵn ở mọi chỗ hiển thị. Thay bằng `00`
      // chứ không để trống: lưới là 4×4, thiếu một ô thì hàng cuối lệch cột.
      '00',
      '0',
      '000',
      'done'
    ];

    return GridView.builder(
      key: const Key('ban-phim-so'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 16,
      // `mainAxisExtent` CỐ ĐỊNH thay vì `childAspectRatio`: bàn phím neo đáy
      // phải cao như nhau ở mọi bề rộng — tỉ lệ ở khung test 800dp cho phím
      // cao gấp đôi và nuốt hết chỗ của thẻ form.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 50,
      ),
      itemBuilder: (context, index) {
        final keyStr = keys[index];
        bool isOperator = keyStr == 'backspace' || keyStr == '+' || keyStr == '-';
        bool isDone = keyStr == 'done';

        return Material(
          color: isDone
              ? AppColors.primary
              : isOperator
                  ? AppColors.surfaceContainer
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            // ✓ là nút lưu (từng là phím chết: `themPhimSoTien` trả nguyên
            // chuỗi với 'done').
            onTap: isDone ? (isSubmitting ? null : onLuu) : () => onKey(keyStr),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (!isOperator && !isDone)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Center(
                child: _noiDungPhim(keyStr, isDone),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _noiDungPhim(String keyStr, bool isDone) {
    if (keyStr == 'backspace') {
      return const Icon(Icons.backspace_outlined, size: 24, color: AppColors.primary);
    }
    if (keyStr == 'done') {
      return const Icon(Icons.check, size: 28, color: Colors.white);
    }
    if (keyStr == kToanTuCong || keyStr == kToanTuTru) {
      return Text(
        // Dấu trừ THẬT (U+2212), cùng ký hiệu với dòng số; gạch nối ASCII ở
        // ngay trước một con số đọc như dấu âm. Giá trị nội bộ vẫn là '-'.
        keyStr == kToanTuTru ? '−' : keyStr,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.normal, color: AppColors.primary),
      );
    }
    return Text(
      keyStr,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primary),
    );
  }
}
