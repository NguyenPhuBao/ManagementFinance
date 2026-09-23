// lib/features/ai_edge/domain/canary_cong_cu.dart
/// Dấu canary cho **phiên có tool** (bước 1b, 2026-09-23) — bẫy 4.33
/// `AI_EDGE_FEATURE.md`.
///
/// ## Vì sao có
///
/// Với `flutter_gemma_litertlm` 1.7.0, phiên có tool bật giải mã có ràng buộc
/// và engine **sập native** ngay lượt giải mã đầu — trên cả hai máy đo, kể cả
/// câu không cần tool. `try/catch` vô dụng: app văng ở **mọi** câu hỏi. Bản
/// 1.9.0 / 1.8.0 hết sập trên hai máy ấy, nhưng máy khác chưa đo. Canary là
/// lưới cho máy chưa đo: ghi một dấu **trước** khi engine giải mã, gỡ khi lượt
/// có sự kiện đầu tiên; dấu còn sót ở lần mở sau là lần trước chết giữa chừng.
///
/// ## Vì sao KHÔNG chép nguyên khuôn canary GPU
///
/// Dấu sót **không** tự nó là bằng chứng sập. Realme giết app khi vuốt khỏi
/// Recents (đo 2026-09-22), hệ điều hành giết khi thiếu RAM, người dùng bấm
/// Buộc dừng — cả ba để dấu lại y hệt một cú sập. Khuôn GPU ("dấu sót = hỏng,
/// vĩnh viễn") mà áp ở đây thì một lần vuốt app giữa lúc trợ lý đang nghĩ là
/// mất bậc tool **vĩnh viễn** trên máy ấy, im lặng — và rơi đúng vào máy chậm,
/// nơi chờ 10–15 giây dễ khiến người ta bỏ đi. Người dùng chốt **lối B**:
///
/// - Android 11+ (API 30) cho biết **lý do** từng lần tiến trình chết
///   (`ApplicationExitInfo`, qua kênh `flowmoney/ly_do_thoat` ở
///   `MainActivity`). Chỉ tắt bậc tool khi lần thoát **đầu tiên sau lúc đặt
///   dấu** là [kLyDoSapNative]; mọi lý do khác chỉ xoá dấu.
/// - Không biết lý do (Android 10 trở xuống, hoặc không có bản ghi nào sau lúc
///   đặt dấu): tắt khi dấu sót **hai lần liền** — một lượt chạy trơn ở giữa
///   đếm lại từ đầu.
/// - Dấu "hỏng" ghi **phiên bản app** và tự xoá khi app lên bản mới: bản mới
///   có thể đã nâng engine, tắt vĩnh viễn là không bao giờ biết.
///
/// Ba tệp cục bộ, cạnh tệp mô hình; không schema, không đồng bộ — chúng là tài
/// sản của **máy**, cùng lối `canary_gpu.dart`.
library;

import 'dart:io';

/// Có mặt = một lượt sinh của phiên có tool đang ở khoảng trước sự kiện đầu
/// tiên (hoặc đã chết ở khoảng ấy). Nội dung: mốc đặt dấu, mili giây epoch.
const String kTepCanaryCongCu = 'slm_cong_cu_dang_thu';

/// Có mặt = phiên có tool từng làm app sập native trên máy này. Nội dung:
/// phiên bản app lúc ghi (`versionCode`), rỗng khi không đọc được.
const String kTepCongCuHong = 'slm_cong_cu_hong';

/// Số lần dấu sót **liền nhau** không rõ lý do — chỉ dùng khi hệ điều hành
/// không cho biết lý do thoát.
const String kTepCongCuSot = 'slm_cong_cu_sot';

/// `ApplicationExitInfo.REASON_CRASH_NATIVE` của Android.
const int kLyDoSapNative = 5;

/// Một lần tiến trình của app chết, theo hệ điều hành.
class LanThoat {
  /// Hằng `REASON_*` của `ApplicationExitInfo`.
  final int lyDo;
  final DateTime luc;
  const LanThoat({required this.lyDo, required this.luc});
}

/// Nguồn "vì sao lần trước app chết" — giao diện thuần; bản thật nói chuyện
/// với `MainActivity` qua kênh native (`data/nguon_ly_do_thoat.dart`).
abstract class NguonLyDoThoat {
  /// Các lần tiến trình của app chết gần đây, theo bất kỳ thứ tự nào. `null`
  /// là **không biết**: Android 10 trở xuống, nền tảng khác, hoặc kênh lỗi.
  Future<List<LanThoat>?> cacLanThoat();

  /// Phiên bản app đang chạy (`versionCode`); `null` khi không đọc được.
  Future<int?> phienBan();
}

/// Máy này từng sập native ở phiên có tool — `SlmRuntime.moPhien` ném lỗi này
/// thay vì mở phiên, và vòng lặp tool rơi về bậc 1 (L1), im lặng.
class BacCongCuDaTat implements Exception {
  const BacCongCuDaTat();
  @override
  String toString() =>
      'BacCongCuDaTat: phiên có tool từng làm app sập native trên máy này';
}

class CanaryCongCu {
  final Future<Directory> Function() thuMuc;
  final NguonLyDoThoat nguon;
  final DateTime Function() dongHo;

