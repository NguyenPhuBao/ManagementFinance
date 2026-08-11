import '../models/goal_entity.dart';

abstract class GoalRepository {
  Future<List<GoalEntity>> getGoals(int idaccount);
  Stream<List<GoalEntity>> watchGoals(int idaccount);
  Future<GoalEntity> addGoal({
    required int idaccount,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String? icon,
    String? colour,
    String? note,
  });
  Future<void> updateAmount({
    required String id,
    required double newAmount,
  });
  Future<void> deleteGoal(String id);
}
