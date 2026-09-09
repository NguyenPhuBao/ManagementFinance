/// Tầng thuần của trang **Xuất báo cáo** (lát 2c).
///
/// Canh chừng điều gì: trang Xuất báo cáo từng là **số cứng** — ví bịa
/// ("Techcombank"), lịch sử xuất bịa, nút xuất chỉ hiện snackbar. Nay mọi con
/// số trên màn Xem trước đi qua các hàm dưới đây, và chúng sai thì sai **im
/// lặng**: một khoản rơi khỏi khoảng vì biên đóng/mở, một khoản chuyển ví bị
/// đếm thành chi tiêu, một quý bị cắt còn hai tháng — không exception nào cả,
/// chỉ có con số khác đi trên tờ báo cáo người dùng mang đi nộp.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';

void main() {
  DongGiaoDich g({
    required DateTime ngay,
    double soTien = 100000,
    String loai = 'chi',
    String? danhMuc = 'an_uong',
    String tenDanhMuc = 'Ăn uống',
    String vi = 'vi_1',
    String tenVi = 'Tiền mặt',
    String tieuDe = 'Khoản chi',
  }) =>
      DongGiaoDich(
        id: '$ngay-$soTien-$tieuDe',
        ngay: ngay,
        soTien: soTien,
        loai: loai,
        categoryId: danhMuc,
        tenDanhMuc: tenDanhMuc,
        mauHex: null,
        icon: null,
        walletId: vi,
        tenVi: tenVi,
        tieuDe: tieuDe,
      );

  group('khoangCuaPhamVi — mọi phạm vi đều trả biên [from, to)', () {
    test('Tháng này lấy trọn tháng đang đứng', () {
      final k = khoangCuaPhamVi(PhamViThoiGian.thangNay,
          now: DateTime(2026, 9, 15, 10, 30));
      expect(k.from, DateTime(2026, 9, 1));
      expect(k.to, DateTime(2026, 10, 1));
    });

    test('Tháng trước ở tháng 1 phải lùi sang tháng 12 NĂM TRƯỚC', () {
      final k = khoangCuaPhamVi(PhamViThoiGian.thangTruoc,
          now: DateTime(2026, 1, 20));
      expect(k.from, DateTime(2025, 12, 1),
          reason: 'Trừ 1 vào tháng mà không cuộn năm là báo cáo "tháng trước" '
              'của tháng 1 rỗng trơn — không lỗi nào báo.');
      expect(k.to, DateTime(2026, 1, 1));
    });

    test('Quý này gom đúng ba tháng của quý đang đứng', () {
      final k =
          khoangCuaPhamVi(PhamViThoiGian.quyNay, now: DateTime(2026, 9, 9));
      expect(k.from, DateTime(2026, 7, 1),
          reason: 'Tháng 9 thuộc quý III (7–9), không phải "ba tháng gần đây".');
      expect(k.to, DateTime(2026, 10, 1));
    });

    test('Quý IV kết thúc ở 01/01 năm sau', () {
      final k =
          khoangCuaPhamVi(PhamViThoiGian.quyNay, now: DateTime(2026, 12, 31));
      expect(k.from, DateTime(2026, 10, 1));
      expect(k.to, DateTime(2027, 1, 1));
    });

    test('Tuỳ chỉnh: ngày cuối người dùng chọn phải NẰM TRONG báo cáo', () {
      final k = khoangCuaPhamVi(
        PhamViThoiGian.tuyChinh,
        now: DateTime(2026, 9, 9),
        tuyChon: (from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30)),
      );
      expect(k.from, DateTime(2026, 9, 1));
      expect(k.to, DateTime(2026, 10, 1),
          reason: 'Bộ chọn ngày trả 00:00, nên lấy thẳng ngày cuối làm biên '
              '`to` MỞ là mất trọn ngày cuối cùng — người dùng chọn tới 30/09 '
              'mà khoản ngày 30/09 không có trong báo cáo.');
    });

    test('Tuỳ chỉnh qua 29/02 của năm nhuận không mất ngày nào', () {
      final k = khoangCuaPhamVi(
        PhamViThoiGian.tuyChinh,
        now: DateTime(2028, 3, 1),
        tuyChon: (from: DateTime(2028, 2, 1), to: DateTime(2028, 2, 29)),
      );
      expect(k.to, DateTime(2028, 3, 1));
    });

    test('Tuỳ chỉnh thiếu khoảng thì lùi về tháng này chứ không nổ', () {
      final k = khoangCuaPhamVi(PhamViThoiGian.tuyChinh,
          now: DateTime(2026, 9, 9), tuyChon: null);
      expect(k.from, DateTime(2026, 9, 1),
          reason: 'Người dùng bấm "Tuỳ chỉnh" rồi thoát bộ chọn — màn xem '
              'trước vẫn phải mở được.');
    });
  });

  group('dungBaoCao — lọc', () {
    final loc = LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1));

    test('biên `to` MỞ: khoản 00:00 ngày đầu tháng sau không thuộc báo cáo', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 30, 23, 59)),
        g(ngay: DateTime(2026, 10, 1)),
      ], loc: loc);
      expect(bc.soGiaoDich, 1,
          reason: 'Đóng biên `to` là khoản đầu tháng sau bị đếm ở CẢ HAI báo '
              'cáo tháng — cùng quy ước với `bienThang`.');
      expect(bc.tong.chi, 100000);
    });

    test("'transfer' bị loại khỏi cả tổng lẫn danh sách", () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 10), loai: 'transfer', soTien: 500000),
        g(ngay: DateTime(2026, 9, 11), loai: 'chi', soTien: 200000),
      ], loc: loc);
      expect(bc.tong.chi, 200000);
      expect(bc.tong.thu, 0);
      expect(bc.soGiaoDich, 1,
          reason: 'Tiền đổi chỗ (nạp mục tiêu, chuyển giữa hai ví) không phải '
              'thu cũng không phải chi. Để nó trong danh sách thì tổng ở đầu '
              'trang không cộng ra được các dòng bên dưới.');
    });

    test('lọc theo ví bỏ hết khoản của ví khác', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 10), vi: 'vi_1', soTien: 100000),
        g(ngay: DateTime(2026, 9, 11), vi: 'vi_2', soTien: 300000),
      ], loc: LocBaoCao(from: loc.from, to: loc.to, walletId: 'vi_1'));
      expect(bc.soGiaoDich, 1);
      expect(bc.tong.chi, 100000);
    });

    test('lọc theo danh mục giữ đúng danh mục ấy', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 10), danhMuc: 'an_uong', soTien: 100000),
        g(ngay: DateTime(2026, 9, 11), danhMuc: 'di_chuyen', soTien: 300000),
      ], loc: LocBaoCao(from: loc.from, to: loc.to, categoryId: 'an_uong'));
      expect(bc.soGiaoDich, 1);
      expect(bc.tong.chi, 100000);
    });

    test('không lọc gì thì giữ cả khoản chưa phân loại', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 10), danhMuc: null, tenDanhMuc: 'Chưa phân loại'),
      ], loc: loc);
      expect(bc.soGiaoDich, 1,
          reason: 'Khoản `categoryId == null` vẫn là tiền đã tiêu. Bỏ nó là '
              'tổng chi nhỏ hơn tổng các dòng.');
    });
  });

  group('dungBaoCao — chi theo danh mục', () {
    final loc = LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1));

    test('gom theo danh mục, sắp giảm dần, tỉ lệ trên tổng chi', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 2), danhMuc: 'an_uong', soTien: 300000),
        g(ngay: DateTime(2026, 9, 3), danhMuc: 'an_uong', soTien: 200000),
        g(
          ngay: DateTime(2026, 9, 4),
          danhMuc: 'di_chuyen',
          tenDanhMuc: 'Di chuyển',
          soTien: 500000,
        ),
      ], loc: loc);

      expect(bc.theoDanhMuc.map((d) => d.ten).toList(),
          ['Ăn uống', 'Di chuyển'],
          reason: 'Hai danh mục hoà nhau (500k) — thứ tự phải ổn định giữa hai '
              'lần dựng, nếu không mỗi lần mở màn xem trước lại thấy một thứ '
              'tự khác.');
      expect(bc.theoDanhMuc.first.soTien, 500000);
      expect(bc.theoDanhMuc.first.tiLe, closeTo(0.5, 0.0001));
    });

    test('khoản THU không lọt vào bảng chi theo danh mục', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 2), loai: 'thu', soTien: 9000000),
        g(ngay: DateTime(2026, 9, 3), loai: 'chi', soTien: 100000),
      ], loc: loc);
      expect(bc.theoDanhMuc.length, 1);
      expect(bc.theoDanhMuc.single.tiLe, closeTo(1.0, 0.0001),
          reason: 'Chia cho tổng THU + CHI thì mọi tỉ lệ đều nhỏ đi mà thanh '
              'nào cũng vẫn vẽ ra được — sai im lặng.');
    });

    test('không có khoản chi nào thì bảng rỗng, không chia cho 0', () {
      final bc = dungBaoCao(
          [g(ngay: DateTime(2026, 9, 2), loai: 'thu', soTien: 9000000)],
          loc: loc);
      expect(bc.theoDanhMuc, isEmpty);
      expect(bc.tong.thu, 9000000);
    });
  });

  group('dungBaoCao — nhóm theo ngày', () {
    final loc = LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1));

    test('mới nhất trước, và trong một ngày cũng mới nhất trước', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 8, 9), tieuDe: 'Sáng 8/9'),
        g(ngay: DateTime(2026, 9, 8, 20), tieuDe: 'Tối 8/9'),
        g(ngay: DateTime(2026, 9, 10, 12), tieuDe: '10/9'),
      ], loc: loc);

      expect(bc.nhom.map((n) => n.ngay).toList(),
          [DateTime(2026, 9, 10), DateTime(2026, 9, 8)],
          reason: 'Báo cáo đọc từ mới về cũ, giống trang Giao dịch. Sắp tăng '
              'dần là tờ báo cáo mở ra bằng khoản cũ nhất.');
      expect(bc.nhom.last.dong.map((d) => d.tieuDe).toList(),
          ['Tối 8/9', 'Sáng 8/9']);
    });

    test('hai khoản cùng ngày khác giờ nằm CHUNG một nhóm', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 8, 0, 0)),
        g(ngay: DateTime(2026, 9, 8, 23, 59)),
      ], loc: loc);
      expect(bc.nhom.length, 1,
          reason: 'Gom theo `DateTime` nguyên vẹn thay vì theo ngày là mỗi '
              'giao dịch một tiêu đề ngày.');
      expect(bc.nhom.single.dong.length, 2);
    });

    test('báo cáo rỗng: không nhóm nào, tổng bằng 0', () {
      final bc = dungBaoCao([], loc: loc);
      expect(bc.nhom, isEmpty);
      expect(bc.soGiaoDich, 0);
      expect(bc.tong.thu, 0);
      expect(bc.tong.chi, 0);
      expect(bc.rong, isTrue);
    });
  });
}
