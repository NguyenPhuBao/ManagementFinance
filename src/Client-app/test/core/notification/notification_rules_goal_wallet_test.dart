/// Bốn luật của lát 6: mục tiêu hoàn thành, mục tiêu trễ tiến độ, đồng bộ
/// hỏng, ví âm.
///
/// Điểm chung khiến chúng khó hơn hai nhóm trước: **không có "kỳ" tự nhiên**.
/// Ngân sách có chu kỳ, hoá đơn có hạn trả — cả hai cho sẵn một mốc để đưa vào
/// `dedupeKey`. Mục tiêu trễ tiến độ thì trễ liên tục hàng tháng trời, ví âm
/// thì âm cho tới khi người dùng nạp tiền, và đồng bộ hỏng thì hỏng lại ở mọi
/// chu kỳ. Không tự đặt một đơn vị lặp lại vào khoá là mỗi lượt quét đẻ một
/// thông báo mới — và quét chạy sau **mọi** lần đồng bộ.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/notification_rules.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/domain/goal_auto_deposit.dart';
import 'package:flowmoney/features/goal/domain/goal_auto_deposit_runner.dart';

void main() {
  final now = DateTime(2026, 9, 15, 10);

  GoalEntity mucTieu({
    String id = 'mt1',
    String ten = 'MacBook',
    double target = 10000000,
    double current = 2000000,
    DateTime? batDau,
    DateTime? ketThuc,
    bool xong = false,
    bool daXoa = false,
  }) {
    return GoalEntity(
      id: id,
      idaccount: 7,
      name: ten,
      targetAmount: target,
      currentAmount: current,
      startDate: batDau ?? DateTime(2026, 1, 1),
      targetDate: ketThuc ?? DateTime(2026, 12, 31),
      isCompleted: xong,
      isDeleted: daXoa,
      updatedAt: DateTime(2026, 9, 1),
    );
  }

  Wallet vi({
    String id = 'vi1',
    String ten = 'Tiền mặt',
    double soDu = 100000,
    bool daXoa = false,
  }) {
    return Wallet(
      id: id,
      idaccount: 7,
      name: ten,
      type: 'cash',
      balance: soDu,
      currency: 'VND',
      icon: 'wallet',
      colour: '#4CAF50',
      isDefault: false,
      status: 'active',
      isDeleted: daXoa,
      syncRetryCount: 0,
      includeInTotal: true,
      syncStatus: 'synced',
      updatedAt: DateTime(2026, 9, 1),
    );
  }

  List<NotificationCandidate> chay({
    List<GoalEntity> goals = const [],
    List<Wallet> wallets = const [],
    List<GoalAutoDepositEvent> autoDeposits = const [],
    bool dongBoHong = false,
    DateTime? at,
    DateTime? silenceBefore,
  }) {
    return buildNotificationCandidates(NotificationRuleInput(
      now: at ?? now,
      goals: goals,
      wallets: wallets,
      autoDeposits: autoDeposits,
      syncFailed: dongBoHong,
      silenceBefore: silenceBefore,
    ));
  }

  group('mục tiêu hoàn thành', () {
    test('đủ tiền thì chúc mừng', () {
      final ra = chay(goals: [mucTieu(target: 1000, current: 1000)]).single;

      expect(ra.kind, NotificationKind.goalCompleted);
      expect(ra.severity, NotificationSeverity.info,
          reason: 'Tin vui không được dùng màu cảnh báo.');
      expect(ra.body, contains('MacBook'));
      expect(ra.deeplink, '/goals/mt1',
          reason: 'Dẫn thẳng tới mục tiêu, không phải về danh sách. Thông báo '
              'đã biết chính xác mục tiêu nào — bắt người dùng tự dò lại trong '
              'danh sách là vứt đi thông tin mình đang cầm.');
    });

    test('cờ isCompleted cũng tính là hoàn thành', () {
      final ra = chay(goals: [mucTieu(current: 0, xong: true)]);
      expect(ra.single.kind, NotificationKind.goalCompleted,
          reason: 'Mục tiêu đóng tay từ trang mục tiêu không nhất thiết đủ '
              'tiền. Bỏ qua cờ này là người dùng không bao giờ được chúc mừng.');
    });

    test('hoàn thành thì KHÔNG đồng thời báo trễ tiến độ', () {
      final ra = chay(goals: [mucTieu(target: 1000, current: 1000)]);
      expect(ra.length, 1);
    });

    test('mỗi mục tiêu chỉ chúc mừng một lần, không theo kỳ', () {
      final mt = mucTieu(target: 1000, current: 1000);
      final thangNay = chay(goals: [mt]).single.dedupeKey;
      final thangSau =
          chay(goals: [mt], at: DateTime(2026, 10, 20)).single.dedupeKey;

      expect(thangNay, thangSau,
          reason: 'Một mục tiêu chỉ hoàn thành một lần trong đời. Đưa tháng '
              'vào khoá là mỗi tháng lại chúc mừng lại cùng một việc.');
    });

    test('mục tiêu đã xoá thì im lặng', () {
      expect(chay(goals: [mucTieu(target: 1000, current: 1000, daXoa: true)]),
          isEmpty);
    });
  });

  group('mục tiêu trễ tiến độ', () {
    GoalEntity treTienDo() => mucTieu(
          target: 1000,
          current: 100,
          batDau: DateTime(2026, 1, 1),
          ketThuc: DateTime(2026, 12, 31),
        );

    test('tụt sau nhịp thì nhắc, kèm số tiền còn thiếu', () {
      final ra = chay(goals: [treTienDo()]).single;

      expect(ra.kind, NotificationKind.goalBehind);
      expect(ra.severity, NotificationSeverity.warning);
      expect(ra.body, contains('MacBook'));
      expect(ra.body, contains('900'),
          reason: 'Câu nhắc phải nói số tiền cụ thể, đúng như mục thứ ba trong '
              'thiết kế Stitch. "Bạn đang trễ tiến độ" không giúp người dùng '
              'quyết định làm gì tiếp.');
      expect(ra.deeplink, '/goals/mt1',
          reason: 'Cùng lý do với thông báo hoàn thành: nhắc "tiết kiệm thêm '
              '900 nghìn" mà đổ người dùng xuống danh sách thì việc cần làm '
              'vẫn còn cách vài cú chạm.');
    });

    test('hai mục tiêu khác nhau dẫn tới hai đường khác nhau', () {
      final ra = chay(goals: [
        mucTieu(id: 'mt1', ten: 'MacBook', target: 1000, current: 1000),
        mucTieu(id: 'mt2', ten: 'Xe máy', target: 2000, current: 2000),
      ]);

      expect(
        ra.map((c) => c.deeplink).toSet(),
        {'/goals/mt1', '/goals/mt2'},
        reason: 'Đường dẫn phải mang id của CHÍNH mục tiêu sinh ra nó. Dựng '
            'chuỗi từ một biến sai chỗ trong vòng lặp là mọi thông báo cùng '
            'trỏ về một mục tiêu — và không có gì báo lỗi.',
      );
    });

    test('nhắc tối đa MỘT lần mỗi tháng', () {
      final mt = treTienDo();
      final ngay15 = chay(goals: [mt]).single.dedupeKey;
      final ngay28 =
          chay(goals: [mt], at: DateTime(2026, 9, 28)).single.dedupeKey;

      expect(ngay15, ngay28,
          reason: 'Trễ tiến độ kéo dài hàng tháng, và quét chạy sau MỌI lần '
              'đồng bộ. Không có đơn vị lặp lại trong khoá là mỗi lượt quét đẻ '
              'một thông báo mới.');
    });

    test('sang tháng mới thì nhắc lại được', () {
      final mt = treTienDo();
      final thang9 = chay(goals: [mt]).single.dedupeKey;
      final thang10 =
          chay(goals: [mt], at: DateTime(2026, 10, 5)).single.dedupeKey;

      expect(thang9 == thang10, isFalse,
          reason: 'Vẫn trễ sau một tháng là tin đáng nhắc lại.');
    });

    test('đi đúng nhịp thì im lặng', () {
      final ra = chay(goals: [
        mucTieu(
          target: 1000,
          current: 700,
          batDau: DateTime(2026, 1, 1),
          ketThuc: DateTime(2026, 12, 31),
        )
      ]);
      expect(ra, isEmpty);
    });

    test('mục tiêu đã xoá thì im lặng', () {
      final mt = mucTieu(
        target: 1000,
        current: 100,
        batDau: DateTime(2026, 1, 1),
        ketThuc: DateTime(2026, 12, 31),
        daXoa: true,
      );
      expect(chay(goals: [mt]), isEmpty);
    });
  });

  group('trích tiền tự động', () {
    GoalAutoDepositEvent sk({
      String goalId = 'mt1',
      String ten = 'MacBook',
      LoaiTrich loai = LoaiTrich.trichDu,
      double soTien = 500000,
      String? viNguon = 'Tiền mặt',
      DateTime? ky,
    }) =>
        GoalAutoDepositEvent(
          goalId: goalId,
          goalName: ten,
          ky: ky ?? DateTime(2026, 9, 15),
          loai: loai,
          soTien: soTien,
          tenViNguon: viNguon,
        );

    test('trích xong thì báo, kèm số tiền và ví nguồn', () {
      final ra = chay(autoDeposits: [sk()]).single;

      expect(ra.kind, NotificationKind.goalAutoDeposited);
      expect(ra.severity, NotificationSeverity.info);
      expect(ra.body, contains('MacBook'));
      expect(ra.body, contains('500'));
      expect(ra.body, contains('Tiền mặt'),
          reason: 'App vừa tự chuyển tiền của người dùng khi họ không có mặt. '
              'Câu báo tối thiểu phải nói RÕ bao nhiêu và từ ví nào, nếu không '
              'họ chỉ thấy số dư hụt đi mà không biết vì sao.');
      expect(ra.deeplink, '/goals/mt1');
    });

    test('trích phần còn lại cũng báo như trích đủ', () {
      final ra =
          chay(autoDeposits: [sk(loai: LoaiTrich.trichPhanConLai, soTien: 120000)])
              .single;
      expect(ra.kind, NotificationKind.goalAutoDeposited);
      expect(ra.body, contains('120'));
    });

    test('ví không đủ thì báo CẢNH BÁO, không phải tin vui', () {
      final ra =
          chay(autoDeposits: [sk(loai: LoaiTrich.viKhongDu, soTien: 0)]).single;

      expect(ra.kind, NotificationKind.goalAutoDepositFailed);
      expect(ra.severity, NotificationSeverity.warning,
          reason: 'Im lặng ở đây là tệ nhất: người dùng tin rằng tháng này đã '
              'tích được, trong khi không có đồng nào rời ví.');
      expect(ra.body, contains('MacBook'));
    });

    test('cấu hình hỏng cũng báo cảnh báo', () {
      final ra = chay(autoDeposits: [sk(loai: LoaiTrich.khongChayDuoc)]).single;
      expect(ra.kind, NotificationKind.goalAutoDepositFailed);
    });

    test('mỗi mục tiêu mỗi kỳ chỉ báo MỘT lần', () {
      final e = sk();
      final lan1 = chay(autoDeposits: [e]).single.dedupeKey;
      final lan2 = chay(autoDeposits: [e], at: DateTime(2026, 9, 28))
          .single
          .dedupeKey;

      expect(lan1, lan2,
          reason: 'Vòng quét chạy sau MỌI lần đồng bộ. Không gộp theo kỳ thì '
              'mỗi lần mở app lại thêm một "Đã trích 500 nghìn" cho việc chỉ '
              'xảy ra một lần.');
    });

    test('hai kỳ khác nhau thì báo riêng', () {
      final ra = chay(autoDeposits: [
        sk(ky: DateTime(2026, 8, 15)),
        sk(ky: DateTime(2026, 9, 15)),
      ]);
      expect(ra.map((c) => c.dedupeKey).toSet().length, 2,
          reason: 'Trích bù hai tháng là hai lần tiền rời ví. Gộp thành một '
              'thông báo giấu mất một khoản.');
    });

    test('mốc sự kiện là KỲ TRÍCH, không phải lúc quét', () {
      final ra = chay(
        autoDeposits: [sk(ky: DateTime(2026, 3, 15))],
        at: DateTime(2026, 9, 15),
        silenceBefore: DateTime(2026, 8, 16),
      );

      expect(ra, isEmpty,
          reason: 'Cửa sổ 30 ngày phải loại được kỳ trích bù từ nửa năm trước. '
              'Lấy lúc quét làm mốc thì mọi kỳ cũ đều lọt qua bộ lọc và người '
              'dùng nhận cả chục thông báo cùng lúc ở lần mở app đầu tiên.');
    });
  });

  group('ví âm', () {
    test('số dư âm là cảnh báo nghiêm trọng', () {
      final ra = chay(wallets: [vi(soDu: -50000, ten: 'Ví tiêu vặt')]).single;

      expect(ra.kind, NotificationKind.walletNegative);
      expect(ra.severity, NotificationSeverity.critical);
      expect(ra.body, contains('Ví tiêu vặt'));
      expect(ra.deeplink, '/wallets');
    });

    test('số dư 0 KHÔNG phải ví âm', () {
      expect(chay(wallets: [vi(soDu: 0)]), isEmpty,
          reason: 'Ví hết tiền là chuyện bình thường; ví âm mới là dấu hiệu ghi '
              'nhầm giao dịch.');
    });

    test('nhắc tối đa một lần mỗi ngày', () {
      final v = vi(soDu: -50000);
      final sang = chay(wallets: [v], at: DateTime(2026, 9, 15, 8)).single;
      final toi = chay(wallets: [v], at: DateTime(2026, 9, 15, 22)).single;

      expect(sang.dedupeKey, toi.dedupeKey,
          reason: 'Ví ở trạng thái âm cho tới khi người dùng nạp tiền. Mỗi lượt '
              'quét một thông báo là hàng chục thông báo trong một ngày.');
    });

    test('sang ngày mới thì nhắc lại được', () {
      final v = vi(soDu: -50000);
      final homNay = chay(wallets: [v]).single.dedupeKey;
      final homSau =
          chay(wallets: [v], at: DateTime(2026, 9, 16)).single.dedupeKey;

      expect(homNay == homSau, isFalse);
    });

    test('ví đã xoá thì im lặng', () {
      expect(chay(wallets: [vi(soDu: -50000, daXoa: true)]), isEmpty);
    });
  });

  group('đồng bộ hỏng', () {
    test('báo khi đồng bộ kết thúc ở trạng thái lỗi', () {
      final ra = chay(dongBoHong: true).single;

      expect(ra.kind, NotificationKind.syncFailed);
      expect(ra.severity, NotificationSeverity.warning,
          reason: 'Dữ liệu vẫn an toàn trong máy — đây là cảnh báo, không phải '
              'thảm hoạ.');
    });

    test('đồng bộ bình thường thì không báo gì', () {
      expect(chay(dongBoHong: false), isEmpty);
    });

    test('nhắc tối đa một lần mỗi ngày', () {
      final sang = chay(dongBoHong: true, at: DateTime(2026, 9, 15, 8)).single;
      final toi = chay(dongBoHong: true, at: DateTime(2026, 9, 15, 22)).single;

      expect(sang.dedupeKey, toi.dedupeKey,
          reason: 'Mất mạng là hỏng ở MỌI chu kỳ đồng bộ. Không gộp theo ngày '
              'là người dùng nhận hàng chục thông báo giống hệt nhau.');
    });
  });

  test('bốn nhóm chạy được cùng lúc mà không giẫm lên nhau', () {
    final ra = chay(
      goals: [
        mucTieu(id: 'xong', target: 1000, current: 1000),
        mucTieu(
          id: 'tre',
          ten: 'Xe máy',
          target: 1000,
          current: 100,
          batDau: DateTime(2026, 1, 1),
          ketThuc: DateTime(2026, 12, 31),
        ),
      ],
      wallets: [vi(soDu: -1000)],
      dongBoHong: true,
    );

    expect(
      ra.map((c) => c.kind).toSet(),
      {
        NotificationKind.goalCompleted,
        NotificationKind.goalBehind,
        NotificationKind.walletNegative,
        NotificationKind.syncFailed,
      },
    );
    expect(ra.map((c) => c.dedupeKey).toSet().length, ra.length,
        reason: 'Khoá trùng giữa hai loại khác nhau là loại thứ hai bị SQLite '
            'nuốt mất, im lặng.');
  });
}
