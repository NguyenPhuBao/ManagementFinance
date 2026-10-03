/// Nhắc ghi — mốc "đã xét đến" theo TÀI KHOẢN (spec §4.4): máy dùng chung là chuyện thật trong dự án này, một mốc chung
/// nghĩa là tài khoản sau thừa hưởng (hoặc bị chặn bởi) mốc của tài khoản trước.
library;

import 'package:flowmoney/core/notification/moc_phien_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (ten, dung) in <(String, MocPhienStore Function())>[
    ('SecureStorage', () {
      FlutterSecureStorage.setMockInitialValues({});
      return const SecureStorageMocPhienStore(FlutterSecureStorage());
    }),
    ('InMemory', InMemoryMocPhienStore.new),
  ]) {
    group(ten, () {
      late MocPhienStore store;
      setUp(() => store = dung());

      test('chưa có → null', () async {
        expect(await store.doc(7), isNull);
      });

      test('⭐ ghi rồi đọc; khác tài khoản là khác; ghi đè', () async {
        await store.ghi(7, DateTime(2026, 10, 3, 11, 20, 35));
        expect(await store.doc(7), DateTime(2026, 10, 3, 11, 20, 35));
        expect(await store.doc(9), isNull);
        await store.ghi(7, DateTime(2026, 10, 3, 12));
        expect(await store.doc(7), DateTime(2026, 10, 3, 12));
      });
    });
  }

  test('SecureStorage: giá trị hỏng → null, không ném', () async {
    FlutterSecureStorage.setMockInitialValues({'nhac_phien:7': 'rác'});
    const store = SecureStorageMocPhienStore(FlutterSecureStorage());
    expect(await store.doc(7), isNull);
  });
}
