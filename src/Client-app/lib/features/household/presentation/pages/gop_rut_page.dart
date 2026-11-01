import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/bao_che_day_toast.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/current_account.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';
import '../../../premium/presentation/bloc/co_quyen.dart';
import '../../../transaction/domain/ban_phim_so_tien.dart';
import '../../../transaction/presentation/widgets/them_giao_dich/ban_phim_so.dart';
import '../../../transaction/presentation/widgets/them_giao_dich/bang_chon_vi.dart';
import '../../../transaction/presentation/widgets/them_giao_dich/khoi_so_tien.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../../wallet/data/repositories/wallet_repository.dart';
import '../../application/gop_quy_service.dart';
import '../../data/repositories/du_lieu_nha_repository.dart';
import '../../data/repositories/nha_repository.dart';
import '../../domain/hoat_dong_nha.dart';
import '../../domain/quyen_nha.dart';
import '../bloc/gop_rut_cubit.dart';
import '../widgets/gop_rut/dong_form_gop_rut.dart';

const _cauKhongQuyen = 'Bạn không còn quyền ghi khoản trong nhà này.';

/// Hai cặp màu ô biểu tượng của Stitch: Góp `f77f5bc0…` 5.3, Rút `c39ac4f7…` 10.3.
const _mauChungGop = (nen: Color(0xFFECFDF5), chu: Color(0xFF059669));
const _mauRiengGop = (nen: Color(0xFFF0F4FF), chu: Color(0xFF2563EB));
const _mauChungRut = (nen: Color(0xFFE8F5E9), chu: Color(0xFF2E7D32));
const _mauRiengRut = (nen: Color(0xFFE3F2FD), chu: Color(0xFF1976D2));

/// Góp vào quỹ / Rút về ví riêng `/nha/gop?vi=&che=gop|rut&ma=` (đợt 1B Task 8; `docs/Family/02A` mục 5). Có `ma` là sửa một cặp.
///
/// - Quyền ghi kiểm LẠI ngay đầu lúc lưu (vai hay nhà có thể đổi sau lúc mở): sai thì không ghi, báo và đóng — nửa của nhà mà
///   server từ chối sau đó để quỹ đã nhận tiền, còn nửa riêng đã trừ ví.
/// - `idaccount` chỉ từ phiên (`AuthBloc`), không phiên thì không ghi.
/// - Bàn phím số tự vẽ như form Thêm giao dịch: 16 phím ẩn khi bàn phím hệ thống mở (G58) hoặc khi đã có số tiền, lúc ấy ✓ lên
///   thanh tiêu đề.
class GopRutPage extends StatefulWidget {
  const GopRutPage({
    super.key,
    required this.cheDo,
    this.viChungId,
    this.maCap,
    this.nha,
    this.duLieu,
    this.gopQuy,
    this.napViRieng,
    this.dongHo,
  });

  final CheDoQuy cheDo;
  final String? viChungId;
  final String? maCap;

  /// Các tham số `null` → `sl<…>()`.
  final NhaRepository? nha;
  final DuLieuNhaRepository? duLieu;
  final GopQuyService? gopQuy;

  /// Danh sách ví riêng đang hoạt động của tài khoản; `null` → `WalletRepository.getActive`.
  final Future<List<WalletEntity>> Function()? napViRieng;

  /// Đồng hồ tiêm được cho nhãn *Hôm nay* và ngày mặc định; `null` → giờ máy.
  final DateTime Function()? dongHo;

  @override
  State<GopRutPage> createState() => _GopRutPageState();
}

class _GopRutPageState extends State<GopRutPage> {
  GopRutCubit? _cubit;
  int? _idNha;
  bool _daDong = false;
  final _ghiChu = TextEditingController();

  NhaRepository get _nhaRepo => widget.nha ?? sl<NhaRepository>();
  DateTime get _bayGio => (widget.dongHo ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final t = _nhaRepo.hienTai;
    final nha = t.nha;
    if (nha == null || !duocLamViecNha(ViecNha.ghiKhoan, vai: t.vai, trangThai: nha.trangThai)) {
      // Sau khung đầu: `_dong` gọi `pop`, không được gọi trong lúc dựng.
      WidgetsBinding.instance.addPostFrameCallback((_) => _dong(_cauKhongQuyen));
      return;
    }
    _idNha = nha.id;
    // Quy tắc 2: idaccount chỉ từ phiên; đọc lại mỗi lần cần (đăng xuất giữa chừng thì không ghi).
    final auth = context.read<AuthBloc>();
    int? taiKhoan() => idaccountTuTrangThai(auth.state);
    final cubit = GopRutCubit(
      gopQuy: widget.gopQuy ?? sl<GopQuyService>(),
      duLieu: widget.duLieu ?? sl<DuLieuNhaRepository>(),
      napViRieng: widget.napViRieng ?? () => _napViRiengCuaPhien(taiKhoan()),
      idNha: nha.id,
      taiKhoan: taiKhoan,
      cheDo: widget.cheDo,
      viChungId: widget.viChungId,
      maCap: widget.maCap,
      bayGio: widget.dongHo,
    );
    _cubit = cubit;
    unawaited(cubit.moTrang());
  }

