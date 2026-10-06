/// Vì sao ô nhập màn Trợ lý AI bị khoá — BA lý do, ba câu, ba nút (spec Premium
/// 2026-10-06 mục 8.1). ⚠️ Basic xét TRƯỚC: không mời người không dùng được
/// đi tải 2,41 GB.
library;

import 'package:flowmoney/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
