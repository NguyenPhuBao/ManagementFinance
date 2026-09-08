/// `BadgeUpdater` — giữ badge trên icon app khớp với số chưa đọc trong app.
///
/// Bốn điều đáng canh. Cả bốn đều hỏng **âm thầm**: badge sai không ném lỗi,
/// không ghi log, và trên máy ảo thì launcher mặc định còn chẳng vẽ số ra để
/// nhìn thấy.
///
/// 1. **Badge phải mang đúng số chưa đọc** — nếu không thì cả tính năng vô
///    nghĩa.
/// 2. **Đọc rồi thì thông báo phải rời khay.** Trên Android chấm trên icon suy
///    từ thông báo đang hiện chứ không từ bảng, nên bỏ bước này là chấm sáng
///    vĩnh viễn dù đã đọc hết.
/// 3. **Thông báo mà bảng không biết thì TUYỆT ĐỐI không được đụng vào.** Đây
///    là ca nguy hiểm nhất: lịch nhắc hoá đơn nổ lúc app đóng chưa kịp có hàng
///    trong bảng, và nhắc ghi chép hằng ngày thì không bao giờ có hàng. Dọn
///    sạch khay sẽ xoá mất chúng trước khi người dùng kịp nhìn.
/// 4. **Không bao giờ được gọi `cancelAll()`.** Nó cuốn theo cả lịch đang chờ
///    trong AlarmManager — đúng lỗi đã làm mất lịch vừa hoãn ở phiên trước.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/database/daos/notification_dao.dart';
import 'package:flowmoney/core/notification/badge_updater.dart';
import 'package:flowmoney/core/notification/os/os_notifier.dart';
import 'package:flowmoney/core/notification/os/os_scheduled_id.dart';

/// Ghi lại mọi lời gọi xuống hệ điều hành, và cho test dựng sẵn trạng thái
/// khay. Không dùng thư viện mock: cái cần canh là **hành vi của updater**, và
/// một lớp tay viết thì đọc test là thấy ngay nó phải làm gì.
class OsNotifierGia implements OsNotifier {
  /// Khay đang hiện những id nào. Test dựng trực tiếp.
  Set<int> khayDangHien = {};

  final List<int> daHuy = [];
  final List<int> badgeDaDat = [];

  /// Canh bẫy: `cancelAll()` cuốn theo cả lịch chưa nổ, nên updater tuyệt đối
  /// không được chạm vào nó.
  int soLanHuyHet = 0;

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
  }) async {}

  @override
  Stream<String> get payloadDaCham => const Stream<String>.empty();

  @override
  Future<String?> payloadKhoiDong() async => null;

  @override
  Future<Set<int>> pendingIds() async => const {};

  /// Trả **bản sao**, đúng như bản thật: nó dựng một tập mới từ kết quả
  /// platform channel. Trả thẳng tập gốc thì `cancel()` sửa đúng cái đang được
  /// duyệt, `ConcurrentModificationError` bị `dongBo` nuốt mất, và test xanh
  /// oan — đã vấp đúng một lần ở đây.
  @override
  Future<Set<int>> activeIds() async => {...khayDangHien};

  @override
  Future<void> datBadge(int soLuong) async => badgeDaDat.add(soLuong);

  @override
  Future<void> cancel(int id) async {
    daHuy.add(id);
    khayDangHien.remove(id);
  }

  @override
  Future<void> cancelAll() async => soLanHuyHet++;
}

