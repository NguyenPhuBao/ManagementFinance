/// A5 mục 5.4 — ảnh QUÉT: mô hình trên máy (Gemma 4 E2B) lấp những ô luật không đọc ra (số tiền · ngày · nội dung).
/// AI đọc CHỮ OCR, không đọc ảnh.
///
/// Đây CHỈ là chỗ gọi mô hình. Kết quả là [KetQuaAiAnh] **thô** — lưới kiểm nằm ở `lapTuAi` (`doc_anh_quet.dart`).
/// Mọi hỏng hóc (chưa sẵn sàng, nạp lỗi, máy từng sập ở phiên có tool, quá hạn, đã huỷ, không gọi tool) trả `null`:
/// màn dùng kết quả luật. Điều kiện Premium nằm ở màn `/quet`, không ở đây.
///
/// Phiên **một** tool, **không** có tham số danh mục — form tự gợi ý danh mục trên ghi chú (YAGNI, spec 5.4).
///
/// ⚠️ Ở `transaction/data/` cùng chỗ `doc_cau_bang_ai.dart`. Chỉ `slm_runtime.dart` được import `flutter_gemma`
/// (test quét 16) — tệp này đi qua `SlmRuntime`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../ai_edge/data/phien_mot_loi_goi.dart';
import '../../ai_edge/data/slm_runtime.dart';
import '../../ai_edge/domain/cong_cu.dart';
import '../domain/doc_anh_quet.dart';
import 'doc_cau_bang_ai.dart' show kThoiHanDocAi;

const String kTenCongCuDienAnhQuet = 'dien_anh_quet';

String _dd(int n) => n.toString().padLeft(2, '0');

String promptAnhQuet(DateTime now) =>
    'Bạn đọc chữ máy quét được từ MỘT hoá đơn hoặc biên lai rồi gọi công cụ $kTenCongCuDienAnhQuet đúng MỘT lần. '
    'Hôm nay là ${_dd(now.day)}/${_dd(now.month)}/${now.year}. '
    'Chỉ chép số và chữ CÓ TRONG đoạn chữ; không đoán. Thiếu thì để 0 hoặc rỗng.';

KhaiBaoCongCu khaiBaoDienAnhQuet() => const KhaiBaoCongCu(
      ten: kTenCongCuDienAnhQuet,
      moTa: 'Điền tổng tiền phải trả, ngày và tên cửa hàng / nội dung từ chữ của ảnh.',
      thamSo: {
        'type': 'object',
        'properties': {
          'so_tien': {'type': 'integer', 'description': 'Tổng tiền phải trả, bằng đồng, chép từ chữ; 0 nếu không thấy.'},
          'ngay': {'type': 'string', 'description': 'Ngày giao dịch dd/mm/yyyy chép từ chữ; rỗng nếu không thấy.'},
          'noi_dung': {'type': 'string', 'description': 'Tên cửa hàng hoặc nội dung chuyển khoản, chép từ chữ.'},
        },
        'required': ['so_tien', 'ngay', 'noi_dung'],
      },
    );

class DocAnhBangAi {
  DocAnhBangAi({
    required this.runtime,
    required this.sanSang,
    required this.duongTep,
    this.thoiHan = kThoiHanDocAi,
  });

  final SlmRuntime runtime;

  /// Máy dùng được AI không — tệp mô hình đủ **và** công tắc AI bật.
  final Future<bool> Function() sanSang;
  final Future<String> Function() duongTep;
  final Duration thoiHan;

  late final PhienMotLoiGoi _phien = PhienMotLoiGoi(
    runtime: runtime,
    sanSang: sanSang,
    duongTep: duongTep,
    thoiHan: thoiHan,
    nhan: '[Quet][AI]',
  );

  /// Các ô thô mô hình đọc được từ chữ của ảnh, hoặc `null` (màn dùng luật).
  Future<KetQuaAiAnh?> doc(String vanBan, {required DateTime now}) async {
    final cau = chuGuiMoHinh(vanBan);
    // Số đo cho nghiệm thu máy thật (spec mục 9 b — độ dài prompt).
    debugPrint('[Quet][AI] chữ gửi mô hình ${cau.length} ký tự');
    final goi = await _phien.goiDauTien(
      heThong: promptAnhQuet(now),
      cauHoi: cau,
      congCu: [khaiBaoDienAnhQuet()],
      laDich: (g) => g.ten == kTenCongCuDienAnhQuet,
    );
    return goi == null ? null : KetQuaAiAnh.tuThamSo(goi.args);
  }

  /// Người dùng bấm Huỷ: lượt đang chạy trả `null`, engine thôi giải mã.
  Future<void> huy() => _phien.huy();
}
