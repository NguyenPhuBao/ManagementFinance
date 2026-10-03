/// Dự án B — ĐƯỜNG GHÉP của định tuyến câu hỏi → tool: luật trước, mô hình sau
/// (spec `2026-10-02-du-an-b-mo-hinh-dinh-tuyen-cau-hoi-design.md` mục 3). Hàm thuần.
///
/// `congCuTheoCauHoi` (luật viết tay, đã đo trên máy thật) quyết trước và không
/// sửa một dòng. Câu luật trả `null` mới tới bộ định tuyến HỌC
/// (`dinh_tuyen_hoc.dart`), và app chỉ nghe nó khi nó đoán một nhãn trong
/// `kNhanMoHinhDuocDinhTuyen` ở xác suất ≥ `kNguongDinhTuyen` — người dùng chốt
/// 2026-10-02 (hướng 1): hiện chỉ nhãn giao dịch.
///
/// ⚠️ [NguonDinhTuyen] không phải thông tin phụ: vòng lặp tool
/// (`data/vong_lap_cong_cu.dart`) chỉ ÉP chạy tool đích khi nguồn là luật. Nguồn
/// mô hình là định tuyến MỀM — chỉ thu phiên về một tool (spec mục 3.1).
library;

import 'chinh_tham_so.dart';
import 'dinh_tuyen_hoc.dart';
import 'trong_so_dinh_tuyen.g.dart';

enum NguonDinhTuyen { luat, moHinh, khong }

class KetQuaDinhTuyen {
  const KetQuaDinhTuyen({
    required this.ten,
    required this.nguon,
    this.nhanMoHinh,
    this.xacSuat,
  });

  /// Tool đích; `null` = phiên sáu tool, mô hình trên máy tự chọn.
  final String? ten;
  final NguonDinhTuyen nguon;

  /// Nhãn bộ định tuyến học đã đoán — ghi cả khi KHÔNG định tuyến (cho log đo
  /// máy thật); `null` khi luật quyết, vì khi ấy mô hình không được hỏi.
  final String? nhanMoHinh;
  final double? xacSuat;
}

/// Chỉ luật — hành vi trước dự án B. Test của vòng lặp ghim về hàm này để
/// không phụ thuộc bộ trọng số (huấn luyện lại là đổi đường của câu mẫu).
KetQuaDinhTuyen dinhTuyenChiLuat(String cauHoi) {
  final t = congCuTheoCauHoi(cauHoi);
  return KetQuaDinhTuyen(
    ten: t,
    nguon: t == null ? NguonDinhTuyen.khong : NguonDinhTuyen.luat,
  );
}

/// Luật trước, mô hình sau. [trongSo] và [nguong] chỉ để test tiêm vào.
KetQuaDinhTuyen dinhTuyenCauHoi(
  String cauHoi, {
  TrongSoDinhTuyen? trongSo,
  double? nguong,
}) {
  final luat = dinhTuyenChiLuat(cauHoi);
  if (luat.ten != null) return luat;
  final d = doanDinhTuyen(trongSo ?? kTrongSoDinhTuyen, cauHoi);
  final dat = kNhanMoHinhDuocDinhTuyen.contains(d.nhan) &&
      d.xacSuat >= (nguong ?? kNguongDinhTuyen);
  return KetQuaDinhTuyen(
    ten: dat ? d.nhan : null,
    nguon: dat ? NguonDinhTuyen.moHinh : NguonDinhTuyen.khong,
    nhanMoHinh: d.nhan,
    xacSuat: d.xacSuat,
  );
}
