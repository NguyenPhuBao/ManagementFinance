import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../data/models/goal_entity.dart';
import '../data/repositories/goal_repository.dart';
import 'goal_auto_deposit.dart';

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
/// ## Vì sao không có bộ lập lịch chạy nền
///
/// Nơi gọi là `NotificationScanner.scan()`, tức mỗi khi một chu kỳ đồng bộ kết
/// thúc. Các kỳ bỏ lỡ được **trích bù** theo đúng thứ tự khi app mở lại, nên
/// không kỳ nào mất; chỉ là chúng xảy ra muộn hơn mốc lý thuyết. Đổi lại, việc
/// chuyển tiền luôn nằm trong tiến trình chính, dùng chung một kết nối CSDL —
/// một isolate nền mở kết nối thứ hai vào cùng tệp SQLite để chuyển tiền là
/// loại rủi ro không đáng đánh đổi lấy vài giờ sớm hơn.
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
    final viNguon = await db.walletDao.getById(viNguonId);
    if (viNguon == null || viNguonId == goal.walletId) {
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
    DateTime? kyCuoiThanhCong;

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
        );
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
      kyCuoiThanhCong = ky;

      ra.add(GoalAutoDepositEvent(
        goalId: goal.id,
        goalName: goal.name,
        ky: ky,
        loai: quyetDinh.loai,
        soTien: quyetDinh.soTien,
        tenViNguon: viNguon.name,
      ));
    }

    if (kyCuoiThanhCong != null) {
      // KHÔNG đặt `syncStatus` ở đây: `autoDepositLastRun` là cột cục bộ, đánh
      // dấu cần đẩy cho một thay đổi không có mặt trong payload là đẩy rỗng.
      // `depositToGoal` đã tự đánh dấu vì nó đổi `currentAmount`.
      await (db.update(db.goals)..where((t) => t.id.equals(goal.id)))
          .write(GoalsCompanion(autoDepositLastRun: Value(kyCuoiThanhCong)));
    }

    return ra;
  }
}
