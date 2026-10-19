/// Cổng lưu ảnh mã VietQR vào Thư viện ảnh (spec G94 2026-10-18 mục 5.3). Ranh giới Dart ↔ Kotlin: gõ nhầm tên kênh /
/// tham số chỉ hiện ra thành "bấm Lưu mà chẳng thấy gì" — hợp đồng gọi thì kiểm được.
library;

import 'package:flowmoney/features/premium/data/datasources/luu_anh_qr.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final anh = Uint8List.fromList([137, 80, 78, 71]);
  final url = Uri.parse('https://img.vietqr.io/image/970422-0123-compact2.png?amount=49000');
  late List<MethodCall> daGoi;
  Object? traVe;
  Object? nem;

  setUp(() {
    daGoi = [];
    traVe = true;
    nem = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(LuuAnhQr.kenh,
        (call) async {
      daGoi.add(call);
      if (nem != null) throw nem!;
      return traVe;
    });
  });
  tearDown(() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(LuuAnhQr.kenh, null));

  test('tải ảnh rồi gọi luuAnh với tên + byte → daLuu', () async {
    Uri? daTai;
    final kq = await LuuAnhQr(taiAnh: (u) async {
      daTai = u;
      return anh;
    }).luu(url, ten: 'FlowMoney-QR-1.png');
    expect(kq, KetQuaLuuAnh.daLuu);
    expect(daTai, url);
    expect(daGoi.single.method, 'luuAnh');
    final args = daGoi.single.arguments as Map;
    expect(args['ten'], 'FlowMoney-QR-1.png');
    expect(args['bytes'], anh);
  });

  test('Kotlin trả false (Android < 10) → khongHoTro', () async {
    traVe = false;
    expect(await LuuAnhQr(taiAnh: (_) async => anh).luu(url, ten: 'a.png'), KetQuaLuuAnh.khongHoTro);
  });

  test('không có kênh (web / máy khác) → khongHoTro', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(LuuAnhQr.kenh, null);
    expect(await LuuAnhQr(taiAnh: (_) async => anh).luu(url, ten: 'a.png'), KetQuaLuuAnh.khongHoTro);
  });

  test('ghi hỏng (PlatformException) → hong; tải ảnh hỏng → hong, KHÔNG gọi kênh', () async {
    nem = PlatformException(code: 'loi_ghi');
    expect(await LuuAnhQr(taiAnh: (_) async => anh).luu(url, ten: 'a.png'), KetQuaLuuAnh.hong);
    daGoi.clear();
    expect(await LuuAnhQr(taiAnh: (_) async => throw StateError('mạng')).luu(url, ten: 'a.png'), KetQuaLuuAnh.hong);
    expect(daGoi, isEmpty);
  });
}
