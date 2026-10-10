import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../data/models/goal_entity.dart';
import '../data/repositories/goal_repository.dart';
import 'goal_auto_deposit.dart';
import 'id_khoan_trich.dart';

/// Kết quả của **một** kỳ trích, để nơi gọi dựng thông báo.
///
/// Cố ý không mang câu chữ: nội dung thông báo nằm trọn trong
/// `notification_rules.dart` cùng bảy luật còn lại. Hai nơi cùng viết câu thông
/// báo là hai giọng khác nhau trong cùng một trung tâm thông báo.
class GoalAutoDepositEvent {
  const GoalAutoDepositEvent({
    required this.goalId,
    required this.goalName,
    required this.ky,
    required this.loai,
    required this.soTien,
    this.tenViNguon,
  });

  final String goalId;
  final String goalName;

  /// Mốc của kỳ. Đi vào khoá chống trùng của thông báo.
  final DateTime ky;

  final LoaiTrich loai;

  /// Số tiền thật sự đã chuyển. 0 với mọi nhánh không trích được.
  final double soTien;

  /// Tên ví nguồn, để câu thông báo nói rõ tiền đi từ đâu. `null` khi ví đã
  /// không còn.
  final String? tenViNguon;
}

/// Chạy các kỳ trích tự động đã tới hạn.
///
/// ## Vì sao đi qua `depositToGoal` chứ không tự ghi
///
/// Một lần trích phải làm đúng bốn việc của một lần nạp: tăng tiến độ, tính lại
/// cờ hoàn thành, đổi số dư hai ví, ghi MỘT giao dịch `'transfer'` — tất cả
/// trong một `db.transaction`. Viết lại chuỗi ấy ở đây là tạo bản sao thứ hai
/// của định nghĩa "nạp tiền là gì", và bản sao sẽ lệch đi ở lần sửa sau.
///
/// ## Ai gọi
///
/// `NotificationScanner.scan()` — khi app mở, VÀ từ 2026-10-10 từ engine nền
/// của WorkManager (Android, spec `2026-10-10-tu-chuyen-tien-chay-nen-design.md`;
/// mở lại G22). Hai lượt cùng tiến trình chặn bằng **khoá thuê** SQLite ở vòng
/// quét; hai MÁY chặn bằng id tất định `idKhoanTrichTuDong` — cùng (mục tiêu,
/// kỳ) thì server ghép làm một hàng. Các kỳ bỏ lỡ vẫn được **trích bù** theo
/// đúng thứ tự, mỗi khoản mang mốc kỳ của nó.
class GoalAutoDepositRunner {
  GoalAutoDepositRunner({
    required this.db,
    required this.repository,
    this.toiDaMoiLuot = 12,
  });

  final AppDatabase db;
  final GoalRepository repository;

  /// Trần số kỳ xử lý cho MỖI mục tiêu trong một lượt chạy.
  final int toiDaMoiLuot;

