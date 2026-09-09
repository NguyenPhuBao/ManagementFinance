import 'package:flutter/material.dart';

import '../../domain/wallet_type.dart';

/// Biểu tượng của từng loại ví.
///
/// Tách khỏi `domain/wallet_type.dart` có chủ ý: tệp ấy phải là **Dart thuần**
/// để `core/sync/sync_payload_normalizer.dart` — tầng hợp đồng giữa client và
/// server, vốn không import gì cả — dùng được phép ánh xạ khoá trong đó.
/// Biểu tượng là chuyện của tầng hiển thị, nên nó ở đây.
extension WalletTypeIcon on WalletType {
  IconData get icon => switch (this) {
        WalletType.cash => Icons.payments,
        WalletType.bank => Icons.account_balance,
        WalletType.saving => Icons.savings,
        WalletType.banking => Icons.link,
      };
}
