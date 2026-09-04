/// `BillReminderScheduler` — đặt trước lịch nhắc hoá đơn với hệ điều hành.
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
import 'package:flowmoney/core/notification/bill_reminder_scheduler.dart';
import 'package:flowmoney/core/notification/notification_rules.dart';
import 'package:flowmoney/core/notification/os/os_notifier.dart';
import 'package:flowmoney/core/notification/os/os_scheduled_id.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs_store.dart';

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

  BillReminderScheduler dung(List<Bill> bills) {
    return BillReminderScheduler(
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

      expect(soLich, BillReminderScheduler.tranSoLich);
      expect(os.lich.length, BillReminderScheduler.tranSoLich,
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
    final s = BillReminderScheduler(
      osNotifier: os,
      loadBills: (id, at) async => [hoaDon(denHan: DateTime(2026, 9, 20))],
      clock: () => now,
    );

    expect(await s.resync(accountId), 1);
  });

  test('nạp hoá đơn theo ĐÚNG tài khoản được yêu cầu', () async {
    int? idDaNap;
    final s = BillReminderScheduler(
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

    final s = BillReminderScheduler(
      osNotifier: os,
      loadBills: (id, at) => db.billDao.getUpcoming(id, days: 30, now: at),
      clock: () => now,
    );

    expect(await s.resync(accountId), 1);
    expect(os.lich.values.single.body, contains('Tiền mạng'));
  });
}
