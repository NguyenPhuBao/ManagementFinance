/// Dựng **nội dung tệp** báo cáo. Thuần: không đụng hệ tệp, không plugin.
///
/// Tách khỏi phần ghi/chia sẻ tệp vì phần ấy là lời gọi plugin, không test tự
/// động được; còn mọi luật ở đây thì hỏng **im lặng** — Excel vẫn mở được tệp,
/// chỉ là chữ mất dấu, cột dồn làm một, hoặc số tiền hoá thành chữ.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import 'bao_cao_xuat.dart';

/// Dấu phân cách của tệp CSV.
///
/// Chấm phẩy chứ không phải phẩy: Excel dùng dấu phân cách theo **locale máy**,
/// và vi-VN là chấm phẩy. Dòng `sep=;` ở đầu tệp nói thẳng cho Excel biết, nên
/// máy en-US mở cũng đúng.
const String _sep = ';';

/// CSV kết thúc dòng bằng CRLF theo RFC 4180 — Excel cũ trên Windows đọc LF
/// thành một dòng dài duy nhất.
const String _hetDong = '\r\n';

/// Tên tệp an toàn cho mọi hệ tệp: `BaoCao_01-09-2026_30-09-2026.csv`.
///
/// Ngày dùng gạch ngang chứ không gạch chéo — `01/09/2026` trong tên tệp là
/// tạo thư mục con trên Linux và lỗi ghi tệp trên Windows.
String tenTepBaoCao(BaoCao bc, {required String duoi}) {
  String ngay(DateTime d) =>
      DateFormatter.formatDate(d).replaceAll('/', '-');
  // Biên `to` MỞ: ngày cuối cùng thuộc báo cáo là `to - 1 ngày`.
  final cuoi = bc.to.subtract(const Duration(days: 1));
  return 'BaoCao_${ngay(bc.from)}_${ngay(cuoi)}.$duoi';
}

/// Nội dung CSV của [bc].
String csvBaoCao(
  BaoCao bc, {
  required String nhanVi,
  required String nhanDanhMuc,
  required DateTime lapNgay,
}) {
  final b = StringBuffer();
  // BOM UTF-8. Không có nó thì Excel đoán bảng mã và "Ăn uống" thành "Ăn
  // uống" — tệp vẫn mở được, đó mới là chỗ nguy.
  b.write('﻿');
  b.write('sep=$_sep$_hetDong');

  void dong(List<Object?> o) {
    b.write(o.map(_o).join(_sep));
    b.write(_hetDong);
  }

  final cuoi = bc.to.subtract(const Duration(days: 1));

  dong(['BÁO CÁO TỔNG QUAN THU CHI']);
  dong([
    'Kỳ báo cáo',
    '${DateFormatter.formatDate(bc.from)} - ${DateFormatter.formatDate(cuoi)}'
  ]);
  dong(['Ví', nhanVi]);
  dong(['Danh mục', nhanDanhMuc]);
  dong(['Lập ngày', DateFormatter.formatDate(lapNgay)]);
  dong([]);

  dong(['TỔNG QUAN']);
  dong(['Tổng thu', _tien(bc.tong.thu)]);
  dong(['Tổng chi', _tien(-bc.tong.chi)]);
  dong(['Còn lại', _tien(bc.tong.conLai)]);
  dong(['Số giao dịch', bc.soGiaoDich]);
  final dt = bc.dongTien;
  if (dt != null) {
    dong(['Số dư đầu kỳ', _tien(dt.dauKy)]);
    dong(['Số dư cuối kỳ', _tien(dt.cuoiKy)]);
  }
  dong([]);

  if (bc.theoDanhMuc.isNotEmpty) {
    dong(['CHI THEO DANH MỤC']);
    dong(['Danh mục', 'Số tiền', 'Tỉ lệ (%)']);
    for (final d in bc.theoDanhMuc) {
      dong([d.ten, _tien(-d.soTien), _tiLe(d.tiLe)]);
    }
    dong([]);
  }

  if (bc.thuTheoDanhMuc.isNotEmpty) {
    dong(['THU THEO DANH MỤC']);
    dong(['Danh mục', 'Số tiền', 'Tỉ lệ (%)']);
    for (final d in bc.thuTheoDanhMuc) {
      dong([d.ten, _tien(d.soTien), _tiLe(d.tiLe)]);
    }
    dong([]);
  }

  if (bc.nganSach.isNotEmpty) {
    dong(['NGÂN SÁCH KỲ NÀY']);
    dong(['Danh mục', 'Đã chi', 'Hạn mức', 'Còn lại']);
    for (final n in bc.nganSach) {
      dong([n.ten, _tien(n.daChi), _tien(n.hanMuc), _tien(n.conLai)]);
    }
    dong([]);
  }

  if (bc.theoVi.isNotEmpty) {
    dong(['PHÂN BỔ THEO VÍ']);
    dong(['Ví', 'Thu', 'Chi', 'Số giao dịch']);
    for (final v in bc.theoVi) {
      dong([v.ten, _tien(v.thu), _tien(-v.chi), v.soGiaoDich]);
    }
    dong([]);
  }

  dong(['DANH SÁCH GIAO DỊCH']);
  dong(['Ngày', 'Nội dung', 'Danh mục', 'Ví', 'Số tiền']);
  for (final n in bc.nhom) {
    for (final d in n.dong) {
      dong([
        DateFormatter.formatDate(d.ngay),
        d.tieuDe,
        d.tenDanhMuc,
        d.tenVi,
        // Chi mang dấu âm: cùng một cột mà không có dấu thì tổng cột ra "thu
        // cộng chi", một con số không có nghĩa gì.
        _tien(d.loai == 'thu' ? d.soTien : -d.soTien),
      ]);
    }
  }

  return b.toString();
}

