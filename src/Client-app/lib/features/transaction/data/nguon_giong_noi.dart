/// C4 — mọi phụ thuộc của phần giọng nói gom một chỗ, tiêm được (DI đăng ký bản thật; widget test tiêm bản giả). Màn Thêm
/// giao dịch không có [NguonGiongNoi] (chưa đăng ký) thì không hiện micro.
library;

import 'dart:typed_data';

import 'chep_loi_bang_gemma.dart';
import 'datasources/ghi_am.dart';
import 'datasources/kenh_micro.dart';
import 'datasources/nghe_android.dart';

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
