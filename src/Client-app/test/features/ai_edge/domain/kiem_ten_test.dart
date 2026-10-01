/// Bộ kiểm TÊN — lớp chắn thứ tư, sinh ra từ bẫy 4.48 (cổng D lần 10, B1,
/// 2026-09-25): *"Bạn có thể đặt mục tiêu mua xe hoặc mua nhà."* — câu KHÔNG có
/// con số nào nên `kiemSo` và `kiemNhan` không có gì để kiểm, `kiemGiong` chỉ
/// kiểm giọng; "mua nhà" là tên bịa (mục tiêu thật là MuaXe, MuaDT).
///
/// Ca quan trọng nhất là ca chép nguyên văn câu trên máy thật.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_ten.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gia extends GoiSo {
  @override
  final String man;
  @override
  final List<SoLieu> soLieu;
  /// Tên không gắn trên SoLieu nào (như `tenLienQuan` của gói tra cứu).
  final List<String> them;
  _Gia(this.man, this.soLieu, {this.them = const []});
  @override
  bool get thieuDuLieu => false;
  @override
  NhanXet mauCau() =>
      NhanXet(cau: '', theSoLieu: soLieu, muc: MucNhanXet.binhThuong);
  @override
  Iterable<String> get tenDoiTuong => [...super.tenDoiTuong, ...them];
}

