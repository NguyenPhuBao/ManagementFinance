import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../../wallet/domain/wallet_status.dart';
import '../../../wallet/domain/wallet_type.dart';
import '../../../wallet/data/repositories/wallet_repository.dart';
import '../../application/gop_quy_service.dart';
import '../../application/thao_tac_khoan_nha.dart';
import '../../data/models/nha_cua_toi.dart';
import '../../data/repositories/du_lieu_nha_repository.dart';
import '../../data/repositories/nha_repository.dart';
import '../../domain/bang_gop.dart';
import '../../domain/hoat_dong_nha.dart';
import '../../domain/loai_khoan_nha.dart';
import '../../domain/muc_tieu_chung.dart';
import '../../domain/quyen_nha.dart';
import '../../domain/vai_nha.dart';
import '../bloc/khoan_nha_cubit.dart';
import '../bloc/nha_cubit.dart';
import '../bloc/vi_chung_cubit.dart';
import '../widgets/bang_gop_view.dart';
import '../widgets/chi_tiet_vi/hang_nut_vi.dart';
import '../widgets/dong_khoan_nha.dart';
import '../widgets/gac_vai_chu.dart';
import '../widgets/khung_the_nha.dart';
import '../widgets/mo_khoan_nha.dart';
import '../widgets/tien_do_muc_tieu.dart';
import '../widgets/tra_ten_nha.dart';

/// Màu của Stitch `ac57e216…` không trùng token nào của `AppColors` (chấm xanh, chữ huy hiệu).
const _xanhCham = Color(0xFF006E1C);
const _chuHuyHieu = Color(0xFF454743);

/// Màn Chi tiết ví chung `/nha/vi/:id` (đợt 1B Task 7; Stitch `ac57e216…` tab Giao dịch, `6d63311f…` tab Bảng góp). Mọi thành viên
/// xem được, kể cả Chỉ xem và nhà chỉ xem: hàng nút và bút sửa theo `duocLamViecNha`. Ví lưu trữ không có hàng nút (đóng băng).
///
/// - Ví bị xoá / không còn trong nhà (máy khác xoá, kéo về) → tự đóng kèm câu; không đoán một ví khác.
/// - Số dư đọc từ `theoDoiViChung` (cột `balance`, cache của sổ), không tính lại ở đây.
/// - Hàng nút nhận danh sách [NutVi]: *Góp · Rút* đứng giữa *Thu* và *Chuyển* theo màn 3 (Task 8).
/// - Chạm dòng giao dịch mở sheet khoản + Sửa / Xoá, y như Hoạt động (`moKhoanNha`).
class ChiTietViChungPage extends StatefulWidget {
  const ChiTietViChungPage(
      {super.key, required this.idVi, this.repo, this.duLieu, this.thaoTac, this.gopQuy, this.viRieng, this.dongHo});

  final String idVi;

  /// Các tham số `null` → `sl<…>()`.
  final NhaRepository? repo;
  final DuLieuNhaRepository? duLieu;

  /// Đồng hồ tiêm được cho nhóm *Hôm nay / Hôm qua* và *tháng này* của Bảng góp; `null` → giờ máy.
  final DateTime Function()? dongHo;

  /// Cho sheet khoản (xoá, đọc nửa kia của cặp): `null` → `sl<…>()`, chỉ chạm khi cần.
  final ThaoTacKhoanNha? thaoTac;
  final GopQuyService? gopQuy;
  final WalletRepository? viRieng;

  @override
  State<ChiTietViChungPage> createState() => _ChiTietViChungPageState();
}

class _ChiTietViChungPageState extends State<ChiTietViChungPage> {
  late final NhaCubit _cubit;
  StreamSubscription<String>? _subBao;
  KhoanNhaCubit? _khoan;
  ViChungCubit? _viChung;
  bool _tabBangGop = false;

  /// Đã đóng vì mất ví: builder chạy nhiều lần trước khi `pop` xong, câu chỉ báo một lần.
  bool _daThoat = false;

  DuLieuNhaRepository get _duLieu => widget.duLieu ?? sl<DuLieuNhaRepository>();
  DateTime get _bayGio => (widget.dongHo ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _cubit = NhaCubit(widget.repo ?? sl<NhaRepository>());
    _subBao = _cubit.canBao.listen((c) => baoNhanh(c, loai: LoaiThongBao.loi));
    _dongBo(_cubit.state);
    unawaited(_cubit.moTrang());
  }

  @override
  void dispose() {
    unawaited(_subBao?.cancel());
    unawaited(_cubit.close());
    unawaited(_khoan?.close());
    unawaited(_viChung?.close());
    super.dispose();
  }

