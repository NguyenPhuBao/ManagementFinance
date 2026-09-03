// Sync models cho offline-first sync engine của FlowMoney.
//
// Mỗi khi user thực hiện thao tác local (thêm/sửa/xoá),
// một SyncOperation được tạo và queue vào SyncEngine.
// Khi có mạng, SyncEngine batch gửi toàn bộ lên backend.

/// Loại thao tác cần sync
enum SyncOperationType { create, update, delete }

/// Entity type để backend biết sync vào bảng nào
enum SyncEntityType { wallet, transaction, category, budget, bill, goal }

/// Một đơn vị thao tác cần đồng bộ lên server
class SyncOperation {
  final String localId;           // UUID của record local
  final SyncEntityType entity;
  final SyncOperationType operation;
  final Map<String, dynamic> payload;  // JSON data của record
  final DateTime createdAt;

  const SyncOperation({
    required this.localId,
    required this.entity,
    required this.operation,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'entity': entity.name,
    'operation': operation.name,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Phân loại nguyên nhân một thao tác đẩy dữ liệu thất bại.
///
/// Trước đây mọi thất bại đều bị gom làm một: bản ghi giữ nguyên `pending` và
/// được đẩy lại mỗi chu kỳ, kể cả khi thử lại chắc chắn vô ích.
enum SyncFailureKind {
  /// Có thể tự khỏi ở lần sau (mất mạng, lỗi 5xx, sai thứ tự đẩy khiến vỡ khoá
  /// ngoại tới category/wallet — Pull xong là đẩy lại được).
  transient,

  /// Thử lại bao nhiêu lần cũng vẫn hỏng với dữ liệu hiện tại.
  permanent,

  /// Phiên đăng nhập trỏ tới một tài khoản không còn tồn tại trên server
  /// (vỡ khoá ngoại `fk_*_account`). Cần đăng nhập lại, không phải thử lại.
  sessionInvalid,
}

/// Một thao tác đẩy dữ liệu thất bại, kèm lý do đã được phân loại.
class SyncOpFailure {
  final String localId;
  final SyncEntityType entity;
  final String message;
  final SyncFailureKind kind;

  const SyncOpFailure({
    required this.localId,
    required this.entity,
    required this.message,
    required this.kind,
  });

  @override
  String toString() => '${entity.name}/$localId [${kind.name}]: $message';
}

/// Kết quả sau khi sync một batch
class SyncResult {
  final int totalOps;
  final int succeeded;
  final int failed;
  final List<String> conflictIds;  // IDs bị conflict
  final List<String> errorMessages;

  /// Chi tiết từng thao tác thất bại kèm phân loại nguyên nhân.
  final List<SyncOpFailure> failures;

  /// Cả batch không gửi đi được (mất mạng, timeout) — khác hẳn với việc server
  /// nhận được rồi từ chối từng thao tác.
  final bool transportFailed;

  const SyncResult({
    required this.totalOps,
    required this.succeeded,
    required this.failed,
    this.conflictIds = const [],
    this.errorMessages = const [],
    this.failures = const [],
    this.transportFailed = false,
  });

  bool get isSuccess => failed == 0 && conflictIds.isEmpty;

  /// Có thao tác nào cho thấy phiên đăng nhập đã chết không.
  bool get hasSessionInvalid =>
      failures.any((f) => f.kind == SyncFailureKind.sessionInvalid);

  /// Có đáng thử lại ngay trong chu kỳ này không.
  bool get hasRetryableFailure =>
      !transportFailed &&
      failures.any((f) => f.kind == SyncFailureKind.transient);

  @override
  String toString() {
    final detail = failures.isEmpty ? '' : ' — ${failures.join('; ')}';
    return 'SyncResult($succeeded/$totalOps succeeded, '
        '${conflictIds.length} conflicts, $failed failed'
        '${transportFailed ? ', transport failed' : ''})$detail';
  }
}

/// Trạng thái của sync session
enum SyncStatus {
  idle,         // Chu kỳ kết thúc, không còn gì tồn đọng
  pending,      // Có dữ liệu chờ sync
  syncing,      // Đang sync
  error,        // Chu kỳ kết thúc nhưng còn thao tác thất bại
  authExpired,  // Phiên đăng nhập đã chết — đã dừng, thử lại là vô ích
}

extension SyncStatusX on SyncStatus {
  /// Chu kỳ đã kết thúc hay chưa (dù kết quả thế nào).
  ///
  /// Test phải chờ theo cờ này chứ đừng chờ đúng `SyncStatus.idle`: một chu kỳ
  /// mà mọi thao tác đẩy đều hỏng nay kết thúc ở `error`, và phiên chết kết
  /// thúc ở `authExpired`. Chờ riêng `idle` sẽ treo tới timeout và báo lỗi
  /// dưới dạng "timeout" — rất khó lần ra nguyên nhân thật.
  bool get isTerminal =>
      this == SyncStatus.idle ||
      this == SyncStatus.error ||
      this == SyncStatus.authExpired;
}
