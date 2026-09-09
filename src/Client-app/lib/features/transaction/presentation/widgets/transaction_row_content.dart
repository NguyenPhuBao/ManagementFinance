import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';

import '../../../../core/category/category_visuals.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/transaction_entity.dart';
import '../../data/models/transaction_type_label.dart';
import '../../domain/transaction_lookup.dart';

/// Những gì một dòng trong sổ giao dịch hiển thị, đã tính xong.
///
/// Bố cục theo Stitch màn Home ("Giao dịch gần đây"): tiêu đề = ghi chú
/// (không có thì tên danh mục), dòng phụ = "Danh mục • Ví", vòng tròn icon
/// bên trái, số tiền có dấu bên phải. Tách khỏi widget để test bằng `expect`
/// thường, không cần dựng cây.
class TransactionRowContent {
  const TransactionRowContent({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colour,
    required this.amountText,
    required this.amountColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color colour;
  final String amountText;
  final Color amountColor;
}

TransactionRowContent buildTransactionRowContent(
  TransactionEntity tx,
  TransactionLookup lookup,
) {
  final money = CurrencyFormatter.formatSoThoi(tx.amount);
  final wallet = lookup.walletName(tx.walletId);
  final note = tx.note.trim();

  if (tx.type == 'transfer') {
    // Chuyển ví không phải thu hay chi: không dấu, không màu thu/chi. Chiều
    // tiền nằm ở "nguồn → đích" — đó là thứ người dùng cần biết.
    final dest = tx.walletTransfer;
    return TransactionRowContent(
      title: note.isNotEmpty ? note : transactionTypeLabel(tx.type),
      subtitle: dest == null ? wallet : '$wallet → ${lookup.walletName(dest)}',
      icon: Icons.swap_horiz,
      colour: AppColors.primary,
      amountText: '$moneyđ',
      amountColor: AppColors.primary,
    );
  }

  final isExpense = tx.type == 'chi';
  final typeColour = isExpense ? AppColors.error : AppColors.income;
  final category = lookup.category(tx.categoryId);
  final categoryName = category?.name;
  return TransactionRowContent(
    title: note.isNotEmpty ? note : (categoryName ?? transactionTypeLabel(tx.type)),
    // Danh mục chỉ xuống dòng phụ khi tiêu đề đã bị ghi chú chiếm; không thì
    // nó đang ở tiêu đề rồi, lặp lại là thừa.
    subtitle: note.isNotEmpty && categoryName != null
        ? '$categoryName • $wallet'
        : wallet,
    icon: category == null
        ? (isExpense ? Icons.arrow_downward : Icons.arrow_upward)
        : categoryIconFor(category.icon),
    colour: category == null
        ? typeColour
        : categoryColorFrom(category.colour, fallback: typeColour),
    amountText: '${isExpense ? '-' : '+'}$moneyđ',
    amountColor: typeColour,
  );
}
