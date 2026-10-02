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
  const MauDinhTuyen(this.nhan, this.cau, {this.chapNhan = const {}});
  final String nhan;
  final String cau;

  /// Các tool KHÁC cũng trả lời đúng câu này. Mô hình học theo [nhan]; khi chấm,
  /// định tuyến sang một tool ở đây không tính là sai (và không tính là đúng).
  /// Tiêu chí ghi vào cột này: tool ấy trả ĐỦ số để trả lời mà Gemma không phải
  /// làm phép tính nào — không phải "mô hình hay đoán thế".
  final Set<String> chapNhan;

  @override
  String toString() => '$nhan\t$cau${chapNhan.isEmpty ? '' : '\t${chapNhan.join(',')}'}';
}

/// Mỗi dòng `nhãn<TAB>câu[<TAB>tool chấp nhận, cách nhau dấu phẩy]`; bỏ dòng
/// trống và dòng bắt đầu `#`.
List<MauDinhTuyen> docTsv(String noiDung) {
  final ra = <MauDinhTuyen>[];
  final dong = noiDung.replaceAll('\r\n', '\n').split('\n');
  for (var i = 0; i < dong.length; i++) {
    final d = dong[i];
    if (d.trim().isEmpty || d.startsWith('#')) continue;
    final cot = d.split('\t');
    if (cot.length < 2 || cot[0].trim().isEmpty || cot[1].trim().isEmpty) {
      throw FormatException('dòng ${i + 1} không phải "nhãn<TAB>câu": $d');
    }
    ra.add(MauDinhTuyen(
      cot[0].trim(),
      cot[1].trim(),
      chapNhan: {
        if (cot.length > 2)
          for (final c in cot[2].split(','))
            if (c.trim().isNotEmpty) c.trim(),
      },
    ));
  }
  return ra;
}

/// SHA-256 (hex) của nội dung sau khi đổi `\r\n` → `\n`.
String bamNoiDung(String noiDung) =>
    sha256.convert(utf8.encode(noiDung.replaceAll('\r\n', '\n'))).toString();

String docTep(String duong) => File(duong).readAsStringSync().replaceAll('\r\n', '\n');
