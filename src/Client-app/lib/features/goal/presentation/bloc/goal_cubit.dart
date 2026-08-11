import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/goal_entity.dart';
import '../../data/repositories/goal_repository.dart';
import 'goal_state.dart';

export 'goal_state.dart';

class GoalCubit extends Cubit<GoalState> {
  final GoalRepository repository;
  StreamSubscription<List<GoalEntity>>? _goalsSubscription;

  GoalCubit({required this.repository}) : super(GoalInitial());

  void watchGoals(int idaccount) {
    emit(GoalLoading());
    _goalsSubscription?.cancel();
    _goalsSubscription = repository.watchGoals(idaccount).listen(
      (goals) {
        final totalTarget = goals.fold<double>(
          0.0,
          (sum, g) => sum + g.targetAmount,
        );
        final totalCurrent = goals.fold<double>(
          0.0,
          (sum, g) => sum + g.currentAmount,
        );
        emit(GoalLoaded(
          goals: goals,
          totalTargetAmount: totalTarget,
          totalCurrentAmount: totalCurrent,
        ));
      },
      onError: (error) {
        emit(GoalError(error.toString()));
      },
    );
  }

  Future<void> loadGoals(int idaccount) async {
    emit(GoalLoading());
    try {
      final goals = await repository.getGoals(idaccount);
      final totalTarget = goals.fold<double>(
        0.0,
        (sum, g) => sum + g.targetAmount,
      );
      final totalCurrent = goals.fold<double>(
        0.0,
        (sum, g) => sum + g.currentAmount,
      );
      emit(GoalLoaded(
        goals: goals,
        totalTargetAmount: totalTarget,
        totalCurrentAmount: totalCurrent,
      ));
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> addGoal({
    required int idaccount,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String? icon,
    String? colour,
    String? note,
  }) async {
    try {
      await repository.addGoal(
        idaccount: idaccount,
        name: name,
        targetAmount: targetAmount,
        targetDate: targetDate,
        icon: icon,
        colour: colour,
        note: note,
      );
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> updateAmount({
    required String id,
    required double newAmount,
  }) async {
    try {
      await repository.updateAmount(id: id, newAmount: newAmount);
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> deleteGoal(String id) async {
    try {
      await repository.deleteGoal(id);
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _goalsSubscription?.cancel();
    return super.close();
  }
}
