/// Phép gõ của bàn phím số trên màn Thêm giao dịch — **định nghĩa duy nhất**.
///
/// ## Vì sao tách khỏi widget
///
/// Màn ấy không dùng `TextField` mà **tự vẽ bàn phím**, nên không áp
/// `inputFormatters` được — tức [GioiHanSoChuSo] không với tới đây. Trần số chữ
/// số phải chặn ngay trong phép gõ, và tách ra hàm thuần thì nó có đúng một chỗ
/// định nghĩa, test được mà không phải dựng cả trang.
///
/// ## Trần này chặn cái gì
///
/// `transaction."Amount"` là **`numeric(15,2)`**: nhiều nhất **13 chữ số phần
/// nguyên**. Tràn cho SQLSTATE `22003`, mà `sync.service.js` **không có nhánh
/// nào** cho mã ấy nên nó rơi về `DB_ERROR`; và `_permanentCodes` của
/// `SyncEngine` là **danh sách trắng**, `DB_ERROR` không nằm trong đó. Kết quả:
/// giao dịch bị **gửi lại ở mọi chu kỳ đồng bộ** — không lỗi, không log, chỉ
/// một hàng đợi càng lúc càng chậm. Cùng vòng lặp mà G31 và G14 sinh ra để
/// chặn, và cùng lỗ hổng vừa vá ở ô số dư ví (G45).
///
/// ⚠️ Chỗ này **nặng hơn ô số dư ví** ở hai điểm: giao dịch là thứ người dùng
/// ghi hàng ngày, và bàn phím có phím **`000`** nên ba chữ số vào một lúc.
library;

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/gioi_han_do_dai.dart';

/// Chuỗi số mới sau khi bấm [phim] trên chuỗi [hienTai].
///
/// [phim] là một chữ số, `'00'`, `'000'`, `'backspace'`, hoặc một phím không
/// đổi gì (`'done'`, `'+'`, `'-'`, `'.'`).
///
/// ⚠️ Trần đếm **chữ số**, không đếm ký tự: một chuỗi có dấu thập phân dài hơn
/// số chữ số của nó, và đếm cả dấu chấm là chặn sớm hơn thật. Chuỗi có dấu
/// chấm vẫn **vào được** qua chế độ sửa — `transaction."Amount"` là
/// `numeric(15,2)` nên số lẻ tồn tại thật — chỉ là không gõ mới ra được.
String themPhimSoTien(String hienTai, String phim) {
  if (phim == 'backspace') {
    if (hienTai.length > 1) return hienTai.substring(0, hienTai.length - 1);
    return '0';
  }

  // ⚠️ `'.'` KHÔNG đổi gì (A12, 2026-09-19). Phím ấy đã bị bỏ khỏi lưới, nhưng
  // nhánh vô hiệu thì giữ: nó từng sinh ra một chuỗi mà `_saveTransaction`
  // strip dấu chấm rồi đọc tiếp, nên `12.5` lưu thành **125** — sai gấp mười,
  // im lặng. Giữ nhánh ở đây để phím có quay lại lưới cũng không phá được.
  if (phim == 'done' || phim == '.') return hienTai;

  if (phim == kToanTuCong || phim == kToanTuTru) {
    // Mở đầu bằng "0 +" không có nghĩa — cùng luật với phím 000.
    if (hienTai == '0') return hienTai;
    final i = _viTriToanTu(hienTai);
    if (i < 0) return hienTai + phim;
    // Vừa gõ toán tử xong thì phím kia THAY nó: bấm lỡ tay phải sửa được,
    // còn "50000+-" là một chuỗi không đọc được.
    if (i == hienTai.length - 1) return hienTai.substring(0, i) + phim;
    // Đã đủ hai vế → rút gọn trước rồi mới nối toán tử mới (nếp máy tính bỏ
    // túi). Nhờ vậy chuỗi luôn có NHIỀU NHẤT MỘT phép toán đang chờ, nên
    // không cần bộ phân tích biểu thức và không có thứ tự ưu tiên để hiểu sai.
    return _chuoiSoNguyen(ketQuaBieuThuc(hienTai)) + phim;
  }

  // ⚠️ Từ đây là chữ số và cụm số 0 — chúng áp vào **VẾ ĐANG GÕ**, không phải
  // cả chuỗi. Đếm chữ số của cả biểu thức thì vế trước đã ăn hết suất và vế
  // sau bị chặn sớm hơn thật tới 12 chữ số.
  final i = _viTriToanTu(hienTai);
  final dauVe = i < 0 ? 0 : i + 1;
  final truoc = hienTai.substring(0, dauVe);
  final ve = hienTai.substring(dauVe);

  final conCho = kSoChuSoToiDaSoTien - _demChuSo(ve);
  if (conCho <= 0) return hienTai;

  if (phim == '00' || phim == '000') {
    // Số 0 đứng một mình thì "000" là một con số vô nghĩa — hành vi cũ, giữ.
    // Vế rỗng (vừa gõ toán tử) cũng vậy.
    if (ve.isEmpty || ve == '0') return hienTai;
    // ⚠️ CẮT BỚT cho vừa trần thay vì bỏ cả cụm: bỏ cả cụm thì người dùng bấm
    // mà không thấy gì xảy ra, còn cắt bớt thì họ được đúng phần còn chỗ.
    final them = conCho < phim.length ? conCho : phim.length;
    return hienTai + '0' * them;
  }

  if (ve.isEmpty || ve == '0') return truoc + phim;
  return hienTai + phim;
}

