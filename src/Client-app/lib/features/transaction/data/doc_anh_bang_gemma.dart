/// A5 mục 13 — ảnh QUÉT hoá đơn: Gemma 4 E2B NHÌN ẢNH, đọc món + tổng (người dùng chốt 2026-10-08: AI đọc món và tổng,
/// luật đọc phần còn lại). Thay `DocAnhBangAi` cũ (mô hình đọc CHỮ OCR — chữ OCR sai thì AI sai theo).
///
/// Đây CHỈ là chỗ gọi mô hình. Kết quả thô; số tổng được chốt với số luật ở `chotTongQuet`. Mọi hỏng hóc (chưa sẵn
/// sàng, nạp lỗi, quá hạn, đã huỷ, chữ không phải JSON) trả `null`: màn dùng kết quả luật. Điều kiện Premium nằm ở màn
/// `/quet`, không ở đây.
///
/// ⚠️ Chỉ `slm_runtime.dart` được import `flutter_gemma` (test quét 16) — tệp này đi qua [SlmDocAnh].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../ai_edge/data/slm_runtime.dart';
import '../domain/doc_anh_gemma.dart';

/// Đo Realme 2026-10-08 (CPU, Mali): 21–42 s một ảnh; GPU OnePlus 3,7–11 s. Trần rộng gấp đôi lượt chậm nhất đã đo.
const Duration kThoiHanDocAnhGemma = Duration(seconds: 90);

class DocAnhBangGemma {
  DocAnhBangGemma({
    required this.moHinh,
    required this.sanSang,
    required this.duongTep,
    this.thoiHan = kThoiHanDocAnhGemma,
  });

  final SlmDocAnh moHinh;

  /// Máy dùng được AI không — tệp mô hình đủ **và** công tắc AI bật.
  final Future<bool> Function() sanSang;
  final Future<String> Function() duongTep;
  final Duration thoiHan;

  var _luot = 0;

  /// Tổng + món mô hình đọc từ [anh], hoặc `null` (màn dùng luật).
  Future<KetQuaGemmaAnh?> doc(Uint8List anh) async {
    final luot = ++_luot;
    final dongHo = Stopwatch()..start();
    try {
      if (!await sanSang() || luot != _luot) return null;
      final tho = await moHinh.docAnh(await duongTep(), kPromptMonTong, anh).timeout(thoiHan, onTimeout: () async {
        await moHinh.huy();
        throw TimeoutException('đọc ảnh quá ${thoiHan.inSeconds} s');
      });
      if (luot != _luot) return null;
      final kq = docJsonGemmaAnh(tho);
      // Tổng tiền hoá đơn chỉ in ở bản debug (cùng luật `[Quet][OCR]`).
      debugPrint('[Quet][Gemma] ${dongHo.elapsedMilliseconds} ms:${kDebugMode ? ' tong=${kq?.tong} ·' : ''}'
          ' ${kq?.mon.length ?? 0} món'
          '${kq == null ? ' · chữ không phải JSON' : ''}');
      return kq;
    } catch (e) {
      debugPrint('[Quet][Gemma] không đọc được sau ${dongHo.elapsedMilliseconds} ms: $e → luật');
      return null;
    }
  }

  /// Người dùng bấm Huỷ: lượt đang chạy trả `null`, engine thôi giải mã.
  Future<void> huy() async {
    _luot++;
    await moHinh.huy();
  }
}
