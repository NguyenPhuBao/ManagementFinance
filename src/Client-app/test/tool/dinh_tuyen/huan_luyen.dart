/// Dự án B — phép HỌC của bộ định tuyến: Naive Bayes, hồi quy logistic, kiểm
/// chéo, chọn ngưỡng, sinh tệp trọng số (spec mục 4.2, 4.3). Không vào bản app:
/// app chỉ mang phép ĐOÁN (`lib/features/ai_edge/domain/dinh_tuyen_hoc.dart`),
/// và mọi phép đoán ở đây gọi lại đúng hàm ấy — một phép đoán, không hai.
///
/// Không có gì ngẫu nhiên: phần của kiểm chéo gán theo mã băm của câu, logistic
/// khởi tạo 0 (bài toán lồi). Chạy lại trên cùng dữ liệu ra cùng trọng số.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen_hoc.dart';

import 'du_lieu.dart';

/// Giữ mẫu đầu của mỗi câu (theo dạng chuẩn hoá). Cùng một câu mang hai nhãn
/// là lỗi của bộ dữ liệu — ném, kèm câu, để sửa tận gốc thay vì lặng lẽ chọn một.
List<MauDinhTuyen> khuTrung(List<MauDinhTuyen> mau) {
  final thay = <String, MauDinhTuyen>{};
  for (final m in mau) {
    final k = chuanHoaDinhTuyen(m.cau);
    final cu = thay[k];
    if (cu == null) {
      thay[k] = m;
    } else if (cu.nhan != m.nhan) {
      throw StateError('câu "$k" mang hai nhãn: ${cu.nhan} và ${m.nhan}');
    }
  }
  return thay.values.toList();
}

/// Đặc trưng có mặt ở ít nhất [toiThieu] mẫu, xếp theo chữ. Đặc trưng chỉ thấy
/// một lần là tên riêng hoặc lỗi gõ — học nó là học thuộc lòng câu ấy.
List<String> tuVungTu(List<MauDinhTuyen> mau, {int toiThieu = 2}) {
  final dem = <String, int>{};
  for (final m in mau) {
    for (final f in dacTrungCua(m.cau)) {
      dem[f] = (dem[f] ?? 0) + 1;
    }
  }
  return [
    for (final e in dem.entries)
      if (e.value >= toiThieu) e.key,
  ]..sort();
}

typedef HamHoc = TrongSoDinhTuyen Function(List<MauDinhTuyen> mau, List<String> nhan);

/// Naive Bayes đa thức NHỊ PHÂN HOÁ, làm trơn Laplace — khuôn B1
/// (`category/domain/phan_loai_ghi_chu.dart`). Điểm của một nhãn là tổng log
/// tần suất các đặc trưng có mặt, nên phép đoán vẫn là tuyến tính + softmax.
TrongSoDinhTuyen hocNaiveBayes(List<MauDinhTuyen> mau, List<String> nhan) {
  final tv = tuVungTu(mau);
  final k = nhan.length, v = tv.length;
  final vt = {for (var i = 0; i < v; i++) tv[i]: i};
  final n = List<int>.filled(k, 0);
  final s = List<int>.filled(k, 0);
  final dem = List<int>.filled(v * k, 0);
  for (final m in mau) {
    final c = nhan.indexOf(m.nhan);
    if (c < 0) throw StateError('nhãn lạ: ${m.nhan}');
    n[c]++;
    for (final f in dacTrungCua(m.cau)) {
      final i = vt[f];
      if (i == null) continue;
      dem[i * k + c]++;
      s[c]++;
    }
  }
  return TrongSoDinhTuyen(
    nhan: nhan,
    tuVung: tv,
    thienLech: [for (var c = 0; c < k; c++) math.log((n[c] + 1) / (mau.length + k))],
    maTran: [
      for (var i = 0; i < v; i++)
        for (var c = 0; c < k; c++) math.log((dem[i * k + c] + 1) / (s[c] + v)),
    ],
  );
}

