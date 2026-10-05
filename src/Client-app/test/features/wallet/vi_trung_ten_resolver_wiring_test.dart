/// `ViTrungTenResolver` phải được dựng ĐÚNG một chỗ và BẮT ĐẦU NGHE ở `main.dart` (spec G63 mục 8, bẫy 11) — cùng
/// khuôn `test/features/bill/bill_conflict_resolver_wiring_test.dart`. Lớp có đủ test riêng mà không được nối thì xanh
/// hết trong khi app thật không bao giờ đặt cờ.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const tepDinhNghia = 'features/wallet/data/services/vi_trung_ten_resolver.dart';

  test('chỉ MỘT chỗ trong lib/ dựng ViTrungTenResolver', () {
    final choDung = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.path.replaceAll(r'\', '/').endsWith(tepDinhNghia)) continue;
      if (f.readAsStringSync().contains('ViTrungTenResolver(')) choDung.add(f.path);
    }
    expect(choDung, hasLength(1), reason: 'Thấy: $choDung');
  });

  test('main.dart BẮT ĐẦU NGHE pushResultStream bằng ViTrungTenResolver', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(
        RegExp(r'sl<ViTrungTenResolver>\(\)\s*\.batDauNghe\(\s*sl<SyncEngine>\(\)\.pushResultStream\s*\)')
            .hasMatch(main),
        isTrue,
        reason: 'Dựng mà quên batDauNghe là lớp nằm im — cùng hậu quả với không dựng.');
  });
}