  /// Dựng cubit khoản / ví cho nhà HIỆN TẠI; nhà đổi id (hoặc mất) thì bỏ cái cũ. Khoản lọc theo ví ngay ở nguồn (kèm khoản chuyển
  /// ĐẾN ví này), trang lọc thêm bằng `locHoatDong`.
  void _dongBo(NhaState s) {
    final id = s.nha.coNha ? s.nha.nha!.id : null;
    if (id == _khoan?.idNha) return;
    unawaited(_khoan?.close());
    unawaited(_viChung?.close());
    _khoan = null;
    _viChung = null;
    if (id != null) {
      _khoan = KhoanNhaCubit(_duLieu, id, walletId: widget.idVi, idaccount: _cubit.idToi);
      _viChung = ViChungCubit(_duLieu, id);
    }
  }

  void _thoatVeVi() {
    if (_daThoat) return;
    _daThoat = true;
    baoNhanh('Ví chung này không còn nữa.', loai: LoaiThongBao.loi);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/nha');
    }
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
        value: _cubit,
        child: BlocListener<NhaCubit, NhaState>(
          // Nhà đổi id (nạp xong kho, vào nhà khác) thì dựng lại nguồn; mất nhà thì báo rồi về Nhà mình.
          listenWhen: (a, b) => a.nha.nha?.id != b.nha.nha?.id,
          listener: (ctx, s) {
            setState(() => _dongBo(s));
            if (!s.nha.coNha) baoMatVaiRoiVe(ctx, _cubit);
          },
          child: BlocBuilder<NhaCubit, NhaState>(
            builder: (context, s) {
              final khoan = _khoan;
              final viChung = _viChung;
              if (!s.daNap || (s.nha.coNha && (khoan == null || viChung == null))) {
                return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
              }
              if (khoan == null || viChung == null) return Scaffold(appBar: AppBar());
              return BlocBuilder<ViChungCubit, ViChungState>(
                bloc: viChung,
                builder: (context, v) {
                  final vi = v.vi.where((w) => w.id == widget.idVi && !w.isDeleted).firstOrNull;
                  if (v.daNap && vi == null) {
                    // Chỉ thoát khi route này đang ở TRÊN CÙNG: form `/nha/khoan`, `/nha/gop`, `/sua` đang đè lên thì `pop` đóng
                    // nhầm form. Đọc `ModalRoute` ở đây là phụ thuộc vào nó, nên builder chạy lại khi route được lộ ra.
                    if (ModalRoute.of(context)?.isCurrent == true) {
                      // `pop` không được gọi trong lúc dựng.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && ModalRoute.of(context)?.isCurrent == true) _thoatVeVi();
                      });
                    }
                    return Scaffold(appBar: AppBar());
                  }
                  return BlocBuilder<KhoanNhaCubit, KhoanNhaState>(
                    bloc: khoan,
                    builder: (context, k) => _khung(context, s, v, k, vi, v.vi),
                  );
                },
              );
            },
          ),
        ),
      );

  Widget _khung(BuildContext context, NhaState s, ViChungState v, KhoanNhaState k, WalletEntity? vi, List<WalletEntity> dsVi) {
    final nha = s.nha.nha;
    final quanLy = duocLamViecNha(ViecNha.quanLyViChung, vai: s.nha.vai, trangThai: nha?.trangThai);
    return Scaffold(
      appBar: AppBar(
        title: Text(vi?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (vi != null && quanLy)
            IconButton(
              key: const Key('nut-sua-vi'),
              tooltip: 'Chỉnh sửa ví',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => unawaited(context.push('/nha/vi/${Uri.encodeComponent(vi.id)}/sua')),
            ),
        ],
      ),
      body: SafeArea(
        child: vi == null || !v.daNap || !k.daNap
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _TheSoDu(vi: vi, vai: s.nha.vai, tienDo: _tienDo(v, vi)),
                  const SizedBox(height: 16),
                  ..._hangNut(context, s, vi),
                  _DieuKhienTab(bangGop: _tabBangGop, onDoi: (b) => setState(() => _tabBangGop = b)),
                  const SizedBox(height: 16),
                  if (nha != null) ..._tabBangGop ? [_bangGop(s.nha, k, vi)] : _giaoDich(context, s.nha, k, vi, dsVi),
                ],
              ),
      ),
    );
  }

  /// Tiến độ mục tiêu chung của ví (đợt 2); `null` = ví không đặt mục tiêu. Số dư lấy từ cột `balance` của chính ví.
  TienDoMucTieuChung? _tienDo(ViChungState v, WalletEntity vi) {
    final muc = v.mucTieu[vi.id];
    return muc == null ? null : tienDoMucTieuChung(mucTieu: muc, soDuVi: vi.balance, now: _bayGio);
  }

  /// Hàng nút theo vai (Stitch `ac57e216…` 3.3). Ví lưu trữ: dải *Ví đã lưu trữ* thay cho hàng nút.
  List<Widget> _hangNut(BuildContext context, NhaState s, WalletEntity vi) {
    if (!WalletStatus.laHoatDong(vi.status)) {
      return [
        Container(
          key: const Key('dai-luu-tru'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
          child: Text('Ví đã lưu trữ',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 16),
      ];
    }
    final trangThai = s.nha.nha?.trangThai;
    final ghi = duocLamViecNha(ViecNha.ghiKhoan, vai: s.nha.vai, trangThai: trangThai);
    final chuyen = duocLamViecNha(ViecNha.chuyenGiuaViChung, vai: s.nha.vai, trangThai: trangThai);
    void moForm(String huong) => unawaited(context.push('/nha/khoan?vi=${Uri.encodeQueryComponent(vi.id)}&huong=$huong'));
    void moGop(String che) => unawaited(context.push('/nha/gop?vi=${Uri.encodeQueryComponent(vi.id)}&che=$che'));
    final nut = [
      if (ghi) NutVi(khoa: 'nut-chi', nhan: 'Chi', icon: Icons.arrow_upward, onCham: () => moForm('chi')),
      if (ghi) NutVi(khoa: 'nut-thu', nhan: 'Thu', icon: Icons.arrow_downward, onCham: () => moForm('thu')),
      // Góp · Rút giữa Thu và Chuyển (màn 3): cùng quyền ghi khoản; mọi vai ghi được đều góp, rút về ví riêng của mình.
      if (ghi) NutVi(khoa: 'nut-gop', nhan: 'Góp', icon: Icons.savings_outlined, onCham: () => moGop('gop')),
      if (ghi) NutVi(khoa: 'nut-rut', nhan: 'Rút', icon: Icons.output, onCham: () => moGop('rut')),
      if (chuyen) NutVi(khoa: 'nut-chuyen', nhan: 'Chuyển', icon: Icons.sync_alt, onCham: () => moForm('transfer')),
    ];
    if (nut.isEmpty) return const [];
    return [HangNutVi(nut: nut), const SizedBox(height: 16)];
  }

  List<Widget> _giaoDich(BuildContext context, NhaCuaToi nha, KhoanNhaState k, WalletEntity vi, List<WalletEntity> dsVi) {
    final ds = locHoatDong(k.ds, vi: vi.id);
    if (ds.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
              child: Text('Chưa có khoản nào.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary))),
        ),
      ];
    }
    return nhomKhoanTheoNgay(
      context,
      ds: ds,
      bayGio: _bayGio,
      dong: (t) {
        final nguoi = tenNguoiNha(nha, t.idaccount);
        final dm = tenDanhMucKhoan(k.danhMuc, t);
        final cau = tieuDeKhoanNha(t, nguoi);
        return DongKhoanNha(
          key: ValueKey('khoan-${t.id}'),
          khoan: t,
          nguoi: nguoi,
          tieuDe: dm == null ? cau : '$cau · $dm',
          dongPhu: _dongPhu(t, dsVi),
          onCham: () => unawaited(moKhoanNha(
            context,
            conSong: () => mounted,
            khoan: t,
            nha: nha,
            idToi: _cubit.idToi,
            bayGio: _bayGio,
            vi: dsVi,
            danhMuc: k.danhMuc,
            thaoTac: widget.thaoTac,
            gopQuy: widget.gopQuy,
            viRieng: widget.viRieng,
          )),
        );
      },
    );
  }

  /// Ghi chú nếu có; góp / rút không ghi chú thì nói nửa riêng đi / về đâu (máy này không biết TÊN ví riêng của người khác).
  /// Chuyển: `Ví nguồn → Ví đích`.
  String _dongPhu(TransactionEntity t, List<WalletEntity> dsVi) {
    final loai = phanLoaiKhoanNha(t);
    if (loai == LoaiKhoanNha.chuyen) {
      final dich = t.walletTransfer;
      final nguon = tenViChungTheoId(dsVi, t.walletId);
      return dich == null ? nguon : '$nguon → ${tenViChungTheoId(dsVi, dich)}';
    }
    final ghiChu = t.note.trim();
    if (ghiChu.isNotEmpty) return ghiChu;
    return switch (loai) {
      // Không "Từ ví riêng": tiền mặt trao tay cũng có mã cặp (màn Góp nói "Không trừ ví nào của bạn", 02A:91).
      LoaiKhoanNha.gopNha => 'Góp vào quỹ',
      LoaiKhoanNha.rutNha => 'Về ví riêng',
      _ => '',
    };
  }

  /// Thành viên đang ở (đủ thẻ, kể cả 0 đ) rồi người đã rời CÓ khoản trong ví này; người ngoài danh sách mà có khoản vẫn hiện
  /// (tiền của họ vẫn nằm trong ví). Người đã rời không có khoản thì không có thẻ.
  Widget _bangGop(NhaCuaToi nha, KhoanNhaState k, WalletEntity vi) {
    final dong = {for (final d in bangGop(locHoatDong(k.ds, vi: vi.id), now: _bayGio, walletId: vi.id)) d.idaccount: d};
    final daCo = <int>{};
    final the = <({DongBangGop dong, bool daRoi})>[];
    for (final m in nha.thanhVien) {
      if (daCo.add(m.idaccount)) the.add((dong: dong[m.idaccount] ?? DongBangGop(idaccount: m.idaccount), daRoi: false));
    }
    for (final m in nha.thanhVienCu) {
      final d = dong[m.idaccount];
      if (d != null && daCo.add(m.idaccount)) the.add((dong: d, daRoi: true));
    }
    // Id không có ở cả hai danh sách thường là người MỚI vào mà `/me` của máy chưa cập nhật: không gắn "đã rời". Cờ lấy từ MỘT
    // nguồn như tab Giao dịch (`tenNguoiNha`).
    final conLai = dong.keys.where((id) => !daCo.contains(id)).toList()..sort();
    for (final id in conLai) {
      the.add((dong: dong[id]!, daRoi: tenNguoiNha(nha, id).daRoi));
    }
    return BangGopView(the: the, tenNguoi: (id) => tenNguoiNha(nha, id));
  }
}

