// lib/features/ai_chat/data/cong_tac_online.dart
/// Công tắc **"Trợ lý online"** và cờ **đã đọc tờ thông tin** — spec trợ lý online
/// 2026-10-11 §3.5. Khuôn `CongTacAi` (`ai_edge/data/cong_tac_ai.dart`): kho
/// `flutter_secure_storage`, **một khoá cho cả máy** (người dùng chốt, câu 9),
/// mọi thao tác nuốt lỗi — mất cờ chỉ đưa về mặc định.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String kKhoaOnlineBat = 'ai_online_bat';
const String kKhoaOnlineDaDocTo = 'ai_online_da_doc_to';

class CongTacOnline {
  const CongTacOnline([this._kho = const FlutterSecureStorage()]);
  final FlutterSecureStorage _kho;

  /// Mặc định **bật**: "có mạng thì dùng backend" là hành vi mặc định người dùng chọn.
  Future<bool> docBat() => _doc(kKhoaOnlineBat, macDinh: true);
  Future<void> ghiBat(bool bat) => _ghi(kKhoaOnlineBat, bat);

  /// Mặc định **chưa**: tờ hiện trước câu online đầu tiên của máy.
  Future<bool> daDocTo() => _doc(kKhoaOnlineDaDocTo, macDinh: false);
  Future<void> ghiDaDocTo() => _ghi(kKhoaOnlineDaDocTo, true);

  Future<bool> _doc(String khoa, {required bool macDinh}) async {
    try {
      final raw = await _kho.read(key: khoa);
      if (raw == null || raw.isEmpty) return macDinh;
      return raw == 'true';
    } catch (_) {
      return macDinh;
    }
  }

  Future<void> _ghi(String khoa, bool v) async {
    try {
      await _kho.write(key: khoa, value: v ? 'true' : 'false');
    } catch (_) {
      // Xem chú thích đầu lớp.
    }
  }
}
