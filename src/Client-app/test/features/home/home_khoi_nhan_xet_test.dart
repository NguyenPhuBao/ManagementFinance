/// Trang chủ thay thẻ "Insight AI" tĩnh bằng khối Nhận xét thật (Edge-SLM P2,
/// Task 14 — đóng A6).
///
/// Thẻ cũ là một đoạn chữ cứng "Thêm thêm giao dịch… để trợ lý AI phân tích"
/// — một lời hứa không bao giờ đổi, dù người dùng đã có ba tháng dữ liệu. Nay
/// thẻ ấy là `KhoiNhanXet(nenToi: true)` đọc `GoiSoTrangChu.tu(...)` với đúng
/// các con số trang đang hiện.
///
/// ## Vì sao quét nguồn chứ không dựng widget
///
/// Cùng lý do với `trang_chu_gon_test.dart`: dựng `HomePage` thật đòi `GetIt`
/// và bảy stream; một ca như thế đỏ vì những lý do chẳng liên quan. Ba điều
/// canh ở đây đều là *sự có mặt* của một lời gọi trong nguồn.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final nguon = File('lib/features/home/presentation/pages/home_page.dart')
      .readAsStringSync();

  test('không còn thẻ "Insight AI" tĩnh', () {
    expect(nguon.contains('Insight AI'), isFalse,
        reason: 'A6: thẻ này là chữ cứng, không đọc dữ liệu nào của người '
            'dùng.');
    expect(nguon.contains('_buildInsightCard'), isFalse);
    expect(nguon.contains('Thêm thêm'), isFalse,
        reason: 'Lỗi chính tả "Thêm thêm" sống cùng thẻ cũ; mất thẻ thì mất '
            'nó.');
  });

  test('có khối Nhận xét nền tối đọc gói số Trang chủ', () {
    expect(nguon.contains('KhoiNhanXet('), isTrue,
        reason: 'Khối dùng chung của bốn màn (Stitch b396533b…, biến thể nền '
            'tối).');
    expect(nguon.contains('GoiSoTrangChu.tu('), isTrue,
        reason: 'Gói số nhận ĐÚNG con số trang đang hiện (thu/chi tháng, '
            'tổng số dư, danh sách ngân sách) — lớp AI không tự cộng gì.');
    expect(nguon.contains('nenToi: true'), isTrue,
        reason: 'Trang chủ dùng biến thể nền tối, thay đúng chỗ thẻ cũ.');
  });
}
