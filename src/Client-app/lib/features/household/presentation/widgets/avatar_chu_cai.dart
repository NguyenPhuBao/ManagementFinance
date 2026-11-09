import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// Bảng pastel theo Stitch (`nha_chu`, `nha_thanh_vien`, `quan_ly_tv`): nền nhạt + chữ đậm cùng tông. Chữ luôn khác nền (quét 13).
const _bangMauAvatar = <({Color nen, Color chu})>[
  (nen: Color(0xFFE3EDFF), chu: Color(0xFF2F5BD6)), // xanh dương
  (nen: Color(0xFFFDE4E8), chu: Color(0xFFC62A47)), // hồng
  (nen: Color(0xFFDDF6E6), chu: Color(0xFF1B7F3B)), // xanh lá
  (nen: Color(0xFFE6E4FA), chu: Color(0xFF4338A8)), // tím
  (nen: Color(0xFFFFEFD2), chu: Color(0xFF9A5B00)), // hổ phách
];

/// Màu avatar chọn theo `idaccount`, KHÔNG theo tên (tên đổi được, màu của một người phải đứng yên ở mọi màn). Hàm thuần: cùng id
/// cùng màu. `null` (chưa biết người) → màu trung tính.
({Color nen, Color chu}) mauAvatarTheoId(int? idaccount) => idaccount == null
    ? (nen: AppColors.surfaceContainerHigh, chu: AppColors.textPrimary)
    : _bangMauAvatar[idaccount.abs() % _bangMauAvatar.length];

class AvatarChuCai extends StatelessWidget {
  const AvatarChuCai({super.key, required this.ten, this.idaccount, this.co = 40, this.daRoi = false});

  final String ten;

  /// Người đã rời nhà: avatar xám (Stitch `50af4171…`: nền `#f1f2ed`, chữ `#868882`), bỏ màu theo id.
  final bool daRoi;

  /// Quyết định màu; `null` → trung tính.
  final int? idaccount;
  final double co;

  @override
  Widget build(BuildContext context) {
    final t = ten.trim();
    final chu = t.isEmpty ? '?' : String.fromCharCode(t.runes.first).toUpperCase();
    final mau = daRoi ? (nen: const Color(0xFFF1F2ED), chu: const Color(0xFF868882)) : mauAvatarTheoId(idaccount);
    return Container(
      width: co,
      height: co,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: mau.nen, shape: BoxShape.circle),
      child: Text(chu, style: TextStyle(fontWeight: FontWeight.w700, color: mau.chu)),
    );
  }
}
