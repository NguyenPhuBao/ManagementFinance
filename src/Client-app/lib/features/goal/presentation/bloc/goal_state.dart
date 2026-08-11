part of 'goal_cubit.dart';

abstract class GoalState extends Equatable {
  const GoalState();

  @override
  List<Object?> get props => [];
}

class GoalInitial extends GoalState {
  const GoalInitial();
}

class GoalLoading extends GoalState {
  const GoalLoading();
}

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

class GoalOperating extends GoalState {
  final List<GoalEntity> goals;
  const GoalOperating(this.goals);

  @override
  List<Object?> get props => [goals];
}

class GoalOperationSuccess extends GoalState {
  final String message;
  const GoalOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class GoalError extends GoalState {
  final String message;
  const GoalError(this.message);

  @override
  List<Object?> get props => [message];
}
