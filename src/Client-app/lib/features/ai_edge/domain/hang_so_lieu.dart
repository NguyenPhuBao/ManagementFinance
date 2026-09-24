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
/// `kToiDaMucMoiGoi`), mục tổng hợp không tên, chữ kèm không số — hoặc một lời
/// TỪ CHỐI khi tham số hỏng.
class KetQuaCongCu {
  final List<HangSoLieu> hang;
  final List<SoLieu> tongHop;

  /// Chữ KHÔNG chứa chữ số kèm cho mô hình, ví dụ `{'ky': 'tháng trước'}`. Số
  /// ở đây sẽ không có trong gói và làm câu bị chặn.
  final Map<String, String> chuThem;

  /// Tool từ chối tham số thì nói vì sao ở đây — cho MÔ HÌNH đọc (vào [json]),
  /// đủ để nó gọi lại đúng. ⚠️ Lượt bị từ chối KHÔNG phải dữ liệu (bước 2b, lật
  /// một vế chốt L1 của spec 4b): cổng D lần 1 đo được E2B đọc lời từ chối thành
  /// "không có dữ liệu" (bẫy 4.40), nên `GoiSoTraCuu` không tính nó là đã tra cứu.
  final String? loi;

  /// Câu cho NGƯỜI DÙNG khi tool từ chối — thứ mẫu câu trung thực (L1b / L2b)
  /// nói ra. Không lộ mã tham số, không chép số từ tham số của mô hình, không
  /// khẳng định gì về dữ liệu (spec 2b mục 2.1). **Không** vào [json].
  final String? choNguoiDung;

  /// Tham số mà một lượt THÀNH CÔNG sau đó của CÙNG tool phải điền để gỡ lời từ
  /// chối này — điền một là đủ (spec 2b mục 2.2). **Không** vào [json].
  final List<String> thamSoGo;

  /// Tên xuất hiện trong kết quả mà KHÔNG nằm trên `SoLieu` nào — tên danh mục /
  /// ví trong chữ trạng thái của hàng giao dịch, tên khớp tham số, danh sách tên
  /// trong lời từ chối (bước 2), và tên SAI mô hình vừa gõ trong lời từ chối
  /// (bước 2b). `GoiSoTraCuu` gom chúng vào `tenDoiTuong` để chữ số trong những
  /// tên ấy không bị bộ kiểm đọc là số (bước 1c). **Không** vào [json].
  final List<String> tenLienQuan;

  /// Lượt THÀNH CÔNG mà 0 khoản khớp bộ lọc (bước 2c, bẫy 4.44). Với tool lọc
  /// bằng chữ tự do (`tim_giao_dich`), 0 khoản không phải câu trả lời mà là
  /// một báo cáo về bộ lọc — `GoiSoTraCuu` đóng cổng hiện chữ và không bao giờ
  /// gỡ. Chỉ `hangGiaoDich` đặt. **Không** vào [json].
  final bool rongTheoBoLoc;

  /// Chữ từng điều kiện lọc đã dùng, theo thứ tự cố định (spec 2c mục 2.2), cho
  /// mẫu câu. Được chứa chữ số (khoảng tiền) vì **không** vào [json] — khác
  /// [chuThem]; mỗi con số ở đây phải bằng đúng `chuoi` của một mục
  /// [soLieuBoLoc].
  final List<String> boLoc;

  /// Số liệu dội lại của bộ lọc (Từ / Đến): nằm trong gói (`kiemSo`, thẻ) và
  /// vào [json] y như [tongHop], nhưng mẫu câu **không** in thành vế — tiền tố
  /// [boLoc] đã nêu.
  final List<SoLieu> soLieuBoLoc;

  const KetQuaCongCu({
    required this.hang,
    required this.tongHop,
    this.chuThem = const {},
    this.tenLienQuan = const [],
    this.rongTheoBoLoc = false,
    this.boLoc = const [],
    this.soLieuBoLoc = const [],
  })  : loi = null,
        choNguoiDung = null,
        thamSoGo = const [];

  /// Lời từ chối. Dựng qua các hàm `tuChoi…` của `loi_tham_so.dart` — chỗ duy
  /// nhất dựng đủ câu cho mô hình lẫn câu cho người dùng.
  const KetQuaCongCu.loi(
    String vi, {
    required String this.choNguoiDung,
    required this.thamSoGo,
    this.tenLienQuan = const [],
  })  : hang = const [],
        tongHop = const [],
        chuThem = const {},
        rongTheoBoLoc = false,
        boLoc = const [],
        soLieuBoLoc = const [],
        loi = vi;

  Map<String, dynamic> get json => {
        if (hang.isNotEmpty) 'hang': [for (final h in hang) h.json],
        for (final s in tongHop) s.nhan: s.chuoi,
        for (final s in soLieuBoLoc) s.nhan: s.chuoi,
        ...chuThem,
        if (loi != null) 'loi': loi,
      };
}
