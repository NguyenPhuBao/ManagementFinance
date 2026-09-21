/// Ví hay dùng theo danh mục — luật học từ lịch sử, chặng 1.2.
///
/// ⚠️ Luật này **im lặng khi chưa đủ mẫu** (luật chung số 4 của kế hoạch): thà
/// giữ ví mặc định còn hơn nhảy ví theo một giao dịch lẻ. Mọi ca dưới đây đều
/// đòi **kết quả cụ thể**, không ca nào chỉ đòi "khác null".
library;

import 'package:flowmoney/features/transaction/domain/vi_hay_dung.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('demViTheoDanhMuc', () {
    test('gom số lần theo cặp danh mục → ví', () {
      final dem = demViTheoDanhMuc([
        (categoryId: 'an', walletId: 'tienmat'),
        (categoryId: 'an', walletId: 'tienmat'),
        (categoryId: 'an', walletId: 'nganhang'),
        (categoryId: 'muasam', walletId: 'nganhang'),
      ]);
      expect(dem, {
        'an': {'tienmat': 2, 'nganhang': 1},
        'muasam': {'nganhang': 1},
      });
    });

    test('bỏ khoản không có danh mục hoặc không có ví', () {
      // Khoản chuyển, khoản điều chỉnh số dư và khoản mở sổ đều trống danh
      // mục — chúng không nói gì về thói quen chọn ví cho một danh mục.
      final dem = demViTheoDanhMuc([
        (categoryId: null, walletId: 'tienmat'),
        (categoryId: 'an', walletId: null),
        (categoryId: 'an', walletId: 'tienmat'),
      ]);
      expect(dem, {
        'an': {'tienmat': 1}
      });
    });
  });

  group('viHayDungCho', () {
    test('9/10 lần dùng một ví → chọn ví ấy', () {
      expect(viHayDungCho({'tienmat': 9, 'nganhang': 1}), 'tienmat');
    });

    test('3 giao dịch: dưới ngưỡng mẫu nên im, dù 100 % cùng một ví', () {
      expect(viHayDungCho({'tienmat': 3}), isNull);
    });

    test('5 giao dịch chia 3–2: đủ mẫu nhưng 60 % chưa phải áp đảo', () {
      // 3/5 = 0,600 đúng bằng ngưỡng. Luật đòi **vượt** ngưỡng, không phải
      // chạm: một cặp 3–2 gần như tung đồng xu, đổi ví theo nó là đoán bừa.
      expect(viHayDungCho({'tienmat': 3, 'nganhang': 2}), isNull);
    });

    test('7 giao dịch chia 5–2: vượt ngưỡng thì chọn', () {
      expect(viHayDungCho({'tienmat': 5, 'nganhang': 2}), 'tienmat');
    });

    test('không có lịch sử → im', () {
      expect(viHayDungCho(const {}), isNull);
    });

    test('hoà nhau thì không có ví nào áp đảo', () {
      expect(viHayDungCho({'a': 5, 'b': 5}), isNull);
    });
  });

  group('viHayDungTheoDanhMuc', () {
    test('chỉ giữ danh mục đủ căn cứ, bỏ hẳn danh mục chưa đủ', () {
      final bang = viHayDungTheoDanhMuc({
        'an': {'tienmat': 9, 'nganhang': 1},
        'muasam': {'nganhang': 2},
        'dilai': {'tienmat': 3, 'nganhang': 2},
      });
      expect(bang, {'an': 'tienmat'},
          reason: 'muasam thiếu mẫu, dilai không ai áp đảo');
    });

    test('lịch sử rỗng cho bảng rỗng — trang rơi về ví mặc định', () {
      expect(viHayDungTheoDanhMuc(const {}), isEmpty);
    });
  });
}
