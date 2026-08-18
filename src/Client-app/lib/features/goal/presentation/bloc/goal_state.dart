import 'package:equatable/equatable.dart';
import '../../data/models/goal_entity.dart';

abstract class GoalState extends Equatable {
  const GoalState();

  @override
  List<Object?> get props => [];
}

class GoalInitial extends GoalState {}

class GoalLoading extends GoalState {}

class GoalLoaded extends GoalState {
  final List<GoalEntity> goals;
  final double totalTargetAmount;
  final double totalCurrentAmount;

  const GoalLoaded({
    required this.goals,
    required this.totalTargetAmount,
    required this.totalCurrentAmount,
  });

  @override
  List<Object?> get props => [goals, totalTargetAmount, totalCurrentAmount];
}

class GoalError extends GoalState {
  final String message;

  const GoalError(this.message);

  @override
  List<Object?> get props => [message];
}
