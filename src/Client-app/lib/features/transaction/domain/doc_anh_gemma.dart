/// A5 mục 13 — Gemma 4 E2B NHÌN ẢNH hoá đơn: câu hỏi gửi mô hình và cách đọc chữ thô nó trả. Hàm thuần.
///
/// Người dùng chốt (2026-10-08): AI đọc MÓN + TỔNG, luật đọc phần còn lại (cửa hàng, ngày). Số tổng của mô hình chưa
/// được tin ngay — `chotTongQuet` chốt nó với số luật.
library;

import 'dart:convert';

import '../../../core/ocr/so_tien_tren_anh.dart';

/// ⚠️ Câu hỏi đã ĐO — Gemma tất định nhưng rất nhạy với câu hỏi: bản này đúng tổng 6/6 hoá đơn trên GPU OnePlus, thêm
/// ba trường cửa hàng / ngày / giờ thì tụt 5/6, câu hỏi không liệt kê món thì một tờ ra gấp mười (757.000). Đổi một chữ
/// là phải đo lại cả bộ ảnh (nút *Lô* của màn spike C4).
const String kPromptMonTong = 'Đây là ảnh một hoá đơn bán hàng. Liệt kê MỌI món hàng in trên hoá đơn. Trả về DUY '
    'NHẤT một JSON: {"mon": [{"ten": "<tên món>", "tien": <thành tiền, số nguyên đồng>}], "tong": <tổng phải trả, số '
    'nguyên đồng>}. Không giải thích.';

class KetQuaGemmaAnh {
  const KetQuaGemmaAnh({this.tong, this.mon = const []});

  /// Tổng phải trả mô hình đọc; `null` = không đọc ra (0, thiếu, quá trần cột tiền).
  final int? tong;

  /// Các dòng có tiền khác 0 (dòng 0 đ là tuỳ chọn *"ít ngọt"*, *"size M"*).
  final List<({String ten, double soTien})> mon;
}

/// Gemma viết số theo ba kiểu: `116000`, `"75,700"`, và `39,000` KHÔNG ngoặc (JSON hỏng — đo OnePlus 2026-10-08).
final RegExp _soTien = RegExp(r'"(tien|tong)"\s*:\s*"?(\d(?:[\d.,]*\d)?)"?');

/// Chữ thô của mô hình → [KetQuaGemmaAnh]; `null` khi không có khối JSON đọc được.
KetQuaGemmaAnh? docJsonGemmaAnh(String tho) {
  final a = tho.indexOf('{'), b = tho.lastIndexOf('}');
  if (a < 0 || b <= a) return null;
  final chu = tho
      .substring(a, b + 1)
      .replaceAllMapped(_soTien, (m) => '"${m[1]}": ${docSoTrenAnh(m[2]!) ?? 0}');
  Object? j;
  try {
    j = jsonDecode(chu);
  } on FormatException {
    return null;
  }
  if (j is! Map) return null;
  int? so(Object? v) => v is num ? v.round() : null;
  final t = so(j['tong']);
  return KetQuaGemmaAnh(
    tong: t != null && t > 0 && t < 1e13 ? t : null,
    mon: [
      if (j['mon'] case final List ds)
        for (final m in ds)
          if (m is Map && m['ten'] is String && (so(m['tien']) ?? 0) != 0)
            (ten: (m['ten'] as String).trim(), soTien: so(m['tien'])!.toDouble()),
    ],
  );
}
