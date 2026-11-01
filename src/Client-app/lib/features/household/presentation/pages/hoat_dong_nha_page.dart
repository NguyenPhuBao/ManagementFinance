import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../category/data/models/category_entity.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../transaction/presentation/pages/add_transaction_page.dart' show EditTransactionArgs;
import '../../../wallet/data/models/wallet_entity.dart';
import '../../../wallet/data/repositories/wallet_repository.dart';
import '../../application/gop_quy_service.dart';
import '../../application/thao_tac_khoan_nha.dart';
import '../../data/models/nha_cua_toi.dart';
import '../../data/repositories/du_lieu_nha_repository.dart';
import '../../data/repositories/nha_repository.dart';
import '../../domain/cau_xoa_khoan_gop.dart';
import '../../domain/hoat_dong_nha.dart';
import '../../domain/loai_khoan_nha.dart';
import '../bloc/khoan_nha_cubit.dart';
import '../bloc/nha_cubit.dart';
import '../bloc/vi_chung_cubit.dart';
import '../widgets/dong_khoan_nha.dart';
import '../widgets/gac_vai_chu.dart';
import '../widgets/sheet_khoan_nha.dart';

/// Màu chữ của tiêu đề nhóm ngày (Stitch `50af4171…` 7.3): không trùng token nào của `AppColors`.
const _mauNhomTrai = Color(0xFF686A65);
const _mauNhomPhai = Color(0xFF8C8E88);
const _mauChanTrang = Color(0xFF9DA099);

/// Hộp chọn của một chip lọc: `null` là *không chọn gì* (đóng ra ngoài) khác với [LuaChon] có giá trị `null` (*mọi người*).
class _LuaChon<T> {
  const _LuaChon(this.giaTri);
  final T? giaTri;
}

/// Màn Hoạt động của nhà `/nha/hoat-dong` (đợt 1B Task 6; Stitch `50af4171…`, chi tiết `a8d53198…`, hộp xoá `6dc96c4a…` 8B).
/// Mọi thành viên xem được, kể cả Chỉ xem và nhà chỉ xem: nút Sửa / Xoá của sheet theo `quyenKhoanNha`.
///
/// ⚠️ Route `/nha/khoan` KHÔNG tự xét quyền sửa, nên nút Sửa ở đây là chốt duy nhất cho Thành viên (khoản chuyển mở form sẽ không
/// chip nào sáng). Nút Sửa của khoản cặp bật ở Task 8 cùng route `/nha/gop`.
class HoatDongNhaPage extends StatefulWidget {
  const HoatDongNhaPage({super.key, this.repo, this.duLieu, this.thaoTac, this.gopQuy, this.viRieng, this.dongHo});

  /// Các tham số `null` → `sl<…>()`, chỉ chạm khi cần (test cũ không dựng DI).
  final NhaRepository? repo;
  final DuLieuNhaRepository? duLieu;
  final ThaoTacKhoanNha? thaoTac;
  final GopQuyService? gopQuy;
  final WalletRepository? viRieng;

  /// Đồng hồ tiêm được cho nhóm *Hôm nay / Hôm qua*; `null` → giờ máy.
  final DateTime Function()? dongHo;

  @override
  State<HoatDongNhaPage> createState() => _HoatDongNhaPageState();
}

class _HoatDongNhaPageState extends State<HoatDongNhaPage> {
  late final NhaCubit _cubit;
  StreamSubscription<String>? _subBao;
  KhoanNhaCubit? _khoan;
  ViChungCubit? _viChung;
  int? _nguoi;
  String? _vi;

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

  /// Dựng cubit khoản / ví cho nhà HIỆN TẠI; nhà đổi id (hoặc mất) thì bỏ cái cũ. Giữ ở trang chứ không ở dòng danh sách.
  void _dongBo(NhaState s) {
    final id = s.nha.coNha ? s.nha.nha!.id : null;
    if (id == _khoan?.idNha) return;
    unawaited(_khoan?.close());
    unawaited(_viChung?.close());
    _khoan = null;
    _viChung = null;
    _nguoi = null;
    _vi = null;
    if (id != null) {
      _khoan = KhoanNhaCubit(_duLieu, id, idaccount: _cubit.idToi);
      _viChung = ViChungCubit(_duLieu, id);
    }
  }

