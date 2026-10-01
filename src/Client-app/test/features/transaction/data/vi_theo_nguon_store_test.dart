/// D1 Task 7 — ví chọn sẵn theo nguồn + đuôi tài khoản của tin biến động số dư (spec D1 §3.3): khoá
/// `bien_dong_vi:<idaccount>` trong `flutter_secure_storage`, cùng khuôn kho tuỳ chọn thông báo.
///
/// Điều đáng canh nhất là **tách theo tài khoản**: máy dùng chung là chuyện thật trong dự án này, và một
/// bảng chung nghĩa là người đăng nhập sau nhận ví chọn sẵn là một `walletId` của người trước.
library;

import 'package:flowmoney/features/transaction/data/vi_theo_nguon_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (ten, dung) in <(String, ViTheoNguonStore Function())>[
    ('SecureStorage', () {
      FlutterSecureStorage.setMockInitialValues({});
      return const SecureStorageViTheoNguonStore(FlutterSecureStorage());
    }),
    ('InMemory', InMemoryViTheoNguonStore.new),
  ]) {
    group(ten, () {
      late ViTheoNguonStore store;
      setUp(() => store = dung());

      test('chưa lưu → null (ví giữ luật chọn sẵn thường)', () async {
        expect(await store.doc(7, 'MB Bank', '7777'), isNull);
      });

      test('⭐ ghi rồi đọc theo CẶP nguồn + đuôi; khác đuôi / khác nguồn / khác tài khoản là khác', () async {
        await store.ghi(7, 'MB Bank', '7777', 'w-mb');
        await store.ghi(7, 'MoMo', null, 'w-momo');
        expect(await store.doc(7, 'MB Bank', '7777'), 'w-mb');
        expect(await store.doc(7, 'MoMo', null), 'w-momo', reason: 'tin ví điện tử không mang đuôi TK');
        expect(await store.doc(7, 'MB Bank', '1234'), isNull, reason: 'hai tài khoản MB là hai ví');
        expect(await store.doc(7, 'Techcombank', '7777'), isNull);
        expect(await store.doc(9, 'MB Bank', '7777'), isNull,
            reason: 'máy dùng chung — tài khoản sau không được nhận walletId của tài khoản trước');
      });

      test('ghi đè cùng cặp', () async {
        await store.ghi(7, 'MB Bank', '7777', 'w-cu');
        await store.ghi(7, 'MB Bank', '7777', 'w-moi');
        expect(await store.doc(7, 'MB Bank', '7777'), 'w-moi');
      });
    });
  }

  test('SecureStorage: JSON hỏng → null, không ném', () async {
    FlutterSecureStorage.setMockInitialValues({'bien_dong_vi:7': '{rác'});
    const store = SecureStorageViTheoNguonStore(FlutterSecureStorage());
    expect(await store.doc(7, 'MB Bank', '7777'), isNull);
    await store.ghi(7, 'MB Bank', '7777', 'w');
    expect(await store.doc(7, 'MB Bank', '7777'), 'w');
  });
}
