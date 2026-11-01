import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../auth/presentation/bloc/current_account.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';
import '../../../premium/presentation/bloc/co_quyen.dart';
import '../../data/repositories/du_lieu_nha_repository.dart';
import '../../data/repositories/nha_repository.dart';
import '../../domain/quyen_nha.dart';
import '../../domain/vai_nha.dart';
import '../bloc/nha_cubit.dart';
import '../bloc/vi_chung_cubit.dart';
import '../widgets/hoi_hang_chua_day.dart';
import '../widgets/hop_xac_nhan_nha.dart';
import '../widgets/nha_minh/danh_sach_thanh_vien.dart';
import '../widgets/nha_minh/khoi_chua_co_nha.dart';
import '../widgets/nha_minh/khoi_vi_chung.dart';
import '../widgets/nha_minh/the_nha.dart';
import '../widgets/the_loi_moi_dang_cho.dart';

/// Trang Nhà mình `/nha` (spec 12.3; Stitch `56739d19…`, `e462a7e8…`, `e3306197…`). Không có ô chờ cho phần 2a–3: nút không làm
/// gì trái quét 10. Dữ liệu nhà tải ngầm sau khi vào nhà, không có màn chờ.
class NhaMinhPage extends StatefulWidget {
  const NhaMinhPage({super.key, this.repo, this.duLieu});

  /// `null` → `sl<NhaRepository>()`.
  final NhaRepository? repo;

  /// Nguồn đếm hàng chưa đẩy cho hộp Rời nhà; `null` → `sl<DuLieuNhaRepository>()`, chỉ chạm khi cần hỏi.
  final DuLieuNhaRepository? duLieu;

  @override
  State<NhaMinhPage> createState() => _NhaMinhPageState();
}

class _NhaMinhPageState extends State<NhaMinhPage> {
  late final NhaCubit _cubit;
  StreamSubscription<String>? _subBao;

  /// Ví chung của nhà HIỆN TẠI, giữ ở trang chứ không ở dòng danh sách: `ListView` bỏ dòng ra khỏi khung là đóng cubit, kéo
  /// lại thì khối thành rỗng một nhịp rồi nhảy. Nhà đổi id (vào nhà khác, giải tán) thì dựng cái mới.
  ViChungCubit? _viChung;

  @override
  void initState() {
    super.initState();
    _cubit = NhaCubit(widget.repo ?? sl<NhaRepository>());
    _subBao = _cubit.canBao.listen((c) => baoNhanh(c, loai: LoaiThongBao.loi));
    _dongBoViChung(_cubit.state);
    unawaited(_cubit.moTrang());
  }

  @override
  void dispose() {
    unawaited(_subBao?.cancel());
    unawaited(_cubit.close());
    unawaited(_viChung?.close());
    super.dispose();
  }

  /// Nguồn đọc ví chung: tiêm được, không thì `sl` — nhưng chỉ khi đã đăng ký (test cũ của trang này không dựng DI; không có
  /// nguồn thì không có khối, trang vẫn dùng được).
  DuLieuNhaRepository? _nguonDuLieu() =>
      widget.duLieu ?? (sl.isRegistered<DuLieuNhaRepository>() ? sl<DuLieuNhaRepository>() : null);

  void _dongBoViChung(NhaState s) {
    final id = s.nha.coNha ? s.nha.nha!.id : null;
    if (id == _viChung?.idNha) return;
    unawaited(_viChung?.close());
    _viChung = null;
    final nguon = _nguonDuLieu();
    if (id != null && nguon != null) _viChung = ViChungCubit(nguon, id);
  }

  Future<void> _roiNha() async {
    // Quy tắc 2: idaccount chỉ từ phiên, đọc TRƯỚC mọi `await` (dùng `context` qua await là sai). `null` = chưa có phiên.
    final idaccount = currentAccountIdOrNull(context);
    final nhaId = _cubit.state.nha.nha?.id;
    if (!await hoiRoiNha(context) || !mounted || nhaId == null) return;
    await lamCoHoiHangChuaDay(
      context,
      cubit: _cubit,
      viec: _cubit.roiNha,
      // `sl` chỉ chạm ở đây (lúc cần hỏi): trang dựng không cần DI.
      moTa: () => (widget.duLieu ?? sl<DuLieuNhaRepository>()).hangChuaDay(nhaId, idaccount: idaccount),
      nhanLam: 'Vẫn rời nhà',
    );
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
        value: _cubit,
        child: Scaffold(
          appBar: AppBar(title: const Text('Nhà mình')),
          body: SafeArea(
            child: BlocListener<NhaCubit, NhaState>(
              listener: (_, s) => setState(() => _dongBoViChung(s)),
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
        ..._khoiViChung(s),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('THÀNH VIÊN',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
        DanhSachThanhVien(thanhVien: s.nha.thanhVien, idToi: _cubit.idToi),
      ];

  /// Khối VÍ CHUNG (1B Task 5). Chưa có nguồn hay chưa nạp xong thì không dựng: nói "Chưa có ví chung nào" khi chưa biết là sai.
  /// Nút Tạo chỉ cho người quản lý được ví chung; ví lưu trữ không chiếm trần.
  List<Widget> _khoiViChung(NhaState s) {
    final vc = _viChung;
    if (vc == null) return const [];
    final nha = s.nha.nha!;
    final quanLy = duocLamViecNha(ViecNha.quanLyViChung, vai: s.nha.vai, trangThai: nha.trangThai);
    return [
      BlocBuilder<ViChungCubit, ViChungState>(
        bloc: vc,
        builder: (context, v) {
          if (!v.daNap) return const SizedBox.shrink();
          return KhoiViChung(
            vi: v.vi,
            tongQuy: vc.tongQuy,
            coTheTao: conTaoDuocViChung(vc.soDangHoatDong, nha.toiDaViChung),
            lyDoKhoa: 'Nhà đã có đủ ${nha.toiDaViChung} ví chung.',
            onTao: quanLy ? () => unawaited(context.push('/nha/vi/tao')) : null,
            // Task 7 truyền `push('/nha/vi/<id>')` cùng lúc thêm route: dòng ví không chạm được tới khi route có thật.
            onChamVi: null,
          );
        },
      ),
      const SizedBox(height: 16),
    ];
  }

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
