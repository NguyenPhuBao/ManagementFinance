import '../../features/goal/domain/goal_auto_deposit.dart';
import 'notification_rules.dart';
import 'notification_scanner.dart' show BillsLoader, GoalsLoader;
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
class ReminderScheduler {
  ReminderScheduler({
    required this.osNotifier,
    required this.loadBills,
    this.loadGoals,
    this.loadLastTransactionAt,
    this.prefsStore,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final OsNotifier osNotifier;
  final BillsLoader loadBills;

  /// Bỏ trống thì không đặt lịch nhắc kỳ trích nào — dùng cho test của phần
  /// hoá đơn, để chúng không phải dựng dữ liệu mục tiêu.
  final GoalsLoader? loadGoals;

  /// Mốc giao dịch gần nhất của tài khoản. Bỏ trống thì không đặt lịch nhắc
  /// ghi chép nào — cùng lý do như [loadGoals].
  ///
  /// `null` **trả về từ hàm này** nghĩa là *chưa từng ghi giao dịch nào*, và
  /// phải đọc thành **cần nhắc**: người mới cài app chính là người cần nhắc
  /// nhất. Đừng lẫn với việc bỏ trống chính callback này, vốn nghĩa là *tính
  /// năng không được nối vào*.
  final Future<DateTime?> Function(int idaccount)? loadLastTransactionAt;

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

  /// Số ngày đặt trước cho lời nhắc ghi chép.
  ///
  /// **Ba, và con số này là một đánh đổi có tính toán.** Đặt một lịch rồi chờ
  /// lượt `resync` sau gia hạn thì người không mở app chỉ được nhắc **đúng một
  /// lần** rồi im — mà đó chính là người cần nhắc nhất. Đặt nhiều ngày hơn thì
  /// tốn suất trong [tranSoLich], và phép cắt sắp theo **thời gian** nên lịch
  /// hằng ngày luôn nằm gần nhất và **thắng** nhắc hoá đơn. Hoá đơn là tiền,
  /// nhắc ghi chép là thói quen — không được đảo thứ tự ấy. Ba suất trên năm
  /// mươi thì không đe doạ gì, mà vẫn phủ được một người mở app vài ngày một
  /// lần. Sau ba lần bị lờ đi, nhắc tiếp là làm phiền.
  static const int soNgayNhacGhiChep = 3;

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

    /// Ứng viên của **cả ba** loại, gộp lại trước khi cắt theo trần.
    final tatCa = <_Lich>[];

    /// Id của lời nhắc thuộc những hoá đơn **còn sống** — chưa trả, chưa xoá.
    ///
    /// Khác [mongMuon] ở đúng một điểm, và điểm ấy là cả lý do nó tồn tại: tập
    /// này **không lọc theo mốc nhắc**. Nó chỉ dùng ở bước dọn dẹp bên dưới,
    /// để đừng huỷ mất một lịch người dùng vừa bấm **"Hoãn"**.
    ///
    /// Vì sao cần: nút "Hoãn" giữ nguyên khoá (và do đó nguyên id) rồi dời lịch
    /// sang mốc mới. Nhưng người dùng chỉ bấm "Hoãn" được **sau khi thông báo
    /// đã nổ**, nên mốc nhắc gốc khi ấy **luôn** nằm ở quá khứ — hoá đơn rơi
    /// vào nhánh `if (!mocNhac.isAfter(at)) continue;` và biến mất khỏi
    /// [mongMuon]. Không có tập này thì lượt quét kế tiếp huỷ đúng cái lịch
    /// người dùng vừa hoãn, im lặng.
    ///
    /// Ngoại lệ được giữ **hẹp** có chủ ý: chỉ hoá đơn còn sống. Trả hoặc xoá
    /// hoá đơn là id rời khỏi tập này và lịch hoãn bị dọn như mọi lịch thừa
    /// khác — phép dọn dẹp của `resync` không được nới lỏng.
    final khongHuy = <int>{};

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
        final khoa = billDueDedupeKey(
          billId: b.id,
          dueDate: hanTra,
          leadDays: leadDays,
        );

        // Ghi nhận TRƯỚC hai phép lọc theo mốc bên dưới — xem chú thích ở
        // `khongHuy`. Một lịch đã hoãn mang đúng khoá này nhưng nằm ở mốc khác
        // hẳn, và mốc gốc thì luôn đã trôi qua.
        khongHuy.add(osScheduledId(khoa));

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
        final soNgay = hanTra.difference(_dauNgay(at)).inDays;

        // Hoá đơn bật tự trả: người dùng đã uỷ quyền cho app trả, nhưng bộ
        // tự trả chỉ chạy khi app mở. Lời nhắc vì thế phải bảo họ MỞ APP chứ
        // không bảo đi trả tay. Cùng khoá lịch — đổi công tắc không phải một
        // sự kiện mới.
        final tuTra = b.autoPayEnabled;
        ungVien.add(_Lich(
          id: osScheduledId(khoa),
          khoa: khoa,
          when: mocNhac,
          title: tuTra ? 'Hoá đơn sắp được tự trả' : 'Hoá đơn sắp đến hạn',
          body: tuTra
              ? (soNgay <= 0
                  ? '${b.name} đến hạn hôm nay. Mở app để hoá đơn được tự trả.'
                  : '${b.name} còn $soNgay ngày tới hạn. Mở app vào ngày đó để '
                      'hoá đơn được tự trả.')
              : (soNgay <= 0
                  ? '${b.name} đến hạn hôm nay.'
                  : '${b.name} còn $soNgay ngày tới hạn.'),
        ));
      }

      tatCa.addAll(ungVien);
    }

