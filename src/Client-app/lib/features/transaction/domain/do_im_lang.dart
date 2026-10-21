// lib/features/transaction/domain/do_im_lang.dart
/// C4 §2.1 — lối Gemma ghi âm tự dừng: im ~2 giây sau khi đã nói, chưa nói gì sau 6 giây, hoặc đủ 20 giây. Hàm thuần —
/// Cubit gọi [BoDoIm.them] mỗi mẫu biên độ ([kNhipBienDo]). ⚠️ Ngưỡng dBFS chưa đo trên máy (spec mục 9).
library;

/// Nhịp mẫu biên độ của bộ ghi (`record.onAmplitudeChanged`) — thời gian trong Cubit đếm bằng số mẫu × nhịp này.
const Duration kNhipBienDo = Duration(milliseconds: 100);
const Duration kImDeDung = Duration(seconds: 2);
const Duration kNgheToiDa = Duration(seconds: 20);
const Duration kChoTiengDau = Duration(seconds: 6);

/// Từ mức này trở lên là có tiếng nói; dưới là im.
const double kNguongCoTieng = -35;

class BoDoIm {
  bool _daCoTieng = false;
  Duration? _imTu;

  /// Đã có mẫu nào ≥ [kNguongCoTieng] chưa. Dừng vì *chưa nói gì sau 6 giây* thì bản ghi là im lặng — đừng đem đi chép.
  bool get daCoTieng => _daCoTieng;

  /// Thêm một mẫu [dbfs] ở mốc [luc] (tính từ lúc bắt đầu ghi). `true` = nên dừng.
  bool them(double dbfs, Duration luc) {
    if (luc >= kNgheToiDa) return true;
    if (dbfs >= kNguongCoTieng) {
      _daCoTieng = true;
      _imTu = null;
      return false;
    }
    if (!_daCoTieng) return luc >= kChoTiengDau;
    final tu = _imTu ??= luc - kNhipBienDo;
    return luc - tu >= kImDeDung;
  }
}
