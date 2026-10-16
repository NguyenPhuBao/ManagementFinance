import 'dart:async';

import '../models/category_entity.dart';
import '../models/category_tree.dart';

class CategoryValidationException implements Exception {
  const CategoryValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class CategoryManagementRepository {
  Stream<CategoryTree> watchTree({
    required int accountId,
    required String classify,
  });

  Future<CategoryTree> loadTree({
    required int accountId,
    required String classify,
  });

  Future<void> saveChild(CategoryChildDraft draft);
  Future<void> saveGroup(CategoryGroupDraft draft);
  Future<void> deleteChild({required int accountId, required String childId});
  Future<void> deleteGroup({required int accountId, required String groupId});
  Future<List<String>> loadKeywords({
    required int accountId,
    required String categoryId,
  });

  /// Từ khoá của MỌI danh mục thuộc tài khoản, gom theo `categoryId`.
  /// Dùng cho bộ gợi ý — nó cần cả tập cùng lúc, gọi `loadKeywords` trong vòng
  /// lặp sẽ sinh một truy vấn cho mỗi danh mục.
  Future<Map<String, List<String>>> loadAllKeywords({required int accountId});
  Future<void> saveKeywords({
    required int accountId,
    required String categoryId,
    required Iterable<String> keywords,
  });
  Future<List<CategoryEntity>> selectableChildren({
    required int accountId,
    required String classify,
  });

  /// Mọi danh mục con chọn được của tài khoản, không phân biệt `classify`.
  ///
  /// Cho bộ gợi ý theo ghi chú ở trang thêm giao dịch: từ 2026-09-05 chiều
  /// tiền suy từ danh mục được chọn chứ không từ segment, nên không còn phân
  /// loại nào để khoanh vùng trước khi tìm.
  Future<List<CategoryEntity>> selectableChildrenAll({required int accountId});

  /// Bảng TRA TÊN: giữ hàng mặc định toàn cục và hàng đã xoá mềm (G41/E8). `categoryDao.getBangTraTen`.
  Future<List<CategoryEntity>> loadBangTraTen({required int accountId});

  /// Mọi danh mục của tài khoản, stream — bộ lọc Sổ giao dịch, Trang chủ. `categoryDao.watchAll`.
  Stream<List<CategoryEntity>> watchAll({required int accountId});

  /// Một hàng, kể cả đã xoá mềm — tên danh mục trên bảng thanh toán hoá đơn. `categoryDao.getById`.
  Future<CategoryEntity?> getById(String id);

}
