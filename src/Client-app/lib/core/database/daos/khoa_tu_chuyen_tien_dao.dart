import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/khoa_tu_chuyen_tien_table.dart';

part 'khoa_tu_chuyen_tien_dao.g.dart';

const String _kTen = 'tu_chuyen_tien';

/// Khoá thuê của hai bộ tự chuyển tiền (cục bộ, v30) — xem [KhoaTuChuyenTiens].
@DriftAccessor(tables: [KhoaTuChuyenTiens])
class KhoaTuChuyenTienDao extends DatabaseAccessor<AppDatabase> with _$KhoaTuChuyenTienDaoMixin {
  KhoaTuChuyenTienDao(super.db);

  /// Lấy khoá cho [chu]. `true` = lấy được.
  ///
  /// ⚠️ Hai câu, mỗi câu tự nguyên tử — KHÔNG viết dạng đọc-rồi-ghi: trong WAL hai giao tác trì hoãn cùng đọc "chưa
  /// có khoá" rồi cùng ghi. `INSERT OR IGNORE` gieo hàng; `UPDATE … WHERE` chỉ đổi khi khoá trống hoặc đã hết hạn, và
  /// số hàng bị ảnh hưởng nói ai thắng.
  Future<bool> lay(String chu, DateTime now, {Duration han = const Duration(minutes: 2)}) async {
    await customStatement(
      'INSERT OR IGNORE INTO khoa_tu_chuyen_tiens (ten, chu_so_huu, het_han_ms) VALUES (?, NULL, 0)',
      [_kTen],
    );
    final n = await customUpdate(
      'UPDATE khoa_tu_chuyen_tiens SET chu_so_huu = ?, het_han_ms = ? '
      'WHERE ten = ? AND (chu_so_huu IS NULL OR het_han_ms < ?)',
      variables: [
        Variable.withString(chu),
        Variable.withInt(now.add(han).millisecondsSinceEpoch),
        Variable.withString(_kTen),
        Variable.withInt(now.millisecondsSinceEpoch),
      ],
      updates: {khoaTuChuyenTiens},
      updateKind: UpdateKind.update,
    );
    return n == 1;
  }

  /// Nhả khoá — chỉ khi [chu] đang giữ nó.
  Future<void> nha(String chu) => customUpdate(
        'UPDATE khoa_tu_chuyen_tiens SET chu_so_huu = NULL, het_han_ms = 0 WHERE ten = ? AND chu_so_huu = ?',
        variables: [Variable.withString(_kTen), Variable.withString(chu)],
        updates: {khoaTuChuyenTiens},
        updateKind: UpdateKind.update,
      );
}
