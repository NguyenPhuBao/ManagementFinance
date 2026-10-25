/// Test quét `lib/` thứ **36** (G89, 2026-10-20): interceptor trạng thái máy chủ chỉ được DỰNG trong
/// `lib/core/api/dio_client.dart`. Dio CHUNG chỉ nói chuyện với backend của app; gắn interceptor này vào một Dio gọi host bên
/// thứ ba (tải ảnh VietQR, tải mô hình) là một 2xx của CDN xoá nhầm dòng nhắc bảo trì (spec G89 mục 3.2).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tệp được nhắc lời dựng: `DioClient` (chỗ duy nhất gắn) và chính tệp định nghĩa (khai constructor).
const _choPhep = {
  'lib/core/api/dio_client.dart',
  'lib/core/api/interceptors/may_chu_interceptor.dart',
};

final _mau = RegExp(r'\bMayChuInterceptor\s*\(');

void main() {
  test('đối chứng dương: mẫu bắt được lời dựng thật trong dio_client.dart', () {
    expect(_mau.hasMatch(File('lib/core/api/dio_client.dart').readAsStringSync()), isTrue,
        reason: 'mẫu không khớp lời dựng thật thì quét dưới xanh vì mù');
  });

  test('ngoài dio_client.dart không chỗ nào dựng interceptor trạng thái máy chủ', () {
    final viPham = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final tep = f.path.replaceAll(r'\', '/');
      if (_choPhep.contains(tep)) continue;
      final dong = f.readAsLinesSync();
      for (var i = 0; i < dong.length; i++) {
        if (_mau.hasMatch(dong[i])) viPham.add('$tep:${i + 1}');
      }
    }
    expect(viPham, isEmpty,
        reason:
            'Dio chung chỉ gọi backend — gắn vào Dio khác là 2xx của host lạ xoá nhầm dòng nhắc (spec G89 mục 3.2)');
  });
}
