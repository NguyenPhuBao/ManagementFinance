/// A5 mục 13 — ảnh QUÉT hoá đơn: Gemma chọn MỘT danh mục chi từ tên cửa hàng + các món đã đọc (người dùng chốt
/// 2026-10-08: "AI chọn danh mục, gọi Gemma lần hai" — tên cửa hàng như *"ỦA TEA"* không khớp từ khoá nào, còn món
/// *"Hồng trà sữa"* thì nói rõ là Ăn uống).
///
/// Chỉ là chỗ gọi mô hình; mọi hỏng hóc trả `null` và form đoán bằng từ khoá như cũ. Phiên **một** tool, tên danh mục là
/// `enum` (engine ép chọn tên có thật) và tên trả về vẫn được soát lại với danh sách.
///
/// ⚠️ Ở `transaction/data/` cạnh `doc_cau_bang_ai.dart`. Đi qua `SlmRuntime` (test quét 16).
library;

import '../../../core/category/category_name.dart';
import '../../ai_edge/data/phien_mot_loi_goi.dart';
import '../../ai_edge/data/slm_runtime.dart';
import '../../ai_edge/domain/cong_cu.dart';
import 'doc_cau_bang_ai.dart' show kThoiHanDocAi;

const String kTenCongCuChonDanhMuc = 'chon_danh_muc';

const String kPromptChonDanhMuc = 'Bạn xếp MỘT hoá đơn mua hàng vào danh mục chi tiêu rồi gọi công cụ '
    '$kTenCongCuChonDanhMuc đúng MỘT lần. Chọn danh mục hợp với các món nhất; không chắc thì để rỗng.';

KhaiBaoCongCu khaiBaoChonDanhMuc(List<String> tenDanhMuc) => KhaiBaoCongCu(
      ten: kTenCongCuChonDanhMuc,
      moTa: 'Chọn danh mục chi tiêu cho hoá đơn.',
      thamSo: {
        'type': 'object',
        'properties': {
          'danh_muc': {'type': 'string', 'enum': tenDanhMuc, 'description': 'Tên danh mục chi tiêu.'},
        },
        'required': ['danh_muc'],
      },
    );

class DocDanhMucBangAi {
  DocDanhMucBangAi({
    required this.runtime,
    required this.sanSang,
    required this.duongTep,
    this.thoiHan = kThoiHanDocAi,
  });

  final SlmRuntime runtime;
  final Future<bool> Function() sanSang;
  final Future<String> Function() duongTep;
  final Duration thoiHan;

  late final PhienMotLoiGoi _phien = PhienMotLoiGoi(
    runtime: runtime,
    sanSang: sanSang,
    duongTep: duongTep,
    thoiHan: thoiHan,
    nhan: '[Quet][danhMuc]',
  );

  /// Tên danh mục (đúng như trong [tenDanhMuc]) mô hình chọn, hoặc `null`.
  Future<String?> chon({required String cuaHang, required List<String> mon, required List<String> tenDanhMuc}) async {
    final ds = [for (final m in mon.take(8)) if (m.trim().isNotEmpty) m.trim()];
    if (tenDanhMuc.isEmpty || (cuaHang.trim().isEmpty && ds.isEmpty)) return null;
    final cau = [
      if (cuaHang.trim().isNotEmpty) 'Cửa hàng: ${cuaHang.trim()}',
      if (ds.isNotEmpty) 'Các món: ${ds.join(', ')}',
    ].join('\n');
    final goi = await _phien.goiDauTien(
      heThong: kPromptChonDanhMuc,
      cauHoi: cau,
      congCu: [khaiBaoChonDanhMuc(tenDanhMuc)],
      laDich: (g) => g.ten == kTenCongCuChonDanhMuc,
    );
    final ten = goi?.args['danh_muc'];
    if (ten is! String) return null;
    final c = normalizeCategoryName(ten);
    return tenDanhMuc.where((t) => normalizeCategoryName(t) == c).firstOrNull;
  }

  /// Người dùng bấm Huỷ.
  Future<void> huy() => _phien.huy();
}
