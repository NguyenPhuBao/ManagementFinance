/// Sinh tệp báo cáo (lát 2c-2) — phần **thuần**, không đụng hệ tệp.
///
/// Canh chừng điều gì: tệp xuất ra là thứ người dùng mang đi nộp, mở bằng máy
/// khác, và mọi lỗi ở đây đều **im lặng** — Excel vẫn mở được, chỉ là chữ mất
/// dấu, mọi cột dồn làm một, hoặc số tiền hoá thành chữ. Không có exception
/// nào để bám vào, nên phải kiểm từng luật một trên chính chuỗi sinh ra.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/date_symbol_data_local.dart';

import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/features/analytics/domain/xuat_tep.dart';

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN', null));

  DongGiaoDich g({
    required DateTime ngay,
    double soTien = 100000,
    String loai = 'chi',
    String? danhMuc = 'c_an',
    String tenDanhMuc = 'Ăn uống',
    String tenVi = 'Tiền mặt',
    String tieuDe = 'Ăn trưa',
  }) =>
      DongGiaoDich(
        id: '$ngay$tieuDe',
        ngay: ngay,
        soTien: soTien,
        loai: loai,
        categoryId: danhMuc,
        tenDanhMuc: tenDanhMuc,
        mauHex: null,
        icon: null,
        walletId: 'w1',
        tenVi: tenVi,
        tieuDe: tieuDe,
      );

  BaoCao baoCao(List<DongGiaoDich> ds, {double? soDu}) => dungBaoCao(
        ds,
        loc: LocBaoCao(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)),
        soDuHienTai: soDu,
      );

  String csv(BaoCao bc) => csvBaoCao(
        bc,
        nhanVi: 'Tất cả các ví',
        nhanDanhMuc: 'Tất cả danh mục',
        lapNgay: DateTime(2026, 9, 9),
      );

  group('csvBaoCao — mở được bằng Excel tiếng Việt', () {
    test('bắt đầu bằng BOM UTF-8', () {
      final s = csv(baoCao([g(ngay: DateTime(2026, 9, 5))]));
      expect(s.codeUnitAt(0), 0xFEFF,
          reason: 'Không có BOM thì Excel đoán bảng mã và "Ăn uống" thành '
              '"Ăn uống". Tệp vẫn mở được — đó mới là chỗ nguy.');
    });

    test('có dòng khai báo dấu phân cách trước mọi thứ khác', () {
      final s = csv(baoCao([g(ngay: DateTime(2026, 9, 5))]));
      expect(s.substring(1).split('\r\n').first, 'sep=;',
          reason: 'Excel dùng dấu phân cách của LOCALE máy: vi-VN là dấu chấm '
              'phẩy, en-US là dấu phẩy. Không khai báo thì một trong hai bên '
              'mở ra thấy mọi cột dồn vào một.');
    });

    test('kết thúc dòng bằng CRLF', () {
      final s = csv(baoCao([g(ngay: DateTime(2026, 9, 5))]));
      expect(s.contains('\r\n'), isTrue);
    });
  });

  group('csvBaoCao — nội dung', () {
    test('đầu tệp ghi khoảng thời gian với NGÀY CUỐI THẬT', () {
      final s = csv(baoCao([g(ngay: DateTime(2026, 9, 5))]));
      expect(s, contains('01/09/2026'));
      expect(s, contains('30/09/2026'));
      expect(s, isNot(contains('01/10/2026')),
          reason: 'Biên `to` là 01/10 và MỞ — cùng luật với màn Xem trước.');
    });

    test('ghi cả bộ lọc đang áp', () {
      final s = csv(baoCao([g(ngay: DateTime(2026, 9, 5))]));
      expect(s, contains('Tất cả các ví'));
      expect(s, contains('Tất cả danh mục'));
    });

    test('số tiền là SỐ NGUYÊN THÔ, không phân cách nghìn, không ký hiệu tiền',
        () {
      final s = csv(baoCao([g(ngay: DateTime(2026, 9, 5), soTien: 1045000)]));
      expect(s, contains('-1045000'),
          reason: 'Cột số phải cộng được trong Excel. "1.045.000 ₫" là chữ, và '
              'Excel tiếng Việt còn đọc dấu chấm thành dấu thập phân.');
      expect(s, isNot(contains('₫')));
      expect(s, isNot(contains('1.045.000')));
    });

    test('DÒNG GIAO DỊCH: khoản chi mang dấu âm, khoản thu dương', () {
      // Cho danh mục "Ăn uống" hai khoản để tổng của nó (80.000) khác số tiền
      // của từng dòng — nếu không, khẳng định về dấu sẽ khớp nhầm dòng "Tổng
      // chi" hoặc dòng của bảng danh mục và **không canh gì cả**. Bản sai có
      // chủ ý (bỏ dấu ở dòng giao dịch) đã đi lọt đúng vì lý do này.
      final s = csv(baoCao([
        g(ngay: DateTime(2026, 9, 4), loai: 'thu', soTien: 9000000,
            tieuDe: 'Lương', tenDanhMuc: 'Lương', danhMuc: 'c_luong'),
        g(ngay: DateTime(2026, 9, 5), loai: 'chi', soTien: 50000,
            tieuDe: 'Ăn trưa'),
        g(ngay: DateTime(2026, 9, 6), loai: 'chi', soTien: 30000,
            tieuDe: 'Ăn tối'),
      ]));
      expect(s, contains('Ăn trưa;Ăn uống;Tiền mặt;-50000'),
          reason: 'Cùng một cột mà không có dấu thì tổng cột ra tổng THU CỘNG '
              'CHI — một con số không có nghĩa gì.');
      expect(s, contains('Lương;Lương;Tiền mặt;9000000'));
    });

    test('trường chứa dấu phân cách được bọc ngoặc kép', () {
      final s = csv(baoCao([
        g(ngay: DateTime(2026, 9, 5), tieuDe: 'Ăn trưa; có tráng miệng'),
      ]));
      expect(s, contains('"Ăn trưa; có tráng miệng"'),
          reason: 'Ghi chú của người dùng có gì cũng được. Không bọc thì một '
              'dấu chấm phẩy làm lệch mọi cột từ đó về sau.');
    });

    test('dấu ngoặc kép trong nội dung được nhân đôi', () {
      final s = csv(baoCao([
        g(ngay: DateTime(2026, 9, 5), tieuDe: 'Mua "sách" cũ'),
      ]));
      expect(s, contains('"Mua ""sách"" cũ"'));
    });

    test('có đủ ba khối: tổng, chi theo danh mục, và danh sách giao dịch', () {
      final s = csv(baoCao([
        g(ngay: DateTime(2026, 9, 5), soTien: 300000),
        g(ngay: DateTime(2026, 9, 6), loai: 'thu', soTien: 900000),
      ]));
      expect(s, contains('TỔNG QUAN'));
      expect(s, contains('CHI THEO DANH MỤC'));
      expect(s, contains('DANH SÁCH GIAO DỊCH'));
    });

    test('có số dư đầu kỳ và cuối kỳ khi biết dòng tiền', () {
      final s = csv(baoCao([g(ngay: DateTime(2026, 9, 5))], soDu: 5000000));
      expect(s, contains('Số dư đầu kỳ'));
      expect(s, contains('Số dư cuối kỳ'));
    });

    test('không có dòng dòng tiền khi báo cáo không tính được', () {
      final s = csv(baoCao([g(ngay: DateTime(2026, 9, 5))]));
      expect(s, isNot(contains('Số dư đầu kỳ')),
          reason: 'Lọc theo ví thì dòng tiền là `null`. In ra "0" là bịa một '
              'con số mà màn hình cố ý không hiện.');
    });

    test("khoản 'transfer' không nằm trong tệp", () {
      final s = csv(baoCao([
        g(ngay: DateTime(2026, 9, 5), loai: 'transfer', tieuDe: 'Nạp mục tiêu'),
        g(ngay: DateTime(2026, 9, 6), tieuDe: 'Ăn trưa'),
      ]));
      expect(s, isNot(contains('Nạp mục tiêu')));
      expect(s, contains('Ăn trưa'));
    });
  });

  group('pdfBaoCao', () {
    // Đọc thẳng tệp font trong `assets/` — test chạy ở gốc package nên đường
    // dẫn này đúng, và như vậy phép kiểm không cần tới `rootBundle`.
    pw.Font nap(String ten) => pw.Font.ttf(
        ByteData.view(File('assets/fonts/$ten').readAsBytesSync().buffer));

    late pw.Font thuong;
    late pw.Font dam;
    setUpAll(() {
      thuong = nap('Roboto-Regular.ttf');
      dam = nap('Roboto-Bold.ttf');
    });

    Future<Uint8List> pdf(BaoCao bc) => pdfBaoCao(
          bc,
          nhanVi: 'Tất cả các ví',
          nhanDanhMuc: 'Tất cả danh mục',
          lapNgay: DateTime(2026, 9, 9),
          fontThuong: thuong,
          fontDam: dam,
        );

    test('sinh ra một tệp PDF hợp lệ', () async {
      final b = await pdf(baoCao([g(ngay: DateTime(2026, 9, 5))], soDu: 5000000));
      expect(String.fromCharCodes(b.take(5)), '%PDF-',
          reason: 'Bốn ký tự đầu là chữ ký của định dạng; thiếu nó thì không '
              'ứng dụng nào mở được tệp.');
      expect(b.length, greaterThan(1000));
    });

    test('KHÔNG rơi về font mặc định Helvetica', () async {
      final b = await pdf(baoCao([g(ngay: DateTime(2026, 9, 5))]));
      final tho = String.fromCharCodes(b);
      expect(tho.contains('Helvetica'), isFalse,
          reason: 'Helvetica của gói `pdf` KHÔNG có glyph tiếng Việt và mất '
              'dấu **im lặng** — "Ăn uống" in ra thành ô trống hoặc "An uong". '
              'Tệp vẫn mở được, nên chỉ có phép kiểm này bắt được.');
      expect(tho.contains('Roboto'), isTrue,
          reason: 'Font nhúng phải là font mình truyền vào.');
    });

    test('báo cáo rỗng vẫn ra tệp, không nổ', () async {
      final b = await pdf(baoCao([]));
      expect(String.fromCharCodes(b.take(5)), '%PDF-');
    });
  });

  group('tenTepBaoCao', () {
    test('mang khoảng thời gian và đuôi tệp', () {
      final ten = tenTepBaoCao(
          baoCao([g(ngay: DateTime(2026, 9, 5))]),
          duoi: 'csv');
      expect(ten, 'BaoCao_01-09-2026_30-09-2026.csv');
    });

    test('không chứa ký tự cấm của hệ tệp', () {
      final ten = tenTepBaoCao(
          baoCao([g(ngay: DateTime(2026, 9, 5))]),
          duoi: 'pdf');
      for (final c in [r'/', r'\', ':', '*', '?', '"', '<', '>', '|']) {
        expect(ten.contains(c), isFalse,
            reason: 'Ngày dạng 01/09/2026 mang dấu gạch chéo — đặt thẳng vào '
                'tên tệp là tạo thư mục con, hoặc lỗi ghi tệp trên Windows.');
      }
    });
  });
}