/// Thẻ số dư (Stitch `ac57e216…` 3.2): nhãn + huy hiệu vai, số dư lớn, chấm xanh + *Tiền mặt · Ví chung*.
class _TheSoDu extends StatelessWidget {
  const _TheSoDu({required this.vi, required this.vai, this.tienDo});
  final WalletEntity vi;
  final VaiNha? vai;

  /// Có thì thẻ thêm khối MỤC TIÊU ở cuối (đợt 2).
  final TienDoMucTieuChung? tienDo;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return KhungTheNha(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SỐ DƯ',
                  style: chu.labelSmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
              if (vai case final v?)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(999)),
                  child: Text(tenVai(v), style: chu.labelSmall?.copyWith(color: _chuHuyHieu)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // 13 chữ số ở 30 px rộng hơn thẻ: co lại một dòng thay vì xuống dòng (Text xuống dòng không báo tràn).
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(CurrencyFormatter.format(vi.balance),
                  key: const Key('so-du-vi'),
                  maxLines: 1,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: _xanhCham, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Flexible(
                child: Text('${WalletType.tuKhoa(vi.type).nhan} · Ví chung',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: chu.bodySmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          if (tienDo case final td?) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.outlineVariant),
            const SizedBox(height: 14),
            KhoiMucTieuChiTiet(tienDo: td, hienCanGop: WalletStatus.laHoatDong(vi.status)),
          ],
        ],
      ),
    );
  }
}

