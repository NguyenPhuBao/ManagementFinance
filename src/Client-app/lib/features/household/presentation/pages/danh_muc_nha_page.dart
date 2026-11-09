import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../category/data/models/category_entity.dart';
import '../../../category/data/models/category_tree.dart';
import '../../../category/domain/category_classify.dart';
import '../../../category/presentation/widgets/category_visuals.dart';
import '../../data/repositories/du_lieu_nha_repository.dart';
import '../../data/repositories/nha_repository.dart';
import '../../domain/quyen_nha.dart';
import '../bloc/nha_cubit.dart';
import '../widgets/gac_vai_chu.dart';

const _mauChuPhu = Color(0xFF454743);

/// Màn Danh mục của nhà `/nha/danh-muc` (đợt 1B Task 11; Stitch 8A `6dc96c4a`). Mọi vai có mặt trong nhà xem được; thêm / sửa
/// theo `ViecNha.suaDanhMuc` (Chủ, Thành viên, nhà đang hoạt động). Không có xoá ở 1B (spec quyết định #4), không từ khoá.
///
/// Khác Stitch (đã chốt): ba tab theo `kCategoryClassifies` (server sao cả danh mục vay / nợ vào nhà), không chân trang
/// "Chế độ gia đình · Đồng bộ thời gian thực", không thanh Home giả. Nhóm hiện như dòng tiêu đề, chưa có form nhóm nhà.
class DanhMucNhaPage extends StatefulWidget {
  const DanhMucNhaPage({super.key, this.repo, this.duLieu});

  /// `null` → `sl<…>()`, chỉ chạm khi cần.
  final NhaRepository? repo;
  final DuLieuNhaRepository? duLieu;

  @override
  State<DanhMucNhaPage> createState() => _DanhMucNhaPageState();
}

class _DanhMucNhaPageState extends State<DanhMucNhaPage> {
  late final NhaCubit _cubit;
  StreamSubscription<String>? _subBao;
  String _classify = kCategoryClassifies.first;

  /// Luồng cây của (nhà, phân loại) đang xem: giữ MỘT thể hiện giữa các lần dựng, nếu không `StreamBuilder` đăng ký lại mỗi
  /// lần build và nhấp nháy.
  (int, String)? _khoaLuong;
  Stream<CategoryTree>? _luong;

  DuLieuNhaRepository get _duLieu => widget.duLieu ?? sl<DuLieuNhaRepository>();

  @override
  void initState() {
    super.initState();
    _cubit = NhaCubit(widget.repo ?? sl<NhaRepository>());
    _subBao = _cubit.canBao.listen((c) => baoNhanh(c, loai: LoaiThongBao.loi));
    unawaited(_cubit.moTrang());
  }

  @override
  void dispose() {
    unawaited(_subBao?.cancel());
    unawaited(_cubit.close());
    super.dispose();
  }

  Stream<CategoryTree> _luongCho(int idNha) {
    final khoa = (idNha, _classify);
    if (_khoaLuong != khoa || _luong == null) {
      _khoaLuong = khoa;
      _luong = _duLieu.theoDoiCayDanhMuc(idNha, _classify);
    }
    return _luong!;
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<NhaCubit, NhaState>(
        bloc: _cubit,
        // Nhà mất lúc màn đang mở (giải tán, bị mời ra qua socket): báo rồi về Nhà mình.
        listenWhen: (a, b) => a.nha.coNha && !b.nha.coNha,
        listener: (ctx, s) => baoMatVaiRoiVe(ctx, _cubit),
        builder: (context, s) {
          final nha = s.nha.nha;
          final duocSua =
              duocLamViecNha(ViecNha.suaDanhMuc, vai: s.nha.vai, trangThai: nha?.trangThai);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Danh mục của nhà'),
              centerTitle: true,
              actions: [
                if (duocSua)
                  IconButton(
                    tooltip: 'Thêm danh mục',
                    icon: const Icon(Icons.add),
                    onPressed: () => unawaited(context.push('/nha/danh-muc/them')),
                  ),
              ],
            ),
            body: SafeArea(
              child: !s.daNap
                  ? const Center(child: CircularProgressIndicator())
                  : nha == null
                      ? const SizedBox.shrink()
                      : _noiDung(context, nha.id, duocSua),
            ),
          );
        },
      );

  Widget _noiDung(BuildContext context, int idNha, bool duocSua) {
    final chu = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _Tab(
          dang: _classify,
          onChon: (c) => setState(() => _classify = c),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16, color: _mauChuPhu),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Danh mục dùng chung cho cả nhà, không lẫn với danh mục cá nhân của bạn.',
                    style: chu.bodySmall?.copyWith(color: _mauChuPhu)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<CategoryTree>(
          stream: _luongCho(idNha),
          builder: (context, snap) {
            final cay = snap.data;
            if (cay == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final dong = _phangHoa(cay);
            if (dong.every((d) => d.laNhom)) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('Chưa có danh mục nào.',
                      style: chu.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                ),
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < dong.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.outlineVariant),
                    dong[i].laNhom
                        ? _TieuDeNhom(ten: dong[i].hang.name)
                        : _DongDanhMuc(
                            hang: dong[i].hang,
                            onCham: duocSua
                                ? () => unawaited(context.push('/nha/danh-muc/${dong[i].hang.id}/sua'))
                                : null,
                          ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Một dòng của danh sách phẳng: tiêu đề nhóm hoặc một danh mục con.
class _Muc {
  const _Muc(this.hang, {required this.laNhom});
  final CategoryEntity hang;
  final bool laNhom;
}

/// Nhóm (kèm con, nhóm không con bị bỏ) rồi các danh mục chưa vào nhóm. Khuôn mặc định / đang tạm ngừng không có ở nhà.
List<_Muc> _phangHoa(CategoryTree cay) => [
      for (final n in cay.groups)
        if (n.children.isNotEmpty) ...[
          _Muc(n.group, laNhom: true),
          for (final c in n.children) _Muc(c, laNhom: false),
        ],
      for (final c in cay.ungroupedChildren) _Muc(c, laNhom: false),
    ];

class _Tab extends StatelessWidget {
  const _Tab({required this.dang, required this.onChon});

  final String dang;
  final ValueChanged<String> onChon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            for (final c in kCategoryClassifies)
              Expanded(
                child: InkWell(
                  key: Key('tab-$c'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    if (c != dang) onChon(c);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c == dang ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      categoryClassifyLabel(c),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c == dang ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _TieuDeNhom extends StatelessWidget {
  const _TieuDeNhom({required this.ten});

  final String ten;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(ten,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}

class _DongDanhMuc extends StatelessWidget {
  const _DongDanhMuc({required this.hang, required this.onCham});

  final CategoryEntity hang;

  /// `null` = chỉ xem: không chevron, không phản ứng khi chạm.
  final VoidCallback? onCham;

  @override
  Widget build(BuildContext context) {
    final mau = categoryColorFrom(hang.colour);
    final noiDung = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: mau.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(categoryIconFor(hang.icon), size: 20, color: mau),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(hang.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (onCham != null) const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
        ],
      ),
    );
    if (onCham == null) return KeyedSubtree(key: Key('muc-${hang.id}'), child: noiDung);
    return InkWell(key: Key('muc-${hang.id}'), onTap: onCham, child: noiDung);
  }
}
