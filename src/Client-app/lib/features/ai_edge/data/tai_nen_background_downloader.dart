// lib/features/ai_edge/data/tai_nen_background_downloader.dart
/// Bản [NguonTaiNen] thật — bọc `background_downloader`.
///
/// Tệp **duy nhất** của dự án import gói ấy, cùng khuôn `slm_runtime.dart` với
/// `flutter_gemma`: mọi tầng trên chỉ thấy [NguonTaiNen] nên test dựng được
/// bản giả mà không cần máy Android.
library;

import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';

import 'nguon_tai_nen.dart';

/// ⚠️ **Hằng của dự án, KHÔNG để gói sinh ngẫu nhiên.**
///
/// Id này là sợi dây duy nhất nối lượt tải của **lần chạy trước** với tiến
/// trình lần này. Id ngẫu nhiên thì sau khi app bị thoát, lượt tải vẫn chạy
/// nhưng không ai tìm lại được nó — hỏng đúng thứ lát này làm ra.
const String kTaskId = 'gemma-4-E2B';

/// Tin tiến độ từ một `TaskProgressUpdate`, hoặc `null` khi con số **không
/// phải tiến độ**.
///
/// ⚠️ Gói dùng **giá trị âm làm mã trạng thái** trong chính trường tiến độ:
/// −1 hỏng · −2 huỷ · −3 không thấy · −4 chờ thử lại · −5 tạm dừng. Đo trên
/// Realme RMX2205 2026-09-22: bản đầu đưa thẳng lên màn thành *"Đang tải…
/// −400%"* / *"−9,64 GB / 2,41 GB"*. Trạng thái đã có `TaskStatusUpdate` lo,
/// nên tin tiến độ âm thì **bỏ**.
TinLuot? tinTuTienDo(double progress) {
  if (progress < 0) return null;
  return (trangThai: TrangThaiLuot.dangChay, phanTram: progress, loi: null);
}

/// `null` = trạng thái không đáng phát lên giao diện.
///
/// ⚠️ `canceled` chỉ là **huỷ** khi chính người dùng bấm Huỷ ([huyDoNguoiDung]).
/// Đo trên Realme 2026-09-22: tắt Wi-Fi giữa lượt thì WorkManager dừng worker
/// vì ràng buộc và gói báo `canceled`, rồi **tự xếp lại** và chạy tiếp khi
/// Wi-Fi về — dịch mù thành huỷ là màn nói "Chưa tải mô hình" cho một lượt
/// vẫn đang xếp hàng. Khi ấy đúng nghĩa là **chờ** (`dangCho`).
///
/// ⚠️ `enqueued` → `dangCho` chứ không `dangChay`: khi `requiresWiFi` bật mà
/// máy chỉ có 4G, lượt **nằm ở `enqueued` vô thời hạn** và không có lỗi nào
/// được phát — đó chính là "chờ Wi-Fi" mà màn phải nói ra. Nhưng
/// `waitingToRetry` thì **không** phải dangCho: đó là lỗi mạng đang được thử
/// lại (máy vẫn ở Wi-Fi), nói "Đang chờ Wi-Fi" là chỉ sai nguyên nhân — giữ
/// `dangChay` với tiến độ cuối, hết ba lần thử thì gói phát `failed`.
TrangThaiLuot? dichTrangThai(TaskStatus s, {bool huyDoNguoiDung = false}) =>
    switch (s) {
      TaskStatus.enqueued => TrangThaiLuot.dangCho,
      TaskStatus.running || TaskStatus.waitingToRetry => TrangThaiLuot.dangChay,
      TaskStatus.paused => TrangThaiLuot.tamDung,
      TaskStatus.complete => TrangThaiLuot.xong,
      TaskStatus.canceled =>
        huyDoNguoiDung ? TrangThaiLuot.huy : TrangThaiLuot.dangCho,
      TaskStatus.failed || TaskStatus.notFound => TrangThaiLuot.hong,
    };

class BackgroundDownloaderTaiNen implements NguonTaiNen {
  final _phat = StreamController<TinLuot>.broadcast();
  final _tai = FileDownloader();

  StreamSubscription<TaskUpdate>? _nghe;
  double _phanTramCuoi = 0;

  /// Đặt trong [huy] và xoá khi bắt đầu/tiếp tục — xem `dichTrangThai`.
  bool _huyDoNguoiDung = false;

  BackgroundDownloaderTaiNen() {
    _nghe = _tai.updates.listen(_nhan);
  }

