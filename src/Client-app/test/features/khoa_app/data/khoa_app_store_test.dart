import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flowmoney/features/khoa_app/data/models/cau_hinh_khoa_app.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bản giả tối thiểu: `delete` của một khoá ném lỗi.
class _KhoGiaHongMotKhoa implements FlutterSecureStorage {
  _KhoGiaHongMotKhoa(this.du, this.khoaHong);
  final Map<String, String> du;
  final String khoaHong;

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      Map.of(du);

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (key == khoaHong) throw StateError('xoá hỏng');
    du.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cauHinh = CauHinhKhoaApp(salt: 'c2FsdA==', bam: 'YmFt', soVong: 30000);

  setUp(() => FlutterSecureStorage.setMockInitialValues({'access_token': 'tk'}));

  test('ghi rồi đọc theo khoá khoa_app_<id>', () async {
    const kho = SecureStorageKhoaAppStore(FlutterSecureStorage());
    await kho.ghi(10, cauHinh);
    expect((await kho.doc(10))!.bam, 'YmFt');
    expect(await kho.doc(11), isNull, reason: 'tài khoản khác không đọc được cấu hình của 10');
    expect(await const FlutterSecureStorage().read(key: 'khoa_app_10'), isNotNull);
  });

  test('hàng hỏng → null, không ném', () async {
    FlutterSecureStorage.setMockInitialValues({'khoa_app_10': '{khong-phai-json'});
    expect(await const SecureStorageKhoaAppStore(FlutterSecureStorage()).doc(10), isNull);
  });

  test('xoaHet chỉ xoá khoá khoa_app_*, giữ token', () async {
    const kho = SecureStorageKhoaAppStore(FlutterSecureStorage());
    await kho.ghi(10, cauHinh);
    await kho.ghi(11, cauHinh);
    await kho.xoaHet();
    expect(await kho.doc(10), isNull);
    expect(await kho.doc(11), isNull);
    expect(await const FlutterSecureStorage().read(key: 'access_token'), 'tk',
        reason: 'đăng xuất xoá khoá app, không được xoá nhầm kho token');
  });

  test('InMemory: hongKhiGhi làm ghi ném', () async {
    final kho = InMemoryKhoaAppStore()..hongKhiGhi = true;
    expect(() => kho.ghi(1, cauHinh), throwsA(isA<StateError>()));
  });

  test('xoaHet: một khoá xoá hỏng không chặn khoá khác, token còn', () async {
    final du = {'khoa_app_10': 'a', 'khoa_app_11': 'b', 'access_token': 'tk'};
    await SecureStorageKhoaAppStore(_KhoGiaHongMotKhoa(du, 'khoa_app_10')).xoaHet();
    expect(du.containsKey('khoa_app_11'), isFalse, reason: 'khoá sau khoá hỏng vẫn phải bị xoá');
    expect(du['access_token'], 'tk');
  });

  test('I2: docNghiemNgat — vắng → null; JSON hỏng / hình lạ → NÉM (khác doc nuốt thành null)', () async {
    const kho = SecureStorageKhoaAppStore(FlutterSecureStorage());
    FlutterSecureStorage.setMockInitialValues({});
    expect(await kho.docNghiemNgat(10), isNull, reason: 'khoá không có = chưa bật');
    FlutterSecureStorage.setMockInitialValues({'khoa_app_10': '{khong-phai-json'});
    await expectLater(kho.docNghiemNgat(10), throwsA(anything));
    FlutterSecureStorage.setMockInitialValues({'khoa_app_10': '{"salt": 1}'});
    await expectLater(kho.docNghiemNgat(10), throwsA(anything));
    await kho.ghi(11, cauHinh);
    expect((await kho.docNghiemNgat(11))!.bam, 'YmFt');
  });
}
