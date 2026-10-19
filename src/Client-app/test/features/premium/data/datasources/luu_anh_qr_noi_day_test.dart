/// Nối dây kênh `flowmoney/luu_anh` (spec G94 2026-10-18 mục 5.3): tên kênh / hàm ở Dart phải khớp `MainActivity.kt`,
/// và phía Kotlin ghi vào Thư viện ảnh (MediaStore.Images), không phải thư mục Tải về. `flutter test` không chạy Kotlin
/// — test đọc tệp nguồn.
library;

import 'dart:io';

import 'package:flowmoney/features/premium/data/datasources/luu_anh_qr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tên kênh / hàm khớp MainActivity.kt; Kotlin ghi MediaStore.Images ở Pictures/FlowMoney', () {
    final kt = File('android/app/src/main/kotlin/com/flowmoney/flowmoney/MainActivity.kt').readAsStringSync();
    expect(LuuAnhQr.kenh.name, 'flowmoney/luu_anh');
    expect(kt, contains('"flowmoney/luu_anh"'));
    expect(kt, contains('"luuAnh"'));
    expect(kt, contains('MediaStore.Images.Media.EXTERNAL_CONTENT_URI'));
    expect(kt, contains('Environment.DIRECTORY_PICTURES'));
    expect(kt, contains('Build.VERSION_CODES.Q'), reason: 'RELATIVE_PATH cần Android 10 — máy cũ trả false');
  });

  test('DI nối LuuAnhQr với taiAnhBangDioTran (Dio TRẦN) — Dio chung gắn token người dùng cho host bên thứ ba', () {
    // Bỏ dòng chú thích: chú thích được phép nhắc tên `DioClient` / `sl<`.
    String ma(String duong) => File(duong)
        .readAsLinesSync()
        .where((d) => !d.trimLeft().startsWith('//'))
        .join('\n');
    final di = ma('lib/core/di/injection_container.dart');
    expect(di, contains('LuuAnhQr(taiAnh: taiAnhBangDioTran)'),
        reason: 'ảnh QR ở img.vietqr.io: phải đi bằng Dio trần, không phải sl<DioClient>().dio (AuthInterceptor gắn token)');
    final tai = ma('lib/features/premium/data/datasources/tai_anh_dio_tran.dart');
    expect(tai, isNot(contains('DioClient')));
    expect(tai, isNot(contains('sl<')));
    expect(tai, contains('Dio()'), reason: 'đòi kết quả, không chỉ đòi vắng mặt: bộ tải phải dựng Dio trần');
  });
}