/// Điều khiển phân đoạn *Giao dịch | Bảng góp* (Stitch 3.4): ô đang chọn nền đen chữ trắng.
class _DieuKhienTab extends StatelessWidget {
  const _DieuKhienTab({required this.bangGop, required this.onDoi});

  final bool bangGop;
  final ValueChanged<bool> onDoi;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(child: _Ngan(khoa: 'tab-giao-dich', nhan: 'Giao dịch', chon: !bangGop, onCham: () => onDoi(false))),
            Expanded(child: _Ngan(khoa: 'tab-bang-gop', nhan: 'Bảng góp', chon: bangGop, onCham: () => onDoi(true))),
          ],
        ),
      );
}

class _Ngan extends StatelessWidget {
  const _Ngan({required this.khoa, required this.nhan, required this.chon, required this.onCham});

  final String khoa;
  final String nhan;
  final bool chon;
  final VoidCallback onCham;

  @override
  Widget build(BuildContext context) => Material(
        color: chon ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: Key(khoa),
          borderRadius: BorderRadius.circular(8),
          onTap: onCham,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(nhan,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: chon ? FontWeight.w600 : FontWeight.w500,
                      color: chon ? AppColors.onPrimary : AppColors.textSecondary)),
            ),
          ),
        ),
      );
}
