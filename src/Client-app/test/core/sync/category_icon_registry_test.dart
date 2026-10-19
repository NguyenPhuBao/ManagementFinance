/// `CategoryIconRegistry` tra theo tên bằng ĐỊNH NGHĨA DUY NHẤT của phép so tên danh mục (`normalizeCategoryName`, quy tắc 7
/// `CLAUDE.md`) — không phải `trim().toLowerCase()` riêng (báo cáo soát kiến trúc 2026-10-18 mục 6). Đo 2026-10-19: `saveIcon`
/// có 0 chỗ gọi trong `lib/` — registry hiện chỉ ĐỌC dữ liệu di sản (`sync_engine` gọi `getIcon`).
/// Ca 1 canh `getIcon` (đường chạy thật, kho gieo sẵn khoá NFC một khoảng trắng); ca 2 canh `saveIcon`.
/// Kho gieo ở `setUpAll` vì `_isLoaded` tĩnh chỉ nạp một lần mỗi tiến trình test.
library;

import 'dart:convert';

import 'package:flowmoney/core/sync/category_icon_registry.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final huyen = String.fromCharCode(0x0300); // dấu huyền tổ hợp
  final mu = String.fromCharCode(0x0302); // dấu mũ tổ hợp
  final sac = String.fromCharCode(0x0301); // dấu sắc tổ hợp

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({
      'flowmoney_category_icon_registry_v1': json.encode({
        'cà phê': {'icon': 'coffee', 'colour': '#795548'},
      }),
    });
  });

  test('getIcon: kho di sản khoá NFC một khoảng trắng, tra bằng tên tách dấu + khoảng trắng đôi → trúng', () async {
    expect(await CategoryIconRegistry.getIcon('', 'Ca$huyen  phe$mu'), {'icon': 'coffee', 'colour': '#795548'},
        reason: 'getIcon phải chuẩn hoá tên tra bằng normalizeCategoryName; tra trượt là mất icon của dữ liệu cũ.');
  });

  test('saveIcon: lưu tên tách dấu + khoảng trắng đôi, tra bằng tên dựng sẵn một khoảng trắng → trúng', () async {
    await CategoryIconRegistry.saveIcon('', 'Tra$huyen  su${sac}a', 'tea', '#112233');
    expect(await CategoryIconRegistry.getIcon('', ' trà sữa '), {'icon': 'tea', 'colour': '#112233'},
        reason: 'Hai tên là MỘT danh mục theo normalizeCategoryName; ghi trượt là mất icon.');
  });
}
