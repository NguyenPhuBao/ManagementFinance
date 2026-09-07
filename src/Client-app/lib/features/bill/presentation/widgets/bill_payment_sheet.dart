import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/bill/bill_recurrence.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/bill_status.dart';
import 'bill_status_visuals.dart';

/// Bảng thanh toán hoá đơn: **thông tin hoá đơn** ở trên, ba ô nhập (số tiền
/// thật của kỳ, ngày trả, ghi chú lần trả), ví trả, và dưới cùng một nút
/// **"Thanh toán bằng <ví>"**.
///
/// Ví mặc định là ví đã gắn với hoá đơn (`bill.Idwallet` bắt buộc phía
/// backend); không còn thì rơi về ví có cờ mặc định, rồi ví đầu danh sách.
/// "Chọn ví khác" mở danh sách để đổi — người dùng yêu cầu 2026-09-06: bấm
/// Thanh toán là thấy ngay hoá đơn nào, bao nhiêu, và một nút để trả bằng ví
/// quen thuộc, thay vì một danh sách ví phải chọn.
///
/// Số tiền hỏi ngay tại đây vì hoá đơn điện nước mỗi kỳ một số khác nhau, mà
/// đổi qua form Sửa là đổi cho MỌI kỳ sau. Ngày trả hỏi vì người dùng hay ghi
/// lại sau (trả hôm qua, hôm nay mới mở app); không cho chọn tương lai —
/// repository cũng chặn.
class BillPaymentSheet extends StatefulWidget {
  final Bill bill;
  final List<Wallet> wallets;

  /// Tên danh mục của hoá đơn để hiện trong khối thông tin; `null` = không có.
  final String? categoryName;

  /// Gọi khi bấm nút thanh toán: ví đã chọn, số tiền đã nhập, ngày trả (chỉ
  /// phần ngày) và ghi chú riêng của lần trả (`null` nếu để trống).
  final void Function(Wallet wallet, double amount, DateTime date, String? note)
      onConfirmed;

  /// "Hôm nay" cho phép tiêm — mặc định của ô ngày và trần của bộ chọn.
  final DateTime? today;

  const BillPaymentSheet({
    super.key,
    required this.bill,
    required this.wallets,
    required this.onConfirmed,
    this.categoryName,
    this.today,
  });

  @override
  State<BillPaymentSheet> createState() => _BillPaymentSheetState();
}

class _BillPaymentSheetState extends State<BillPaymentSheet> {
  late final TextEditingController _soTien;
  final _ghiChu = TextEditingController();
  late DateTime _homNay;
  late DateTime _ngay;
  Wallet? _vi;
  bool _dangChonVi = false;
  String? _loi;

