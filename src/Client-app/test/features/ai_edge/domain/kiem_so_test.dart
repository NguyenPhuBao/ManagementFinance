/// Bộ kiểm số — điều kiện 10 của mục 13 bản đánh giá: mọi con số trong câu
/// phải có trong gói số, sai thì rơi về mẫu câu. Đây là câu hội đồng sẽ hỏi
/// ("mô hình bịa số thì sao?"), nên ca "câu bịa một số bị chặn" là ca quan
/// trọng nhất của tệp.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gia extends GoiSo {
  @override
  final String man = 'ngan_sach';
  @override
  final List<SoLieu> soLieu;
  _Gia(this.soLieu);
  @override
  bool get thieuDuLieu => false;
  @override
  NhanXet mauCau() =>
      NhanXet(cau: '', theSoLieu: soLieu, muc: MucNhanXet.binhThuong);
}

void main() {
  final goi = _Gia([
    soTien('Đã chi', 2100000),
    soPhanTram('Tỉ lệ', 70),
    soNgay('Còn', 9),
  ]);

  test('trichSo đọc được tiền có chấm nghìn, phần trăm có phẩy, số trần', () {
    final s = trichSo('Bạn đã dùng 2.100.000 đ (70,0%), còn 9 ngày.');
    expect(s.map((x) => x.giaTri).toList(), [2100000, 70, 9]);
    expect(s[0].laPhanTram, isFalse);
    expect(s[1].laPhanTram, isTrue);
    expect(s[2].laPhanTram, isFalse);
  });

  test('câu đúng số lọt', () {
    expect(kiemSo('Bạn đã dùng 2.100.000 đ (70,0%), còn 9 ngày.', goi), isTrue);
  });

  test('câu BỊA một số bị chặn', () {
    expect(kiemSo('Bạn đã dùng 2.150.000 đ, còn 9 ngày.', goi), isFalse,
        reason: '2.150.000 không có trong gói — mô hình vừa bịa');
  });

  test('câu không có số nào thì lọt', () {
    expect(kiemSo('Bạn đang chi tiêu đúng nhịp.', goi), isTrue);
  });

  test('phần trăm lệch trong 0,05 lọt, lệch hơn bị chặn', () {
    expect(kiemSo('Bạn đã dùng 70,04%.', goi), isTrue);
    expect(kiemSo('Bạn đã dùng 70,2%.', goi), isFalse);
  });

  test('số tiền lệch 1 đồng bị chặn (ngưỡng nửa đồng)', () {
    expect(kiemSo('Bạn đã dùng 2.100.001 đ.', goi), isFalse);
  });

  test('số có % không được khớp với số liệu TIỀN cùng giá trị', () {
    final g = _Gia([soTien('Đã chi', 70)]);
    expect(kiemSo('Bạn đã dùng 70%.', g), isFalse,
        reason: '70 đ và 70% là hai con số khác nhau; loại phải khớp');
  });

  test('số trần khớp số ngày hoặc số đếm, không khớp tiền', () {
    final g = _Gia([soNgay('Còn', 9), soTien('Đã chi', 9)]);
    expect(kiemSo('Còn 9 ngày.', g), isTrue);
    expect(kiemSo('Đã chi 9 đ.', g), isTrue,
        reason: 'số trần theo sau đ vẫn là một con số, khớp tiền được');
  });
}
