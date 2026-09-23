/// Tool (công cụ) của màn Trợ lý AI — giao diện thuần + khai báo cho mô hình
/// (spec 4b mục 3.3 / 3.4).
///
/// Tên tool là định danh ASCII `snake_case` cho mô hình; **mô tả tiếng Việt**
/// là thứ duy nhất dẫn E2B chọn đúng (không có few-shot ở bậc tool), nên mỗi
/// mô tả nêu thẳng câu hỏi kiểu nào thì gọi.
///
/// Không tool ghi — bất biến ④ `docs/AI_AGENT_ARCHITECTURE.md`.
library;

import 'hang_so_lieu.dart';

const String kTenCongCuNganSach = 'danh_sach_ngan_sach';
const String kTenCongCuHoaDon = 'danh_sach_hoa_don';
const String kTenCongCuVi = 'danh_sach_vi';
const String kTenCongCuChiTieu = 'chi_tieu_theo_ky';
const String kTenCongCuMucTieu = 'danh_sach_muc_tieu';

/// Trần số LỜI GỌI tool trong một câu hỏi. Gọi song song đếm từng lời; tool bịa
/// tên cũng tốn một suất, để vòng lặp không quay vô hạn.
const int kTranGoiCongCu = 3;

class KhaiBaoCongCu {
  final String ten;
  final String moTa;

  /// JSON Schema của tham số — runtime dịch nguyên sang `Tool.parameters`.
  final Map<String, dynamic> thamSo;

  const KhaiBaoCongCu({
    required this.ten,
    required this.moTa,
    required this.thamSo,
  });
}

abstract class CongCu {
  KhaiBaoCongCu get khaiBao;

  /// [args] do mô hình sinh — tool TỰ kiểm enum, giá trị lạ → `KetQuaCongCu.loi`,
  /// không đoán. [idaccount] và [now] do vòng lặp truyền từ màn: tool không tự
  /// đọc phiên đăng nhập (quy tắc 2 `CLAUDE.md`) và không tự đọc đồng hồ.
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
  });
}

/// Chữ trên dòng chỉ báo trong lúc tool chạy — một chỗ, để màn không giữ bảng
/// tên tool riêng.
String cauDangTraCuu(String tenCongCu) => switch (tenCongCu) {
      kTenCongCuNganSach => 'Đang tra cứu ngân sách…',
      kTenCongCuHoaDon => 'Đang tra cứu hoá đơn…',
      kTenCongCuVi => 'Đang tra cứu ví…',
      kTenCongCuChiTieu => 'Đang tra cứu chi tiêu…',
      kTenCongCuMucTieu => 'Đang tra cứu mục tiêu…',
      _ => 'Đang tra cứu…',
    };
