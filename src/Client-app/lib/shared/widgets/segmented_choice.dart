import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Một lựa chọn trên [SegmentedChoice]: giá trị và nhãn hiển thị.
class SegmentedOption<T> {
  final T value;
  final String label;

  const SegmentedOption(this.value, this.label);
}

/// Thanh chọn phân đoạn: các ô nằm trên **một hàng ngang**, chia đều bề
/// ngang, ô được chọn nổi nền trắng trên một rãnh xám.
///
/// Dùng chung cho chu kỳ của hoá đơn, ngân sách và mục tiêu (2026-09-06).
/// Trước đó ba form có ba bộ chọn viết tay: hoá đơn là thanh ngang, ngân sách
/// là `Wrap` hai ô mỗi hàng, mục tiêu là thanh ngang nhưng không khoá chiều
/// cao. Cùng một khái niệm mà ba hình dạng thì người dùng phải học ba lần.
///
/// Hình dạng theo bản dựng Stitch "Thêm Mục Tiêu Tiết Kiệm" (`flex
/// bg-surface-container-low p-1 rounded-xl`, ô chọn `bg-surface-container-lowest
/// shadow-sm`). Màn ngân sách trong Stitch vẽ ô viền rời nhưng cũng chia đều
/// một hàng (`flex-1`); phần "một hàng chia đều" là điểm chung được giữ.
///
/// Ba điều đã vấp, nay chỉ có một chỗ để tái phát:
///
/// - **`Row` + `Expanded`, không phải `Wrap`.** Một `Container` có `alignment`
///   mà không có kích thước sẽ giãn hết ràng buộc nhận được, nên trong `Wrap`
///   mỗi ô chiếm trọn một hàng — bốn chu kỳ của hoá đơn từng xếp dọc vì thế.
///   Và kể cả khi co theo nội dung, năm nhãn tiếng Việt cộng đệm vừa mấp mé
///   411dp nên thỉnh thoảng lại rớt hàng. Chia đều thì luôn một hàng.
/// - **`IntrinsicHeight` + `stretch`** để mọi ô cao bằng nhau: nhãn dài ngắn
///   khác nhau nên `FittedBox` co mỗi chữ một tỉ lệ, để tự do thì các viên
///   thuốc lệch nhau vài pixel.
/// - **Nhãn là `Text` thật** để test tìm theo chữ (`find.text`) vẫn chạy.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.keyPrefix,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.accent,
  });

  /// Tiền tố key của từng ô: `ValueKey('$keyPrefix-$value')`. Giá trị `null`
  /// cho key `...-null` — ngân sách dùng `null` cho "Ngày cụ thể".
  final String keyPrefix;

  final List<SegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Màu chữ của ô được chọn. Mặc định màu chính; mục tiêu dùng màu thu
  /// (Stitch: `text-secondary`).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final mauChon = accent ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final o in options)
              Expanded(
                child: _Segment<T>(
                  key: ValueKey('$keyPrefix-${o.value}'),
                  label: o.label,
                  selected: o.value == selected,
                  accent: mauChon,
                  onTap: () => onChanged(o.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        // Co chữ thay vì cắt bằng ellipsis: không ô nào được mất chữ, kể cả
        // khi cỡ chữ hệ thống lớn hoặc năm nhãn chen trên 411dp.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? accent : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