  /// Một dòng cho quét 2 (`wallet_picker_sources_test`): đây là BỘ CHỌN ví nên chỉ ví đang hoạt động.
  Future<List<WalletEntity>> _napViRiengCuaPhien(int? idaccount) =>
      idaccount == null ? Future.value(const <WalletEntity>[]) : sl<WalletRepository>().getActive(idaccount);

  @override
  void dispose() {
    _ghiChu.dispose();
    unawaited(_cubit?.close());
    super.dispose();
  }

  /// Báo rồi đóng; chỉ một lần dù được gọi nhiều chỗ.
  void _dong(String cau) {
    if (_daDong) return;
    _daDong = true;
    baoNhanh(cau, loai: LoaiThongBao.loi);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/nha');
    }
  }

  /// Đọc lại vai và nhà NGAY trước khi ghi.
  bool _conDuocGhi() {
    final t = _nhaRepo.hienTai;
    final nha = t.nha;
    final duoc = nha != null && nha.id == _idNha && duocLamViecNha(ViecNha.ghiKhoan, vai: t.vai, trangThai: nha.trangThai);
    if (!duoc) _dong(_cauKhongQuyen);
    return duoc;
  }

  Future<void> _luu(GopRutCubit cubit) async {
    if (cubit.state.dangLuu || !_conDuocGhi()) return;
    final cheDo = cubit.state.cheDo;
    final dangSua = cubit.state.dangSua;
    final cau = await cubit.luu();
    if (!mounted) return;
    if (cau != null) {
      // Khoản đã mất: lắng nghe `cauDong` đã báo và đóng, đừng báo hai lần.
      if (cubit.state.cauDong == null) baoNhanh(cau, loai: LoaiThongBao.loi);
      return;
    }
    baoNhanh(dangSua ? 'Đã sửa khoản.' : (cheDo == CheDoQuy.gop ? 'Đã góp vào quỹ.' : 'Đã rút về ví riêng.'));
    context.pop(true);
  }

  Future<void> _chonNgay(GopRutCubit cubit) async {
    final hien = cubit.state.ngay;
    final p = await showDatePicker(context: context, initialDate: hien, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (p == null) return;
    // Giữ giờ của khoản: chỉ đổi ngày, không đưa khoản về 00:00.
    cubit.chonNgay(DateTime(p.year, p.month, p.day, hien.hour, hien.minute, hien.second));
  }

  String _chuHienThi(String chuoi) =>
      coToanTu(chuoi) ? nhanBieuThuc(chuoi) : CurrencyFormatter.format(double.tryParse(chuoi) ?? 0);

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) return Scaffold(appBar: AppBar());
    return BlocProvider.value(
      value: cubit,
      child: MultiBlocListener(
        listeners: [
          BlocListener<GopRutCubit, GopRutState>(
            listenWhen: (a, b) => a.cauDong == null && b.cauDong != null,
            listener: (_, s) => _dong(s.cauDong!),
          ),
          // Chữ ghi chú của khoản đang sửa vào ô một lần, lúc nạp xong; sau đó ô là nguồn (cubit chỉ nghe).
          BlocListener<GopRutCubit, GopRutState>(
            listenWhen: (a, b) => !a.daNap && b.daNap,
            listener: (_, s) => _ghiChu.text = s.ghiChu,
          ),
        ],
        child: BlocBuilder<GopRutCubit, GopRutState>(builder: (context, s) => _khung(context, cubit, s)),
      ),
    );
  }

  Widget _khung(BuildContext context, GopRutCubit cubit, GopRutState s) {
    final gop = s.cheDo == CheDoQuy.gop;
    final coBanPhim = s.hienBanPhimSo && MediaQuery.viewInsetsOf(context).bottom == 0;
    final tieuDe = s.dangSua ? (gop ? 'Sửa khoản góp' : 'Sửa khoản rút') : (gop ? 'Góp vào quỹ' : 'Rút về ví riêng');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/nha'),
        ),
        title: Text(tieuDe, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          // MỘT luật cho nút lưu (G58): 16 phím (mang phím ✓) không trên màn thì ✓ ở thanh tiêu đề.
          if (!coBanPhim)
            IconButton(
              key: const Key('luu-thanh-tieu-de'),
              tooltip: 'Lưu',
              icon: const Icon(Icons.check),
              onPressed: s.dangLuu || !s.daNap ? null : () => unawaited(_luu(cubit)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            KhoiSoTien(
              chuoiSoTien: s.chuoiSoTien,
              chuHienThi: _chuHienThi(s.chuoiSoTien),
              mau: AppColors.primary,
              hienBanPhimSo: s.hienBanPhimSo,
              onCham: () {
                final heThong = MediaQuery.viewInsetsOf(context).bottom > 0;
                if (heThong) FocusScope.of(context).unfocus();
                cubit.chamSoTien(banPhimHeThongMo: heThong);
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: s.daNap ? _the(context, cubit, s, gop) : const SizedBox.shrink(),
              ),
            ),
            if (coBanPhim)
              BaoCheDayToast(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: BanPhimSo(
                    isSubmitting: s.dangLuu,
                    onKey: cubit.goPhim,
                    onLuu: () => unawaited(_luu(cubit)),
                    choPhepTinh: context.coQuyen(MaQuyen.inAppCalculator),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _the(BuildContext context, GopRutCubit cubit, GopRutState s, bool gop) {
    final chu = Theme.of(context).textTheme;
    final khoa = s.dangSua;
    final mauChung = gop ? _mauChungGop : _mauChungRut;
    final mauRieng = gop ? _mauRiengGop : _mauRiengRut;
    final chung = s.chonChung;
    final rieng = s.chonRieng;
    final hang = <Widget>[
      DongFormGopRut(
        key: const Key('dong-vi-chung'),
        icon: Icons.account_balance_wallet_outlined,
        mau: mauChung,
        nhan: gop ? 'Vào ví chung' : 'Từ ví chung',
        // Góp: Stitch chỉ in tên quỹ; Rút: tên · số dư (quỹ là nguồn nên số dư quyết định rút được bao nhiêu).
        giaTri: GiaTriVi(ten: chung?.name ?? 'Chọn ví chung', soDu: gop || chung == null ? null : CurrencyFormatter.format(chung.balance)),
        chevron: !khoa,
        onCham: khoa
            ? null
            : () => moBangChonVi(context,
                isDestination: gop, wallets: s.viChung, idDangChon: chung?.id, onChon: cubit.chonChung),
      ),
      if (!s.tienMat)
        DongFormGopRut(
          key: const Key('dong-vi-rieng'),
          icon: Icons.account_balance_outlined,
          mau: mauRieng,
          nhan: gop ? 'Từ ví riêng' : 'Về ví riêng',
          giaTri: GiaTriVi(
            ten: rieng?.name ?? (khoa ? 'Ví riêng' : 'Chọn ví riêng'),
            soDu: rieng == null ? null : CurrencyFormatter.format(rieng.balance),
          ),
          chevron: !khoa,
          onCham: khoa
              ? null
              : () => moBangChonVi(context,
                  isDestination: !gop, wallets: s.viRieng, idDangChon: rieng?.id, onChon: cubit.chonRieng),
        ),
      // Tiền mặt trao tay: chỉ khi góp và chỉ lúc tạo — sửa không đổi được ví nào của cặp.
      if (gop && !khoa)
        DongFormGopRut(
          key: const Key('dong-tien-mat'),
          icon: Icons.payments_outlined,
          nhan: 'Tiền mặt trao tay',
          nen: AppColors.surfaceContainerLow,
          giaTri: Text('Không trừ ví nào của bạn', style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
          onCham: () => cubit.datTienMat(!s.tienMat),
          cuoi: Switch(
            value: s.tienMat,
            onChanged: cubit.datTienMat,
            activeTrackColor: AppColors.primary,
            activeThumbColor: AppColors.onPrimary,
          ),
        ),
      DongFormGopRut(
        key: const Key('dong-ngay'),
        icon: Icons.calendar_today_outlined,
        nhan: 'Ngày',
        giaTri: Text(nhanNhomNgay(s.ngay, _bayGio), style: chu.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        chevron: true,
        onCham: () => unawaited(_chonNgay(cubit)),
      ),
      DongFormGopRut(
        icon: Icons.notes,
        nhan: 'Ghi chú',
        giaTri: TextField(
          key: const Key('o-ghi-chu'),
          controller: _ghiChu,
          onChanged: cubit.ghiChuDoi,
          maxLines: 1,
          style: chu.bodyMedium,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: 'Thêm ghi chú',
          ),
        ),
      ),
    ];
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < hang.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.surfaceContainerLow),
                hang[i],
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.info_outline, size: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_chuThich(s, gop), style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ],
    );
  }

  String _chuThich(GopRutState s, bool gop) {
    if (!gop) return 'Số tiền được trừ khỏi quỹ và cộng vào ví riêng của bạn.';
    return s.tienMat
        ? 'Số tiền được cộng vào quỹ, không trừ ví nào của bạn.'
        : 'Số tiền được trừ khỏi ví riêng của bạn và cộng vào quỹ.';
  }
}
