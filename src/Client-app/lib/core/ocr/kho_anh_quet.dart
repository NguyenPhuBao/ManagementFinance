/// A5 mục 5.5 — kho ảnh người dùng QUÉT bằng nút Quét ở Trang chủ: `filesDir/anh_quet/`.
///
/// ⚠️ Thư mục RIÊNG, tách khỏi `bien_lai/` của chia sẻ biên lai: `KhoBienLai.donMoCoi` chạy ở mỗi lượt nhập (app
/// resume) và xoá ảnh không có hàng loại 20 trỏ tới — ảnh quét không có hàng nào, dùng chung thư mục là người dùng chuyển
/// app giữa chừng thì ảnh trên form biến mất.
///
/// Mỗi lúc MỘT ảnh, kèm danh sách món (`<tên ảnh>.mon.json`, mục 11.2b). Xoá khi: Lưu / thoát form (form gọi [xoa]),
/// bắt đầu lần quét kế ([luu]), đăng xuất ([xoaHet]). Không hàm nào ném — dọn ảnh hỏng chỉ tốn dung lượng.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../features/transaction/domain/doc_mon_hang.dart';
import '../notification/ten_tep_bien_lai.dart';

const String kThuMucAnhQuet = 'anh_quet';

final RegExp _duoi = RegExp(r'^[a-z0-9]{1,5}$');

class KhoAnhQuet {
  KhoAnhQuet({required this.thuMuc});

  /// `getApplicationSupportDirectory()` (= `filesDir`).
  final Future<Directory> Function() thuMuc;

  Future<Directory> _thuMuc() async => Directory('${(await thuMuc()).path}/$kThuMucAnhQuet');

  /// Xoá mọi ảnh cũ rồi chép [duongDanNguon] vào kho. Trả TÊN tệp (`<uuid>.<đuôi>` — đi vào query của `/add`, nên khớp
  /// `tenTepBienLaiHopLe`); `null` khi chép hỏng.
  Future<String?> luu(String duongDanNguon) async {
    try {
      final nguon = File(duongDanNguon);
      if (!nguon.existsSync()) return null;
      final d = await _thuMuc();
      if (d.existsSync()) d.deleteSync(recursive: true);
      d.createSync(recursive: true);
      final cham = duongDanNguon.lastIndexOf('.');
      final duoi = cham < 0 ? '' : duongDanNguon.substring(cham + 1).toLowerCase();
      final ten = '${const Uuid().v4()}.${_duoi.hasMatch(duoi) ? duoi : 'jpg'}';
      nguon.copySync('${d.path}/$ten');
      return ten;
    } catch (e) {
      debugPrint('[Quet] chép ảnh hỏng: ${e.runtimeType}');
      return null;
    }
  }

  /// Đường dẫn ảnh; `null` khi tên không hợp lệ hoặc tệp không còn.
  Future<String?> duongDan(String tep) async {
    if (!tenTepBienLaiHopLe(tep)) return null;
    try {
      final f = File('${(await _thuMuc()).path}/$tep');
      return f.existsSync() ? f.path : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> luuMon(String tep, List<MonHang> mon) async {
    if (!tenTepBienLaiHopLe(tep)) return;
    try {
      File('${(await _thuMuc()).path}/$tep.mon.json').writeAsStringSync(jsonEncode([for (final m in mon) m.toJson()]));
    } catch (e) {
      debugPrint('[Quet] ghi danh sách món hỏng: ${e.runtimeType}');
    }
  }

  /// Thiếu / hỏng → rỗng (form chỉ còn đường nhập số tiền).
  Future<List<MonHang>> docMon(String tep) async {
    if (!tenTepBienLaiHopLe(tep)) return const [];
    try {
      final f = File('${(await _thuMuc()).path}/$tep.mon.json');
      if (!f.existsSync()) return const [];
      final j = jsonDecode(f.readAsStringSync());
      if (j is! List) return const [];
      return [for (final x in j) if (MonHang.fromJson(x) case final m?) m];
    } catch (_) {
      return const [];
    }
  }

  /// Xoá ảnh và danh sách món của nó.
  Future<void> xoa(String? tep) async {
    if (tep == null || !tenTepBienLaiHopLe(tep)) return;
    try {
      final d = (await _thuMuc()).path;
      for (final f in [File('$d/$tep'), File('$d/$tep.mon.json')]) {
        if (f.existsSync()) f.deleteSync();
      }
    } catch (e) {
      debugPrint('[Quet] xoá ảnh hỏng: ${e.runtimeType}');
    }
  }

  Future<void> xoaHet() async {
    try {
      final d = await _thuMuc();
      if (d.existsSync()) d.deleteSync(recursive: true);
    } catch (e) {
      debugPrint('[Quet] xoá hết hỏng: ${e.runtimeType}');
    }
  }
}
