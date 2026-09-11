import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, this.authRepository});

  /// `null` = lấy từ `sl`; test tiêm thẳng.
  final AuthRepository? authRepository;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  late final AuthRepository _authRepository =
      widget.authRepository ?? sl<AuthRepository>();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  /// Gửi yêu cầu xóa tài khoản (đặt PendingDelete + ân hạn 30 ngày)
  void _handleDelete() async {
    if (!_formKey.currentState!.validate()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.schedule, color: Color(0xFFBA1A1A)),
            SizedBox(width: 8),
            Flexible(
              child: Text('Xác nhận yêu cầu xóa', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: const Text(
          'Tài khoản của bạn sẽ được đặt vào trạng thái chờ xóa trong 30 ngày.\n\n'
          'Sau 30 ngày, tài khoản sẽ bị xóa vĩnh viễn.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => ctx.pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Lấy Bloc TRƯỚC await: nút quay lại bấm được cả lúc đang gửi, nên khi server
    // trả lời trang có thể đã rời cây — lúc ấy không còn `context` để đọc.
    final authBloc = context.read<AuthBloc>();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authRepository.deleteAccount(_passwordController.text);
      // Repository đã ghi PendingDelete vào bộ nhớ đệm: báo Bloc NGAY, dù trang
      // còn hay đã rời cây. Chờ tới sau hộp thoại (bản trước) thì rời trang giữa
      // chừng là AuthSuccess vẫn Active — Trang chủ không có thẻ nhắc, Cài đặt vẫn
      // mời gửi yêu cầu (soát cuối G33). Chỉ setState, hộp thoại và điều hướng
      // mới cần trang còn gắn.
      authBloc.add(ThongTinTaiKhoanThayDoi());
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Báo đã ghi nhận. KHÔNG đăng xuất — backend cho dùng tiếp 30 ngày (G33).
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF006E1C)),
              SizedBox(width: 8),
              Flexible(
                child: Text('Yêu cầu đã được ghi nhận'),
              ),
            ],
          ),
          content: const Text(
            'Bạn vẫn dùng app bình thường trong 30 ngày, và huỷ được bất cứ lúc nào ở Trang chủ hoặc Cài đặt.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => ctx.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 24),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Yêu cầu xóa tài khoản',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Banner cảnh báo ân hạn ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.schedule, color: Color(0xFFE65100), size: 64),
                        SizedBox(height: 12),
                        Text(
                          'Ân hạn 30 ngày',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tài khoản sẽ không bị xoá ngay lập tức. Bạn có 30 ngày để đổi ý — huỷ yêu cầu ở Trang chủ hoặc Cài đặt.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF5D4037),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Timeline các mốc thời gian ---
                  _buildTimeline(),
                  const SizedBox(height: 24),

                  // --- Form nhập mật khẩu ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Nhập mật khẩu để xác nhận',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Vui lòng nhập mật khẩu để xác nhận';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: 'Mật khẩu của bạn',
                              hintStyle: TextStyle(
                                color: AppColors.outlineVariant.withValues(alpha: 0.8),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.outlineVariant),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFBA1A1A),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.error),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.error,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppColors.error, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                          color: AppColors.error, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleDelete,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBA1A1A),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Gửi yêu cầu xóa tài khoản',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Điều gì sẽ xảy ra?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          _timelineStep(
            icon: Icons.hourglass_top,
            color: const Color(0xFFBA1A1A),
            title: 'Ngay lập tức',
            desc:
                'Tài khoản chuyển sang chờ xoá, bạn vẫn dùng app bình thường.',
          ),
          _timelineDivider(),
          _timelineStep(
            icon: Icons.restore,
            color: const Color(0xFF0066CC),
            title: 'Trong 30 ngày',
            desc: 'Huỷ yêu cầu ở Trang chủ hoặc Cài đặt.',
          ),
          _timelineDivider(),
          _timelineStep(
            icon: Icons.delete_forever,
            color: const Color(0xFF777777),
            title: 'Sau 30 ngày',
            desc:
                'Tài khoản và toàn bộ dữ liệu bị xóa vĩnh viễn, không thể phục hồi.',
          ),
        ],
      ),
    );
  }

  Widget _timelineStep({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timelineDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 17, top: 4, bottom: 4),
      child: Container(
        width: 2,
        height: 20,
        color: AppColors.outlineVariant,
      ),
    );
  }
}
