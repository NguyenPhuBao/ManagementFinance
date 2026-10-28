/// Vì sao ô nhập màn Trợ lý AI bị khoá — BỐN lý do, bốn câu (tạm ngừng không nút) (spec Premium
/// 2026-10-06 mục 8.1). ⚠️ Basic xét TRƯỚC: không mời người không dùng được
/// đi tải 2,41 GB.
library;

import 'package:flowmoney/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('⭐ B1: tạm ngừng xét TRƯỚC Basic — câu tạm ngừng, không câu "Nâng cấp"', () {
    expect(lyDoKhoa(laPremium: false, tamNgung: true, coTep: true, congTacBat: true), LyDoKhoaHoiDap.tamNgung);
    expect(lyDoKhoa(laPremium: false, tamNgung: true, coTep: false, congTacBat: false, onlineBat: true),
        LyDoKhoaHoiDap.tamNgung);
    expect(cauKhoa(LyDoKhoaHoiDap.tamNgung), 'Trợ lý AI hiện đang tạm ngừng.');
    expect(cauKhoa(LyDoKhoaHoiDap.tamNgung), isNot(contains('Nâng cấp')));
  });

  test('Basic xét TRƯỚC — không mời người không dùng được tải 2,41 GB', () {
    expect(lyDoKhoa(laPremium: false, coTep: false, congTacBat: false),
        LyDoKhoaHoiDap.goiBasic);
    expect(lyDoKhoa(laPremium: false, coTep: true, congTacBat: true),
        LyDoKhoaHoiDap.goiBasic);
  });

  test('Premium: chưa tệp → chuaCoMoHinh; có tệp mà tắt → congTacTat; đủ → null',
      () {
    expect(lyDoKhoa(laPremium: true, coTep: false, congTacBat: true),
        LyDoKhoaHoiDap.chuaCoMoHinh);
    expect(lyDoKhoa(laPremium: true, coTep: true, congTacBat: false),
        LyDoKhoaHoiDap.congTacTat);
    expect(lyDoKhoa(laPremium: true, coTep: true, congTacBat: true), isNull);
  });

  test('cauKhoa giữ hai câu cũ nguyên văn; câu Basic nói Premium, không nói tải',
      () {
    expect(cauKhoa(LyDoKhoaHoiDap.chuaCoMoHinh), kChuaCoMoHinh);
    expect(cauKhoa(LyDoKhoaHoiDap.congTacTat), kCongTacDangTat);
    expect(cauKhoa(LyDoKhoaHoiDap.goiBasic), kGoiBasic);
    expect(kGoiBasic, contains('Premium'));
    expect(kGoiBasic, isNot(contains('tải')));
  });

  group('onlineBat (spec trợ lý online 2026-10-11 §3.5 d)', () {
    test('mặc định false → bảng chân trị cũ không đổi', () {
      expect(lyDoKhoa(laPremium: true, coTep: false, congTacBat: true),
          LyDoKhoaHoiDap.chuaCoMoHinh);
      expect(lyDoKhoa(laPremium: true, coTep: true, congTacBat: false),
          LyDoKhoaHoiDap.congTacTat);
    });
    test('Basic vẫn khoá dù online bật — cả hai đường đều đòi ai_assistant', () {
      expect(
          lyDoKhoa(
              laPremium: false, coTep: true, congTacBat: true, onlineBat: true),
          LyDoKhoaHoiDap.goiBasic);
    });
    test('chưa có mô hình / công tắc tắt nhưng online bật → MỞ (null)', () {
      expect(
          lyDoKhoa(
              laPremium: true, coTep: false, congTacBat: true, onlineBat: true),
          isNull);
      expect(
          lyDoKhoa(
              laPremium: true, coTep: true, congTacBat: false, onlineBat: true),
          isNull);
    });
    test('online tắt → lý do cũ', () {
      expect(
          lyDoKhoa(
              laPremium: true,
              coTep: false,
              congTacBat: false,
              onlineBat: false),
          LyDoKhoaHoiDap.chuaCoMoHinh,
          reason: 'không có tệp xét trước công tắc — hai câu khác nhau (cauKhoaHoiDap)');
    });
  });
}
