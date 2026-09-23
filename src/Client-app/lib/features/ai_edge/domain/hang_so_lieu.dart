/// Một HÀNG đầy đủ — thứ chặng 4a đo được là còn thiếu (spec 4b mục 3.3).
///
/// Gói số của 4a mang tên trên từng `SoLieu` rời: `Quá hạn: 1` ở một dòng và
/// `Kiem · Đã quá hạn: 45.000 đ` ở dòng khác, và E2B không nối được hai mục
/// rời bằng suy luận (bảng "Đo lại sau chặng 4a", mục 5.6
/// `docs/AI_AGENT_ARCHITECTURE.md`). Hàng gom **tên + trạng thái + các số** của
/// một đối tượng vào một chỗ, và trả cho mô hình dưới dạng MỘT object JSON.
///
/// ⚠️ [HangSoLieu.json] bơm `SoLieu.chuoi` — chuỗi đã định dạng — không bơm
/// `soTho`, cùng lý lẽ với `slm_prompt.dart`: mô hình chép nguyên chuỗi thì
/// `kiemSo` khớp.
library;

import 'goi_so.dart';

class HangSoLieu {
  /// Tên đối tượng: "Kiem", "Giáo dục", "Tiền mặt", "Ăn uống".
  final String ten;

  /// Chữ do DOMAIN quyết ("đã quá hạn", "vượt hạn mức", "đang âm"); `null` khi
  /// hàng không có trạng thái (danh mục chi).
  final String? trangThai;

  /// Do tool gán từ enum domain. `GoiSoTraCuu` suy `muc` từ cờ này, KHÔNG đọc
  /// chuỗi [trangThai] để đoán — đổi một chữ trong nhãn là đổi mức im lặng.
  final bool canhBao;

  /// Mỗi mục mang `ten == ten` của hàng — `kiemNhan` đòi câu nêu tên.
  final List<SoLieu> soLieu;

  const HangSoLieu({
    required this.ten,
    required this.trangThai,
    required this.canhBao,
    required this.soLieu,
  });

  Map<String, dynamic> get json => {
        'ten': ten,
        if (trangThai != null) 'trang_thai': trangThai,
        for (final s in soLieu) s.nhan: s.chuoi,
      };
}

/// Kết quả MỘT lần chạy tool: các hàng (đã xếp theo thứ tự đáng chú ý, tối đa
/// `kToiDaMucMoiGoi`), mục tổng hợp không tên, chữ kèm không số, hoặc lời từ
/// chối khi tham số lạ.
class KetQuaCongCu {
  final List<HangSoLieu> hang;
  final List<SoLieu> tongHop;

  /// Chữ KHÔNG chứa chữ số kèm cho mô hình, ví dụ `{'ky': 'tháng trước'}`. Số
  /// ở đây sẽ không có trong gói và làm câu bị chặn.
  final Map<String, String> chuThem;

  /// Tool từ chối tham số lạ thì nói vì sao ở đây — mô hình đọc được, và người
  /// gọi biết tool ĐÃ chạy (không phải L1).
  final String? loi;

  /// Tên xuất hiện trong kết quả mà KHÔNG nằm trên `SoLieu` nào — tên danh mục /
  /// ví trong chữ trạng thái của hàng giao dịch, tên khớp tham số, danh sách tên
  /// trong lời từ chối (bước 2). `GoiSoTraCuu` gom chúng vào `tenDoiTuong` để
  /// chữ số trong những tên ấy không bị bộ kiểm đọc là số (bước 1c). **Không** vào
  /// [json]: tên đã có sẵn trong `trang_thai` / `loi`.
  final List<String> tenLienQuan;

  const KetQuaCongCu({
    required this.hang,
    required this.tongHop,
    this.chuThem = const {},
    this.loi,
    this.tenLienQuan = const [],
  });

  const KetQuaCongCu.loi(String vi, {this.tenLienQuan = const []})
      : hang = const [],
        tongHop = const [],
        chuThem = const {},
        loi = vi;

  Map<String, dynamic> get json => {
        if (hang.isNotEmpty) 'hang': [for (final h in hang) h.json],
        for (final s in tongHop) s.nhan: s.chuoi,
        ...chuThem,
        if (loi != null) 'loi': loi,
      };
}
