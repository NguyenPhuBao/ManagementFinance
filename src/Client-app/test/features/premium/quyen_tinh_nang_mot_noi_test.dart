import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/premium/domain/quyen_tinh_nang.dart';

/// Test quét `lib/` thứ 21 (spec phân quyền client 2026-10-08 mục 6).
///
/// Bảng quyền server chỉ được đọc qua `duocDung` — đọc thẳng `quyenTinhNang` là bỏ qua phép xét hạn (Premium hết hạn
/// offline vẫn mở mọi tính năng — lỗi 1 của mã backend viết sẵn). Và mã quyền server chỉ nằm ở `MaQuyen`: chuỗi rải
/// rác là chỗ thứ hai phải đổi khi admin… không, khi BACKEND đổi tên khoá.
void main() {
  const choPhepDoc = {
    'lib/features/premium/domain/quyen_tinh_nang.dart',
    'lib/features/premium/domain/trang_thai_goi.dart', // đọc / ghi kho và JSON server
  };
  const noiMaQuyen = 'lib/features/premium/domain/quyen_tinh_nang.dart';

  Map<String, String> quetLib() => {
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart'))
            f.path.replaceAll('\\', '/'): f
                .readAsLinesSync()
                .where((d) => !d.trimLeft().startsWith('//'))
                .join('\n'),
      };

  test('tiền đề: phép quét thấy chính tệp định nghĩa', () {
    final tep = quetLib();
    expect(tep.keys, contains(noiMaQuyen));
    expect(tep[noiMaQuyen], contains('quyenTinhNang'));
  });

  test('quyenTinhNang chỉ được đọc ở quyen_tinh_nang.dart (và kho ở trang_thai_goi.dart)', () {
    final viPham = [
      for (final e in quetLib().entries)
        if (e.value.contains('quyenTinhNang') && !choPhepDoc.contains(e.key)) e.key,
    ];
    expect(viPham, isEmpty,
        reason: 'Đọc bảng quyền ngoài `duocDung` là bỏ qua phép xét hạn — dùng `GoiCubit.coQuyen(MaQuyen.…)`.');
  });

  test('mã quyền server chỉ nằm ở MaQuyen', () {
    final viPham = <String>[];
    for (final e in quetLib().entries) {
      if (e.key == noiMaQuyen) continue;
      for (final m in MaQuyen.values) {
        if (e.value.contains("'${m.maServer}'")) viPham.add('${e.key}: ${m.maServer}');
      }
    }
    expect(viPham, isEmpty, reason: 'Dùng `MaQuyen.…` / `maQuyenTuServer` thay vì chuỗi.');
  });
}
