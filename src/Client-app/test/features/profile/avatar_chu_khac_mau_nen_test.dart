/// Chữ cái đầu trên avatar phải khác màu nền — 2026-09-19.
///
/// ## Vì sao có tệp này
///
/// `AppColors.primaryContainer` **chính là** `AppColors.primary` (cùng
/// `#1A1A19`, xem `app_colors.dart:50`). Nên một avatar tô nền
/// `primaryContainer` rồi viết chữ `primary` lên là **chữ đen trên nền đen** —
/// người dùng thấy một vòng tròn đen trống, và không lệnh nào của Flutter nói
/// gì cả.
///
/// Lượt đánh giá UX 2026-09-19 (A9) đã sửa chỗ này ở **drawer**, nhưng bỏ sót
/// **hai chỗ khác** mang đúng khuôn ấy. Chúng lộ ra khi nút bút chì trên avatar
/// tab Cá nhân được nối vào trang Thông tin cá nhân và máy ảo chụp được cái
/// vòng đen ở đó.
///
/// ⚠️ Ca này quét **cặp màu trong cùng một khối avatar** chứ không dựng trang:
/// `EditProfilePage` là `StatefulWidget` có controller và phụ thuộc riêng, nên
/// dựng nó chỉ để đọc một màu là ca test giòn.
library;

import 'dart:io';

import 'package:flowmoney/shared/theme/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hai màu ấy đúng là MỘT — tiền đề của cả tệp này', () {
    expect(AppColors.primaryContainer, AppColors.primary,
        reason: 'Nếu ngày nào đó chúng khác nhau thì cả tệp này hết lý do tồn '
            'tại — và lúc ấy hãy xoá nó thay vì để một lưới quét vô nghĩa.');
    expect(AppColors.onPrimaryContainer, isNot(AppColors.primaryContainer),
        reason: '`onPrimaryContainer` là màu chữ đúng để viết lên nền ấy.');
  });

  /// Trong cửa sổ 20 dòng sau một khai báo nền `primaryContainer`, không được
  /// có dòng màu chữ `color: AppColors.primary,`.
  test('⚠️ không avatar nào viết chữ `primary` lên nền `primaryContainer`', () {
    final loi = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final dong = f.readAsLinesSync();
      for (var i = 0; i < dong.length; i++) {
        final d = dong[i].trim();
        final laNen = d.startsWith('backgroundColor: AppColors.primaryContainer') ||
            d.startsWith('color: AppColors.primaryContainer');
        if (!laNen) continue;
        for (var j = i + 1; j < dong.length && j < i + 20; j++) {
          if (dong[j].trim() == 'color: AppColors.primary,') {
            loi.add('${f.path.replaceAll(r'\', '/')}:${j + 1}');
            break;
          }
        }
      }
    }
    expect(loi, isEmpty,
        reason: 'Chữ `primary` trên nền `primaryContainer` là chữ đen trên nền '
            'đen — một vòng tròn trống. Dùng `AppColors.onPrimaryContainer`.\n'
            '${loi.join('\n')}');
  });
}
