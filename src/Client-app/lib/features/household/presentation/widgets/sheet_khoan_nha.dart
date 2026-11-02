import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../domain/hoat_dong_nha.dart';
import '../../domain/loai_khoan_nha.dart';
import 'avatar_chu_cai.dart';
import 'dong_khoan_nha.dart';

enum HanhDongKhoanNha { sua, xoa }

/// Màu số tiền thu / góp trong sheet (Stitch `a8d53198…`: `#006e1c`), đậm hơn `#008736` ở danh sách.
const _mauThuSheet = Color(0xFF006E1C);

String _nhanLoai(TransactionEntity t) => switch (phanLoaiKhoanNha(t)) {
      LoaiKhoanNha.gopNha || LoaiKhoanNha.gopRieng => 'Góp vào quỹ',
      LoaiKhoanNha.rutNha || LoaiKhoanNha.rutRieng => 'Rút về ví riêng',
      LoaiKhoanNha.chuyen => 'Chuyển giữa ví chung',
      LoaiKhoanNha.thuKhac => 'Thu nhập',
      LoaiKhoanNha.chiNha => 'Chi tiêu',
      _ => t.type == 'thu' ? 'Thu nhập' : (t.type == 'transfer' ? 'Chuyển giữa ví' : 'Chi tiêu'),
    };

/// Mở chi tiết một khoản (Stitch `a8d53198…`). Trả hành động người dùng chọn, `null` khi đóng. Việc sửa / xoá do chỗ gọi làm,
/// vì xoá khoản cặp cần đọc nửa kia và hỏi lại.
Future<HanhDongKhoanNha?> moSheetKhoanNha(
  BuildContext context, {
  required TransactionEntity khoan,
  required TenNguoi nguoi,
  required String nhanNgay,
  required String viHienThi,
  required String? tenDanhMuc,
  required ({bool sua, bool xoa}) quyen,
}) =>
    showModalBottomSheet<HanhDongKhoanNha>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SheetKhoanNha(
        khoan: khoan,
        nguoi: nguoi,
        nhanNgay: nhanNgay,
        viHienThi: viHienThi,
        tenDanhMuc: tenDanhMuc,
        quyen: quyen,
      ),
    );

/// Nội dung sheet. Nút theo [quyen]: không quyền nào thì không hàng nút. Nút Sửa chỉ do chỗ gọi cấp (`quyen.sua`); khoản cặp
/// sửa qua `/nha/gop?ma=` (Task 8), chỉ người ghi (`duocSuaKhoanNha`).
class SheetKhoanNha extends StatelessWidget {
  const SheetKhoanNha({
    super.key,
    required this.khoan,
    required this.nguoi,
    required this.nhanNgay,
    required this.viHienThi,
    required this.tenDanhMuc,
    required this.quyen,
  });

  final TransactionEntity khoan;
  final TenNguoi nguoi;

  /// `Hôm nay` / `Hôm qua` / ngày — dòng phụ dưới tên.
  final String nhanNgay;

  /// Một ví (`Tiền chợ`) hoặc `Tiền chợ → Điện nước` khi chuyển.
  final String viHienThi;
  final String? tenDanhMuc;
  final ({bool sua, bool xoa}) quyen;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final dau = dauTienKhoanNha(khoan);
    final mauTien = nguoi.daRoi ? AppColors.textSecondary : (dau == true ? _mauThuSheet : AppColors.textPrimary);
    final laChuyen = phanLoaiKhoanNha(khoan) == LoaiKhoanNha.chuyen;
    final ghiChu = khoan.note.trim();
    final dong = <(String, String)>[
      ('Loại', _nhanLoai(khoan)),
      if (tenDanhMuc != null) ('Danh mục', tenDanhMuc!),
      (laChuyen ? 'Chuyển' : 'Ví chung', viHienThi),
      ('Người ghi', nguoi.daRoi ? '${nguoi.ten} (đã rời)' : nguoi.ten),
      ('Ngày', DateFormatter.formatDate(khoan.date)),
      if (ghiChu.isNotEmpty) ('Ghi chú', ghiChu),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  AvatarChuCai(ten: nguoi.ten, idaccount: khoan.idaccount, co: 40, daRoi: nguoi.daRoi),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tieuDeKhoanNha(khoan, nguoi),
                            key: const Key('sheet-tieu-de'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text(nhanNgay, style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 13 chữ số ở 28 px rộng hơn sheet: co một dòng, không xuống dòng (Text xuống dòng không báo tràn).
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(chuTienKhoanNha(khoan),
                      key: const Key('sheet-so-tien'),
                      maxLines: 1,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: mauTien)),
                ),
              ),
              const SizedBox(height: 8),
              for (final (nhan, giaTri) in dong) ...[
                const Divider(height: 1, color: AppColors.surfaceContainerLow),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nhan, style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(giaTri,
                            textAlign: TextAlign.right,
                            style: chu.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ),
                    ],
                  ),
                ),
              ],
              if (quyen.sua || quyen.xoa) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (quyen.xoa)
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            key: const Key('sheet-xoa'),
                            onPressed: () => Navigator.of(context).pop(HanhDongKhoanNha.xoa),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 19),
                            label: const Text('Xoá'),
                          ),
                        ),
                      ),
                    if (quyen.sua && quyen.xoa) const SizedBox(width: 12),
                    if (quyen.sua)
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: FilledButton.icon(
                            key: const Key('sheet-sua'),
                            onPressed: () => Navigator.of(context).pop(HanhDongKhoanNha.sua),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 19),
                            label: const Text('Sửa'),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Hộp *Xoá khoản góp?* / *Xoá khoản rút?* (Stitch `6dc96c4a…` 8B): ô thùng rác, tiêu đề, [cau] từ `cauXoaKhoanGop`, Huỷ / Xoá.
/// Trả `true` khi người dùng bấm Xoá.
Future<bool> hoiXoaKhoanGop(BuildContext context, {required String tieuDe, required String cau}) async {
  final kq = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.errorContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_outline, color: AppColors.error),
        ),
      ),
      iconPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Text(tieuDe, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      content: Text(cau, style: Theme.of(ctx).textTheme.bodySmall),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Huỷ', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          key: const Key('hop-xoa-xac-nhan'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Xoá', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return kq ?? false;
}
