import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/auth/current_account.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import 'bill_payment_sheet.dart';

/// Ba luồng thao tác trên một hoá đơn, dùng chung cho trang danh sách và
/// trang chi tiết. Đều bắn sự kiện vào `BillBloc` của [context]; nơi gọi tự
/// lắng `BillOperationSuccess`/`BillError` để báo và nạp lại.

Future<void> moBangThanhToanHoaDon(BuildContext context, Bill bill) async {
  final db = sl<AppDatabase>();
  // Không có phiên thì không có ví nào để thanh toán bằng. Trước đây chỗ này
  // rơi về idaccount = 1 rồi, khi tài khoản đó chưa có ví, còn đọc tiếp
  // `getAllNonDeleted()` — bày ra ví của tài khoản khác trên cùng máy.
  final accountId = currentAccountIdOrNull(context);
  final wallets =
      accountId == null ? <Wallet>[] : await db.walletDao.getActive(accountId);
  // Tên danh mục cho khối thông tin trên bảng; không có/đã xoá thì bỏ trống.
  final danhMuc = bill.categoryId == null
      ? null
      : await db.categoryDao.getById(bill.categoryId!);

  if (!context.mounted) return;

  if (accountId == null || wallets.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Vui lòng tạo ít nhất 1 ví trước khi thanh toán.')),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    // Bàn phím số phải đẩy được bảng lên, không che ô nhập.
    isScrollControlled: true,
    builder: (_) => BillPaymentSheet(
      bill: bill,
      wallets: wallets,
      categoryName: danhMuc?.name,
      onConfirmed: (wallet, soTien, ngay, ghiChu) {
        context.read<BillBloc>().add(
              PayBillEvent(
                bill: bill,
                walletId: wallet.id,
                idaccount: accountId,
                amount: soTien,
                occurredAt: ngay,
                note: ghiChu,
              ),
            );
      },
    ),
  );
}

/// Hỏi trước khi hoàn tác: thao tác này trả tiền lại ví, xoá khoản chi và
/// gỡ kỳ kế tiếp — ba hệ quả, nên phải nói rõ trước.
void hoiHoanTacHoaDon(BuildContext context, Bill bill) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hoàn tác thanh toán'),
      content: Text(
        'Hoàn ${CurrencyFormatter.format(bill.amount)} về ví, xoá khoản chi '
        'đã ghi${bill.isRecurrence ? ' và gỡ kỳ kế tiếp' : ''}. '
        'Hoá đơn "${bill.name}" quay lại trạng thái chưa thanh toán.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.read<BillBloc>().add(UndoPaymentEvent(billId: bill.id));
          },
          child: const Text('Hoàn tác'),
        ),
      ],
    ),
  );
}

void hoiXoaHoaDon(BuildContext context, String billId) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Xóa hóa đơn'),
      content: const Text('Bạn có chắc chắn muốn xóa hóa đơn này?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            Navigator.pop(ctx);
            context.read<BillBloc>().add(DeleteBillEvent(id: billId));
          },
          child: const Text('Xóa', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
