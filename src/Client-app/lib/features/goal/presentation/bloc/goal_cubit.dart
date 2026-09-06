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

  /// Trả `null` khi thành công, hoặc câu lỗi để nơi gọi hiển thị — giống
  /// [updateGoal], và vì đúng cùng một lý do.
  ///
  /// Trang tạo gọi `.then(...)` rồi đóng trang ngay, nó KHÔNG đọc trạng thái
  /// cubit. Bản trước chỉ phát `GoalError`, nên một mục tiêu bị từ chối (trùng
  /// tên chẳng hạn) vẫn hiện thông báo "thành công" rồi đóng trang — người
  /// dùng mất hết những gì vừa gõ và không biết vì sao mục tiêu không có ở đó.
  Future<String?> addGoal({
    required int idaccount,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String? walletId,
    String? cycleTakeMoney,
    String? icon,
    String? colour,
    String? note,
    bool? recurrence,
    String? timeRecurrence,
    double? autoDepositAmount,
    String? autoDepositWalletId,
    DateTime? autoDepositAnchor,
  }) async {
    try {
      await repository.addGoal(
        idaccount: idaccount,
        name: name,
        targetAmount: targetAmount,
        targetDate: targetDate,
        walletId: walletId,
        cycleTakeMoney: cycleTakeMoney,
        icon: icon,
        colour: colour,
        note: note,
        recurrence: recurrence,
        timeRecurrence: timeRecurrence,
        autoDepositAmount: autoDepositAmount,
        autoDepositWalletId: autoDepositWalletId,
        autoDepositAnchor: autoDepositAnchor,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sửa phần mô tả của mục tiêu. Tiến độ và ví tích luỹ KHÔNG đi qua đây —
  /// xem `GoalRepository.updateGoal`.
  ///
  /// Trả `null` khi thành công, hoặc câu lỗi để nơi gọi hiển thị. Trang sửa cần
  /// biết kết quả ngay tại chỗ để quyết định có đóng trang không; phát
  /// `GoalError` như các lệnh khác thì trang vẫn đóng rồi mới hiện lỗi, và
  /// người dùng mất luôn những gì vừa gõ.
  Future<String?> updateGoal({
    required String id,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String? cycleTakeMoney,
    String? icon,
    String? colour,
    String? note,
    bool? recurrence,
    String? timeRecurrence,
    double? autoDepositAmount,
    String? autoDepositWalletId,
    DateTime? autoDepositAnchor,
  }) async {
    try {
      await repository.updateGoal(
        id: id,
        name: name,
        targetAmount: targetAmount,
        targetDate: targetDate,
        cycleTakeMoney: cycleTakeMoney,
        icon: icon,
        colour: colour,
        note: note,
        recurrence: recurrence,
        timeRecurrence: timeRecurrence,
        autoDepositAmount: autoDepositAmount,
        autoDepositWalletId: autoDepositWalletId,
        autoDepositAnchor: autoDepositAnchor,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Bắt đầu vòng mới cho một mục tiêu lặp lại đã hoàn thành.
  ///
  /// Trả `null` khi xong, hoặc câu lỗi để nơi gọi hiện snackbar — cùng lối với
  /// [updateGoal]: nút nằm trên trang chi tiết và trang ấy không đóng lại sau
  /// thao tác, nên người dùng phải thấy lý do ngay tại chỗ.
  Future<String?> batDauVongMoi(String goalId) async {
    try {
      await repository.batDauVongMoi(goalId);
      return null;
    } catch (e) {
      return e.toString();
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

  /// [walletId] là ví NGUỒN. Ví nhận không truyền vào — repository đọc từ chính
  /// mục tiêu, vì nó được chọn một lần lúc tạo và chỉ đổi qua "Đổi ví nhận".
  Future<void> depositToGoal({
    required String goalId,
    required String goalName,
    required double depositAmount,
    required String walletId,
    required int idaccount,
  }) async {
    try {
      await repository.depositToGoal(
        goalId: goalId,
        goalName: goalName,
        depositAmount: depositAmount,
        walletId: walletId,
        idaccount: idaccount,
      );
      // watchGoals stream sẽ tự động cập nhật UI — không cần gọi loadGoals
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  /// [walletId] là ví NHẬN tiền rút ra. Ví tích lũy đọc từ chính mục tiêu.
  Future<void> withdrawFromGoal({
    required String goalId,
    required String goalName,
    required double amount,
    required String walletId,
    required int idaccount,
  }) async {
    try {
      await repository.withdrawFromGoal(
        goalId: goalId,
        goalName: goalName,
        amount: amount,
        walletId: walletId,
        idaccount: idaccount,
      );
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
