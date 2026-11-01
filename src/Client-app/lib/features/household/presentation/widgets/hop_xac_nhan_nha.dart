import 'package:flutter/material.dart';

import '../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/giai_tan_nha.dart';

/// Vạch đỏ trên đỉnh hộp giải tán (Stitch `ca283a41…`, hộp 4 và 5). Đặt vào chỗ `title` của `AlertDialog` có
/// `titlePadding` bằng 0 để vạch phủ hết bề rộng và bo theo góc hộp.
class _VachDo extends StatelessWidget {
  const _VachDo();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: Key('vach-do-hop'), height: 4, width: double.infinity, child: ColoredBox(color: AppColors.error));
}

/// Hộp của Nhà mình: canh trái, `scrollable` để cuộn được ở 360 dp + bàn phím + cỡ chữ lớn.
AlertDialog _hop({
  required Widget than,
  required List<Widget> actions,
  bool vachDo = false,
}) =>
    AlertDialog(
      scrollable: true,
      clipBehavior: Clip.antiAlias,
      title: vachDo ? const _VachDo() : null,
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      content: than,
      actions: actions,
    );

/// Ô tròn nhạt chứa biểu tượng, đứng bên trái tiêu đề.
class _OBieuTuong extends StatelessWidget {
  const _OBieuTuong({required this.icon, required this.mau});

  final IconData icon;
  final Color mau;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: mau.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: mau, size: 20),
      );
}

/// Thân hộp: biểu tượng bên trái, tiêu đề đậm + nội dung bên phải.
Widget _than(
  BuildContext context, {
  required IconData icon,
  required Color mau,
  required String tieuDe,
  required Widget noiDung,
  Color? mauTieuDe,
}) {
  final chu = Theme.of(context).textTheme;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _OBieuTuong(icon: icon, mau: mau),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tieuDe, style: chu.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: mauTieuDe ?? AppColors.textPrimary)),
            const SizedBox(height: 8),
            noiDung,
          ],
        ),
      ),
    ],
  );
}

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
  bool vachDo = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => _hop(
        vachDo: vachDo,
        than: _than(
          ctx,
          icon: icon,
          mau: mau,
          tieuDe: tieuDe,
          mauTieuDe: vachDo ? AppColors.error : null,
          noiDung: Text(noiDung, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        ),
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
    vachDo: true,
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
    final chu = Theme.of(context).textTheme;
    return _hop(
      vachDo: true,
      than: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.delete_forever_outlined, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(child: Text('Gõ tên nhà để xác nhận', style: chu.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('Nhập đúng:', style: chu.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              Container(
                key: const Key('o-ten-nha-giai-tan'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Text(widget.tenNha, style: chu.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('TÊN XÁC NHẬN', style: chu.labelSmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _o,
            autofocus: true,
            inputFormatters: const [GioiHanDoRong(DoRongCot.tenNha)],
            decoration: const InputDecoration(hintText: 'Nhập tên nhà để xác nhận'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.onError),
          onPressed: khop ? () => Navigator.of(context).pop(true) : null,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(Icons.lock_outline, size: 18), SizedBox(width: 6), Text('Giải tán nhà')],
          ),
        ),
      ],
    );
  }
}