void main() {
  const accountId = 7;

  late AppDatabase db;
  late NotificationDao dao;
  late OsNotifierGia os;
  late BadgeUpdater updater;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = NotificationDao(db);
    os = OsNotifierGia();
    updater = BadgeUpdater(dao: dao, osNotifier: os);
  });

  tearDown(() async {
    await updater.stop();
    await db.close();
  });

  /// Chèn một thông báo và trả về id hệ điều hành tương ứng với nó.
  Future<({String id, int osId})> themThongBao(
    String dedupeKey, {
    int idaccount = accountId,
  }) async {
    final id = 'n-$dedupeKey';
    await dao.insertIfAbsent(
      AppNotificationsCompanion.insert(
        id: id,
        idaccount: idaccount,
        kind: 'billDueSoon',
        dedupeKey: dedupeKey,
        title: 'Hoá đơn sắp đến hạn',
        body: 'Tiền điện đến hạn ngày mai.',
        severity: 'warning',
        createdAt: DateTime(2026, 9, 8, 10),
      ),
    );
    return (id: id, osId: osScheduledId(dedupeKey));
  }

  group('badge mang đúng số chưa đọc', () {
    test('hai hàng chưa đọc thì badge là 2', () async {
      await themThongBao('bill:a');
      await themThongBao('bill:b');

      await updater.dongBo(accountId);

      expect(
        os.badgeDaDat.last,
        2,
        reason: 'Badge phải bằng số chưa đọc trong app — cùng con số mà chuông '
            'trên Home đang hiện. Lệch nghĩa là badge đếm bằng một phép đếm '
            'thứ hai, và hai phép đếm sẽ trôi khỏi nhau.',
      );
    });

    test('đọc hết thì badge về 0', () async {
      await themThongBao('bill:a');
      await dao.markAllRead(accountId);

      await updater.dongBo(accountId);

      expect(
        os.badgeDaDat.last,
        0,
        reason: 'Đọc hết trong app mà badge không về 0 thì chấm trên icon nói '
            'dối — nó bảo còn việc trong khi không còn.',
      );
    });

    test('không đếm hàng của tài khoản khác', () async {
      await themThongBao('bill:a');
      await themThongBao('bill:cua-nguoi-khac', idaccount: 99);

      await updater.dongBo(accountId);

      expect(
        os.badgeDaDat.last,
        1,
        reason: 'Badge phải theo phiên đăng nhập hiện tại. Đếm cả tài khoản '
            'khác là rò dữ liệu người này sang màn hình khoá người kia.',
      );
    });
  });

  group('huỷ chọn lọc trên khay', () {
    test('hàng ĐÃ ĐỌC đang hiện trên khay thì bị huỷ', () async {
      final a = await themThongBao('bill:a');
      os.khayDangHien = {a.osId};
      await dao.markRead(a.id);

      await updater.dongBo(accountId);

      expect(
        os.daHuy,
        contains(a.osId),
        reason: 'Đọc trong app rồi thì bản sao trên khay phải rút đi, nếu '
            'không chấm trên icon sáng vĩnh viễn — Android suy badge từ khay, '
            'không từ bảng AppNotifications.',
      );
    });

    test('hàng CHƯA ĐỌC đang hiện trên khay thì được giữ nguyên', () async {
      final a = await themThongBao('bill:a');
      os.khayDangHien = {a.osId};

      await updater.dongBo(accountId);

      expect(
        os.daHuy,
        isEmpty,
        reason: 'Chưa đọc mà đã dọn khỏi khay là lấy đi lời nhắc trước khi '
            'người dùng kịp nhìn thấy nó.',
      );
    });

    test(
      'thông báo trên khay mà BẢNG KHÔNG BIẾT thì không bị đụng tới',
      () async {
        // Nhắc ghi chép hằng ngày cố ý không sinh hàng nào trong bảng — nó chỉ
        // sống ở tầng hệ điều hành. Lịch nhắc hoá đơn nổ lúc app đóng cũng ở
        // trạng thái này cho tới khi app mở và vòng quét chạy.
        final laId = osScheduledId('nhacGhiChep:2026-09-08');
        os.khayDangHien = {laId};

        // Bảng rỗng: số chưa đọc bằng 0. Bản dọn-sạch-khay sẽ xoá mất lời nhắc.
        await updater.dongBo(accountId);

        expect(
          os.daHuy,
          isEmpty,
          reason: 'Số chưa đọc bằng 0 KHÔNG có nghĩa là khay phải trống. Nhắc '
              'ghi chép hằng ngày không bao giờ có hàng trong bảng, và lịch '
              'hoá đơn nổ lúc app đóng thì chưa có hàng. Huỷ mù ở đây là xoá '
              'mất một lời nhắc thật mà không ai biết.',
        );
      },
    );

    test('huỷ đúng cái đã đọc, giữ đúng cái chưa đọc, trong cùng một lượt',
        () async {
      final daDoc = await themThongBao('bill:da-doc');
      final chuaDoc = await themThongBao('bill:chua-doc');
      final laMat = osScheduledId('nhacGhiChep:2026-09-08');
      os.khayDangHien = {daDoc.osId, chuaDoc.osId, laMat};
      await dao.markRead(daDoc.id);

      await updater.dongBo(accountId);

      expect(
        os.daHuy,
        [daDoc.osId],
        reason: 'Ba thông báo cùng nằm trên khay với ba thân phận khác nhau, '
            'và chỉ một cái được phép rời đi. Đây là bài kiểm tổng của quy tắc '
            'huỷ chọn lọc.',
      );
    });
  });

  test('KHÔNG BAO GIỜ gọi cancelAll()', () async {
    final a = await themThongBao('bill:a');
    os.khayDangHien = {a.osId};
    await dao.markAllRead(accountId);

    await updater.dongBo(accountId);

    expect(
      os.soLanHuyHet,
      0,
      reason: 'cancelAll() huỷ CẢ LỊCH ĐANG CHỜ trong AlarmManager, không chỉ '
          'thứ đang hiện trên khay. Dùng nó để dọn khay là xoá sạch mọi lời '
          'nhắc hoá đơn chưa nổ — đúng lỗi đã làm mất lịch vừa hoãn ở phiên '
          'trước, và nó không lộ ra cho tới ngày lời nhắc lẽ ra phải tới.',
    );
  });

  group('vòng đời', () {
    test('start() theo dõi và đẩy badge khi số chưa đọc đổi', () async {
      await updater.start(accountId);
      await themThongBao('bill:a');
      // Nhường cho stream của Drift phát và cho lượt đồng bộ chạy xong.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        os.badgeDaDat.last,
        1,
        reason: 'Cả điểm của việc nghe stream là badge tự đúng mà không cần ai '
            'nhớ gọi. Không có nó thì năm đường ghi cờ đã đọc phải tự gọi lấy, '
            'và chỗ bị quên sẽ hỏng âm thầm.',
      );
    });

    test('stop() cắt đứt hẳn, không đẩy badge nữa', () async {
      await updater.start(accountId);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await updater.stop();
      final soLanTruoc = os.badgeDaDat.length;

      await themThongBao('bill:sau-khi-dung');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        os.badgeDaDat.length,
        soLanTruoc,
        reason: 'Còn sót subscription sau khi đăng xuất là badge của người vừa '
            'rời đi vẫn được cập nhật bằng dữ liệu của người mới.',
      );
    });

    test('start() gọi nhiều lần không nhân listener', () async {
      await updater.start(accountId);
      await updater.start(accountId);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final soLanTruoc = os.badgeDaDat.length;

      await themThongBao('bill:a');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        os.badgeDaDat.length - soLanTruoc,
        1,
        reason: 'home_page.dart gọi SyncEngine.start() ngay trong build(); ai '
            'chép mẫu ấy sang đây thì mỗi lần Home rebuild là thêm một '
            'listener, và một thay đổi sẽ đẩy badge n lần.',
      );
    });
  });
}
