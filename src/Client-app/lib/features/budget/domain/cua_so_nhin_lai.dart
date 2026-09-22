/// Cửa sổ nhìn lại để suy một mức "mỗi tháng" từ lịch sử — **định nghĩa duy
/// nhất** của phép ấy trong app.
///
/// ## Vì sao nó tồn tại
///
/// Trước 2026-09-21, hai chỗ trong app tự cắt **ba tháng lịch đã đóng**:
/// `BudgetRepositoryImpl.suggestAmount` (gợi ý hạn mức) và
/// `TaiPhanBoNguonImpl._thuNhapMoiThang` (thu nhập nuôi phép neo ngưỡng).
///
/// Đo trên CSDL dev ngày 2026-09-21: **79** giao dịch sống, giao dịch **sớm
/// nhất là 02/09/2026**, và **0** hàng trước tháng 9. Tức không tài khoản nào
/// có một tháng lịch đã đóng nào có dữ liệu — cả hai hàm trả về rỗng trên mọi
/// tài khoản, **im lặng**. Hệ quả: gợi ý hạn mức trong form tạo ngân sách chưa
/// từng hiện một con số nào kể từ khi vào repo ngày 2026-09-06 (`f746a32`), và
/// `thuNhapMoiThang` luôn bằng 0 nên phép neo ngưỡng theo thu nhập luôn rơi về
/// sàn.
///
/// Dự án vốn đã có lối cuộn ở một nơi — `goal_history_filter.dart` lùi theo
/// **ngày** chứ không theo tháng lịch. Tệp này đưa lối ấy thành luật chung.
///
/// Spec: `docs/superpowers/specs/2026-09-21-cua-so-nhin-lai-va-de-xuat-tao-ngan-sach-design.md`
library;

/// Nhìn lại tối đa 90 ngày. Dài hơn thì thói quen chi tiêu cũ lấn át hiện tại.
const int kSoNgayNhinLai = 90;

/// Dưới 14 ngày thì **im hẳn**: suy một mức "mỗi tháng" từ chưa đầy hai tuần là
/// bịa một lời hứa.
const int kSoNgayToiThieu = 14;

/// Số ngày quy ước của một tháng khi đổi mức ngày sang mức tháng.
const int kSoNgayMotThang = 30;

/// Khoảng thời gian dùng làm nền cho một con số "mỗi tháng".
class CuaSoNhinLai {
  /// Mốc bắt đầu, **đóng**.
  final DateTime from;

  /// Mốc kết thúc, **mở** — biên `[from, to)`, cùng quy ước với `watchKhoang`
  /// và `tongThuChi`.
  final DateTime to;

  /// Số ngày thật của cửa sổ. Đây là **mẫu số** khi quy về mức tháng.
  final int soNgay;

  const CuaSoNhinLai({
    required this.from,
    required this.to,
    required this.soNgay,
  });
}

/// Cửa sổ nhìn lại tính tới [now], với [mocDauTien] là giao dịch đầu tiên của
/// **tài khoản**.
///
/// Trả `null` khi chưa đủ dữ liệu để nói. **`null` có đúng một nghĩa: *chưa đủ
/// để nói*** — người gọi phải im hẳn. `?? 0` ở đây biến "tôi chưa biết" thành
/// "bạn không chi gì", hai câu khác hẳn nhau; cùng luật với `duBaoHoanThanh`
/// của mục tiêu tiết kiệm.
///
/// ⚠️ [mocDauTien] là mốc của **TÀI KHOẢN**, không phải của danh mục đang xét.
/// Lấy theo danh mục thì một danh mục vừa phát sinh **hôm qua** có mẫu số 1
/// ngày, và mức tháng của nó phồng lên **30 lần** — một con số hoàn toàn hợp lý
/// về hình thức và hoàn toàn sai. Đây là chỗ dễ vấp nhất của cả mảng này.
CuaSoNhinLai? cuaSoNhinLai(DateTime now, DateTime? mocDauTien) {
  if (mocDauTien == null) return null;

  final tran = now.subtract(const Duration(days: kSoNgayNhinLai));
  final from = mocDauTien.isAfter(tran) ? mocDauTien : tran;

  // Đếm theo ngày trọn, KHÔNG làm tròn lên: đây là mẫu số, nên làm tròn lên là
  // làm mọi mức tháng nhỏ đi một cách im lặng.
  final soNgay = now.difference(from).inDays;
  if (soNgay < kSoNgayToiThieu) return null;

  // ⚠️ `to = now`, tức ĐÓNG ở đầu sau. CSDL thật có giao dịch ghi **ngày tương
  // lai** (khoản trích tự động của mục tiêu, 10/10 và 10/11), và một cửa sổ hở
  // đầu sau sẽ nuốt tiền chưa tiêu vào một con số nói về quá khứ.
  return CuaSoNhinLai(from: from, to: now, soNgay: soNgay);
}

/// Số ngày còn thiếu để cửa sổ nhìn lại đủ [kSoNgayToiThieu] — để giao diện
/// **nói ra** thay vì im.
///
/// `null` khi không có gì để đếm ngược: chưa có giao dịch nào ([soNgayCoDuLieu]
/// là `null`), hoặc đã đủ ngày. Hai ca `null` ấy cố ý gộp: chỗ gọi chỉ cần biết
/// *có cần nói "cần thêm N ngày" không*, và cả hai đều là "không cần".
///
/// ⚠️ Đây là ngoại lệ có chủ ý với luật "khối rỗng thì ẩn hẳn": "cần thêm 5
/// ngày dữ liệu" **là** tin, không phải khối rỗng. Im lặng ở đây chính là thứ
/// đã che `suggestAmount` chết suốt hai tuần.
int? soNgayConThieu(int? soNgayCoDuLieu) {
  if (soNgayCoDuLieu == null) return null;
  final thieu = kSoNgayToiThieu - soNgayCoDuLieu;
  return thieu > 0 ? thieu : null;
}
