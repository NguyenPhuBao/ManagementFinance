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

  test('B1 (chốt 6): gói số Trang chủ bỏ "Tổng số dư" khi quyền net_worth_overview khoá', () {
    // Bỏ dòng chú thích: một lời gọi bị comment không được tính là có.
    final ma = nguon.split('\n').where((d) => !d.trimLeft().startsWith('//')).join('\n');
    expect(ma.contains('builder: (ctx) {'), isTrue,
        reason: 'khối Nhận xét bọc trong một Builder riêng — chỉ Builder ấy dựng lại khi GoiCubit phát');
    expect(ma.contains('final khoaTongSoDu = !ctx.coQuyen(MaQuyen.netWorthOverview);'), isTrue,
        reason: 'đọc quyền bằng context của Builder (ctx), không bằng context của HomePage');
    expect(ma.contains('!context.coQuyen(MaQuyen.netWorthOverview)'), isFalse,
        reason: 'context.coQuyen = watch<GoiCubit> ở cấp HomePage: mỗi lần GoiCubit phát là dựng lại CẢ trang và tạo lại '
            'mọi stream Drift (M2 review toàn nhánh B1)');
    expect(ma.contains('boTongSoDu: khoaTongSoDu'), isTrue,
        reason: 'thẻ Tổng số dư đã là thẻ khoá (Task 8) — chip của khối Nhận xét ngay dưới không được nói lại con số');
  });
}
