/// Phép ĐO trên CSDL THẬT — CHẠY TAY, mặc định bỏ qua. Đo thời gian
/// `rows.map(TransactionEntity.fromDrift).toList()` trên toàn sổ giao dịch của
/// một tài khoản (spec `2026-10-14-entity-giao-dich-vi-design.md`, nghiệm thu).
///
/// ```bash
/// ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
/// export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*"
/// D=app_flutter/flowmoney.db
/// for E in "" "-wal" "-shm"; do
///   "$ADB" exec-out "run-as com.flowmoney.flowmoney cat $D$E" > /tmp/that.db$E
/// done
/// FLOWMONEY_DB=/tmp/that.db FLOWMONEY_IDACCOUNT=10 \
///   flutter test test/tool/do_from_drift_test.dart --run-skipped
/// ```
///
/// ⚠️ Chép cả `-wal` và `-shm` (bẫy 4.9 `AI_EDGE_FEATURE.md`); công cụ mở `.db`
/// checkpoint và xoá `-wal` nên chép bản mới mỗi lần chạy. Chỉ đo, không đòi
/// ngưỡng — con số ghi vào spec / `CLIENT_APP_KNOWN_GAPS.md` G88.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final duong = Platform.environment['FLOWMONEY_DB'];
  final idaccount =
      int.tryParse(Platform.environment['FLOWMONEY_IDACCOUNT'] ?? '');

  test(
    'CSDL thật: thời gian TransactionEntity.fromDrift trên toàn sổ',
    () async {
      expect(duong, isNotNull, reason: 'đặt FLOWMONEY_DB=<tệp sqlite đã chép>');
      expect(idaccount, isNotNull,
          reason: 'đặt FLOWMONEY_IDACCOUNT=<mã tài khoản>');
      expect(File('$duong-wal').existsSync(), isTrue,
          reason: 'thiếu -wal thì phép đo nói dối (bẫy 4.9) — chép cả hai');

      final db = AppDatabase.forTesting(NativeDatabase(File(duong!)));
      addTearDown(db.close);

      final rows = await db.transactionDao.getAll(idaccount!);
      final lan = <double>[];
      for (var i = 0; i < 20; i++) {
        final sw = Stopwatch()..start();
        final entities = rows.map(TransactionEntity.fromDrift).toList();
        sw.stop();
        expect(entities.length, rows.length);
        lan.add(sw.elapsedMicroseconds / 1000);
      }
      lan.sort();
      final trungVi = (lan[9] + lan[10]) / 2;
      // ignore: avoid_print
      print('ROW| số hàng = ${rows.length} | 20 lượt fromDrift: '
          'trung vị ${trungVi.toStringAsFixed(3)} ms '
          '(nhỏ nhất ${lan.first.toStringAsFixed(3)}, '
          'lớn nhất ${lan.last.toStringAsFixed(3)})');
    },
    skip: 'chạy tay: xem docstring',
  );
}