    // Nhóm mục tiêu tắt bật ĐỘC LẬP với nhóm hoá đơn, dù hai loại lịch dùng
    // chung một bộ đặt.
    final tai = loadGoals;
    if (tai != null && prefs.osBat && prefs.batNhom(NotificationGroup.goal)) {
      for (final g in await tai(idaccount, at)) {
        if (g.isDeleted || !g.autoDepositEnabled) continue;
        if (g.isCompleted || g.remainingAmount <= 0) continue;

        final ky = kyKeTiep(
          mocNeo: g.timeCycleTakeMoney,
          lanChayGanNhat: g.autoDepositLastRun,
          chuKy: g.cycleTakeMoney,
          now: at,
        );
        if (ky == null) continue;
        if (ky.isAfter(at.add(cuaSo))) continue;

        // ĐÚNG khoá của thông báo "đã trích" cho chính kỳ ấy — nên cùng
        // `osScheduledId`, và khi khoản trích chạy xong thông báo kia THAY CHỖ
        // lời nhắc thay vì nằm cạnh nó. Hai thông báo cho một sự việc là thứ
        // người dùng đọc thành "app trích hai lần".
        final khoa = 'goalAuto:${khoaKyTrich(g.id, ky)}';

        tatCa.add(_Lich(
          id: osScheduledId(khoa),
          khoa: khoa,
          // Mốc của chính kỳ, KHÔNG phải `prefs.gioNhac`: giờ nhắc chung là
          // của hoá đơn, còn kỳ trích có giờ riêng người dùng đã chọn và đang
          // nhìn thấy trên màn hình.
          when: ky,
          title: 'Đến kỳ trích tự động',
          body: '${_tienGon(g.autoDepositAmount!)} cho mục tiêu ${g.name}. '
              'Mở app để tiền được chuyển.',
        ));
      }
    }

