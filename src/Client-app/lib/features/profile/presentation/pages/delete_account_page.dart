import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isCancelLoading = false;
  String? _errorMessage;

  final AuthRepository _authRepository = sl<AuthRepository>();

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
          'Trong thời gian này, bạn có thể đăng nhập lại để hủy yêu cầu và khôi phục tài khoản.\n\n'
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authRepository.deleteAccount(_passwordController.text);
      if (!mounted) return;

      // Hiện dialog thông báo thành công trước khi logout
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
            'Tài khoản của bạn sẽ bị xóa sau 30 ngày.\n\n'
            'Để hủy yêu cầu, hãy đăng nhập lại trong vòng 30 ngày — hệ thống sẽ tự động khôi phục tài khoản cho bạn.',
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
      context.read<AuthBloc>().add(LogoutRequested());
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  /// Hủy yêu cầu xóa tài khoản (nếu tài khoản đang ở PendingDelete)
  void _handleCancelDelete() async {
    setState(() {
      _isCancelLoading = true;
      _errorMessage = null;
    });
    try {
      await _authRepository.cancelDelete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yêu cầu xóa tài khoản đã được hủy thành công.'),
          backgroundColor: Color(0xFF006E1C),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCancelLoading = false;
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
                          'Tài khoản sẽ không bị xóa ngay lập tức. Bạn có 30 ngày để đổi ý và khôi phục tài khoản bằng cách đăng nhập lại.',
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
                  const SizedBox(height: 16),

                  // --- Nút hủy yêu cầu xóa ---
                  OutlinedButton.icon(
                    onPressed: _isCancelLoading ? null : _handleCancelDelete,
                    icon: _isCancelLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.undo, size: 18),
                    label: const Text('Hủy yêu cầu xóa tài khoản'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nếu bạn đã gửi yêu cầu xóa trước đó, hãy nhấn vào đây để hủy ngay.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
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
            icon: Icons.logout,
            color: const Color(0xFFBA1A1A),
            title: 'Ngay lập tức',
            desc: 'Bạn sẽ bị đăng xuất khỏi tất cả thiết bị.',
          ),
          _timelineDivider(),
          _timelineStep(
            icon: Icons.restore,
            color: const Color(0xFF0066CC),
            title: 'Trong 30 ngày',
            desc:
                'Đăng nhập lại để hủy yêu cầu — tài khoản được khôi phục tự động.',
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
