import 'notification_rules.dart';
import 'notification_scanner.dart' show BillsLoader;
import 'os/os_notifier.dart';
import 'os/os_scheduled_id.dart';
import 'prefs/notification_prefs.dart';
import 'prefs/notification_prefs_store.dart';

/// Đặt **trước** lịch nhắc hoá đơn với hệ điều hành.
///
/// ## Vì sao cần lớp này khi đã có `NotificationScanner`
///
/// Scanner chỉ chạy khi app đang mở: nó nghe `SyncEngine.statusStream` và quét
/// sau mỗi lần đồng bộ. Người dùng đóng app ba ngày thì không có lượt quét nào,
/// và nhắc hoá đơn đến hạn không bao giờ tới. Đặt lịch trước với AlarmManager
/// (Android) / UNUserNotificationCenter (iOS) là cách **duy nhất** để thông báo
/// nổ khi app đóng mà không cần tác vụ nền.
///
/// ## Điểm nối với thông báo trong app
///
/// Lịch mang `payload = dedupeKey`, dựng bằng **đúng** `billDueDedupeKey()` mà
/// bộ luật dùng. Nên khi lịch nổ lúc app đóng, người dùng bấm vào, app mở, vòng
/// quét chạy và `insertOrIgnore` sinh **đúng** hàng ấy — một lần duy nhất.
/// Không có đường nào nhân đôi.
class BillReminderScheduler {
  BillReminderScheduler({
    required this.osNotifier,
    required this.loadBills,
    this.prefsStore,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final OsNotifier osNotifier;
  final BillsLoader loadBills;

  /// Bỏ trống thì chạy như `NotificationPrefs.macDinh` — bật hết.
  final NotificationPrefsStore? prefsStore;

  final DateTime Function() clock;

  /// Chỉ đặt lịch cho hoá đơn tới hạn trong khoảng này.
  ///
  /// Khớp `NotificationScanner.cuaSoSuKien` để hai đường không nói hai chuyện
  /// khác nhau về việc "còn đáng nhắc hay chưa".
  static const Duration cuaSo = Duration(days: 30);

  /// Trần số lịch chờ.
  ///
  /// **iOS chỉ giữ 64 lịch chờ và ÂM THẦM bỏ phần còn lại** — không lỗi, không
  /// log (bẫy 7.5). Đặt trần 50 chừa chỗ cho lịch của những tính năng sau; số
  /// nào cũng được miễn là dưới 64 và việc cắt bớt là **có chủ ý** chứ không
  /// phó mặc cho nền tảng chọn hộ.
  static const int tranSoLich = 50;

  /// Đồng bộ lại toàn bộ lịch nhắc của [idaccount]. Trả về số lịch đang chờ.
  ///
  /// **Luỹ đẳng.** Gọi sau mỗi lần ghi hoá đơn và sau mỗi lần pull — tức là rất
  /// nhiều lần. Chỉ đặt cái chưa có và chỉ huỷ cái không còn cần: huỷ-rồi-đặt-
  /// lại toàn bộ ở mỗi lượt là mỗi lượt thêm một cơ hội để lịch rơi mất.
  Future<int> resync(int idaccount, {DateTime? now}) async {
    final at = now ?? clock();
    final prefs =
        await prefsStore?.read(idaccount) ?? NotificationPrefs.macDinh;

    final mongMuon = <int, _Lich>{};

    // Tắt công tắc tổng, hoặc tắt riêng nhóm hoá đơn → không có lịch nào được
    // phép tồn tại. Vẫn chạy tiếp xuống phần dọn dẹp bên dưới: lịch đã đặt
    // trước đó nằm trong AlarmManager và không tự biến mất khi người dùng gạt
    // công tắc.
    if (prefs.osBat && prefs.batNhom(NotificationGroup.bill)) {
      final bills = await loadBills(idaccount, at);
      final ungVien = <_Lich>[];

      for (final b in bills) {
        if (b.isDeleted) continue;
        // Lọc theo CẢ HAI cột trạng thái, cùng lý do như trong bộ luật: hàng
        // kéo về từ backend có thể mang `payStatus = 'Payed'` trong khi
        // `isPaid` còn false, và ngược lại.
        if (b.isPaid || b.payStatus == 'Payed') continue;

        final leadDays = billLeadDays(b, fallback: prefs.soNgayNhacHoaDon);
        final hanTra = DateTime(b.dueDate.year, b.dueDate.month, b.dueDate.day);
        final mocNhac = DateTime(
          hanTra.year,
          hanTra.month,
          hanTra.day - leadDays,
          prefs.gioNhac,
          prefs.phutNhac,
        );

        // Mốc đã trôi qua: Android bắn NGAY còn iOS lặng lẽ bỏ — hai nền tảng
        // hỏng theo hai kiểu, cả hai đều sai. Thông báo cho những hoá đơn này
        // vẫn tới qua vòng quét trong app.
        if (!mocNhac.isAfter(at)) continue;
        if (mocNhac.isAfter(at.add(cuaSo))) continue;

        final khoa = billDueDedupeKey(
          billId: b.id,
          dueDate: hanTra,
          leadDays: leadDays,
        );
        final soNgay = hanTra.difference(_dauNgay(at)).inDays;

        ungVien.add(_Lich(
          id: osScheduledId(khoa),
          khoa: khoa,
          when: mocNhac,
          title: 'Hoá đơn sắp đến hạn',
          body: soNgay <= 0
              ? '${b.name} đến hạn hôm nay.'
              : '${b.name} còn $soNgay ngày tới hạn.',
        ));
      }

      // Cắt phải bỏ những mốc XA nhất: bỏ mốc gần nhất là người dùng mất đúng
      // cái nhắc họ cần trước tiên.
      ungVien.sort((a, b) => a.when.compareTo(b.when));
      for (final l in ungVien.take(tranSoLich)) {
        mongMuon[l.id] = l;
      }
    }

    final dangCho = await osNotifier.pendingIds();

    for (final id in dangCho) {
      if (!mongMuon.containsKey(id)) await osNotifier.cancel(id);
    }

    for (final entry in mongMuon.entries) {
      if (dangCho.contains(entry.key)) continue;
      final l = entry.value;
      await osNotifier.zonedSchedule(
        id: l.id,
        title: l.title,
        body: l.body,
        when: l.when,
        payload: l.khoa,
      );
    }

    return mongMuon.length;
  }
}

DateTime _dauNgay(DateTime d) => DateTime(d.year, d.month, d.day);

class _Lich {
  const _Lich({
    required this.id,
    required this.khoa,
    required this.when,
    required this.title,
    required this.body,
  });

  final int id;
  final String khoa;
  final DateTime when;
  final String title;
  final String body;
}
