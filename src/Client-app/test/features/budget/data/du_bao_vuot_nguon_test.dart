// Bản thử NCKH, tầng 2: ĐƯỜNG DỮ LIỆU của app cho xác suất vượt ngân sách. Mỗi người trong
// `research/.../results/app_drift_cases.json` (`python -u app_drift_cases.py`, 300 người TabFormer-VN, giao dịch thật
// kèm giờ phút) được nạp vào một CSDL Drift trong bộ nhớ đúng lược đồ app, cộng năm loại hàng app PHẢI bỏ qua; rồi
// hỏi `DuBaoVuotNguonImpl` như trang chi tiết ngân sách. Kết quả phải bằng số Python (`core.py`, M3 hệ số cố định)
// tới 1e-6. Tóm tắt ghi ra `results/app_drift.json`. Thiếu tệp ca (máy khác) thì bỏ qua.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/data/datasources/budget_local_data_source.dart';
import 'package:flowmoney/features/budget/data/du_bao_vuot_nguon.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flutter_test/flutter_test.dart';

const _thuMuc = '../../research/du-bao-vuot-ngan-sach/experiment/results';
const _id = 7;
const _vi = '11111111-1111-4111-8111-111111111111';
const _vi2 = '44444444-4444-4444-8444-444444444444';
const _anUong = '33333333-3333-4333-8333-333333333333';

void main() {
  final tep = File('$_thuMuc/app_drift_cases.json');

  test('300 người: DuBaoVuotNguon trên CSDL Drift = core.py (Python) tới 1e-6', () async {
    final ca = (jsonDecode(tep.readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final lechMax = List<double>.filled(4, 0);
    final dongLech = List<int>.filled(4, 0);
    var soGiaoDich = 0, rong = 0;
    final dongHo = Stopwatch()..start();
    for (final c in ca) {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final y = c['y'] as int, mo = c['mo'] as int, t = c['t'] as int;
        final now = DateTime(y, mo, t, 23, 59, 59);
        final cap = DateTime(2000);
        for (final (id, ten) in [(_vi, 'Tiền mặt'), (_vi2, 'Tiết kiệm')]) {
          await db.walletDao.insert(WalletsCompanion(
            id: Value(id), idaccount: const Value(_id), name: Value(ten), balance: const Value(0), updatedAt: Value(cap)));
        }
        await db.categoryDao.insert(CategoriesCompanion(
          id: const Value(_anUong), idaccount: const Value(_id), name: const Value('Ăn uống'),
          classify: const Value('chi'), updatedAt: Value(cap)));
        final tx = (c['tx'] as List).cast<List<dynamic>>();
        soGiaoDich += tx.length;
        var n = 0;
        TransactionsCompanion hang(DateTime ngay, double tien, String loai,
                {String? cat, String note = '', String? den, DateTime? xoa}) =>
            TransactionsCompanion(
              id: Value('t${n++}'), idaccount: const Value(_id), walletId: const Value(_vi),
              walletTransfer: Value(den), categoryId: Value(cat), amount: Value(tien), type: Value(loai),
              note: Value(note), date: Value(ngay), deletedAt: Value(xoa), updatedAt: Value(cap));
        var dau = DateTime(9999);
        final hangs = <TransactionsCompanion>[];
        for (final r in tx) {
          final ngay = DateTime(r[0] as int, r[1] as int, r[2] as int, (r[3] as int) ~/ 60, (r[3] as int) % 60);
          if (ngay.isBefore(dau)) dau = ngay;
          hangs.add(hang(ngay, (r[4] as num).toDouble(), 'chi', cat: _anUong));
        }
        final thangDau = DateTime(dau.year, dau.month);
        // Năm loại hàng app phải BỎ QUA (sai một cái là số đổi):
        hangs.add(hang(DateTime(thangDau.year, thangDau.month - 3, 2), 5000000, 'thu', note: 'Số dư ban đầu'));
        for (var k = DateTime(thangDau.year, thangDau.month); !k.isAfter(now); k = DateTime(k.year, k.month + 1)) {
          hangs.add(hang(DateTime(k.year, k.month, 1, 7), 20000000, 'thu', note: 'Lương'));
        }
        hangs.add(hang(DateTime(y, mo - 1, 15, 9), 50000000, 'chi', note: 'Điều chỉnh số dư'));
        hangs.add(hang(DateTime(y, mo, 1, 9), 30000000, 'transfer', den: _vi2));
        hangs.add(hang(DateTime(y, mo, 1, 10), 40000000, 'chi', cat: _anUong, xoa: DateTime(y, mo, 1, 11)));
        await db.batch((b) => b.insertAll(db.transactions, hangs));

        final nganSach = BudgetEntity(
          id: 'b-tong', idaccount: _id, categoryId: null, amount: (c['B'] as num).toDouble(),
          startDate: DateTime(y, mo, 1), recurrence: true, timeRecurrence: BudgetRecurrence.month, updatedAt: cap);
        final kq = await DuBaoVuotNguonImpl(local: BudgetLocalDataSourceImpl(db: db)).duBao(nganSach, now);
        if (kq == null) {
          rong++;
          continue;
        }
        final mong = (c['exp'] as List).cast<num>();
        final thuc = [kq.p0, kq.p1, kq.p2, kq.p3];
        for (var j = 0; j < 4; j++) {
          final d = (thuc[j] - mong[j].toDouble()).abs();
          if (d > lechMax[j]) lechMax[j] = d;
          if (d > 1e-6) dongLech[j]++;
        }
      } finally {
        await db.close();
      }
    }
    final tomTat = {
      'users': ca.length,
      'transactions': soGiaoDich,
      'null_results': rong,
      'max_abs_diff': {'p0': lechMax[0], 'p1': lechMax[1], 'p2': lechMax[2], 'p3': lechMax[3]},
      'rows_over_1e-6': {'p0': dongLech[0], 'p1': dongLech[1], 'p2': dongLech[2], 'p3': dongLech[3]},
      'ignored_rows_per_user': ['salary each month', 'opening balance 3 months before first expense',
          'balance adjustment 50M', 'transfer 30M', 'deleted expense 40M'],
      'seconds': dongHo.elapsed.inSeconds,
    };
    File('$_thuMuc/app_drift.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(tomTat));
    expect(rong, 0, reason: 'nguồn trả null cho người đủ dữ liệu');
    expect(dongLech, [0, 0, 0, 0], reason: 'lệch Python > 1e-6: $tomTat');
  }, skip: tep.existsSync() ? false : 'thiếu dữ liệu research/ trên máy này', timeout: const Timeout(Duration(minutes: 15)));
}
