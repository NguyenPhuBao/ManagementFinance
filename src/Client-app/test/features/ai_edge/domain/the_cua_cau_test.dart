/// Thẻ số liệu đi kèm câu trả lời = **những con số câu ấy thật sự nhắc tới**
/// (điều kiện 12 đặc tả gốc). Trước 2026-09-22 tối nó nằm trong
/// `ai_chat_page._theChoCau` và so bằng `cau.contains(s.chuoi)` — so **chuỗi
/// con**, nên khi hai gói hoá đơn và ví mang số đếm ngắn (`Số cam kết 15`,
/// `Quá hạn 1`, `Số ví 4`) thì câu *"…tổng thu 15.135.000 đ"* kéo theo cả bốn
/// thẻ ấy trên máy thật. Thẻ thành tiếng ồn thay vì nguồn kiểm chứng.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flowmoney/features/ai_edge/domain/the_cua_cau.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gia extends GoiSo {
  @override
  final String man;
  @override
  final List<SoLieu> soLieu;
  _Gia(this.man, this.soLieu);
  @override
  bool get thieuDuLieu => false;
  @override
  NhanXet mauCau() =>
      NhanXet(cau: '', theSoLieu: soLieu, muc: MucNhanXet.binhThuong);
}

void main() {
  final phanTich = _Gia('phan_tich', [
    soTien('Tổng chi', 2141000),
    soTien('Tổng thu', 15135000),
    soPhanTram('Để dành', 85.4),
  ]);
  final hoaDon = _Gia('hoa_don', [
    soDem('Số cam kết', 15),
    soDem('Quá hạn', 1),
  ]);
  final vi = _Gia('vi', [soDem('Số ví', 4)]);

  test('⭐ số đếm ngắn KHÔNG khớp vì là chuỗi con của một số tiền', () {
    // Chính màn máy thật 2026-09-22 tối: câu chỉ nhắc hai số tiền mà thẻ in
    // thêm "Số cam kết 15", "Quá hạn 1", "Số ví 4".
    final the = theCuaCau(
      'Chi tiêu tháng này là 2.141.000 đ trên tổng thu 15.135.000 đ.',
      [phanTich, hoaDon, vi],
    );
    expect(the, ['Tổng chi 2.141.000 đ', 'Tổng thu 15.135.000 đ']);
  });

  test('cùng phép khớp với bộ kiểm số: loại và ngưỡng theo `soLieuKhop`', () {
    // 85,4% khớp phần trăm, không khớp tiền; câu không nhắc 2.141.000 thì
    // không có thẻ ấy.
    expect(theCuaCau('Bạn để dành 85,4% thu nhập.', [phanTich]),
        ['Để dành 85,4%']);
  });

  test('số đếm được nhắc THẬT thì có thẻ', () {
    expect(theCuaCau('Có 15 cam kết, 1 quá hạn.', [hoaDon]),
        ['Số cam kết 15', 'Quá hạn 1']);
  });

  test('hai nhãn ở hai gói cùng một con số → MỘT thẻ, lấy nhãn gặp trước', () {
    // `Tổng chi` (phân tích) và `Chi` (trang chủ) cùng đọc `tk.tong.chi`.
    final trangChu = _Gia('trang_chu', [soTien('Chi', 2141000)]);
    expect(theCuaCau('Chi 2.141.000 đ.', [phanTich, trangChu]),
        ['Tổng chi 2.141.000 đ']);
  });

  test('câu không có số thì không thẻ', () {
    expect(theCuaCau('Bạn đang chi tiêu đúng nhịp.', [phanTich]), isEmpty);
  });
}
