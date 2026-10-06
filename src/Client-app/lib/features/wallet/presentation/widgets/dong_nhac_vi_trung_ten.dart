import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/vi_trung_ten_nguon.dart';
import '../an_nhac_vi_trung_ten.dart';

/// Dòng nhắc "N ví trùng tên đang chờ bạn xử lý" ở Trang chủ (G63) — spec
/// 2026-10-05 mục 5.5, màn Stitch `5dd90541f4cc4be398a8f2840bcec9d6`
/// *"Trang chủ - Dòng nhắc ví trùng tên"*.
///
/// Chạm → mở Quản lý ví (`push`: Trang chủ nằm trong shell, `/wallets` là route
/// gốc — đúng hướng drawer vẫn dùng). ✕ ẩn trong lần mở app này
/// ([AnNhacViTrungTen]). Không có cặp nào thì không dựng gì, kể cả khoảng cách
/// phía trên — khoảng ấy nằm TRONG widget.
class DongNhacViTrungTen extends StatefulWidget {
  const DongNhacViTrungTen({
    super.key,
    required this.idaccount,
    this.nguon,
    this.an,
    this.moQuanLyVi,
  });

  final int idaccount;

  /// `null` → `sl` nếu đã đăng ký; chưa đăng ký (test cũ của Trang chủ) thì
  /// không dựng gì.
  final ViTrungTenNguon? nguon;
  final AnNhacViTrungTen? an;

  /// Mặc định `context.push('/wallets')`.
  final VoidCallback? moQuanLyVi;

  @override
  State<DongNhacViTrungTen> createState() => _DongNhacViTrungTenState();
}

class _DongNhacViTrungTenState extends State<DongNhacViTrungTen> {
  Stream<List<CapViHienThi>>? _ds;

  ViTrungTenNguon? get _nguon =>
      widget.nguon ??
      (sl.isRegistered<ViTrungTenNguon>() ? sl<ViTrungTenNguon>() : null);

  AnNhacViTrungTen? get _an =>
      widget.an ??
      (sl.isRegistered<AnNhacViTrungTen>() ? sl<AnNhacViTrungTen>() : null);

  @override
  void initState() {
    super.initState();
    _ds = _nguon?.theoDoi(widget.idaccount);
  }

  @override
  void didUpdateWidget(covariant DongNhacViTrungTen old) {
    super.didUpdateWidget(old);
    if (old.idaccount != widget.idaccount || old.nguon != widget.nguon) {
      _ds = _nguon?.theoDoi(widget.idaccount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = _ds;
    final an = _an;
    if (ds == null || an == null) return const SizedBox.shrink();
    // StreamBuilder NGOÀI, ValueListenableBuilder TRONG: bấm ✕ rồi đặt lại
    // không được nghe lại stream (stream thật — `watch` + `asyncMap` — chỉ một
    // người nghe).
    return StreamBuilder<List<CapViHienThi>>(
      stream: ds,
      builder: (context, snap) {
        final n = snap.data?.length ?? 0;
        return ValueListenableBuilder<bool>(
          valueListenable: an,
          builder: (context, daAn, _) {
            if (n == 0 || daAn) return const SizedBox.shrink();
            final cau = '$n ví trùng tên đang chờ bạn xử lý';
            return Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Material(
                key: const ValueKey('dong-nhac-vi-trung-ten'),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.moQuanLyVi ?? () => context.push('/wallets'),
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.sync_problem,
                              size: 20, color: AppColors.warning),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cau,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 18, color: AppColors.textSecondary),
                          Container(
                            width: 1,
                            height: 14,
                            margin: const EdgeInsets.only(left: 4),
                            color: AppColors.outlineVariant,
                          ),
                          IconButton(
                            tooltip: 'Ẩn lời nhắc',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close,
                                size: 16, color: AppColors.textSecondary),
                            onPressed: () => an.value = true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