/// Hồi quy logistic đa lớp (softmax), phạt L2 trên trọng số (không trên thiên
/// lệch), hạ gradient toàn lô, số vòng cố định, khởi tạo 0.
TrongSoDinhTuyen hocLogistic(
  List<MauDinhTuyen> mau,
  List<String> nhan, {
  int vong = 400,
  double buoc = 0.5,
  double l2 = 0.001,
}) {
  final tv = tuVungTu(mau);
  final k = nhan.length, v = tv.length, n = mau.length;
  final vt = {for (var i = 0; i < v; i++) tv[i]: i};
  final x = [
    for (final m in mau)
      [
        for (final f in dacTrungCua(m.cau))
          if (vt[f] != null) vt[f]!,
      ]..sort(),
  ];
  final y = [
    for (final m in mau)
      nhan.contains(m.nhan) ? nhan.indexOf(m.nhan) : throw StateError('nhãn lạ: ${m.nhan}'),
  ];
  final w = List<double>.filled(v * k, 0);
  final b = List<double>.filled(k, 0);
  final gw = List<double>.filled(v * k, 0);
  final gb = List<double>.filled(k, 0);
  final p = List<double>.filled(k, 0);
  for (var it = 0; it < vong; it++) {
    gw.fillRange(0, gw.length, 0);
    gb.fillRange(0, k, 0);
    for (var j = 0; j < n; j++) {
      var lon = double.negativeInfinity;
      for (var c = 0; c < k; c++) {
        var d = b[c];
        for (final i in x[j]) {
          d += w[i * k + c];
        }
        p[c] = d;
        if (d > lon) lon = d;
      }
      var tong = 0.0;
      for (var c = 0; c < k; c++) {
        p[c] = math.exp(p[c] - lon);
        tong += p[c];
      }
      for (var c = 0; c < k; c++) {
        final g = p[c] / tong - (c == y[j] ? 1 : 0);
        gb[c] += g;
        for (final i in x[j]) {
          gw[i * k + c] += g;
        }
      }
    }
    for (var i = 0; i < w.length; i++) {
      w[i] -= buoc * (gw[i] / n + l2 * w[i]);
    }
    for (var c = 0; c < k; c++) {
      b[c] -= buoc * gb[c] / n;
    }
  }
  return TrongSoDinhTuyen(nhan: nhan, tuVung: tv, thienLech: b, maTran: w);
}

/// Phần kiểm chéo của một câu: FNV-1a 32 bit trên dạng chuẩn hoá. Tất định —
/// xáo ngẫu nhiên thì hai lần chạy cho hai bảng so sánh.
int phanCua(String cauChuanHoa, {int soPhan = 5}) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(cauChuanHoa)) {
    h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
  }
  return h % soPhan;
}

class DuDoan {
  const DuDoan(this.mau, this.nhanDoan, this.xacSuat);
  final MauDinhTuyen mau;
  final String nhanDoan;
  final double xacSuat;
}

/// Dự đoán NGOÀI-PHẦN: mỗi mẫu được đoán bởi mô hình học trên các phần khác.
/// Từ vựng cũng dựng lại theo từng lượt (trong [hoc]) — dùng từ vựng của toàn
/// bộ là để lọt thông tin của mẫu đang đoán.
List<DuDoan> kiemCheo(List<MauDinhTuyen> mau, List<String> nhan, HamHoc hoc, {int soPhan = 5}) {
  final phan = [for (final m in mau) phanCua(chuanHoaDinhTuyen(m.cau), soPhan: soPhan)];
  final ra = <DuDoan>[];
  for (var p = 0; p < soPhan; p++) {
    final doan = [
      for (var i = 0; i < mau.length; i++)
        if (phan[i] == p) mau[i],
    ];
    if (doan.isEmpty) continue;
    final w = hoc([
      for (var i = 0; i < mau.length; i++)
        if (phan[i] != p) mau[i],
    ], nhan);
    for (final m in doan) {
      final d = doanDinhTuyen(w, m.cau);
      ra.add(DuDoan(m, d.nhan, d.xacSuat));
    }
  }
  return ra;
}

class ThongKe {
  const ThongKe({
    required this.chinhXac,
    required this.soDinhTuyen,
    required this.dinhTuyenSai,
    required this.phu,
  });

  /// Phần câu đoán đúng nhãn (mười nhãn, không xét ngưỡng).
  final double chinhXac;

  /// Số câu được định tuyến: nhãn đoán là một tool VÀ xác suất đạt ngưỡng.
  final int soDinhTuyen;

  /// Số câu được định tuyến sang tool KHÁC nhãn đúng — kể cả câu nhãn đúng là
  /// "không định tuyến". Đây là con số ngưỡng phải đưa về 0.
  final int dinhTuyenSai;

  /// Số câu định tuyến đúng / số câu mang nhãn tool.
  final double phu;
}

bool duocDinhTuyen(DuDoan d, double nguong) =>
    d.nhanDoan != kNhanKhongDinhTuyen && d.xacSuat >= nguong;