  TenNguoi _tenNguoi(NhaCuaToi nha, int id) {
    for (final m in nha.thanhVien) {
      if (m.idaccount == id) return TenNguoi(m.tenHienThi);
    }
    for (final m in nha.thanhVienCu) {
      if (m.idaccount == id) return TenNguoi(m.tenHienThi, daRoi: true);
    }
    return TenNguoi('Thành viên #$id');
  }

  String _tenVi(List<WalletEntity> vi, String id) {
    for (final v in vi) {
      if (v.id == id) return v.name;
    }
    return 'Ví đã xoá';
  }

  String? _tenDanhMuc(List<CategoryEntity> dm, TransactionEntity t) {
    final id = t.categoryId;
    if (id == null) return null;
    for (final c in dm) {
      if (c.id == id) return c.name;
    }
    return 'Danh mục đã xoá';
  }

  /// `Danh mục · Ví` (chi, thu), `Ví` (góp, rút), `Ví nguồn → Ví đích` (chuyển).
  String _dongPhu(TransactionEntity t, List<WalletEntity> vi, List<CategoryEntity> dm) {
    final nguon = _tenVi(vi, t.walletId);
    if (phanLoaiKhoanNha(t) == LoaiKhoanNha.chuyen) {
      final dich = t.walletTransfer;
      return dich == null ? nguon : '$nguon → ${_tenVi(vi, dich)}';
    }
    final dmTen = _tenDanhMuc(dm, t);
    return dmTen == null ? nguon : '$dmTen · $nguon';
  }

  Future<void> _chonNguoi(NhaCuaToi nha) async {
    final kq = await showModalBottomSheet<_LuaChon<int>>(
      context: context,
      builder: (_) => _BangChon<int>(
        tieuDe: 'Lọc theo người',
        macDinh: 'Mọi người',
        dang: _nguoi,
        muc: [
          for (final m in nha.thanhVien) (m.idaccount, m.tenHienThi),
          for (final m in nha.thanhVienCu) (m.idaccount, '${m.tenHienThi} (đã rời)'),
        ],
      ),
    );
    if (kq != null && mounted) setState(() => _nguoi = kq.giaTri);
  }

  Future<void> _chonVi(List<WalletEntity> vi) async {
    final kq = await showModalBottomSheet<_LuaChon<String>>(
      context: context,
      builder: (_) => _BangChon<String>(
        tieuDe: 'Lọc theo ví chung',
        macDinh: 'Mọi ví chung',
        dang: _vi,
        muc: [for (final v in vi) (v.id, v.name)],
      ),
    );
    if (kq != null && mounted) setState(() => _vi = kq.giaTri);
  }

  Future<void> _moKhoan(TransactionEntity t, NhaState s, KhoanNhaState k, List<WalletEntity> vi) async {
    final nha = s.nha;
    final goc = quyenKhoanNha(t, vai: nha.vai, trangThai: nha.nha?.trangThai, idToi: _cubit.idToi);
    // Khoản cặp: nút Sửa bật ở Task 8 (route `/nha/gop`), tới đó Xoá vẫn dùng được.
    final quyen = (sua: goc.sua && t.fundPairId == null, xoa: goc.xoa);
    final dich = t.walletTransfer;
    final hanhDong = await moSheetKhoanNha(
      context,
      khoan: t,
      nguoi: _tenNguoi(nha, t.idaccount),
      nhanNgay: nhanNhomNgay(t.date, _bayGio),
      viHienThi: phanLoaiKhoanNha(t) == LoaiKhoanNha.chuyen && dich != null
          ? '${_tenVi(vi, t.walletId)} → ${_tenVi(vi, dich)}'
          : _tenVi(vi, t.walletId),
      tenDanhMuc: _tenDanhMuc(k.danhMuc, t),
      quyen: quyen,
    );
    if (hanhDong == null || !mounted) return;
    switch (hanhDong) {
      case HanhDongKhoanNha.sua:
        CategoryEntity? dm;
        for (final c in k.danhMuc) {
          if (c.id == t.categoryId) dm = c;
        }
        // Thiếu `category` là cubit `danhMuc == null` và lưu sửa báo *Vui lòng chọn danh mục*.
        unawaited(context.push('/nha/khoan', extra: EditTransactionArgs(transaction: t, category: dm)));
      case HanhDongKhoanNha.xoa:
        await _xoa(t, nha, vi);
    }
  }

