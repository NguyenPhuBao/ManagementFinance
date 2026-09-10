import '../../features/wallet/domain/wallet_type.dart';

/// Chuẩn hóa enum nội bộ của Client trước khi gửi sang Sync API.
///
/// ⚠️ Tệp này cố ý **không import Flutter**. `wallet_type.dart` là Dart thuần
/// đúng vì lý do đó — biểu tượng của loại ví nằm riêng ở tầng hiển thị.
class SyncPayloadNormalizer {
  const SyncPayloadNormalizer._();

  /// Giá trị `Classify` mà client GỬI LÊN cho danh mục vay/nợ.
  ///
  /// Đang là `'Vay/no'` (KHÔNG dấu) vì đó là giá trị duy nhất mà CHECK
  /// constraint `ck_category_classify` trên PostgreSQL cho phép, và cũng là
  /// giá trị `seed.js` đang ghi vào CSDL.
  ///
  /// Tài liệu `New_Database.md` và kế hoạch align schema lại ghi `'Vay/nợ'`
  /// (CÓ dấu) — hai bên đang lệch nhau. Xem
  /// `docs/superpowers/backend/DA-XONG/CATEGORY_CLASSIFY_ALIGNMENT.md` để biết cách xử lý.
  ///
  /// Khi backend đã đổi CHECK constraint + seed + dữ liệu sang `'Vay/nợ'`,
  /// chỉ cần đổi hằng số này — phần ĐỌC của client đã chấp nhận cả hai dạng từ
  /// trước nên không cần sửa gì thêm.
  static const String canonicalDebtClassify = 'Vay/no';

  /// Đưa mọi biến thể của phân loại danh mục về một dạng so sánh được:
  /// chữ thường, `-` và `/` thành `_`, và bỏ dấu ở `nợ`.
  /// Nhờ vậy `vay_no`, `vay_nợ`, `Vay/no`, `Vay/nợ` đều tương đương.
  static String _canonicalClassifyKey(String value) => value
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll('/', '_')
      .replaceAll('ợ', 'o');

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
    // ⚠️ KHÔNG có nhánh "giữ nguyên giá trị lạ" ở đây. `chk_wallet_type` trên
    // PostgreSQL chỉ nhận đúng bốn chuỗi mà `WalletType.khoaGuiLen` sinh ra;
    // bản trước để giá trị lạ đi qua nguyên vẹn, nên ví tạo bằng "Ví điện tử"
    // hay "Thẻ tín dụng" của giao diện cũ vỡ CHECK ở MỌI lần đẩy và kẹt hàng
    // đợi vĩnh viễn — im lặng, không log, không gì trên màn hình.
    normalized['type'] =
        WalletType.tuKhoa(normalized['type']?.toString()).khoaGuiLen;
    // ⚠️ KHÔNG chuẩn hoá `status` ở đây, vì nó cố ý không có mặt trong
    // payload (G28). Lý do ban đầu: cột `Status` của PostgreSQL là varchar(7)
    // còn giá trị cần gửi là 'Inactive' — 8 ký tự. CSDL dev đã nới lên
    // varchar(20) tối 2026-09-10, nhưng việc nối lại người dùng chốt để sau.
    // Xem chú thích dài ở nhánh kéo về ví trong `sync_engine.dart`.
    // `WalletStatus.khoaGuiLen` vẫn giữ nguyên và vẫn được test canh, để ngày
    // mở lại thì chỉ cần một dòng ở đây.
    return normalized;
  }

  static Map<String, dynamic> categoryForPush(Map<String, dynamic> payload) {
    final normalized = forPush(payload);
    final raw = normalized['classify']?.toString();
    normalized['classify'] = switch (
      raw == null ? null : _canonicalClassifyKey(raw)
    ) {
      'thu' => 'Thu',
      'chi' => 'Chi',
      // Nhận cả 'vay_no', 'vay_nợ', 'vay/no', 'vay/nợ' → gửi lên đúng một dạng.
      'vay_no' => canonicalDebtClassify,
      null => 'Chi',
      // Giá trị lạ thì giữ nguyên như client gửi vào, để backend tự từ chối.
      _ => raw,
    };
    return normalized;
  }

  static String walletTypeFromBackend(String value) => value.toLowerCase();

  static String transactionTypeFromBackend(String type, num amount) {
    if (type == 'Transfer') return 'transfer';
    return amount < 0 ? 'chi' : 'thu';
  }

  /// Đổi giá trị `Classify` của backend về dạng nội bộ của client.
  ///
  /// Chấp nhận CẢ `'Vay/no'` lẫn `'Vay/nợ'` để client chạy đúng bất kể backend
  /// đã migrate sang dạng có dấu hay chưa.
  static String categoryClassifyFromBackend(String value) =>
      _canonicalClassifyKey(value);

  static bool sameCategoryClassify(String first, String second) =>
      _canonicalClassifyKey(first) == _canonicalClassifyKey(second);
}
