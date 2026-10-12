// test/features/transaction/domain/chon_loi_nghe_test.dart
/// C4 §2.2 — app tự chọn lối nghe, không công tắc. ⚠️ Chuỗi mã lỗi của `speech_to_text` lấy theo tài liệu gói, CHƯA đo
/// trên máy (spec mục 9) — sửa hằng ở `chon_loi_nghe.dart` nếu máy trả khác.
library;

import 'package:flowmoney/features/transaction/domain/chon_loi_nghe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chonLoiNghe — bảng 2.2', () {
    for (final (coMang, android, gemma, uuTien, ky) in [
      (true, true, true, false, LoiNghe.android),
      (true, true, false, false, LoiNghe.android),
      (false, true, true, false, LoiNghe.gemma),
      (false, true, false, false, LoiNghe.androidTrenMay),
      (false, false, true, false, LoiNghe.gemma),
      (true, false, true, false, LoiNghe.gemma), // có mạng mà máy không có dịch vụ nhận dạng
      (false, false, false, false, null),
      (true, false, false, false, null),
      (true, true, true, true, LoiNghe.gemma), // vừa mất mạng giữa chừng ở lối Android
      (true, true, false, true, LoiNghe.android), // ưu tiên Gemma mà Gemma không sẵn sàng → như thường
    ]) {
      test('mạng=$coMang android=$android gemma=$gemma ưuTiênGemma=$uuTien → $ky', () {
        expect(chonLoiNghe(coMang: coMang, androidSanSang: android, gemmaSanSang: gemma, uuTienGemma: uuTien), ky);
      });
    }
  });

  group('thongBaoChoLoiAndroid', () {
    test('mất mạng + Gemma sẵn sàng → gợi ý nói lại bằng AI trên máy', () {
      expect(thongBaoChoLoiAndroid('error_network', gemmaSanSang: true), ThongBaoNghe.matMangThuGemma);
      expect(thongBaoChoLoiAndroid('error_server', gemmaSanSang: true), ThongBaoNghe.matMangThuGemma);
    });
    test('thiếu gói tiếng Việt + Gemma sẵn sàng → câu riêng, không phải "mất mạng"', () {
      for (final ma in ['error_language_unavailable', 'error_language_not_supported']) {
        expect(thongBaoChoLoiAndroid(ma, gemmaSanSang: true), ThongBaoNghe.khongCoGoiThuGemma,
            reason: 'C4 P9: có mạng mà máy thiếu gói tiếng Việt — câu "Mất mạng" sai nghĩa');
        expect(thongBaoChoLoiAndroid(ma, gemmaSanSang: false), ThongBaoNghe.khongCoLoi);
      }
    });
    test('mất mạng, không Gemma → không có lối nào', () {
      expect(thongBaoChoLoiAndroid('error_network_timeout', gemmaSanSang: false), ThongBaoNghe.khongCoLoi);
    });
    test('không nghe được gì → nói lại', () {
      expect(thongBaoChoLoiAndroid('error_no_match', gemmaSanSang: true), ThongBaoNghe.khongNgheRo);
      expect(thongBaoChoLoiAndroid('error_speech_timeout', gemmaSanSang: false), ThongBaoNghe.khongNgheRo);
    });
    test('quyền / lạ', () {
      expect(thongBaoChoLoiAndroid('error_permission', gemmaSanSang: true), ThongBaoNghe.tuChoiQuyen);
      expect(thongBaoChoLoiAndroid('error_busy', gemmaSanSang: true), ThongBaoNghe.loiChung);
    });
  });

  test('mỗi thông báo có một câu, không câu nào trùng', () {
    final cau = ThongBaoNghe.values.map(cauThongBaoNghe).toList();
    expect(cau.toSet(), hasLength(cau.length));
    expect(cau.every((c) => c.isNotEmpty), isTrue);
  });

  test('hai thông báo "nói lại bằng AI trên máy" → lượt sau đi Gemma (kThuGemmaLuotSau)', () {
    expect(kThuGemmaLuotSau, {ThongBaoNghe.matMangThuGemma, ThongBaoNghe.khongCoGoiThuGemma});
  });

  test('ghim nguyên văn hai câu hứa nói lại bằng AI trên máy', () {
    expect(cauThongBaoNghe(ThongBaoNghe.khongCoGoiThuGemma),
        'Máy không có gói tiếng Việt — bấm micro nói lại bằng AI trên máy');
    expect(
        cauThongBaoNghe(ThongBaoNghe.matMangThuGemma), 'Mất mạng — bấm micro nói lại, lần này nghe bằng AI trên máy');
  });
}
