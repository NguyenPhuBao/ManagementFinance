/// Điều chỉnh số dư ví (đối soát) — **nơi duy nhất** định nghĩa cả phép tính
/// khoản bù, khuôn ghi chú, và phép nhận dạng ngược.
///
/// ## Việc này là gì
///
/// Người dùng đếm ví ngoài đời rồi nhập **số dư thực tế**; app sinh một khoản
/// bù để lịch sử giao dịch khớp lại với số ấy. Khoản bù **không vào thống kê**:
/// nó không phải thu nhập cũng không phải chi tiêu, chỉ là phép sửa sổ. Đây là
/// khuôn của Money Lover, và là lối thoát duy nhất cho việc số dư trôi khỏi
/// lịch sử.
///
/// ## Vì sao khoản bù là `thu`/`chi` chứ không phải `transfer`
///
/// `transfer` **đã** bị loại khỏi thống kê sẵn, nên thoạt nhìn nó tiện hơn.
/// Nhưng `TransactionRepository._applyBalances` **cố ý không động vào ví nào**
/// khi khoản chuyển thiếu ví đích ("đừng trừ một nửa") — nên khoản bù kiểu ấy
/// sẽ không đổi số dư, và xoá nó cũng không hoàn lại. Dùng `thu`/`chi` thì cả
/// phép cộng trừ lẫn phép hoàn lại khi xoá đều có sẵn và đúng cả hai chiều.
///
/// ## Vì sao nhận dạng bằng CẶP điều kiện
///
/// `transaction.Note` **sửa được** — xem `TRANSACTION_NOTE_ENCODING.md`. Một
/// dấu hiệu chỉ nằm trong ghi chú có thể mất, và mất thì khoản bù lặng lẽ trở
/// thành thu nhập thật: sai một **con số**, không chỉ sai một nhãn.
///
/// Chân thứ hai là cấu trúc: khoản bù **không mang danh mục**, mà giao diện
/// thêm giao dịch **bắt buộc chọn danh mục** cho mọi khoản `thu`/`chi`
/// (`add_transaction_page.dart:496`). Một khoản thu/chi không danh mục là thứ
/// giao diện không tạo ra được.
///
/// Riêng chân ấy thì **không đủ**: giao dịch kéo về từ server có thể trống danh
/// mục — 17 hàng như thế đã có trên CSDL, đo 2026-09-10 — nên chỉ nhìn danh mục
/// rỗng mà loại khỏi thống kê là giấu mất thu chi thật của người dùng.
///
/// Cả hai chân đều **đồng bộ được**: không cột cục bộ nào, khác hẳn cột `status`
/// của lưu trữ ví (G28).
library;

/// Tiền tố của mọi ghi chú khoản điều chỉnh. Nơi ghi và nơi đọc dùng chung
/// hằng số này, nên chúng không lệch nhau được.
const String tienToDieuChinh = 'Điều chỉnh số dư';

/// Ngưỡng coi hai số dư là bằng nhau, tính bằng **đồng**.
///
/// Số dư là `double` và mọi phép cộng dồn trên `double` đều để lại đuôi lẻ.
/// Không có ngưỡng thì một ví "đúng" vẫn đẻ ra khoản bù `0,0000001đ` ở mỗi lần
/// mở màn — và `chk_transaction_nonzero_amount` của PostgreSQL cho nó đi qua,
/// vì nó khác 0 thật. Nửa đồng là mức nhỏ nhất có nghĩa với tiền Việt.
const double _nguongBangNhau = 0.5;

/// Khoản bù cần ghi để số dư khớp với thực tế.
class KhoanDieuChinh {
  const KhoanDieuChinh({required this.loai, required this.soTien});

  /// `'thu'` khi thực tế nhiều hơn sổ, `'chi'` khi ít hơn.
  final String loai;

  /// Luôn **dương** — chiều nằm ở [loai], đúng quy ước của bảng `transactions`
  /// và của `_applyBalances`.
  final double soTien;
}

/// Tính khoản bù, hoặc `null` nếu không cần ghi gì.
///
/// Trả `null` khi hai số bằng nhau (trong [_nguongBangNhau]) là **chốt chặn bắt
/// buộc**, không phải phép dọn cho gọn: PostgreSQL có
/// `chk_transaction_nonzero_amount` bắt `Amount <> 0` (đo 2026-09-10), nên một
/// khoản 0đ là bản ghi vỡ ở tầng CSDL rồi kẹt hàng đợi đẩy — im lặng.
KhoanDieuChinh? tinhKhoanDieuChinh({
  required double soDuHienTai,
  required double soDuThucTe,
}) {
  final chenh = soDuThucTe - soDuHienTai;
  if (chenh.abs() < _nguongBangNhau) return null;
  return KhoanDieuChinh(
    loai: chenh > 0 ? 'thu' : 'chi',
    soTien: chenh.abs(),
  );
}

/// Dựng ghi chú cho khoản bù. [lyDo] rỗng thì chỉ còn tiền tố.
String ghiChuDieuChinh(String lyDo) {
  final s = lyDo.trim();
  return s.isEmpty ? tienToDieuChinh : '$tienToDieuChinh: $s';
}

/// "Hàng này có phải khoản điều chỉnh số dư không" — phép hỏi **duy nhất**.
///
/// Đòi đủ **cả ba**: là `thu`/`chi` (khoản chuyển đã có luật loại riêng, nhận
/// nó ở đây là hai luật cùng nói về một hàng), **không** danh mục, và ghi chú
/// mở đầu bằng [tienToDieuChinh].
bool laKhoanDieuChinh({
  required String loai,
  required String? categoryId,
  required String? ghiChu,
}) {
  if (loai != 'thu' && loai != 'chi') return false;
  if (categoryId != null) return false;
  return (ghiChu ?? '').trimLeft().startsWith(tienToDieuChinh);
}
