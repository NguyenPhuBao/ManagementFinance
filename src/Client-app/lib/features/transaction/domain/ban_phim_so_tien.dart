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
  if (phim == 'done' || phim == '+' || phim == '-' || phim == '.') {
    return hienTai;
  }

  final daDung = _demChuSo(hienTai);
  final conCho = kSoChuSoToiDaSoTien - daDung;
  if (conCho <= 0) return hienTai;

  if (phim == '00' || phim == '000') {
    // Số 0 đứng một mình thì "000" là một con số vô nghĩa — hành vi cũ, giữ.
    if (hienTai == '0') return hienTai;
    // ⚠️ CẮT BỚT cho vừa trần thay vì bỏ cả cụm: bỏ cả cụm thì người dùng bấm
    // mà không thấy gì xảy ra, còn cắt bớt thì họ được đúng phần còn chỗ.
    final them = conCho < phim.length ? conCho : phim.length;
    return hienTai + '0' * them;
  }

  if (hienTai == '0') return phim;
  return hienTai + phim;
}

int _demChuSo(String s) {
  var n = 0;
  for (final ma in s.codeUnits) {
    if (ma >= 48 && ma <= 57) n++;
  }
  return n;
}
