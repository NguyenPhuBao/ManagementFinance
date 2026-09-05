import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class TransactionEntity {
  final String id;
  final String walletId;
  final int idaccount;
  final String? categoryId;

  /// Ví đích khi `type == 'transfer'`; `null` với mọi giao dịch khác.
  ///
  /// Là chỗ DUY NHẤT ghi lại tiền đã đi đâu: payload đẩy đọc cột này thành
  /// `idwallet_transfer`, và đường xoá dựa vào nó để hoàn tiền cho ví đích.
  /// Trước 2026-09-05 entity không có trường này nên `toCompanion()` bỏ trống
  /// cột — khoản chuyển tạo từ màn thêm giao dịch lên server không có ví đích.
  final String? walletTransfer;

  /// Mục tiêu tiết kiệm sở hữu khoản này (nạp/rút/trích tự động); `null` với
  /// giao dịch thường. Cột CỤC BỘ, không đi qua đồng bộ — hàng kéo từ server
  /// luôn trống, nên nơi nhận diện phải kèm nhánh đọc tiền tố ghi chú
  /// (xem `transactionOwnerOf`).
  final String? goalId;
  final double amount;

  /// `'chi'` (tiền ra) | `'thu'` (tiền vào) | `'transfer'` (chuyển giữa hai ví).
  ///
  /// Đây là bộ giá trị NỘI BỘ của client; `SyncPayloadNormalizer` quy đổi sang
  /// `Transaction` ± amount / `Transfer` của backend. Chiều tiền của giao dịch
  /// gắn danh mục vay/nợ cũng nằm ở đây (người dùng chọn trên form).
  final String type;
  final String note;
  final DateTime date;
  final List<String> images;
  final String syncStatus;
  final DateTime updatedAt;
  final bool isDeleted;

  TransactionEntity({
    required this.id,
    required this.walletId,
    required this.idaccount,
    this.categoryId,
    this.walletTransfer,
    this.goalId,
    required this.amount,
    required this.type,
    this.note = '',
    required this.date,
    this.images = const [],
    this.syncStatus = 'pending',
    required this.updatedAt,
    this.isDeleted = false,
  });

  factory TransactionEntity.fromDrift(Transaction d) {
    List<String> imgList = [];
    if (d.images.isNotEmpty && d.images != '[]') {
      try {
        imgList = (d.images.replaceAll('[', '').replaceAll(']', '').split(','))
            .map((e) => e.trim().replaceAll('"', ''))
            .where((e) => e.isNotEmpty)
            .toList();
      } catch (_) {}
    }
    return TransactionEntity(
      id: d.id,
      walletId: d.walletId,
      idaccount: d.idaccount,
      categoryId: d.categoryId,
      walletTransfer: d.walletTransfer,
      goalId: d.goalId,
      amount: d.amount,
      type: d.type,
      note: d.note,
      date: d.date,
      images: imgList,
      syncStatus: d.syncStatus,
      updatedAt: d.updatedAt,
      isDeleted: d.isDeleted,
    );
  }

  TransactionsCompanion toCompanion() {
    final imgJson = '[${images.map((e) => '"$e"').join(',')}]';
    return TransactionsCompanion.insert(
      id: id,
      walletId: walletId,
      idaccount: idaccount,
      categoryId: Value(categoryId),
      walletTransfer: Value(walletTransfer),
      goalId: Value(goalId),
      amount: amount,
      type: type,
      note: Value(note),
      date: date,
      images: Value(imgJson),
      syncStatus: Value(syncStatus),
      updatedAt: updatedAt,
      isDeleted: Value(isDeleted),
    );
  }

  TransactionEntity copyWith({
    String? id,
    String? walletId,
    int? idaccount,
    String? categoryId,
    String? walletTransfer,
    String? goalId,
    double? amount,
    String? type,
    String? note,
    DateTime? date,
    List<String>? images,
    String? syncStatus,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      idaccount: idaccount ?? this.idaccount,
      categoryId: categoryId ?? this.categoryId,
      walletTransfer: walletTransfer ?? this.walletTransfer,
      goalId: goalId ?? this.goalId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      note: note ?? this.note,
      date: date ?? this.date,
      images: images ?? this.images,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
