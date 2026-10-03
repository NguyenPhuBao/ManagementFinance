/// Chia sẻ biên lai — thư mục ảnh trong vùng riêng của app (`filesDir/bien_lai/`, do `NhanBienLaiActivity` ghi).
///
/// MỘT luật (spec `2026-10-02-chia-se-bien-lai-design.md` mục 7): ảnh sống khi còn một hàng loại 20 hoặc một dòng
/// hàng chờ trỏ tới nó. Xoá ngay ở Lưu / Bỏ qua ([xoa]); [donMoCoi] là lưới an toàn ở mỗi lượt nhập; [xoaHet] lúc
/// đăng xuất. Không hàm nào ở đây ném — dọn ảnh hỏng chỉ tốn dung lượng.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'ten_tep_bien_lai.dart';

class KhoBienLai {
  KhoBienLai({required this.thuMuc});

  /// `filesDir` phía Kotlin ↔ `getApplicationSupportDirectory()`.
  final Future<Directory> Function() thuMuc;

  Future<Directory> _anh() async => Directory('${(await thuMuc()).path}/$kThuMucBienLai');

  /// Đường dẫn tệp ảnh; `null` khi tên không hợp lệ ([tenTepBienLaiHopLe] — tên đến từ deeplink) hoặc tệp không còn.
  Future<String?> duongDan(String tep) async {
    if (!tenTepBienLaiHopLe(tep)) return null;
    try {
      final f = File('${(await _anh()).path}/$tep');
      return f.existsSync() ? f.path : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> xoa(String? tep) async {
    if (tep == null || !tenTepBienLaiHopLe(tep)) return;
    try {
      final f = File('${(await _anh()).path}/$tep');
      if (f.existsSync()) f.deleteSync();
    } catch (e) {
      debugPrint('[BienLai] xoá ảnh hỏng: ${e.runtimeType}');
    }
  }

  /// Xoá mọi ảnh KHÔNG nằm trong [conDung]; trả số tệp đã xoá.
  Future<int> donMoCoi(Set<String> conDung) async {
    try {
      final d = await _anh();
      if (!d.existsSync()) return 0;
      var n = 0;
      for (final f in d.listSync().whereType<File>()) {
        if (conDung.contains(f.uri.pathSegments.last)) continue;
        await f.delete();
        n++;
      }
      return n;
    } catch (e) {
      debugPrint('[BienLai] dọn ảnh mồ côi hỏng: ${e.runtimeType}');
      return 0;
    }
  }

  /// Thư mục ảnh + tệp hàng chờ (kể cả bản `.dang_nhap` của một lượt nhập dở).
  Future<void> xoaHet() async {
    try {
      final goc = await thuMuc();
      final d = await _anh();
      if (d.existsSync()) await d.delete(recursive: true);
      for (final ten in [kTepBienLaiCho, '$kTepBienLaiCho.dang_nhap']) {
        final f = File('${goc.path}/$ten');
        if (f.existsSync()) f.deleteSync();
      }
    } catch (e) {
      debugPrint('[BienLai] xoá hết hỏng: ${e.runtimeType}');
    }
  }
}
