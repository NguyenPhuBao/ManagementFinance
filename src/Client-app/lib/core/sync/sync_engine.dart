import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../api/dio_client.dart';
import '../database/app_database.dart';
import '../network/trang_thai_may_chu.dart';
import 'ap_du_lieu_keo_ve.dart';
import 'cong_so_du_vi.dart';
import 'cong_vi_bi_giu.dart';
import 'sync_models.dart';
import 'sync_checkpoint_store.dart';
import 'gui_lo_dong_bo.dart';
import 'thu_gom_day.dart';

/// SyncEngine — bộ máy đồng bộ offline-first.
///
/// ## Chiến lược:
/// - **Local-first:** Mọi thao tác ghi vào SQLite ngay (syncStatus = 'pending').
/// - **Background sync:** SyncEngine theo dõi kết nối mạng và tự
///   động sync khi có internet.
/// - **Debounce:** Tránh gửi quá nhiều request liên tiếp — gom
///   các thay đổi trong 2 giây rồi mới gửi 1 batch.
/// - **Conflict resolution:** Last-Write-Wins dựa trên `updatedAt`.
///   Record nào có `updatedAt` mới hơn sẽ "thắng".
///
/// ## Cách dùng:
/// ```dart
/// // Đăng ký với GetIt:
/// sl<SyncEngine>().start(idaccount: currentUser.idaccount);
///
/// // Trigger manual (sau khi ghi local):
/// sl<SyncEngine>().scheduleSync();
/// ```
class SyncEngine {
  final Connectivity _connectivity;

  /// Ba lớp cộng tác (spec tách SyncEngine 2026-10-19) — dựng trong thân constructor vì cần bao đóng đọc trạng thái
  /// của engine.
  late final ApDuLieuKeoVe _keoVe;
  late final GuiLoDongBo _guiLo;
  late final ThuGomThaoTacDay _thuGom;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  final _pushResultController = StreamController<SyncResult>.broadcast();

  /// Kết quả của **mỗi lượt đẩy thật sự có việc để làm**.
  ///
  /// `statusStream` chỉ nói chu kỳ kết thúc ở `idle` hay `error` — không nói
  /// được "đã đưa 5 thay đổi lên server", mà đó chính là câu người dùng cần
  /// nghe sau một quãng mất mạng: họ ghi chép offline và muốn biết công sức ấy
  /// đã an toàn.
  ///
  /// **Không phát khi không có gì để đẩy.** Phần lớn chu kỳ là như vậy, và phát
  /// mọi lần là ép nơi nhận tự lọc — sớm muộn sẽ có chỗ quên lọc rồi hiện "đã
  /// đồng bộ 0 thay đổi".
  ///
  /// Kênh RIÊNG chứ không nhét vào [statusStream], cùng lý do như
  /// [sessionInvalidStream].
  Stream<SyncResult> get pushResultStream => _pushResultController.stream;

  final _sessionInvalidController = StreamController<void>.broadcast();

  /// Phát tín hiệu khi server cho thấy phiên đăng nhập trỏ tới một tài khoản
  /// không còn tồn tại (vỡ khoá ngoại `fk_*_account` khi đẩy dữ liệu).
  ///
  /// Dùng kênh RIÊNG chứ không nhét vào [statusStream], vì `stop()` kết thúc
  /// bằng `_setStatus(idle)` nên sẽ ghi đè mất trạng thái lỗi vừa phát.
  Stream<void> get sessionInvalidStream => _sessionInvalidController.stream;

  void _emitPushResult(SyncResult result) {
    if (_disposed || _pushResultController.isClosed) return;
    _pushResultController.add(result);
  }

  void _emitSessionInvalid() {
    if (_disposed || _sessionInvalidController.isClosed) return;
    _sessionInvalidController.add(null);
  }

  Timer? _debounceTimer;
  Timer? _periodicTimer;
  StreamSubscription? _connectivitySub;
  int? _currentIdaccount;

  static const _debounceSeconds = 2;

  /// Chu kỳ đồng bộ nền. Nếu không có, thiết bị này sẽ không bao giờ biết thiết
  /// bị khác vừa thay đổi gì cho tới khi chính nó ghi dữ liệu hoặc đổi mạng.
  static const _periodicSyncMinutes = 15;