/// Số tiền **thô** cho cột tính toán: số nguyên, không phân cách nghìn, không
/// ký hiệu tiền tệ.
///
/// Tiền Việt không có phần lẻ trong thực tế, và bỏ phần lẻ ở đây tránh luôn cái
/// bẫy dấu thập phân: Excel tiếng Việt đọc `1.045.000` thành một phẩy không
/// bốn năm.
String _tien(double x) => x.round().toString();

/// Tỉ lệ `[0,1]` → phần trăm một chữ số thập phân, dùng **dấu chấm**: đây là ô
/// số, và dấu phẩy thập phân sẽ đụng dấu phân cách cột.
String _tiLe(double x) => (x * 100).toStringAsFixed(1);

/// Một ô CSV, đã thoát theo RFC 4180.
String _o(Object? v) {
  final s = v?.toString() ?? '';
  final canBoc =
      s.contains(_sep) || s.contains('"') || s.contains('\n') || s.contains('\r');
  if (!canBoc) return s;
  return '"${s.replaceAll('"', '""')}"';
}

// ───────────────────────────────────────────────────────────────────────────
// PDF
// ───────────────────────────────────────────────────────────────────────────

/// Dựng tệp PDF của [bc].
///
/// Font phải **truyền vào** chứ không tự nạp: hàm này thuần nên test gọi được
/// mà không cần `rootBundle`. Và font là bắt buộc — font mặc định của gói `pdf`
/// là Helvetica, **không có glyph tiếng Việt** và mất dấu im lặng.
Future<Uint8List> pdfBaoCao(
  BaoCao bc, {
  required String nhanVi,
  required String nhanDanhMuc,
  required DateTime lapNgay,
  required pw.Font fontThuong,
  required pw.Font fontDam,
}) async {
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: fontThuong, bold: fontDam),
  );

  final cuoi = bc.to.subtract(const Duration(days: 1));
  final khoang =
      '${DateFormatter.formatDate(bc.from)} – ${DateFormatter.formatDate(cuoi)}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Trang ${ctx.pageNumber}/${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (ctx) => [
        pw.Text('BÁO CÁO TỔNG QUAN THU CHI',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(khoang, style: const pw.TextStyle(fontSize: 13)),
        pw.SizedBox(height: 2),
        pw.Text(
          'Ví: $nhanVi  ·  Danh mục: $nhanDanhMuc  ·  '
          'Lập ngày ${DateFormatter.formatDate(lapNgay)}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.Divider(height: 20),
        ..._pdfTongQuan(bc),
        ..._pdfBieuDo(bc),
        ..._pdfBang('CHI THEO DANH MỤC', ['Danh mục', 'Số tiền', 'Tỉ lệ'], [
          for (final d in bc.theoDanhMuc)
            [d.ten, _vnd(d.soTien), '${_tiLe(d.tiLe)}%'],
        ]),
        ..._pdfBang('THU THEO DANH MỤC', ['Danh mục', 'Số tiền', 'Tỉ lệ'], [
          for (final d in bc.thuTheoDanhMuc)
            [d.ten, _vnd(d.soTien), '${_tiLe(d.tiLe)}%'],
        ]),
        ..._pdfBang(
            'NGÂN SÁCH KỲ NÀY', ['Danh mục', 'Đã chi', 'Hạn mức', 'Còn lại'], [
          for (final n in bc.nganSach)
            [n.ten, _vnd(n.daChi), _vnd(n.hanMuc), _vnd(n.conLai)],
        ]),
        ..._pdfBang('PHÂN BỔ THEO VÍ', ['Ví', 'Thu', 'Chi', 'Giao dịch'], [
          for (final v in bc.theoVi)
            [v.ten, _vnd(v.thu), _vnd(v.chi), '${v.soGiaoDich}'],
        ]),
        ..._pdfBang('DANH SÁCH GIAO DỊCH',
            ['Ngày', 'Nội dung', 'Danh mục', 'Ví', 'Số tiền'], [
          for (final n in bc.nhom)
            for (final d in n.dong)
              [
                DateFormatter.formatDate(d.ngay),
                d.tieuDe,
                d.tenDanhMuc,
                d.tenVi,
                d.loai == 'thu' ? '+${_vnd(d.soTien)}' : '-${_vnd(d.soTien)}',
              ],
        ]),
      ],
    ),
  );

  return doc.save();
}

