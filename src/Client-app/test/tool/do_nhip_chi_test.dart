/// Phép ĐO trên CSDL THẬT cho nhịp chi ngân sách (dự án C việc hai, spec mục 7.3).
/// CHẠY TAY, mặc định bỏ qua.
///
/// ```bash
/// ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
/// export MSYS_NO_PATHCONV=1
/// D=app_flutter/flowmoney.db
/// for E in "" "-wal"; do
///   "$ADB" exec-out "run-as com.flowmoney.flowmoney cat $D$E" > /tmp/that.db$E
/// done
/// FLOWMONEY_DB=/tmp/that.db FLOWMONEY_IDACCOUNT=10 \
///   flutter test test/tool/do_nhip_chi_test.dart --run-skipped
/// ```
///
/// Với từng ngân sách ĐANG CHẠY in: chu kỳ · số kỳ đã đóng xét được · số kỳ có chi ·
/// học được chưa · dự phóng cũ → mới · chip cũ → mới. Không `expect` ngoài *có tài khoản*:
/// đây là phép đo. ⚠️ Chép bản gốc ra mỗi lần chạy — mở tệp `.db` là SQLite checkpoint
/// và xoá `-wal`. ĐỪNG chép `-shm` lệch pha. `run-as` chỉ đọc được bản **debug**.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/ai_edge/domain/tai_phan_bo.dart';
import 'package:flowmoney/features/budget/data/datasources/budget_local_data_source.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository_impl.dart';
import 'package:flowmoney/features/budget/domain/budget_history.dart';
import 'package:flowmoney/features/budget/domain/budget_pace.dart';
import 'package:flowmoney/features/budget/domain/nhip_chi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final duong = Platform.environment['FLOWMONEY_DB'];
  final idaccount =
      int.tryParse(Platform.environment['FLOWMONEY_IDACCOUNT'] ?? '');

  test(
    'CSDL thật: nhịp chi từng ngân sách đang chạy',
    () async {
      expect(duong, isNotNull,
          reason: 'đặt FLOWMONEY_DB=<tệp sqlite đã chép>');
      expect(idaccount, isNotNull,
          reason: 'đặt FLOWMONEY_IDACCOUNT=<mã tài khoản>');
      expect(File('$duong-wal').existsSync(), isTrue,
          reason: 'thiếu -wal thì phép đo nói dối (bẫy 4.9)');

      final db = AppDatabase.forTesting(NativeDatabase(File(duong!)));
      addTearDown(db.close);
      final now = DateTime.now();
      final nguon = BudgetLocalDataSourceImpl(db: db);
      final repo = BudgetRepositoryImpl(
          localDataSource: nguon, syncEngine: null, clock: () => now);
      final moc = await nguon.mocGiaoDichDauTien(idaccount!);
      final dangChay = [
        for (final v in await repo.getBudgets(idaccount, now: now))
          if (!v.budget.isExpired(now)) v,
      ];
      // ignore: avoid_print
      print('ROW| tài khoản $idaccount · giao dịch đầu tiên $moc · '
          '${dangChay.length} ngân sách đang chạy');

      final nhip = await repo.nhipChiTheoNganSach(
          idaccount, [for (final v in dangChay) v.budget],
          now: now);
      for (final v in dangChay) {
        final b = v.budget;
        final ky = kyDaDongTruoc(b,
            now: now, mocDauTien: moc, toiDa: kSoKyHocToiDa);
        var coChi = 0;
        for (final k in ky) {
          final s = await nguon.sumExpenses(
              idaccount: idaccount,
              categoryId: b.categoryId,
              from: k.from,
              to: k.to);
          if (s > 0) coChi++;
        }
        final n = nhip[b.id];
        final muc = b.categoryId == null
            ? null
            : await repo.suggestAmount(idaccount, b.categoryId!, now: now);
        final cu = duPhongCua(v, now: now, mucThang: muc);
        final moi = duPhongCua(v, now: now, mucThang: muc, nhipChi: n);
        // ignore: avoid_print
        print('ROW| ${v.displayName} · ${b.timeRecurrence ?? 'Ngày cụ thể'} · '
            'bắt đầu ${b.startDate} · kỳ xét ${ky.length} · có chi $coChi · '
            'học ${n == null ? 'KHÔNG' : 'CÓ (${n.soKy} kỳ)'} · '
            'dự phóng $cu → $moi · chip ${budgetPaceOf(b, now).status.name} → '
            '${budgetPaceOf(b, now, nhipChi: n).status.name}');
      }
      expect(idaccount, greaterThan(0));
    },
    skip: 'chạy tay: xem docstring',
  );
}
