/// Lớp giả `FlutterSecureStorage` dùng chung cho test công tắc / cờ lưu ở kho bảo mật (khuôn `CongTacAi`).
/// `KhoGia([ban])`: `ban` là nội dung kho; `hong = true` thì `read` / `write` ném (kiểm "nuốt lỗi");
/// `write(value: null)` xoá khoá như kho thật; phần còn lại qua `noSuchMethod`.
/// Nơi dùng: `ai_chat/data/cong_tac_online_test.dart`; (Task 9 và 11 của kế hoạch Trợ lý online dùng lại).
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KhoGia implements FlutterSecureStorage {
  KhoGia([Map<String, String>? ban]) : ban = ban ?? {};
  final Map<String, String> ban;
  bool hong = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (hong) throw Exception('kho hỏng');
    return ban[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (hong) throw Exception('kho hỏng');
    if (value == null) {
      ban.remove(key);
    } else {
      ban[key] = value;
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
