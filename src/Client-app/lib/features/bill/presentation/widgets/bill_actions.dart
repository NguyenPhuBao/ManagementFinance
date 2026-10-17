import '../../../category/data/repositories/category_management_repository.dart';
import '../../../wallet/data/repositories/wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/bloc/current_account.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../data/models/bill_entity.dart';
import '../../domain/bill_nhac_truoc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import 'bill_payment_sheet.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';

/// Ba luồng thao tác trên một hoá đơn, dùng chung cho trang danh sách và
/// trang chi tiết. Đều bắn sự kiện vào `BillBloc` của [context]; nơi gọi tự
/// lắng `BillOperationSuccess`/`BillError` để báo và nạp lại.

/// [soNgayNhac]: ngưỡng nhãn "Sắp đến hạn" trang đang dùng (tuỳ chọn "Nhắc
/// trước"), để nhãn trên bảng khớp nhãn của dòng vừa chạm.
Future<void> moBangThanhToanHoaDon(BuildContext context, BillEntity bill,
    {int soNgayNhac = mocNhacMacDinh}) async {
  // Không có phiên thì không có ví nào để thanh toán bằng. Trước đây chỗ này
  // rơi về idaccount = 1 rồi, khi tài khoản đó chưa có ví, còn đọc tiếp
  // `getAllNonDeleted()` — bày ra ví của tài khoản khác trên cùng máy.
  final accountId = currentAccountIdOrNull(context);
  final wallets =
      accountId == null ? <WalletEntity>[] : await sl<WalletRepository>().getActive(accountId);
  // Tên danh mục cho khối thông tin trên bảng; không có/đã xoá thì bỏ trống.
  final danhMuc = bill.categoryId == null
      ? null
      : await sl<CategoryManagementRepository>().getById(bill.categoryId!);

  if (!context.mounted) return;

  if (accountId == null || wallets.isEmpty) {
    baoNhanh('Vui lòng tạo ít nhất 1 ví trước khi thanh toán.', loai: LoaiThongBao.loi);
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
      soNgayNhacMacDinh: soNgayNhac,
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
///
/// [coKhoanTra]: kỳ có khoản chi gắn `billId` trong bản đồ khoản chi của trang
/// (`paymentsOf`). Không có — khoản trả ghi bằng bản app cũ, có thể đã xoá ở
/// Sổ — thì hoàn tiền là không làm được (`BillUndoUnavailableException`), nên
/// hỏi đưa kỳ về chưa trả **không hoàn tiền** (`DatLaiChuaTraEvent`). Bản đồ
/// không bao giờ chứa khoản kiểu cũ (nó không có `billId`), nên rẽ theo nó
/// không phải đoán.
///
/// [kySau]: kỳ sau mà lần đưa về chưa trả sẽ gỡ — `kySauConPhaiTra` trên danh
/// sách hoá đơn của trang; `null` thì hộp không nhắc kỳ sau.
void hoiHoanTacHoaDon(BuildContext context, BillEntity bill,
    {required bool coKhoanTra, BillEntity? kySau}) {
  if (!coKhoanTra) {
    _hoiDuaVeChuaTra(context, bill, kySau);
    return;
  }
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

/// Hộp của kỳ không còn khoản chi gắn `billId`: về chưa trả, không đụng ví.
///
/// Câu "hãy xoá nó ở đó trước" là chốt duy nhất cho khoản kiểu cũ còn sống ở
/// Sổ — app không đoán được khoản nào (tiền tố ghi chú + số tiền + ngày là
/// phép so `billId` sinh ra để thay), và để nó sống rồi trả lại là hai khoản
/// chi cho một kỳ.
///
/// Vế kỳ kế tiếp chỉ có khi [kySau] có — `datLaiChuaTra` chỉ gỡ kỳ sau **nối
/// chuỗi** còn phải trả. Kỳ kiểu cũ thường tạo trước cột nối, nên kỳ cùng tên
/// kế đó không phải "kỳ sau" của nó và vẫn còn sau khi bấm; nhắc vế ấy cho mọi
/// hoá đơn lặp là hứa sai (máy ảo 2026-10-17, người dùng chốt).
void _hoiDuaVeChuaTra(BuildContext context, BillEntity bill, BillEntity? kySau) {
  final veKySau = kySau == null
      ? ''
      : ' và gỡ kỳ kế tiếp (hạn '
          '${DateFormat('dd/MM/yyyy').format(kySau.dueDate)}, chưa trả)';
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hoàn tác thanh toán'),
      content: Text(
        'Không tìm thấy khoản chi của lần trả này — nó được ghi bằng bản ứng '
        'dụng cũ. Nếu khoản ấy còn ở Sổ giao dịch, hãy xoá nó ở đó trước; bước '
        'này không đổi số dư ví.\n\n'
        'Đưa kỳ "${bill.name}" về chưa thanh toán$veKySau?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.read<BillBloc>().add(DatLaiChuaTraEvent(billId: bill.id));
          },
          child: const Text('Đưa về chưa trả'),
        ),
      ],
    ),
  );
}

/// Hỏi trước khi bỏ qua: thao tác này đóng kỳ mà không trả đồng nào, và với
/// hoá đơn lặp thì còn tạo kỳ kế tiếp — nói rõ cả ba trước khi làm.
///
/// Câu chữ đi theo `isRecurrence`: nói "kỳ kế tiếp vẫn được tạo" cho một hoá
/// đơn không lặp là hứa một thứ không xảy ra.
void hoiBoQuaKyHoaDon(BuildContext context, BillEntity bill) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Bỏ qua kỳ này'),
      content: Text(
        'Kỳ đến hạn của "${bill.name}" sẽ được đánh dấu là bỏ qua: '
        'không trừ tiền ví, không ghi khoản chi nào'
        '${bill.isRecurrence ? ', và kỳ kế tiếp vẫn được tạo' : ''}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.read<BillBloc>().add(SkipBillEvent(billId: bill.id));
          },
          child: const Text('Bỏ qua'),
        ),
      ],
    ),
  );
}

/// Hỏi trước khi hoàn tác việc bỏ qua. Không có bước hoàn tiền nào để nói —
/// lần bỏ qua chưa từng trừ tiền.
void hoiHoanTacBoQua(BuildContext context, BillEntity bill) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hoàn tác bỏ qua'),
      content: Text(
        'Hoá đơn "${bill.name}" quay lại trạng thái chưa thanh toán'
        '${bill.isRecurrence ? ', và kỳ kế tiếp đã tạo sẽ bị gỡ' : ''}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.read<BillBloc>().add(UndoSkipEvent(billId: bill.id));
          },
          child: const Text('Hoàn tác'),
        ),
      ],
    ),
  );
}

/// Hỏi qua màn xác nhận xoá (`/bills/:id/delete`, `BillDeletePage`) — lối chung của ba chỗ xoá: thùng rác trên thẻ
/// danh sách, nút xoá ở trang Chi tiết, nút "Xóa hóa đơn" ở form Sửa. Trang chỉ hỏi; xác nhận thì gửi
/// `DeleteBillEvent` vào `BillBloc` của [context]. Trả `true` khi đã gửi — form Sửa dựa vào đó để tự đóng.
///
/// [bill] là ảnh chụp để trang vẽ ngay; trang vẫn đọc lại theo [billId].
Future<bool> xacNhanXoaHoaDon(BuildContext context, String billId, {BillEntity? bill}) async {
  final dongY = await context.push<bool>('/bills/$billId/delete', extra: bill);
  if (dongY != true || !context.mounted) return false;
  context.read<BillBloc>().add(DeleteBillEvent(id: billId));
  return true;
}
