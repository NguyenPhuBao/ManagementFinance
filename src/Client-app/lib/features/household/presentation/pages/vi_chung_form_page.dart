import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/current_account.dart';
import '../../../category/presentation/widgets/category_visuals.dart';
import '../../../wallet/application/dieu_chinh_so_du_service.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../../wallet/domain/rang_buoc_vi.dart';
import '../../../wallet/domain/wallet_status.dart';
import '../../../wallet/domain/wallet_type.dart';
import '../../../wallet/presentation/widgets/o_so_du_vi.dart';
import '../../data/repositories/du_lieu_nha_repository.dart';
import '../../data/repositories/nha_repository.dart';
import '../../domain/cau_loi_nha.dart';
import '../../domain/quyen_nha.dart';
import '../widgets/khung_the_nha.dart';

/// Sáu biểu tượng và sáu màu của form ví chung (Stitch `3bfb38b3…`). Khoá lưu vào cột `icon` / `colour` của ví; hình vẽ do
/// `categoryIconFor` (MỘT bộ vẽ cho ví chung — `KhoiViChung` và Chi tiết ví cũng qua nó).
const kIconViChung = ['payments', 'account_balance', 'savings', 'shopping_basket', 'home', 'restaurant'];
const kMauViChung = ['#006E1C', '#1967D2', '#E65100', '#BA1A1A', '#7B1FA2', '#00897B'];
const _tenMauViChung = ['Xanh lá', 'Xanh dương', 'Vàng cam', 'Đỏ', 'Tím', 'Teal'];

/// Màu của Stitch không trùng token nào của `AppColors` (nút Lưu xanh đậm, chữ phụ).
const _xanhLuu = Color(0xFF006E1C);
const _chuPhu = Color(0xFF454743);

/// Tạo (`idVi == null`) và Sửa ví chung (Stitch `3bfb38b3…`, `be328002…`). Trang MỚI: `WalletAddPage` / `WalletEditPage` của ví
/// cá nhân nói chuyện với `WalletRepository` (lọc theo tài khoản, có ví mặc định / tính vào tổng / cho âm) — không dùng lại.
///
/// - Vai kiểm Ở ĐÂY lúc mở (deeplink, vai đổi giữa chừng): không phải Chủ nhà đang hoạt động thì tự đóng kèm câu. Nút mở form
///   đã ẩn theo vai; chốt này là lưới cho đường vào không qua nút.
/// - `idaccount` chỉ từ phiên, đọc TRƯỚC mọi `await`; không phiên thì báo lỗi và không ghi (quy tắc 2).
/// - Số dư ở Sửa không ghi đè: đổi số dư là một khoản điều chỉnh trong sổ (`DieuChinhSoDuService`, bất biến ⑦), người ghi là
///   `nguoiGhi: phiên`.
class ViChungFormPage extends StatefulWidget {
  const ViChungFormPage({super.key, this.idVi, this.duLieu, this.dieuChinh, this.nha});

  /// `null` = Tạo.
  final String? idVi;

  /// `null` → `sl<DuLieuNhaRepository>()`, chỉ chạm khi cần.
  final DuLieuNhaRepository? duLieu;
  final DieuChinhSoDuService? dieuChinh;

  /// Nguồn vai / nhà lúc mở. `null` → `sl<NhaRepository>()`.
  final NhaRepository? nha;

  @override
  State<ViChungFormPage> createState() => _ViChungFormPageState();
}

class _ViChungFormPageState extends State<ViChungFormPage> {
  final _ten = TextEditingController();
  final _soDu = TextEditingController();
  String _loai = WalletType.cash.khoa;
  String _icon = kIconViChung.first;
  String _mau = kMauViChung.first;
  bool _luuTru = false;
  bool _dangLuu = false;
  bool _daNap = false;
  int? _idNha;
  WalletEntity? _viGoc;

  /// Chữ ô số dư lúc mở: so với nó để biết người dùng có đổi số dư không (ví số dư lẻ hiện làm tròn, so với `balance` thì ví
  /// nào cũng "đổi").
  String _soDuLucMo = '';

  /// Mọi ví của nhà kể cả ví lưu trữ — chúng vẫn giữ tên trên server.
  List<WalletEntity> _viHienCo = const [];

  bool get _laSua => widget.idVi != null;
  DuLieuNhaRepository get _nguon => widget.duLieu ?? sl<DuLieuNhaRepository>();

  @override
  void initState() {
    super.initState();
    // Sau khung đầu: `_thoat` gọi `pop`, không được gọi trong lúc dựng.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_nap()));
  }

  @override
  void dispose() {
    _ten.dispose();
    _soDu.dispose();
    super.dispose();
  }

