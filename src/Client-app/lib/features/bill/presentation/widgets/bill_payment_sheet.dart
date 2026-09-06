import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';

/// Bảng thanh toán hoá đơn: số tiền **thật của kỳ này** + ngày trả + ví trả.
///
/// Thay cho `WalletSelectionBottomSheet` cũ, vốn chỉ hỏi ví. Hoá đơn điện
/// nước mỗi kỳ một số khác nhau, mà đổi qua form Sửa là đổi cho MỌI kỳ sau
/// chứ không riêng kỳ này — nên số tiền phải hỏi được ngay tại đây.
///
/// Ngày trả: người dùng hay ghi lại sau (trả hôm qua bằng tiền mặt, hôm nay
/// mới mở app). Không hỏi thì khoản chi luôn mang ngày mở app và thống kê
/// theo ngày lệch. Không cho chọn ngày tương lai — repository cũng chặn.
class BillPaymentSheet extends StatefulWidget {
  final List<Wallet> wallets;

  /// Số tiền ghi trên hoá đơn, điền sẵn vào ô.
  final double initialAmount;

  /// Ví đã lưu sẵn trên hoá đơn. Được đưa lên đầu và đánh dấu.
  ///
  /// Vì sao: hoá đơn **bắt buộc** có ví (`bill.Idwallet` NOT NULL phía
  /// backend) nhưng luồng trả trước đây bày ra một danh sách không gợi ý gì,
  /// nên mỗi lần trả người dùng phải nhớ lại mình đã chọn ví nào lúc tạo.
  final String? preferredWalletId;

  /// Gọi khi người dùng chọn ví: ví đã chọn, số tiền đã nhập và ngày trả
  /// (chỉ phần ngày, không giờ).
  final void Function(Wallet wallet, double amount, DateTime date) onConfirmed;

  /// "Hôm nay" cho phép tiêm — mặc định của ô ngày và trần của bộ chọn.
  final DateTime? today;

  const BillPaymentSheet({
    super.key,
    required this.wallets,
    required this.initialAmount,
    required this.onConfirmed,
    this.preferredWalletId,
    this.today,
  });

  @override
  State<BillPaymentSheet> createState() => _BillPaymentSheetState();
}

class _BillPaymentSheetState extends State<BillPaymentSheet> {
  late final TextEditingController _soTien;
  late DateTime _homNay;
  late DateTime _ngay;
  String? _loi;

  static final _dinhDangNgay = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    // Số thô, không dấu chấm — để `CurrencyFormatter.parse` đọc như khi người
    // dùng tự gõ. Cùng quy ước với nút "Dùng số này" của form ngân sách.
    _soTien =
        TextEditingController(text: widget.initialAmount.round().toString());
    final t = widget.today ?? DateTime.now();
    _homNay = DateTime(t.year, t.month, t.day);
    _ngay = _homNay;
  }

  Future<void> _chonNgay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _ngay,
      firstDate: DateTime(2020),
      // Khoản chi không được mang ngày chưa tới.
      lastDate: _homNay,
    );
    if (picked == null || !mounted) return;
    setState(() => _ngay = DateTime(picked.year, picked.month, picked.day));
  }

  @override
  void dispose() {
    _soTien.dispose();
    super.dispose();
  }

  /// Ví của hoá đơn lên đầu, thứ tự còn lại giữ nguyên.
  List<Wallet> get _xepLai {
    final uu = widget.wallets.where((w) => w.id == widget.preferredWalletId);
    if (uu.isEmpty) return widget.wallets;
    return [
      ...uu,
      ...widget.wallets.where((w) => w.id != widget.preferredWalletId),
    ];
  }

  void _chon(Wallet wallet) {
    final soTien = CurrencyFormatter.parse(_soTien.text);
    if (soTien == null || soTien <= 0) {
      // Không đóng bảng: đóng rồi báo lỗi thì người dùng mất luôn số vừa gõ.
      setState(() => _loi = 'Nhập số tiền lớn hơn 0');
      return;
    }
    Navigator.pop(context);
    widget.onConfirmed(wallet, soTien, _ngay);
  }

  @override
  Widget build(BuildContext context) {
    final danhSach = _xepLai;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        // Bàn phím số đẩy ô nhập lên, không che nó.
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thanh toán hoá đơn',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Số tiền kỳ này',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('bill-pay-amount'),
            controller: _soTien,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              suffixText: 'đ',
              errorText: _loi,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_loi != null) setState(() => _loi = null);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Ngày trả',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            key: const ValueKey('bill-pay-date'),
            onTap: _chonNgay,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
              ),
              child: Text(
                _dinhDangNgay.format(_ngay),
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Chọn ví để trừ tiền',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          if (danhSach.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Không tìm thấy ví nào khả dụng.'),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: danhSach.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final wallet = danhSach[index];
                  final laViCuaHoaDon = wallet.id == widget.preferredWalletId;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.account_balance_wallet,
                          color: AppColors.primary),
                    ),
                    title: Text(
                      wallet.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Số dư: ${CurrencyFormatter.format(wallet.balance)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: laViCuaHoaDon
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Ví của hoá đơn',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : null,
                    onTap: () => _chon(wallet),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