    // Nguồn ứng viên thứ ba, và là nguồn DUY NHẤT suy từ việc **không có** dữ
    // liệu. Không đi qua bộ luật và không sinh hàng nào trong
    // `AppNotifications` — xem chú thích ở `NotificationPrefs.nhacGhiChepBat`.
    // Cũng không chịu công tắc nhóm nào: nó không phải một `NotificationKind`.
    final docMoc = loadLastTransactionAt;
    if (docMoc != null && prefs.osBat && prefs.nhacGhiChepBat) {
      final homNay = _dauNgay(at);
      final mocCuoi = await docMoc(idaccount);

      // `null` = chưa từng ghi gì = CẦN nhắc. Đọc ngược lại là người mới cài
      // app không bao giờ được nhắc.
      final daGhiHomNay = mocCuoi != null && _dauNgay(mocCuoi) == homNay;

      for (var i = 0; i < soNgayNhacGhiChep; i++) {
        // Chỉ **hôm nay** mới biết được đã ghi hay chưa; hai ngày sau thì
        // không, nên chúng vẫn được đặt. Nếu người dùng ghi sớm vào ngày ấy
        // thì lượt `resync` của chính ngày ấy sẽ gỡ lịch đi — đó là cả lý do
        // chọn ba lịch RỜI thay vì một lịch lặp `DateTimeComponents.time`:
        // lịch lặp chỉ tốn một suất nhưng không bỏ qua được ngày nào.
        if (i == 0 && daGhiHomNay) continue;

        final ngay = DateTime(homNay.year, homNay.month, homNay.day + i);
        final moc = DateTime(ngay.year, ngay.month, ngay.day,
            prefs.gioNhacGhiChep, prefs.phutNhacGhiChep);

        // Mốc đã trôi qua: Android bắn NGAY còn iOS lặng lẽ bỏ — cùng lý lẽ
        // với nhánh hoá đơn bên trên.
        if (!moc.isAfter(at)) continue;

        final khoa = ghiChepDedupeKey(ngay);
        tatCa.add(_Lich(
          id: osScheduledId(khoa),
          khoa: khoa,
          when: moc,
          // Câu HỎI, không phải câu khẳng định. Hai lịch của ngày mai và ngày
          // kia được đặt lúc chưa ai biết hôm ấy có ghi gì không, nên một câu
          // "hôm nay bạn chưa ghi gì" có thể nói sai — và một thông báo nói
          // sai là thứ người dùng tắt ngay lần đầu gặp.
          title: 'Hôm nay bạn đã ghi gì chưa?',
          body: 'Ghi lại vài dòng để cuối tháng còn nhìn lại được.',
        ));
      }
    }

    // Cắt phải bỏ những mốc XA nhất: bỏ mốc gần nhất là người dùng mất đúng
    // cái nhắc họ cần trước tiên. Trần tính trên TỔNG ba loại — iOS đếm chung
    // một hàng đợi 64 lịch, nên cắt riêng từng loại là cả ba đều tưởng mình
    // còn dư chỗ.
    tatCa.sort((a, b) => a.when.compareTo(b.when));
    for (final l in tatCa.take(tranSoLich)) {
      mongMuon[l.id] = l;
    }

    final dangCho = await osNotifier.pendingIds();

    for (final id in dangCho) {
      if (mongMuon.containsKey(id)) continue;
      // Lịch đã hoãn của một hoá đơn còn sống — giữ nguyên cả mốc lẫn id.
      if (khongHuy.contains(id)) continue;
      await osNotifier.cancel(id);
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

/// Khoá của lời nhắc ghi chép cho **một ngày**.
///
/// Ngày nằm trong khoá là thứ làm `resync()` luỹ đẳng: cùng một ngày luôn cho
/// cùng `osScheduledId`, nên lượt chạy sau nhận ra lịch đã đặt và không đặt
/// lại.
///
/// ⚠️ Tiền tố `ghiChep` được `deeplinkTuDedupeKey()` so khớp **bằng chữ**, y
/// như `billDue` và `walletNeg`. Đổi tiền tố ở đây mà quên đổi bên ấy thì cú
/// chạm rơi về `/notifications` — không lỗi, không log, chỉ là đi sai chỗ.
///
/// Khác mọi khoá còn lại ở một điểm: nó **không** tương ứng với hàng nào trong
/// `AppNotifications`. Lời nhắc này chỉ sống ở tầng hệ điều hành.
String ghiChepDedupeKey(DateTime ngay) {
  final thang = ngay.month.toString().padLeft(2, '0');
  final ngayTrongThang = ngay.day.toString().padLeft(2, '0');
  return 'ghiChep:${ngay.year}-$thang-$ngayTrongThang';
}

/// Rút gọn số tiền cho câu nhắc. Bản riêng ở đây thay vì dùng chung với bộ luật
/// vì hàm bên ấy là private — và một lời nhắc chỉ cần đủ để người dùng quyết
/// định có mở app hay không, không cần con số đầy đủ.
String _tienGon(double v) {
  if (v >= 1000000) {
    final trieu = v / 1000000;
    final s = trieu.toStringAsFixed(trieu >= 10 ? 0 : 1).replaceAll('.', ',');
    return '${s.endsWith(',0') ? s.substring(0, s.length - 2) : s} triệu';
  }
  if (v >= 1000) return '${(v / 1000).round()} nghìn';
  return '${v.round()} đồng';
}

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
