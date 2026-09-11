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
/// Stitch `657d29a8f89e4750ae6f878d096aa94e`; chữ, màu và hành vi ở §5.2 spec
/// `docs/superpowers/specs/2026-09-10-cuong-che-dang-xuat-va-cho-xoa-design.md`.
/// Không hiện gì — kể cả khoảng cách phía trên thẻ — khi tài khoản không chờ xoá
/// hoặc đã bấm "Để sau" trong lần mở app này.
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
        const chuThan = TextStyle(
            fontSize: 14, height: 1.5, color: AppColors.textPrimary);
        return Padding(
          // Khoảng 24 tách thẻ khỏi header nằm TRONG widget chứ không ở
          // `home_page.dart`: ẩn thẻ ("Để sau") thì khoảng cách mất theo. Bản
          // trước để nó ngoài thẻ nên còn khoảng trống 24dp suốt phiên (soát cuối G33).
          padding: const EdgeInsets.only(top: 24),
          child: Container(
            key: const Key('the-cho-xoa-trang-chu'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.schedule, color: AppColors.onErrorContainer, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tài khoản đang chờ xoá',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _dangHuy ? null : () => _anThe.value = true,
                      style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
                      child: const Text('Để sau'),
                    ),
                    const SizedBox(width: 8),
                    // FilledButton chứ không ElevatedButton: theme của app ép
                    // ElevatedButton rộng vô hạn — nằm trong Row là trắng cả trang.
                    FilledButton(
                      onPressed: _dangHuy ? null : _huyXoa,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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