  CanaryCongCu({
    required this.thuMuc,
    required this.nguon,
    DateTime Function()? dongHo,
  }) : dongHo = dongHo ?? DateTime.now;

  Future<File> _tep(String ten) async => File('${(await thuMuc()).path}/$ten');

  /// Xét dấu sót của lần chạy trước, **rồi xoá nó**. Gọi lúc app khởi động —
  /// khi lịch sử lý do thoát của Android còn nguyên bản ghi của cú sập — và
  /// lại một lần trước mỗi phiên ([daTat]). Không có dấu thì không hỏi hệ điều
  /// hành gì. Không bao giờ ném: phép này chạy ở đường khởi động.
  Future<void> xetDauSot() async {
    try {
      final canary = await _tep(kTepCanaryCongCu);
      if (!canary.existsSync()) return;
      final lucDat = _mocDat(canary);

      bool? sap; // null = không biết lý do
      final ds = await nguon.cacLanThoat();
      if (ds != null) {
        // Lần thoát ĐẦU TIÊN sau lúc đặt dấu — của chính tiến trình giữ dấu.
        // Lấy bản ghi mới nhất là đọc nhầm một tiến trình về sau (chẳng hạn
        // bị buộc dừng trước khi kịp xét dấu) và bỏ qua đúng cú sập.
        final sau = [
          for (final l in ds)
            if (!l.luc.isBefore(lucDat)) l,
        ]..sort((a, b) => a.luc.compareTo(b.luc));
        if (sau.isNotEmpty) sap = sau.first.lyDo == kLyDoSapNative;
      }

      final sot = await _tep(kTepCongCuSot);
      if (sap == null) {
        final dem = (_docSo(sot) ?? 0) + 1;
        sap = dem >= 2;
        if (sap) {
          _xoa(sot);
        } else {
          sot.writeAsStringSync('$dem');
        }
      } else {
        _xoa(sot);
      }

      if (sap) {
        final pb = await nguon.phienBan();
        (await _tep(kTepCongCuHong)).writeAsStringSync(pb == null ? '' : '$pb');
      }
      _xoa(canary);
    } catch (_) {
      // Hỏng ở đây thì dấu còn nguyên và được xét lại lần sau.
    }
  }

  /// `true` = máy này từng sập native ở phiên có tool, ở **chính phiên bản app
  /// này** — người gọi không mở phiên. App đã lên bản khác thì dấu "hỏng" được
  /// xoá và bậc tool mở lại; không đọc được phiên bản thì giữ trạng thái tắt,
  /// vì thử lại là liều văng app ở mọi câu hỏi.
  Future<bool> daTat() async {
    await xetDauSot();
    final hong = await _tep(kTepCongCuHong);
    if (!hong.existsSync()) return false;
    final ghi = _docSo(hong);
    final hienTai = await nguon.phienBan();
    if (ghi != null && hienTai != null && ghi != hienTai) {
      _xoa(hong);
      return false;
    }
    return true;
  }

  /// Ghi dấu ngay trước khi engine bắt đầu giải mã một lượt.
  Future<void> batDauLuot() async {
    (await _tep(kTepCanaryCongCu))
        .writeAsStringSync('${dongHo().millisecondsSinceEpoch}', flush: true);
  }

  /// Lượt đã có sự kiện đầu tiên (hoặc kết thúc, ném lỗi thường, bị huỷ): gỡ
  /// dấu. Một lượt chạy trơn cũng xoá bộ đếm dấu sót — "hai lần **liền**".
  Future<void> xongLuot() async {
    _xoa(await _tep(kTepCanaryCongCu));
    _xoa(await _tep(kTepCongCuSot));
  }

  DateTime _mocDat(File canary) {
    final ms = _docSo(canary);
    return ms != null
        ? DateTime.fromMillisecondsSinceEpoch(ms)
        : canary.lastModifiedSync();
  }

  static int? _docSo(File f) {
    if (!f.existsSync()) return null;
    try {
      return int.tryParse(f.readAsStringSync().trim());
    } catch (_) {
      return null;
    }
  }

  static void _xoa(File f) {
    if (!f.existsSync()) return;
    try {
      f.deleteSync();
    } catch (_) {}
  }
}

/// Bọc MỘT lượt sinh của phiên có tool: dấu có mặt từ trước khi [luot] được
/// gọi — tức trước khi engine bắt đầu giải mã — tới sự kiện đầu tiên của lượt.
///
/// Bẫy 4.33: bản engine cũ sập **trước khi phát được gì**; có sự kiện đầu là
/// engine đã qua bước ấy, giữ dấu tiếp chỉ kéo dài cửa sổ báo nhầm. Lượt rỗng,
/// lượt ném lỗi thường, lượt bị huỷ đều gỡ dấu — chỉ cú sập native (không chạy
/// tới `finally`) mới để dấu lại, và đó đúng là thứ cần bắt.
Stream<T> quaCanary<T>(
  Stream<T> Function() luot,
  CanaryCongCu? canary,
) async* {
  if (canary == null) {
    yield* luot();
    return;
  }
  await canary.batDauLuot();
  var daGo = false;
  try {
    await for (final e in luot()) {
      if (!daGo) {
        daGo = true;
        await canary.xongLuot();
      }
      yield e;
    }
  } finally {
    if (!daGo) await canary.xongLuot();
  }
}
