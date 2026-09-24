/// Tool (công cụ) của màn Trợ lý AI — giao diện thuần + khai báo cho mô hình
/// (spec 4b mục 3.3 / 3.4).
///
/// Tên tool là định danh ASCII `snake_case` cho mô hình; **mô tả tiếng Việt**
/// là thứ duy nhất dẫn E2B chọn đúng (không có few-shot ở bậc tool), nên mỗi
/// mô tả nêu thẳng câu hỏi kiểu nào thì gọi.
///
/// Không tool ghi — bất biến ④ `docs/AI_AGENT_ARCHITECTURE.md`.
library;

import 'dart:convert';

import 'hang_so_lieu.dart';

const String kTenCongCuNganSach = 'danh_sach_ngan_sach';
const String kTenCongCuHoaDon = 'danh_sach_hoa_don';
const String kTenCongCuVi = 'danh_sach_vi';
/// Tên cũ `chi_tieu_theo_ky` tới 2026-09-24: ba lần đo cổng D, 9 câu "tiêu gì /
/// chi những gì" đều bám vào chữ `chi_tieu` trong tên (đòn bẩy spec 2b mục 1.2
/// hàng 10). Tên mới nói rõ TỔNG và nêu cả thu lẫn chi — đúng thứ tool trả.
const String kTenCongCuTongKet = 'tong_ket_thu_chi_ky';
const String kTenCongCuMucTieu = 'danh_sach_muc_tieu';
const String kTenCongCuGoiYHanMuc = 'goi_y_han_muc';
const String kTenCongCuGiaoDich = 'tim_giao_dich';

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

/// Chuỗi `tools_json` của một bộ khai báo — đúng nội dung gói gửi xuống SDK
/// (`SdkResponseParser.serializeToolsForSdk`). MỘT định nghĩa: `slm_runtime` đo
/// độ dài bằng nó, `bo_cong_cu_test` chặn độ dài bằng nó (bẫy 4.39 — trần
/// `maxTokens` là trần TỔNG, khai báo tool cũng chiếm chỗ).
String toolsJsonCua(List<KhaiBaoCongCu> congCu) => jsonEncode([
      for (final k in congCu)
        {
          'type': 'function',
          'function': {
            'name': k.ten,
            'description': k.moTa,
            'parameters': k.thamSo,
          },
        },
    ]);

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
      kTenCongCuTongKet => 'Đang tổng kết thu chi…',
      kTenCongCuMucTieu => 'Đang tra cứu mục tiêu…',
      kTenCongCuGoiYHanMuc => 'Đang tính gợi ý hạn mức…',
      kTenCongCuGiaoDich => 'Đang tìm giao dịch…',
      _ => 'Đang tra cứu…',
    };
