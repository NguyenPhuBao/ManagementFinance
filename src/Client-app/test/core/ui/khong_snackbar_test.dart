/// Không tệp nào trong `lib/` được dựng `SnackBar` hay gọi `ScaffoldMessenger` — test quét `lib/` thứ **mười chín**
/// (E4 của lượt UX, 2026-10-06, người dùng duyệt).
///
/// Nếp đã chốt của dự án: thông báo tạm thời là **viên nhỏ thu gọn theo nội dung** (`AppToast`), không phải dải kín
/// ngang màn hình. Trước E4 app có 88 `SnackBar` ở 31 tệp sống cạnh viên toast — hai kiểu thông báo trong một app, và
/// dải SnackBar còn che nội dung đáy màn, đứng yên hàng phút khi có `action` (Realme 2026-10-03). Nay mọi câu đi qua
/// `baoNhanh(...)` (`core/ui/thong_bao_nhanh.dart`). Một `SnackBar` mới không gây lỗi nào — nó chỉ lặng lẽ đưa kiểu
/// thông báo cũ trở lại, nên phép canh phải là quét.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final khuon = RegExp(r'(?<![A-Za-z_])(?:SnackBar|ScaffoldMessenger)\b');

  test('không tệp nào trong lib/ dựng SnackBar hay gọi ScaffoldMessenger', () {
    final loi = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart')) continue;
      final duong = f.path.replaceAll('\\', '/').replaceFirst(RegExp(r'^lib/'), '');
      final dong = f.readAsLinesSync();
      for (var i = 0; i < dong.length; i++) {
        final t = dong[i].trimLeft();
        if (t.startsWith('//')) continue; // tài liệu trong mã được nhắc tên cũ
        if (khuon.hasMatch(dong[i])) loi.add('$duong:${i + 1}: ${t.trim()}');
      }
    }
    expect(loi, isEmpty,
        reason: 'Dùng baoNhanh(cau, loai: LoaiThongBao.loi/xong) — viên toast của AppToast. '
            'Nút như "Hoàn tác" thì truyền hanhDong: HanhDongToast(...).');
  });

  test('tiền đề: phép quét thấy được một tệp có thật trong lib/', () {
    expect(File('lib/core/ui/thong_bao_nhanh.dart').existsSync(), isTrue,
        reason: 'quét sai thư mục thì ca trên xanh giả');
  });
}
