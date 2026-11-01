import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/nha_cua_toi.dart';
import '../../data/repositories/nha_repository.dart';
import '../bloc/nha_cubit.dart';
import '../widgets/gac_vai_chu.dart';
import '../widgets/hop_xac_nhan_nha.dart';
import '../widgets/nha_minh/danh_sach_thanh_vien.dart';
import '../widgets/nha_minh/khung_the_nha.dart';
import '../widgets/quan_ly_thanh_vien/the_thanh_vien_quan_ly.dart';

/// Màn Quản lý thành viên `/nha/thanh-vien` (spec 5.4, 5.5, 12.2; Stitch `456078e5…`). Nhà `ReadOnly` vẫn đổi vai / chuyển chủ /
/// giải tán được (spec 12.3), nên chỉ khoá khi một thao tác đang chạy.
class QuanLyThanhVienPage extends StatefulWidget {
  const QuanLyThanhVienPage({super.key, this.repo});

  /// `null` → `sl<NhaRepository>()`.
  final NhaRepository? repo;

  @override
  State<QuanLyThanhVienPage> createState() => _QuanLyThanhVienPageState();
}

class _QuanLyThanhVienPageState extends State<QuanLyThanhVienPage> {
  late final NhaCubit _cubit;
  StreamSubscription<String>? _subBao;

  /// Chuyển chủ / giải tán do chính màn này: `GacVaiChu` đứng yên, màn tự về một lần.
  bool _tuThaoTac = false;

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

  Future<void> _lamRoiVe(Future<bool> Function() viec) async {
    _tuThaoTac = true;
    final xong = await viec();
    // Thành công thì GIỮ cờ: state "mất vai" tới BlocListener sau `await` vài microtask và màn còn sống suốt hiệu ứng pop.
    // Hạ cờ ở đây là GacVaiChu pop lần hai, `canPop` false → `go('/nha')` thay cả stack.
    if (xong && mounted) {
      roiVeNhaMinh(context);
      return;
    }
    // Mất vai trong lúc thao tác đang bay: `GacVaiChu` chỉ nổ ở cạnh chủ → không-chủ và cạnh ấy đã bị nuốt bởi cờ — xét lại.
    // GIỮ cờ khi tự về: callback của BlocListener có thể còn nằm trong hàng microtask, hạ cờ trước là pop lần hai (I1).
    if (mounted && !laChuNha(_cubit.state)) {
      baoMatVaiRoiVe(context, _cubit);
      return;
    }
    _tuThaoTac = false;
  }

  Future<void> _chuyenChu(ThanhVienNhaEntity tv) async {
    if (!await hoiChuyenChu(context, tv.tenHienThi) || !mounted) return;
    await _lamRoiVe(() => _cubit.chuyenChu(tv.idaccount));
  }

  Future<void> _moiRa(ThanhVienNhaEntity tv) async {
    if (!await hoiMoiRa(context, tv.tenHienThi) || !mounted) return;
    await _cubit.moiRa(tv.idaccount);
  }

  Future<void> _giaiTan(String ten) async {
    if (!await hoiGiaiTan(context, ten) || !mounted) return;
    await _lamRoiVe(_cubit.giaiTan);
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
        value: _cubit,
        child: GacVaiChu(
          dangTuThaoTac: () => _tuThaoTac,
          child: Scaffold(
            appBar: AppBar(title: const Text('Quản lý thành viên')),
            body: SafeArea(
              child: BlocBuilder<NhaCubit, NhaState>(
                builder: (context, s) {
                  final nha = s.nha.nha;
                  if (nha == null) return const SizedBox.shrink();
                  final chu = Theme.of(context).textTheme;
                  final toi = _cubit.idToi;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('${s.nha.thanhVien.length}/${nha.toiDaThanhVien} thành viên',
                          style: chu.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      for (final tv in s.nha.thanhVien) ...[
                        if (tv.idaccount == toi)
                          KhungTheNha(
                            child: Row(
                              children: [
                                AvatarChuCai(ten: tv.tenHienThi, co: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TenThanhVien(ten: tv.tenHienThi, laToi: true),
                                      if (tv.vaoLuc != null) NgayVaoNha(vao: tv.vaoLuc!),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                NhanVai(vai: tv.vai),
                              ],
                            ),
                          )
                        else
                          TheThanhVienQuanLy(
                            tv: tv,
                            khoa: s.dangXuLy,
                            onDoiVai: (v) => unawaited(_cubit.doiVai(tv.idaccount, v)),
                            onChuyenChu: () => unawaited(_chuyenChu(tv)),
                            onMoiRa: () => unawaited(_moiRa(tv)),
                          ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 8),
                      KhungTheNha(
                        vien: AppColors.errorContainer,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.error),
                                const SizedBox(width: 8),
                                Text('VÙNG NGUY HIỂM',
                                    style: chu.labelMedium?.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text('Quỹ chung, sổ chung và danh mục của nhà sẽ biến mất với mọi người.'),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              // Khoá thì viền xám như chữ (Material tự đổi `foregroundColor`, còn `side` đặt cứng thì không).
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error).copyWith(
                                side: WidgetStateProperty.resolveWith((st) => BorderSide(
                                    color: st.contains(WidgetState.disabled) ? AppColors.outlineVariant : AppColors.error)),
                              ),
                              onPressed: s.dangXuLy ? null : () => unawaited(_giaiTan(nha.ten)),
                              icon: const Icon(Icons.delete_forever_outlined),
                              label: const Text('Giải tán nhà'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
}
