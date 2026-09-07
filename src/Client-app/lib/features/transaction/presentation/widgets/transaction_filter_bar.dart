import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/transaction_filter.dart';
import '../../domain/transaction_lookup.dart';

/// Thanh lọc của sổ giao dịch: ô tìm theo ghi chú, chip loại, chip ví, chip
/// danh mục và nút xoá lọc.
///
/// Widget không lọc gì cả — chỉ phát [TransactionFilter] mới qua [onChanged];
/// trang giữ trạng thái và chạy `applyTransactionFilter`. Bảng chọn danh mục
/// là route riêng của app nên nhận qua [pickCategory] để test được.
class TransactionFilterBar extends StatefulWidget {
  const TransactionFilterBar({
    super.key,
    required this.filter,
    required this.lookup,
    required this.wallets,
    required this.onChanged,
    required this.pickCategory,
  });

  final TransactionFilter filter;
  final TransactionLookup lookup;
  final List<Wallet> wallets;
  final ValueChanged<TransactionFilter> onChanged;
  final Future<Category?> Function() pickCategory;

  @override
  State<TransactionFilterBar> createState() => _TransactionFilterBarState();
}

class _TransactionFilterBarState extends State<TransactionFilterBar> {
  late final TextEditingController _query =
      TextEditingController(text: widget.filter.query);

  @override
  void didUpdateWidget(covariant TransactionFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // "Xoá lọc" đổi filter từ bên ngoài — ô tìm kiếm phải theo.
    if (widget.filter.query != _query.text) {
      _query.text = widget.filter.query;
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  TransactionFilter get _filter => widget.filter;

  static const _typeLabels = {
    TransactionTypeFilter.all: 'Tất cả',
    TransactionTypeFilter.thu: 'Thu',
    TransactionTypeFilter.chi: 'Chi',
    TransactionTypeFilter.transfer: 'Chuyển khoản',
  };

  Future<void> _pickWallet() async {
    final chosen = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive, color: AppColors.primary),
              title: const Text('Tất cả ví'),
              onTap: () => Navigator.of(ctx).pop(''),
            ),
            for (final w in widget.wallets)
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined,
                    color: AppColors.primary),
                title: Text(w.name),
                trailing: _filter.walletId == w.id
                    ? const Icon(Icons.check, color: AppColors.secondary)
                    : null,
                onTap: () => Navigator.of(ctx).pop(w.id),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return; // bấm ra ngoài
    widget.onChanged(chosen.isEmpty
        ? _filter.copyWith(clearWallet: true)
        : _filter.copyWith(walletId: chosen));
  }

  Future<void> _pickCategory() async {
    final category = await widget.pickCategory();
    if (category == null) return;
    widget.onChanged(_filter.copyWith(categoryId: category.id));
  }

  @override
  Widget build(BuildContext context) {
    final walletId = _filter.walletId;
    final categoryId = _filter.categoryId;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _query,
            onChanged: (value) =>
                widget.onChanged(_filter.copyWith(query: value)),
            decoration: InputDecoration(
              hintText: 'Tìm theo ghi chú…',
              hintStyle: const TextStyle(color: AppColors.outline),
              prefixIcon: const Icon(Icons.search, color: AppColors.outline),
              suffixIcon: _filter.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          widget.onChanged(_filter.copyWith(query: '')),
                    ),
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in _typeLabels.entries) ...[
                  _chip(
                    key: Key('filter-type-${entry.key.name}'),
                    label: entry.value,
                    selected: _filter.type == entry.key,
                    onTap: () =>
                        widget.onChanged(_filter.copyWith(type: entry.key)),
                  ),
                  const SizedBox(width: 8),
                ],
                _chip(
                  key: const Key('filter-wallet'),
                  icon: Icons.account_balance_wallet_outlined,
                  label: walletId == null
                      ? 'Ví'
                      : widget.lookup.walletName(walletId),
                  selected: walletId != null,
                  onTap: _pickWallet,
                ),
                const SizedBox(width: 8),
                _chip(
                  key: const Key('filter-category'),
                  icon: Icons.category_outlined,
                  label: categoryId == null
                      ? 'Danh mục'
                      : (widget.lookup.category(categoryId)?.name ??
                          'Danh mục'),
                  selected: categoryId != null,
                  onTap: _pickCategory,
                ),
                if (_filter.isActive) ...[
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () =>
                        widget.onChanged(const TransactionFilter()),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Xoá lọc'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) =>
      ChoiceChip(
        key: key,
        avatar: icon == null
            ? null
            : Icon(icon,
                size: 16,
                color: selected ? Colors.white : AppColors.primary),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceContainerLow,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : AppColors.primary,
        ),
        onSelected: (_) => onTap(),
      );
}
