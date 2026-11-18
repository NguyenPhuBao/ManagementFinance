import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../analytics/data/datasources/luu_tep_platform.dart';
import 'datasources/ban_sao_du_lieu_api.dart';

/// Lưu tệp bản sao vào **Tải về** (`MediaStore`, không xin quyền — dùng lại kênh của Xuất báo cáo); máy không làm
/// được thì ghi tệp tạm + sheet chia sẻ (khuôn `XuatTepServiceImpl`). Không ghi gì vào SQLite (đơn mục 52 việc 5).
class LuuTepBanSao {
  const LuuTepBanSao({this.luuTep = const LuuTepPlatform(), this.chiaSe});

  final LuuTepPlatform luuTep;

  /// Tiêm cho test; `null` → tệp tạm + `SharePlus`.
  final Future<void> Function(TepTaiVe tep)? chiaSe;

  /// Đường dẫn hiển thị khi lưu vào Tải về; `null` khi đã lùi về sheet chia sẻ. Ném khi ghi hỏng thật.
  Future<String?> luu(TepTaiVe tep) async {
    final noi = await luuTep.luuVaoTaiVe(ten: tep.ten, mime: tep.mime, bytes: tep.bytes);
    if (noi != null) return noi;
    await (chiaSe ?? _chiaSeMacDinh)(tep);
    return null;
  }

  static Future<void> _chiaSeMacDinh(TepTaiVe tep) async {
    final thuMuc = await getTemporaryDirectory();
    final f = File('${thuMuc.path}/${tep.ten}');
    await f.writeAsBytes(tep.bytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], subject: tep.ten));
  }
}