ThongKe danhGia(List<DuDoan> duDoan, double nguong) {
  var dung = 0, tuyen = 0, sai = 0, tuyenDung = 0, coTool = 0;
  for (final d in duDoan) {
    if (d.nhanDoan == d.mau.nhan) dung++;
    if (d.mau.nhan != kNhanKhongDinhTuyen) coTool++;
    if (!duocDinhTuyen(d, nguong)) continue;
    tuyen++;
    if (d.nhanDoan == d.mau.nhan) {
      tuyenDung++;
    } else {
      sai++;
    }
  }
  return ThongKe(
    chinhXac: duDoan.isEmpty ? 0 : dung / duDoan.length,
    soDinhTuyen: tuyen,
    dinhTuyenSai: sai,
    phu: coTool == 0 ? 0 : tuyenDung / coTool,
  );
}

/// Ngưỡng thấp nhất trên lưới 0,50…0,99 mà không câu nào định tuyến sai, cộng
/// đệm 0,05, kẹp trong [0,60; 0,99]. `null`: còn câu sai ở 0,99 — mô hình bị loại.
double? chonNguong(List<DuDoan> duDoan) {
  for (var i = 50; i <= 99; i++) {
    final t = i / 100;
    if (danhGia(duDoan, t).dinhTuyenSai == 0) {
      return math.min(0.99, math.max(0.60, t + 0.05));
    }
  }
  return null;
}

/// Nội dung tệp `trong_so_dinh_tuyen.g.dart`. ⚠️ Nhãn và từ vựng là MỘT chuỗi
/// bọc `|` hai đầu, tách lúc chạy: test quét 14 cấm âm tiết chiều tiền đứng
/// riêng trong nháy ở `ai_edge/`, và hai âm tiết ấy chắc chắn có trong từ vựng.
String sinhTepTrongSo(
  TrongSoDinhTuyen w, {
  required String loai,
  required double nguong,
  required String bamHuanLuyen,
}) {
  final k = w.nhan.length;
  String so(double x) {
    final s = x.toStringAsFixed(4);
    return s == '-0.0000' ? '0.0000' : s;
  }

  final b = StringBuffer()
    ..writeln('// TỆP SINH RA — KHÔNG SỬA TAY.')
    ..writeln('// Sinh bởi: flutter test test/tool/dinh_tuyen/huan_luyen_dinh_tuyen_test.dart --run-skipped')
    ..writeln('// Dự án B (spec 2026-10-02-du-an-b-mo-hinh-dinh-tuyen-cau-hoi-design.md mục 4.3).')
    ..writeln('// ignore_for_file: type=lint')
    ..writeln()
    ..writeln("import 'dinh_tuyen_hoc.dart';")
    ..writeln()
    ..writeln('/// Loại mô hình đã học ra bộ trọng số này — chỉ để đọc; phép đoán là một.')
    ..writeln("const String kLoaiMoHinhDinhTuyen = '$loai';")
    ..writeln()
    ..writeln('/// Dưới ngưỡng này câu hỏi không được định tuyến (phiên sáu tool).')
    ..writeln('const double kNguongDinhTuyen = ${nguong.toStringAsFixed(2)};')
    ..writeln()
    ..writeln('/// SHA-256 của bộ huấn luyện (xuống dòng LF) đã sinh ra tệp này.')
    ..writeln("const String kBamBoHuanLuyen = '$bamHuanLuyen';")
    ..writeln()
    ..writeln('// Một chuỗi bọc dấu gạch đứng hai đầu, tách lúc chạy (test quét 14).')
    ..writeln("const String _nhan = '|${w.nhan.join('|')}|';")
    ..writeln("const String _tuVung = '|${w.tuVung.join('|')}|';")
    ..writeln()
    ..writeln('const List<double> _thienLech = [${w.thienLech.map(so).join(', ')}];')
    ..writeln()
    ..writeln('/// ${w.tuVung.length} đặc trưng × $k nhãn, mỗi dòng một đặc trưng.')
    ..writeln('const List<double> _maTran = [');
  for (var i = 0; i < w.tuVung.length; i++) {
    b.writeln('  ${[for (var c = 0; c < k; c++) so(w.maTran[i * k + c])].join(', ')},');
  }
  b
    ..writeln('];')
    ..writeln()
    ..writeln("List<String> _tach(String s) => s.split('|').where((t) => t.isNotEmpty).toList();")
    ..writeln()
    ..writeln('final TrongSoDinhTuyen kTrongSoDinhTuyen = TrongSoDinhTuyen(')
    ..writeln('  nhan: _tach(_nhan),')
    ..writeln('  tuVung: _tach(_tuVung),')
    ..writeln('  thienLech: _thienLech,')
    ..writeln('  maTran: _maTran,')
    ..writeln(');');
  return b.toString();
}
