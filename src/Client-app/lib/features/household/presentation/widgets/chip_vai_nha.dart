import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/vai_nha.dart';

/// Chip chọn vai: đang chọn = nền đen chữ trắng, chưa chọn = nền xám nhạt (Stitch `456078e5…`, `b017710c…`). Dùng chung màn
/// Quản lý thành viên và màn Mời. [onChon] `null` là khoá: chip vẫn đọc ra là đang chọn, không rơi về kiểu "vô hiệu".
class ChipVaiNha extends StatelessWidget {
  const ChipVaiNha({super.key, required this.vai, required this.chon, required this.onChon, this.dauTick = false});

  final VaiNha vai;
  final bool chon;
  final VoidCallback? onChon;

  /// Kiểu màn Mời (Stitch `moi`), chip đứng trong `Expanded`: chữ nằm giữa, chip chọn có ✓ SÁT chữ, nhãn co lại khi cỡ chữ
  /// lớn thay vì bị cắt mờ dần. Màn Quản lý (mặc định) không có ✓.
  final bool dauTick;

  @override
  Widget build(BuildContext context) {
    final mau = chon ? AppColors.primary : AppColors.surfaceContainerLow;
    final chuNhan = chon ? AppColors.onPrimary : AppColors.textPrimary;
    final ten = tenVai(vai);
    return ChoiceChip(
      label: dauTick
          ? Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chon) ...[Icon(Icons.check, size: 18, color: chuNhan), const SizedBox(width: 6)],
                    Text(ten, maxLines: 1, softWrap: false),
                  ],
                ),
              ),
            )
          : Text(ten),
      selected: chon,
      showCheckmark: false,
      selectedColor: mau,
      backgroundColor: mau,
      disabledColor: mau,
      labelStyle: TextStyle(color: chuNhan),
      visualDensity: dauTick ? VisualDensity.compact : null, // Stitch `moi`: chip thấp hơn mặc định
      side: BorderSide.none,
      shape: const StadiumBorder(), // viên thuốc theo Stitch
      onSelected: onChon == null ? null : (_) => onChon!(),
    );
  }
}
