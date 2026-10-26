import 'package:flowmoney/features/khoa_app/data/datasources/kenh_sinh_trac.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const kenh = MethodChannel(kKenhSinhTrac);
  final goi = <MethodCall>[];

  void tra(Object? Function(MethodCall c) f) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(kenh, (c) async {
        goi.add(c);
        return f(c);
      });

  tearDown(() {
    goi.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(kenh, null);
  });

  test('trangThai đọc hai cờ; lỗi kênh → không hỗ trợ', () async {
    tra((_) => {'hoTro': true, 'daDangKy': false});
    final t = await const KenhSinhTracAndroid().trangThai();
    expect([t.hoTro, t.daDangKy], [true, false]);
    expect(goi.single.method, 'trangThai');
    tra((_) => throw PlatformException(code: 'x'));
    expect((await const KenhSinhTracAndroid().trangThai()).hoTro, isFalse);
  });

  test('bat gửi idaccount + bí mật base64, nhận bản mã + iv', () async {
    tra((_) => {'banMa': 'YmFu', 'iv': 'aXY='});
    final kq = await const KenhSinhTracAndroid().bat(10, Uint8List.fromList([1, 2, 3]));
    expect(goi.single.method, 'bat');
    expect(goi.single.arguments, {'idaccount': 10, 'biMat': 'AQID'});
    expect([kq.banMa, kq.iv, kq.loi], ['YmFu', 'aXY=', null]);
  });

  test('mã lỗi Kotlin → LoiSinhTrac; mã lạ → loi', () async {
    for (final (ma, loi) in [
      ('HUY', LoiSinhTrac.huy),
      ('VO_HIEU', LoiSinhTrac.voHieu),
      ('MAT_KHOA', LoiSinhTrac.matKhoa),
      ('TAM_KHOA', LoiSinhTrac.tamKhoa),
      ('KHONG_HO_TRO', LoiSinhTrac.khongHoTro),
      ('???', LoiSinhTrac.loi),
    ]) {
      tra((_) => {'loi': ma});
      expect((await const KenhSinhTracAndroid().mo(10, banMa: 'a', iv: 'b')).loi, loi, reason: ma);
    }
  });

  test('mo thành công trả bí mật đã giải base64', () async {
    tra((_) => {'biMat': 'AQID'});
    expect((await const KenhSinhTracAndroid().mo(10, banMa: 'a', iv: 'b')).biMat, [1, 2, 3]);
    expect(goi.single.method, 'mo');
    expect(goi.single.arguments, {'idaccount': 10, 'banMa': 'a', 'iv': 'b'});
  });

  test('xoaHet gọi lệnh xoaHet', () async {
    tra((_) => null);
    await const KenhSinhTracAndroid().xoaHet();
    expect(goi.single.method, 'xoaHet');
  });

  test('bản trống: không hỗ trợ, không gọi kênh', () async {
    tra((_) => fail('không được gọi kênh'));
    const t = KenhSinhTracTrong();
    expect((await t.trangThai()).hoTro, isFalse);
    expect((await t.bat(1, Uint8List(32))).loi, LoiSinhTrac.khongHoTro);
    expect((await t.mo(1, banMa: 'a', iv: 'b')).loi, LoiSinhTrac.khongHoTro);
    await t.xoaHet();
  });
}
