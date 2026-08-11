import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/goal_entity.dart';
import '../../data/repositories/goal_repository.dart';

part 'goal_state.dart';

class GoalCubit extends Cubit<GoalState> {
  final GoalRepository _repository;

  GoalCubit({required GoalRepository repository})
      : _repository = repository,
        super(const GoalInitial());

  Future<void> loadGoals(int idaccount) async {
    emit(const GoalLoading());
    try {
      final goals = await _repository.getGoals(idaccount);
      final totalTarget = goals.fold<double>(0, (sum, g) => sum + g.targetAmount);
      final totalCurrent = goals.fold<double>(0, (sum, g) => sum + g.currentAmount);

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
    String icon = 'flag',
    String colour = '#4CAF50',
    String note = '',
  }) async {
    try {
      await _repository.addGoal(
        idaccount: idaccount,
        name: name,
        targetAmount: targetAmount,
        targetDate: targetDate,
        icon: icon,
        colour: colour,
        note: note,
      );
      emit(const GoalOperationSuccess('Tạo mục tiêu thành công!'));
      await loadGoals(idaccount);
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> updateAmount({
    required int idaccount,
    required String id,
    required double newAmount,
  }) async {
    try {
      await _repository.updateAmount(id: id, newAmount: newAmount);
      await loadGoals(idaccount);
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> deleteGoal({required int idaccount, required String id}) async {
    try {
      await _repository.deleteGoal(id);
      await loadGoals(idaccount);
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }
}
