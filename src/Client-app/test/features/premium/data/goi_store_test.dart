/// Kho trạng thái gói theo tài khoản (spec Premium 6.1) — khuôn
/// `SecureStorageNotificationPrefsStore`: một khoá mỗi tài khoản, mọi thao tác
/// nuốt lỗi, rác → `null`.
library;

import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 6, 3);
  final premium = TrangThaiGoi(
      loai: LoaiGoi.premium, hetHan: DateTime.utc(2026, 11, 5), nhanLuc: now);

  group('SecureStorageGoiStore', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('ghi rồi đọc theo tài khoản; hai tài khoản không đè nhau', () async {
      const kho = SecureStorageGoiStore(FlutterSecureStorage());
      await kho.ghi(10, premium);
      await kho.ghi(11, TrangThaiGoi.basicMacDinh(now));
      expect((await kho.doc(10))!.laPremium(now), isTrue);
      expect((await kho.doc(11))!.laPremium(now), isFalse);
      expect(await kho.doc(12), isNull);
    });

    test('khoá có mã tài khoản',
        () => expect(SecureStorageGoiStore.khoa(10), 'goi_tai_khoan_10'));

    test('giá trị rác → null, không ném', () async {
      FlutterSecureStorage.setMockInitialValues({'goi_tai_khoan_10': '{rac'});
      const kho = SecureStorageGoiStore(FlutterSecureStorage());
      expect(await kho.doc(10), isNull);
    });

    test('xoa', () async {
      const kho = SecureStorageGoiStore(FlutterSecureStorage());
      await kho.ghi(10, premium);
      await kho.xoa(10);
      expect(await kho.doc(10), isNull);
    });
  });

  test('InMemoryGoiStore cùng hợp đồng', () async {
    final kho = InMemoryGoiStore();
    expect(await kho.doc(10), isNull);
    await kho.ghi(10, premium);
    expect((await kho.doc(10))!.loai, LoaiGoi.premium);
    await kho.xoa(10);
    expect(await kho.doc(10), isNull);
  });
}
