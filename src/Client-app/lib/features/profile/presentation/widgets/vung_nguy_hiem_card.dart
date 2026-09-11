import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/dem_nguoc_xoa.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/huy_yeu_cau_xoa.dart';

/// Thẻ "Vùng nguy hiểm" ở Cài đặt — hai trạng thái (spec cưỡng chế đăng xuất §5.3).
///
/// - Tài khoản hoạt động: như trước — dẫn vào trang Xoá tài khoản.
/// - Đang chờ xoá: Stitch `13a6c1f6adac41ce8ed89e6f248f511f` — hộp đếm số ngày,
///   ngày xoá và nút huỷ. Trang Xoá tài khoản không còn nút huỷ (§5.4), nên thẻ
///   này cùng thẻ ở Trang chủ là hai chỗ huỷ. ⚠️ Stitch tự áp hệ "Kinetic
///   Clarity" cho màn ấy — màu và cỡ chữ lấy theo spec, không theo token của hệ kia.
class VungNguyHiemCard extends StatefulWidget {
  const VungNguyHiemCard({
    super.key,
    required this.user,
    this.authRepository,
    this.now,
  });

  final UserModel? user;

  /// `null` = lấy từ `sl`; test tiêm thẳng.
  final AuthRepository? authRepository;
  final DateTime Function()? now;

  @override
  State<VungNguyHiemCard> createState() => _VungNguyHiemCardState();
}

class _VungNguyHiemCardState extends State<VungNguyHiemCard> {
  static const _mauDo = Color(0xFFBA1A1A);

  bool _dangHuy = false;

  Future<void> _huyXoa() async {
    setState(() => _dangHuy = true);
    await huyYeuCauXoa(context, widget.authRepository ?? sl<AuthRepository>());
    if (mounted) setState(() => _dangHuy = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD6).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mauDo.withValues(alpha: 0.2), width: 2),
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
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _mauDo),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Vùng nguy hiểm (Danger Zone)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _mauDo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (user != null && user.dangChoXoa)
            ..._noiDungChoXoa(user)
          else
            ..._noiDungHoatDong(context),
        ],
      ),
    );
  }

  List<Widget> _noiDungHoatDong(BuildContext context) {
    return [
      const Text(
        'Khi gửi yêu cầu xóa tài khoản, tất cả lịch sử giao dịch, ví tiền và mục tiêu sẽ bị đóng vĩnh viễn sau 30 ngày khôi phục.',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: () => context.push('/settings/delete-account'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF1453B),
          side: const BorderSide(color: Color(0xFFF1453B), width: 2),
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Yêu cầu xóa tài khoản',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ];
  }

  List<Widget> _noiDungChoXoa(UserModel user) {
    final soNgay = soNgayConLai(
      countdown: user.countdown,
      nhanLuc: user.countdownNhanLuc,
      now: (widget.now ?? DateTime.now)(),
    );
    final ngayXoa = ngayXoaVinhVien(
      countdown: user.countdown,
      nhanLuc: user.countdownNhanLuc,
    );
    const chuPhu =
        TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5);
    return [
      if (soNgay != null && ngayXoa != null)
        Container(
          key: const Key('hop-dem-cho-xoa'),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$soNgay',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: _mauDo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'ngày còn lại',
                      style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tài khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn vào ${DateFormat('dd/MM/yyyy').format(ngayXoa)}.',
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: AppColors.textPrimary),
              ),
            ],
          ),
        )
      else
        const Text(
          'Tài khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn khi hết thời hạn chờ.',
          style: chuPhu,
        ),
      const SizedBox(height: 16),
      const Text(
        'Trong thời gian này bạn vẫn dùng app bình thường. Huỷ yêu cầu để giữ lại tài khoản.',
        style: chuPhu,
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: _dangHuy ? null : _huyXoa,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _dangHuy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Huỷ yêu cầu xoá',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    ];
  }
}
