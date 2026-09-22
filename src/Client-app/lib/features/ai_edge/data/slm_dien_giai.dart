// lib/features/ai_edge/data/slm_dien_giai.dart
/// Bản `BoDienGiai` thứ hai — câu do mô hình trên máy viết.
///
/// Khe cắm đã có từ P2: `KhoiNhanXet` đọc `sl<BoDienGiai>()`, không đăng ký thì
/// dùng `const MauCau()`. Nên P3 **không sửa màn nào** để bật mô hình.
///
/// ## Năm nhánh rơi về mẫu câu, tất cả đều IM LẶNG
///
/// Gói thiếu dữ liệu · chưa tải mô hình · nạp hỏng (x86_64, RAM thấp) · mô hình
/// ném giữa chừng · câu không qua bộ kiểm số. Không toast, không dialog: người
/// dùng vẫn nhận được một câu đúng, chỉ là không "mượt" bằng (H3 của đặc tả).
library;

import 'package:flutter/foundation.dart';

import '../domain/bo_dien_giai.dart';
import '../domain/goi_so.dart';
import '../domain/kiem_giong.dart';
import '../domain/kiem_so.dart';
import '../domain/nhan_xet.dart';
import '../domain/slm_prompt.dart';
import 'mo_hinh_tai_ve.dart';
import 'slm_cache.dart';
import 'slm_runtime.dart';

class SlmDienGiai implements BoDienGiai {
  final SlmRuntime runtime;
  final SlmCache cache;
  final MoHinhTaiVe moHinh;

  /// Nạp hỏng một lần thì thôi thử lại trong phiên này — mỗi lần thử là một
  /// lượt `install()` vài trăm ms cho một kết quả đã biết.
  bool _napHongRoi = false;

  SlmDienGiai({
    required this.runtime,
    required this.cache,
    required this.moHinh,
  });

  @override
  Future<NhanXet> dienGiai(GoiSo goi) async {
    if (goi.thieuDuLieu) return goi.mauCau();

    final sanCo = cache.doc(goi.dauVan);
    if (sanCo != null) return _tuCau(sanCo, goi);

    final cau = await _sinh(goi);
    if (cau == null) return goi.mauCau();

    await cache.ghi(goi.dauVan, cau);
    return _tuCau(cau, goi);
  }

  /// `null` = mọi nhánh hỏng; người gọi rơi về mẫu câu.
  Future<String?> _sinh(GoiSo goi) async {
    if (_napHongRoi) return null;
    try {
      if (!runtime.dangSan) {
        // Nạp LƯỜI: chỉ hỏi tệp khi thật sự cần. Người chưa tải mô hình không
        // phải trả RAM nào, và `daCo()` là một phép `existsSync` rẻ.
        if (!await moHinh.daCo()) return null;
        await runtime.moHinhSan(await moHinh.duongTep());
      }
      final cau = await runtime.sinh(promptCauTheoMan(goi), tranToken: 120);
      if (!kiemSo(cau, goi)) {
        debugPrint('[SLM] câu không qua bộ kiểm số, rơi về mẫu: $cau');
        return null;
      }
      if (!kiemGiong(cau, goi.mauCau().muc)) {
        debugPrint('[SLM] câu sai giọng so với mức của hệ luật, rơi về mẫu: $cau');
        return null;
      }
      return cau;
    } catch (e) {
      debugPrint('[SLM] sinh câu hỏng, rơi về mẫu: $e');
      _napHongRoi = !runtime.dangSan;
      return null;
    }
  }

  NhanXet _tuCau(String cau, GoiSo goi) => NhanXet(
        cau: cau,
        // Thẻ số liệu luôn của GÓI, không bao giờ của mô hình — điều kiện 12.
        theSoLieu: goi.mauCau().theSoLieu,
        muc: goi.mauCau().muc,
        tuMoHinh: true,
      );
}
