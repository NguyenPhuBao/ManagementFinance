import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Quy tắc 2 `CLAUDE.md`: `idaccount` CHỈ đến từ phiên đăng nhập, không bao giờ
/// mặc định về `1` — đó là tài khoản **admin THẬT**, không phải giá trị "chưa
/// biết".
///
/// G4 và G8 đã gỡ các bản `?? 1` ở bill, goal và khâu đồng bộ, và tài liệu từng
/// ghi "không còn ở bất kỳ đâu". Nhưng ba màn quản lý danh mục vẫn giữ đúng
/// khuôn ấy (G35, tìm ra 2026-09-11), vì biểu thức bị ngắt dòng:
///
///     return int.tryParse(...) ??
///         1;
///
/// dạng ấy lọt qua mọi lượt `grep` một dòng. Test này quét cả `lib/` bằng regex
/// nhiều dòng, như `currency_formatter_test` và `wallet_picker_sources_test`,
/// để lần sau không phải trông vào trí nhớ.
void main() {
  test('không chỗ nào trong lib/ lấy mã tài khoản với dự phòng `?? 1`', () {
    final duPhong1 = RegExp(r'\?\?\s*1\s*[;,)\]]');
    // Chỉ bắt `?? 1` đứng gần mã tài khoản / người dùng, để một số lượng mặc
    // định 1 hợp lệ ở chỗ khác không làm test đỏ oan.
    final ganTaiKhoan = RegExp(r'account|user', caseSensitive: false);

    final viPham = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart')) continue;
      final noiDung = f.readAsStringSync();
      for (final m in duPhong1.allMatches(noiDung)) {
        final batDau = m.start - 200 < 0 ? 0 : m.start - 200;
        if (!ganTaiKhoan.hasMatch(noiDung.substring(batDau, m.start))) continue;
        final dong = '\n'.allMatches(noiDung.substring(0, m.start)).length + 1;
        viPham.add('${f.path.replaceAll(r'\', '/')}:$dong');
      }
    }

    expect(viPham, isEmpty,
        reason: 'Mã tài khoản rơi về 1 là đọc và ghi dưới danh nghĩa admin '
            'thật. Dùng `currentAccountIdOrNull` '
            '(`core/auth/current_account.dart`) và tự xử lý `null`.');
  });
}
