/// C4 — mọi phụ thuộc của phần giọng nói gom một chỗ, tiêm được (DI đăng ký bản thật; widget test tiêm bản giả). Màn Thêm
/// giao dịch không có [NguonGiongNoi] (chưa đăng ký) thì không hiện micro.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/do_im_lang.dart';
import 'chep_loi_bang_gemma.dart';
import 'datasources/ghi_am.dart';
import 'datasources/kenh_micro.dart';
import 'datasources/nghe_android.dart';

const String _tienToTep = 'giong_noi_';
const String _duoiTep = '.wav';

/// Đường dẫn MỚI cho một WAV tạm trong [thuMuc] — cùng định nghĩa tiền tố / đuôi với [donTepGiongNoiSot].
String tepGiongNoiMoi(String thuMuc) => '$thuMuc/$_tienToTep${DateTime.now().millisecondsSinceEpoch}$_duoiTep';

/// Xoá các WAV giọng nói sót trong [thuMuc] (tiến trình bị giết giữa lượt ghi để lại giọng người dùng — spec §2.4: không
/// lưu âm thanh). Chỉ tệp `giong_noi_*.wav` **cũ hơn** [kNgheToiDa] + [kThoiHanChepLoi] (một lượt ghi + chép dài nhất):
/// hai trang `/add` cùng sống thì WAV đang ghi của trang kia còn mới, không bị xoá (review toàn nhánh, M2). Không bao giờ ném.
Future<void> donTepGiongNoiSot(Directory thuMuc) async {
  try {
    for (final f in thuMuc.listSync()) {
      if (f is! File) continue;
      final ten = f.uri.pathSegments.last;
      if (!ten.startsWith(_tienToTep) || !ten.endsWith(_duoiTep)) continue;
      try {
        if (DateTime.now().difference(f.lastModifiedSync()) < kNgheToiDa + kThoiHanChepLoi) continue;
        await f.delete();
      } catch (e) {
        debugPrint('[GiongNoi] không xoá được tệp sót: $e');
      }
    }
  } catch (e) {
    debugPrint('[GiongNoi] dọn tệp sót lỗi: $e');
  }
}

class NguonGiongNoi {
  const NguonGiongNoi({
    required this.android,
    required this.ghiAm,
    required this.micro,
    required this.coMang,
    required this.tepTam,
    required this.docTep,
    required this.xoaTep,
    this.gemma,
  });

  final NgheAndroid android;
  final GhiAm ghiAm;
  final KenhMicro micro;
  final Future<bool> Function() coMang;

  /// `null` = máy không có đường Gemma (không đăng ký) — lối Gemma coi như không sẵn sàng.
  final ChepLoiBangGemma? gemma;

  /// Đường dẫn MỚI cho một tệp WAV tạm.
  final Future<String> Function() tepTam;
  final Future<Uint8List> Function(String duongTep) docTep;

  /// Không bao giờ ném.
  final Future<void> Function(String duongTep) xoaTep;
}
