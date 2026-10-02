/// Phép ĐO trên CSDL THẬT cho gợi ý danh mục theo SỐ TIỀN (dự án C, spec
/// `2026-10-02-du-an-c-goi-y-danh-muc-theo-so-tien-design.md` mục 7.3). CHẠY TAY, mặc định bỏ qua.
///
/// ```bash
/// ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
/// export MSYS_NO_PATHCONV=1
/// D=app_flutter/flowmoney.db
/// for E in "" "-wal"; do
///   "$ADB" exec-out "run-as com.flowmoney.flowmoney cat $D$E" > /tmp/that.db$E
/// done
/// FLOWMONEY_DB=/tmp/that.db FLOWMONEY_IDACCOUNT=10 \
///   flutter test test/tool/do_goi_y_so_tien_test.dart --run-skipped
/// ```
///
/// **Phát lại theo thời gian**: với giao dịch thứ i (xếp theo ngày), học từ các giao dịch có ngày TRƯỚC nó rồi đoán
/// nó — đúng thứ người dùng đã thấy nếu tính năng bật từ đầu. Khác leave-one-out của công cụ đo B1
/// (`do_goi_y_danh_muc_test.dart`): ở đó mẫu TƯƠNG LAI cũng được học, nên con số lạc quan hơn.
///
/// In HAI dòng tổng:
/// - **mọi lần mô hình lên tiếng** — số khoản xét · số lần gợi ý · đúng, tách theo CÓ / KHÔNG ghi chú;
/// - **những lần thẻ số tiền THẬT SỰ HIỆN trên màn** — tức B1 (học trên cùng các khoản trước đó) và bảng từ khoá đều
///   im. Thẻ là lớp cuối sau hai nguồn ấy, nên đây mới là con số người dùng trải qua; dòng đầu đếm cả những lần mô
///   hình đoán sai mà người dùng không bao giờ thấy.
///
/// Không `expect` gì ngoài *có ≥ 1 khoản*: đây là phép đo, không phải ca canh. Ngưỡng dừng của spec (mục 7.4): từ 5 lần gợi ý mà đúng dưới 60 % → hỏi người
/// dùng trước khi bật.
///
/// ⚠️ Chép cả `-wal` (bẫy 4.9 `AI_EDGE_FEATURE.md`). ĐỪNG chép `-shm` lệch pha — SQLite tự dựng lại từ `-wal`; đo
/// 2026-10-02: chép cả ba khi app đang chạy thì `-shm` cũ làm phép đọc bỏ qua WAL. `run-as` chỉ đọc được CSDL của bản
/// **debug**.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_suggestion.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/category/data/services/category_suggestion_engine.dart';
import 'package:flowmoney/features/category/domain/gan_hang_loat.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/category/domain/phan_loai_so_tien.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final duong = Platform.environment['FLOWMONEY_DB'];
  final idaccount = int.tryParse(Platform.environment['FLOWMONEY_IDACCOUNT'] ?? '');

  test(
    'CSDL thật: phát lại theo thời gian gợi ý danh mục theo số tiền',
    () async {
      expect(duong, isNotNull, reason: 'đặt FLOWMONEY_DB=<tệp sqlite đã chép>');
      expect(idaccount, isNotNull, reason: 'đặt FLOWMONEY_IDACCOUNT=<mã tài khoản>');
      expect(File('$duong-wal').existsSync(), isTrue, reason: 'thiếu -wal thì phép đo nói dối (bẫy 4.9)');

      final db = AppDatabase.forTesting(NativeDatabase(File(duong!)));
      addTearDown(db.close);

      final txs = (await db.transactionDao.getAll(idaccount!)).toList()..sort((a, b) => a.date.compareTo(b.date));
      // Bảng TRA TÊN giữ cả hàng mặc định toàn cục và hàng đã xoá — chỉ để in tên, KHÔNG dùng làm ứng viên.
      final ten = {
        for (final c in await db.select(db.categories).get())
          if (c.idaccount == idaccount || (c.isDefault && c.idaccount == 0)) c.id: c.name,
      };
      // Ứng viên đi ĐÚNG đường của màn Thêm giao dịch (bài học công cụ đo B1, `9f407e6`).
      final repo = CategoryManagementRepositoryImpl(db: db);
      final danhMuc = await repo.selectableChildrenAll(accountId: idaccount);
      final moiDanhMuc = {for (final c in danhMuc) c.id};
      final tuKhoa = await repo.loadAllKeywords(accountId: idaccount);
      final ungVienTuKhoa = [
        for (final c in danhMuc)
          for (final k in tuKhoa[c.id] ?? const <String>[]) CategoryKeywordCandidate(category: c, keyword: k),
      ];
      const engine = CategorySuggestionEngine();

      ({String loai, String? categoryId, String? ghiChu, double soTien, String walletId, DateTime ngay, bool daXoa})
          rec(Transaction t) => (
                loai: t.type,
                categoryId: t.categoryId,
                ghiChu: t.note,
                soTien: t.amount,
                walletId: t.walletId,
                ngay: t.date,
                daXoa: t.isDeleted,
              );

      var xet = 0;
      final dem = {
        true: [0, 0],
        false: [0, 0],
      }; // có ghi chú? → [gợi ý, đúng]
      final sai = <String>[];
      final dung = <String>[];
      var hien = 0, hienDung = 0; // thẻ số tiền thật sự hiện (B1 + từ khoá im)
      for (final t in txs) {
        // Chỉ xét khoản mà chính nó là một mẫu hợp lệ — có nhãn thật để so.
        if (mauSoTienTu([rec(t)]).isEmpty) continue;
        xet++;
        final bo = BoPhanLoaiSoTien.hoc(mauSoTienTu([
          for (final u in txs)
            if (u.date.isBefore(t.date)) rec(u),
        ]));
        final d = bo.doan(
          chieu: t.type,
          soTien: t.amount,
          ngay: t.date,
          walletId: t.walletId,
          hopLe: hopLeTheoChieu(t.type, danhMuc),
        );
        if (d == null) continue;
        final ghiChu = t.note.trim();
        final coGhiChu = ghiChu.isNotEmpty;
        dem[coGhiChu]![0]++;
        // Hai nguồn đứng TRƯỚC nguồn số tiền trên màn: B1 học trên cùng các khoản trước đó, rồi bảng từ khoá.
        var biChe = '';
        if (coGhiChu) {
          final b1 = BoPhanLoaiGhiChu.hoc(mauHocTu([
            for (final u in txs)
              if (u.date.isBefore(t.date)) (loai: u.type, categoryId: u.categoryId, ghiChu: u.note, ngay: u.date),
          ])).doan(ghiChu, hopLe: moiDanhMuc);
          if (b1 != null) {
            biChe = ' [bị B1 che]';
          } else if (engine.suggest(rawText: ghiChu, candidates: ungVienTuKhoa) != null) {
            biChe = ' [bị từ khoá che]';
          }
        }
        if (biChe.isEmpty) {
          hien++;
          if (d.categoryId == t.categoryId) hienDung++;
        }
        final dong = '${t.amount.toStringAsFixed(0)} "${t.note}" → ${ten[d.categoryId] ?? d.categoryId} '
            '(thật: ${ten[t.categoryId] ?? t.categoryId}; p=${d.xacSuat.toStringAsFixed(2)}, '
            '${d.soLanCung}/${d.soLanTong})$biChe';
        if (d.categoryId == t.categoryId) {
          dem[coGhiChu]![1]++;
          if (dung.length < 15) dung.add(dong);
        } else if (sai.length < 15) {
          sai.add(dong);
        }
      }

      String pt(int a, int b) => b == 0 ? '—' : '${(100 * a / b).toStringAsFixed(1)}%';
      final goiY = dem[true]![0] + dem[false]![0];
      final soDung = dem[true]![1] + dem[false]![1];
      // ignore: avoid_print
      print('ROW| tài khoản $idaccount · ${txs.length} giao dịch · xét $xet · gợi ý $goiY · đúng $soDung '
          '(${pt(soDung, goiY)}) · không ghi chú: ${dem[false]![1]}/${dem[false]![0]} · '
          'có ghi chú: ${dem[true]![1]}/${dem[true]![0]}');
      // ignore: avoid_print
      print('ROW| thẻ số tiền THẬT SỰ HIỆN (B1 và từ khoá im): $hien · đúng $hienDung (${pt(hienDung, hien)})');
      for (final x in dung) {
        // ignore: avoid_print
        print('ROW| đúng: $x');
      }
      for (final x in sai) {
        // ignore: avoid_print
        print('ROW| sai: $x');
      }
      expect(xet, greaterThan(0), reason: 'tài khoản không có khoản nào có nhãn — không có gì để đo');
    },
    skip: 'chạy tay: xem docstring',
  );
}
