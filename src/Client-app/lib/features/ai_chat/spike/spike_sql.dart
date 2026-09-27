/// Spike "E2B tự viết SQL" — đường ĐO TẠM, mục 9.29 `AI_EDGE_FEATURE.md`
/// (2026-09-27). Chỉ sống khi build với `--dart-define=SPIKE_SQL=true`; bản
/// thường hằng [kSpikeSql] là `false` và trình biên dịch loại cả nhánh.
///
/// Câu hỏi trong chat bắt đầu bằng `sql:` đi thẳng vào đây, KHÔNG qua bậc tool,
/// không qua lớp chắn: mô hình nhận lược đồ + luật ngầm + hai ví dụ rồi viết
/// MỘT câu SELECT; câu ấy đi qua hàng rào chỉ-đọc [trichSelect] rồi chạy trên
/// chính SQLite của app, kết quả hiện nguyên hàng. Mục đích duy nhất: trả lời
/// bằng số đo câu hỏi *"nếu cho mô hình đọc thẳng CSDL thì đúng được bao
/// nhiêu"* trước khi quyết giữa tool truy vấn tổng quát và mô hình đọc SQL.
///
/// ⚠️ Không phải tính năng: không có ca nào đảm bảo mô hình viết SQL đúng, và
/// mọi con số ra từ đây là số thật nên SAI SẼ IM LẶNG — đúng lý do spec 9.28
/// khuyên không cho E2B sinh SQL tự do ngoài phép đo.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/database/app_database.dart';
import '../../ai_edge/data/slm_runtime.dart';

/// Bật bằng `flutter build apk --dart-define=SPIKE_SQL=true`.
const bool kSpikeSql = bool.fromEnvironment('SPIKE_SQL');

/// Tiền tố của câu đi vào spike.
const String kTienToSpikeSql = 'sql:';

/// Hàng rào chỉ-đọc quanh chữ mô hình trả về: bỏ rào ```sql```, lấy từ chữ
/// `SELECT` đầu tiên, từ chối khi có câu thứ hai sau dấu `;` hay bất kỳ từ khoá
/// ghi / đọc lược đồ nào, và thêm `LIMIT 20` nếu mô hình chưa đặt. Trả `null`
/// là từ chối — người gọi hiện nguyên chữ mô hình để chấm.
String? trichSelect(String vanBan) {
  var s = vanBan
      .replaceAll(RegExp(r'```(?:sql)?', caseSensitive: false), ' ')
      .trim();
  final i = s.toUpperCase().indexOf('SELECT');
  if (i < 0) return null;
  s = s.substring(i);
  final dauCham = s.indexOf(';');
  if (dauCham >= 0) {
    if (s.substring(dauCham + 1).trim().isNotEmpty) return null;
    s = s.substring(0, dauCham);
  }
  s = s.trim();
  final cam = RegExp(
    r'\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE|ATTACH|DETACH|PRAGMA|VACUUM|REINDEX)\b|pragma_',
    caseSensitive: false,
  );
  if (cam.hasMatch(s)) return null;
  if (!RegExp(r'\bLIMIT\b', caseSensitive: false).hasMatch(s)) s = '$s LIMIT 20';
  return s;
}

