/// Chuẩn hóa enum nội bộ của Client trước khi gửi sang Sync API.
class SyncPayloadNormalizer {
  const SyncPayloadNormalizer._();

  static String transactionType(String localType) => switch (localType) {
        'thu' => 'Income',
        'chi' => 'Expense',
        _ => localType,
      };

  /// Sync API uses `update_at`, while SQLite uses `updated_at`.
  static Map<String, dynamic> forPush(Map<String, dynamic> payload) {
    final normalized = Map<String, dynamic>.from(payload);
    final updatedAt = normalized.remove('updated_at');
    if (updatedAt != null) {
      normalized['update_at'] = updatedAt;
    }
    return normalized;
  }

  /// Maps the local transaction column names to the Sync API contract.
  static Map<String, dynamic> transactionForPush(
      Map<String, dynamic> payload) {
    final normalized = forPush(payload);
    final walletId = normalized.remove('wallet_id');
    final categoryId = normalized.remove('category_id');
    final date = normalized.remove('date');
    final localType = normalized['type']?.toString().toLowerCase();
    final rawAmount = normalized['amount'];
    final amount = rawAmount is num ? rawAmount : num.tryParse('$rawAmount');

    normalized['walletId'] = walletId;
    normalized['categoryId'] = categoryId;
    normalized['dateTransaction'] = date;
    switch (localType) {
      case 'thu':
      case 'income':
        normalized['type'] = 'Transaction';
        if (amount != null) normalized['amount'] = amount.abs();
      case 'chi':
      case 'expense':
        normalized['type'] = 'Transaction';
        if (amount != null) normalized['amount'] = -amount.abs();
      case 'transfer':
        normalized['type'] = 'Transfer';
        normalized['categoryId'] = null;
    }
    return normalized;
  }

  static Map<String, dynamic> walletForPush(Map<String, dynamic> payload) {
    final normalized = forPush(payload);
    final colour = normalized.remove('colour');
    if (colour != null) normalized['color'] = colour;
    normalized['type'] = switch (normalized['type']?.toString().toLowerCase()) {
      'cash' => 'Cash',
      'bank' => 'Bank',
      'saving' => 'Saving',
      'banking' => 'Banking',
      final value? => value,
      null => 'Cash',
    };
    return normalized;
  }

  static Map<String, dynamic> categoryForPush(Map<String, dynamic> payload) {
    final normalized = forPush(payload);
    normalized['classify'] = switch (
      normalized['classify']?.toString().toLowerCase().replaceAll('_', '/')
    ) {
      'thu' => 'Thu',
      'chi' => 'Chi',
      'vay/no' => 'Vay/no',
      final value? => value,
      null => 'Chi',
    };
    return normalized;
  }

  static String walletTypeFromBackend(String value) => value.toLowerCase();

  static String transactionTypeFromBackend(String type, num amount) {
    if (type == 'Transfer') return 'transfer';
    return amount < 0 ? 'chi' : 'thu';
  }

  static String categoryClassifyFromBackend(String value) =>
      value.toLowerCase().replaceAll('/', '_');

  static bool sameCategoryClassify(String first, String second) {
    String normalize(String value) => value.toLowerCase().replaceAll('-', '_');

    final normalizedFirst = normalize(first).replaceAll('/', '_');
    final normalizedSecond = normalize(second).replaceAll('/', '_');
    return normalizedFirst == normalizedSecond;
  }
}