/// Phím cộng và phím trừ — giá trị NỘI BỘ của chuỗi biểu thức.
///
/// Phím trừ dùng gạch nối ASCII ở đây cho dễ phân tích; chỗ **hiển thị** thì
/// đổi sang dấu trừ thật `−` (xem [nhanBieuThuc]).
const String kToanTuCong = '+';
const String kToanTuTru = '-';

/// Trần số tiền suy thẳng từ [kSoChuSoToiDaSoTien] — đừng ghi cứng con số,
/// đổi hằng kia mà quên chỗ này là hai luật rời nhau.
final double _tranSoTien = double.parse('9' * kSoChuSoToiDaSoTien);

/// Vị trí toán tử trong [s], hoặc `-1` khi chuỗi chỉ có một vế.
///
/// Tìm từ **chỉ số 1**: vế đầu luôn có ít nhất một chữ số, nên ký tự đầu
/// không bao giờ là toán tử.
int _viTriToanTu(String s) {
  for (var i = 1; i < s.length; i++) {
    if (s[i] == kToanTuCong || s[i] == kToanTuTru) return i;
  }
  return -1;
}

String _chuoiSoNguyen(double v) => v.toInt().toString();

/// Giá trị của [bieuThuc] sau khi rút gọn phép toán đang chờ.
///
/// ⚠️ **Kết quả bị KẸP TRẦN.** Hai vế 13 chữ số cộng lại ra 14 chữ số, vượt
/// `numeric(15,2)` của `transaction."Amount"` — tràn cho SQLSTATE `22003`, mà
/// `sync.service.js` không có nhánh cho mã ấy nên nó rơi về `DB_ERROR`, thứ
/// **không** nằm trong danh sách trắng `_permanentCodes`; giao dịch bị gửi lại
/// ở mọi chu kỳ đồng bộ, im lặng. Cùng vòng lặp G31/G14/G46.
///
/// ⚠️ **Hiệu được phép ÂM** và không kẹp về 0: `_saveTransaction` đã có chốt
/// `amount <= 0` báo thẳng ra màn hình, còn kẹp ở đây thì `30000-50000` lặng
/// lẽ thành 0 rồi bị chốt kia từ chối với một lời nhắn chẳng ăn nhập. (Phía
/// âm không cần kẹp: hai vế đều không âm nên hiệu nhỏ nhất đúng bằng âm trần.)
double ketQuaBieuThuc(String bieuThuc) {
  final i = _viTriToanTu(bieuThuc);
  final trai = double.tryParse(
          bieuThuc.substring(0, i < 0 ? bieuThuc.length : i)) ??
      0;
  if (i < 0) return _kepTran(trai);
  final phai = bieuThuc.substring(i + 1);
  // Toán tử lẻ ở cuối: người dùng bấm ✓ ngay sau nó — hiểu là chưa nhập vế
  // sau, không phải cộng thêm chính nó.
  if (phai.isEmpty) return _kepTran(trai);
  final b = double.tryParse(phai) ?? 0;
  return _kepTran(bieuThuc[i] == kToanTuCong ? trai + b : trai - b);
}

double _kepTran(double v) {
  if (v > _tranSoTien) return _tranSoTien;
  if (v < -_tranSoTien) return -_tranSoTien;
  return v;
}

/// Chuỗi có toán tử hay không — kể cả toán tử **lẻ** ở cuối.
///
/// ⚠️ Khác [coPhepToanDangCho], và hai chỗ gọi không thay nhau được: hàm này
/// quyết định dòng số hiện dạng **biểu thức** (`"50.000 +"`) hay dạng **số
/// tiền** (`"50.000 đ"`), còn hàm kia quyết định có hiện dòng kết quả không.
/// Với `"50000+"` thì hàm này đúng còn hàm kia sai.
bool coToanTu(String bieuThuc) => _viTriToanTu(bieuThuc) >= 0;

/// Có một phép toán **đủ hai vế** đang chờ rút gọn hay không.
///
/// Dùng để quyết định có hiện dòng "= …" dưới con số: chuỗi mới có toán tử mà
/// chưa có vế sau thì dòng ấy trống nghĩa.
bool coPhepToanDangCho(String bieuThuc) {
  final i = _viTriToanTu(bieuThuc);
  return i >= 0 && i < bieuThuc.length - 1;
}

/// [bieuThuc] ở dạng người đọc: mỗi vế ngăn nghìn riêng, toán tử có khoảng
/// trắng hai bên. Không kèm ký hiệu tiền — một biểu thức chưa phải một số tiền.
///
/// ⚠️ Phép trừ hiện bằng dấu trừ thật `−` (U+2212), không phải gạch nối: gạch
/// nối ở ngay trước một con số đọc như **dấu âm**.
String nhanBieuThuc(String bieuThuc) {
  final i = _viTriToanTu(bieuThuc);
  final trai = CurrencyFormatter.formatSoThoi(
      double.tryParse(bieuThuc.substring(0, i < 0 ? bieuThuc.length : i)) ?? 0);
  if (i < 0) return trai;
  final dau = bieuThuc[i] == kToanTuCong ? '+' : '−';
  final phai = bieuThuc.substring(i + 1);
  if (phai.isEmpty) return '$trai $dau';
  return '$trai $dau '
      '${CurrencyFormatter.formatSoThoi(double.tryParse(phai) ?? 0)}';
}

int _demChuSo(String s) {
  var n = 0;
  for (final ma in s.codeUnits) {
    if (ma >= 48 && ma <= 57) n++;
  }
  return n;
}

