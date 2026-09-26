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

  test('⭐ thẻ nhận ra mục qua nhãn THAY THẾ, in nhãn CHÍNH (bẫy 4.47)', () {
    final giaoDich = _Gia('tra_cuu', [soDem('Số giao dịch', 2, nhanKhac: const ['Số khoản'])]);
    final hoaDon2 = _Gia('hoa_don', [soDem('Quá hạn', 2)]);
    expect(theCuaCau('Có 2 khoản thu.', [hoaDon2, giaoDich]), ['Số giao dịch 2'],
        reason: 'cùng giá trị 2 ở gói hoá đơn đứng TRƯỚC — không có nhãn thay thế '
            'thì thẻ rơi về "Quá hạn 2" (bẫy 4.27), nói về một đại lượng khác hẳn câu');
  });

  test('câu không có số thì không thẻ', () {
    expect(theCuaCau('Bạn đang chi tiêu đúng nhịp.', [phanTich]), isEmpty);
  });

  test('⭐ chữ số trong TÊN không đẻ ra thẻ của một con số khác (bước 1c)', () {
    final hdT9 =
        _Gia('tra_cuu', [soTien('Số tiền', 50000, ten: 'Tiền nhà T9')]);
    final nsCon9 = _Gia('ngan_sach', [soNgay('Còn', 9)]);
    expect(
      theCuaCau('Tiền nhà T9 chưa trả 50.000 đ.', [hdT9, nsCon9]),
      ['Tiền nhà T9 · Số tiền 50.000 đ'],
      reason: 'Chữ số 9 của "T9" khớp "Còn 9 ngày" của gói ngân sách — thẻ ấy '
          'nói về một đại lượng câu không hề nhắc tới. Thẻ là nguồn kiểm '
          'chứng, nên nó phải đọc số bằng đúng phép của bộ kiểm.',
    );
  });

  group('trùng GIÁ TRỊ giữa hai gói — bẫy 4.27 (chặng 4a)', () {
    // Đúng ca máy thật bắt được ở chặng 3: gói hoá đơn có `Quá hạn 1`, gói ví
    // có `Ví đang âm 1`. Cùng giá trị 1, và gói hoá đơn xếp TRƯỚC gói ví.
    final viAm = _Gia('vi', [soDem('Ví đang âm', 1)]);

    test('⭐ câu nói về VÍ thì thẻ lấy nhãn của ví, không phải của hoá đơn', () {
      expect(
        theCuaCau('Ví đang âm: 1', [hoaDon, viAm]),
        ['Ví đang âm 1'],
        reason: 'Khử trùng theo GIÁ TRỊ thì nhãn của gói đứng trước thắng, và '
            'thẻ nói "Quá hạn 1" dưới một câu về ví — đúng thứ máy thật in ra '
            'ngày 2026-09-22. Thẻ sinh ra để làm nguồn kiểm chứng, không phải '
            'để nói về một đại lượng khác.',
      );
    });

    test('câu nói về hoá đơn thì vẫn lấy nhãn hoá đơn', () {
      expect(theCuaCau('Có 1 hoá đơn quá hạn.', [hoaDon, viAm]), ['Quá hạn 1']);
    });

    test('câu không nhắc nhãn nào → giữ hành vi cũ, cái đầu theo thứ tự gói',
        () {
      expect(
        theCuaCau('Con số là 1.', [hoaDon, viAm]),
        ['Quá hạn 1'],
        reason: 'Không có căn cứ nào để chọn thì đừng đoán.',
      );
    });

    test('thẻ nêu TÊN đối tượng khi có', () {
      final nganSach =
          _Gia('ngan_sach', [soPhanTram('Tỉ lệ', 90.0, ten: 'Giáo dục')]);
      expect(theCuaCau('Giáo dục đã dùng 90,0%.', [nganSach]),
          ['Giáo dục · Tỉ lệ 90,0%']);
    });

    test('tên cũng dùng được làm căn cứ chọn nhãn', () {
      final a = _Gia('ngan_sach', [soPhanTram('Tỉ lệ', 90.0, ten: 'Giáo dục')]);
      final b = _Gia('vi', [soPhanTram('Tỉ lệ', 90.0, ten: 'Ăn uống')]);
      expect(theCuaCau('Ăn uống đã dùng 90,0%.', [a, b]),
          ['Ăn uống · Tỉ lệ 90,0%'],
          reason: 'Hai mục cùng nhãn VÀ cùng giá trị, chỉ khác tên — nếu '
              'không xét tên thì thẻ nói về Giáo dục dưới một câu về Ăn uống.');
    });
  });

  group('xét theo TỪNG CÂU — bẫy 4.34 (chặng 4b, OnePlus 2026-09-23)', () {
    // Đúng cặp máy thật bắt được: tool ngân sách trả Di chuyển (hạn mức
    // 450.000) đứng TRƯỚC Ăn uống (còn lại 450.000). Câu trả lời nhắc cả hai
    // tên — ở hai câu khác nhau — và thẻ in "Di chuyển · Hạn mức 450.000 đ"
    // dưới câu "Ăn uống: … Còn lại 450.000 đ".
    final nganSach = _Gia('tra_cuu', [
      soTien('Còn lại', 95000, ten: 'Di chuyển'),
      soTien('Hạn mức', 450000, ten: 'Di chuyển'),
      soTien('Còn lại', 450000, ten: 'Ăn uống'),
    ]);

    test('⭐ số ở câu về Ăn uống lấy mục của Ăn uống, dù Di chuyển được nhắc ở câu khác',
        () {
      expect(
        theCuaCau('Di chuyển còn lại 95.000 đ. Ăn uống còn lại 450.000 đ.',
            [nganSach]),
        ['Di chuyển · Còn lại 95.000 đ', 'Ăn uống · Còn lại 450.000 đ'],
        reason: 'Xét cả tin nhắn thì "Di chuyển" có mặt nên mục Hạn mức của nó '
            'cũng được ưu tiên, và nó đứng trước — đúng thẻ sai máy thật in ra. '
            'Đơn vị phải là CÂU, cùng đơn vị với kiemNhan.',
      );
    });

    test('câu cuối không có dấu kết vẫn được xét', () {
      expect(
        theCuaCau('Di chuyển còn lại 95.000 đ. Ăn uống còn lại 450.000 đ',
            [nganSach]),
        ['Di chuyển · Còn lại 95.000 đ', 'Ăn uống · Còn lại 450.000 đ'],
      );
    });
  });
}
