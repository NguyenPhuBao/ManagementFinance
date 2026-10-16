/// Vòng đời của một phiên mô hình chỉ cần **lời gọi tool đầu tiên**: nạp mô hình một lần, mở phiên, lấy lời gọi, đóng
/// phiên. Dùng chung cho ô *Nhập nhanh* (C2, `DocCauBangAi`) và lệnh tạo ở màn Trợ lý (C3 §8.2, `DocLenhBangAi`) — hai
/// chỗ ấy chỉ khác lời hệ thống và khai báo tool.
///
/// Mọi hỏng hóc (chưa sẵn sàng, nạp lỗi, máy từng sập ở phiên có tool, quá hạn, đã huỷ, mô hình không gọi tool đích)
/// đều trả `null`: người gọi dùng đường luật, không báo lỗi to.
///
/// Đi qua [SlmRuntime] — chỉ `slm_runtime.dart` được import `flutter_gemma` (test quét 16).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/canary_cong_cu.dart';
import '../domain/cong_cu.dart';
import 'phien_cong_cu.dart';
import 'slm_runtime.dart';

class PhienMotLoiGoi {
  PhienMotLoiGoi({
    required this.runtime,
    required this.sanSang,
    required this.duongTep,
    required this.thoiHan,
    required this.nhan,
  });

  final SlmRuntime runtime;

  /// Máy dùng được AI không — tệp mô hình đủ **và** công tắc AI bật (cùng hai điều kiện của màn Trợ lý AI).
  final Future<bool> Function() sanSang;
  final Future<String> Function() duongTep;

  /// Tính từ lúc mở phiên, không tính nạp mô hình.
  final Duration thoiHan;

  /// Tiền tố log, vd `[NhapNhanh][AI]`, `[SLM][lenh]`.
  final String nhan;

  Future<bool>? _nap;
  PhienCongCu? _phien;
  var _luot = 0;

  /// Nạp mô hình. MỘT `Future` dùng chung: gọi chồng nhau thì chờ chính nó. `false` = không dùng được AI; nạp lỗi thì
  /// lần sau thử lại. Mô hình bị nơi khác ĐÓNG sau một lần nạp thành công (màn Quét đóng sau khi đọc ảnh) → nạp lại.
  Future<bool> chuanBi() {
    final cu = _nap;
    if (cu != null && !runtime.dangSan) {
      // Đang nạp dở cũng có `dangSan == false` — chỉ bỏ Future đã XONG với kết quả `true`.
      return cu.then((ok) {
        if (!ok || runtime.dangSan) return ok;
        if (identical(_nap, cu)) _nap = null;
        return _napMoi();
      });
    }
    return _napMoi();
  }

  Future<bool> _napMoi() => _nap ??= () async {
        try {
          if (!await sanSang()) {
            _nap = null;
            return false;
          }
          if (!runtime.dangSan) await runtime.moHinhSan(await duongTep());
          return true;
        } catch (e) {
          debugPrint('$nhan nạp mô hình hỏng: $e');
          _nap = null;
          return false;
        }
      }();

  /// Lời gọi tool ĐẦU TIÊN thoả [laDich], hoặc `null`.
  Future<GoiCongCu?> goiDauTien({
    required String heThong,
    required String cauHoi,
    required List<KhaiBaoCongCu> congCu,
    required bool Function(GoiCongCu) laDich,
  }) async {
    final luot = ++_luot;
    if (!await chuanBi() || luot != _luot) return null;
    final dongHo = Stopwatch()..start();
    try {
      // Trần `maxTokens` là trần TỔNG (bẫy 4.39) — độ dài khai báo là con số buổi đo máy thật cần đọc từ logcat.
      debugPrint('$nhan tools_json ${toolsJsonCua(congCu).length} ký tự, ${congCu.length} tool');
      final phien = await runtime.moPhien(heThong: heThong, cauHoi: cauHoi, congCu: congCu);
      _phien = phien;
      try {
        if (luot != _luot) return null;
        final goi = await phien
            .sinhLuot()
            .where((e) => e is GoiCongCu && laDich(e))
            .cast<GoiCongCu>()
            .first
            .timeout(thoiHan);
        // Tham số mang dữ liệu người dùng (số tiền, ghi chú, danh mục) — bản release chỉ in thời gian + tên tool.
        debugPrint('$nhan ${dongHo.elapsedMilliseconds} ms: ${goi.ten}${kDebugMode ? ' ${goi.args}' : ''}');
        return luot == _luot ? goi : null;
      } finally {
        await phien.huy();
        await phien.dong();
        if (identical(_phien, phien)) _phien = null;
      }
    } on BacCongCuDaTat {
      debugPrint('$nhan máy từng sập native ở phiên có tool → luật');
      return null;
    } catch (e) {
      // Quá hạn (TimeoutException), mô hình không gọi tool (StateError: No element), lượt bị huỷ, engine lỗi.
      debugPrint('$nhan không đọc được sau ${dongHo.elapsedMilliseconds} ms: $e → luật');
      return null;
    }
  }

  /// Người dùng bấm Huỷ: lượt đang chạy trả `null`, engine thôi giải mã.
  Future<void> huy() async {
    _luot++;
    await _phien?.huy();
  }
}
