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
const String kTenCongCuMucTieu = 'danh_sach_muc_tieu';
const String kTenCongCuGoiYHanMuc = 'goi_y_han_muc';

/// Lát 1 của spec mở rộng tool (2026-09-27 §4.1): con số ĐÃ TRỪ cam kết — câu
/// 16–17 chặng 3 đòi phép trừ mà mô hình không được làm.
const String kTenCongCuDuBao = 'du_bao_dong_tien';

/// Lát 2 (§4.2, §4.3): thu nhập THẬT, tiết kiệm, thống kê nhanh, tài sản, dư nợ;
/// và danh sách danh mục — thứ trước đó không tool nào liệt kê.
const String kTenCongCuTongQuan = 'tong_quan_tai_chinh';
const String kTenCongCuDanhMuc = 'danh_sach_danh_muc';

/// Thay `tim_giao_dich` + `tong_ket_thu_chi_ky` từ 2026-09-27 (spec tool truy vấn
/// tổng quát): hai tool trên cùng một sổ giao dịch là chỗ mô hình chọn nhầm
/// nhiều nhất (E5, C13, sáu câu có điều kiện ở lần đo 4–8). Lịch sử tên:
/// `chi_tieu_theo_ky` → `tong_ket_thu_chi_ky` (2026-09-24) → gộp vào đây.
const String kTenCongCuTruyVan = 'truy_van_giao_dich';

/// Tool CHỈ ĐI QUA ĐỊNH TUYẾN (`congCuTheoCauHoi`): không khai cho mô hình ở
/// phiên của câu hỏi không định tuyến được. Hai lý do đo được trên OnePlus
/// 2026-09-28 (mục 9.33–9.34 `AI_EDGE_FEATURE.md`): mô hình gần như không tự
/// chọn chúng (tool dự báo 0/3), và khai cả chín tool đưa `tools_json` lên
/// 8.170 ký tự — tool danh mục trả 15 hàng là VỠ TRẦN `FAILED_PRECONDITION`.
const Set<String> kCongCuChiQuaDinhTuyen = {
  kTenCongCuDuBao,
  kTenCongCuTongQuan,
  kTenCongCuDanhMuc,
};

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
  /// [cauHoi] là câu hỏi gốc của người dùng (2026-09-25, mục 9.28): tool nào đọc
  /// được tham số thẳng từ câu hỏi bằng luật thì chỉnh args trước khi kiểm —
  /// hôm nay `truy_van_giao_dich` và `danh_sach_ngan_sach` (`chinh_tham_so.dart`);
  /// tool khác bỏ qua.
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
    String cauHoi = '',
  });
}

/// Chữ trên dòng chỉ báo trong lúc tool chạy — một chỗ, để màn không giữ bảng
/// tên tool riêng.
String cauDangTraCuu(String tenCongCu) => switch (tenCongCu) {
      kTenCongCuNganSach => 'Đang tra cứu ngân sách…',
      kTenCongCuHoaDon => 'Đang tra cứu hoá đơn…',
      kTenCongCuVi => 'Đang tra cứu ví…',
      kTenCongCuMucTieu => 'Đang tra cứu mục tiêu…',
      kTenCongCuGoiYHanMuc => 'Đang tính gợi ý hạn mức…',
      kTenCongCuTruyVan => 'Đang tra cứu giao dịch…',
      kTenCongCuDuBao => 'Đang dự báo dòng tiền…',
      kTenCongCuTongQuan => 'Đang tổng hợp tài chính…',
      kTenCongCuDanhMuc => 'Đang tra cứu danh mục…',
      _ => 'Đang tra cứu…',
    };
