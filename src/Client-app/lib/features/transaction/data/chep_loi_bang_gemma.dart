// lib/features/transaction/data/chep_loi_bang_gemma.dart
/// C4 — chép lời bằng Gemma 4 E2B trên máy (lối mất mạng, spec 2026-10-12 §3.5). Đây CHỈ là chỗ gọi mô hình; câu đi tiếp
/// đường Nhập nhanh như câu gõ. Mọi hỏng hóc trả `null`. Không in nội dung lời nói vào log (lời người dùng).
///
/// ⚠️ Chỉ `slm_runtime.dart` được import `flutter_gemma` (test quét 16) — tệp này đi qua [SlmChepLoi].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../ai_edge/data/slm_runtime.dart';
import '../domain/chep_loi.dart';

/// Spike C4 (Realme CPU, giọng tổng hợp 2,8 s): chép lời 9,8 s. Trần 60 s tính CẢ pha đóng + nạp bản hai cờ (CPU nạp bản chữ ≈ 27 s, bản hai cờ chưa đo) — con số phải đo trên máy.
const Duration kThoiHanChepLoi = Duration(seconds: 60);

class ChepLoiBangGemma {
  ChepLoiBangGemma({
    required this.moHinh,
    required this.sanSang,
    required this.duongTep,
    this.thoiHan = kThoiHanChepLoi,
  });

  final SlmChepLoi moHinh;

  /// Máy dùng được AI không — tệp mô hình đủ **và** công tắc AI bật (cùng điều kiện ô Nhập nhanh).
  final Future<bool> Function() sanSang;
  final Future<String> Function() duongTep;
  final Duration thoiHan;

  /// Tăng mỗi lần [huy] — lượt chụp giá trị này lúc vào; khác nhau nghĩa là lượt đã bị huỷ (kể cả khi còn xếp hàng).
  var _doiHuy = 0;

  /// Mô hình là MỘT (singleton) nên mọi lượt chép — dù từ Cubit nào — xếp hàng ở đây, không chồng lên nhau.
  Future<void> _hangDoi = Future<void>.value();

  Future<bool> sanSangChua() async {
    try {
      return await sanSang();
    } catch (_) {
      return false;
    }
  }

  /// Câu chép từ [wav], hoặc `null`. Chờ lượt đang chạy xong rồi mới gọi mô hình; bị [huy] trong lúc xếp hàng thì trả
  /// `null` mà KHÔNG gọi mô hình. [thoiHan] chỉ bao lời gọi mô hình, không bao thời gian xếp hàng.
  Future<String?> chep(Uint8List wav) async {
    final doi = _doiHuy;
    final truoc = _hangDoi;
    final xong = Completer<void>();
    _hangDoi = xong.future;
    final dongHo = Stopwatch()..start();
    try {
      await truoc;
      if (doi != _doiHuy) return null;
      if (!await sanSang() || doi != _doiHuy) return null;
      final tho = await moHinh.chepLoi(await duongTep(), kPromptChepLoi, wav).timeout(thoiHan, onTimeout: () async {
        await moHinh.huy();
        throw TimeoutException('chép lời quá ${thoiHan.inSeconds} s');
      });
      if (doi != _doiHuy) return null;
      final cau = lamSachLoiChep(tho);
      debugPrint('[GiongNoi][Gemma] ${dongHo.elapsedMilliseconds} ms → ${cau.length} ký tự');
      return cau.isEmpty ? null : cau;
    } catch (e) {
      debugPrint('[GiongNoi][Gemma] không chép được sau ${dongHo.elapsedMilliseconds} ms: $e');
      return null;
    } finally {
      xong.complete();
    }
  }

  /// Người dùng bấm Huỷ: lượt đang chạy trả `null`; engine thôi giải mã, hoặc — nếu đang nạp mô hình — lượt ấy bị bỏ
  /// ngay khi nạp xong (không tạo chat).
  Future<void> huy() async {
    _doiHuy++;
    await moHinh.huy();
  }
}