int _epoch(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

/// Prompt: lược đồ rút gọn (đúng tên bảng/cột Drift), các luật ngầm mà lược đồ
/// không tự nói, mốc kỳ tính sẵn theo epoch giây, hai ví dụ, rồi câu hỏi.
String promptSpikeSql(
  String cauHoi, {
  required int idaccount,
  required DateTime now,
}) {
  final homNay = DateTime(now.year, now.month, now.day);
  final ngayMai = homNay.add(const Duration(days: 1));
  final thangTu = DateTime(now.year, now.month, 1);
  final thangDen = DateTime(now.year, now.month + 1, 1);
  final thangTruocTu = DateTime(now.year, now.month - 1, 1);
  final tuanTu = homNay.subtract(Duration(days: homNay.weekday - 1));
  final tuanDen = tuanTu.add(const Duration(days: 7));
  final quyTu = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
  final quyDen = DateTime(quyTu.year, quyTu.month + 3, 1);
  final namTu = DateTime(now.year, 1, 1);
  final namDen = DateTime(now.year + 1, 1, 1);
  final y = now.year;
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');

  return '''
Bạn là bộ dịch câu hỏi tiếng Việt sang SQL của SQLite. Chỉ trả về MỘT câu SELECT, không giải thích, không markdown.

Lược đồ (chỉ dùng đúng các bảng và cột này):
transactions(id, idaccount, wallet_id, category_id, amount REAL, type TEXT, note TEXT, date INTEGER, wallet_transfer TEXT, is_deleted INTEGER)
categories(id, name TEXT, classify TEXT, is_deleted INTEGER)
wallets(id, idaccount, name TEXT, type TEXT, balance REAL, status TEXT, include_in_total INTEGER, is_deleted INTEGER)
bills(id, idaccount, name TEXT, amount REAL, due_date INTEGER, pay_status TEXT, category_id, wallet_id, is_deleted INTEGER)
goals(id, idaccount, name TEXT, target_amount REAL, current_amount REAL, start_date INTEGER, target_date INTEGER, is_completed INTEGER, is_deleted INTEGER)
budgets(id, idaccount, category_id, amount REAL, spent REAL, start_date INTEGER, end_date INTEGER, is_deleted INTEGER)

Luật bắt buộc:
- Luôn thêm idaccount = $idaccount và is_deleted = 0 ở mọi bảng có hai cột ấy (categories chỉ cần is_deleted = 0).
- amount luôn dương. Chiều tiền nằm ở transactions.type: 'chi' là khoản chi, 'thu' là khoản thu, 'transfer' là chuyển giữa hai ví (không tính vào chi tiêu hay thu nhập).
- Khi thống kê thu/chi phải bỏ các khoản có category_id IS NULL mà note bắt đầu bằng 'Điều chỉnh số dư' hoặc 'Số dư ban đầu'.
- Mọi cột ngày là epoch GIÂY. Hôm nay là $y-$m-$d. Mốc tính sẵn: hôm nay [${_epoch(homNay)}, ${_epoch(ngayMai)}); tuần này [${_epoch(tuanTu)}, ${_epoch(tuanDen)}); tháng này [${_epoch(thangTu)}, ${_epoch(thangDen)}); tháng trước [${_epoch(thangTruocTu)}, ${_epoch(thangTu)}); quý này [${_epoch(quyTu)}, ${_epoch(quyDen)}); năm nay [${_epoch(namTu)}, ${_epoch(namDen)}). Dùng date >= mốc đầu AND date < mốc cuối.
- bills.pay_status: 'Pending' và 'Overdue' là chưa trả, 'Payed' là đã trả, 'Skipped' là bỏ qua.
- Tên danh mục, ví, hoá đơn, mục tiêu so bằng LOWER(name) = LOWER('...'); nối danh mục qua transactions.category_id = categories.id, ví qua wallet_id = wallets.id.
- Tiền tính bằng đồng, không làm tròn. Câu hỏi "nào / gì / những" thì trả về tên và số tiền, "bao nhiêu" thì trả về SUM hoặc COUNT.

Ví dụ:
Hỏi: Tháng này tôi chi bao nhiêu?
SQL: SELECT SUM(amount) AS tong_chi FROM transactions WHERE idaccount = $idaccount AND is_deleted = 0 AND type = 'chi' AND date >= ${_epoch(thangTu)} AND date < ${_epoch(thangDen)} AND NOT (category_id IS NULL AND (note LIKE 'Điều chỉnh số dư%' OR note LIKE 'Số dư ban đầu%'));
Hỏi: Ví Tiền mặt còn bao nhiêu tiền?
SQL: SELECT name, balance FROM wallets WHERE idaccount = $idaccount AND is_deleted = 0 AND LOWER(name) = LOWER('Tiền mặt');

Hỏi: $cauHoi
SQL:''';
}

/// Chạy trọn một câu spike: sinh → rào → chạy đọc → chữ để hiện. Mọi mốc thời
/// gian in `[SLM][spike]` một dòng ngắn (bẫy 4.31: `debugPrint` tiết lưu log
/// dài), và dòng kết mang khuôn `xong sau N ms:` để script đo bắt được.
Future<String> chaySpikeSql(
  String cauHoi, {
  required SlmRuntime runtime,
  required AppDatabase db,
  required int idaccount,
  DateTime? now,
}) async {
  final dongHo = Stopwatch()..start();
  final prompt =
      promptSpikeSql(cauHoi, idaccount: idaccount, now: now ?? DateTime.now());
  final raw = await runtime.sinh(prompt, tranToken: 220);
  final tSinh = dongHo.elapsedMilliseconds;
  final sql = trichSelect(raw);
  debugPrint('[SLM][spike] sinh $tSinh ms, ${raw.length} ký tự, '
      'prompt ${prompt.length} ký tự, rào: ${sql == null ? 'TỪ CHỐI' : 'qua'}');
  if (sql == null) {
    debugPrint('[SLM][spike] xong sau ${dongHo.elapsedMilliseconds} ms: '
        '0 hàng (từ chối)');
    return 'SQL bị từ chối (không phải một câu SELECT):\n${raw.trim()}';
  }
  debugPrint('[SLM][spike] SQL: ${sql.replaceAll('\n', ' ')}');
  try {
    final rows = await db.customSelect(sql).get();
    final ds = rows
        .map((r) => r.data.entries.map((e) => '${e.key}=${e.value}').join(', '))
        .toList();
    debugPrint('[SLM][spike] xong sau ${dongHo.elapsedMilliseconds} ms: '
        '${rows.length} hàng');
    for (final h in ds) {
      debugPrint('[SLM][spike] hàng: $h');
    }
    return 'SQL:\n$sql\n\nKết quả (${rows.length} hàng):\n'
        '${ds.isEmpty ? '(rỗng)' : ds.join('\n')}';
  } catch (e) {
    debugPrint('[SLM][spike] xong sau ${dongHo.elapsedMilliseconds} ms: LỖI $e');
    return 'SQL:\n$sql\n\nLỗi chạy: $e';
  }
}
