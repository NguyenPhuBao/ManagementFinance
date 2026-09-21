/// Luật chọn danh mục đáng đặt ngân sách — mục ④ của danh sách việc.
///
/// Hàm thuần, không chạm Drift và không chạm bộ lọc `classify`: nguồn duy nhất
/// của danh sách ứng viên là `BudgetRepository.getExpenseCategories`, vốn **đã**
/// chỉ trả danh mục `'chi'`. Thêm một bộ lọc thứ hai ở đây là dựng bản chép tay
/// của một luật đã có chỗ đúng duy nhất.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/domain/de_xuat_ngan_sach.dart';

void main() {
  const danhMuc = [
    (id: 'an', ten: 'Ăn uống', icon: 'food', colour: '#FF5722'),
    (id: 'giaitri', ten: 'Giải trí', icon: 'movie', colour: null),
    (id: 'yte', ten: 'Y tế', icon: null, colour: null),
    (id: 'nhacua', ten: 'Nhà cửa', icon: null, colour: null),
  ];

  GoiDeXuat? chon({
    Set<String> daCo = const {},
    Map<String, double?> muc = const {
      'an': 500000,
      'giaitri': 300000,
      'yte': 900000,
      'nhacua': null,
    },
    int? soNgay = 20,
  }) =>
      chonDeXuat(
        danhMucChi: danhMuc,
        daCoNganSach: daCo,
        mucThangTheoDanhMuc: muc,
        soNgayCuaSo: soNgay,
      );

  test('bỏ danh mục ĐÃ có ngân sách đang chạy', () {
    final g = chon(daCo: {'yte'})!;

    expect(
      g.ds.map((d) => d.categoryId),
      isNot(contains('yte')),
      reason: 'gợi ý tạo ngân sách cho danh mục đã có ngân sách là nhiễu, và '
          '`_assertCategoryFree` cũng sẽ từ chối',
    );
    expect(g.ds.map((d) => d.categoryId), contains('an'),
        reason: 'ĐÒI KẾT QUẢ: những danh mục còn lại vẫn phải ở đó');
  });

  test('bỏ danh mục không gợi ý được số', () {
    final g = chon()!;

    expect(
      g.ds.map((d) => d.categoryId),
      isNot(contains('nhacua')),
      reason: '`null` là "chưa đủ để nói"; một dòng "0 đ mỗi tháng" là gợi ý sai',
    );
  });

  test('xếp theo mức tháng GIẢM DẦN', () {
    final g = chon()!;

    expect(g.ds.map((d) => d.categoryId).toList(), ['yte', 'an', 'giaitri'],
        reason: 'danh mục tiêu nhiều nhất là chỗ đặt ngân sách đáng giá nhất');
  });

  test('lấy tối đa $kToiDaDeXuat', () {
    final g = chonDeXuat(
      danhMucChi: const [
        (id: 'a', ten: 'A', icon: null, colour: null),
        (id: 'b', ten: 'B', icon: null, colour: null),
        (id: 'c', ten: 'C', icon: null, colour: null),
        (id: 'd', ten: 'D', icon: null, colour: null),
        (id: 'e', ten: 'E', icon: null, colour: null),
      ],
      daCoNganSach: const {},
      mucThangTheoDanhMuc: const {
        'a': 100,
        'b': 200,
        'c': 300,
        'd': 400,
        'e': 500,
      },
      soNgayCuaSo: 20,
    )!;

    expect(g.ds, hasLength(kToiDaDeXuat));
    expect(g.ds.first.categoryId, 'e', reason: 'vẫn là ba cái lớn nhất');
  });

  test('không ứng viên nào thì trả null, không phải danh sách rỗng', () {
    final g = chon(daCo: {'an', 'giaitri', 'yte', 'nhacua'});

    expect(
      g,
      isNull,
      reason: '`null` để chỗ gọi ẩn HẲN thẻ. Một danh sách rỗng buộc widget tự '
          'nghĩ ra luật ẩn, và đó là chỗ luật bị chép ra lần thứ hai',
    );
  });

  test('chưa đủ dữ liệu (soNgayCuaSo null) thì trả null', () {
    expect(
      chon(soNgay: null),
      isNull,
      reason: 'cửa sổ nhìn lại im hẳn thì thẻ cũng phải im — không có con số '
          'nào đáng tin để gợi ý',
    );
  });

  test('giữ nguyên tên danh mục để widget khỏi tra lại', () {
    final g = chon()!;

    expect(g.ds.first.tenDanhMuc, 'Y tế');
    expect(g.soNgayCuaSo, 20,
        reason: 'độ dài cửa sổ đi cùng GÓI chứ không lặp ở từng dòng: nó là '
            'một tính chất của phép suy, không phải của danh mục');
  });
}
