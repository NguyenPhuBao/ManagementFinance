/// Phép kiểm trên CSDL THẬT — CHẠY TAY, mặc định bỏ qua.
///
/// ```bash
/// ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
/// export MSYS_NO_PATHCONV=1
/// D=app_flutter/flowmoney.db
/// for E in "" "-wal" "-shm"; do
///   "$ADB" exec-out "run-as com.flowmoney.flowmoney cat $D$E" > /tmp/that.db$E
/// done
/// FLOWMONEY_DB=/tmp/that.db FLOWMONEY_IDACCOUNT=10 \
///   flutter test test/tool/kiem_csdl_that_test.dart --run-skipped
/// ```
///
/// Vì sao tồn tại: bộ test dựng sẵn dữ liệu nên MÙ với đầu vào chết —
/// `suggestAmount` đúng từng dòng mà trả null trên mọi tài khoản thật suốt hai
/// tuần (2026-09-06 → 21). Thứ bắt được là một phép đo trên dữ liệu thật. Chạy
/// lại sau mỗi lát tính năng đụng "trung bình mỗi tháng" hay gói số.
///
/// ⚠️ Chép cả `-wal` và `-shm` (bẫy 4.9 `AI_EDGE_FEATURE.md`). Tệp chính có mốc
/// sửa cũ hàng ngày — đo 2026-09-22: `flowmoney.db` mốc 19/09 còn `-wal` mốc
/// 21/09, tức mọi giao dịch gần đây nằm trong WAL. Chép mỗi tệp chính thì phép
/// đo báo "thiếu dữ liệu" **sai**.
///
/// ⚠️ `run-as` chỉ đọc được CSDL của bản **debug**. Trên máy thật cài bản
/// release thì lối này im lặng trả tệp rỗng.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/data/datasources/budget_local_data_source.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final duong = Platform.environment['FLOWMONEY_DB'];
  final idaccount =
      int.tryParse(Platform.environment['FLOWMONEY_IDACCOUNT'] ?? '');

  test(
    'CSDL thật: cửa sổ nhìn lại mở, và có ít nhất một danh mục gợi ý được',
    () async {
      expect(duong, isNotNull, reason: 'đặt FLOWMONEY_DB=<tệp sqlite đã chép>');
      expect(idaccount, isNotNull,
          reason: 'đặt FLOWMONEY_IDACCOUNT=<mã tài khoản>');
      expect(File('$duong-wal').existsSync(), isTrue,
          reason: 'thiếu -wal thì phép đo nói dối (bẫy 4.9) — chép cả hai');

      final db = AppDatabase.forTesting(NativeDatabase(File(duong!)));
      addTearDown(db.close);
      final repo = BudgetRepositoryImpl(
        localDataSource: BudgetLocalDataSourceImpl(db: db),
      );

      final tuoi = await repo.soNgayCoDuLieu(idaccount!);
      final cuaSo = await repo.soNgayCuaSoNhinLai(idaccount);
      final cats = await repo.getExpenseCategories(idaccount);
      final goiY = <String, double?>{};
      for (final c in cats) {
        goiY[c.name] = await repo.suggestAmount(idaccount, c.id);
      }

      // In bảng để người chạy đọc — đây là PHÉP ĐO, không chỉ là pass/fail.
      // ignore: avoid_print
      print('ROW| tuổi dữ liệu = $tuoi ngày | cửa sổ = $cuaSo ngày');
      for (final e in goiY.entries) {
        // ignore: avoid_print
        print('ROW| ${e.key}: ${e.value ?? "null"}');
      }

      expect(tuoi, isNotNull, reason: 'tài khoản này chưa có giao dịch nào');
      if (tuoi! < 14) {
        expect(cuaSo, isNull, reason: 'dưới 14 ngày thì cửa sổ phải im');
        return; // tài khoản trẻ: không có gì để đòi thêm
      }
      expect(cuaSo, isNotNull,
          reason: 'đủ ngày mà cửa sổ vẫn null → đúng lớp lỗi "đầu vào chết"');
      expect(goiY.values.any((v) => v != null), isTrue,
          reason: 'có dữ liệu $tuoi ngày mà KHÔNG danh mục nào gợi ý được — '
              'suggestAmount lại chết trên dữ liệu thật');
    },
    skip: 'chạy tay: xem docstring',
  );
}
