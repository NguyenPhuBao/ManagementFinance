// lib/features/ai_edge/data/slm_cache.dart
/// Cache câu theo **dấu vân của gói số** (spec mục 4.5).
///
/// Vì sao cần: `KhoiNhanXet` nghe một stream phát lại sau **mỗi** chu kỳ đồng
/// bộ. Không cache thì mỗi lượt phát là 2,3 giây chạy mô hình cho một gói số y
/// hệt lượt trước — và người dùng thấy câu nhấp nháy.
///
/// LRU chứ không FIFO: gói Trang chủ được đọc mỗi lần mở app, nên nó phải sống
/// sót dù ghi từ lâu. `Map` của Dart giữ **thứ tự chèn**, nên "chạm vào" =
/// xoá rồi chèn lại ở cuối.
library;

import 'dart:convert';
import 'dart:io';

const int kTranCache = 200;

class SlmCache {
  final Future<Directory> Function() thuMuc;
  final Map<String, String> _bo = {};
  File? _tep;

  SlmCache({required this.thuMuc});

  Future<void> nap() async {
    _tep = File('${(await thuMuc()).path}/slm_cache.json');
    if (!_tep!.existsSync()) return;
    try {
      final j = jsonDecode(_tep!.readAsStringSync()) as Map<String, dynamic>;
      _bo
        ..clear()
        ..addAll(j.map((k, v) => MapEntry(k, v as String)));
    } catch (_) {
      // Tệp hỏng (ghi dở vì máy tắt giữa chừng) thì bắt đầu lại từ rỗng. Cache
      // là thứ suy lại được — ném ở đây là làm hỏng cả khối Nhận xét vì một
      // tệp phụ.
      _bo.clear();
    }
  }

  String? doc(String dauVan) {
    final c = _bo.remove(dauVan);
    if (c != null) _bo[dauVan] = c; // chạm vào → thành mới nhất
    return c;
  }

  Future<void> ghi(String dauVan, String cau) async {
    _bo
      ..remove(dauVan)
      ..[dauVan] = cau;
    while (_bo.length > kTranCache) {
      _bo.remove(_bo.keys.first);
    }
    await _luu();
  }

  Future<void> xoaHet() async {
    _bo.clear();
    await _luu();
  }

  Future<void> _luu() async {
    final t = _tep;
    if (t == null) return;
    try {
      t.writeAsStringSync(jsonEncode(_bo));
    } catch (_) {
      // Đĩa đầy hoặc không ghi được: cache trong bộ nhớ vẫn chạy hết phiên.
    }
  }
}
