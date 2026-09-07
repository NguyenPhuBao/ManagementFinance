/// `ReminderScheduler` — đặt trước lịch nhắc hoá đơn với hệ điều hành.
///
/// Đây là cách **duy nhất** để thông báo nổ khi app đóng hoàn toàn mà không
/// cần tác vụ nền. Vì thế mọi cách nó hỏng đều hỏng **im lặng**: người dùng
/// không nhận được nhắc, và không có gì trên màn hình nói cho họ biết vì sao.
///
/// Ba điều đáng canh nhất:
///
/// 1. **Luỹ đẳng.** `resync` chạy sau mỗi lần ghi hoá đơn và sau mỗi lần pull —
///    tức là rất nhiều lần. Đặt lại một lịch đã có nghĩa là huỷ rồi đặt lại,
///    và trên iOS mỗi vòng như vậy là một cơ hội để lịch rơi mất.
/// 2. **Trần số lịch.** iOS giữ tối đa 64 lịch chờ và **âm thầm** bỏ phần còn
///    lại — không lỗi, không log. Vượt trần là những hoá đơn xa nhất biến mất
///    mà không ai biết.
/// 3. **Cùng `dedupeKey` với thông báo trong app.** Đó là điểm nối: lịch nổ
///    lúc app đóng, người dùng bấm vào, app mở, vòng quét sinh đúng hàng ấy
///    một lần duy nhất nhờ trùng khoá.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/reminder_scheduler.dart';
import 'package:flowmoney/core/notification/notification_rules.dart';
import 'package:flowmoney/core/notification/os/os_notifier.dart';
import 'package:flowmoney/core/notification/os/os_scheduled_id.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs_store.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';

/// Giả lập kho lịch của hệ điều hành: đặt thì thêm, huỷ thì bớt.
class OsGia implements OsNotifier {
  final Map<int, ({DateTime when, String title, String body, String? payload})>
      lich = {};
  final List<int> daHuy = [];
  int soLanDat = 0;

  @override
  bool get isSupported => true;
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> daCoQuyen() async => true;
  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    soLanDat++;
    lich[id] = (when: when, title: title, body: body, payload: payload);
  }

  // Hai thành viên của cú chạm — bản giả này không dựng kịch bản chạm nào.
  @override
  Stream<String> get payloadDaCham => const Stream<String>.empty();

  @override
  Future<String?> payloadKhoiDong() async => null;

  @override
  Future<Set<int>> pendingIds() async => lich.keys.toSet();

  @override
  Future<void> cancel(int id) async {
    daHuy.add(id);
    lich.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    daHuy.addAll(lich.keys);
    lich.clear();
  }
}

