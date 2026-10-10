import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor connect() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'flowmoney.db'));
    // Từ 2026-10-10 dự án CỐ Ý cho hai kết nối cùng sống: engine nền của
    // WorkManager và engine của app (spec tự chuyển tiền chạy nền mục 3.4).
    // Mặc định busy_timeout = 0 → mọi lần ghi trùng nhịp ném SQLITE_BUSY ngay.
    return NativeDatabase.createInBackground(
      file,
      setup: (raw) => raw.execute('PRAGMA busy_timeout = 5000'),
    );
  });
}
