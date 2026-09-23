// lib/features/ai_edge/domain/canary_gpu.dart
/// Dấu canary cho lượt nạp mô hình bằng GPU.
///
/// Đo trên Realme RMX2205 (Dimensity 1100, Mali-G77) 2026-09-22: nạp với
/// `preferredBackend: gpu` làm app **sập native** — SIGSEGV null-pointer trong
/// `libLiteRtOpenClAccelerator.so` lúc `ModifyGraphWithDelegate`. Bậc thang
/// "GPU hỏng → CPU" của P1 chỉ bắt được **exception** (`try/catch` quanh
/// `getActiveModel`); crash native giết tiến trình trước khi Dart kịp bắt, nên
/// máy ấy không bao giờ tới nhánh CPU: mỗi lần hỏi là một lần văng về màn chính.
///
/// Cách chữa là cách của mọi trình duyệt với plugin hay sập: ghi một dấu
/// **trước** khi thử, xoá khi xong. Mở app lại mà dấu còn đó nghĩa là lần trước
/// chết giữa chừng → ghi nhớ "GPU hỏng" (tệp thứ hai, vĩnh viễn) và dùng CPU.
/// Hai tệp cục bộ, không schema, không đồng bộ — chúng là tài sản của *máy*.
library;

import 'dart:io';

/// Có mặt = một lượt thử GPU đang chạy (hoặc đã chết giữa chừng).
const String kTepCanaryGpu = 'slm_gpu_dang_thu';

/// Có mặt = GPU máy này đã làm app sập một lần; từ đó dùng CPU.
const String kTepGpuHong = 'slm_gpu_hong';

class CanaryGpu {
  final Future<Directory> Function() thuMuc;
  const CanaryGpu({required this.thuMuc});

  Future<File> _canary() async =>
      File('${(await thuMuc()).path}/$kTepCanaryGpu');
  Future<File> _hong() async => File('${(await thuMuc()).path}/$kTepGpuHong');

  /// Hỏi TRƯỚC khi nạp. `true` = dùng CPU. Dấu canary còn sót từ lần trước
  /// được đổi thành dấu "hỏng" ngay tại đây, để câu trả lời là vĩnh viễn.
  Future<bool> nenDungCpu() async {
    final hong = await _hong();
    if (hong.existsSync()) return true;
    final canary = await _canary();
    if (canary.existsSync()) {
      hong.createSync();
      try {
        canary.deleteSync();
      } catch (_) {}
      return true;
    }
    return false;
  }

  /// Ghi dấu ngay trước khi gọi engine với GPU. Đã biết GPU hỏng thì không
  /// ghi — chạy CPU mà để dấu lại là lần sau đọc nhầm "CPU cũng sập".
  Future<void> batDauThu() async {
    if ((await _hong()).existsSync()) return;
    (await _canary()).createSync();
  }

  /// Nạp xong (hoặc ném exception thường): dọn dấu. Chỉ crash native mới
  /// để dấu lại — đó đúng là thứ cần bắt.
  Future<void> thuXong() async {
    final c = await _canary();
    if (c.existsSync()) {
      try {
        c.deleteSync();
      } catch (_) {}
    }
  }
}
