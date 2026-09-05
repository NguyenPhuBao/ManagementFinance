import '../models/goal_entity.dart';

/// Lỗi do **người dùng nhập sai**, không phải lỗi lập trình.
///
/// Cùng mẫu với `CategoryValidationException`, và vì cùng một lý do: câu lỗi
/// này đi thẳng ra snackbar qua `e.toString()`, nên nó phải đọc được. Một
/// `ArgumentError` ở đây hiện ra thành
/// `Invalid argument (name): <câu tiếng Việt>: "<giá trị>"` — người dùng không
/// hiểu được nửa đầu lẫn nửa cuối.
class GoalValidationException implements Exception {
  const GoalValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

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

    /// Bật lặp lại mục tiêu sau khi hoàn thành, kèm chu kỳ [timeRecurrence].
    bool? recurrence,
    String? timeRecurrence,
    /// Đi thành cặp với [autoDepositWalletId]; đủ cả hai là bật trích tự động
    /// ngay từ lúc tạo, và mốc chạy được đặt bằng "bây giờ" nên kỳ đầu tiên rơi
    /// vào một chu kỳ sau đó.
    double? autoDepositAmount,
    String? autoDepositWalletId,
    /// **Mốc neo** của nhịp trích ("ngày 15 hàng tháng lúc 08:00"), lưu vào cột
    /// đồng bộ được `timeCycleTakeMoney`. Cùng số phận với [cycleTakeMoney]:
    /// tắt trích tự động là xoá nó.
    DateTime? autoDepositAnchor,
  });
  Future<void> updateAmount({
    required String id,
    required double newAmount,
  });

  /// Sửa phần **mô tả** của một mục tiêu: tên, số tiền đích, hạn định, chu kỳ.
  ///
  /// Cố ý KHÔNG nhận `currentAmount` lẫn `walletId`. Số đã tích được là tiền
  /// thật đang nằm trong ví — nó chỉ đổi qua [depositToGoal]/[withdrawFromGoal],
  /// nơi số dư ví đổi theo cùng lúc. Ví tích luỹ chỉ đổi qua [changeWallet],
  /// nơi có phép khoá sau khoản nạp đầu tiên; cho form sửa ghi thẳng cột ấy là
  /// đi vòng qua khoá.
  ///
  /// Cờ hoàn thành được **tính lại**, cùng luật với [withdrawFromGoal]: nó là
  /// giá trị suy ra từ tiến độ so với mục tiêu, không phải một ô người dùng
  /// bật tắt. Nâng mục tiêu lên mà giữ cờ thì `_goalCandidates` bỏ qua mục tiêu
  /// này vĩnh viễn và nó không bao giờ nhắc "chậm tiến độ" nữa.
  ///
  /// [cycleTakeMoney] bằng `null` nghĩa là **xoá** chu kỳ đã lưu, không phải
  /// "giữ nguyên" — người dùng tắt công tắc trích tiền định kỳ thì kế hoạch cũ
  /// phải biến mất, nếu không hộp dự báo cứ so với một nhịp đã bị bỏ.
  ///
  /// Ném [ArgumentError] nếu tên rỗng hoặc số tiền ≤ 0, và [StateError] nếu
  /// không tìm thấy mục tiêu.
  ///
  /// [icon], [colour] và [note] bằng `null` nghĩa là **giữ nguyên**, ngược với
  /// [cycleTakeMoney]. Hai cột đầu không có trạng thái "không có" — đưa chúng
  /// về mặc định khi nơi gọi chỉ muốn sửa tên sẽ làm mọi mục tiêu lặng lẽ trở
  /// lại lá cờ xanh. Với [note] thì **chuỗi rỗng mới là xoá**: đó là ý định rõ
  /// ràng của người dùng khi họ xoá sạch ô nhập, còn `null` chỉ có nghĩa nơi
  /// gọi không đụng tới. Gộp hai ca ấy làm một thì không còn cách nào bỏ ghi
  /// chú đi.
  ///
  /// [autoDepositAmount] và [autoDepositWalletId] đi **thành cặp**: đủ cả hai
  /// là bật trích tự động, thiếu một là tắt. `autoDepositLastRun` do đây đặt,
  /// nơi gọi không truyền vào — nó là mốc "lúc bật", và chỉ được đặt khi công
  /// tắc chuyển từ tắt sang bật. Sửa tên hay đổi số tiền **không** đặt lại mốc:
  /// làm vậy thì người dùng sửa mục tiêu hàng tháng sẽ không bao giờ tới kỳ.
  Future<void> updateGoal({
    required String id,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String? cycleTakeMoney,
    String? icon,
    String? colour,
    String? note,

    /// Bật lặp lại mục tiêu sau khi hoàn thành. `false` **xoá luôn**
    /// [timeRecurrence] — cùng số phận với mốc neo khi tắt trích tự động: để
    /// sót lại thì bật lần sau dùng một nhịp cũ mà người dùng không còn nhìn
    /// thấy ở đâu.
    bool? recurrence,

    /// Chu kỳ giữa hai VÒNG, khác [cycleTakeMoney] (nhịp trích tiền TRONG một
    /// vòng). Hai tên gần nhau đến khó chịu, nhưng đó là tên backend đã đặt và
    /// đổi tên một cột dùng chung thì phía kia phải đồng ý trước.
    String? timeRecurrence,
    double? autoDepositAmount,
    String? autoDepositWalletId,
    /// **Mốc neo** của nhịp trích ("ngày 15 hàng tháng lúc 08:00"), lưu vào cột
    /// đồng bộ được `timeCycleTakeMoney`. Cùng số phận với [cycleTakeMoney]:
    /// tắt trích tự động là xoá nó.
    DateTime? autoDepositAnchor,
  });

  /// Bắt đầu một **vòng mới** cho mục tiêu đã hoàn thành và có bật lặp lại.
  ///
  /// Đặt tiến độ về 0, gỡ cờ hoàn thành, dời hạn tới kỳ kế tiếp và đặt lại mốc
  /// bắt đầu bằng "bây giờ".
  ///
  /// ⚠️ **KHÔNG đụng một đồng nào.** Tiền của vòng cũ vẫn nằm trong ví tích
  /// luỹ; người dùng tự rút khi muốn tiêu. Họ mới chỉ bấm "bắt đầu vòng mới" —
  /// suy ra rằng họ cũng muốn chuyển tiền đi là đúng kiểu tự tiện mà cả tính
  /// năng mục tiêu tránh từ đầu.
  ///
  /// Mốc bắt đầu phải đặt lại: `tocDoThucTe` đo từ nó, nên giữ mốc cũ thì vòng
  /// mới hiện tốc độ tiết kiệm của vòng trước.
  ///
  /// Ném [GoalValidationException] nếu mục tiêu chưa xong hoặc chưa bật lặp
  /// lại. Phép chặn nằm ở tầng này chứ không phải ở chỗ ẩn nút đi: đặt lại một
  /// mục tiêu đang dở là xoá tiến độ đã tích được, và không có gì hoàn tác.
  Future<void> batDauVongMoi(String goalId);

  /// Chuyển [depositAmount] từ ví [walletId] sang **ví nhận của mục tiêu** và
  /// tăng tiến độ tương ứng.
  ///
  /// Ví nhận đọc từ chính mục tiêu, nơi gọi không truyền vào: ví ấy được chọn
  /// một lần lúc tạo mục tiêu và chỉ đổi qua [changeWallet].
  ///
  /// Ném [StateError] nếu mục tiêu chưa có ví nhận (chỉ xảy ra với mục tiêu do
  /// bản app cũ tạo) hoặc ví nguồn **không đủ tiền thật**, và [ArgumentError]
  /// nếu ví nguồn trùng ví nhận, số tiền ≤ 0, hoặc [occurredAt] nằm ngoài
  /// khoảng cho phép.
  ///
  /// Hai phép kiểm cuối trùng với phép kiểm đã có ở ô nhập — cố ý. Phép kiểm
  /// nằm một mình trên giao diện thì mọi đường gọi khác đi vòng qua được, và
  /// nó cũng nằm NGOÀI khối nguyên tử nên không phải là chỗ giữ bất biến.
  Future<void> depositToGoal({
    required String goalId,
    required String goalName,
    required double depositAmount,
    required String walletId,
    required int idaccount,

    /// Thời điểm của **sự việc**, mặc định là "bây giờ".
    ///
    /// Chỉ tồn tại cho bộ trích tự động: khi app đóng nhiều kỳ, các kỳ bỏ lỡ
    /// được trích **bù** cùng một lượt, và mỗi hàng giao dịch phải mang mốc
    /// của kỳ nó thuộc về chứ không phải thời điểm bù. Không có nó thì ba kỳ
    /// dồn thành một cột trong thống kê theo ngày, trong khi trung tâm thông
    /// báo — vốn lấy mốc kỳ — hiện đúng ba ngày.
    ///
    /// **Đường nạp tay không truyền tham số này** và không nên bắt đầu truyền:
    /// đây là tầng ghi tiền, và một ngày do nơi gọi tự đặt là một ngày bịa.
    /// Hai đầu chặn (không ở tương lai, không trước `startDate` của mục tiêu)
    /// là thứ giữ cho tham số không trở thành cửa sau.
    ///
    /// Chỉ đổi cột `date`. `updatedAt` vẫn là "bây giờ" vì nó là sổ sách đồng
    /// bộ, không phải ngày của sự việc.
    DateTime? occurredAt,
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
