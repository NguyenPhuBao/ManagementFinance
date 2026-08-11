import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class TransactionEntity {
  final String id;
  final String walletId;
  final int idaccount;
  final String? categoryId;
  final double amount;
  final String type; // 'chi' | 'thu' | 'transfer' | 'adjustment'
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
