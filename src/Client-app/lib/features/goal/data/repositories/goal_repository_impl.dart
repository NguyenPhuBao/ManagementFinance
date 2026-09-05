import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/category/category_name.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_engine.dart';
import '../datasources/goal_local_data_source.dart';
import '../../domain/goal_history_direction.dart';
import '../../domain/goal_recurrence.dart';
import '../models/goal_entity.dart';
import 'goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  final GoalLocalDataSource localDataSource;
  final AppDatabase? db;
  final SyncEngine? syncEngine;

  GoalRepositoryImpl({
    required this.localDataSource,
    this.db,
    this.syncEngine,
  });

  @override
  Future<List<GoalEntity>> getGoals(int idaccount) {
    return localDataSource.getGoals(idaccount);
  }

  @override
  Stream<List<GoalEntity>> watchGoals(int idaccount) {
    return localDataSource.watchGoals(idaccount);
  }

  @override
  Future<GoalEntity?> getGoalById(String id) {
    return localDataSource.getGoalById(id);
  }

  /// Tên mục tiêu đã có người dùng trong cùng tài khoản chưa?
  ///
  /// ## Vì sao mục tiêu cũng cần quy tắc này
  ///
  /// Không phải để cho gọn danh sách. `TransactionDao.watchByGoal` nối lịch sử
  /// tích luỹ bằng `goalId` cho hàng mới, nhưng vẫn giữ **nhánh dự phòng** tra
  /// bằng `LIKE` trên ghi chú `"Tích lũy mục tiêu: <tên>"` — nhánh ấy là thứ
  /// duy nhất tìm lại được hàng do bản app cũ tạo và hàng kéo về từ server
  /// (cột `goalId` là cục bộ nên server không bao giờ trả nó về). Hai mục tiêu
  /// trùng tên thì cả hai cùng nhận vơ đúng những hàng ấy.
  ///
  /// ## Ba lựa chọn đã chốt, giống hệt danh mục
  ///
  /// - So tên bằng [normalizeCategoryName] — **định nghĩa duy nhất** của phép
  ///   so tên trong dự án. Đừng viết biến thể khác, và tuyệt đối đừng dùng
  ///   `removeVietnameseTones()`: bỏ dấu là phép so *mất thông tin*.
  /// - Hàng đã **xoá mềm không giữ chỗ** — `goalDao.getAll` đã lọc `deletedAt`.
  ///   Giữ chỗ thì người dùng xoá rồi không tạo lại được bằng chính tên ấy mà
  ///   cũng không thấy gì đang chiếm chỗ.
  /// - Chỉ xét khi tên **thật sự đổi** ([tenHienTai]). Máy người dùng có thể
  ///   đang giữ sẵn hai mục tiêu trùng tên do bản client trước tạo; chặn tuyệt
  ///   đối là chúng kẹt vĩnh viễn, không sửa nổi cả số tiền lẫn biểu tượng.
  Future<bool> _trungTen({
    required int idaccount,
    required String ten,
    String? boQuaId,
    String? tenHienTai,
  }) async {
    final dich = normalizeCategoryName(ten);
    if (tenHienTai != null && normalizeCategoryName(tenHienTai) == dich) {
      return false;
    }
    final dangCo = await localDataSource.getGoals(idaccount);
    return dangCo.any(
      (g) => g.id != boQuaId && normalizeCategoryName(g.name) == dich,
    );
  }

  @override
  Future<GoalEntity> addGoal({
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
    final tenGon = name.trim();
    if (await _trungTen(idaccount: idaccount, ten: tenGon)) {
      throw GoalValidationException(
        'Đã có mục tiêu tên "$tenGon". Mỗi tài khoản không được có hai mục '
        'tiêu trùng tên.',
      );
    }

    final now = DateTime.now();
    // Cùng luật với `updateGoal`: đủ CẢ HAI mảnh mới là bật.
    final batTrich = autoDepositAmount != null &&
        autoDepositAmount > 0 &&
        autoDepositWalletId != null &&
        autoDepositWalletId.isNotEmpty;
    final goal = GoalEntity(
      id: const Uuid().v4(),
      idaccount: idaccount,
      name: tenGon,
      targetAmount: targetAmount,
      currentAmount: 0.0,
      // Mốc bắt đầu tính nhịp tiến độ là lúc tạo. Bỏ trống thì
      // `isBehindSchedule` trả `false` vĩnh viễn cho mục tiêu này (nó cố ý im
      // lặng khi thiếu căn cứ), nên luật thông báo "chậm tiến độ" không bao
      // giờ nổ — hỏng lặng lẽ, không exception, không log. Nhánh kéo về từ
      // server vẫn ghi đè bằng `Start_date` của backend như trước.
      startDate: now,
      targetDate: targetDate,
      walletId: walletId,
      cycleTakeMoney: cycleTakeMoney,
      timeCycleTakeMoney: batTrich ? autoDepositAnchor : null,
      autoDepositAmount: batTrich ? autoDepositAmount : null,
      autoDepositWalletId: batTrich ? autoDepositWalletId : null,
      // Mốc chạy là LÚC TẠO, nên kỳ đầu tiên rơi vào một chu kỳ sau đó. Không
      // trích ngay lúc bấm "Tạo": người dùng vừa mô tả một kế hoạch, chưa đồng
      // ý cho tiền rời ví ngay giây này.
      autoDepositLastRun: batTrich ? now : null,
      // Lặp lại cần ĐỦ cả hai mảnh, cùng luật với trích tự động: bật mà
      // không có chu kỳ thì `batDauVongMoi` không biết dời hạn đi đâu.
      recurrence: recurrence == true && timeRecurrence != null,
      timeRecurrence: recurrence == true ? timeRecurrence : null,
      icon: icon ?? 'flag',
      colour: colour ?? '#4CAF50',
      note: note ?? '',
      isCompleted: false,
      isDeleted: false,
      syncStatus: 'pending',
      updatedAt: now,
    );

    await localDataSource.addGoal(goal);
    syncEngine?.scheduleSync();
    return goal;
  }

  @override
  Future<void> updateAmount({
    required String id,
    required double newAmount,
  }) async {
    await localDataSource.updateGoalAmount(id, newAmount);
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> updateGoal({
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
    // Kiểm ở tầng này chứ không chỉ ở form. Trang sửa đã chặn cả hai ca, nhưng
    // phép kiểm nằm một mình trên giao diện thì đường gọi nào khác cũng đi vòng
    // qua được — và mục tiêu 0 đồng làm `GoalEntity.progress` trả thẳng `1.0`,
    // tức một mục tiêu tự nhận đã hoàn thành mà không có đồng nào.
    final tenGon = name.trim();
    if (tenGon.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tên mục tiêu không được rỗng.');
    }
    if (targetAmount <= 0) {
      throw ArgumentError.value(
        targetAmount,
        'targetAmount',
        'Số tiền mục tiêu phải lớn hơn 0.',
      );
    }

    final goal = await localDataSource.getGoalById(id);
    if (goal == null) {
      throw StateError('Không tìm thấy mục tiêu $id.');
    }

    // Đường SỬA cũng phải chặn, không chỉ đường tạo: tạo hai tên khác nhau rồi
    // đổi một cái thành cái kia là đi vòng qua trọn vẹn quy tắc.
    if (await _trungTen(
      idaccount: goal.idaccount,
      ten: tenGon,
      boQuaId: id,
      tenHienTai: goal.name,
    )) {
      throw GoalValidationException(
        'Đã có mục tiêu tên "$tenGon". Mỗi tài khoản không được có hai mục '
        'tiêu trùng tên.',
      );
    }

    if (db == null) return;

    // Trích tự động cần ĐỦ cả hai mảnh; thiếu một là tắt. Đoán bù mảnh thiếu
    // (một ví nguồn mặc định, một số tiền suy từ chu kỳ) chính là kiểu tự tiện
    // đã bị loại ở mục 3.1 — và ở đây nó tự tiện bằng tiền thật.
    final batTrich = autoDepositAmount != null &&
        autoDepositAmount > 0 &&
        autoDepositWalletId != null &&
        autoDepositWalletId.isNotEmpty;

    // Mốc chạy chỉ đặt khi công tắc chuyển TỪ tắt SANG bật. Đặt lại ở mỗi lần
    // lưu làm kỳ trích lùi ra xa mãi; giữ lại khi tắt thì bật lần sau sẽ tính
    // bù cả quãng công tắc đang tắt, tức trích tiền cho thời gian người dùng đã
    // cố ý dừng.
    final Value<DateTime?> mocChay;
    if (!batTrich) {
      mocChay = const Value(null);
    } else if (goal.autoDepositLastRun == null) {
      mocChay = Value(DateTime.now());
    } else {
      mocChay = const Value.absent();
    }

    // Chỉ gán bốn cột mô tả. `currentAmount`, `walletId` và `startDate` vắng
    // mặt ở đây là CÓ CHỦ Ý — xem chú thích ở `GoalRepository.updateGoal`.
    //
    // Cờ hoàn thành tính lại theo mục tiêu MỚI, cùng luật với `withdrawFromGoal`:
    // hạ mục tiêu xuống dưới số đã tích thì bật, nâng lên trên thì gỡ.
    await (db!.update(db!.goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        name: Value(tenGon),
        targetAmount: Value(targetAmount),
        targetDate: Value(targetDate),
        // `Value(null)` chứ không `Value.absent()`: null ở đây nghĩa là XOÁ chu
        // kỳ, không phải "giữ nguyên".
        cycleTakeMoney: Value(cycleTakeMoney),
        // Mốc neo là nửa còn lại của kế hoạch, cùng số phận với chu kỳ: tắt
        // trích tự động là xoá. Để sót lại thì bật lần sau dùng một nhịp cũ mà
        // người dùng không còn nhìn thấy ở đâu.
        timeCycleTakeMoney:
            batTrich ? Value(autoDepositAnchor) : const Value(null),
        // Ngược lại với chu kỳ: `Value.absent()` chứ không `Value(null)`. Biểu
        // tượng và màu không có trạng thái "không có", nên null ở đây nghĩa là
        // nơi gọi không đụng tới chúng — gán đại sẽ đưa cột về mặc định và mọi
        // mục tiêu lặng lẽ trở lại lá cờ xanh sau một lần sửa tên.
        icon: icon == null ? const Value.absent() : Value(icon),
        colour: colour == null ? const Value.absent() : Value(colour),
        // Cùng luật với hai cột trên, nhưng lưu ý chỗ khác: **chuỗi rỗng** ở
        // đây là ý định XOÁ rõ ràng (người dùng đã xoá sạch ô nhập), nên nó
        // vẫn được ghi xuống. Chỉ `null` mới là "không đụng tới".
        note: note == null ? const Value.absent() : Value(note),
        // Cùng luật với trích tự động: tắt là XOÁ luôn chu kỳ. Để sót lại thì
        // bật lần sau dùng một nhịp cũ mà người dùng không còn thấy ở đâu.
        //
        // `null` ở đây là "nơi gọi không đụng tới" — trang sửa luôn truyền cả
        // hai, nhưng đường gọi khác thì không nhất thiết.
        recurrence: recurrence == null
            ? const Value.absent()
            : Value(recurrence && timeRecurrence != null),
        timeRecurrence: recurrence == null
            ? const Value.absent()
            : Value(recurrence ? timeRecurrence : null),
        autoDepositAmount:
            batTrich ? Value(autoDepositAmount) : const Value(null),
        autoDepositWalletId:
            batTrich ? Value(autoDepositWalletId) : const Value(null),
        autoDepositLastRun: mocChay,
        isCompleted: Value(goal.currentAmount >= targetAmount),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> batDauVongMoi(String goalId) async {
    final goal = await localDataSource.getGoalById(goalId);
    if (goal == null) {
      throw StateError('Không tìm thấy mục tiêu $goalId.');
    }

    // Hai phép chặn, và chúng nằm ở TẦNG NÀY chứ không phải ở chỗ ẩn nút đi.
    // Đặt lại một mục tiêu đang dở là xoá tiến độ người dùng đã tích được, và
    // không có gì hoàn tác lại được.
    if (!goal.daHoanThanh) {
      throw GoalValidationException(
        'Mục tiêu "${goal.name}" chưa hoàn thành nên chưa có vòng nào để lặp '
        'lại.',
      );
    }
    if (!goal.recurrence) {
      throw GoalValidationException(
        'Mục tiêu "${goal.name}" chưa bật lặp lại. Mở phần chỉnh sửa để bật.',
      );
    }

    if (db == null) return;
    final now = DateTime.now();

    final hanMoi = hanVongMoi(
      hanCu: goal.targetDate,
      chuKy: goal.timeRecurrence,
      now: now,
    );
    if (hanMoi == null) {
      throw GoalValidationException(
        'Hạn định của mục tiêu "${goal.name}" nằm quá xa để tính được vòng '
        'tiếp theo. Hãy sửa lại hạn định trước.',
      );
    }

    // KHÔNG đụng `walletId` lẫn số dư ví nào: tiền của vòng cũ vẫn nằm nguyên
    // trong ví tích luỹ. Người dùng mới chỉ bấm "bắt đầu vòng mới" — suy ra
    // rằng họ cũng muốn chuyển tiền đi là đúng kiểu tự tiện mà cả tính năng
    // mục tiêu tránh từ đầu.
    await (db!.update(db!.goals)..where((t) => t.id.equals(goalId))).write(
      GoalsCompanion(
        currentAmount: const Value(0.0),
        isCompleted: const Value(false),
        // Mốc bắt đầu là BÂY GIỜ. `tocDoThucTe` đo từ nó, nên giữ mốc cũ thì
        // vòng mới hiện tốc độ tiết kiệm của vòng trước.
        startDate: Value(now),
        targetDate: Value(hanMoi),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ),
    );
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> depositToGoal({
    required String goalId,
    required String goalName,
    required double depositAmount,
    required int idaccount,
    required String walletId,
    DateTime? occurredAt,
  }) async {
    // Một lần nạp là bốn thao tác ghi: tăng tiến độ mục tiêu, có thể đánh dấu
    // hoàn thành, đổi số dư hai ví, và chèn MỘT giao dịch chuyển khoản. Chạy
    // rời rạc thì một sự cố ở giữa để lại tiền đã trừ khỏi ví mà mục tiêu chưa
    // tăng — người dùng mất tiền, không có gì ghi nhận, và không có exception
    // nào tới được màn hình. Cả khối phải cùng sống hoặc cùng chết.
    final now = DateTime.now();

    Future<void> ghiCaKhoi() async {
      // Phép kiểm số tiền ở TẦNG NÀY, không chỉ ở ô nhập. Trang chi tiết đã
      // chặn, nhưng phép kiểm nằm một mình trên giao diện thì mọi đường gọi
      // khác đi vòng qua được — và số âm chạy trót lọt tới cuối: ví nguồn được
      // CỘNG tiền trong khi tiến độ mục tiêu tụt xuống.
      if (depositAmount <= 0) {
        throw ArgumentError.value(
          depositAmount,
          'depositAmount',
          'Số tiền nạp phải lớn hơn 0.',
        );
      }

      final goal = await localDataSource.getGoalById(goalId);
      if (goal == null) {
        throw StateError('Không tìm thấy mục tiêu $goalId.');
      }

      // Hai đầu chặn của [occurredAt], và chúng phải đi cùng nhau.
      //
      // Tham số này tồn tại cho đúng MỘT việc: đưa một khoản trích **bù** về
      // mốc kỳ đáng lẽ nó xảy ra. Đây là tầng ghi tiền, chỗ ít đáng nới lỏng
      // nhất, nên chỉ chặn đầu trên là chưa đủ — bịa về quá khứ cũng là bịa,
      // và khoản nạp sẽ rơi xuống đáy lịch sử tích luỹ ở một chỗ mục tiêu còn
      // chưa ra đời.
      //
      // Bộ trích tự động không bao giờ chạm hai đầu này: `cacKyDenHan` sinh ra
      // các mốc nằm SAU `autoDepositLastRun` (đặt lúc bật công tắc, tức sau
      // `startDate`) và KHÔNG sau `now`.
      if (occurredAt != null) {
        if (occurredAt.isAfter(now)) {
          throw ArgumentError.value(
            occurredAt,
            'occurredAt',
            'Không ghi được một khoản nạp mang dấu thời gian ở tương lai.',
          );
        }
        final batDau = goal.startDate;
        if (batDau != null && occurredAt.isBefore(batDau)) {
          throw ArgumentError.value(
            occurredAt,
            'occurredAt',
            'Mục tiêu "${goal.name}" mới bắt đầu từ $batDau.',
          );
        }
      }

      // Ví nhận đọc từ chính mục tiêu. Nơi gọi KHÔNG truyền vào: ví ấy được
      // chọn một lần lúc tạo mục tiêu và chỉ đổi qua `changeWallet`.
      //
      // Chỉ mục tiêu do bản app cũ tạo mới có thể thiếu ví. Đoán bừa một ví
      // nhận chính là lỗi vừa gỡ bỏ; còn im lặng tăng tiến độ mà không chuyển
      // tiền thì số dư ví và sổ sách lệch nhau vĩnh viễn.
      final viNhan = goal.walletId;
      if (viNhan == null || viNhan.isEmpty) {
        throw StateError(
          'Mục tiêu "${goal.name}" chưa có ví nhận tiền tích lũy.',
        );
      }
      if (viNhan == walletId) {
        throw ArgumentError.value(
          walletId,
          'walletId',
          'Ví nguồn trùng ví nhận: chuyển tiền sang chính nó chỉ đẻ ra một '
              'hàng vô nghĩa trong khi tiến độ mục tiêu vẫn tăng.',
        );
      }

      // Trần "tiền THẬT trong ví", đối xứng với `withdrawFromGoal`. Thiếu nó
      // thì đoạn dưới trừ thẳng và ví nguồn xuống ÂM — mục tiêu tích được một
      // số tiền chưa từng tồn tại. Giao diện và bộ trích tự động đều đã chặn ca
      // này, nhưng cả hai đều nằm NGOÀI khối nguyên tử, tức không phải là chỗ
      // giữ bất biến.
      //
      // Đọc ví nguồn trước khi ghi bất cứ thứ gì: `db == null` (đường không có
      // CSDL) thì không có số dư để so, và ca ấy vốn cũng không chuyển tiền.
      final viNguon = db == null ? null : await db!.walletDao.getById(walletId);
      if (viNguon != null && depositAmount > viNguon.balance) {
        throw StateError(
          'Ví "${viNguon.name}" chỉ còn ${viNguon.balance} — không đủ để nạp '
          '$depositAmount vào mục tiêu "${goal.name}".',
        );
      }

      final newGoalAmount = goal.currentAmount + depositAmount;
      await localDataSource.updateGoalAmount(goalId, newGoalAmount);

      if (newGoalAmount >= goal.targetAmount && db != null) {
        await (db!.update(db!.goals)..where((t) => t.id.equals(goalId))).write(
          const GoalsCompanion(
            isCompleted: Value(true),
            syncStatus: Value('pending'),
          ),
        );
      }

      if (db == null) return;

      if (viNguon != null) {
        await db!.walletDao
            .updateBalance(walletId, viNguon.balance - depositAmount);
      }
      final viDich = await db!.walletDao.getById(viNhan);
      if (viDich != null) {
        await db!.walletDao
            .updateBalance(viNhan, viDich.balance + depositAmount);
      }

      // MỘT hàng duy nhất, kiểu 'transfer' — cùng quy ước với chuyển khoản của
      // tính năng giao dịch thường. Trước đây chỗ này ghi hai hàng rời ('chi' ở
      // ví nguồn, 'thu' ở ví đích) cho một việc duy nhất là chuyển tiền giữa
      // hai ví của cùng người dùng, khiến phần thống kê đếm khoản này thành chi
      // tiêu thật.
      //
      // `walletTransfer` là chỗ duy nhất ghi lại tiền đã đi đâu, và payload đẩy
      // đã có sẵn `idwallet_transfer` cho nó. Tính năng giao dịch thường hiện
      // KHÔNG điền cột này (`TransactionEntity` không có trường tương ứng) —
      // đây là chỗ Goal làm đầy đủ hơn, không phải chỗ lệch.
      await db!.transactionDao.insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          idaccount: idaccount,
          walletId: walletId,
          walletTransfer: Value(viNhan),
          amount: depositAmount,
          type: 'transfer',
          note: Value('$kGhiChuNapMucTieu$goalName'),
          goalId: Value(goalId),
          // `date` là ngày của SỰ VIỆC, `updatedAt` là sổ sách ĐỒNG BỘ — hai
          // thứ khác nhau và chỉ cái đầu lùi về mốc kỳ. Lùi `updatedAt` theo
          // sẽ làm phép phân xử LWW coi bản ghi này cũ hơn thực tế và ghi đè
          // mất chính khoản vừa trích.
          date: occurredAt ?? now,
          syncStatus: const Value('pending'),
          updatedAt: now,
        ),
      );
    }

    if (db != null) {
      await db!.transaction(ghiCaKhoi);
    } else {
      // Không có `db` thì chỉ có mỗi thao tác cập nhật tiến độ, không có gì để
      // giữ nguyên tử.
      await ghiCaKhoi();
    }

    syncEngine?.scheduleSync();
  }

  @override
  Future<void> withdrawFromGoal({
    required String goalId,
    required String goalName,
    required double amount,
    required String walletId,
    required int idaccount,
  }) async {
    Future<void> ghiCaKhoi() async {
      final goal = await localDataSource.getGoalById(goalId);
      if (goal == null) {
        throw StateError('Không tìm thấy mục tiêu $goalId.');
      }

      final viTichLuy = goal.walletId;
      if (viTichLuy == null || viTichLuy.isEmpty) {
        throw StateError(
          'Mục tiêu "${goal.name}" chưa có ví tích lũy nên không có gì để rút.',
        );
      }
      if (viTichLuy == walletId) {
        throw ArgumentError.value(walletId, 'walletId',
            'Ví đích trùng ví tích lũy: tiền không đi đâu cả.');
      }
      if (amount <= 0) {
        throw ArgumentError.value(amount, 'amount', 'Số tiền phải lớn hơn 0.');
      }

      // Hai trần khác nhau, và phải kiểm CẢ HAI.
      //
      // Trần thứ nhất là tiến độ: rút quá số mục tiêu đang ghi nhận thì tiến độ
      // xuống âm.
      if (amount > goal.currentAmount) {
        throw ArgumentError.value(
          amount,
          'amount',
          'Mục tiêu "${goal.name}" mới tích được ${goal.currentAmount}.',
        );
      }

      if (db == null) return;

      // Trần thứ hai là tiền THẬT trong ví. Hai con số này lệch nhau được —
      // người dùng có thể đã tiêu bớt tiền trong ví tích lũy bằng một giao dịch
      // thường, mà giao dịch ấy không mang `goalId` nên không hạ tiến độ. Bỏ
      // qua trần này là đưa ví về số dư âm, tức tạo tiền từ hư không.
      final viNguon = await db!.walletDao.getById(viTichLuy);
      if (viNguon == null) {
        throw StateError('Không tìm thấy ví tích lũy $viTichLuy.');
      }
      if (amount > viNguon.balance) {
        throw StateError(
          'Ví "${viNguon.name}" chỉ còn ${viNguon.balance} — ít hơn số mục '
          'tiêu đang ghi nhận. Có khoản chi nào đó đã tiêu vào tiền tích lũy.',
        );
      }

      final soConLai = goal.currentAmount - amount;
      final now = DateTime.now();

      // Gỡ cờ hoàn thành khi tụt xuống dưới mục tiêu. Giữ cờ thì
      // `_goalCandidates` bỏ qua mục tiêu này vĩnh viễn — rút gần hết mà nó
      // không bao giờ nhắc "chậm tiến độ" nữa. Cờ và thanh tiến độ phải nói
      // cùng một điều.
      await (db!.update(db!.goals)..where((t) => t.id.equals(goalId))).write(
        GoalsCompanion(
          currentAmount: Value(soConLai),
          isCompleted: Value(soConLai >= goal.targetAmount),
          syncStatus: const Value('pending'),
          updatedAt: Value(now),
        ),
      );

      // Ví đích PHẢI tồn tại. Cột `walletTransfer` không khai khoá ngoại, nên
      // thiếu phép kiểm này thì tiền rời ví tích lũy mà không ví nào được
      // cộng — hàng giao dịch ghi một khoản chuyển tới ví ma, và tiền biến mất
      // khỏi tổng tài sản mà không có gì báo.
      final viDich = await db!.walletDao.getById(walletId);
      if (viDich == null) {
        throw StateError('Không tìm thấy ví đích $walletId.');
      }

      await db!.walletDao.updateBalance(viTichLuy, viNguon.balance - amount);
      await db!.walletDao.updateBalance(walletId, viDich.balance + amount);

      await db!.transactionDao.insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          idaccount: idaccount,
          // Ngược chiều nạp tiền: ví tích lũy là NGUỒN.
          walletId: viTichLuy,
          walletTransfer: Value(walletId),
          amount: amount,
          type: 'transfer',
          note: Value('$kGhiChuRutMucTieu$goalName'),
          goalId: Value(goalId),
          date: now,
          syncStatus: const Value('pending'),
          updatedAt: now,
        ),
      );
    }

    if (db != null) {
      await db!.transaction(ghiCaKhoi);
    } else {
      await ghiCaKhoi();
    }

    syncEngine?.scheduleSync();
  }

  @override
  Stream<dynamic> watchGoalTransactions(
    int idaccount,
    String goalId,
    String goalName,
  ) {
    if (db != null) {
      return db!.transactionDao.watchByGoal(idaccount, goalId, goalName);
    }
    return Stream.value([]);
  }

  @override
  Future<void> changeWallet(String goalId, String walletId) async {
    if (db == null) return;

    final goal = await localDataSource.getGoalById(goalId);
    if (goal == null) {
      throw StateError('Không tìm thấy mục tiêu $goalId.');
    }

    // Khoá ví sau khoản nạp đầu tiên.
    //
    // Tiền đã tích được đang nằm THẬT trong ví hiện tại. Đổi ví mà không chuyển
    // tiền theo thì mục tiêu báo 2 triệu trong khi số ấy nằm rải ở ví khác —
    // càng đổi càng phân mảnh, và không có gì trong app lần lại được số tiền
    // của một mục tiêu đang nằm ở những đâu.
    //
    // Ngoại lệ: mục tiêu **chưa có ví nào**. Mục tiêu do bản app cũ tạo có thể
    // vừa thiếu ví vừa đã tích được tiền; chặn cả ca đó là chúng kẹt vĩnh viễn,
    // không nạp thêm được mà cũng không gắn được ví.
    if (goal.walletId != null && goal.currentAmount > 0) {
      throw StateError(
        'Mục tiêu "${goal.name}" đã tích được tiền trong ví hiện tại nên '
        'không đổi ví được.',
      );
    }

    await (db!.update(db!.goals)..where((t) => t.id.equals(goalId))).write(
      GoalsCompanion(
        walletId: Value(walletId),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> deleteGoal(String id) async {
    await localDataSource.deleteGoal(id);
    syncEngine?.scheduleSync();
  }
}
