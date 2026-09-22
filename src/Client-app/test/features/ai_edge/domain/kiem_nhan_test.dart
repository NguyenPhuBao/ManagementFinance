/// Bộ kiểm NHÃN — lớp chắn thứ ba, sinh ra từ điểm 4 cổng A hỏng theo đường
/// không ai lường (mục 9.5 `AI_EDGE_FEATURE.md`): mô hình không bịa **con
/// số** mà bịa **cái tên** của con số. *"Tỉ lệ phân bổ là 85,4%"* — mọi số
/// đều thật (85,4 % là tỉ lệ *để dành*), nên `kiemSo` cho qua.
///
/// Ca quan trọng nhất của tệp là ca chép **nguyên văn** câu đo trên máy thật.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_nhan.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
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
  // Đúng gói phân tích của tài khoản 10 ngày 2026-09-22 (mục 9.5).
  final phanTich = _Gia('phan_tich', [
    soTien('Tổng chi', 2141000),
    soTien('Tổng thu', 15135000),
    soPhanTram('Để dành', 85.4),
  ]);

  group('tuKhoaNhan', () {
    test('bỏ âm tiết chung (tổng, số, đã, so, với, là), giữ phần có nghĩa',
        () {
      expect(tuKhoaNhan('Tổng chi'), ['chi']);
      expect(tuKhoaNhan('Để dành'), ['để', 'dành']);
      expect(tuKhoaNhan('Số cam kết'), ['cam', 'kết']);
      expect(tuKhoaNhan('So kỳ trước'), ['kỳ', 'trước']);
    });

    test('nhãn chỉ toàn âm tiết chung thì giữ nguyên nhãn', () {
      expect(tuKhoaNhan('Tổng'), ['tổng']);
    });

    test('nhãn một âm tiết có nghĩa giữ nguyên', () {
      expect(tuKhoaNhan('Còn'), ['còn']);
    });
  });

  test('⭐ câu đo trên máy thật 2026-09-22 bị chặn ở vế gán sai nhãn', () {
    expect(
      kiemNhan('Tỉ lệ phân bổ là 85,4%.', [phanTich]),
      isFalse,
      reason: '85,4 chỉ khớp nhãn "Để dành" mà câu không có chữ "để dành" — '
          'đây là đúng câu mô hình đã nói, mọi số đều thật',
    );
  });

  test('câu dùng đúng nhãn thì qua', () {
    expect(
      kiemNhan(
        'Chi tiêu tháng này là 2.141.000 đ trên tổng thu 15.135.000 đ.',
        [phanTich],
      ),
      isTrue,
    );
    expect(kiemNhan('Bạn để dành được 85,4% thu nhập.', [phanTich]), isTrue);
  });

  test('không phân biệt hoa thường', () {
    expect(kiemNhan('Để Dành 85,4%.', [phanTich]), isTrue);
  });

  test('câu không có số nào thì qua — không có nhãn nào để gán sai', () {
    expect(kiemNhan('Bạn đang chi tiêu đúng nhịp.', [phanTich]), isTrue);
  });

  test('số không khớp nhãn nào thì chặn — không có nhãn để thoả', () {
    expect(kiemNhan('Bạn để dành 99,0%.', [phanTich]), isFalse);
  });

  test('số khớp HAI nhãn ở hai gói: đủ một nhãn là qua', () {
    // `Tổng chi` (phân tích) và `Chi` (trang chủ) cùng giá trị — có thật,
    // hai gói cùng đọc `tk.tong.chi`.
    final trangChu = _Gia('trang_chu', [soTien('Chi', 2141000)]);
    expect(
      kiemNhan('Tháng này chi 2.141.000 đ.', [phanTich, trangChu]),
      isTrue,
    );
  });

  test('nhãn nhiều âm tiết: đủ mọi âm tiết là qua, thứ tự và chen chữ tự do',
      () {
    final g = _Gia('phan_tich', [soTien('Khoản lớn nhất', 500000)]);
    expect(kiemNhan('Khoản chi lớn nhất là 500.000 đ.', [g]), isTrue);
    expect(kiemNhan('Lớn nhất là 500.000 đ.', [g]), isFalse,
        reason: 'thiếu "khoản" — nửa nhãn không đủ');
  });

  test('từ khoá so theo ÂM TIẾT, không theo chuỗi con', () {
    expect(
      kiemNhan('Chiều nay tiêu 2.141.000 đ.', [phanTich]),
      isFalse,
      reason: '"chiều" chứa "chi" nhưng không phải chữ "chi" — so chuỗi con '
          'là để một nhãn lọt qua nhờ một từ khác tình cờ chứa nó',
    );
  });

  test('mỗi số kiểm riêng: một số sai nhãn là cả câu bị chặn', () {
    expect(
      kiemNhan(
        'Tổng chi 2.141.000 đ, tỉ lệ phân bổ 85,4%.',
        [phanTich],
      ),
      isFalse,
    );
  });
}
