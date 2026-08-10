import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_colors.dart';
import '../bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) return;
    // Dùng AuthBloc từ root (main.dart) — không tạo mới
    context.read<AuthBloc>().add(
      LoginSubmitted(email: username, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe AuthBloc từ root
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          context.go('/home');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        if (mounted) {
          setState(() => _isLoading = state is AuthLoading);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Header
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet,
                                  color: AppColors.primary, size: 28),
                              SizedBox(width: 8),
                              Text(
                                'FlowMoney',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: -0.01,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Main Content
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            children: [
                              const SizedBox(height: 32),
                              const Text(
                                'Chào mừng trở lại',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.02,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Quản lý dòng tiền của bạn một cách thông minh.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Form Card
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Username Field
                                    const Text(
                                      'TÊN ĐĂNG NHẬP',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.02,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _usernameController,
                                      keyboardType: TextInputType.text,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(
                                            Icons.person_outline,
                                            color: AppColors.outline),
                                        hintText: 'username',
                                        hintStyle: const TextStyle(
                                            color: AppColors.outlineVariant),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.outlineVariant),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.primary),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 14),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Password Label Row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'MẬT KHẨU',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                            letterSpacing: 0.02,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => context
                                              .push('/forgot-password'),
                                          child: const Text(
                                            'Quên mật khẩu?',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(
                                            Icons.lock_outline,
                                            color: AppColors.outline),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                            color: AppColors.outline,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                        hintText: '••••••••',
                                        hintStyle: const TextStyle(
                                            color: AppColors.outlineVariant),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.outlineVariant),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.primary),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 14),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Submit Button
                                    ElevatedButton(
                                      onPressed:
                                          _isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        minimumSize:
                                            const Size(double.infinity, 48),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2),
                                            )
                                          : const Text(
                                              'Đăng nhập',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),

                                    const SizedBox(height: 24),
                                    const Row(
                                      children: [
                                        Expanded(
                                            child: Divider(
                                                color:
                                                    AppColors.outlineVariant)),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16),
                                          child: Text(
                                            'hoặc tiếp tục với',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                            child: Divider(
                                                color:
                                                    AppColors.outlineVariant)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {},
                                            icon: const Icon(
                                                Icons.g_mobiledata,
                                                size: 24,
                                                color: AppColors.primary),
                                            label: const Text('Google',
                                                style: TextStyle(
                                                    color:
                                                        AppColors.textPrimary)),
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(0, 44),
                                              side: const BorderSide(
                                                  color:
                                                      AppColors.outlineVariant),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {},
                                            icon: const Icon(Icons.apple,
                                                size: 20,
                                                color: AppColors.primary),
                                            label: const Text('Apple',
                                                style: TextStyle(
                                                    color:
                                                        AppColors.textPrimary)),
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(0, 44),
                                              side: const BorderSide(
                                                  color:
                                                      AppColors.outlineVariant),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Footer
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: 24, top: 48),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Chưa có tài khoản? ',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => context.push('/register'),
                                    child: const Text(
                                      'Đăng ký ngay',
                                      style: TextStyle(
                                        color: AppColors.income,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '© 2024 FlowMoney',
                                style: TextStyle(
                                  color: Color(0xFF868382),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
