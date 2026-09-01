import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_colors.dart';
import '../bloc/auth_bloc.dart';

/// Màn hình nhập OTP trong luồng đăng ký mới.
///
/// Nhận [RegisterOtpSent] state qua route extra, dispatch:
/// - [RegisterVerifyOtpSubmitted] khi người dùng submit OTP
/// - [RegisterSendOtpRequested] khi người dùng nhấn "Gửi lại"
class RegisterOtpPage extends StatefulWidget {
  final RegisterOtpSent registerState;

  const RegisterOtpPage({super.key, required this.registerState});

  @override
  State<RegisterOtpPage> createState() => _RegisterOtpPageState();
}

class _RegisterOtpPageState extends State<RegisterOtpPage> {
  static const int _otpLength = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String get _otp => _controllers.map((c) => c.text).join();

  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  void _onDigitChanged(String value, int index) {
    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  void _handleSubmit() {
    if (_otp.length < _otpLength) return;
    context.read<AuthBloc>().add(
          RegisterVerifyOtpSubmitted(
            username: widget.registerState.username,
            fullname: widget.registerState.fullname,
            email: widget.registerState.email,
            password: widget.registerState.password,
            otp: _otp,
            phone: widget.registerState.phone,
          ),
        );
  }

  void _handleResend() {
    _clearOtp();
    context.read<AuthBloc>().add(
          RegisterSendOtpRequested(
            username: widget.registerState.username,
            fullname: widget.registerState.fullname,
            email: widget.registerState.email,
            password: widget.registerState.password,
            phone: widget.registerState.phone,
            isResend: true,
          ),
        );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is RegistrationCompleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đăng ký thành công. Vui lòng đăng nhập.'),
            ),
          );
          context.go('/login');
        } else if (state is RegisterOtpSent) {
          // Gửi lại OTP thành công → thông báo và reset input
          setState(() {
            _errorMessage = null;
            _isLoading = false;
          });
          _clearOtp();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã gửi lại mã OTP. Kiểm tra email của bạn.'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is RegisterOtpError) {
          setState(() {
            _errorMessage = state.message;
            _isLoading = false;
          });
          _clearOtp();
        }
        if (mounted) {
          setState(() => _isLoading = state is RegisterOtpLoading);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: AppColors.primary, size: 24),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Xác thực Email',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Icon header ──────────────────────────────────────
                    Container(
                      alignment: Alignment.center,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          color: AppColors.income,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Description ──────────────────────────────────────
                    const Text(
                      'Nhập mã xác thực 6 số đã được gửi đến',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.registerState.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mã có hiệu lực trong 10 phút.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── OTP input card ───────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              AppColors.outlineVariant.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // OTP digit boxes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(_otpLength, (i) {
                              return SizedBox(
                                width: 45,
                                child: TextFormField(
                                  controller: _controllers[i],
                                  focusNode: _focusNodes[i],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(1),
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (v) => _onDigitChanged(v, i),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: AppColors.outlineVariant),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppColors.income,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              );
                            }),
                          ),

                          // Error message
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(10),
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
                                        color: AppColors.error,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Submit button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.income,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Xác nhận',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),

                          const SizedBox(height: 12),

                          // Resend button
                          TextButton(
                            onPressed: _isLoading ? null : _handleResend,
                            child: const Text(
                              'Gửi lại mã OTP',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
