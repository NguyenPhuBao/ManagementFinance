import 'package:equatable/equatable.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class GoalEntity extends Equatable {
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

  const GoalEntity({
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

  factory GoalEntity.fromDrift(Goal data) {
    return GoalEntity(
      id: data.id,
      idaccount: data.idaccount,
      name: data.name,
      targetAmount: data.targetAmount,
      currentAmount: data.currentAmount,
      targetDate: data.targetDate,
      icon: data.icon,
      colour: data.colour,
      note: data.note,
      isCompleted: data.isCompleted,
      isDeleted: data.isDeleted,
      syncStatus: data.syncStatus,
      updatedAt: data.updatedAt,
    );
  }

  GoalsCompanion toCompanion() {
    return GoalsCompanion(
      id: Value(id),
      idaccount: Value(idaccount),
      name: Value(name),
      targetAmount: Value(targetAmount),
      currentAmount: Value(currentAmount),
      targetDate: Value(targetDate),
      icon: Value(icon),
      colour: Value(colour),
      note: Value(note),
      isCompleted: Value(isCompleted),
      isDeleted: Value(isDeleted),
      syncStatus: Value(syncStatus),
      updatedAt: Value(updatedAt),
    );
  }

  @override
  List<Object?> get props => [
        id,
        idaccount,
        name,
        targetAmount,
        currentAmount,
        targetDate,
        icon,
        colour,
        note,
        isCompleted,
        isDeleted,
        syncStatus,
        updatedAt,
      ];
}
