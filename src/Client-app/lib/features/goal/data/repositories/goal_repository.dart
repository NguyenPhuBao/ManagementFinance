import '../models/goal_entity.dart';

abstract class GoalRepository {
  Future<List<GoalEntity>> getGoals(int idaccount);
  Stream<List<GoalEntity>> watchGoals(int idaccount);
  Future<GoalEntity?> getGoalById(String id);
  Future<GoalEntity> addGoal({
    required int idaccount,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String? walletId,
    /// Nhịp người dùng dự định trích tiền — chỉ để hiển thị kế hoạch cạnh thực
    /// tế, không có bộ lập lịch nào đọc nó.
    String? cycleTakeMoney,
    String? icon,
    String? colour,
    String? note,
  });
  Future<void> updateAmount({
    required String id,
    required double newAmount,
  });
  /// Chuyển [depositAmount] từ ví [walletId] sang **ví nhận của mục tiêu** và
  /// tăng tiến độ tương ứng.
  ///
  /// Ví nhận đọc từ chính mục tiêu, nơi gọi không truyền vào: ví ấy được chọn
  /// một lần lúc tạo mục tiêu và chỉ đổi qua [changeWallet].
  ///
  /// Ném [StateError] nếu mục tiêu chưa có ví nhận (chỉ xảy ra với mục tiêu do
  /// bản app cũ tạo), và [ArgumentError] nếu ví nguồn trùng ví nhận.
  Future<void> depositToGoal({
    required String goalId,
    required String goalName,
    required double depositAmount,
    required String walletId,
    required int idaccount,
  });
  /// Lịch sử tích luỹ của một mục tiêu.
  ///
  /// Cần cả [goalId] lẫn [goalName]: id nối các khoản nạp mới, còn tên chỉ để
  /// tra lại những hàng cũ chưa mang id (bản app trước, và hàng kéo về từ
  /// server). Xem `TransactionDao.watchByGoal`.
  /// Rút [amount] khỏi mục tiêu, chuyển về ví [walletId].
  ///
  /// Ngược chiều [depositToGoal]: ví tích luỹ của mục tiêu là **nguồn**, ví
  /// truyền vào là **đích**. Cũng ghi đúng một giao dịch `'transfer'`, nên chiều
  /// tiền đọc được từ vị trí ví tích luỹ trong hàng mà không cần thêm cột.
  ///
  /// Ném [StateError] nếu mục tiêu chưa có ví tích luỹ hoặc ví ấy **không còn
  /// đủ tiền thật**, và [ArgumentError] nếu số tiền ≤ 0, vượt quá số mục tiêu
  /// đang giữ, hoặc ví đích trùng ví tích luỹ.
  Future<void> withdrawFromGoal({
    required String goalId,
    required String goalName,
    required double amount,
    required String walletId,
    required int idaccount,
  });

  Stream<dynamic> watchGoalTransactions(
    int idaccount,
    String goalId,
    String goalName,
  );
  /// Trỏ mục tiêu sang một ví nhận khác.
  ///
  /// Đây là **đường thoát duy nhất** cho bế tắc xoá ví: ví đang liên kết với
  /// một mục tiêu thì không xoá được, nên phải chuyển mục tiêu sang ví khác
  /// trước. Cố ý không có lệnh gỡ về `null` — mục tiêu luôn phải có ví nhận,
  /// nếu không thì lần nạp sau không biết chuyển tiền đi đâu.
  Future<void> changeWallet(String goalId, String walletId);

  Future<void> deleteGoal(String id);
}
