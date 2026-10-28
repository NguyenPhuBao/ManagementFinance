import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/category_entity.dart';
import 'category_visuals.dart';

/// G110 (2026-10-28) — danh mục **đang ẩn theo khuôn** (`CategoryTree.dangTamNgung`, luật `dangAnTheoKhuon`): admin xoá danh mục
/// hệ thống cùng (tên, loại) nên nó biến khỏi mọi bộ chọn. Hai khối của màn Stitch `2dd819da…` *"Danh mục - Mục Đang tạm ngừng"*:
/// [MucDangTamNgung] cuối màn Danh mục — chỗ duy nhất người dùng thấy nó và mở form Sửa để đổi tên (đổi tên → hết khớp khuôn → hiện
/// lại, chốt 2 spec 2026-10-27) — và [DaiNhacTamNgung] đầu form Sửa. Tông xám của băng *"Tạm ngừng"* (`AppColors.khoaNgung*`).
/// Chữ không cắt `…` (luật G74–G78).

/// Khối thu gọn sẵn (người dùng chốt). Không nút xoá, không nút Nâng cấp — chỉ bút mở form Sửa kèm `?tamNgung=1`.
class MucDangTamNgung extends StatefulWidget {
  const MucDangTamNgung({super.key, required this.danhMuc});

  final List<CategoryEntity> danhMuc;

  @override
  State<MucDangTamNgung> createState() => _MucDangTamNgungState();
}

class _MucDangTamNgungState extends State<MucDangTamNgung> {
  bool _mo = false;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('muc-dang-tam-ngung'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.khoaNgungNen,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.khoaNgungVien),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: _mo,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _mo = !_mo),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.pause_circle_outline, size: 22, color: AppColors.khoaNgungIcon),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đang tạm ngừng (${widget.danhMuc.length})',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Danh mục hệ thống cùng tên đã ngừng',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(_mo ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.khoaNgungIcon),
                  ],
                ),
              ),
            ),
            if (_mo) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.khoaNgungVien),
              const SizedBox(height: 10),
              for (final (i, dm) in widget.danhMuc.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                _Dong(danhMuc: dm),
              ],
            ],
          ],
        ),
      );
}

class _Dong extends StatelessWidget {
  const _Dong({required this.danhMuc});

  final CategoryEntity danhMuc;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Opacity(
              opacity: 0.5,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle),
                child: Icon(categoryIconFor(danhMuc.icon), size: 18, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    danhMuc.name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                  const Text(
                    'Đổi tên để dùng tiếp',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key('tam-ngung-sua-${danhMuc.id}'),
              tooltip: 'Sửa danh mục',
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
              onPressed: () => context.push('/categories/child/${danhMuc.id}/edit?tamNgung=1'),
            ),
          ],
        ),
      );
}

/// Dải nhắc đầu form Sửa khi mở từ [MucDangTamNgung] (Stitch `2dd819da…` khối 2): chỉ đổi biểu tượng / màu / từ khoá thì danh mục
/// VẪN ẩn (chốt 2 spec 2026-10-27) — người dùng cần biết đổi tên mới là lối ra. Không nút.
class DaiNhacTamNgung extends StatelessWidget {
  const DaiNhacTamNgung({super.key, required this.ten});

  /// Tên lúc mở form (không theo ô đang gõ).
  final String ten;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('dai-nhac-tam-ngung'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.khoaNgungNen,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.khoaNgungVien),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline, size: 20, color: AppColors.khoaNgungIcon),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '‘$ten’ đang tạm ngừng vì danh mục hệ thống cùng tên đã bị gỡ. Đổi tên để dùng tiếp — chỉ đổi biểu tượng '
                'hay từ khoá thì vẫn tạm ngừng.',
                style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.khoaNgungChu),
              ),
            ),
          ],
        ),
      );
}
