import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/vai_nha.dart';

/// Chip chọn vai: đang chọn = nền đen chữ trắng, chưa chọn = nền xám nhạt (Stitch `456078e5…`, `b017710c…`). Dùng chung màn
/// Quản lý thành viên và màn Mời. [onChon] `null` là khoá: chip vẫn đọc ra là đang chọn, không rơi về kiểu "vô hiệu".
class ChipVaiNha extends StatelessWidget {
  const ChipVaiNha({
    super.key,
    required this.vai,
    required this.chon,
    required this.onChon,
    this.dauTick = false,
    this.canGiua = false,
  });

  final VaiNha vai;
  final bool chon;
  final VoidCallback? onChon;

  /// Màn Mời (Stitch `moi`): chip đang chọn có ✓ trước chữ. Màn Quản lý không có.
  final bool dauTick;

  /// Chip đứng trong `Expanded`: chữ nằm giữa.
  final bool canGiua;

  @override
  Widget build(BuildContext context) {
    final mau = chon ? AppColors.primary : AppColors.surfaceContainerLow;
    return ChoiceChip(
      label: canGiua ? Center(child: Text(tenVai(vai))) : Text(tenVai(vai)),
      selected: chon,
      showCheckmark: dauTick,
      checkmarkColor: AppColors.onPrimary,
      selectedColor: mau,
      backgroundColor: mau,
      disabledColor: mau,
      labelStyle: TextStyle(color: chon ? AppColors.onPrimary : AppColors.textPrimary),
      side: BorderSide.none,
      shape: const StadiumBorder(), // viên thuốc theo Stitch
      onSelected: onChon == null ? null : (_) => onChon!(),
    );
  }
}