  /// Giãn cách sau mỗi chu kỳ đồng bộ hỏng liên tiếp.
  ///
  /// Chỉ giữ trong RAM: một bản bền vững qua các lần mở app cần thêm cột vào
  /// lược đồ SQLite (xem G3 trong `docs/CLIENT_APP_KNOWN_GAPS.md`).
  static const List<Duration> _backoffSteps = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 60),
  ];

  /// Số chu kỳ LIÊN TIẾP mà lượt đẩy gặp 503 quá tải (`kMaQuaTai`) được hẹn lại mà KHÔNG tính là hỏng (2026-10-26). Quá
  /// chừng ấy thì server quá tải mãi là server hỏng: chu kỳ kế tính như lỗi thường — giãn cách tăng, và người dùng được
  /// báo "Đồng bộ hỏng".
  ///
  /// ⚠️ Đếm CHU KỲ, không đếm thời gian: như bảo trì (G89), lượt quá tải không dựng `_nextAllowedSyncAt`, nên mỗi lần ghi
  /// cục bộ trong lúc chờ (`scheduleSync`, gộp trong 2 s) vẫn kích một chu kỳ — bốn lần ghi cách nhau hơn 2 s giữa một đợt
  /// quá tải vẫn chạm trần và báo. Trước bản này một chu kỳ đã báo; đây là giới hạn đã biết, không phải lỗi.
  static const soLanQuaTaiKhongTinh = 3;
  int _lanQuaTaiLienTiep = 0;

  int _consecutiveFailures = 0;
  DateTime? _nextAllowedSyncAt;

  /// Hẹn giờ chạy lại chu kỳ đã bị nhánh giãn cách từ chối.
  ///
  /// Cần vì các nguồn kích hoạt còn lại đều thưa hoặc ngẫu nhiên: timer 15
  /// phút, đổi trạng thái mạng, và `start()` lúc mở app. Trước bản vá này,
  /// nhánh chặn chỉ `return` — một thay đổi ghi trong lúc giãn cách nằm chờ
  /// đúng một trong ba nguồn đó, dài hơn bậc giãn cách rất nhiều.
  ///
  /// Đo được trên app thật (2026-09-03): xoá một ngân sách trong lúc engine
  /// đang giãn cách thì thao tác **không** lên tới backend, kể cả sau khi hết
  /// giãn cách; phải mở lại app mới đẩy được. Người dùng thấy mục biến mất
  /// ngay nên tin là đã xong, còn máy khác vẫn thấy nó nguyên vẹn.
  Timer? _backoffRetryTimer;
  DateTime? _backoffRetryAt;

  /// Mốc mà hẹn giờ chạy lại sẽ nổ, `null` khi không nợ ai lần chạy nào.
  @visibleForTesting
  DateTime? get backoffRetryAt => _backoffRetryAt;

  /// Hẹn chạy lại đúng lúc [until] — mốc hết giãn cách.
  ///
  /// Cố ý **không** dựng hẹn giờ mới cho mỗi lần bị chặn: mỗi thao tác ghi đều
  /// gọi `scheduleSync()`, nên làm vậy sẽ đẩy mốc chạy lại lùi mãi về sau.
  void _scheduleBackoffRetry(DateTime until) {
    if (_disposed) return;
    if (_backoffRetryAt == until && (_backoffRetryTimer?.isActive ?? false)) {
      return;
    }
    _backoffRetryTimer?.cancel();
    _backoffRetryAt = until;
    final remaining = until.difference(_now());
    _backoffRetryTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        _backoffRetryAt = null;
        unawaited(_runSync());
      },
    );
  }

  void _cancelBackoffRetry() {
    _backoffRetryTimer?.cancel();
    _backoffRetryTimer = null;
    _backoffRetryAt = null;
  }

  /// Đồng hồ — tiêm được để test không phải chờ thật 30 giây.
  final DateTime Function() _now;

  @visibleForTesting
  int get consecutiveFailures => _consecutiveFailures;

  @visibleForTesting
  DateTime? get nextAllowedSyncAt => _nextAllowedSyncAt;

  void _registerFailedCycle() {
    _consecutiveFailures++;
    final step = _backoffSteps[
        (_consecutiveFailures - 1).clamp(0, _backoffSteps.length - 1)];
    _nextAllowedSyncAt = _now().add(step);
  }

  /// Bậc chặn cho bản ghi lỗi vĩnh viễn trong lô vừa gửi — `GuiLoDongBo` đọc qua hàm này lúc gặp lỗi (sau `await`).
  /// Biểu thức chép nguyên văn từ `SyncEngine._sendBatch` cũ (nay `GuiLoDongBo.sendBatch` đọc qua `_bacChan()`): chỉ số là `_consecutiveFailures`, KHÔNG trừ một như ở trên.
  Duration _bacChanHienTai() =>
      _backoffSteps[_consecutiveFailures.clamp(0, _backoffSteps.length - 1)];

  void _resetBackoff() {
    _consecutiveFailures = 0;
    _nextAllowedSyncAt = null;
    // `start()` / `stop()` cũng qua đây — phiên mới không thừa chuỗi quá tải của phiên trước.
    _lanQuaTaiLienTiep = 0;
    // Không còn giãn cách thì cũng không còn gì để chờ — một hẹn giờ sót lại
    // chỉ chạy thêm một chu kỳ thừa.
    _cancelBackoffRetry();
  }

  /// Đã kéo dữ liệu về thành công ít nhất một lần trong phiên này chưa.
  ///
  /// Dùng để biết khi nào **đã có thể tin** vào nội dung SQLite cục bộ. Trước
  /// khi pull xong, một CSDL rỗng không phân biệt được với "tài khoản chưa có
  /// gì" — và `PersonalDefaultCategories` từng vấp đúng chỗ đó: nó tạo 5 danh
  /// mục trên một máy mới trong khi tài khoản đã có sẵn chúng ở backend, sinh
  /// ra 5 thao tác đẩy hỏng vĩnh viễn (G14).
  ///
  /// Cố ý **không** suy ra từ `ApDuLieuKeoVe._lastPullTime`: mốc đó chỉ được đặt khi có dữ
  /// liệu trả về, nên tài khoản mới toanh sẽ mãi trông như chưa pull lần nào.
  bool get hasCompletedPull => _keoVe.daKeoXong;

  /// Số lần kéo về THÀNH CÔNG trong đời engine này. Bước Pull nuốt lỗi nên trạng thái "chu kỳ xong" không nói được
  /// dữ liệu đã mới chưa; `NotificationScanner` đọc con số này để chỉ gộp kỳ hoá đơn trùng (G87) trên dữ liệu vừa
  /// làm mới — gộp trên dữ liệu cũ là xoá hoá đơn máy khác đã trả.
  int get soLanKeoVeXong => _keoVe.soLanKeoVeXong;

  /// `true` khi lượt kéo về gần nhất bị máy chủ TRẢ LỜI bằng lỗi (2026-10-26, đơn 53 vế C) — Trang chủ hiện dòng nhắc
  /// *"Chưa nhận được dữ liệu mới"* (`DongNhacKeoVe`). Bước Pull vẫn nuốt lỗi: chu kỳ KHÔNG thành `error` (bộ quét sẽ nổ
  /// "Đồng bộ hỏng") và KHÔNG giãn cách (lượt đẩy vẫn tốt) — người dùng chốt chỉ dòng nhắc. Tắt khi một lượt kéo thành
  /// công và khi [stop]; mất mạng giữ nguyên. Luật mã HTTP: `keoVeBiMayChuTuChoi` (`ap_du_lieu_keo_ve.dart`).
  ValueListenable<bool> get keoVeBiTuChoi => _keoVe.biTuChoi;

  /// Việc chạy sau **MỖI** lượt kéo về thành công, trong chính chu kỳ ấy (sau Pull, trước lần thử đẩy lại) — DI nối bộ
  /// gieo danh mục mặc định (quy tắc 8 `CLAUDE.md`; `core/sync` không biết tên mảng). Trả số hàng vừa ghi; > 0 thì hẹn
  /// đẩy. `null` = không có việc gì. Nhận kèm các thay đổi khuôn của lượt (`ApDuLieuKeoVe.thayDoiKhuonLuotCuoi`, spec
  /// 2026-10-27 mục 5).
  final ViecSauKeoVe? _sauKeoVe;

  /// Trạng thái máy chủ (spec G89 mục 3.3) — `null` = hành vi như trước G89 (test cũ không truyền). DI truyền bản thật.
  final TrangThaiMayChu? _trangThaiMayChu;

  SyncEngine({
    required DioClient dioClient,
    required AppDatabase db,
    required CongSoDuVi soDuVi,
    required CongViBiGiu viBiGiu,
    Connectivity? connectivity,
    SyncCheckpointStore? checkpointStore,
    DateTime Function()? now,
    ViecSauKeoVe? sauKeoVe,
    TrangThaiMayChu? trangThaiMayChu,
  })  : _now = now ?? DateTime.now,
        _connectivity = connectivity ?? Connectivity(),
        _sauKeoVe = sauKeoVe,
        _trangThaiMayChu = trangThaiMayChu {
    _keoVe = ApDuLieuKeoVe(
      dioClient: dioClient,
      db: db,
      soDuVi: soDuVi,
      checkpointStore: checkpointStore,
    );
    _thuGom = ThuGomThaoTacDay(
      db: db,
      viBiGiu: viBiGiu,
      now: _now,
      taiKhoanPhien: () => _currentIdaccount,
    );
    _guiLo = GuiLoDongBo(
      dioClient: dioClient,
      db: db,
      now: _now,
      bacChan: _bacChanHienTai,
    );
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Khởi động SyncEngine sau khi user đăng nhập thành công.
  Future<void> start({required int idaccount}) async {
    // Đăng nhập / mở app là hành động chủ động của người dùng — xoá giãn cách
    // của phiên trước để họ không phải chờ hết một chu kỳ backoff cũ.
    _resetBackoff();
    _currentIdaccount = idaccount;
    await _keoVe.napMoc(idaccount);

    // Lắng nghe thay đổi kết nối
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        debugPrint('[SyncEngine] Network restored — scheduling sync');
        unawaited(syncNow());
      }
    });

    // Đồng bộ nền định kỳ để nhận thay đổi từ thiết bị khác.
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(minutes: _periodicSyncMinutes),
      (_) => unawaited(syncNow()),
    );

    // Kích hoạt đồng bộ LẬP TỨC ngay khi vừa đăng nhập (không cần chờ thao tác)
    await syncNow();
  }

  /// Dừng SyncEngine khi logout.
  void stop() {
    _debounceTimer?.cancel();
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _connectivitySub?.cancel();
    _currentIdaccount = null;
    _keoVe.datLaiPhien();
    _resetBackoff();
    _setStatus(SyncStatus.idle);
  }

  // ── Trigger ───────────────────────────────────────────────────────────────

  /// Kích hoạt đồng bộ LẬP TỨC (Immediate Sync) không cần chờ timer debounce.
  Future<void> syncNow() async {
    _debounceTimer?.cancel();
    await _runSync();
  }

  /// Lượt kéo về KẾ TIẾP đi từ 1970 rồi chạy ngay — cho khi tài khoản vừa VÀO một phạm vi dữ liệu mà mốc tăng dần đã vượt
  /// qua (gia đình: vào nhà — dữ liệu cũ của nhà mang `Server_update_at` dưới mốc; spec 2026-10-23 mục 4.3). `core/sync`
  /// không biết khái niệm nhà: người gọi là bộ điều phối của mảng gia đình, nối ở DI.
  ///
  /// Yêu cầu giữ tới khi MỘT lượt kéo bắt đầu SAU nó thành công: lượt đang chạy lúc gọi không ghi mốc, lượt hỏng không xoá
  /// yêu cầu, mốc đã lưu bị xoá ngay. Chu kỳ đang chạy thì `syncNow` ghi nợ một lượt bù — lượt bù ấy là lượt kéo toàn bộ.
  Future<void> keoLaiToanBo(int idaccount) async {
    await _keoVe.yeuCauKeoToanBo(idaccount);
    if (_currentIdaccount == idaccount) await syncNow();
  }

  /// MỘT lượt đồng bộ cho lượt nền của WorkManager (spec tự chuyển tiền chạy
  /// nền mục 3.3).
  ///
  /// Không đi qua [start]: `start()` dựng hẹn giờ 15 phút và bộ nghe mạng — thứ
  /// lượt nền không được để lại — và chỉ `auth_bloc.dart` được gọi nó (test quét
  /// thứ tư). Đặt `_currentIdaccount` cho riêng lượt này rồi TRẢ LẠI giá trị cũ,
  /// nên một `scheduleSync()` sau đó không chạy nhầm cho tài khoản này.
  Future<void> syncMotLuot(int idaccount) async {
    final cu = _currentIdaccount;
    _currentIdaccount = idaccount;
    await _keoVe.napMocNeuChuaCo(idaccount);
    try {
      await _runSync();
    } finally {
      _currentIdaccount = cu;
    }
  }

  /// Đặt lịch sync với debounce — gọi liên tiếp chỉ trigger 1 lần.
  void scheduleSync() {
    // Sau logout, `stop()` đặt _currentIdaccount = null nhưng các repository
    // vẫn tiếp tục gọi scheduleSync() sau mỗi lần ghi — bỏ qua cho rẻ.
    if (_currentIdaccount == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(seconds: _debounceSeconds),
      () => _runSync(),
    );
    if (_status == SyncStatus.idle) {
      _setStatus(SyncStatus.pending);
    }
  }

  // ── Core sync logic ───────────────────────────────────────────────────────

  /// Có một yêu cầu đồng bộ bị từ chối vì chu kỳ khác đang chạy, và đang **nợ**
  /// người gọi một lần chạy.
  ///
  /// Cùng lý lẽ với `_scheduleBackoffRetry` ở nhánh giãn cách: từ chối một yêu
  /// cầu mà không hẹn lại thì thay đổi vừa ghi nằm chờ một nguồn kích hoạt khác
  /// — timer 15 phút, đổi mạng, hoặc lần mở app sau. Nguồn hay rơi đúng vào cửa
  /// sổ này lại là hai nguồn dày nhất: `scheduleSync()` sau mỗi lần ghi, và sự
  /// kiện `sync.completed` của socket (G34) khi máy khác vừa đẩy xong.
  ///
  /// Là `bool` chứ không phải bộ đếm: nhiều yêu cầu dồn vào một cửa sổ vẫn chỉ
  /// đáng **một** lần chạy bù, vì `ThuGomThaoTacDay.collectPendingOps` gom toàn bộ bản ghi còn
  /// `pending` chứ không xử theo từng yêu cầu.
  bool _noMotLanChay = false;

  Future<void> _runSync() async {
    // Danh tính CHỈ đến từ phiên đăng nhập, không bao giờ suy ra từ dữ liệu
    // trong SQLite. Trước đây khi `_currentIdaccount` là null hoặc 1, engine
    // đọc `walletDao.getAllNonDeleted()` (không lọc tài khoản) và lấy
    // `idaccount` của ví đầu tiên — đủ để làm sống lại một tài khoản đã bị xoá,
    // hoặc chiếm danh tính của admin (idaccount = 1 vốn là tài khoản THẬT chứ
    // không phải giá trị "chưa biết").
    if (_disposed) return;
    final accountId = _currentIdaccount;
    if (accountId == null || accountId <= 0) {
      debugPrint('[SyncEngine] Chưa có phiên đăng nhập — bỏ qua đồng bộ');
      _setStatus(SyncStatus.idle);
      return;
    }
    // Không chạy chồng — nhưng ghi nợ để chạy bù, đừng nuốt yêu cầu.
    if (_status == SyncStatus.syncing) {
      _noMotLanChay = true;
      return;
    }

    // Giãn dần sau các chu kỳ hỏng liên tiếp. Trước đây thao tác `transient`
    // được thử lại ở MỌI chu kỳ kế tiếp mà không giãn ra, trong khi nguồn kích
    // hoạt thì dày đặc: debounce 2 giây sau mỗi lần ghi, đổi trạng thái mạng,
    // timer 15 phút và mỗi lần start(). Server đang hỏng sẽ nhận đúng lượng
    // request đó lặp lại mãi.
    final blockedUntil = _nextAllowedSyncAt;
    if (blockedUntil != null && _now().isBefore(blockedUntil)) {
      debugPrint('[SyncEngine] Đang trong thời gian giãn cách sau '
          '$_consecutiveFailures chu kỳ hỏng — hoãn tới $blockedUntil');
      // Từ chối một yêu cầu đồng bộ nghĩa là NỢ người gọi một lần chạy. Chỉ
      // `return` ở đây thì thay đổi vừa ghi nằm chờ một nguồn kích hoạt khác —
      // timer 15 phút, đổi mạng, hoặc lần mở app sau.
      _scheduleBackoffRetry(blockedUntil);
      _setStatus(SyncStatus.pending);
      return;
    }

    // Kiểm tra kết nối
    final connectivity = await _connectivity.checkConnectivity();
    final hasConnection = connectivity.any((r) => r != ConnectivityResult.none);
    if (!hasConnection) {
      _setStatus(SyncStatus.pending);
      debugPrint('[SyncEngine] No connection — sync deferred');
      return;
    }

    _setStatus(SyncStatus.syncing);
    debugPrint(
        '[SyncEngine] Starting full sync (Push & Pull) for account $accountId');

    // G89: trạng thái máy chủ LÚC VÀO chu kỳ — cuối chu kỳ chỉ tính lời chặn ghi TRONG chu kỳ này (mỗi phản hồi chặn là một
    // đối tượng mới), để một 503 cũ còn sót (trợ lý online, chu kỳ trước) không biến lỗi mạng thường thành hẹn 30 s.
    final chanDauChuKy = _trangThaiMayChu?.value;

    try {
      // 1. Push local pending ops to Backend
      final ops = await _thuGom.collectPendingOps(accountId);
      SyncResult? pushResult;
      if (ops.isNotEmpty) {
        pushResult = await _guiLo.sendBatch(ops);
        debugPrint('[SyncEngine] Push complete: $pushResult');
      } else {
        debugPrint(
            '[SyncEngine] No pending local ops — proceeding to Pull from backend');
      }

      // Phiên trỏ tới tài khoản không còn tồn tại → thử lại là vô ích, và mỗi
      // chu kỳ lại nhân đôi số request hỏng. Dừng hẳn và báo ra ngoài.
      if (pushResult != null && pushResult.hasSessionInvalid) {
        debugPrint('[SyncEngine] Phiên đăng nhập không còn hợp lệ — dừng đồng bộ');
        _emitSessionInvalid();
        _setStatus(SyncStatus.authExpired);
        return;
      }

      // Phát kết quả đẩy **TRƯỚC** bước Pull — thứ tự này là một cam kết.
      //
      // Người nghe phản ứng với THẤT BẠI của lần đẩy, và phản ứng ấy thường
      // phải bù lại một thay đổi cục bộ mà chính máy này vừa ghi. Pull ở giữa
      // có thể đã thay đúng hàng ấy bằng bản của server, nên phép bù cộng vào
      // một con số **không hề chứa** thay đổi cần bù.
      //
      // ⚠️ ĐÃ VẤP THẬT ngày 2026-09-13, và 2303 ca test đều xanh — đúng loại
      // lỗi thứ ba ở mục "Ba loại lỗi `flutter test` KHÔNG bắt được". Hoá đơn
      // tự trả trên hai máy: ví bị trừ còn 1.650.000 → push ví xung đột, server
      // giữ 2.000.000 → **pull ghi đè, lần trừ biến mất** → resolver hoàn
      // 350.000 → ví thành **2.350.000**. Phình thêm đúng một lần trả, im lặng.
      if (pushResult != null) _emitPushResult(pushResult);

      // 2. Pull all updated data from Backend PostgreSQL to SQLite local
      final soLanKeoTruoc = _keoVe.soLanKeoVeXong;
      await _keoVe.pullFromBackend(accountId);
      // Gác theo SỐ LẦN kéo xong, không theo `hasCompletedPull`: cờ ấy đúng mãi sau lượt đầu, còn Pull nuốt lỗi.
      if (_keoVe.soLanKeoVeXong > soLanKeoTruoc) await _sauMoiLuotKeoVe(accountId);

      // Một transaction thất bại có thể đang trỏ tới ID danh mục mặc định cũ;
      // Pull xong mới có UUID từ backend nên đáng thử lại MỘT lần.
      // Chỉ thử lại khi thật sự có lỗi thuộc loại tạm thời — trước đây điều
      // kiện chỉ là `failed > 0` nên lỗi vĩnh viễn cũng bị gửi lại mỗi chu kỳ.
      SyncResult? retryResult;
      if (pushResult != null && pushResult.hasRetryableFailure) {
        final retryOps = await _thuGom.collectPendingOps(accountId);
        if (retryOps.isNotEmpty) {
          retryResult = await _guiLo.sendBatch(retryOps);
          debugPrint('[SyncEngine] Push retry complete: $retryResult');
          if (retryResult.hasSessionInvalid) {
            _emitSessionInvalid();
            _setStatus(SyncStatus.authExpired);
            return;
          }
        }
      }

      // Trạng thái kết thúc phải phản ánh kết quả thật. Trước đây chu kỳ nào
      // cũng kết thúc bằng `idle`, kể cả khi mọi thao tác đẩy đều hỏng — nên
      // `SyncStatus.error` gần như là mã chết: `GuiLoDongBo.sendBatch` không ném lỗi ra
      // ngoài nên khối `catch` bên dưới chỉ chạm tới được khi có exception
      // thật sự, chứ không phải khi server từ chối dữ liệu.
      //
      // Lấy kết quả của lần đẩy SAU CÙNG: `ThuGomThaoTacDay.collectPendingOps` gom lại toàn bộ
      // bản ghi còn `pending` nên lần thử lại đã bao gồm cả những thao tác hỏng
      // vĩnh viễn của lần đầu.
      final lastPush = retryResult ?? pushResult;
      final stillFailing = lastPush != null && lastPush.failed > 0;
      // G89 (spec mục 3.3): máy chủ bảo trì / phong toả có giờ → KHÔNG tính lượt hỏng (không đụng `_consecutiveFailures`
      // lẫn `_nextAllowedSyncAt` — đổi mạng vẫn thử ngay được), hẹn thử lại đúng mốc server cho (sàn `kSanThuLai`), và kết
      // thúc `pending` chứ không `error`: `error` là bộ quét thông báo nổ "Đồng bộ hỏng" (`NotificationKind.syncFailed`) cho
      // một sự cố đã có dòng nhắc riêng ở Trang chủ. Áp cả khi không có gì để đẩy mà chỉ lượt kéo bị chặn. Mốc bảo trì
      // trượt theo mỗi 503 mới (`thuLaiLuc` tính từ lúc nhận) — vô hại: mỗi 503 ấy đã là một request.
      final mocChan = _mocThuLaiNeuBiChan(chanDauChuKy);
      // Quá tải thoáng qua (503 `kMaQuaTai`, 2026-10-26): cùng luật với bảo trì — không tính lượt hỏng, hẹn theo
      // `Retry-After` (sàn 30 s), kết thúc `pending` — nhưng chỉ [soLanQuaTaiKhongTinh] chu kỳ liên tiếp. Lượt kéo bị cắt
      // tải thì `ApDuLieuKeoVe` nuốt lỗi như mọi lỗi kéo; chỉ lượt đẩy biến chu kỳ thành `error`.
      final quaTai = lastPush?.quaTaiThuLaiLuc;
      _lanQuaTaiLienTiep = quaTai == null ? 0 : _lanQuaTaiLienTiep + 1;
      final mocHen = mocChan ?? (_lanQuaTaiLienTiep <= soLanQuaTaiKhongTinh ? quaTai : null);
      if (mocHen != null) {
        debugPrint(mocChan != null
            ? '[SyncEngine] Máy chủ đang chặn — không tính lượt hỏng, thử lại lúc $mocHen'
            : '[SyncEngine] Máy chủ quá tải (lượt $_lanQuaTaiLienTiep) — không tính lượt hỏng, thử lại lúc $mocHen');
        _scheduleBackoffRetry(mocHen);
      } else if (stillFailing) {
        _registerFailedCycle();
      } else {
        _resetBackoff();
      }
      // Lần đẩy đầu đã được phát TRƯỚC bước Pull (xem chú thích ở đó). Ở đây
      // chỉ còn kết quả của lần THỬ LẠI, và nó buộc phải nằm sau Pull vì chính
      // Pull là thứ làm nó đáng thử lại. Người nghe phải chịu được hai lượt
      // phát cho cùng một thất bại — `BillPaymentConflictResolver` chịu được,
      // vì khoản chi đã gỡ thì không còn tìm thấy ở lượt sau.
      if (retryResult != null) _emitPushResult(retryResult);
      _setStatus(mocHen != null ? SyncStatus.pending : (stillFailing ? SyncStatus.error : SyncStatus.idle));
    } catch (e) {
      debugPrint('[SyncEngine] Sync error: $e');
      _setStatus(SyncStatus.error);
    } finally {
      // Trả món nợ ghi ở đầu hàm. Đặt trong `finally` để chu kỳ bù vẫn chạy khi
      // chu kỳ này kết thúc bằng lỗi — yêu cầu bị từ chối không liên quan gì
      // tới việc chu kỳ đang chạy thành hay bại.
      if (_noMotLanChay && !_disposed) {
        _noMotLanChay = false;
        debugPrint('[SyncEngine] Chạy bù cho yêu cầu đến giữa chu kỳ trước');
        unawaited(_runSync());
      }
    }
  }

  /// Mốc thử lại khi máy chủ đang chặn VÀ lời chặn được ghi trong chu kỳ vừa chạy (khác [chanDauChuKy]); `null` = không.
  DateTime? _mocThuLaiNeuBiChan(TinhTrangMayChu? chanDauChuKy) {
    final hienTai = _trangThaiMayChu?.value;
    if (hienTai == null || identical(hienTai, chanDauChuKy)) return null;
    return mocThuLaiKhiBiChan(hienTai, _now());
  }

  /// Chạy [_sauKeoVe] cho [accountId] — tài khoản của CHU KỲ (biến cục bộ của `_runSync`, đúng cả với `syncMotLuot`).
  ///
  /// Ba chốt (ca canh `sync_gieo_sau_keo_ve_test.dart`): chạy trong cờ `syncing` nên hai lượt không gieo chồng nhau
  /// (gieo chồng là bản sao trùng — dạng G16); phiên đã đóng giữa lượt kéo (`stop()`) thì bỏ; lỗi chỉ ghi log — Đẩy và
  /// Kéo đã xong, biến chu kỳ thành `error` là kéo engine vào giãn cách vì một việc cục bộ, và lượt kéo sau tự thử lại.
  Future<void> _sauMoiLuotKeoVe(int accountId) async {
    final viec = _sauKeoVe;
    if (viec == null || _currentIdaccount != accountId) return;
    try {
      final daGhi = await viec(accountId, _keoVe.thayDoiKhuonLuotCuoi);
      if (daGhi > 0) {
        debugPrint('[SyncEngine] Việc sau kéo về ghi $daGhi hàng — hẹn đẩy');
        scheduleSync(); // hàng vừa ghi nằm sau bước đẩy của chu kỳ này
      }
    } catch (e) {
      debugPrint('[SyncEngine] Việc sau kéo về hỏng — lượt kéo sau thử lại: $e');
    }
  }

  /// Chuyển tiếp — định nghĩa và lý do ở [GuiLoDongBo.accountNotFoundCode] (tách SyncEngine 2026-10-19). Giữ vì là
  /// API công khai của engine (`sync_payload_contract_test` đọc nó).
  static const String accountNotFoundCode = GuiLoDongBo.accountNotFoundCode;

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setStatus(SyncStatus s) {
    _status = s;
    // Timer debounce/định kỳ và listener kết nối có thể kích hoạt SAU khi engine
    // đã bị huỷ; khi đó `add()` trên controller đã đóng sẽ ném
    // "Bad state: Cannot add new events after calling close".
    if (_disposed || _statusController.isClosed) return;
    _statusController.add(s);
  }

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    stop();
    _statusController.close();
    _sessionInvalidController.close();
    _pushResultController.close();
  }
}