  void _thoat(String cau) {
    baoNhanh(cau, loai: LoaiThongBao.loi);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/nha');
    }
  }

  void _loi(String cau) => baoNhanh(cau, loai: LoaiThongBao.loi);

  String _cau(Object e) => e.toString().replaceAll('CacheException: ', '').replaceAll('Exception: ', '');

  Future<void> _nap() async {
    final t = (widget.nha ?? sl<NhaRepository>()).hienTai;
    final nha = t.nha;
    if (nha == null || !duocLamViecNha(ViecNha.quanLyViChung, vai: t.vai, trangThai: nha.trangThai)) {
      _thoat(cauLoiNha(LoaiLoiNha.khongPhaiChu));
      return;
    }
    _idNha = nha.id;
    try {
      final ds = await _nguon.theoDoiViChung(nha.id).first;
      if (!mounted) return;
      _viHienCo = ds;
      final id = widget.idVi;
      if (id != null) {
        final vi = ds.where((v) => v.id == id && !v.isDeleted).firstOrNull;
        if (vi == null) {
          _thoat('Không tìm thấy ví chung này.');
          return;
        }
        _viGoc = vi;
        _ten.text = vi.name;
        _soDu.text = CurrencyFormatter.formatSoThoi(vi.balance.toInt());
        _soDuLucMo = _soDu.text;
        _loai = vi.type;
        _icon = vi.icon;
        _mau = vi.colour;
        _luuTru = !WalletStatus.laHoatDong(vi.status);
      }
    } catch (e) {
      if (!mounted) return;
      // Sửa mà không đọc được ví thì không có gì để sửa; Tạo vẫn dùng được (kho là chốt trùng tên thật).
      if (_laSua) {
        _thoat(_cau(e));
        return;
      }
    }
    setState(() => _daNap = true);
  }

  Future<void> _luu() async {
    if (_dangLuu) return;
    final ten = _ten.text.trim();
    if (ten.isEmpty) {
      _loi('Vui lòng nhập tên ví chung');
      return;
    }
    final idNha = _idNha;
    if (idNha == null) return;
    // Quy tắc 2: idaccount chỉ từ phiên, đọc trước `await`. `null` = chưa có phiên dùng được.
    final idaccount = currentAccountIdOrNull(context);
    if (idaccount == null) {
      _loi('Không xác định được tài khoản. Hãy đăng nhập lại.');
      return;
    }
    if (viTrungTen(_viHienCo, ten, boQuaId: widget.idVi) != null) {
      _loi(thongBaoTrungTen(ten));
      return;
    }
    final soDu = double.tryParse(_soDu.text.replaceAll('.', '')) ?? 0.0;
    setState(() => _dangLuu = true);
    try {
      final goc = _viGoc;
      if (goc == null) {
        await _nguon.taoViChung(
          idNha: idNha,
          idaccount: idaccount,
          ten: ten,
          loai: _loai,
          soDuBanDau: soDu,
          icon: _icon,
          mau: _mau,
        );
      } else {
        await _luuSua(goc, ten: ten, soDu: soDu, idNha: idNha, idaccount: idaccount);
      }
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) _loi(_cau(e));
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  Future<void> _luuSua(WalletEntity goc, {required String ten, required double soDu, required int idNha, required int idaccount}) async {
    await _nguon.suaViChung(goc.copyWith(name: ten, type: _loai, icon: _icon, colour: _mau));
    final dangLuuTru = !WalletStatus.laHoatDong(goc.status);
    final doiTrangThai = _luuTru != dangLuuTru;
    // Số dư đi đường riêng (không ghi đè): một khoản điều chỉnh trong sổ, người ghi là người dùng này.
    final doiSoDu = _soDu.text != _soDuLucMo;
    Future<void> trangThai() async {
      if (doiTrangThai) await _nguon.luuTruViChung(idNha: idNha, id: goc.id, luuTru: _luuTru);
    }

    Future<void> soDuMoi() async {
      if (doiSoDu) {
        await (widget.dieuChinh ?? sl<DieuChinhSoDuService>())
            .dieuChinh(walletId: goc.id, soDuThucTe: soDu, lyDo: '', nguoiGhi: idaccount);
      }
    }

    // Đối soát từ chối ví đã lưu trữ: lưu trữ SAU khi đối soát, bỏ lưu trữ TRƯỚC.
    if (_luuTru) {
      await soDuMoi();
      await trangThai();
    } else {
      await trangThai();
      await soDuMoi();
    }
  }

  Future<void> _xoa() async {
    final goc = _viGoc;
    final idNha = _idNha;
    if (goc == null || idNha == null) return;
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá ví chung?'),
        content: Text('Ví "${goc.name}" sẽ bị xoá. Ví còn giao dịch thì chỉ lưu trữ được, không xoá được.'),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            key: const Key('xac-nhan-xoa-vi-chung'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá ví chung'),
          ),
        ],
      ),
    );
    if (dongY != true || !mounted) return;
    setState(() => _dangLuu = true);
    try {
      await _nguon.xoaViChung(idNha: idNha, id: goc.id);
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) _loi(_cau(e));
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(tooltip: 'Quay lại', icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(_laSua ? 'Sửa ví chung' : 'Tạo ví chung'),
        actions: [
          TextButton(
            key: const Key('nut-luu-vi-chung'),
            onPressed: _dangLuu || !_daNap ? null : _luu,
            child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w600, color: _xanhLuu)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: !_daNap
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _theChinh(context),
                    if (_laSua) ...[
                      const SizedBox(height: 16),
                      _theLuuTru(context),
                      const SizedBox(height: 16),
                      _nutXoa(context),
                    ] else ...[
                      const SizedBox(height: 12),
                      _chuThich(context),
                      const SizedBox(height: 24),
                      _nutTao(),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _nhan(String s, {TextAlign canh = TextAlign.start}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s,
            textAlign: canh,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      );

  Widget _theChinh(BuildContext context) {
    return KhungTheNha(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _nhan(_laSua ? 'SỐ DƯ HIỆN TẠI' : 'SỐ DƯ BAN ĐẦU', canh: TextAlign.center),
          OSoDuVi(controller: _soDu),
          if (_laSua)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Sửa số dư sẽ tạo một khoản điều chỉnh trong ví',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ),
          const SizedBox(height: 20),
          _nhan('TÊN VÍ CHUNG'),
          TextField(
            key: const Key('o-ten-vi-chung'),
            controller: _ten,
            inputFormatters: const [GioiHanDoRong(DoRongCot.tenVi)],
            decoration: InputDecoration(
              hintText: _laSua ? 'Nhập tên ví chung' : 'Ví dụ: Tiền chợ',
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          _nhan('LOẠI VÍ'),
          _loaiVi(),
          const SizedBox(height: 20),
          _nhan('CHỌN BIỂU TƯỢNG'),
          _bieuTuong(),
          const SizedBox(height: 20),
          _nhan('MÀU SẮC CHỦ ĐẠO'),
          _mauSac(),
        ],
      ),
    );
  }

  Widget _loaiVi() {
    final chu = Theme.of(context).textTheme;
    return Row(
      children: [
        for (var i = 0; i < WalletType.chonDuoc.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Builder(builder: (_) {
              final loai = WalletType.chonDuoc[i];
              final chon = _loai == loai.khoa;
              return Material(
                color: chon ? AppColors.primary : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: Key('loai-${loai.khoa}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _loai = loai.khoa),
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: Text(loai.nhan,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: chu.labelMedium?.copyWith(
                              color: chon ? AppColors.onPrimary : _chuPhu, fontWeight: chon ? FontWeight.w600 : FontWeight.w500)),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _bieuTuong() => Row(
        children: [
          for (var i = 0; i < kIconViChung.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            // `Expanded` chứ không rộng cố định: sáu ô 44 dp + khe tràn ở 320 dp.
            Expanded(
              child: Builder(builder: (_) {
                final khoa = kIconViChung[i];
                final chon = _icon == khoa;
                return Material(
                  color: chon ? AppColors.primary : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: Key('icon-$khoa'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _icon = khoa),
                    child: SizedBox(
                      height: 44,
                      child: Icon(categoryIconFor(khoa), size: 20, color: chon ? AppColors.onPrimary : _chuPhu),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      );

  Widget _mauSac() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < kMauViChung.length; i++)
            Builder(builder: (_) {
              final hex = kMauViChung[i];
              final mau = categoryColorFrom(hex);
              final chon = _mau.toUpperCase() == hex;
              return Semantics(
                button: true,
                selected: chon,
                label: _tenMauViChung[i],
                child: GestureDetector(
                  key: Key('mau-$hex'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _mau = hex),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: mau,
                      shape: BoxShape.circle,
                      // Vòng ngoài cùng màu cách một khe trắng (`ring-2 ring-offset-2`).
                      border: chon ? Border.all(color: AppColors.surface, width: 2) : null,
                      boxShadow: chon ? [BoxShadow(color: mau, spreadRadius: 2)] : null,
                    ),
                    child: chon ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  ),
                ),
              );
            }),
        ],
      );

  Widget _chuThich(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 17, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Ví chung thuộc về cả nhà. Mọi thành viên thấy số dư và các khoản trong ví.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );

  Widget _nutTao() => SizedBox(
        height: 48,
        child: FilledButton(
          key: const Key('nut-tao-vi-chung'),
          onPressed: _dangLuu ? null : _luu,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(Icons.add_circle_outline, size: 19), SizedBox(width: 8), Text('Tạo ví chung')],
          ),
        ),
      );

  Widget _theLuuTru(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return KhungTheNha(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.inventory_2_outlined, size: 20, color: _chuPhu),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lưu trữ ví chung', style: chu.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text('Ẩn khỏi lựa chọn khi ghi khoản. Lịch sử vẫn còn.',
                    style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            key: const Key('cong-tac-luu-tru'),
            value: _luuTru,
            onChanged: _dangLuu ? null : (v) => setState(() => _luuTru = v),
            activeTrackColor: AppColors.primary,
            activeThumbColor: Colors.white,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFDADAD6),
          ),
        ],
      ),
    );
  }

  Widget _nutXoa(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: OutlinedButton(
              key: const Key('nut-xoa-vi-chung'),
              onPressed: _dangLuu ? null : _xoa,
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.delete_outline, size: 20), SizedBox(width: 8), Text('Xoá ví chung')],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Ví còn giao dịch thì chỉ lưu trữ được, không xoá được.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ),
        ],
      );
}
