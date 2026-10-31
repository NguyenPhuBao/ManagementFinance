import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';
import '../../../premium/presentation/bloc/co_quyen.dart';
import '../../data/repositories/nha_repository.dart';
import '../../domain/quyen_nha.dart';
import '../../domain/vai_nha.dart';
import '../bloc/nha_cubit.dart';
import '../widgets/hop_xac_nhan_nha.dart';
import '../widgets/nha_minh/danh_sach_thanh_vien.dart';
import '../widgets/nha_minh/khoi_chua_co_nha.dart';
import '../widgets/nha_minh/the_nha.dart';
import '../widgets/the_loi_moi_dang_cho.dart';

/// Trang Nhà mình `/nha` (spec 12.3; Stitch `56739d19…`, `e462a7e8…`, `e3306197…`). Không có ô chờ cho phần 2a–3: nút không làm
/// gì trái quét 10. Dữ liệu nhà tải ngầm sau khi vào nhà, không có màn chờ.
class NhaMinhPage extends StatefulWidget {
  const NhaMinhPage({super.key, this.repo});

  /// `null` → `sl<NhaRepository>()`.
  final NhaRepository? repo;

  @override
  State<NhaMinhPage> createState() => _NhaMinhPageState();
}

class _NhaMinhPageState extends State<NhaMinhPage> {
  late final NhaCubit _cubit;
  StreamSubscription<String>? _subBao;

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

  Future<void> _roiNha() async {
    if (await hoiRoiNha(context)) await _cubit.roiNha();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
        value: _cubit,
        child: Scaffold(
          appBar: AppBar(title: const Text('Nhà mình')),
          body: SafeArea(
            child: BlocBuilder<NhaCubit, NhaState>(
              builder: (context, s) {
                if (!s.daNap) return const Center(child: CircularProgressIndicator());
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: s.nha.coNha ? _thanCoNha(s) : _thanChuaCoNha(s),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: s.nha.coNha ? _nutCoNha(s) : _nutChuaCoNha(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

  List<Widget> _theLoiMoi(NhaState s) => [
        for (final m in s.loiMoi) ...[
          TheLoiMoiDangCho(
            loiMoi: m,
            dangONha: s.nha.coNha,
            laChu: s.nha.vai == VaiNha.chu,
            duocThamGia: context.coQuyen(MaQuyen.thamGiaNha),
            dangXuLy: s.dangXuLy,
            onChapNhan: () => unawaited(_cubit.chapNhan(m.ma)),
            onTuChoi: () => unawaited(_cubit.tuChoi(m.ma)),
          ),
          const SizedBox(height: 16),
        ],
      ];

  List<Widget> _thanChuaCoNha(NhaState s) => [..._theLoiMoi(s), const KhoiChuaCoNha()];

  List<Widget> _thanCoNha(NhaState s) => [
        if (s.nha.nha!.trangThai == TrangThaiNha.chiXem) ...[const DaiNhaChiXem(), const SizedBox(height: 16)],
        TheNha(trangThai: s.nha),
        const SizedBox(height: 16),
        ..._theLoiMoi(s),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('THÀNH VIÊN',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
        DanhSachThanhVien(thanhVien: s.nha.thanhVien, idToi: _cubit.idToi),
      ];

  Widget _nutChuaCoNha() {
    final canPremium = context.trangThaiQuyen(MaQuyen.giaDinh) == TrangThaiQuyen.canPremium;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: () => context.push('/nha/tao'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Tạo nhà'),
              if (canPremium) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.khoaNenVang, borderRadius: BorderRadius.circular(999)),
                  child: Text('PREMIUM',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.khoaCanChu, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => context.push('/nha/tham-gia'), child: const Text('Tham gia bằng mã')),
      ],
    );
  }

  Widget _nutCoNha(NhaState s) {
    final t = s.nha;
    if (duocLamViecNha(ViecNha.roiNha, vai: t.vai, trangThai: t.nha?.trangThai)) {
      return TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: AppColors.error),
        onPressed: s.dangXuLy ? null : () => unawaited(_roiNha()),
        icon: const Icon(Icons.logout),
        label: const Text('Rời nhà'),
      );
    }
    final moiDuoc = duocLamViecNha(ViecNha.taoMa, vai: t.vai, trangThai: t.nha?.trangThai);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: moiDuoc ? () => context.push('/nha/moi') : null,
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Mời thành viên'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => context.push('/nha/thanh-vien'), child: const Text('Quản lý thành viên')),
      ],
    );
  }
}
