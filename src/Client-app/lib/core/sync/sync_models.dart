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

/// Kết quả sau khi sync một batch
class SyncResult {
  final int totalOps;
  final int succeeded;
  final int failed;
  final List<String> conflictIds;  // IDs bị conflict
  final List<String> errorMessages;

  const SyncResult({
    required this.totalOps,
    required this.succeeded,
    required this.failed,
    this.conflictIds = const [],
    this.errorMessages = const [],
  });

  bool get isSuccess => failed == 0 && conflictIds.isEmpty;

  @override
  String toString() =>
      'SyncResult($succeeded/$totalOps succeeded, '
      '${conflictIds.length} conflicts, $failed failed)';
}

/// Trạng thái của sync session
enum SyncStatus {
  idle,         // Không có gì cần sync
  pending,      // Có dữ liệu chờ sync
  syncing,      // Đang sync
  error,        // Sync thất bại (sẽ retry)
}
