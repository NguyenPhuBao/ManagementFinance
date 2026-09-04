import 'dart:async';
import 'package:flutter/material.dart';

import '../widgets/bank_header_row.dart';
import 'package:go_router/go_router.dart';

class BankLinkPage extends StatefulWidget {
  const BankLinkPage({super.key});

  @override
  State<BankLinkPage> createState() => _BankLinkPageState();
}

class _BankLinkPageState extends State<BankLinkPage> {
  final TextEditingController _usernameController = TextEditingController(text: '0912345678');
  final TextEditingController _passwordController = TextEditingController(text: '••••••••');
  bool _isPasswordVisible = false;
  bool _isConsentChecked = true;

  // OTP 6 digits controllers
  final List<TextEditingController> _otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (index) => FocusNode());

  int _countdownSeconds = 105;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Default OTP values matching mockup
    const defaultOtp = ['4', '8', '2', '9', '1', '0'];
    for (int i = 0; i < 6; i++) {
      _otpControllers[i].text = defaultOtp[i];
    }
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        setState(() => _countdownSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _formattedCountdown {
    final mins = (_countdownSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_countdownSeconds % 60).toString().padLeft(2, '0');
    return '($mins:$secs)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00020D)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Liên kết Ngân hàng',
          style: TextStyle(
            color: Color(0xFF00020D),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF96F592).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.verified_user,
              color: Color(0xFF006E1C),
              size: 20,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Selected Bank Card
            _buildCardContainer(
              child: BankHeaderRow(
                bankName: 'Ngân hàng Techcombank',
                statusText: 'Đang kết nối API',
                chipText: 'Cổng API an toàn',
                logo: Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCbBMyxzF8X2Mvv9v8aDAWt8nTEj1xxX5P3qmWPGx7XRMPrweLKXtax2dg0i7Eo15XPulnC0oHJqF8Zgvx-90MBy34ng1hmN3NFASKVTdNUpguZMI11pzNu_8URZdqPe2pxmLeZm-Og1buJBpfE-jrYq2qe8Kkc-dRLviNlrPdwmmLx4dVkg3xTPF-DObefpihkp7JTC47dIx-jAzJlkIOpdWR_tgJk3_kvHz4PN_83ZuzJ5-cFB6zjF9suRWQZFxscXN8oNvu43EU',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Login Form Card
            _buildCardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock_outlined, color: Color(0xFF808498), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Đăng nhập Bank API',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00020D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('TÊN ĐĂNG NHẬP / SĐT'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF4F4F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF00020D)),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('MẬT KHẨU INTERNET BANKING'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF4F4F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: const Color(0xFF46464C),
                        ),
                        onPressed: () {
                          setState(() => _isPasswordVisible = !_isPasswordVisible);
                        },
                      ),
                    ),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF00020D)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFF1453B), width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Xác thực tài khoản',
                        style: TextStyle(
                          color: Color(0xFFF1453B),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // OTP Verification Card
            _buildCardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nhập mã xác thực OTP',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00020D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mã OTP 6 chữ số đã được gửi qua SMS.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF46464C),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 44,
                        height: 52,
                        child: TextField(
                          controller: _otpControllers[index],
                          focusNode: _otpFocusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00020D),
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFFEEEEEA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE8E8E4)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE8E8E4)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF181C2C), width: 2),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _otpFocusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _otpFocusNodes[index - 1].requestFocus();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Không nhận được mã? ',
                        style: TextStyle(fontSize: 13, color: Color(0xFF46464C)),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _countdownSeconds = 120);
                        },
                        child: const Text(
                          'Gửi lại mã ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF006E1C),
                          ),
                        ),
                      ),
                      Text(
                        _formattedCountdown,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF77767D),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Consent & Final Button
            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _isConsentChecked,
                      onChanged: (val) => setState(() => _isConsentChecked = val ?? false),
                      fillColor: WidgetStateProperty.resolveWith<Color>(
                        (states) => states.contains(WidgetState.selected)
                            ? const Color(0xFF00020D)
                            : Colors.transparent,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Ủy quyền cho FlowMoney đọc tự động biến động số dư và lịch sử giao dịch thông qua cổng API mã hóa.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF46464C),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isConsentChecked
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Liên kết ngân hàng thành công!')),
                            );
                            context.pop();
                          }
                        : null,
                    icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    label: const Text(
                      'Hoàn tất Liên kết Ngân hàng',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF181C2C),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Security Footer Badge
            Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFFC7C6CD), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'AES-256 BANKING STANDARD ENCRYPTION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC7C6CD),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'PCI-DSS • ISO 27001 • Norton Secured',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFFC7C6CD).withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF46464C),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
