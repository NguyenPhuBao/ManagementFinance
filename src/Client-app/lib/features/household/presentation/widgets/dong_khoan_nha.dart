import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../domain/hoat_dong_nha.dart';
import 'avatar_chu_cai.dart';

/// Màu số tiền thu / góp của Stitch `50af4171…` (`#008736`): không trùng token nào của `AppColors`.
const kMauThuKhoanNha = Color(0xFF008736);

/// Màu số tiền: thu / góp xanh, chi / rút / chuyển đen; người đã rời thì xám (cả dòng đã rời mờ đi).
Color mauTienKhoanNha(bool? dau, {required bool daRoi}) {
  if (daRoi) return AppColors.textSecondary;
  return dau == true ? kMauThuKhoanNha : AppColors.primary;
}

/// Số tiền cột phải: có dấu theo [dauTienKhoanNha] (`+` thu, `-` chi, trống khi chuyển).
String chuTienKhoanNha(TransactionEntity t) {
  final dau = dauTienKhoanNha(t);
  return dau == null ? CurrencyFormatter.format(t.amount) : CurrencyFormatter.formatCoDau(t.amount, thu: dau);
}

/// Một dòng của Hoạt động (Stitch `50af4171…` 7.3): avatar người ghi, câu *"An chi 120.000 đ"*, dòng phụ, số tiền có dấu.
/// Không gọi `sl`: trang truyền chữ vào.
class DongKhoanNha extends StatelessWidget {
  const DongKhoanNha({
    super.key,
    required this.khoan,
    required this.nguoi,
    required this.dongPhu,
    this.onCham,
    this.tieuDe,
  });

  final TransactionEntity khoan;
  final TenNguoi nguoi;

  /// `Danh mục · Ví` / `Ví` / `Ví nguồn → Ví đích` — trang ghép, vì tên danh mục và ví cần tra.
  final String dongPhu;

  /// `null` = dòng không chạm được (Chi tiết ví chưa có sheet khoản).
  final VoidCallback? onCham;

  /// Câu tiêu đề thay cho mặc định *"An chi 120.000 đ"*: Chi tiết ví (Stitch `ac57e216…`) để số tiền ở cột phải, không lặp.
  final String? tieuDe;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final dau = dauTienKhoanNha(khoan);
    final mauTien = mauTienKhoanNha(dau, daRoi: nguoi.daRoi);
    return InkWell(
      onTap: onCham,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: LayoutBuilder(
          builder: (context, c) => Row(
            children: [
              AvatarChuCai(ten: nguoi.ten, idaccount: khoan.idaccount, co: 40, daRoi: nguoi.daRoi),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tieuDe ?? '${tieuDeKhoanNha(khoan, nguoi)} ${CurrencyFormatter.format(khoan.amount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: chu.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: nguoi.daRoi ? AppColors.textSecondary : AppColors.textPrimary)),
                    if (dongPhu.isNotEmpty)
                      Text(dongPhu,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Số tiền KHÔNG flex, trần 40 % dòng: 13 chữ số co lại (FittedBox) thay vì đè hết câu tiêu đề.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth * 0.4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(chuTienKhoanNha(khoan),
                      key: const Key('tien-khoan-nha'),
                      maxLines: 1,
                      style: chu.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: mauTien)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
