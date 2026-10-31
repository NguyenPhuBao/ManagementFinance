import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';
import '../../../premium/presentation/bloc/co_quyen.dart';
import '../../data/repositories/nha_repository.dart';
import '../../domain/cau_loi_nha.dart';
import '../../domain/moi_thanh_vien.dart';
import '../../domain/vai_nha.dart';
import '../bloc/nha_cubit.dart';
import '../widgets/nha_minh/khung_the_nha.dart';

/// Màn Tạo nhà `/nha/tao` (spec 5.1, 12.2; Stitch `411a20c1…`). Basic và Premium tạm ngừng bị cửa route chặn trước khi tới đây.
class TaoNhaPage extends StatefulWidget {
  const TaoNhaPage({super.key, this.repo});

  /// `null` → `sl<NhaRepository>()`.
  final NhaRepository? repo;

  @override
  State<TaoNhaPage> createState() => _TaoNhaPageState();
}

class _TaoNhaPageState extends State<TaoNhaPage> {
  final _ten = TextEditingController();
  late final NhaCubit _cubit;
  StreamSubscription<String>? _subBao;

  @override
  void initState() {
    super.initState();
    _cubit = NhaCubit(widget.repo ?? sl<NhaRepository>());
    _subBao = _cubit.canBao.listen((c) => baoNhanh(c, loai: LoaiThongBao.loi));
  }

  @override
  void dispose() {
    _ten.dispose();
    unawaited(_subBao?.cancel());
    unawaited(_cubit.close());
    super.dispose();
  }

  Future<void> _tao() async {
    final cau = cauTaoNhaBiTat(context.trangThaiQuyenDoc(MaQuyen.giaDinh));
    final xong = await _cubit.taoNha(_ten.text.trim(), cauKhiTatQuyen: cau);
    if (xong && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final mo = tenNhaHopLe(_ten.text) && !_cubit.state.dangXuLy;
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo nhà')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Tên nhà', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ten,
                    inputFormatters: const [GioiHanDoRong(DoRongCot.tenNha)],
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  const KhungTheNha(
                    child: Column(
                      children: [
                        _DongGhiChu(icon: Icons.stars_outlined, chu: 'Bạn sẽ là Chủ nhà'),
                        Divider(height: 24),
                        _DongGhiChu(
                            icon: Icons.groups_outlined, chu: 'Nhà có tối đa $kToiDaThanhVienMacDinh thành viên'),
                        Divider(height: 24),
                        _DongGhiChu(icon: Icons.wifi, chu: 'Cần có mạng để tạo nhà'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: mo ? () => unawaited(_tao().then((_) => mounted ? setState(() {}) : null)) : null,
                  child: const Text('Tạo nhà'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DongGhiChu extends StatelessWidget {
  const _DongGhiChu({required this.icon, required this.chu});

  final IconData icon;
  final String chu;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(child: Text(chu)),
        ],
      );
}
