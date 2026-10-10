/// Test quét `lib/` thứ **22** (spec bịt điểm rò 2026-10-10, mục 4.7): tầng giao diện không được cầm CSDL.
///
/// Trước đợt này 17 tệp `presentation` gọi `sl<AppDatabase>()` rồi đi thẳng xuống DAO, đi vòng repository. Không lỗi
/// nào lộ ra: trang vẫn chạy, chỉ là luật đọc (ví lưu trữ, hàng đã xoá, tài khoản) nằm rải ở trang thay vì một chỗ.
/// Hai mẫu bị cấm: `sl<AppDatabase>` / `sl.isRegistered<AppDatabase>` và mọi lối `.‹tên›Dao`. **Không** cấm import kiểu
/// hàng Drift (quyết định 10 của spec). Tệp còn vi phạm phải nằm trong [conCho] kèm số dòng và chỉ được GIẢM; sạch rồi
/// mà quên rút khỏi danh sách thì test cũng đỏ (khuôn `khong_co_nut_chet_test`).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final cam = <RegExp>[
    RegExp(r'\bsl(\.isRegistered)?<AppDatabase>'),
    RegExp(r'\.(wallet|transaction|category|budget|bill|goal|notification|notificationEvent|aiFeedback|'
        r'goiYPhanHoi|goiYHoaDon|thuTuKhoi|khoaTuChuyenTien)Dao\b'),
  ];

  /// Tệp (tương đối `lib/`) → số dòng còn vi phạm. Điền từ lượt chạy đầu (Step 3); Task 7, 8, 10 rút về rỗng.
  const conCho = <String, int>{
    'features/ai_chat/presentation/pages/ai_chat_page.dart': 1,
    'features/auth/presentation/bloc/auth_bloc.dart': 3,
    'features/bill/presentation/pages/bill_add_page.dart': 3,
    'features/bill/presentation/pages/bill_detail_page.dart': 6,
    'features/bill/presentation/pages/bill_edit_page.dart': 3,
    'features/bill/presentation/pages/bill_page.dart': 3,
    'features/bill/presentation/widgets/bill_actions.dart': 3,
    'features/budget/presentation/pages/budget_page.dart': 1,
    'features/category/presentation/pages/gan_danh_muc_page.dart': 2,
    'features/goal/presentation/pages/goal_detail_page.dart': 10,
    'features/goal/presentation/pages/goal_page.dart': 2,
    'features/home/presentation/pages/home_page.dart': 9,
    'features/notification/presentation/pages/notification_center_page.dart': 1,
    'features/notification/presentation/widgets/notification_panel.dart': 2,
    'features/profile/presentation/pages/profile_page.dart': 1,
    'features/transaction/presentation/pages/add_transaction_page.dart': 6,
    'features/transaction/presentation/pages/transaction_page.dart': 5,
  };

  test('presentation/ và shared/ không cầm AppDatabase hay DAO, trừ danh sách rút dần', () {
    final thay = <String, int>{};
    var soTep = 0;
    for (final goc in [Directory('lib/features'), Directory('lib/shared')]) {
      expect(goc.existsSync(), isTrue, reason: 'Chạy từ src/Client-app.');
      for (final f in goc.listSync(recursive: true).whereType<File>()) {
        final duong = f.path.replaceAll('\\', '/');
        if (!duong.endsWith('.dart')) continue;
        if (duong.contains('/features/') && !duong.contains('/presentation/')) continue;
        soTep++;
        var n = 0;
        for (final d in f.readAsLinesSync()) {
          if (d.trimLeft().startsWith('//')) continue;
          if (cam.any((r) => r.hasMatch(d))) n++;
        }
        if (n > 0) thay[duong.replaceFirst(RegExp(r'^lib/'), '')] = n;
      }
    }
    expect(soTep, greaterThan(100), reason: 'Phép quét phải thấy tệp presentation — đang quét sai thư mục.');

    final loi = <String>[];
    for (final e in thay.entries) {
      final tran = conCho[e.key];
      if (tran == null) {
        loi.add('${e.key}: ${e.value} dòng cầm CSDL — đi qua repository của mảng hoặc ThongBaoNguon (spec mục 4.2).');
      } else if (e.value > tran) {
        loi.add('${e.key}: ${e.value} dòng, danh sách cho phép $tran — chỉ được giảm.');
      }
    }
    for (final e in conCho.entries) {
      if (!thay.containsKey(e.key)) loi.add('${e.key}: đã sạch — rút khỏi conCho.');
    }
    expect(loi, isEmpty, reason: loi.join('\n'));
  });
}
