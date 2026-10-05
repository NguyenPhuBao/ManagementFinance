import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/vi_trung_ten_nguon.dart';

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
  const TheViTrungTen({super.key, required this.idaccount, this.nguon});

  final int idaccount;

  /// `null` → `sl<ViTrungTenNguon>()` nếu đã đăng ký; chưa đăng ký (test cũ
  /// của trang) thì thẻ không dựng gì.
  final ViTrungTenNguon? nguon;

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
                  _HopCap(cap: c),
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
  const _HopCap({required this.cap});

  final CapViHienThi cap;

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
        ],
      ),
    );
  }
}
