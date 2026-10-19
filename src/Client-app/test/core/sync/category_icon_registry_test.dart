/// `CategoryIconRegistry` tra theo tên bằng ĐỊNH NGHĨA DUY NHẤT của phép so tên danh mục (`normalizeCategoryName`, quy tắc 7
/// `CLAUDE.md`) — không phải `trim().toLowerCase()` riêng (báo cáo soát kiến trúc 2026-10-18 mục 6). Đo 2026-10-19: `saveIcon`
/// có 0 chỗ gọi trong `lib/` — registry hiện chỉ ĐỌC dữ liệu di sản (`sync_engine` gọi `getIcon`); ca này canh phép so tên để
/// bản ghi nào còn dùng nó không có một định nghĩa thứ hai.
library;

import 'package:flowmoney/core/sync/category_icon_registry.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lưu với tên tách dấu + khoảng trắng đôi, tra bằng tên dựng sẵn một khoảng trắng → trúng', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final huyen = String.fromCharCode(0x0300); // dấu huyền tổ hợp
    final mu = String.fromCharCode(0x0302); // dấu mũ tổ hợp
    await CategoryIconRegistry.saveIcon('', 'Ca$huyen  phe$mu', 'coffee', '#795548');
    expect(await CategoryIconRegistry.getIcon('', ' cà phê '), {'icon': 'coffee', 'colour': '#795548'},
        reason: 'Hai tên là MỘT danh mục theo normalizeCategoryName; tra trượt là mất icon.');
  });
}
