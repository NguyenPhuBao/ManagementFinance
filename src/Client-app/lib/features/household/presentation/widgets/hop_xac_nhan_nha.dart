import 'package:flutter/material.dart';

import '../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/giai_tan_nha.dart';

/// Năm hộp xác nhận của Nhà mình (Stitch `ca283a41…`, spec 12.2 bỏ bộ đếm ký tự). Trang nằm trong `Navigator` nên dùng
/// `showDialog`. Bấm ra ngoài là KHÔNG làm: `null` đọc thành `false`.
Future<bool> _hoi(
  BuildContext context, {
  required IconData icon,
  required Color mau,
  required String tieuDe,
  required String noiDung,
  required String nhanHuy,
  required String nhanLam,
  Color mauNut = AppColors.error,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(icon, color: mau),
        title: Text(tieuDe),
        content: Text(noiDung),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(nhanHuy)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: mauNut, foregroundColor: AppColors.onError),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(nhanLam),
          ),
        ],
      ),
    ) ??
    false;

Future<bool> hoiRoiNha(BuildContext context) => _hoi(
      context,
      icon: Icons.logout,
      mau: AppColors.error,
      tieuDe: 'Rời nhà?',
      noiDung: 'Dữ liệu của nhà sẽ được gỡ khỏi máy này. Khoản bạn đã ghi vẫn ở lại nhà.',
      nhanHuy: 'Ở lại',
      nhanLam: 'Rời nhà',
    );

Future<bool> hoiMoiRa(BuildContext context, String ten) => _hoi(
      context,
      icon: Icons.person_remove_outlined,
      mau: AppColors.error,
      tieuDe: 'Mời $ten ra khỏi nhà?',
      noiDung: 'Các khoản người này đã ghi vẫn ở lại nhà.',
      nhanHuy: 'Huỷ',
      nhanLam: 'Mời ra',
    );

Future<bool> hoiChuyenChu(BuildContext context, String ten) => _hoi(
      context,
      icon: Icons.manage_accounts_outlined,
      mau: AppColors.warning,
      tieuDe: 'Chuyển chủ nhà cho $ten?',
      noiDung: 'Bạn sẽ thành Thành viên. Nếu chủ nhà mới không có Premium, nhà chuyển sang chế độ chỉ xem.',
      nhanHuy: 'Huỷ',
      nhanLam: 'Chuyển chủ nhà',
      mauNut: AppColors.primary,
    );

/// Hai bước (spec 5.5): cảnh báo, rồi gõ đúng tên nhà.
Future<bool> hoiGiaiTan(BuildContext context, String tenNha) async {
  final tiep = await _hoi(
    context,
    icon: Icons.warning_amber_rounded,
    mau: AppColors.error,
    tieuDe: 'Giải tán nhà?',
    noiDung: 'Quỹ chung, sổ chung và danh mục của nhà sẽ biến mất với mọi người.',
    nhanHuy: 'Huỷ',
    nhanLam: 'Tiếp tục',
  );
  if (!tiep || !context.mounted) return false;
  return await showDialog<bool>(context: context, builder: (_) => _HopGoTenNha(tenNha: tenNha)) ?? false;
}

class _HopGoTenNha extends StatefulWidget {
  const _HopGoTenNha({required this.tenNha});

  final String tenNha;

  @override
  State<_HopGoTenNha> createState() => _HopGoTenNhaState();
}

class _HopGoTenNhaState extends State<_HopGoTenNha> {
  final _o = TextEditingController();

  @override
  void dispose() {
    _o.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final khop = tenGiaiTanKhop(_o.text, widget.tenNha);
    return AlertDialog(
      icon: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
      title: const Text('Gõ tên nhà để xác nhận'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhập đúng: ${widget.tenNha}'),
            const SizedBox(height: 12),
            TextField(
              controller: _o,
              autofocus: true,
              inputFormatters: const [GioiHanDoRong(DoRongCot.tenNha)],
              decoration: const InputDecoration(hintText: 'Nhập tên nhà để xác nhận'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.onError),
          onPressed: khop ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Giải tán nhà'),
        ),
      ],
    );
  }
}
