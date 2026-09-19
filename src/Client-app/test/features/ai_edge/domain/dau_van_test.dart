/// Dấu vân của gói số là khoá cache câu (P3). Sai một trong ba tính chất dưới
/// đây là hoặc gọi mô hình lại sau mỗi chu kỳ đồng bộ (khoá đổi vô cớ), hoặc
/// dùng chung câu cho hai gói khác nghĩa (khoá trùng oan).
library;

import 'package:flowmoney/features/ai_edge/domain/dau_van.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gia extends GoiSo {
  @override
  final String man;
  @override
  final List<SoLieu> soLieu;
  _Gia(this.man, this.soLieu);
  @override
  bool get thieuDuLieu => soLieu.isEmpty;
  @override
  NhanXet mauCau() =>
      NhanXet(cau: '', theSoLieu: soLieu, muc: MucNhanXet.binhThuong);
}

void main() {
  test('đổi một số là đổi dấu vân', () {
    final a = _Gia('ngan_sach', [soTien('Đã chi', 1), soTien('Hạn mức', 2)]);
    final b = _Gia('ngan_sach', [soTien('Đã chi', 1), soTien('Hạn mức', 3)]);
    expect(dauVanCua(a), isNot(dauVanCua(b)));
  });

  test('đổi THỨ TỰ số liệu không đổi dấu vân', () {
    final a = _Gia('ngan_sach', [soTien('Đã chi', 1), soTien('Hạn mức', 2)]);
    final b = _Gia('ngan_sach', [soTien('Hạn mức', 2), soTien('Đã chi', 1)]);
    expect(dauVanCua(a), dauVanCua(b),
        reason: 'stream phát lại sau đồng bộ dựng lại danh sách — thứ tự '
            'không được là lý do gọi mô hình lần hai');
  });

  test('cùng số nhưng khác màn là hai dấu vân', () {
    final a = _Gia('ngan_sach', [soTien('X', 1)]);
    final b = _Gia('trang_chu', [soTien('X', 1)]);
    expect(dauVanCua(a), isNot(dauVanCua(b)));
  });

  test('GoiSo.dauVan gọi đúng dauVanCua', () {
    final a = _Gia('ngan_sach', [soTien('X', 1)]);
    expect(a.dauVan, dauVanCua(a));
  });
}
