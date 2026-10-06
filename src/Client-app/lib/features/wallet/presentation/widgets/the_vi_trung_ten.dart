import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/wallet_entity.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/services/gop_vi_service.dart';
import '../../data/vi_trung_ten_nguon.dart';
import '../../domain/vi_trung_ten.dart';
import 'hop_doi_ten_vi.dart';
import 'hop_gop_vi.dart';

/// Thẻ "VÍ TRÙNG TÊN" ở đầu màn Quản lý ví (G63) — spec 2026-10-05 mục 5.1,
/// màn Stitch `c5a2cecebc9f4959966346b3e99b4d47` *"Quản lý ví - Thẻ ví trùng tên"*.
///
/// Mỗi cặp một hộp con: ví trên máy này (bị server từ chối vì trùng tên, đang
/// bị giữ khỏi đồng bộ) và ví cùng tên đã đồng bộ. Không có cặp nào thì không
/// dựng gì — kể cả khoảng cách. Thẻ **tự nạp** qua [ViTrungTenNguon] (stream:
/// cờ vừa đặt trong lúc trang mở thì thẻ hiện ngay), không đi qua `WalletCubit`.
///
/// Bo góc theo quy ước sẵn của trang (thẻ 16) chứ không theo Stitch (8) — mọi
/// thẻ khác của trang đã lệch Stitch đúng chỗ ấy.
class TheViTrungTen extends StatefulWidget {
  const TheViTrungTen({
    super.key,
    required this.idaccount,
    this.nguon,
    this.viHienCo = const [],
    this.viRepo,
    this.thongBao,
    this.gopVi,
    this.onDaXuLy,
  });

  final int idaccount;

  /// `null` → `sl<ViTrungTenNguon>()` nếu đã đăng ký; chưa đăng ký (test cũ
  /// của trang) thì thẻ không dựng gì.
  final ViTrungTenNguon? nguon;

  /// Mọi ví chưa xoá của trang (kể cả lưu trữ) — để gợi ý và kiểm tên mới.
  final List<WalletEntity> viHienCo;

  /// `null` → `sl<WalletRepository>()`.
  final WalletRepository? viRepo;

  /// `null` → `sl<ThongBaoNhanh>()`.
  final ThongBaoNhanh? thongBao;

  /// `null` → `sl<GopViService>()`.
  final GopViService? gopVi;

  /// Gọi sau Đổi tên / Gộp — trang nạp lại `WalletCubit`.
  final VoidCallback? onDaXuLy;

  @override
  State<TheViTrungTen> createState() => _TheViTrungTenState();
}

class _TheViTrungTenState extends State<TheViTrungTen> {
  Stream<List<CapViHienThi>>? _ds;

  ViTrungTenNguon? get _nguon =>
      widget.nguon ??
      (sl.isRegistered<ViTrungTenNguon>() ? sl<ViTrungTenNguon>() : null);

  @override
  void initState() {
    super.initState();
    _ds = _nguon?.theoDoi(widget.idaccount);
  }

  @override
  void didUpdateWidget(covariant TheViTrungTen old) {
    super.didUpdateWidget(old);
    if (old.idaccount != widget.idaccount || old.nguon != widget.nguon) {
      _ds = _nguon?.theoDoi(widget.idaccount);
    }
  }

  ThongBaoNhanh get _thongBao => widget.thongBao ?? sl<ThongBaoNhanh>();

  Future<void> _doiTen(CapViHienThi cap) async {
    final ten = await hoiTenMoiChoVi(
      context,
      goiY: tenGoiYKhiTrung(cap.ten, widget.viHienCo.map((w) => w.name)),
      kiemTen: (t) => loiTenViMoi(t, widget.viHienCo, boQuaId: cap.idViMayNay),
    );
    if (ten == null || !mounted) return;
    final repo = widget.viRepo ?? sl<WalletRepository>();
    try {
      final vi = await repo.getById(cap.idViMayNay);
      if (vi == null) return;
      // Đường của trang Sửa ví: datasource kiểm trùng tên, ghi, gỡ cờ + mốc
      // chặn (spec mục 7) — không có lối ghi thứ hai.
      await repo.updateWallet(vi.copyWith(name: ten));
      _thongBao.hien('Đã đổi tên ví.');
    } on CacheException catch (e) {
      _thongBao.hien(e.message);
    }
    widget.onDaXuLy?.call();
  }

