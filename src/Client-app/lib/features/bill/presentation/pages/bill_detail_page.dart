import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/auth/current_account.dart';
import '../../../../core/bill/bill_recurrence.dart';
import '../../../../core/category/category_visuals.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../transaction/domain/transaction_lookup.dart';
import '../../domain/bill_chain.dart';
import '../../domain/bill_status.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_state.dart';
import '../widgets/bill_actions.dart';
import '../widgets/bill_status_visuals.dart';

/// Trang chi tiết một hoá đơn (`/bills/:id`), mở khi chạm một dòng chưa trả.
///
/// Đọc CSDL trực tiếp như trang chi tiết mục tiêu (một lần lúc mở, và đọc
/// lại sau mỗi thao tác thành công) chứ không bắt `BillBloc` mang thêm trạng
/// thái cho một hoá đơn. Thao tác thì vẫn đi qua `BillBloc` để dùng chung ba
/// luồng trả / hoàn tác / xoá với trang danh sách.
///
/// "Lịch sử các kỳ" lần theo `generatedFromBillId` — cột **cục bộ** (v16),
/// nên hoá đơn kéo về từ server chỉ có một dòng lịch sử; đừng đoán theo tên.
class BillDetailPage extends StatefulWidget {
  final String id;

  /// Ảnh chụp từ danh sách, để vẽ ngay trong lúc đọc CSDL. Có thể cũ.
  final Bill? bill;

  /// Tiêm được để test không phụ thuộc ngày chạy.
  final DateTime? now;

  const BillDetailPage({super.key, required this.id, this.bill, this.now});

  @override
  State<BillDetailPage> createState() => _BillDetailPageState();
}

class _BillDetailPageState extends State<BillDetailPage> {
  Bill? _bill;
  List<Bill> _chuoi = const [];
  Map<String, Transaction> _khoanChi = const {};
  TransactionLookup _lookup = TransactionLookup.empty;
  bool _dangTai = true;

  static final _ngay = DateFormat('dd/MM/yyyy');
  @override
  void initState() {
    super.initState();
    _bill = widget.bill;
    if (_bill != null) _chuoi = [_bill!];
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    final db = sl<AppDatabase>();
    final bill = await db.billDao.getById(widget.id);
    if (!mounted) return;
    if (bill == null) {
      setState(() {
        _bill = null;
        _dangTai = false;
      });
      return;
    }

    // `idaccount` chỉ lấy từ phiên (quy tắc 2). Không có phiên thì vẫn vẽ
    // được hoá đơn, chỉ thiếu tên ví/danh mục và lịch sử.
    final accountId = currentAccountIdOrNull(context);
    var tatCa = <Bill>[bill];
    var khoanChi = <String, Transaction>{};
    var lookup = TransactionLookup.empty;
    if (accountId != null) {
      tatCa = await db.billDao.getAll(accountId);
      khoanChi = await db.transactionDao.getBillPayments(accountId);
      final vi = await db.walletDao.getAll(accountId);
      final dm = await db.categoryDao.getAll(accountId);
      lookup = TransactionLookup(wallets: vi, categories: dm);
    }
    if (!mounted) return;
    setState(() {
      _bill = bill;
      _chuoi = chuoiKyCua(tatCa, bill.id);
      if (_chuoi.isEmpty) _chuoi = [bill];
      _khoanChi = khoanChi;
      _lookup = lookup;
      _dangTai = false;
    });
  }

