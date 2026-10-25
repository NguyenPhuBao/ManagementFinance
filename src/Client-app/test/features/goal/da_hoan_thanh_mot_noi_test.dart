/// Test quét `lib/` thứ **30** — luật "mục tiêu đã xong" có MỘT định nghĩa: getter `daHoanThanh` của `GoalEntity`
/// (`goal/data/models/goal_entity.dart`; báo cáo soát kiến trúc 2026-10-18 mục 6, sửa 2026-10-19).
///
/// Vì sao: docstring của getter đã dặn đừng chép, vậy mà tới 2026-10-18 có sáu bản viết tay ở năm tệp với HAI công thức
/// (một bản so `progress`, năm bản so số tiền còn thiếu) — bộ trích tự động, lịch nhắc, mốc chạy nền, khối Nhận xét chi
/// tiết mục tiêu mỗi nơi một bản. Hôm nay chúng chỉ khác nhau ở biên NaN / âm; lần sửa sau của một bản là lệch im lặng.
///
/// Quét: ngoài `goal_entity.dart`, không dòng MÃ nào (dòng bắt đầu bằng `//` được bỏ qua) chứa `isCompleted` theo sau là
/// toán tử hoặc. Trong `goal_entity.dart` chỉ đúng một dòng mã như thế — chính getter.
///
/// Giới hạn đã biết: chỉ bắt dạng `isCompleted` đứng TRƯỚC `||`; không bắt `|| …isCompleted` ở cuối, dạng phủ định, hay vế số
/// tiền đứng một mình (vd. `duBaoHoanThanh` ở `goal_forecast.dart` dùng `remainingAmount <= 0` — phép chặn số học, cố ý giữ).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _mau = RegExp(r'isCompleted\s*\|\|');
const _tepDinhNghia = 'lib/features/goal/data/models/goal_entity.dart';

List<String> _dongMaKhop(File f) {
  final ra = <String>[];
  final dong = f.readAsLinesSync();
  for (var i = 0; i < dong.length; i++) {
    final d = dong[i].trimLeft();
    if (d.startsWith('//')) continue;
    if (_mau.hasMatch(d)) ra.add('${f.path.replaceAll(r'\', '/')}:${i + 1}: ${d.trim()}');
  }
  return ra;
}

void main() {
  test('ngoài goal_entity.dart không dòng mã nào viết lại luật "đã xong"', () {
    final vi = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
      if (f.path.replaceAll(r'\', '/').endsWith(_tepDinhNghia)) continue;
      vi.addAll(_dongMaKhop(f));
    }
    expect(vi, isEmpty,
        reason: 'Gọi `.daHoanThanh` thay cho bản viết tay. Hai công thức "đã xong" sống song song là một chỗ sẽ lệch '
            'ở lần sửa sau — bộ trích tự động chạy tiếp cho mục tiêu mà màn hình nói đã đạt, hoặc ngược lại.');
  });

  test('trong goal_entity.dart chỉ getter daHoanThanh viết luật ấy', () {
    final khop = _dongMaKhop(File(_tepDinhNghia));
    expect(khop, hasLength(1), reason: 'Mọi chỗ khác trong lớp (vd. `isBehindSchedule`) gọi `daHoanThanh`. Thấy: $khop');
    expect(khop.single, contains('get daHoanThanh'));
  });
}
