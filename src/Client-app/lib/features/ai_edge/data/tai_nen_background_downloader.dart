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

class BackgroundDownloaderTaiNen implements NguonTaiNen {
  final _phat = StreamController<TinLuot>.broadcast();
  final _tai = FileDownloader();

  StreamSubscription<TaskUpdate>? _nghe;
  double _phanTramCuoi = 0;

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
    final tt = _dich(ghi.status);
    // Lượt ĐÃ HUỶ là trạng thái cuối, không phải "đang sống": trả nó về là
    // `khoiPhuc()` phát một tin thừa và `tiepTuc()` đi tìm một lượt để nối
    // thay vì bắt đầu lượt mới. Lượt hỏng thì GIỮ — nó nối lại được.
    if (tt == null || tt == TrangThaiLuot.huy) return null;
    return (trangThai: tt, phanTram: ghi.progress, loi: null);
  }

  @override
  Future<void> tamDung() async {
    final t = await _tai.taskForId(kTaskId);
    if (t is DownloadTask) await _tai.pause(t);
  }

  @override
  Future<void> tiepTuc() async {
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
    await _tai.cancelTaskWithId(kTaskId);
  }

  void _nhan(TaskUpdate u) {
    if (u.task.taskId != kTaskId) return;
    if (u is TaskProgressUpdate) {
      _phanTramCuoi = u.progress;
      _phat.add((
        trangThai: TrangThaiLuot.dangChay,
        phanTram: u.progress,
        loi: null,
      ));
      return;
    }
    if (u is TaskStatusUpdate) {
      final tt = _dich(u.status);
      if (tt == null) return;
      _phat.add((
        trangThai: tt,
        phanTram: tt == TrangThaiLuot.xong ? 1 : _phanTramCuoi,
        loi: u.exception?.description,
      ));
    }
  }

  /// ⚠️ `enqueued` dịch thành `dangCho` chứ không `dangChay`: khi `requiresWiFi`
  /// bật mà máy chỉ có 4G, lượt **nằm ở `enqueued` vô thời hạn** và không có
  /// lỗi nào được phát. Đó chính là trạng thái "chờ Wi-Fi" mà màn phải nói ra.
  TrangThaiLuot? _dich(TaskStatus s) => switch (s) {
        TaskStatus.enqueued || TaskStatus.waitingToRetry =>
          TrangThaiLuot.dangCho,
        TaskStatus.running => TrangThaiLuot.dangChay,
        TaskStatus.paused => TrangThaiLuot.tamDung,
        TaskStatus.complete => TrangThaiLuot.xong,
        TaskStatus.canceled => TrangThaiLuot.huy,
        TaskStatus.failed || TaskStatus.notFound => TrangThaiLuot.hong,
      };

  Future<void> dong() async {
    await _nghe?.cancel();
    await _phat.close();
  }
}