  Future<void> _xoa(TransactionEntity t, NhaCuaToi nha, List<WalletEntity> vi) async {
    final maCap = t.fundPairId;
    if (maCap == null) {
      if (!await ConfirmDialog.show(context,
          title: 'Xoá khoản này?',
          message: 'Khoản sẽ bị xoá khỏi nhà và số dư ví chung được tính lại.',
          confirmText: 'Xoá',
          cancelText: 'Huỷ')) {
        return;
      }
    } else {
      final cau = await _cauXoaCap(t, maCap, nha, vi);
      if (cau == null || !mounted) return;
      // Hàng của nhà: góp là `thu`, rút là `chi` (`phanLoaiKhoanNha`).
      final gop = t.type == 'thu';
      if (!await hoiXoaKhoanGop(context, tieuDe: gop ?'Xoá khoản góp?' : 'Xoá khoản rút?', cau: cau)) return;
    }
    if (!mounted) return;
    try {
      await (widget.thaoTac ?? sl<ThaoTacKhoanNha>()).xoa(t);
      baoNhanh('Đã xoá khoản.');
    } on CacheException catch (e) {
      baoNhanh(e.message, loai: LoaiThongBao.loi);
    } catch (_) {
      baoNhanh('Không xoá được khoản này. Thử lại sau.', loai: LoaiThongBao.loi);
    }
  }

