/// Phép ĐO trên CSDL THẬT cho B1 — gợi ý danh mục học từ ghi chú. CHẠY TAY, mặc định bỏ qua.
///
/// ```bash
/// ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
/// export MSYS_NO_PATHCONV=1
/// D=app_flutter/flowmoney.db
/// for E in "" "-wal" "-shm"; do
///   "$ADB" exec-out "run-as com.flowmoney.flowmoney cat $D$E" > /tmp/that.db$E
/// done
/// FLOWMONEY_DB=/tmp/that.db FLOWMONEY_IDACCOUNT=10 \
///   flutter test test/tool/do_goi_y_danh_muc_test.dart --run-skipped
/// ```
///
/// **Leave-one-out** (spec B1 mục 5): với mỗi mẫu có nhãn, học trên MỌI mẫu trừ nó rồi đoán nó. Báo **độ phủ** (phần
/// trăm mẫu được gợi ý) và **độ đúng** (trong số được gợi ý, phần trăm trúng danh mục người dùng đã chốt), cùng hai số
/// ấy cho **bộ từ khoá cũ** trên cùng mẫu — để biết B1 có hơn không. Không `expect` gì ngoài *có ≥ 1 mẫu*: đây là phép
/// đo, không phải ca canh.
///
/// ⚠️ Chép cả `-wal` và `-shm` (bẫy 4.9 `AI_EDGE_FEATURE.md`). `run-as` chỉ đọc được CSDL của bản **debug**.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_suggestion.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/category/data/services/category_suggestion_engine.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final duong = Platform.environment['FLOWMONEY_DB'];
  final idaccount = int.tryParse(Platform.environment['FLOWMONEY_IDACCOUNT'] ?? '');

  test(
    'CSDL thật: leave-one-out gợi ý học vs bộ từ khoá',
    () async {
      expect(duong, isNotNull, reason: 'đặt FLOWMONEY_DB=<tệp sqlite đã chép>');
      expect(idaccount, isNotNull, reason: 'đặt FLOWMONEY_IDACCOUNT=<mã tài khoản>');
      expect(File('$duong-wal').existsSync(), isTrue,
          reason: 'thiếu -wal thì phép đo nói dối (bẫy 4.9) — chép cả hai');

      final db = AppDatabase.forTesting(NativeDatabase(File(duong!)));
      addTearDown(db.close);

      final txs = await db.transactionDao.getAll(idaccount!);
      // Cặp (ghi chú gốc, mẫu) — cùng bộ lọc với `mauHocTu`, giữ ghi chú có dấu để đoán như trên màn.
      final cap = <(String, MauGhiChu)>[];
      for (final t in txs) {
        final m = mauHocTu([(loai: t.type, categoryId: t.categoryId, ghiChu: t.note, ngay: t.date)]);
        if (m.isNotEmpty) cap.add((t.note, m.single));
      }

      // Bảng TRA TÊN giữ cả hàng mặc định toàn cục (`idaccount = 0`): giao dịch cũ có thể trỏ tới chúng (G41, quy
      // tắc 8 `CLAUDE.md`). Chỉ để in tên — KHÔNG dùng làm ứng viên.
      final ten = {
        for (final c in await db.select(db.categories).get())
          if (c.idaccount == idaccount || (c.isDefault && c.idaccount == 0)) c.id: c.name,
      };
      // Ứng viên đi ĐÚNG đường của màn Thêm giao dịch (`_loadSuggestion`): `selectableChildrenAll` + `loadAllKeywords`.
      // ⚠️ Bản đầu (`8bee5d7`) lấy ứng viên từ bảng tra tên ở trên, tức CẢ hàng toàn cục — mà hàng toàn cục mang
      // cùng từ khoá với bản sao của tài khoản (seed: Ăn uống ↔ `grab`), nên hai danh mục cùng khớp một từ khoá cùng độ
      // dài → bộ từ khoá coi là HOÀ và im. Đo trên Realme 2026-09-29: từ khoá "phủ 0 %" trong khi thẻ trên máy vẫn gợi ý
      // Ăn uống cho "grab" — phép so nghiêng về B1, im lặng.
      final repo = CategoryManagementRepositoryImpl(db: db);
      final danhMuc = await repo.selectableChildrenAll(accountId: idaccount);
      final hopLe = {for (final c in danhMuc) c.id};
      final tuKhoa = await repo.loadAllKeywords(accountId: idaccount);
      final ungVien = [
        for (final c in danhMuc)
          for (final k in tuKhoa[c.id] ?? const <String>[]) CategoryKeywordCandidate(category: c, keyword: k),
      ];
      const engine = CategorySuggestionEngine();

      var phuHoc = 0, dungHoc = 0, phuTk = 0, dungTk = 0;
      final sai = <String>[];
      for (var i = 0; i < cap.length; i++) {
        final (ghiChu, mau) = cap[i];
        final bo = BoPhanLoaiGhiChu.hoc([for (var j = 0; j < cap.length; j++) if (j != i) cap[j].$2]);
        final d = bo.doan(ghiChu, hopLe: hopLe);
        if (d != null) {
          phuHoc++;
          if (d.categoryId == mau.categoryId) {
            dungHoc++;
          } else if (sai.length < 10) {
            sai.add('"$ghiChu" → ${ten[d.categoryId] ?? d.categoryId} (thật: ${ten[mau.categoryId] ?? mau.categoryId})');
          }
        }
        final k = engine.suggest(rawText: ghiChu, candidates: ungVien);
        if (k != null) {
          phuTk++;
          if (k.categoryId == mau.categoryId) dungTk++;
        }
      }

      String pt(int a, int b) => b == 0 ? '—' : '${(100 * a / b).toStringAsFixed(1)}%';
      final n = cap.length;
      // ignore: avoid_print
      print('ROW| mẫu $n · học: phủ ${pt(phuHoc, n)} ($phuHoc) đúng ${pt(dungHoc, phuHoc)} ($dungHoc) · '
          'từ khoá: phủ ${pt(phuTk, n)} ($phuTk) đúng ${pt(dungTk, phuTk)} ($dungTk)');
      for (final x in sai) {
        // ignore: avoid_print
        print('ROW| sai: $x');
      }

      expect(n, greaterThan(0), reason: 'tài khoản không có mẫu có nhãn nào — không có gì để đo');
    },
    skip: 'chạy tay: xem docstring',
  );
}