  Future<List<GoalAutoDepositEvent>> chay(int idaccount,
      {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final ra = <GoalAutoDepositEvent>[];

    for (final row in await db.goalDao.getAll(idaccount)) {
      final goal = GoalEntity.fromDrift(row);
      if (goal.isDeleted || !goal.autoDepositEnabled) continue;
      if (goal.isCompleted || goal.remainingAmount <= 0) continue;

      // Mỗi mục tiêu độc lập: một cấu hình hỏng không được chặn những mục tiêu
      // còn lại, nếu không một lỗi lẻ làm cả tính năng ngừng chạy trong im
      // lặng.
      ra.addAll(await _chayMotMucTieu(goal, idaccount, at));
    }

    return ra;
  }

  Future<List<GoalAutoDepositEvent>> _chayMotMucTieu(
    GoalEntity goal,
    int idaccount,
    DateTime at,
  ) async {
    final cacKy = cacKyDenHan(
      // Nhịp bám mốc neo người dùng chọn; mốc chạy chỉ là SÀN. Xem
      // `cacKyDenHan`.
      mocNeo: goal.timeCycleTakeMoney,
      lanChayGanNhat: goal.autoDepositLastRun,
      chuKy: goal.cycleTakeMoney,
      now: at,
      toiDa: toiDaMoiLuot,
    );
    if (cacKy.isEmpty) return const [];

    final viNguonId = goal.autoDepositWalletId!;

    // Ví nguồn KHÔNG được bảo vệ khỏi việc xoá như ví tích luỹ (phép chặn ở
    // `wallet_local_data_source` chỉ nhìn `goals.walletId`), nên ca này xảy ra
    // thật. Và ví nguồn trùng ví tích luỹ thì tiền không đi đâu cả trong khi
    // tiến độ vẫn tăng — mục tiêu tự đầy lên từ hư không.
    // Ví ĐÃ LƯU TRỮ cũng vào nhánh này: lưu trữ là đóng băng ví, và rút tiền
    // im lặng khỏi một ví người dùng đã cất đi là cách hỏng tệ nhất ở đây —
    // họ không nhìn ví ấy nữa nên sẽ không thấy gì cả.
    final viNguon = await db.walletDao.getById(viNguonId);
    // ⚠️ `getById` trả cả hàng ĐÃ XOÁ MỀM — kiểm `null` thôi là rút tiền từ ví
    // đã xoá (ca test "ví nguồn ĐÃ XOÁ MỀM"). Luật ở `viNguonChoTrich`.
    if (viNguon == null ||
        !viNguonChoTrich(
          goal,
          viNguonConSong: !viNguon.isDeleted,
          trangThaiViNguon: viNguon.status,
        )) {
      return [
        GoalAutoDepositEvent(
          goalId: goal.id,
          goalName: goal.name,
          ky: cacKy.first,
          loai: LoaiTrich.khongChayDuoc,
          soTien: 0,
          tenViNguon: viNguon?.name,
        ),
      ];
    }

    final ra = <GoalAutoDepositEvent>[];
    var soDu = viNguon.balance;
    var daTich = goal.currentAmount;

    for (final ky in cacKy) {
      final quyetDinh = quyetDinhTrich(
        soTienCai: goal.autoDepositAmount!,
        conThieu: goal.targetAmount - daTich,
        soDuViNguon: soDu,
      );

      if (quyetDinh.loai == LoaiTrich.mucTieuDaXong) break;

      if (quyetDinh.loai == LoaiTrich.viKhongDu) {
        ra.add(GoalAutoDepositEvent(
          goalId: goal.id,
          goalName: goal.name,
          ky: ky,
          loai: LoaiTrich.viKhongDu,
          soTien: 0,
          tenViNguon: viNguon.name,
        ));
        // DỪNG hẳn, và KHÔNG đẩy mốc qua kỳ này: nhảy qua là kỳ chưa trích
        // được biến mất vĩnh viễn. Giữ lại thì nó tự thử lại khi ví có tiền.
        break;
      }

      try {
        await repository.depositToGoal(
          goalId: goal.id,
          goalName: goal.name,
          depositAmount: quyetDinh.soTien,
          walletId: viNguonId,
          idaccount: idaccount,
          // Mốc của KỲ, không phải lúc chạy. Bỏ app ba ngày với chu kỳ hàng
          // ngày thì ba kỳ được bù cùng một lượt; để chúng mang thời điểm bù
          // là ba sự việc của ba ngày dồn thành một cột trong thống kê theo
          // ngày — trong khi thông báo, vốn lấy mốc kỳ, hiện đúng ba ngày.
          occurredAt: ky,
          // Chỗ DUY NHẤT trong app truyền cờ này. Nó chỉ thêm hậu tố vào ghi
          // chú — không đổi chiều tiền, không đổi cột nào khác — để lịch sử
          // nói được ai đã chuyển khoản tiền ấy.
          tuDong: true,
          // Id tất định + mốc ghi CÙNG giao tác (spec tự chuyển tiền chạy nền
          // mục 3.4, 5): app sập giữa vòng không trích lại kỳ đã xong, và hai
          // máy cùng trích kỳ này chỉ ra một hàng trên server.
          transactionId: idKhoanTrichTuDong(goal.id, ky),
          mocChayMoi: ky,
        );
      } on KyDaTrichException {
        // Máy khác đã trích kỳ này (cùng id v5), hoặc người dùng đã xoá khoản
        // ấy. Không trừ tiền, KHÔNG sự kiện (báo "Đã trích…" cho việc máy kia
        // làm là nói dối) — chỉ đẩy mốc để lượt sau không thử lại kỳ ấy.
        await (db.update(db.goals)..where((t) => t.id.equals(goal.id)))
            .write(GoalsCompanion(autoDepositLastRun: Value(ky)));
        continue;
      } catch (e) {
        // `depositToGoal` là một khối nguyên tử — hỏng thì không để lại gì. Nuốt
        // lỗi ở đây vì nơi gọi là vòng quét thông báo: ném lên sẽ giết luôn cả
        // trung tâm thông báo, tức mất phần vẫn còn dùng được.
        ra.add(GoalAutoDepositEvent(
          goalId: goal.id,
          goalName: goal.name,
          ky: ky,
          loai: LoaiTrich.khongChayDuoc,
          soTien: 0,
          tenViNguon: viNguon.name,
        ));
        break;
      }

      soDu -= quyetDinh.soTien;
      daTich += quyetDinh.soTien;

      ra.add(GoalAutoDepositEvent(
        goalId: goal.id,
        goalName: goal.name,
        ky: ky,
        loai: quyetDinh.loai,
        soTien: quyetDinh.soTien,
        tenViNguon: viNguon.name,
      ));
    }

    return ra;
  }
}
