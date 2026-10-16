// lib/features/transaction/domain/chon_loi_nghe.dart
/// C4 §2.2 — chọn lối nghe (Android trước, Gemma dự phòng; người dùng chốt 2026-10-12), mã lỗi của bộ nhận giọng nói
/// Android và câu thông báo. Hàm thuần.
///
/// ⚠️ Mã lỗi là chuỗi của gói `speech_to_text` theo tài liệu gói — CHƯA đo trên máy. Phần kiểm thử ghi chuỗi thật.
library;

enum LoiNghe { android, androidTrenMay, gemma }

enum ThongBaoNghe { tuChoiQuyen, biChanQuyen, khongCoLoi, matMangThuGemma, khongCoGoiThuGemma, khongNgheRo, loiChung }

const Set<String> kLoiMatMang = {'error_network', 'error_network_timeout', 'error_server', 'error_server_disconnected'};
const Set<String> kLoiKhongCoGoi = {'error_language_unavailable', 'error_language_not_supported'};
const Set<String> kLoiKhongNghe = {'error_no_match', 'error_speech_timeout'};
const Set<String> kLoiQuyen = {'error_permission', 'error_insufficient_permissions'};

/// Thông báo hứa "bấm micro nói lại bằng AI trên máy" ⇒ lượt sau đi Gemma (`uuTienGemma: true`). Task 13/14 dùng hằng
/// này, không ghi cứng giá trị enum.
const Set<ThongBaoNghe> kThuGemmaLuotSau = {ThongBaoNghe.matMangThuGemma, ThongBaoNghe.khongCoGoiThuGemma};

/// `null` = không lối nào dùng được. [uuTienGemma]: lượt trước Android báo mất mạng giữa chừng hoặc máy thiếu gói tiếng
/// Việt — âm thanh lượt ấy không có (Android giữ micro), nên lượt này đi Gemma.
LoiNghe? chonLoiNghe({
  required bool coMang,
  required bool androidSanSang,
  required bool gemmaSanSang,
  bool uuTienGemma = false,
}) {
  if (uuTienGemma && gemmaSanSang) return LoiNghe.gemma;
  if (coMang && androidSanSang) return LoiNghe.android;
  if (!coMang && gemmaSanSang) return LoiNghe.gemma;
  if (!coMang && androidSanSang) return LoiNghe.androidTrenMay;
  if (gemmaSanSang) return LoiNghe.gemma;
  return null;
}

ThongBaoNghe thongBaoChoLoiAndroid(String ma, {required bool gemmaSanSang}) {
  if (kLoiMatMang.contains(ma)) {
    return gemmaSanSang ? ThongBaoNghe.matMangThuGemma : ThongBaoNghe.khongCoLoi;
  }
  if (kLoiKhongCoGoi.contains(ma)) {
    return gemmaSanSang ? ThongBaoNghe.khongCoGoiThuGemma : ThongBaoNghe.khongCoLoi;
  }
  if (kLoiKhongNghe.contains(ma)) return ThongBaoNghe.khongNgheRo;
  if (kLoiQuyen.contains(ma)) return ThongBaoNghe.tuChoiQuyen;
  return ThongBaoNghe.loiChung;
}

String cauThongBaoNghe(ThongBaoNghe t) => switch (t) {
      ThongBaoNghe.tuChoiQuyen => 'Cần quyền micro để nói',
      ThongBaoNghe.biChanQuyen => 'Micro đang bị chặn — bật lại trong Cài đặt',
      ThongBaoNghe.khongCoLoi => 'Cần mạng hoặc mô hình AI trên máy để nói',
      ThongBaoNghe.matMangThuGemma => 'Mất mạng — bấm micro nói lại, lần này nghe bằng AI trên máy',
      ThongBaoNghe.khongCoGoiThuGemma => 'Máy không có gói tiếng Việt — bấm micro nói lại bằng AI trên máy',
      ThongBaoNghe.khongNgheRo => 'Không nghe rõ — nói lại nhé',
      ThongBaoNghe.loiChung => 'Không nghe được — thử lại sau',
    };
