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

  var _luot = 0;

  Future<bool> sanSangChua() async {
    try {
      return await sanSang();
    } catch (_) {
      return false;
    }
  }

  /// Câu chép từ [wav], hoặc `null`.
  Future<String?> chep(Uint8List wav) async {
    final luot = ++_luot;
    final dongHo = Stopwatch()..start();
    try {
      if (!await sanSang() || luot != _luot) return null;
      final tho = await moHinh.chepLoi(await duongTep(), kPromptChepLoi, wav).timeout(thoiHan, onTimeout: () async {
        await moHinh.huy();
        throw TimeoutException('chép lời quá ${thoiHan.inSeconds} s');
      });
      if (luot != _luot) return null;
      final cau = lamSachLoiChep(tho);
      debugPrint('[GiongNoi][Gemma] ${dongHo.elapsedMilliseconds} ms → ${cau.length} ký tự');
      return cau.isEmpty ? null : cau;
    } catch (e) {
      debugPrint('[GiongNoi][Gemma] không chép được sau ${dongHo.elapsedMilliseconds} ms: $e');
      return null;
    }
  }

  /// Người dùng bấm Huỷ: lượt đang chạy trả `null`; engine thôi giải mã, hoặc — nếu đang nạp mô hình — lượt ấy bị bỏ
  /// ngay khi nạp xong (không tạo chat).
  Future<void> huy() async {
    _luot++;
    await moHinh.huy();
  }
}
