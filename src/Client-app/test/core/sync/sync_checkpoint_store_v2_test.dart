import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/sync/sync_checkpoint_store.dart';

/// G67 — mốc lưu bằng khoá mới để mỗi máy kéo lại toàn bộ đúng một lần.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('⭐ mốc lưu bằng khoá CŨ (giờ ghi của máy) không còn được đọc', () async {
    FlutterSecureStorage.setMockInitialValues({
      'sync_last_pull_7': '2026-10-05T07:44:27.000Z',
    });
    const store = SecureStorageSyncCheckpointStore(FlutterSecureStorage());

    expect(await store.read(7), isNull,
        reason: 'Những hàng G67 từng bỏ sót mang giờ-server cũ, nằm dưới mốc cũ. '
            'Đọc lại mốc cũ là chúng không bao giờ về; null → since = 1970, kéo '
            'toàn bộ một lần.');
  });

  test('ghi rồi đọc lại bằng khoá mới; lần sau không ép kéo toàn bộ nữa', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureStorageSyncCheckpointStore(FlutterSecureStorage());

    await store.write(7, DateTime.utc(2026, 10, 8, 7, 45));

    expect(await store.read(7), DateTime.utc(2026, 10, 8, 7, 45));
    expect(await store.read(8), isNull, reason: 'Mốc theo từng tài khoản.');
  });

  test('clear dọn cả khoá mới lẫn khoá cũ', () async {
    FlutterSecureStorage.setMockInitialValues({
      'sync_last_pull_7': '2026-10-05T07:44:27.000Z',
    });
    const storage = FlutterSecureStorage();
    const store = SecureStorageSyncCheckpointStore(storage);
    await store.write(7, DateTime.utc(2026, 10, 8));

    await store.clear(7);

    expect(await storage.readAll(), isEmpty);
  });
}