void main() {
  const accountId = 7;
  final now = DateTime(2026, 9, 15, 10);

  late AppDatabase db;
  late OsGia os;
  late InMemoryNotificationPrefsStore prefs;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    os = OsGia();
    prefs = InMemoryNotificationPrefsStore();
  });

  tearDown(() => db.close());

  Bill hoaDon({
    required DateTime denHan,
    String id = 'hd1',
    String ten = 'Tiền điện',
    String? nhacTruoc = '3',
    bool daTra = false,
    bool daXoa = false,
  }) {
    return Bill(
      id: id,
      idaccount: accountId,
      name: ten,
      amount: 300000,
      dueDate: denHan,
      payStatus: daTra ? 'Payed' : 'Pending',
      isPaid: daTra,
      autoPayEnabled: false,
      timeNotification: nhacTruoc,
      isRecurrence: true,
      timeRecurrence: 'Month',
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: daXoa,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 1),
    );
  }

  ReminderScheduler dung(List<Bill> bills) {
    return ReminderScheduler(
      osNotifier: os,
      loadBills: (id, at) async => bills,
      prefsStore: prefs,
      clock: () => now,
    );
  }

  group('đặt lịch', () {
    test('đặt đúng một lịch cho hoá đơn sắp tới hạn', () async {
      final soLich = await dung([hoaDon(denHan: DateTime(2026, 9, 20))])
          .resync(accountId);

      expect(soLich, 1);
      expect(os.lich.length, 1);
    });

    test('lịch nổ vào GIỜ NHẮC của người dùng, không phải nửa đêm', () async {
      await prefs.write(
        accountId,
        const NotificationPrefs(gioNhac: 21, phutNhac: 30),
      );

      await dung([hoaDon(denHan: DateTime(2026, 9, 20))]).resync(accountId);

      // Hạn 20/09, nhắc trước 3 ngày → 17/09 lúc 21:30.
      expect(os.lich.values.single.when, DateTime(2026, 9, 17, 21, 30),
          reason: 'Quên giờ nhắc thì lịch neo vào 00:00 và điện thoại kêu lúc '
              'nửa đêm — bẫy 7.3.');
    });

    test('id và payload dùng ĐÚNG dedupeKey của thông báo trong app', () async {
      await dung([hoaDon(denHan: DateTime(2026, 9, 20))]).resync(accountId);

      final khoa = billDueDedupeKey(
        billId: 'hd1',
        dueDate: DateTime(2026, 9, 20),
        leadDays: 3,
      );

      expect(os.lich.keys.single, osScheduledId(khoa));
      expect(os.lich.values.single.payload, khoa,
          reason: 'Đây là điểm nối: lịch nổ lúc app đóng, người dùng bấm vào, '
              'app mở, vòng quét sinh ĐÚNG hàng ấy nhờ trùng khoá. Khoá lệch '
              'là mỗi sự kiện sinh hai thông báo.');
    });

    test('nội dung lịch nêu tên hoá đơn', () async {
      await dung([hoaDon(denHan: DateTime(2026, 9, 20), ten: 'Tiền nước')])
          .resync(accountId);

      expect(os.lich.values.single.body, contains('Tiền nước'),
          reason: 'Thông báo trên màn hình khoá không nói hoá đơn nào thì '
              'người dùng buộc phải mở app mới biết — mất hết ý nghĩa.');
    });

    test('số ngày nhắc riêng của hoá đơn thắng tuỳ chọn chung', () async {
      await prefs.write(
          accountId, const NotificationPrefs(soNgayNhacHoaDon: 7));

      await dung([hoaDon(denHan: DateTime(2026, 9, 25), nhacTruoc: '1')])
          .resync(accountId);

      expect(os.lich.values.single.when, DateTime(2026, 9, 24, 8, 0));
    });

    test('hoá đơn không tự đặt thì theo tuỳ chọn chung', () async {
      await prefs.write(
          accountId, const NotificationPrefs(soNgayNhacHoaDon: 7));

      await dung([hoaDon(denHan: DateTime(2026, 9, 25), nhacTruoc: null)])
          .resync(accountId);

      expect(os.lich.values.single.when, DateTime(2026, 9, 18, 8, 0));
    });
  });

  group('không đặt lịch cho những thứ này', () {
    test('mốc nhắc đã trôi qua', () async {
      // Hạn 16/09, nhắc trước 3 ngày → mốc 13/09, đã qua so với 15/09.
      final soLich =
          await dung([hoaDon(denHan: DateTime(2026, 9, 16))]).resync(accountId);

      expect(soLich, 0,
          reason: 'Đặt lịch vào quá khứ thì Android bắn NGAY lập tức và iOS '
              'lặng lẽ bỏ qua — hai nền tảng hỏng theo hai kiểu khác nhau, cả '
              'hai đều sai.');
      expect(os.lich, isEmpty);
    });

    test('hoá đơn đã thanh toán', () async {
      final soLich = await dung(
        [hoaDon(denHan: DateTime(2026, 9, 20), daTra: true)],
      ).resync(accountId);
      expect(soLich, 0);
    });

    test('hoá đơn đã xoá mềm', () async {
      final soLich = await dung(
        [hoaDon(denHan: DateTime(2026, 9, 20), daXoa: true)],
      ).resync(accountId);
      expect(soLich, 0,
          reason: 'Nhắc một hoá đơn vừa bị xoá là lỗi người dùng nhìn thấy '
              'ngay và không hiểu vì sao.');
    });

    test('mốc nhắc nằm ngoài cửa sổ 30 ngày', () async {
      final soLich = await dung(
        [hoaDon(denHan: DateTime(2026, 12, 20))],
      ).resync(accountId);
      expect(soLich, 0);
    });

    test('người dùng tắt nhóm hoá đơn', () async {
      await prefs.write(accountId,
          const NotificationPrefs(nhomTat: {NotificationGroup.bill}));

      final soLich =
          await dung([hoaDon(denHan: DateTime(2026, 9, 20))]).resync(accountId);

      expect(soLich, 0);
      expect(os.lich, isEmpty);
    });

    test('người dùng tắt công tắc thông báo hệ điều hành', () async {
      await prefs.write(accountId, const NotificationPrefs(osBat: false));

      final soLich =
          await dung([hoaDon(denHan: DateTime(2026, 9, 20))]).resync(accountId);

      expect(soLich, 0,
          reason: 'Công tắc tổng nói "đừng hiện ra ngoài". Một lịch đặt trước '
              'là thứ chắc chắn hiện ra ngoài.');
    });
  });

  group('luỹ đẳng', () {
    test('chạy lại với dữ liệu không đổi thì không đặt lại lịch nào', () async {
      final s = dung([hoaDon(denHan: DateTime(2026, 9, 20))]);
      await s.resync(accountId);
      final lanDau = os.soLanDat;
      await s.resync(accountId);

      expect(os.soLanDat, lanDau,
          reason: 'resync chạy sau MỖI lần ghi hoá đơn và MỖI lần pull. Đặt '
              'lại lịch đã có nghĩa là huỷ rồi đặt lại, và mỗi vòng như vậy là '
              'một cơ hội để lịch rơi mất.');
      expect(os.daHuy, isEmpty);
      expect(os.lich.length, 1);
    });

    test('hoá đơn được thanh toán thì lịch cũ bị huỷ', () async {
      await dung([hoaDon(denHan: DateTime(2026, 9, 20))]).resync(accountId);
      final idCu = os.lich.keys.single;

      await dung([hoaDon(denHan: DateTime(2026, 9, 20), daTra: true)])
          .resync(accountId);

      expect(os.daHuy, contains(idCu),
          reason: 'Nhắc một hoá đơn đã trả rồi là lỗi khó chịu nhất của loại '
              'tính năng này. Lịch nằm trong AlarmManager, không tự biến mất '
              'khi bản ghi đổi.');
      expect(os.lich, isEmpty);
    });

    test('đổi hạn trả thì huỷ lịch cũ và đặt lịch mới', () async {
      await dung([hoaDon(denHan: DateTime(2026, 9, 20))]).resync(accountId);
      final idCu = os.lich.keys.single;

      await dung([hoaDon(denHan: DateTime(2026, 9, 25))]).resync(accountId);

      expect(os.daHuy, contains(idCu));
      expect(os.lich.length, 1);
      expect(os.lich.keys.single == idCu, isFalse);
    });

    test('tắt công tắc rồi resync thì dọn sạch lịch đã đặt', () async {
      final bills = [hoaDon(denHan: DateTime(2026, 9, 20))];
      await dung(bills).resync(accountId);
      expect(os.lich.length, 1);

      await prefs.write(accountId, const NotificationPrefs(osBat: false));
      await dung(bills).resync(accountId);

      expect(os.lich, isEmpty,
          reason: 'Tắt công tắc mà lịch cũ vẫn nổ là bằng chứng rõ nhất rằng '
              'công tắc không có tác dụng.');
    });
  });

  group('trần số lịch', () {
    test('không bao giờ đặt quá 50 lịch', () async {
      final bills = [
        for (var i = 0; i < 80; i++)
          hoaDon(
            id: 'hd$i',
            // Rải đều trong cửa sổ 30 ngày, nhắc trước 0 ngày cho gọn.
            denHan: DateTime(2026, 9, 16).add(Duration(days: i ~/ 3)),
            nhacTruoc: '0',
          ),
      ];

      final soLich = await dung(bills).resync(accountId);

      expect(soLich, ReminderScheduler.tranSoLich);
      expect(os.lich.length, ReminderScheduler.tranSoLich,
          reason: 'iOS giữ tối đa 64 lịch chờ và ÂM THẦM bỏ phần còn lại. Trần '
              '50 chừa chỗ cho lịch của các tính năng sau.');
    });

    test('khi phải cắt thì giữ những mốc GẦN nhất', () async {
      final bills = [
        for (var i = 0; i < 80; i++)
          hoaDon(
            id: 'hd$i',
            denHan: DateTime(2026, 9, 16).add(Duration(days: i ~/ 3)),
            nhacTruoc: '0',
          ),
      ];

      await dung(bills).resync(accountId);

      int idCua(Bill b) => osScheduledId(billDueDedupeKey(
            billId: b.id,
            dueDate: b.dueDate,
            leadDays: 0,
          ));

      expect(os.lich.keys, contains(idCua(bills.first)),
          reason: 'Hoá đơn gần nhất là cái người dùng cần nhắc trước tiên — nó '
              'phải sống sót qua mọi lần cắt.');
      expect(os.lich.keys, isNot(contains(idCua(bills.last))),
          reason: 'Cắt phải bỏ những hoá đơn XA nhất. Để nền tảng tự chọn hộ '
              'là iOS âm thầm giữ 64 cái tuỳ ý nó.');
    });
  });

  test('không có kho tuỳ chọn thì chạy như mặc định', () async {
    final s = ReminderScheduler(
      osNotifier: os,
      loadBills: (id, at) async => [hoaDon(denHan: DateTime(2026, 9, 20))],
      clock: () => now,
    );

    expect(await s.resync(accountId), 1);
  });

  test('nạp hoá đơn theo ĐÚNG tài khoản được yêu cầu', () async {
    int? idDaNap;
    final s = ReminderScheduler(
      osNotifier: os,
      loadBills: (id, at) async {
        idDaNap = id;
        return const [];
      },
      clock: () => now,
    );

    await s.resync(9);

    expect(idDaNap, 9,
        reason: 'Đặt nhắc hoá đơn của tài khoản khác lên máy này là rò dữ liệu '
            'tài chính ra màn hình khoá.');
  });

  test('dùng được với BillsCompanion thật từ CSDL', () async {
    // Kiểm rằng chữ ký `loadBills` khớp với `billDao.getUpcoming` thật, chứ
    // không chỉ khớp với dữ liệu tự dựng trong test.
    await db.billDao.insert(BillsCompanion.insert(
      id: 'hd-that',
      idaccount: accountId,
      name: 'Tiền mạng',
      amount: 200000,
      dueDate: DateTime(2026, 9, 20),
      walletId: const Value('vi1'),
      categoryId: const Value('cat1'),
      timeNotification: const Value('3'),
      updatedAt: DateTime(2026, 9, 1),
    ));

    final s = ReminderScheduler(
      osNotifier: os,
      loadBills: (id, at) => db.billDao.getUpcoming(id, days: 30, now: at),
      clock: () => now,
    );

    expect(await s.resync(accountId), 1);
    expect(os.lich.values.single.body, contains('Tiền mạng'));
  });

  group('lịch nhắc kỳ trích tự động', () {
    GoalEntity mucTieu({
      String id = 'mt1',
      String ten = 'MuaXe',
      double target = 2000000,
      double current = 500000,
      String? chuKy = 'Month',
      double? soTien = 100000,
      String? viNguon = 'vi_nguon',
      DateTime? mocNeo,
      DateTime? sanChay,
      bool xong = false,
      bool daXoa = false,
    }) =>
        GoalEntity(
          id: id,
          idaccount: accountId,
          name: ten,
          targetAmount: target,
          currentAmount: current,
          startDate: DateTime(2026, 1, 1),
          targetDate: DateTime(2027, 12, 31),
          cycleTakeMoney: chuKy,
          timeCycleTakeMoney: mocNeo ?? DateTime(2026, 9, 20, 8),
          autoDepositAmount: soTien,
          autoDepositWalletId: viNguon,
          autoDepositLastRun: sanChay ?? DateTime(2026, 9, 1),
          isCompleted: xong,
          isDeleted: daXoa,
          updatedAt: DateTime(2026, 9, 1),
        );

    ReminderScheduler dungGoal(List<GoalEntity> goals,
            {List<Bill> bills = const []}) =>
        ReminderScheduler(
          osNotifier: os,
          loadBills: (id, at) async => bills,
          loadGoals: (id, at) async => goals,
          prefsStore: prefs,
          clock: () => now,
        );

    test('đặt lịch đúng vào MỐC KỲ, không phải giờ nhắc chung', () async {
      await dungGoal([mucTieu()]).resync(accountId);

      final l = os.lich.values.single;
      expect(l.when, DateTime(2026, 9, 20, 8),
          reason: 'Giờ nhắc chung (`prefs.gioNhac`) là của hoá đơn. Kỳ trích có '
              'giờ riêng do người dùng chọn — dùng giờ chung ở đây là nhắc '
              'lệch so với đúng cái mốc mà màn hình đang hiện.');
      expect(l.body, contains('MuaXe'));
      expect(l.body, contains('100'));
    });

    test('payload trùng khoá thông báo "đã trích" của chính kỳ đó', () async {
      await dungGoal([mucTieu()]).resync(accountId);

      final l = os.lich.values.single;
      expect(l.payload, 'goalAuto:mt1:2026-09-20T08:00',
          reason: 'Cùng khoá nghĩa là cùng `osScheduledId`, nên khi khoản trích '
              'chạy xong, thông báo "đã trích" THAY CHỖ lời nhắc thay vì nằm '
              'cạnh nó. Hai thông báo cho một sự việc là thứ người dùng đọc '
              'thành "app trích hai lần".');
    });

    test('mục tiêu chưa bật trích tự động thì không đặt lịch', () async {
      final s = dungGoal([mucTieu(soTien: null, viNguon: null, sanChay: null)]);
      expect(await s.resync(accountId), 0);
      expect(os.lich, isEmpty);
    });

    test('mục tiêu đã hoàn thành hoặc đã xoá thì không đặt lịch', () async {
      expect(await dungGoal([mucTieu(xong: true)]).resync(accountId), 0);
      expect(await dungGoal([mucTieu(daXoa: true)]).resync(accountId), 0);
      expect(
          await dungGoal([mucTieu(target: 500000, current: 500000)])
              .resync(accountId),
          0,
          reason: 'Đủ tiền rồi thì không còn kỳ nào để nhắc.');
    });

    test('tắt nhóm mục tiêu thì gỡ lịch, KHÔNG đụng lịch hoá đơn', () async {
      await prefs.write(
        accountId,
        const NotificationPrefs(nhomTat: {NotificationGroup.goal}),
      );

      final s = dungGoal(
        [mucTieu()],
        bills: [hoaDon(denHan: DateTime(2026, 9, 20))],
      );

      expect(await s.resync(accountId), 1,
          reason: 'Chỉ còn lịch hoá đơn. Hai nhóm phải tắt bật độc lập — dùng '
              'chung một bộ đặt lịch không được biến chúng thành một công tắc.');
      expect(os.lich.values.single.body, contains('Tiền điện'));
    });

    test('hoá đơn và mục tiêu CÙNG TỒN TẠI, không bên nào huỷ bên kia',
        () async {
      final s = dungGoal(
        [mucTieu()],
        bills: [hoaDon(denHan: DateTime(2026, 9, 20))],
      );

      expect(await s.resync(accountId), 2,
          reason: '`resync` huỷ MỌI lịch chờ không nằm trong tập nó muốn. Tách '
              'thành hai bộ đặt lịch riêng là mỗi bên xoá sạch lịch của bên '
              'kia ở mỗi lượt chạy — im lặng, và chỉ lộ ra khi người dùng phàn '
              'nàn rằng nhắc hoá đơn đã ngừng hoạt động.');
    });

    test('luỹ đẳng: chạy lại không đặt lại lịch đã có', () async {
      final s = dungGoal([mucTieu()]);
      await s.resync(accountId);
      final lanDau = os.soLanDat;

      await s.resync(accountId);
      expect(os.soLanDat, lanDau,
          reason: 'Huỷ rồi đặt lại ở mỗi lượt là mỗi lượt thêm một cơ hội để '
              'lịch rơi mất.');
    });

    test('trần số lịch tính CHUNG cho cả hoá đơn lẫn mục tiêu', () async {
      final nhieuMucTieu = [
        for (var i = 0; i < 60; i++)
          mucTieu(id: 'mt$i', ten: 'Mục tiêu $i'),
      ];

      final soLich = await dungGoal(nhieuMucTieu).resync(accountId);
      expect(soLich, ReminderScheduler.tranSoLich,
          reason: 'iOS giữ tối đa 64 lịch chờ rồi ÂM THẦM bỏ phần còn lại. '
              'Trần phải tính trên tổng hai loại, nếu không hai bên cộng lại '
              'vượt 64 mà mỗi bên đều tưởng mình còn dư chỗ.');
    });
  });

  group('nhắc ghi chép hằng ngày', () {
    /// Dựng một bộ đặt lịch **không có hoá đơn nào**, để mọi lịch đếm được đều
    /// là lịch nhắc ghi chép.
    ReminderScheduler dungGhiChep({
      DateTime? mocGiaoDichCuoi,
      DateTime? luc,
    }) {
      return ReminderScheduler(
        osNotifier: os,
        loadBills: (id, at) async => const [],
        loadLastTransactionAt: (id) async => mocGiaoDichCuoi,
        prefsStore: prefs,
        clock: () => luc ?? now,
      );
    }

    Future<void> bat({int gio = 20, int phut = 0}) => prefs.write(
          accountId,
          NotificationPrefs(
            nhacGhiChepBat: true,
            gioNhacGhiChep: gio,
            phutNhacGhiChep: phut,
          ),
        );

    test('tắt sẵn — không đặt lịch nhắc ghi chép nào', () async {
      final soLich = await dungGhiChep().resync(accountId);

      expect(soLich, 0,
          reason: 'nhacGhiChepBat mặc định false. Bật sẵn là mọi bản đã cài '
              'bỗng nhiên nhận một thông báo mỗi ngày mà không ai báo trước.');
      expect(os.lich, isEmpty);
    });

    test('bật thì đặt BA lịch: hôm nay và hai ngày kế', () async {
      await bat();

      final soLich = await dungGhiChep().resync(accountId);

      expect(soLich, 3,
          reason: 'Ba chứ không phải một: đặt một lịch rồi chờ lượt resync sau '
              'gia hạn là người dùng không mở app sẽ chỉ được nhắc ĐÚNG MỘT '
              'lần rồi im — mà đó chính là người cần nhắc nhất.');
      expect(
        os.lich.values.map((l) => l.when).toList()..sort(),
        [
          DateTime(2026, 9, 15, 20),
          DateTime(2026, 9, 16, 20),
          DateTime(2026, 9, 17, 20),
        ],
      );
    });

    test('giờ nhắc lấy từ tuỳ chọn RIÊNG, không phải gioNhac', () async {
      await bat(gio: 21, phut: 30);

      await dungGhiChep().resync(accountId);

      expect(os.lich.values.first.when, DateTime(2026, 9, 15, 21, 30),
          reason: 'gioNhac (mặc định 08:00) là của hoá đơn. Dùng chung là hỏi '
              '"hôm nay ghi chép chưa" trước khi có gì để ghi.');
    });

    test('hôm nay ĐÃ có giao dịch thì bỏ qua lịch hôm nay', () async {
      await bat();

      // Cùng ngày với `now`, sớm hơn giờ nhắc.
      final soLich = await dungGhiChep(
        mocGiaoDichCuoi: DateTime(2026, 9, 15, 9),
      ).resync(accountId);

      expect(soLich, 2);
      expect(
        os.lich.values.map((l) => l.when).toList()..sort(),
        [DateTime(2026, 9, 16, 20), DateTime(2026, 9, 17, 20)],
        reason: 'Nhắc người vừa ghi xong là đúng kiểu làm phiền khiến người '
            'dùng tắt hẳn thông báo. Chỉ HÔM NAY biết được, hai ngày sau thì '
            'không — nên chúng vẫn được đặt.',
      );
    });

    test('giao dịch của HÔM QUA không cứu được hôm nay', () async {
      await bat();

      final soLich = await dungGhiChep(
        mocGiaoDichCuoi: DateTime(2026, 9, 14, 23, 59),
      ).resync(accountId);

      expect(soLich, 3,
          reason: 'So theo NGÀY, không theo khoảng 24 giờ. 23:59 hôm qua cách '
              '`now` chưa tới 11 tiếng nhưng vẫn là một ngày khác.');
    });

    test('chưa từng ghi giao dịch nào thì vẫn được nhắc', () async {
      await bat();

      final soLich =
          await dungGhiChep(mocGiaoDichCuoi: null).resync(accountId);

      expect(soLich, 3,
          reason: 'null nghĩa là "chưa từng ghi gì" và phải đọc thành CẦN '
              'nhắc. Đọc thành "vừa ghi xong" là người mới cài app — đúng '
              'người cần nhắc nhất — không bao giờ được nhắc.');
    });

    test('giờ nhắc đã trôi qua thì bỏ qua hôm nay', () async {
      await bat();

      final soLich = await dungGhiChep(
        luc: DateTime(2026, 9, 15, 21),
      ).resync(accountId);

      expect(soLich, 2,
          reason: 'Mốc quá khứ thì Android bắn NGAY còn iOS lặng lẽ bỏ — hai '
              'nền tảng hỏng theo hai kiểu, cả hai đều sai. Cùng lý lẽ với '
              'nhánh hoá đơn.');
      expect(os.lich.values.map((l) => l.when).toList()..sort(),
          [DateTime(2026, 9, 16, 20), DateTime(2026, 9, 17, 20)]);
    });

    test('tắt công tắc tổng thì không đặt lịch nào', () async {
      await prefs.write(
        accountId,
        const NotificationPrefs(osBat: false, nhacGhiChepBat: true),
      );

      expect(await dungGhiChep().resync(accountId), 0);
    });

    test('luỹ đẳng — chạy lần hai không đặt lại lịch nào', () async {
      await bat();
      final bo = dungGhiChep();

      await bo.resync(accountId);
      final sauLan1 = os.soLanDat;
      await bo.resync(accountId);

      expect(os.soLanDat, sauLan1,
          reason: 'resync chạy sau mỗi lần ghi và mỗi lần pull. Huỷ-rồi-đặt-'
              'lại ở mỗi lượt là mỗi lượt thêm một cơ hội để lịch rơi mất.');
    });

    test('ghi giao dịch xong thì lượt sau HUỶ lịch hôm nay', () async {
      await bat();
      await dungGhiChep().resync(accountId);
      final idHomNay = osScheduledId('ghiChep:2026-09-15');
      expect(os.lich.containsKey(idHomNay), true);

      // Người dùng ghi một giao dịch lúc 15h — lượt quét kế tiếp chạy resync.
      await dungGhiChep(mocGiaoDichCuoi: DateTime(2026, 9, 15, 15))
          .resync(accountId);

      expect(os.daHuy, contains(idHomNay),
          reason: 'Đây là cả lý do chọn ba lịch RỜI thay vì một lịch lặp '
              '`DateTimeComponents.time`: lịch lặp chỉ tốn một suất nhưng '
              'không bỏ qua được ngày nào, nên nó nhắc cả những hôm người dùng '
              'đã ghi rồi.');
      expect(os.lich.containsKey(idHomNay), false);
    });

    test('tắt công tắc thì dọn sạch lịch đã đặt trước đó', () async {
      await bat();
      await dungGhiChep().resync(accountId);
      expect(os.lich, hasLength(3));

      await prefs.write(accountId, const NotificationPrefs());
      await dungGhiChep().resync(accountId);

      expect(os.lich, isEmpty,
          reason: 'Lịch đã đặt nằm trong AlarmManager và không tự biến mất khi '
              'người dùng gạt công tắc.');
    });
  });
}
