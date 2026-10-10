import 'package:drift/drift.dart';

/// Khoá thuê của **hai bộ tự chuyển tiền** (tự trả hoá đơn, trích mục tiêu) — **cục bộ, KHÔNG đi qua đồng bộ**
/// (quy tắc 9 `CLAUDE.md`, test quét 15). Schema v30, spec 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 3.4.
///
/// Vì sao không khoá tệp: engine nền (WorkManager) và engine của app có thể sống **cùng tiến trình**, mà khoá
/// `fcntl` không chặn hai isolate của cùng một tiến trình. SQLite thì tuần tự hoá người ghi giữa các kết nối, nên
/// một câu `UPDATE … WHERE` là nguyên tử.
class KhoaTuChuyenTiens extends Table {
  TextColumn get ten => text()();
  TextColumn get chuSoHuu => text().nullable()();

  /// Mili-giây epoch — số nguyên để câu `UPDATE` so trực tiếp, không qua phép đổi `DateTime` của Drift.
  IntColumn get hetHanMs => integer()();

  @override
  Set<Column> get primaryKey => {ten};
}