  /// Câu hộp xoá khoản cặp, đọc nửa kia của cặp trên máy này. `null` khi đọc hỏng (đã báo).
  Future<String?> _cauXoaCap(TransactionEntity t, String maCap, NhaCuaToi nha, List<WalletEntity> vi) async {
    try {
      final cap = await (widget.gopQuy ?? sl<GopQuyService>()).docCap(maCap);
      final nuaNha = cap.nha ?? t;
      final rieng = cap.rieng;
      String? tenViRieng;
      String? tenNguoiKhac;
      if (rieng != null) {
        final v = await (widget.viRieng ?? sl<WalletRepository>()).getById(rieng.walletId);
        tenViRieng = v?.name ?? 'ví riêng';
      } else if (t.idaccount != _cubit.idToi) {
        // Chủ xoá hộ: nửa riêng nằm trên máy người ghi, máy này không có.
        tenNguoiKhac = _tenNguoi(nha, t.idaccount).ten;
      }
      return cauXoaKhoanGop(
        gop: nuaNha.type == 'thu',
        tenQuy: _tenVi(vi, nuaNha.walletId),
        soTien: t.amount,
        tenViRieng: tenViRieng,
        tenNguoiKhac: tenNguoiKhac,
      );
    } catch (_) {
      baoNhanh('Không đọc được khoản này. Thử lại sau.', loai: LoaiThongBao.loi);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
        value: _cubit,
        child: Scaffold(
          appBar: AppBar(title: const Text('Hoạt động')),
          body: SafeArea(
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
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (khoan == null || viChung == null) return const SizedBox.shrink();
                  return BlocBuilder<ViChungCubit, ViChungState>(
                    bloc: viChung,
                    builder: (context, v) => BlocBuilder<KhoanNhaCubit, KhoanNhaState>(
                      bloc: khoan,
                      builder: (context, k) => _noiDung(context, s, k, v.vi),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

  Widget _noiDung(BuildContext context, NhaState s, KhoanNhaState k, List<WalletEntity> vi) {
    if (!k.daNap) return const Center(child: CircularProgressIndicator());
    final chu = Theme.of(context).textTheme;
    final ds = locHoatDong(k.ds, nguoi: _nguoi, vi: _vi);
    final tenNguoiLoc = _nguoi == null ? 'Mọi người' : _tenNguoi(s.nha, _nguoi!).ten;
    final tenViLoc = _vi == null ? 'Mọi ví chung' : _tenVi(vi, _vi!);
    final nhom = <String, List<TransactionEntity>>{};
    for (final t in ds) {
      nhom.putIfAbsent(DateFormatter.dayKey(t.date), () => []).add(t);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Row(
          children: [
            Flexible(child: _ChipLoc(khoa: 'chip-nguoi', nhan: tenNguoiLoc, onCham: () => unawaited(_chonNguoi(s.nha)))),
            const SizedBox(width: 8),
            Flexible(child: _ChipLoc(khoa: 'chip-vi', nhan: tenViLoc, onCham: () => unawaited(_chonVi(vi)))),
          ],
        ),
        const SizedBox(height: 16),
        if (ds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('Chưa có khoản nào.', style: chu.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            ),
          ),
        for (final entry in nhom.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(nhanNhomNgay(entry.value.first.date, _bayGio),
                    style: chu.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: _mauNhomTrai)),
                Text('${entry.value.length} giao dịch', style: chu.labelSmall?.copyWith(color: _mauNhomPhai)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.surfaceContainerLow),
                  DongKhoanNha(
                    key: ValueKey('khoan-${entry.value[i].id}'),
                    khoan: entry.value[i],
                    nguoi: _tenNguoi(s.nha, entry.value[i].idaccount),
                    dongPhu: _dongPhu(entry.value[i], vi, k.danhMuc),
                    onCham: () => unawaited(_moKhoan(entry.value[i], s, k, vi)),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 14, color: _mauChanTrang),
            const SizedBox(width: 6),
            Flexible(
              child: Text('Chỉ các thành viên trong nhà mới có thể xem hoạt động',
                  textAlign: TextAlign.center, style: chu.labelSmall?.copyWith(color: _mauChanTrang)),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChipLoc extends StatelessWidget {
  const _ChipLoc({required this.khoa, required this.nhan, required this.onCham});

  final String khoa;
  final String nhan;
  final VoidCallback onCham;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        shape: const StadiumBorder(side: BorderSide(color: Color(0xFFE2E1DB))),
        child: InkWell(
          key: Key(khoa),
          customBorder: const StadiumBorder(),
          onTap: onCham,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(nhan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF71736E)),
              ],
            ),
          ),
        ),
      );
}

/// Bảng chọn của chip lọc: dòng đầu là *mọi …* (giá trị `null`), rồi từng mục. Đóng ra ngoài trả `null` (giữ bộ lọc).
class _BangChon<T> extends StatelessWidget {
  const _BangChon({required this.tieuDe, required this.macDinh, required this.dang, required this.muc});

  final String tieuDe;
  final String macDinh;
  final T? dang;
  final List<(T, String)> muc;

  @override
  Widget build(BuildContext context) {
    Widget dong(String nhan, T? giaTri) => ListTile(
          key: Key('chon-${giaTri ?? 'tat-ca'}'),
          title: Text(nhan, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: giaTri == dang ? const Icon(Icons.check, color: AppColors.primary) : null,
          onTap: () => Navigator.of(context).pop(_LuaChon<T>(giaTri)),
        );
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(tieuDe, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            dong(macDinh, null),
            for (final (giaTri, nhan) in muc) dong(nhan, giaTri),
          ],
        ),
      ),
    );
  }
}
