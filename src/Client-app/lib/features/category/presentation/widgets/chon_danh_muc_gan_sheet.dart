import 'package:flutter/material.dart';

import '../../../../core/category/category_classify.dart';
import '../../../../core/category/category_visuals.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/theme/app_colors.dart';

/// Bảng chọn danh mục của màn *Gắn danh mục nhanh* (C1) — màn Stitch `45c91102174a4b56bbd15754bb9284af`.
///
/// Không dùng trang *Chọn danh mục* có sẵn: trang ấy mở đủ ba tab và không lọc được theo chiều tiền, nên chọn được
/// *"Lương"* cho một khoản chi. Ở đây [ungVien] đã được lọc bằng `hopLeTheoChieu` — MỘT luật với dự đoán.
///
/// ⚠️ `isScrollControlled` + thân cuộn: bottom sheet mặc định chỉ cao 9/16 màn (G60), mà một tài khoản có thể có hơn
/// mười danh mục chi.
Future<Category?> moChonDanhMucGan(
  BuildContext context, {
  required String loai,
  required String moTa,
  required List<Category> ungVien,
  String? dangChon,
}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
      child: _ThanBangChon(loai: loai, moTa: moTa, ungVien: ungVien, dangChon: dangChon),
    ),
  );
}

class _ThanBangChon extends StatelessWidget {
  const _ThanBangChon({required this.loai, required this.moTa, required this.ungVien, this.dangChon});

  final String loai;
  final String moTa;
  final List<Category> ungVien;
  final String? dangChon;

  @override
  Widget build(BuildContext context) {
    final chinh = [for (final c in ungVien) if (!isDebtClassify(c.classify)) c];
    final vayNo = [for (final c in ungVien) if (isDebtClassify(c.classify)) c];
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Chọn danh mục',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              moTa,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          // Màu nêu rõ: `Divider` mặc định lấy màu theme, trên máy thật ra một vạch ĐEN đậm — Stitch vẽ xám nhạt.
          const Divider(height: 1, color: AppColors.outlineVariant),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (chinh.isNotEmpty) ...[
                  _TieuDeNhom(loai == 'thu' ? 'KHOẢN THU' : 'KHOẢN CHI'),
                  for (final c in chinh) _DongDanhMuc(danhMuc: c, dangChon: c.id == dangChon),
                ],
                if (vayNo.isNotEmpty) ...[
                  const _TieuDeNhom('VAY / NỢ'),
                  for (final c in vayNo) _DongDanhMuc(danhMuc: c, dangChon: c.id == dangChon),
                ],
                if (ungVien.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có danh mục nào phù hợp',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TieuDeNhom extends StatelessWidget {
  const _TieuDeNhom(this.chu);
  final String chu;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
        child: Text(
          chu,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
      );
}

class _DongDanhMuc extends StatelessWidget {
  const _DongDanhMuc({required this.danhMuc, required this.dangChon});
  final Category danhMuc;
  final bool dangChon;

  @override
  Widget build(BuildContext context) {
    final mau = categoryColorFrom(danhMuc.colour);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: Key('gan-chon-${danhMuc.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(context, danhMuc),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: dangChon
              ? BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12))
              : null,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: mau.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(categoryIconFor(danhMuc.icon), size: 18, color: mau),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  danhMuc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: AppColors.primary),
                ),
              ),
              if (dangChon) const Icon(Icons.check, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
