/// Chia sẻ biên lai (spec `2026-10-02-chia-se-bien-lai-design.md`). `NhanBienLaiActivity` (Kotlin) chép ảnh người dùng
/// chia sẻ từ app ngân hàng vào `filesDir/[kThuMucBienLai]/` và nối mỗi ảnh một dòng JSON vào [kTepBienLaiCho]; phía
/// Dart đọc khi app mở. Hai hằng tên tệp khớp TAY với hằng Kotlin — `bien_lai_noi_day_test.dart` canh.
library;

import 'dart:convert';
import 'dart:io';

import '../ocr/che_hinh_dang.dart';
import '../ocr/doc_chu_anh.dart';
import '../ocr/dong_ocr.dart';

const String kTepBienLaiCho = 'bien_lai_cho.jsonl';
const String kThuMucBienLai = 'bien_lai';

/// Nguồn hiển thị khi app gửi không nằm trong `kNguonTheoGoi` (hoặc không lấy được tên gói).
const String kNguonBienLai = 'Biên lai';

final RegExp _tenTep = RegExp(r'^[A-Za-z0-9_-]{4,64}\.[A-Za-z0-9]{1,5}$');

/// Tên tệp ảnh do Kotlin đặt (`<uuid>.<đuôi>`). ⚠️ Tên này đi vào `deeplink` (`anh=`) rồi được ghép thành đường dẫn —
/// không khớp khuôn thì coi như không có ảnh, không bao giờ ghép.
bool tenTepBienLaiHopLe(String tep) => _tenTep.hasMatch(tep);

/// Một dòng Kotlin ghi: `{"tep","goi","luc"}`, `luc` là mili giây epoch (lúc chia sẻ).
typedef DongBienLai = ({String tep, String goi, DateTime luc});

/// `null` = dòng hỏng. Không bao giờ ném.
DongBienLai? docDongBienLai(String dong) {
  try {
    final m = jsonDecode(dong);
    if (m is! Map) return null;
    final tep = m['tep'];
    final goi = m['goi'];
    final luc = m['luc'];
    if (tep is! String || !tenTepBienLaiHopLe(tep) || goi is! String || luc is! int) return null;
    return (tep: tep, goi: goi, luc: DateTime.fromMillisecondsSinceEpoch(luc));
  } catch (_) {
    return null;
  }
}

/// Chế độ thu mẫu — CHỈ nối ở bản debug (DI truyền khi `kDebugMode`): in hình dạng ĐÃ CHE ([cheHinhDang]) của chữ trên
/// từng biên lai đang chờ, để viết mẫu đọc cho một app ngân hàng mà không lộ số tiền / số tài khoản / tên người (quy
/// tắc §13.6 `progress/Client-app.md`). Chỉ ĐỌC — không xoá hàng chờ, không xoá ảnh. Không bao giờ ném.
///
/// `print` chứ không `debugPrint`: `debugPrint` bị tiết lưu và nuốt dòng khi in nhiều (đã vấp ở lượt đo AI).
Future<void> thuMauBienLai({
  required Future<Directory> Function() thuMuc,
  required DocChuAnh docChu,
  void Function(String dong)? inRa,
}) async {
  // ignore: avoid_print
  final ra = inRa ?? print;
  try {
    final dir = await thuMuc();
    final tep = File('${dir.path}/$kTepBienLaiCho');
    if (!tep.existsSync()) return;
    for (final d in await tep.readAsLines()) {
      final r = docDongBienLai(d.trim());
      if (r == null) continue;
      final dong = await docChu.doc('${dir.path}/$kThuMucBienLai/${r.tep}');
      ra('[BienLaiThu] goi=${r.goi} · ${dong.length} dòng chữ');
      for (final h in ghepDongTheoHang(dong).split('\n')) {
        ra('[BienLaiThu]   ${cheHinhDang(h)}');
      }
    }
  } catch (e) {
    // Chỉ KIỂU lỗi: thông báo lỗi của gói đọc ảnh có thể mang đường dẫn tệp.
    ra('[BienLaiThu] hỏng: ${e.runtimeType}');
  }
}
