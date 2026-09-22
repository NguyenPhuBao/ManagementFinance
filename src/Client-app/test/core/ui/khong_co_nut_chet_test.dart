import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Không tệp nào trong `lib/` được để **handler rỗng** trên một nút — test quét
/// `lib/` thứ **mười** (2026-09-19).
///
/// `onPressed: () {}` khiến nút vẫn vẽ như nút sống (màu, hiệu ứng chạm) mà
/// bấm vào không xảy ra gì. `flutter analyze` im lặng, `flutter test` im lặng,
/// và lỗi chỉ hiện ra khi người dùng bấm đúng chỗ ấy. Lượt đánh giá UX ngày
/// 2026-09-19 đếm được **16** chỗ như vậy, trong đó hamburger ở tab Cá nhân và
/// hai mục MFA / Đồng bộ Cloud ở Cài đặt đã sống qua nhiều phiên.
///
/// Muốn giữ một nút chưa có việc thì phải **liệt kê tay** ở đây kèm lý do và số
/// chỗ — giống `wallet_picker_sources_test`. Sửa xong một chỗ mà quên rút khỏi
/// danh sách thì test cũng đỏ, để danh sách không phình thành nơi giấu nợ.
void main() {
  /// Tệp còn được phép giữ handler rỗng: đường dẫn tương đối `lib/` →
  /// (số chỗ, lý do). Mỗi mục là một quyết định **chờ người dùng chốt**, không
  /// phải một ngoại lệ vĩnh viễn.
  const conChoChot = <String, (int, String)>{
    'features/ai_chat/presentation/pages/ai_chat_page.dart': (
      5,
      'Trợ lý AI chưa làm; giữ hay gỡ khỏi menu là mục D9 của danh sách '
          'UX 2026-09-19, chờ chốt.',
    ),
    'features/auth/presentation/pages/login_page.dart': (
      2,
      'Hai nút Google / Apple: backend chưa có OAuth. Chờ chốt gỡ hay làm.',
    ),
    'features/auth/presentation/pages/forgot_password_page.dart': (
      1,
      '"Liên hệ hỗ trợ": dự án chưa có kênh hỗ trợ nào để trỏ tới.',
    ),
    'features/transaction/presentation/pages/add_transaction_page.dart': (
      1,
      'Menu ⋮ ở màn Thêm giao dịch chưa có mục nào. Chờ chốt gỡ hay làm.',
    ),
  };

  final khuon = RegExp(
    r'\bon(Pressed|Tap|Changed|LongPress|Selected|Submitted)\s*:\s*'
    r'\((?:_|\w+)?\)\s*(?:async\s*)?\{\s*\}',
  );

  test('không nút nào trong lib/ mang handler rỗng, trừ danh sách chờ chốt',
      () {
    final goc = Directory('lib');
    expect(goc.existsSync(), isTrue, reason: 'Chạy từ src/Client-app.');

    final thay = <String, int>{};
    for (final f in goc.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final duong = f.path
          .replaceAll('\\', '/')
          .replaceFirst(RegExp(r'^lib/'), '');
      // Bỏ dòng chú thích: hai tệp mục tiêu nhắc tới `onPressed: () {}`
      // trong lời giải thích vì sao KHÔNG được làm thế.
      final maThat = f
          .readAsLinesSync()
          .where((d) => !d.trimLeft().startsWith('//'))
          .join('\n');
      final n = khuon.allMatches(maThat).length;
      if (n > 0) thay[duong] = n;
    }

    final loi = <String>[];
    for (final e in thay.entries) {
      final cho = conChoChot[e.key];
      if (cho == null) {
        loi.add('${e.key}: ${e.value} handler rỗng — nút chết, chưa được '
            'liệt kê ở danh sách chờ chốt.');
      } else if (cho.$1 != e.value) {
        loi.add('${e.key}: có ${e.value} handler rỗng nhưng danh sách ghi '
            '${cho.$1} — cập nhật danh sách hoặc sửa nút.');
      }
    }
    for (final e in conChoChot.entries) {
      if (!thay.containsKey(e.key)) {
        loi.add('${e.key}: danh sách chờ chốt vẫn ghi nhưng tệp không còn '
            'handler rỗng nào — rút mục này ra.');
      }
    }

    expect(loi, isEmpty, reason: loi.join('\n'));
  });
}