  static final _dinhDangNgay = DateFormat('dd/MM/yyyy');
  static final _tien = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    // Số thô, không dấu chấm — để `CurrencyFormatter.parse` đọc như khi người
    // dùng tự gõ. Cùng quy ước với nút "Dùng số này" của form ngân sách.
    _soTien =
        TextEditingController(text: widget.bill.amount.round().toString());
    final t = widget.today ?? DateTime.now();
    _homNay = DateTime(t.year, t.month, t.day);
    _ngay = _homNay;
    _vi = _viMacDinh();
  }

  @override
  void dispose() {
    _soTien.dispose();
    _ghiChu.dispose();
    super.dispose();
  }

  /// Ví của hoá đơn → ví có cờ mặc định → ví đầu danh sách → không có.
  Wallet? _viMacDinh() {
    final ws = widget.wallets;
    if (ws.isEmpty) return null;
    for (final w in ws) {
      if (w.id == widget.bill.walletId) return w;
    }
    for (final w in ws) {
      if (w.isDefault) return w;
    }
    return ws.first;
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

  void _xacNhan() {
    final vi = _vi;
    if (vi == null) return;
    final soTien = CurrencyFormatter.parse(_soTien.text);
    if (soTien == null || soTien <= 0) {
      // Không đóng bảng: đóng rồi báo lỗi thì người dùng mất luôn số vừa gõ.
      setState(() => _loi = 'Nhập số tiền lớn hơn 0');
      return;
    }
    Navigator.pop(context);
    final ghiChu = _ghiChu.text.trim();
    widget.onConfirmed(vi, soTien, _ngay, ghiChu.isEmpty ? null : ghiChu);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    final vi = _vi;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        // Bàn phím số đẩy ô nhập lên, không che nó.
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 12),
            _khoiThongTin(b),
            const SizedBox(height: 16),
            _nhan('Số tiền kỳ này'),
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
            const SizedBox(height: 16),
            _nhan('Ngày trả'),
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
            const SizedBox(height: 16),
            _nhan('Ghi chú lần trả này (không bắt buộc)'),
            TextField(
              key: const ValueKey('bill-pay-note'),
              controller: _ghiChu,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Số công tơ, mã giao dịch…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _nhan('Trả bằng ví'),
            if (vi == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Không tìm thấy ví nào khả dụng.'),
              )
            else ...[
              _dongVi(vi),
              if (_dangChonVi) _danhSachVi(),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                key: const ValueKey('bill-pay-confirm'),
                onPressed: _xacNhan,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: Text(
                  'Thanh toán bằng ${vi.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nhan(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );

  /// Khối thông tin hoá đơn — đủ như trang chi tiết (người dùng yêu cầu
  /// 06/09: "hiện khá ít, muốn nhiều hơn"): trạng thái, đến hạn kèm còn/quá
  /// bao nhiêu ngày, khoảng kỳ, chu kỳ, danh mục, ví của hoá đơn, nhắc
  /// trước, tự động trả, ghi chú cố định của hoá đơn (khác ghi chú lần trả).
  Widget _khoiThongTin(Bill b) {
    final status = billDisplayStatusOf(b, _homNay);
    final nhac = b.timeNotification;
    String tenVi = 'Ví đã xoá';
    for (final w in widget.wallets) {
      if (w.id == b.walletId) tenVi = w.name;
    }
    return Container(
      key: const ValueKey('bill-pay-info'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                child: const Icon(Icons.receipt_long_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: mauNenTrangThaiHoaDon(status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        nhanTrangThaiHoaDon(status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: mauChuTrangThaiHoaDon(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _tien.format(b.amount),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),
          _dongThongTin('Đến hạn', _denHan(b.dueDate)),
          // Hàng kéo về từ server có thể thiếu ngày bắt đầu — bỏ hàng này.
          if (b.startDate != null)
            _dongThongTin(
                'Kỳ',
                '${_dinhDangNgay.format(b.startDate!)} → '
                    '${_dinhDangNgay.format(b.dueDate)}'),
          _dongThongTin('Chu kỳ',
              b.isRecurrence ? tenChuKyHoaDon(b.timeRecurrence) : 'Không lặp'),
          _dongThongTin(
              'Danh mục',
              b.categoryId == null
                  ? 'Chưa có danh mục'
                  : (widget.categoryName ?? 'Danh mục đã xoá')),
          _dongThongTin('Ví của hoá đơn', tenVi),
          _dongThongTin('Nhắc trước',
              (nhac == null || nhac.isEmpty) ? 'Không nhắc' : '$nhac ngày'),
          _dongThongTin('Tự động trả', b.autoPayEnabled ? 'Bật' : 'Tắt'),
          if (b.note.trim().isNotEmpty) _dongThongTin('Ghi chú', b.note.trim()),
        ],
      ),
    );
  }

  /// "dd/MM/yyyy (còn N ngày)" / "(hôm nay)" / "(quá hạn N ngày)". So theo
  /// NGÀY chứ không theo giờ: hạn 23h hôm nay vẫn là hôm nay.
  String _denHan(DateTime due) {
    final ngayHan = DateTime(due.year, due.month, due.day);
    final chenh = ngayHan.difference(_homNay).inDays;
    final phu = chenh == 0
        ? 'hôm nay'
        : chenh > 0
            ? 'còn $chenh ngày'
            : 'quá hạn ${-chenh} ngày';
    return '${_dinhDangNgay.format(due)} ($phu)';
  }

  Widget _dongThongTin(String nhan, String giaTri) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: Text(nhan,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(
                giaTri,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary),
              ),
            ),
          ],
        ),
      );

  Widget _dongVi(Wallet vi) {
    final laViCuaHoaDon = vi.id == widget.bill.walletId;
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.account_balance_wallet,
              color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                laViCuaHoaDon ? '${vi.name} (ví của hoá đơn)' : vi.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Số dư: ${_tien.format(vi.balance)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        TextButton(
          key: const ValueKey('bill-pay-other-wallet'),
          onPressed: () => setState(() => _dangChonVi = !_dangChonVi),
          child: Text(_dangChonVi ? 'Đóng' : 'Chọn ví khác'),
        ),
      ],
    );
  }

  Widget _danhSachVi() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < widget.wallets.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              key: ValueKey('bill-pay-wallet-${widget.wallets[i].id}'),
              dense: true,
              leading: Icon(
                widget.wallets[i].id == _vi?.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: AppColors.primary,
                size: 20,
              ),
              title: Text(widget.wallets[i].name),
              subtitle:
                  Text('Số dư: ${_tien.format(widget.wallets[i].balance)}'),
              onTap: () => setState(() {
                _vi = widget.wallets[i];
                _dangChonVi = false;
              }),
            ),
          ],
        ],
      ),
    );
  }
}
