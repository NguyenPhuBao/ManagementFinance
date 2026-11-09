import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../data/cap_gop_quy_nguon.dart';
import '../../data/hoa_don_da_xoa_nguon.dart';
import '../../data/models/transaction_entity.dart';
import '../../domain/transaction_lookup.dart';
import '../../domain/transaction_owner.dart';
import 'transaction_row_content.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';

/// Một dòng trong sổ giao dịch: vuốt trái để xoá.
///
/// Khoản thuộc mục tiêu, hay khoản trả của hoá đơn còn sống, thì `confirmDismiss` trả `false` — hàng bật lại và một
/// câu chỉ đường tới nơi xoá đúng — vì xoá ở đây chỉ hoàn ví, không đụng tới bộ đếm/cờ của thực thể kia (xem
/// `transactionOwnerOf`). Khoản trả hoá đơn kiểu cũ / mồ côi (việc 4c) thì hỏi xác nhận kèm câu cảnh báo
/// (`canhBaoXoaTaiSo`); giao dịch thường vẫn vuốt là xoá.
/// Nội dung hiển thị do [buildTransactionRowContent] tính. Tách khỏi
/// `TransactionPage` để test được mà không cần `sl` lẫn `AuthBloc`.
class TransactionListRow extends StatelessWidget {
  const TransactionListRow({
    super.key,
    required this.transaction,
    required this.onDelete,
    this.lookup,
    this.onTap,
    this.nguonHoaDonDaXoa,
    this.hoiCap,
    this.onXoaCap,
  });

  final TransactionEntity transaction;
  final VoidCallback onDelete;

  /// Đợt 1B Task 9 — hỏi "nửa riêng này còn cặp góp / rút không". Còn cặp thì vuốt xoá đi cùng đường [onXoaCap] (xoá CẢ HAI
  /// nửa), không bao giờ [onDelete]. `null` (dòng đơn lẻ trong test, trang chưa đăng ký cổng) → đường cũ.
  final Future<CapGopQuy?> Function(TransactionEntity)? hoiCap;

  /// Xoá cả cặp theo mã cặp; ném thì dòng báo lỗi và hàng bật lại.
  final Future<void> Function(String maCap)? onXoaCap;

  /// Việc 4c — hỏi "hoá đơn của khoản này đã xoá chưa" lúc vuốt (mở khoá có cảnh báo cho khoản mồ côi). `null` (dòng
  /// đơn lẻ trong test, trang chưa đăng ký cổng) → khoản có `billId` vẫn khoá.
  final HoaDonDaXoaNguon? nguonHoaDonDaXoa;

  /// Bấm vào dòng — trang mở bảng chi tiết. `null` thì dòng không phản ứng.
  final VoidCallback? onTap;

  /// Tra tên ví/danh mục; `null` thì mọi ví hiện là "Ví đã xoá" và không có
  /// danh mục — chỉ dành cho test dựng dòng đơn lẻ.
  final TransactionLookup? lookup;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final content =
        buildTransactionRowContent(tx, lookup ?? TransactionLookup.empty);

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        // Nửa riêng của khoản góp, rút còn cặp: xoá CẢ HAI nửa qua cổng. Luôn trả `false` — stream drift tự rút hàng; trả
        // `true` là `onDismissed` → `onDelete` gỡ thêm MỘT nửa, đúng lỗi lệch cặp đang chặn. Toast nằm ở `onDismissed`
        // (không chạy khi trả `false`) nên báo ở đây.
        final cap = await hoiCap?.call(tx);
        if (cap != null) {
          if (!cap.choThaoTac) {
            baoNhanh('Nhà đang ở chế độ chỉ xem.', loai: LoaiThongBao.loi);
            return false;
          }
          if (!context.mounted) return false;
          final dongY = await ConfirmDialog.show(
            context,
            title: cap.laGop ? 'Xoá khoản góp?' : 'Xoá khoản rút?',
            message: cap.cauXoa,
          );
          if (dongY) {
            try {
              await onXoaCap!(cap.maCap);
              baoNhanh('Đã xóa giao dịch', loai: LoaiThongBao.xong);
            } catch (_) {
              baoNhanh('Không xoá được khoản này. Thử lại sau.', loai: LoaiThongBao.loi);
            }
          }
          return false;
        }
        final daXoa = await hoaDonDaXoaCua(tx, nguonHoaDonDaXoa);
        final lyDo =
            lyDoKhongXoaTaiSo(transactionOwnerOf(tx, hoaDonDaXoa: daXoa));
        if (lyDo != null) {
          baoNhanh(lyDo, loai: LoaiThongBao.loi);
          return false;
        }
        final canhBao = canhBaoXoaTaiSo(tx, hoaDonDaXoa: daXoa);
        // Giao dịch thường giữ nguyên vuốt-là-xoá — không thêm hộp thoại.
        if (canhBao == null) return true;
        if (!context.mounted) return false;
        return ConfirmDialog.show(
          context,
          title: 'Xoá giao dịch?',
          message: canhBao,
        );
      },
      onDismissed: (_) {
        onDelete();
        baoNhanh('Đã xóa giao dịch', loai: LoaiThongBao.xong);
      },
      child: InkWell(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.surfaceContainer,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Vòng tròn nền màu danh mục ở 12% — cùng ý "chip 10% màu danh
            // mục, chữ 100%" trong design system Kinetic Finance.
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: content.colour.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(content.icon, color: content.colour, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    content.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              content.amountText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: content.amountColor,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