  Future<void> _gop(CapViHienThi cap) async {
    final svc = widget.gopVi ?? sl<GopViService>();
    // Hộp in đúng kế hoạch này; `gop` lập lại trong giao tác và từ chối nếu
    // dữ liệu đã đổi (KeHoachGopCuException).
    final kh = await svc.lapKeHoach(
        idViBo: cap.idViMayNay, idViGiu: cap.idViDaDongBo);
    if (!mounted) return;
    if (!await hoiGopVi(context, tenVi: cap.ten, keHoach: kh)) return;
    try {
      await svc.gop(kh);
      _thongBao.hien('Đã gộp ví.');
    } on KeHoachGopCuException catch (e) {
      _thongBao.hien(e.toString());
    }
    widget.onDaXuLy?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ds = _ds;
    if (ds == null) return const SizedBox.shrink();
    return StreamBuilder<List<CapViHienThi>>(
      stream: ds,
      builder: (context, snap) {
        final cap = snap.data ?? const <CapViHienThi>[];
        if (cap.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            key: const ValueKey('the-vi-trung-ten'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_rounded,
                        size: 18, color: AppColors.warning),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'VÍ TRÙNG TÊN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${cap.length} ví',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tên này đã có trên tài khoản (tạo từ thiết bị khác) nên ví '
                  'trên máy này chưa đồng bộ được.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                for (final c in cap) ...[
                  const SizedBox(height: 12),
                  _HopCap(
                    cap: c,
                    onDoiTen: () => _doiTen(c),
                    onGop: () => _gop(c),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Một cặp trùng — hộp con nền kem của Stitch.
class _HopCap extends StatelessWidget {
  const _HopCap({
    required this.cap,
    required this.onDoiTen,
    required this.onGop,
  });

  final CapViHienThi cap;
  final VoidCallback onDoiTen;
  final VoidCallback onGop;

  @override
  Widget build(BuildContext context) {
    const phu = TextStyle(fontSize: 12, height: 1.35, color: AppColors.textSecondary);
    const dam = TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cap.ten,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Máy này: '),
              TextSpan(
                  text: CurrencyFormatter.format(cap.soDuMayNay), style: dam),
              TextSpan(text: ' · ${cap.soGiaoDich} giao dịch'),
            ]),
            style: phu,
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Đã đồng bộ: '),
              TextSpan(
                  text: CurrencyFormatter.format(cap.soDuDaDongBo), style: dam),
            ]),
            style: phu,
          ),
          // Không gộp được (ví liên kết ngân hàng) thì nói vì sao — luật ở
          // `lyDoKhongGop`, cùng một chỗ với kế hoạch gộp.
          if (!cap.coTheGop) ...[
            const SizedBox(height: 6),
            Text(cap.lyDoKhongGop!, style: phu),
          ],
          const SizedBox(height: 4),
          // Hàng nút canh phải, như Stitch: "Đổi tên" chữ trần, "Gộp" nút đặc
          // bo tròn có biểu tượng.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: ValueKey('vi-trung-doi-ten-${cap.idViMayNay}'),
                onPressed: onDoiTen,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: const Text('Đổi tên'),
              ),
              if (cap.coTheGop) ...[
                const SizedBox(width: 8),
                // FilledButton chứ không ElevatedButton (bẫy 4.11).
                FilledButton.icon(
                  key: ValueKey('vi-trung-gop-${cap.idViMayNay}'),
                  onPressed: onGop,
                  icon: const Icon(Icons.merge, size: 16),
                  label: const Text('Gộp'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(64, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
