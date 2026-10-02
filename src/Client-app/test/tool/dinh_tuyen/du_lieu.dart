/// Dự án B — đọc dữ liệu của bộ định tuyến học. Không vào bản app.
///
/// ⚠️ Repo đặt `core.autocrlf=true`: cùng một tệp là LF trong git và CRLF trên
/// đĩa của Windows. Mọi mã băm ở đây tính trên nội dung ĐÃ ĐỔI `\r\n` → `\n`,
/// nếu không ca canh "bộ đo không bị sửa" đỏ trên máy này và xanh trên máy kia.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen_hoc.dart';

const String kDuongBoDo = 'test/tool/dinh_tuyen/bo_do.tsv';
const String kDuongBoHuanLuyen = 'test/tool/dinh_tuyen/bo_huan_luyen.tsv';

/// Chín tool + nhãn âm. Thứ tự CỐ ĐỊNH: nó là thứ tự cột của ma trận trọng số.
const List<String> kMuoiNhan = [
  kTenCongCuTruyVan,
  kTenCongCuNganSach,
  kTenCongCuHoaDon,
  kTenCongCuVi,
  kTenCongCuMucTieu,
  kTenCongCuGoiYHanMuc,
  kTenCongCuDuBao,
  kTenCongCuTongQuan,
  kTenCongCuDanhMuc,
  kNhanKhongDinhTuyen,
];

class MauDinhTuyen {
  const MauDinhTuyen(this.nhan, this.cau);
  final String nhan;
  final String cau;

  @override
  String toString() => '$nhan\t$cau';
}

/// Mỗi dòng `nhãn<TAB>câu`; bỏ dòng trống và dòng bắt đầu `#`.
List<MauDinhTuyen> docTsv(String noiDung) {
  final ra = <MauDinhTuyen>[];
  final dong = noiDung.replaceAll('\r\n', '\n').split('\n');
  for (var i = 0; i < dong.length; i++) {
    final d = dong[i];
    if (d.trim().isEmpty || d.startsWith('#')) continue;
    final t = d.indexOf('\t');
    if (t <= 0 || d.substring(t + 1).trim().isEmpty) {
      throw FormatException('dòng ${i + 1} không phải "nhãn<TAB>câu": $d');
    }
    ra.add(MauDinhTuyen(d.substring(0, t).trim(), d.substring(t + 1).trim()));
  }
  return ra;
}

/// SHA-256 (hex) của nội dung sau khi đổi `\r\n` → `\n`.
String bamNoiDung(String noiDung) =>
    sha256.convert(utf8.encode(noiDung.replaceAll('\r\n', '\n'))).toString();

String docTep(String duong) => File(duong).readAsStringSync().replaceAll('\r\n', '\n');
