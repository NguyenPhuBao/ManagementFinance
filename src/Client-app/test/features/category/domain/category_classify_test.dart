import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/domain/category_classify.dart';
import 'package:flutter_test/flutter_test.dart';

import '../presentation/category_test_fakes.dart';

final _diChuyen = makeCategory(id: 'c-dc', name: 'Di chuyển');
final _anUong = makeCategory(id: 'c-an', name: 'Ăn uống');
final _luong = makeCategory(id: 'c-luong', name: 'Lương', classify: 'thu');
final _choVay = makeCategory(id: 'c-vay', name: 'Cho vay', classify: 'vay_no');
final _chonDuoc = [_diChuyen, _anUong, _luong, _choVay];

void main() {
  group('kCategoryClassifies', () {
    test('đúng ba giá trị, theo thứ tự tab: chi → thu → vay_no', () {
      expect(
        kCategoryClassifies,
        ['chi', 'thu', 'vay_no'],
        reason: 'Đây là danh sách DUY NHẤT dựng tab ở trang quản lý danh mục, '
            'bảng chọn danh mục khi tạo giao dịch và form tạo danh mục. Trước '
            'đây nó bị chép tay ở 5 chỗ; thêm tab Vay/nợ mà sót một chỗ là tab '
            'ấy vô hình ở nơi đó.',
      );
    });

    test('nhãn hiển thị khớp trang quản lý danh mục và thiết kế Stitch', () {
      expect(categoryClassifyLabel('chi'), 'Khoản chi');
      expect(categoryClassifyLabel('thu'), 'Khoản thu');
      expect(categoryClassifyLabel('vay_no'), 'Vay / nợ');
    });

    test('isDebtClassify chỉ đúng với vay_no', () {
      expect(isDebtClassify('vay_no'), isTrue);
      expect(isDebtClassify('chi'), isFalse);
      expect(isDebtClassify('thu'), isFalse);
    });
  });

  group('suggestDebtDirection', () {
    /// Canh chừng điều gì: `classify = vay_no` gom CẢ HAI chiều tiền — cho vay
    /// là tiền ra, đi vay là tiền vào — mà không có cột nào ở client lẫn
    /// backend ghi chiều. Form gợi sẵn theo tên để người dùng đỡ một cú chạm;
    /// đoán sai thì họ đổi được, nên đây là phép đoán, không phải quy tắc.
    test('bốn danh mục mặc định: Cho vay/Trả nợ là tiền ra, Đi vay/Thu nợ là tiền vào',
        () {
      expect(suggestDebtDirection('Cho vay'), 'chi');
      expect(suggestDebtDirection('Trả nợ'), 'chi');
      expect(suggestDebtDirection('Đi vay'), 'thu');
      expect(suggestDebtDirection('Thu nợ'), 'thu');
    });

    test('không phân biệt hoa/thường và khoảng trắng thừa', () {
      expect(suggestDebtDirection('  ĐI VAY  '), 'thu');
      expect(suggestDebtDirection('cho   vay'), 'chi');
    });

    test('nhận ra từ khoá nằm giữa tên dài hơn', () {
      expect(suggestDebtDirection('Thu nợ anh Ba'), 'thu');
      expect(suggestDebtDirection('Cho vay bạn Nam'), 'chi');
    });

    test('tên không nhận ra thì mặc định tiền ra — người dùng đổi trên form', () {
      expect(suggestDebtDirection('Góp vốn'), 'chi');
      expect(suggestDebtDirection(''), 'chi');
    });
  });

  group('hopLeTheoChieu', () {
    test('khoản chi → danh mục chi và vay/nợ', () {
      expect(hopLeTheoChieu('chi', _chonDuoc), {'c-dc', 'c-an', 'c-vay'});
    });

    test('khoản thu → danh mục thu và vay/nợ', () {
      expect(hopLeTheoChieu('thu', _chonDuoc), {'c-luong', 'c-vay'});
    });

    test('bỏ danh mục đã xoá và nhóm', () {
      final goc = makeCategory(id: 'c-xoa', name: 'Cũ');
      final xoa = CategoryEntity(
        id: goc.id,
        idaccount: goc.idaccount,
        name: goc.name,
        classify: goc.classify,
        icon: goc.icon,
        colour: goc.colour,
        isDefault: goc.isDefault,
        isDeleted: true,
        parentId: goc.parentId,
        isGroup: goc.isGroup,
        aiCoDinh: goc.aiCoDinh,
        syncStatus: goc.syncStatus,
        updatedAt: goc.updatedAt,
      );
      final nhom = makeCategory(id: 'c-nhom', name: 'Nhóm', isGroup: true);
      expect(hopLeTheoChieu('chi', [..._chonDuoc, xoa, nhom]), {'c-dc', 'c-an', 'c-vay'});
    });
  });
}