void main() {
  // Đúng gói của B1: hai mục tiêu có tên.
  final mucTieu = _Gia('tra_cuu', [
    soTien('Còn thiếu', 899000, ten: 'MuaXe'),
    soTien('Còn thiếu', 4000000, ten: 'MuaDT'),
  ]);
  // Gói tổng kết + hàng giao dịch: danh mục, ví, hoá đơn có tên.
  final tongKet = _Gia('tra_cuu', [
    soTien('Tổng chi', 2141000),
    soTien('Chi', 800000, ten: 'Cho vay'),
    soTien('Số tiền', 123000, ten: 'Thanh toán hóa đơn: Kiem thu hoa don 2026-09-04'),
    soTien('Số tiền', 50000, ten: 'Ăn uống'),
  ], them: ['Tiền mặt', 'Tiết kiệm', 'test', 'Giáo dục', 'di h0c']);

  test('⭐ câu B1 lần 10 (2026-09-25) bị chặn: "mua nhà" không phải tên mục tiêu nào', () {
    expect(
      kiemTen('Bạn có thể đặt mục tiêu mua xe hoặc mua nhà.', [mucTieu]),
      isFalse,
      reason: 'Nguyên văn trên Realme — không con số nào nên ba lớp chắn cũ im. '
          '"mua xe" khớp MuaXe (bỏ khoảng trắng), "mua nhà" không khớp tên nào.',
    );
  });

  test('⭐ bẫy 4.50 (2026-09-27, câu người dùng tự hỏi): "danh mục đã đặt ngân sách bao gồm: …" qua', () {
    final nganSach = _Gia('tra_cuu', [
      soTien('Còn lại', 5000, ten: 'Giáo dục'),
      soTien('Còn lại', 95000, ten: 'Di chuyển'),
      soTien('Còn lại', 450000, ten: 'Ăn uống'),
      soTien('Còn lại', 790000, ten: 'Mua sắm'),
    ]);
    expect(kiemTen('Các danh mục đã đặt ngân sách bao gồm: Giáo dục, Di chuyển, Ăn uống, Mua sắm.', [nganSach]), isTrue,
        reason: 'bị chặn thật: cụm sau "ngân sách" là "bao gồm" — từ chức năng, không phải tên');
    expect(kiemTen('Ngân sách bao nhiêu thì đủ?', [nganSach]), isTrue);
    expect(kiemTen('Tổng cộng bốn ngân sách các danh mục hiện tại.', [nganSach]), isTrue);
  });

  test('⭐ lát 3 (2026-09-28): "hoá đơn tự trả / dự kiến / cố định" là chữ của tool hoá đơn, không phải tên', () {
    expect(kiemTen('Có 1 hoá đơn tự trả là Kiem thu hoa don.', [tongKet]), isTrue,
        reason: 'bị chặn thật ở ca đơn vị của hangHoaDon: cụm sau "hoá đơn" là "tự trả"');
    expect(kiemTen('Tháng tới có hai hoá đơn dự kiến.', [tongKet]), isTrue);
    expect(kiemTen('Các hoá đơn cố định mỗi tháng.', [tongKet]), isTrue);
    expect(kiemTen('Hoá đơn tự trả là Internet.', [tongKet]), isTrue,
        reason: 'giới hạn cố ý: sau "là" không còn là cụm tên của từ loại — sai theo chiều an toàn '
            'đã có từ trước, không do lát này');
    expect(kiemTen('Hoá đơn Internet tự trả.', [tongKet]), isFalse,
        reason: 'tên bịa đứng TRƯỚC chữ chức năng vẫn bị chặn');
  });

  test('lát 3 Task 10: "ví nguồn" là chữ của tool mục tiêu, không phải tên ví', () {
    expect(kiemTen('Ví nguồn của MuaXe chỉ còn ít tiền.', [mucTieu]), isTrue);
    expect(kiemTen('Có ví nguồn không đủ tiền để trích.', [mucTieu]), isTrue);
  });

  test('⭐ Task 10 lộ ra (có từ trước): cụm MỞ ĐẦU bằng chữ số là giá trị, không phải tên', () {
    expect(kiemTen('MuaXe đã tích 1.101.000 đ trên mục tiêu 2.000.000 đ.', [mucTieu]), isTrue,
        reason: 'mẫu câu "…, Mục tiêu 2.000.000 đ, …" của chính tool mục tiêu từng bị chặn: '
            'cụm sau "mục tiêu" là "2000000 đ"');
    expect(kiemTen('Ví 500.000 đ là ví lớn nhất.', [tongKet]), isTrue);
    expect(kiemTen('Hoá đơn Kiem thu hoa don 2026-09-04 đã thanh toán.', [tongKet]), isTrue,
        reason: 'chữ số GIỮA tên vẫn thuộc tên');
    expect(kiemTen('Mục tiêu Du lịch 2027 đang chậm.', [mucTieu]), isFalse,
        reason: 'tên bịa có chữ số ở cuối vẫn bị chặn');
    expect(kiemTen('Mục tiêu Mua 2 xe đang chậm.', [mucTieu]), isFalse,
        reason: 'chữ số GIỮA cụm không được cắt cụm: cắt ở "2" thì cụm còn "mua" — '
            'chứa trong "muaxe", tên bịa lọt');
  });

  test('tên bịa đứng một mình cũng bị chặn', () {
    expect(kiemTen('Mục tiêu Du lịch của bạn đang chậm.', [mucTieu]), isFalse);
    expect(kiemTen('Ví Ngân hàng đang âm.', [tongKet]), isFalse);
  });

  test('tên thật — nguyên văn, trong ngoặc kép, hay bỏ khoảng trắng — qua', () {
    expect(kiemTen('Bạn có hai mục tiêu "MuaXe" và "MuaDT".', [mucTieu]), isTrue);
    expect(kiemTen('Mục tiêu MuaXe còn thiếu tiền.', [mucTieu]), isTrue);
    expect(kiemTen('Bạn có thể đặt mục tiêu mua xe.', [mucTieu]), isTrue,
        reason: 'mô hình viết tên có khoảng trắng — vẫn là tên thật');
    expect(kiemTen('Ví Tiền mặt của bạn chi nhiều nhất.', [tongKet]), isTrue);
    expect(kiemTen('Danh mục Ăn uống là 50.000 đ.', [tongKet]), isTrue);
    expect(kiemTen('Hoá đơn di h0c còn phải trả.', [tongKet]), isTrue);
  });

  test('cụm dài hơn hay ngắn hơn tên thật: chứa nhau là qua', () {
    expect(
      kiemTen('Hoá đơn Kiem thu hoa don 2026-09-04 đã thanh toán.', [tongKet]),
      isTrue,
      reason: 'tiêu đề hàng dài hơn cụm mô hình nêu — chứa nhau là đủ',
    );
  });

  test('⭐ câu đúng A8 "Các danh mục chi lớn nhất là: Cho vay…" qua — "chi" là từ chức năng, không phải tên', () {
    expect(
      kiemTen(
        'Trong tháng này, tổng chi là 2.141.000 đ. Các danh mục chi lớn nhất là: Cho vay (800.000 đ).',
        [tongKet],
      ),
      isTrue,
    );
  });

  test('từ loại theo sau là từ chức năng thì không phải khẳng định — qua', () {
    for (final cau in [
      'Bạn có hai mục tiêu đang theo đuổi.',
      'Ví nào đó tháng này chi những gì?',
      'Các danh mục sau đây cần xem lại.',
      'Ngân sách của bạn còn 1.340.000 đ.',
      'Hoá đơn sắp đến hạn.',
    ]) {
      expect(kiemTen(cau, [mucTieu, tongKet]), isTrue, reason: cau);
    }
  });

  test('phủ định trước từ loại thì bỏ qua — "không có danh mục nào tên abc" là câu thật', () {
    expect(kiemTen('Không có danh mục "abc" nào trong tháng này.', [tongKet]), isTrue);
    expect(kiemTen('Bạn không có mục tiêu Du lịch.', [mucTieu]), isTrue);
  });

  test('câu không có từ loại nào thì qua — không có khẳng định để kiểm', () {
    expect(kiemTen('Tổng chi tháng này là 2.141.000 đ.', [tongKet]), isTrue);
    expect(kiemTen('Không có dữ liệu.', const []), isTrue);
  });

  test('tên lấy từ MỌI gói, không phân theo từ loại', () {
    expect(kiemTen('Mục tiêu Tiết kiệm của bạn.', [mucTieu, tongKet]), isTrue,
        reason: 'Tiết kiệm là tên ví — vẫn là tên có thật trong gói');
  });
}
