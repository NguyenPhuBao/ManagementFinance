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
import 'package:pdf/pdf.dart';
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

  /// Các dòng của **một khối** CSV: từ ngay sau dòng tiêu đề tới dòng trống kế
  /// tiếp.
  ///
  /// Cần nó vì `contains` trên cả tệp khớp nhầm khối khác — nhiều khối dùng
  /// chung một nhãn cột ("Số tiền", "Danh mục"), và một khẳng định khớp nhầm
  /// chỗ là một ca test **không canh gì cả**.
  List<String> khoi(String s, String ten) {
    final dong = s.split('\r\n');
    final i = dong.indexOf(ten);
    if (i < 0) return const [];
    final r = <String>[];
    for (var j = i + 1; j < dong.length; j++) {
      if (dong[j].isEmpty) break;
      r.add(dong[j]);
    }
    return r;
  }

  /// Kỳ tháng 9 có thu 9.000.000 và chi 300.000; kỳ trước (tháng 8) có thu
  /// 8.000.000 và chi 250.000 — tức +12,5% thu và +20,0% chi.
  BaoCao hasoSanh() => baoCao([
        g(
            ngay: DateTime(2026, 8, 10),
            loai: 'thu',
            soTien: 8000000,
            tieuDe: 'Lương tháng 8',
            tenDanhMuc: 'Lương',
            danhMuc: 'c_luong'),
        g(ngay: DateTime(2026, 8, 12), soTien: 250000, tieuDe: 'Chợ tháng 8'),
        g(
            ngay: DateTime(2026, 9, 4),
            loai: 'thu',
            soTien: 9000000,
            tieuDe: 'Lương tháng 9',
            tenDanhMuc: 'Lương',
            danhMuc: 'c_luong'),
        g(ngay: DateTime(2026, 9, 5), soTien: 300000, tieuDe: 'Ăn trưa'),
      ]);

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
          reason: 'Cột số phải cộng được trong Excel. "1.045.000 đ" là chữ, và '
              'Excel tiếng Việt còn đọc dấu chấm thành dấu thập phân.');
      expect(s, isNot(contains('đ')));
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

  group('csvBaoCao — so với kỳ trước', () {
    test('ghi tổng của KỲ TRƯỚC bằng số thô, chi mang dấu âm', () {
      final s = csv(hasoSanh());
      expect(s, contains('Kỳ trước - tổng thu;8000000'));
      expect(s, contains('Kỳ trước - tổng chi;-250000'),
          reason: 'Cùng luật dấu với mọi số chi khác của tệp — cột phải cộng '
              'được.');
      expect(s, contains('Kỳ trước - còn lại;7750000'));
    });

    test('phần trăm KHÔNG bị nhân 100 lần thứ hai', () {
      final s = csv(hasoSanh());
      expect(s, contains('Thu so với kỳ trước (%);12.5'),
          reason: '`phanTramSoVoi` đã trả sẵn thang 0–100, còn `_tiLe` trong '
              'chính tệp này lại nhân thêm 100. Dùng lại `_tiLe` ở đây là in ra '
              '1250.0 mà không exception nào báo.');
      expect(s, contains('Chi so với kỳ trước (%);20.0'));
      expect(s, isNot(contains('1250')));
    });

    test('ô phần trăm để TRỐNG khi kỳ trước bằng 0', () {
      // Không giao dịch nào của tháng 8 → nền bằng 0 → `phanTramSoVoi` trả null.
      final s = csv(baoCao([g(ngay: DateTime(2026, 9, 5))]));
      expect(s, contains('Thu so với kỳ trước (%);\r\n'),
          reason: 'Đây là ô SỐ. Ghi "—" vào đó là nhét một chuỗi chữ vào cột '
              'Excel sắp cộng, và ghi "0" là bịa ra "không đổi".');
      expect(khoi(s, 'TỔNG QUAN'), isNot(contains('Thu so với kỳ trước (%);—')));
    });
  });

  group('csvBaoCao — số liệu nhanh', () {
    test('có đúng ba chỉ số, không lặp lại Số giao dịch', () {
      final s = csv(hasoSanh());
      expect(khoi(s, 'SỐ LIỆU NHANH'), [
        'Chi mỗi ngày;10000',
        'Ngày chi nhiều nhất;05/09/2026;300000',
        'Khoản chi lớn nhất;Ăn trưa;300000',
      ], reason: 'Màn Xem trước có bốn ô, nhưng ô "Số giao dịch" đã nằm ở khối '
          'TỔNG QUAN của tệp — lặp lại là hai con số phải khớp nhau mãi mãi.');
    });

    test('chi mỗi ngày chia cho số ngày CỦA KỲ, không phải số ngày có chi', () {
      final s = csv(hasoSanh());
      expect(khoi(s, 'SỐ LIỆU NHANH').first, 'Chi mỗi ngày;10000',
          reason: '300.000 chia 30 ngày của tháng 9 là 10.000. Chia cho một '
              'ngày có phát sinh là ra 300.000 — con số ấy vẫn "hợp lý".');
    });

    test('kỳ chỉ có thu thì hai chỉ số về chi để trống', () {
      final s = csv(baoCao([
        g(ngay: DateTime(2026, 9, 5), loai: 'thu', soTien: 900000,
            tieuDe: 'Lương', tenDanhMuc: 'Lương', danhMuc: 'c_luong'),
      ]));
      expect(khoi(s, 'SỐ LIỆU NHANH'), [
        'Chi mỗi ngày;0',
        'Ngày chi nhiều nhất;;',
        'Khoản chi lớn nhất;;',
      ]);
    });

    test('bỏ hẳn khối khi kỳ rỗng', () {
      final s = csv(baoCao([]));
      expect(s, isNot(contains('SỐ LIỆU NHANH')),
          reason: 'Cùng luật với màn Xem trước, nơi khối này chỉ dựng ở nhánh '
              'không rỗng. In ra toàn số 0 là vẽ một kỳ có thật.');
    });
  });

  group('csvBaoCao — top 5 khoản chi', () {
    test('bảng mang số thứ tự, và số tiền có dấu âm', () {
      final s = csv(hasoSanh());
      expect(khoi(s, 'TOP 5 KHOẢN CHI'), [
        '#;Nội dung;Danh mục;Ngày;Số tiền',
        '1;Ăn trưa;Ăn uống;05/09/2026;-300000',
      ]);
    });

    test('chỉ lấy năm khoản, giảm dần theo số tiền', () {
      final s = csv(baoCao([
        for (var i = 1; i <= 7; i++)
          g(ngay: DateTime(2026, 9, i), soTien: i * 10000, tieuDe: 'Chi $i'),
      ]));
      final k = khoi(s, 'TOP 5 KHOẢN CHI').skip(1).toList();
      expect(k.length, 5);
      expect(k.first, startsWith('1;Chi 7;'));
      expect(k.last, startsWith('5;Chi 3;'));
    });

    test('bỏ hẳn khối khi kỳ không có khoản chi nào', () {
      final s = csv(baoCao([
        g(ngay: DateTime(2026, 9, 5), loai: 'thu', soTien: 900000,
            tieuDe: 'Lương', tenDanhMuc: 'Lương', danhMuc: 'c_luong'),
      ]));
      expect(s, isNot(contains('TOP 5 KHOẢN CHI')));
    });
  });

  group('nhanPhanTramSoVoi', () {
    // Tầng vẽ PDF không kiểm được bằng máy (tệp nén, font subset), nên luật
    // định dạng duy nhất có rủi ro của nó nằm ở hàm thuần này.
    test('không so được thì trả dấu gạch', () {
      expect(nhanPhanTramSoVoi(null), '—');
    });

    test('tăng thì mang dấu cộng, và dấu PHẨY thập phân', () {
      expect(nhanPhanTramSoVoi(12.5), '+12,5%',
          reason: 'PDF là tài liệu để ĐỌC nên theo thông lệ Việt Nam — ngược '
              'với CSV, nơi cùng con số ấy phải mang dấu chấm.');
    });

    test('giảm thì mang dấu trừ', () {
      expect(nhanPhanTramSoVoi(-3), '-3,0%',
          reason: 'Bản thiết kế đầu dùng ▲/▼ như màn Xem trước; ca test quét '
              'glyph đã lật nó — Roboto nhúng không có hai hình tam giác ấy và '
              'gói `pdf` bỏ chúng đi im lặng.');
    });

    test('không đổi thì vẫn mang dấu cộng, 0,0%', () {
      expect(nhanPhanTramSoVoi(0), '+0,0%');
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

    test('mọi ký tự HẰNG mà PDF in ra đều có glyph trong font nhúng', () {
      // Canh chừng điều gì: font thiếu glyph thì gói `pdf` **bỏ ký tự đi** và
      // chỉ in một dòng cảnh báo ra console — tệp vẫn mở được, chỉ là mũi tên
      // hoặc dấu biến mất. Cùng loại lỗi với "rơi về Helvetica", nhưng bản
      // Roboto nhúng vẫn dính: nó **không có** khối Mũi tên (U+2190…) lẫn khối
      // Hình học (U+25A0…). Đã bắt được ba ca thật: → ▲ ▼.
      final cmap = {
        'Roboto-Regular.ttf': TtfParser(ByteData.view(
            File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync().buffer)),
        'Roboto-Bold.ttf': TtfParser(ByteData.view(
            File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync().buffer)),
      };

      // Chỉ quét chuỗi HẰNG của chính tệp dựng PDF. Chú thích bị loại vì chúng
      // mang ⚠️ và những ký tự chỉ con người đọc, không bao giờ vào tệp; còn
      // chữ của người dùng (tên ví, ghi chú) thì không ai chặn trước được.
      final ma = File('lib/features/analytics/domain/xuat_tep.dart')
          .readAsLinesSync()
          .map((d) {
            if (d.trimLeft().startsWith('//')) return '';
            final i = d.indexOf('//');
            return i < 0 ? d : d.substring(0, i);
          })
          .join('\n');

      final la = <int>{};
      for (final m in RegExp("'([^'\\\\\\n]*)'").allMatches(ma)) {
        for (final r in m.group(1)!.runes) {
          if (r > 0x7F) la.add(r);
        }
      }
      expect(la.length, greaterThan(20),
          reason: 'Gom được quá ít ký tự thì phép quét đã hỏng và ca này rỗng '
              'ruột — tệp nguồn có hàng chục chữ tiếng Việt có dấu.');

      for (final e in cmap.entries) {
        final thieu = [
          for (final r in la)
            if (!e.value.charToGlyphIndexMap.containsKey(r))
              '${String.fromCharCode(r)} (U+${r.toRadixString(16).toUpperCase()})',
        ];
        expect(thieu, isEmpty,
            reason: '${e.key} không có glyph cho những ký tự này, nên PDF in ra '
                'sẽ THIẾU chúng mà không báo lỗi nào.');
      }
    });

    test('kỳ chỉ có thu vẫn ra tệp hợp lệ', () async {
      // Ba giá trị `null` cùng lúc trong khối Số liệu nhanh —
      // `ngayChiNhieuNhat`, `khoanChiLonNhat`, và `topChi` rỗng. Kỳ **rỗng**
      // không đi qua đường này vì khối bị bỏ hẳn.
      final b = await pdf(baoCao([
        g(ngay: DateTime(2026, 9, 5), loai: 'thu', soTien: 900000,
            tieuDe: 'Lương', tenDanhMuc: 'Lương', danhMuc: 'c_luong'),
      ]));
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