List<pw.Widget> _pdfTongQuan(BaoCao bc) {
  final dt = bc.dongTien;
  return [
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _pdfO('TỔNG THU', _vnd(bc.tong.thu)),
        _pdfO('TỔNG CHI', _vnd(bc.tong.chi)),
        _pdfO('CÒN LẠI', _vnd(bc.tong.conLai)),
        _pdfO('SỐ GIAO DỊCH', '${bc.soGiaoDich}'),
      ],
    ),
    if (dt != null) ...[
      pw.SizedBox(height: 10),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        child: pw.Text(
          'Số dư đầu kỳ ${_vnd(dt.dauKy)}   →   số dư cuối kỳ '
          '${_vnd(dt.cuoiKy)}   (suy ngược từ số dư hiện tại của các ví)',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ),
    ],
    pw.SizedBox(height: 14),
  ];
}

pw.Widget _pdfO(String nhan, String giaTri) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(nhan,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(giaTri,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    );

/// Biểu đồ thu/chi. Bỏ qua khi chuỗi quá ngắn hoặc phẳng — một đường thẳng tắp
/// không nói gì mà vẫn chiếm nửa trang giấy.
List<pw.Widget> _pdfBieuDo(BaoCao bc) {
  if (bc.chuoi.length < 2) return [];
  var dinh = 0.0;
  for (final d in bc.chuoi) {
    if (d.thu > dinh) dinh = d.thu;
    if (d.chi > dinh) dinh = d.chi;
  }
  if (dinh <= 0) return [];
  final maxY = dinh * 1.15;

  List<pw.PointChartValue> diem(double Function(DiemBaoCao) lay) => [
        for (var i = 0; i < bc.chuoi.length; i++)
          pw.PointChartValue(i.toDouble(), lay(bc.chuoi[i])),
      ];

  return [
    pw.Text('THU CHI TRONG KỲ',
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 6),
    pw.SizedBox(
      height: 150,
      child: pw.Chart(
        grid: pw.CartesianGrid(
          xAxis: pw.FixedAxis(
            [for (var i = 0; i < bc.chuoi.length; i++) i],
            buildLabel: (v) {
              // Nhiều nhất sáu nhãn — 30 cột thì chữ chồng lên nhau.
              final buoc = (bc.chuoi.length / 6).ceil();
              final i = v.toInt();
              if (i % buoc != 0 || i >= bc.chuoi.length) {
                return pw.SizedBox();
              }
              return pw.Text(bc.chuoi[i].nhan,
                  style: const pw.TextStyle(fontSize: 7));
            },
          ),
          yAxis: pw.FixedAxis(
            [for (var i = 0; i <= 3; i++) (maxY / 3 * i).round()],
            divisions: true,
            buildLabel: (v) => pw.Text(rutGon(v.toDouble()),
                style: const pw.TextStyle(fontSize: 7)),
          ),
        ),
        datasets: [
          pw.LineDataSet(
            legend: 'Thu',
            data: diem((d) => d.thu),
            color: PdfColors.green600,
            drawPoints: false,
            isCurved: true,
          ),
          pw.LineDataSet(
            legend: 'Chi',
            data: diem((d) => d.chi),
            color: PdfColors.red400,
            drawPoints: false,
            isCurved: true,
          ),
        ],
      ),
    ),
    pw.SizedBox(height: 16),
  ];
}

/// Một bảng của báo cáo; bảng rỗng thì bỏ hẳn cả tiêu đề.
List<pw.Widget> _pdfBang(
  String tieuDe,
  List<String> cot,
  List<List<String>> hang,
) {
  if (hang.isEmpty) return [];
  return [
    pw.Text(tieuDe,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 6),
    pw.TableHelper.fromTextArray(
      headers: cot,
      data: hang,
      border: null,
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellHeight: 18,
      cellAlignments: {
        for (var i = 0; i < cot.length; i++)
          i: i == 0 ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
      },
    ),
    pw.SizedBox(height: 16),
  ];
}

/// Số tiền có phân cách nghìn cho tài liệu ĐỌC — ngược với CSV, nơi số phải
/// thô để Excel cộng được.
String _vnd(double x) => CurrencyFormatter.format(x);