  Future<void> _sua(Bill b) async {
    await context.push('/bills/${b.id}/edit', extra: b);
    if (mounted) _nap();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final b = _bill;

    return BlocListener<BillBloc, BillState>(
      listener: (context, state) {
        if (state is BillOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          // Xoá xong thì không còn gì để xem — quay về danh sách.
          if (state.message.startsWith('Xóa')) {
            final nav = Navigator.of(context);
            if (nav.canPop()) nav.pop();
            return;
          }
          _nap();
        } else if (state is BillError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          centerTitle: false,
          title: Text(
            b?.name ?? 'Chi tiết hoá đơn',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          actions: b == null
              ? null
              : [
                  IconButton(
                    key: const ValueKey('bill-detail-edit'),
                    tooltip: 'Sửa',
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.primary),
                    onPressed: () => _sua(b),
                  ),
                  IconButton(
                    key: const ValueKey('bill-detail-delete'),
                    tooltip: 'Xoá',
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error),
                    onPressed: () => hoiXoaHoaDon(context, b.id),
                  ),
                ],
        ),
        body: b == null
            ? Center(
                child: _dangTai
                    ? const CircularProgressIndicator()
                    : const Text('Không tìm thấy hoá đơn',
                        style: TextStyle(color: AppColors.textSecondary)),
              )
            : _noiDung(context, b, now),
      ),
    );
  }

  Widget _noiDung(BuildContext context, Bill b, DateTime now) {
    final status = billDisplayStatusOf(b, now);
    final danhMuc = _lookup.category(b.categoryId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _theDauTrang(b, status, danhMuc),
        const SizedBox(height: 16),
        _theThongTin(b, danhMuc),
        const SizedBox(height: 16),
        _theLichSu(b, now),
        const SizedBox(height: 24),
        _nutThaoTac(context, b, status),
      ],
    );
  }

  BoxDecoration get _the => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0DB)),
      );

  Widget _theDauTrang(Bill b, BillDisplayStatus status, Category? danhMuc) {
    final mauDanhMuc =
        categoryColorFrom(danhMuc?.colour, fallback: AppColors.primary);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _the,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: mauDanhMuc.withValues(alpha: 0.12),
                child: Icon(categoryIconFor(danhMuc?.icon), color: mauDanhMuc),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hạn ${_ngay.format(b.dueDate)}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  CurrencyFormatter.format(b.amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _nhan(status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nhan(BillDisplayStatus status) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: mauNenTrangThaiHoaDon(status),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          nhanTrangThaiHoaDon(status),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: mauChuTrangThaiHoaDon(status),
          ),
        ),
      );

  Widget _tieuDe(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _dong(String nhan, String giaTri, {Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(nhan,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(
                giaTri,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary),
              ),
            ),
          ],
        ),
      );

  Widget _theThongTin(Bill b, Category? danhMuc) {
    // Ba trạng thái danh mục, cùng cách đọc với trang danh sách.
    final tenDanhMuc = b.categoryId == null
        ? 'Chưa có danh mục'
        : (danhMuc?.name ?? 'Danh mục đã xoá');
    final nhac = b.timeNotification;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: _the,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tieuDe('THÔNG TIN'),
          _dong('Đến hạn', _ngay.format(b.dueDate)),
          _dong('Chu kỳ',
              b.isRecurrence ? tenChuKyHoaDon(b.timeRecurrence) : 'Không lặp'),
          _dong('Ví trả', _lookup.walletName(b.walletId)),
          _dong('Danh mục', tenDanhMuc),
          _dong('Nhắc trước',
              (nhac == null || nhac.isEmpty) ? 'Không nhắc' : '$nhac ngày'),
          // Trang chi tiết là nơi duy nhất nói rõ app có tự trừ tiền hay không.
          _dong(
            'Tự động trả',
            b.autoPayEnabled ? 'Bật — trừ ví đúng ngày đến hạn' : 'Tắt',
            key: const ValueKey('bill-detail-autopay'),
          ),
          if (b.note.trim().isNotEmpty) _dong('Ghi chú', b.note.trim()),
        ],
      ),
    );
  }

  Widget _theLichSu(Bill hienTai, DateTime now) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: _the,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tieuDe('LỊCH SỬ CÁC KỲ'),
          for (var i = 0; i < _chuoi.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _dongLichSu(_chuoi[i],
                laHienTai: _chuoi[i].id == hienTai.id, now: now),
          ],
        ],
      ),
    );
  }

  Widget _dongLichSu(Bill b, {required bool laHienTai, required DateTime now}) {
    final status = billDisplayStatusOf(b, now);
    final tra = _khoanChi[b.id];
    // Chữ thường, khác nhãn IN HOA ở đầu trang, để không lẫn hai thứ.
    final phu = switch (status) {
      BillDisplayStatus.paid =>
        tra == null ? 'Đã trả' : 'Trả ${_ngay.format(tra.date)}',
      BillDisplayStatus.overdue => 'Quá hạn',
      BillDisplayStatus.dueSoon => 'Sắp đến hạn',
      BillDisplayStatus.pending => 'Chưa trả',
    };
    return Padding(
      key: ValueKey('bill-history-${b.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mauVachTrangThaiHoaDon(status),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kỳ ${_ngay.format(b.dueDate)}${laHienTai ? ' (đang xem)' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: laHienTai ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  phu,
                  style: TextStyle(
                      fontSize: 12, color: mauChuTrangThaiHoaDon(status)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CurrencyFormatter.format(b.amount),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _nutThaoTac(BuildContext context, Bill b, BillDisplayStatus status) {
    if (status == BillDisplayStatus.paid) {
      return OutlinedButton.icon(
        key: const ValueKey('bill-detail-undo'),
        onPressed: () => hoiHoanTacHoaDon(context, b),
        icon: const Icon(Icons.undo, size: 18),
        label: const Text('Hoàn tác thanh toán'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    return ElevatedButton.icon(
      key: const ValueKey('bill-detail-pay'),
      onPressed: () => moBangThanhToanHoaDon(context, b),
      icon: const Icon(Icons.payments_outlined, size: 18),
      label: const Text('Thanh toán'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