  /// Phải gọi MỘT lần lúc dựng DI, trước khi màn nào hỏi [luotDangSong].
  ///
  /// `trackTasks()` bật CSDL theo dõi của gói (không có nó thì `recordForId`
  /// luôn `null`); `resumeFromBackground()` kéo về những cập nhật đã xảy ra
  /// khi app không chạy. Thông báo hệ thống có Tạm dừng / Huỷ (gói tự vẽ nút
  /// khi `allowPause`), tiến độ dạng thanh.
  Future<void> chuanBi() async {
    await _tai.trackTasks();
    await _tai.resumeFromBackground();
    _tai.configureNotification(
      running: const TaskNotification('Đang tải mô hình AI', '{progress}'),
      complete: const TaskNotification('Đã tải xong mô hình AI', ''),
      paused: const TaskNotification('Tạm dừng tải mô hình AI', '{progress}'),
      error: const TaskNotification('Tải mô hình AI hỏng', ''),
      progressBar: true,
    );
  }

  @override
  Stream<TinLuot> get tin => _phat.stream;

  @override
  Future<void> batDau({
    required String url,
    required String tenTep,
    required bool chiWifi,
  }) async {
    _huyDoNguoiDung = false;
    final ok = await _tai.enqueue(DownloadTask(
      taskId: kTaskId,
      url: url,
      filename: tenTep,
      baseDirectory: BaseDirectory.applicationSupport,
      updates: Updates.statusAndProgress,
      requiresWiFi: chiWifi,
      allowPause: true,
      retries: 3,
    ));
    // Cùng `taskId` đang sống thì gói từ chối — đó là chốt "không hai lượt ghi
    // vào cùng một tệp". Chỉ ghi log; màn đã hiện lượt đang chạy.
    if (!ok) debugPrint('[SLM] enqueue bị từ chối — lượt $kTaskId đang sống?');
  }

  @override
  Future<TinLuot?> luotDangSong() async {
    final t = await _tai.taskForId(kTaskId);
    if (t == null) return null;
    final ghi = await _tai.database.recordForId(kTaskId);
    if (ghi == null) return null;
    // Bản ghi `canceled` ở đây là của WorkManager (dừng vì ràng buộc, đã xếp
    // lại): người dùng huỷ thì [huy] đã xoá bản ghi nên không tới được đây.
    final tt = dichTrangThai(ghi.status);
    if (tt == null) return null;
    // Bản ghi cũng mang tiến độ âm làm mã (xem `tinTuTienDo`).
    return (
      trangThai: tt,
      phanTram: ghi.progress < 0 ? 0.0 : ghi.progress,
      loi: null,
    );
  }

  @override
  Future<void> tamDung() async {
    final t = await _tai.taskForId(kTaskId);
    if (t is DownloadTask) await _tai.pause(t);
  }

  @override
  Future<void> tiepTuc() async {
    _huyDoNguoiDung = false;
    final t = await _tai.taskForId(kTaskId);
    if (t is! DownloadTask) return;
    // `resume` nối lại từ chỗ đứt (tạm dừng, hoặc hỏng mà server có `Range`).
    // Nó trả `false` khi không nối được — khi ấy xếp lại lượt mới cùng `taskId`
    // chứ không để nút Thử lại chết.
    if (await _tai.resume(t)) return;
    await _tai.enqueue(t);
  }

  @override
  Future<void> huy() async {
    _huyDoNguoiDung = true;
    await _tai.cancelTaskWithId(kTaskId);
    // Xoá bản ghi để `luotDangSong()` ở lần chạy sau không đọc `canceled`
    // thành "chờ ràng buộc" — lượt huỷ tay là trạng thái cuối, không sống.
    await _tai.database.deleteRecordWithId(kTaskId);
  }

  void _nhan(TaskUpdate u) {
    if (u.task.taskId != kTaskId) return;
    if (u is TaskProgressUpdate) {
      final tin = tinTuTienDo(u.progress);
      if (tin == null) return;
      _phanTramCuoi = tin.phanTram;
      _phat.add(tin);
      return;
    }
    if (u is TaskStatusUpdate) {
      final tt = dichTrangThai(u.status, huyDoNguoiDung: _huyDoNguoiDung);
      if (tt == null) return;
      debugPrint('[SLM] tải: ${u.status.name} → ${tt.name} '
          '(${(_phanTramCuoi * 100).round()}%)');
      _phat.add((
        trangThai: tt,
        phanTram: tt == TrangThaiLuot.xong ? 1 : _phanTramCuoi,
        loi: u.exception?.description,
      ));
    }
  }

  Future<void> dong() async {
    await _nghe?.cancel();
    await _phat.close();
  }
}
