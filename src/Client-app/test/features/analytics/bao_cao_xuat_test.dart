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

  group('khoangKyTruoc — kỳ liền trước phải cùng "loại", không phải trừ N ngày',
      () {
    test('một tháng dương lịch lùi về ĐÚNG tháng trước', () {
      final k =
          khoangKyTruoc(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1));
      expect(k.from, DateTime(2026, 8, 1));
      expect(k.to, DateTime(2026, 9, 1),
          reason: 'Tháng 9 dài 30 ngày. Trừ 30 ngày để lấy "kỳ trước" ra '
              '02/08–01/09 — lệch một ngày, và con số "so với tháng trước" sai '
              'mà không ai thấy.');
    });

    test('tháng 3 lùi về tháng 2 (28 ngày), không phải 31 ngày trước', () {
      final k =
          khoangKyTruoc(from: DateTime(2026, 3, 1), to: DateTime(2026, 4, 1));
      expect(k.from, DateTime(2026, 2, 1));
      expect(k.to, DateTime(2026, 3, 1));
    });

    test('tháng 1 lùi về tháng 12 NĂM TRƯỚC', () {
      final k =
          khoangKyTruoc(from: DateTime(2026, 1, 1), to: DateTime(2026, 2, 1));
      expect(k.from, DateTime(2025, 12, 1));
    });

    test('một quý lùi về đúng quý liền trước', () {
      final k =
          khoangKyTruoc(from: DateTime(2026, 7, 1), to: DateTime(2026, 10, 1));
      expect(k.from, DateTime(2026, 4, 1));
      expect(k.to, DateTime(2026, 7, 1));
    });

    test('khoảng tuỳ chỉnh lùi đúng bằng độ dài của nó', () {
      final k =
          khoangKyTruoc(from: DateTime(2026, 9, 10), to: DateTime(2026, 9, 20));
      expect(k.to, DateTime(2026, 9, 10),
          reason: 'Kỳ trước phải kết thúc đúng lúc kỳ này bắt đầu — hở một '
              'ngày là một ngày không thuộc kỳ nào.');
      expect(k.from, DateTime(2026, 8, 31));
    });
  });

  group('so với kỳ trước', () {
    test('tổng kỳ trước lấy từ đúng khoảng trước, và tôn trọng bộ lọc ví', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 5), soTien: 200000, vi: 'vi_1'),
        g(ngay: DateTime(2026, 8, 5), soTien: 100000, vi: 'vi_1'),
        g(ngay: DateTime(2026, 8, 6), soTien: 900000, vi: 'vi_2'),
        g(ngay: DateTime(2026, 7, 5), soTien: 500000, vi: 'vi_1'),
      ],
          loc: LocBaoCao(
              from: DateTime(2026, 9, 1),
              to: DateTime(2026, 10, 1),
              walletId: 'vi_1'));

      expect(bc.tong.chi, 200000);
      expect(bc.tongTruoc.chi, 100000,
          reason: 'Bỏ bộ lọc ở kỳ trước là so một ví với tất cả các ví — con '
              'số phần trăm khi ấy vô nghĩa mà vẫn hiện ra bình thường.');
    });

    test('kỳ trước bằng 0 thì phần trăm là null, không phải 100%', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 5), soTien: 200000),
      ], loc: LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)));
      expect(bc.chiSoVoiTruoc, isNull);
    });
  });

  group('dòng tiền — số dư đầu kỳ và cuối kỳ', () {
    final loc = LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1));

    test('cuối kỳ = số dư hiện tại trừ đi phần phát sinh SAU kỳ', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 5), loai: 'chi', soTien: 100000),
        g(ngay: DateTime(2026, 10, 3), loai: 'chi', soTien: 50000),
      ], loc: loc, soDuHienTai: 1000000);

      expect(bc.dongTien!.cuoiKy, 1050000,
          reason: 'App không lưu lịch sử số dư, nên số dư cuối kỳ phải suy '
              'ngược từ số dư HIỆN TẠI. Bỏ bước trừ phần sau kỳ là tờ báo cáo '
              'tháng 9 mang số dư của hôm nay.');
    });

    test('đầu kỳ = cuối kỳ trừ đi thu và chi trong kỳ', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 5), loai: 'thu', soTien: 300000),
        g(ngay: DateTime(2026, 9, 6), loai: 'chi', soTien: 100000),
      ], loc: loc, soDuHienTai: 1000000);

      expect(bc.dongTien!.cuoiKy, 1000000);
      expect(bc.dongTien!.dauKy, 800000);
      expect(bc.dongTien!.dauKy + bc.tong.thu - bc.tong.chi, bc.dongTien!.cuoiKy,
          reason: 'Đây là phép cân của cả tờ báo cáo: đầu kỳ + thu − chi = '
              'cuối kỳ. Lệch là người đọc bắt được ngay.');
    });

    test('chuyển ví KHÔNG làm lệch dòng tiền khi tính trên tất cả các ví', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 5), loai: 'transfer', soTien: 400000),
        g(ngay: DateTime(2026, 10, 5), loai: 'transfer', soTien: 700000),
      ], loc: loc, soDuHienTai: 1000000);

      expect(bc.dongTien!.dauKy, 1000000);
      expect(bc.dongTien!.cuoiKy, 1000000,
          reason: 'Tiền đổi chỗ giữa hai ví của cùng người dùng thì tổng số dư '
              'không đổi.');
    });

    test('lọc theo MỘT ví thì KHÔNG tính dòng tiền', () {
      final bc = dungBaoCao(
        [g(ngay: DateTime(2026, 9, 5))],
        loc: LocBaoCao(from: loc.from, to: loc.to, walletId: 'vi_1'),
        soDuHienTai: 1000000,
      );
      expect(bc.dongTien, isNull,
          reason: 'Với một ví riêng, khoản `transfer` có ảnh hưởng thật tới số '
              'dư nhưng CHIỀU tiền không suy được từ vị trí ví (bẫy đã ghi ở '
              'GOAL_FEATURE). Thà không hiện còn hơn hiện một con số có thể '
              'sai.');
    });

    test('không biết số dư hiện tại thì không bịa ra dòng tiền', () {
      final bc = dungBaoCao([g(ngay: DateTime(2026, 9, 5))], loc: loc);
      expect(bc.dongTien, isNull);
    });
  });

  group('thu theo danh mục', () {
    final loc = LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1));

    test('chỉ gom khoản THU, tỉ lệ tính trên tổng thu', () {
      final bc = dungBaoCao([
        g(
            ngay: DateTime(2026, 9, 2),
            loai: 'thu',
            danhMuc: 'c_luong',
            tenDanhMuc: 'Lương',
            soTien: 9000000),
        g(
            ngay: DateTime(2026, 9, 3),
            loai: 'thu',
            danhMuc: 'c_thuong',
            tenDanhMuc: 'Thưởng',
            soTien: 1000000),
        g(ngay: DateTime(2026, 9, 4), loai: 'chi', soTien: 500000),
      ], loc: loc);

      expect(bc.thuTheoDanhMuc.map((d) => d.ten).toList(), ['Lương', 'Thưởng']);
      expect(bc.thuTheoDanhMuc.first.tiLe, closeTo(0.9, 0.0001),
          reason: 'Chia cho tổng thu, không phải tổng thu cộng chi.');
    });

    test('không có khoản thu nào thì bảng rỗng', () {
      final bc = dungBaoCao([g(ngay: DateTime(2026, 9, 2))], loc: loc);
      expect(bc.thuTheoDanhMuc, isEmpty);
    });
  });

  group('phân bổ theo ví', () {
    final loc = LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1));

    test('gom chi và thu theo từng ví, sắp theo chi giảm dần', () {
      final bc = dungBaoCao([
        g(
            ngay: DateTime(2026, 9, 2),
            vi: 'v1',
            tenVi: 'Tiền mặt',
            soTien: 100000),
        g(
            ngay: DateTime(2026, 9, 3),
            vi: 'v2',
            tenVi: 'Ngân hàng',
            soTien: 300000),
        g(
            ngay: DateTime(2026, 9, 4),
            vi: 'v2',
            tenVi: 'Ngân hàng',
            loai: 'thu',
            soTien: 5000000),
      ], loc: loc);

      expect(bc.theoVi.map((v) => v.ten).toList(), ['Ngân hàng', 'Tiền mặt']);
      expect(bc.theoVi.first.chi, 300000);
      expect(bc.theoVi.first.thu, 5000000);
      expect(bc.theoVi.first.soGiaoDich, 2);
    });

    test('đã lọc theo một ví thì không cần bảng phân bổ', () {
      final bc = dungBaoCao(
        [g(ngay: DateTime(2026, 9, 2), vi: 'v1')],
        loc: LocBaoCao(from: loc.from, to: loc.to, walletId: 'v1'),
      );
      expect(bc.theoVi, isEmpty,
          reason: 'Một bảng chỉ có đúng một dòng, lặp lại con số đã có ở thẻ '
              'tổng, là rác trên tờ báo cáo.');
    });
  });

  group('số liệu nhanh', () {
    final loc = LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1));

    test('chi trung bình mỗi ngày chia cho SỐ NGÀY CỦA KỲ', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 2), soTien: 300000),
      ], loc: loc);
      expect(bc.soLieu.chiMoiNgay, closeTo(10000, 0.001),
          reason: 'Tháng 9 có 30 ngày: 300.000/30. Chia cho số ngày CÓ giao '
              'dịch là ra 300.000/ngày — con số ấy nói một điều khác hẳn.');
    });

    test(
        'ngày chi nhiều nhất là ngày cộng dồn lớn nhất, không phải khoản lớn nhất',
        () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 2), soTien: 400000),
        g(ngay: DateTime(2026, 9, 3), soTien: 250000),
        g(ngay: DateTime(2026, 9, 3, 20), soTien: 250000),
      ], loc: loc);
      expect(bc.soLieu.ngayChiNhieuNhat, DateTime(2026, 9, 3));
      expect(bc.soLieu.chiNgayNhieuNhat, 500000);
    });

    test('khoản chi lớn nhất là một dòng giao dịch thật', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 2), soTien: 400000, tieuDe: 'Thuê nhà'),
        g(ngay: DateTime(2026, 9, 3), loai: 'thu', soTien: 9000000),
      ], loc: loc);
      expect(bc.soLieu.khoanChiLonNhat!.tieuDe, 'Thuê nhà',
          reason: 'Khoản THU to hơn nhưng đây là "khoản chi lớn nhất".');
    });

    test('kỳ rỗng: không chia cho 0, không có ngày nào', () {
      final bc = dungBaoCao([], loc: loc);
      expect(bc.soLieu.chiMoiNgay, 0);
      expect(bc.soLieu.ngayChiNhieuNhat, isNull);
      expect(bc.soLieu.khoanChiLonNhat, isNull);
    });
  });

  group('top khoản chi lớn nhất', () {
    final loc = LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1));

    test('nhiều hơn năm khoản thì chỉ giữ năm, giảm dần', () {
      final bc = dungBaoCao([
        for (var i = 1; i <= 6; i++)
          g(ngay: DateTime(2026, 9, i), soTien: i * 10000.0, tieuDe: 'Khoản $i'),
      ], loc: loc);

      expect(bc.topChi.length, 5);
      expect(bc.topChi.first.tieuDe, 'Khoản 6');
      expect(bc.topChi.map((d) => d.tieuDe), isNot(contains('Khoản 1')));
    });

    test('khoản thu không lọt vào danh sách chi lớn nhất', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 2), loai: 'thu', soTien: 9000000),
        g(ngay: DateTime(2026, 9, 3), loai: 'chi', soTien: 10000),
      ], loc: loc);
      expect(bc.topChi.length, 1);
    });
  });

  group('chuỗi cho biểu đồ — độ chia đổi theo độ dài kỳ', () {
    test('kỳ một tháng chia theo NGÀY, ngày rỗng vẫn giữ chỗ', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 2), soTien: 100000),
      ], loc: LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)));

      expect(bc.chuoi.length, 30);
      expect(bc.chuoi[1].chi, 100000);
      expect(bc.chuoi[0].chi, 0,
          reason: 'Bỏ ngày rỗng là trục co lại, hai ngày cách nhau một tuần '
              'hiện ra như liền kề — cùng bài học với biểu đồ xu hướng 2b.');
    });

    test('kỳ ba tháng chia theo TUẦN, không phải 90 cột', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 7, 15), soTien: 100000),
      ], loc: LocBaoCao(from: DateTime(2026, 7, 1), to: DateTime(2026, 10, 1)));

      expect(bc.chuoi.length, lessThan(20));
      expect(bc.chuoi.length, greaterThan(10));
      expect(bc.chuoi.fold<double>(0, (s, d) => s + d.chi), 100000);
    });

    test('kỳ một năm chia theo THÁNG', () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 3, 15), soTien: 100000),
      ], loc: LocBaoCao(from: DateTime(2026, 1, 1), to: DateTime(2027, 1, 1)));

      expect(bc.chuoi.length, 12);
      expect(bc.chuoi[2].chi, 100000);
    });

    test("'transfer' không vào biểu đồ", () {
      final bc = dungBaoCao([
        g(ngay: DateTime(2026, 9, 2), loai: 'transfer', soTien: 500000),
      ], loc: LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)));
      expect(bc.chuoi.fold<double>(0, (s, d) => s + d.chi), 0);
    });
  });
}
