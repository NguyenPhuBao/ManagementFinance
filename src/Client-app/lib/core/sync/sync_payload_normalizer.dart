import '../../features/wallet/domain/wallet_status.dart';
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
    // `chk_wallet_status` chỉ nhận đúng hai chuỗi `'Active'` và `'Inactive'`.
    // Mọi giá trị lạ, `null` và chuỗi rỗng đều về `'Active'` qua `tuKhoa` —
    // giữ nguyên là để chúng đi thẳng lên server rồi vỡ CHECK, và ví **kẹt
    // hàng đợi đẩy vĩnh viễn, im lặng**. Cùng khuôn `type` ngay trên (bài học
    // `ewallet`/`debt`, migration v20).
    //
    // Mở lại ngày 2026-09-14 (G28). Cột `Status` từng là `varchar(7)` trong
    // khi `'Inactive'` dài 8 ký tự, nên trước đó client cố ý không gửi cột
    // này; đo lại cùng ngày: `varchar(20)`, `NOT NULL`, `DEFAULT 'Active'`.
    normalized['status'] =
        WalletStatus.tuKhoa(normalized['status']?.toString()).khoaGuiLen;
    // Cột thứ BA có ràng buộc kiểm tra, và là cột cuối cùng còn bỏ ngỏ tới
    // 2026-09-18: `chk_wallet_currency` chỉ nhận `'VND'` và `'USD'`. Hai cột
    // trên đã có lớp này sau khi mỗi cột làm ví **kẹt hàng đợi đẩy vĩnh viễn**
    // một lần (`ewallet`/`debt` ở `type`, `'Inactive'` ở `status`); cột này
    // chịu đúng một kiểu ràng buộc mà chưa từng được che.
    //
    // Chưa có màn nào cho đổi tiền tệ nên chưa có đường sinh giá trị lạ — đây
    // là lớp phòng thủ đặt trước, vì `WalletRepositoryImpl.addWallet` nhận
    // `currency` như một tham số thường và chỗ gọi tiếp theo là đủ để mở lại
    // vòng lặp ấy.
    normalized['currency'] = tienTeGuiLen(normalized['currency']?.toString());
    return normalized;
  }

  /// Mã tiền tệ hợp lệ với `chk_wallet_currency`, từ một giá trị bất kỳ.
  ///
  /// Chữ thường được **nâng lên** chứ không gộp mù về `VND`: `'usd'` rõ ràng là
  /// `USD`, và gộp nó thành `VND` sẽ đổi ý nghĩa số dư của một ví. Mọi thứ
  /// không nhận ra được mới về `VND` — mặc định của cột trên server.
  static String tienTeGuiLen(String? raw) {
    final khoa = raw?.trim().toUpperCase();
    return (khoa == 'USD' || khoa == 'VND') ? khoa! : 'VND';
  }

  static Map<String, dynamic> categoryForPush(Map<String, dynamic> payload) {
    final normalized = forPush(payload);
    // Backend chỉ đọc `color` — thiếu phép đổi này thì màu danh mục bị bỏ qua
    // im lặng (G24). Cùng khuôn `walletForPush`, và phủ cả thao tác danh mục
    // đang chờ lẫn danh mục mà bước 1b của `_collectPendingOps` gửi kèm.
    final colour = normalized.remove('colour');
    if (colour != null) normalized['color'] = colour;
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
