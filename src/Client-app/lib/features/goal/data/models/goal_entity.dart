import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class GoalEntity {
  final String id;
  final int idaccount;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final String icon;
  final String colour;
  final String note;
  final bool isCompleted;
  final bool isDeleted;
  final String syncStatus;
  final DateTime updatedAt;

  GoalEntity({
    required this.id,
    required this.idaccount,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.targetDate,
    this.icon = 'flag',
    this.colour = '#4CAF50',
    this.note = '',
    this.isCompleted = false,
    this.isDeleted = false,
    this.syncStatus = 'pending',
    required this.updatedAt,
  });

  factory GoalEntity.fromDrift(Goal d) {
    return GoalEntity(
      id: d.id,
      idaccount: d.idaccount,
      name: d.name,
      targetAmount: d.targetAmount,
      currentAmount: d.currentAmount,
      targetDate: d.targetDate,
      icon: d.icon,
      colour: d.colour,
      note: d.note,
      isCompleted: d.isCompleted,
      isDeleted: d.isDeleted,
      syncStatus: d.syncStatus,
      updatedAt: d.updatedAt,
    );
  }

  GoalsCompanion toCompanion() {
    return GoalsCompanion.insert(
      id: id,
      idaccount: idaccount,
      name: name,
      targetAmount: targetAmount,
      currentAmount: Value(currentAmount),
      targetDate: targetDate,
      icon: Value(icon),
      colour: Value(colour),
      note: Value(note),
      isCompleted: Value(isCompleted),
      isDeleted: Value(isDeleted),
      syncStatus: Value(syncStatus),
      updatedAt: updatedAt,
    );
  }

  GoalEntity copyWith({
    String? id,
    int? idaccount,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? icon,
    String? colour,
    String? note,
    bool? isCompleted,
    bool? isDeleted,
    String? syncStatus,
    DateTime? updatedAt,
  }) {
    return GoalEntity(
      id: id ?? this.id,
      idaccount: idaccount ?? this.idaccount,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      icon: icon ?? this.icon,
      colour: colour ?? this.colour,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
