import 'package:flutter/material.dart';

import '../../../../core/auth/dem_nguoc_xoa.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/an_the_cho_xoa.dart';
import '../../../auth/presentation/huy_yeu_cau_xoa.dart';

/// Thẻ nhắc "Tài khoản đang chờ xoá" ở Trang chủ — sửa G33.
///
/// Chữ và hành vi ở §5.2 spec
/// `docs/superpowers/specs/2026-09-10-cuong-che-dang-xuat-va-cho-xoa-design.md`;
/// hình theo HTML của màn Stitch `657d29a8f89e4750ae6f878d096aa94e` — tên lớp
/// Tailwind ghi cạnh từng chỗ để lần sau đối chiếu. Màu lấy hằng `AppColors`
/// tương ứng khi có. Không hiện gì — kể cả khoảng cách phía trên thẻ — khi tài
/// khoản không chờ xoá hoặc đã bấm "Để sau" trong lần mở app này.
class TheChoXoaTrangChu extends StatefulWidget {
  const TheChoXoaTrangChu({
    super.key,
    required this.user,
    this.authRepository,
    this.anThe,
    this.now,
  });

  final UserModel user;

  /// `null` = lấy từ `sl`; test tiêm thẳng.
  final AuthRepository? authRepository;
  final AnTheChoXoa? anThe;
  final DateTime Function()? now;

  @override
  State<TheChoXoaTrangChu> createState() => _TheChoXoaTrangChuState();
}

class _TheChoXoaTrangChuState extends State<TheChoXoaTrangChu> {
  /// Stitch `text-tertiary-container` (hệ Kinetic Finance của dự án) —
  /// `AppColors` chưa có hằng tương ứng.
  static const _mauThan = Color(0xFF410005);

  bool _dangHuy = false;

  AnTheChoXoa get _anThe => widget.anThe ?? sl<AnTheChoXoa>();

  Future<void> _huyXoa() async {
    setState(() => _dangHuy = true);
    await huyYeuCauXoa(context, widget.authRepository ?? sl<AuthRepository>());
    if (mounted) setState(() => _dangHuy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _anThe,
      builder: (context, daAn, _) {
        if (!widget.user.dangChoXoa || daAn) return const SizedBox.shrink();
        final soNgay = soNgayConLai(
          countdown: widget.user.countdown,
          nhanLuc: widget.user.countdownNhanLuc,
          now: (widget.now ?? DateTime.now)(),
        );
        // `text-[13px] leading-relaxed`
        const chuThan = TextStyle(fontSize: 13, height: 1.625, color: _mauThan);
        return Padding(
          // Khoảng 24 tách thẻ khỏi header nằm TRONG widget chứ không ở
          // `home_page.dart`: ẩn thẻ ("Để sau") thì khoảng cách mất theo. Bản
          // trước để nó ngoài thẻ nên còn khoảng trống 24dp suốt phiên (soát cuối G33).
          padding: const EdgeInsets.only(top: 24),
          child: Container(
            key: const Key('the-cho-xoa-trang-chu'),
            width: double.infinity,
            padding: const EdgeInsets.all(16), // `p-4`
            decoration: BoxDecoration(
              color: AppColors.errorContainer, // `bg-error-container`
              borderRadius: BorderRadius.circular(8), // `rounded-lg`
              // `border border-error/20`
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              // `custom-shadow`: 0 4px 12px rgba(0, 0, 0, .05)
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // `w-7 h-7 rounded-full bg-white/60`, đồng hồ `text-[18px] text-error`
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.schedule, color: AppColors.error, size: 18),
                    ),
                    const SizedBox(width: 8), // `gap-2`
                    const Flexible(
                      child: Text(
                        'Tài khoản đang chờ xoá',
                        // `text-sm font-bold text-on-error-container`
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8), // `mb-2`
                if (soNgay == null)
                  const Text(
                    'Tài khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn khi hết thời hạn chờ.',
                    style: chuThan,
                  )
                else
                  Text.rich(
                    TextSpan(
                      style: chuThan,
                      children: [
                        const TextSpan(text: 'Còn '),
                        TextSpan(
                          text: '$soNgay ngày',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                            text: ' nữa tài khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn.'),
                      ],
                    ),
                  ),
                const SizedBox(height: 12), // `mt-3`
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _dangHuy ? null : () => _anThe.value = true,
                      // `text-on-surface-variant font-medium text-[13px] px-3 py-1.5`
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      child: const Text('Để sau'),
                    ),
                    const SizedBox(width: 12), // `gap-3`
                    // FilledButton chứ không ElevatedButton: theme của app ép
                    // ElevatedButton rộng vô hạn — nằm trong Row là trắng cả trang.
                    FilledButton(
                      onPressed: _dangHuy ? null : _huyXoa,
                      // `bg-primary text-white font-semibold text-[13px] rounded-lg h-[36px] px-4`
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(64, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _dangHuy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Huỷ xoá'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
