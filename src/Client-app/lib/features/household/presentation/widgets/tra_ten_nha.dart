import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../category/data/models/category_entity.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../data/models/nha_cua_toi.dart';
import '../../domain/hoat_dong_nha.dart';

/// Tra tên và nhóm theo ngày dùng chung cho Hoạt động và Chi tiết ví chung (đợt 1B, Task 6 + 7): một định nghĩa, hai màn.

/// Tên người ghi: thành viên đang ở, người đã rời (kèm cờ), hay `Thành viên #id` khi không tra được.
TenNguoi tenNguoiNha(NhaCuaToi nha, int id) {
  for (final m in nha.thanhVien) {
    if (m.idaccount == id) return TenNguoi(m.tenHienThi);
  }
  for (final m in nha.thanhVienCu) {
    if (m.idaccount == id) return TenNguoi(m.tenHienThi, daRoi: true);
  }
  return TenNguoi('Thành viên #$id');
}

String tenViChungTheoId(List<WalletEntity> vi, String id) {
  for (final v in vi) {
    if (v.id == id) return v.name;
  }
  return 'Ví đã xoá';
}

/// Tên danh mục của khoản; `null` khi khoản không có danh mục (góp, rút, chuyển).
String? tenDanhMucKhoan(List<CategoryEntity> dm, TransactionEntity t) {
  final id = t.categoryId;
  if (id == null) return null;
  for (final c in dm) {
    if (c.id == id) return c.name;
  }
  return 'Danh mục đã xoá';
}

/// Màu chữ của tiêu đề nhóm ngày (Stitch `50af4171…` 7.3): không trùng token nào của `AppColors`.
const _mauNhomTrai = Color(0xFF686A65);
const _mauNhomPhai = Color(0xFF8C8E88);

/// Khoản của nhà gom theo NGÀY (thứ tự đã sắp của [ds]): mỗi nhóm một tiêu đề *Hôm nay · n giao dịch* và một thẻ trắng chia
/// bằng đường kẻ. [dong] dựng từng dòng.
List<Widget> nhomKhoanTheoNgay(
  BuildContext context, {
  required List<TransactionEntity> ds,
  required DateTime bayGio,
  required Widget Function(TransactionEntity t) dong,
}) {
  final chu = Theme.of(context).textTheme;
  final nhom = <String, List<TransactionEntity>>{};
  for (final t in ds) {
    nhom.putIfAbsent(DateFormatter.dayKey(t.date), () => []).add(t);
  }
  return [
    for (final entry in nhom.entries) ...[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(nhanNhomNgay(entry.value.first.date, bayGio),
                style: chu.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: _mauNhomTrai)),
            Text('${entry.value.length} giao dịch', style: chu.labelSmall?.copyWith(color: _mauNhomPhai)),
          ],
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          children: [
            for (var i = 0; i < entry.value.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.surfaceContainerLow),
              dong(entry.value[i]),
            ],
          ],
        ),
      ),
    ],
  ];
}
