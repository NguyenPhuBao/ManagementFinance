/// Bộ giả lập dùng chung cho các test widget của danh mục và giao dịch.
///
/// Trước đây chúng nằm riêng trong `category_management_widget_test.dart`
/// (dạng private). Test cho `AddTransactionPage` và `ChooseCategoryPage` cần
/// cùng bộ này nên tách ra để hai bên không chép lại nhau.
library;

import 'package:flowmoney/core/category/category_classify.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';

Category makeCategory({
  required String id,
  required String name,
  int idaccount = 1,
  String classify = 'chi',
  bool isGroup = false,
  bool isDefault = false,
  String? parentId,
  DateTime? updatedAt,
}) =>
    Category(
      id: id,
      idaccount: idaccount,
      name: name,
      classify: classify,
      icon: 'category',
      colour: '#10B981',
      parentId: parentId,
      isGroup: isGroup,
      isDefault: isDefault,
      isDeleted: false,
      isLocalOnly: !isDefault,
      syncStatus: 'pending',
      syncRetryCount: 0,
      updatedAt: updatedAt ?? DateTime(2026, 8, 21),
    );

Wallet makeWallet({
  String id = 'cash',
  String name = 'Tiền mặt',
  double balance = 100000,
}) =>
    Wallet(
      id: id,
      idaccount: 1,
      name: name,
      type: 'cash',
      balance: balance,
      currency: 'VND',
      icon: 'wallet',
      colour: '#10B981',
      isDefault: true,
      isDeleted: false,
      // Hai trường bắt buộc được thêm ở schema v5/v6 (includeInTotal, status)
      // — thiếu chúng thì cả file test này không biên dịch được.
      includeInTotal: true,
      status: 'active',
      syncStatus: 'pending',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 8, 21),
    );

class FakeCategoryRepository implements CategoryManagementRepository {
  FakeCategoryRepository(
      {CategoryTree? tree,
      Map<String, CategoryTree>? trees,
      List<Category> selectable = const [],
      Future<List<Category>> Function(int accountId, String classify)?
          selectableLoader,
      Map<String, List<String>> keywords = const {}})
      : _trees = trees ?? {'chi': tree ?? _emptyTree},
        _selectable = selectable,
        _selectableLoader = selectableLoader,
        _keywords = keywords;

  static final _emptyTree = CategoryTree(
    groups: const [],
    ungroupedChildren: const [],
    defaultChildren: const [],
  );

  final Map<String, CategoryTree> _trees;
  final List<Category> _selectable;
  final Future<List<Category>> Function(int accountId, String classify)?
      _selectableLoader;
  final Map<String, List<String>> _keywords;
  List<String>? savedKeywords;
  CategoryChildDraft? savedChild;
  CategoryGroupDraft? savedGroup;

  /// Các classify mà trang đã hỏi `loadTree`, theo thứ tự gọi.
  final List<String> loadedClassifies = [];

  /// Đếm số lần trang gọi xuống tầng dữ liệu để dựng gợi ý. Dùng để canh chừng
  /// hai thứ: debounce ô ghi chú, và việc đọc từ khoá bằng MỘT truy vấn thay vì
  /// một truy vấn cho mỗi danh mục.
  int soLanDocDanhMuc = 0;
  int soLanDocTuKhoa = 0;

  /// Mã tài khoản của MỌI lời gọi đọc, theo thứ tự. Canh G35: khi chưa có
  /// phiên đăng nhập, màn danh mục không được đọc gì — kể cả tài khoản 0,
  /// vì 0 là bộ khuôn danh mục mặc định toàn cục (quy tắc 8).
  final List<int> accountIdsDoc = [];

  @override
  Stream<CategoryTree> watchTree({
    required int accountId,
    required String classify,
  }) {
    accountIdsDoc.add(accountId);
    return Stream.value(_trees[classify] ?? _emptyTree);
  }

  @override
  Future<CategoryTree> loadTree({
    required int accountId,
    required String classify,
  }) async {
    accountIdsDoc.add(accountId);
    loadedClassifies.add(classify);
    return _trees[classify] ?? _emptyTree;
  }

  @override
  Future<void> saveKeywords({
    required int accountId,
    required String categoryId,
    required Iterable<String> keywords,
  }) async {
    savedKeywords = keywords.toList();
  }

  @override
  Future<List<String>> loadKeywords({
    required int accountId,
    required String categoryId,
  }) async {
    accountIdsDoc.add(accountId);
    soLanDocTuKhoa++;
    return _keywords[categoryId] ?? const [];
  }

  @override
  Future<Map<String, List<String>>> loadAllKeywords({
    required int accountId,
  }) async {
    accountIdsDoc.add(accountId);
    soLanDocTuKhoa++;
    return _keywords;
  }

  @override
  Future<void> saveChild(CategoryChildDraft draft) async {
    savedChild = draft;
  }

  @override
  Future<void> saveGroup(CategoryGroupDraft draft) async {
    savedGroup = draft;
  }

  @override
  Future<void> deleteChild({
    required int accountId,
    required String childId,
  }) async {}

  @override
  Future<void> deleteGroup({
    required int accountId,
    required String groupId,
  }) async {}

  @override
  Future<List<Category>> selectableChildren({
    required int accountId,
    required String classify,
  }) {
    accountIdsDoc.add(accountId);
    soLanDocDanhMuc++;
    return _selectableLoader?.call(accountId, classify) ??
        Future.value(
          _selectable
              .where((category) => category.classify == classify)
              .toList(),
        );
  }

  @override
  Future<List<Category>> selectableChildrenAll({required int accountId}) async {
    // Một lượt gợi ý = MỘT lần đếm, dù bên dưới hỏi từng classify.
    accountIdsDoc.add(accountId);
    soLanDocDanhMuc++;
    final loader = _selectableLoader;
    if (loader == null) return List.of(_selectable);
    final perClassify = await Future.wait(
      kCategoryClassifies.map((classify) => loader(accountId, classify)),
    );
    return [for (final list in perClassify) ...list];
  }
}

/// Ghi lại những gì trang gửi xuống, để test kiểm được entity đã dựng ra
/// (loại, danh mục, ví đích) thay vì chỉ kiểm giao diện.
class FakeTransactionRepository implements TransactionRepository {
  final List<({TransactionEntity transaction, String? destinationWalletId})>
      added = [];
  final List<({TransactionEntity transaction, String? destinationWalletId})>
      deleted = [];
  final List<({TransactionEntity before, TransactionEntity after})> updated =
      [];

  @override
  Future<void> updateTransaction(
    TransactionEntity before,
    TransactionEntity after,
  ) async {
    updated.add((before: before, after: after));
  }

  @override
  Future<void> addTransaction(
    TransactionEntity transaction, {
    String? destinationWalletId,
  }) async {
    added.add(
        (transaction: transaction, destinationWalletId: destinationWalletId));
  }

  @override
  Future<void> deleteTransaction(
    TransactionEntity transaction, {
    String? destinationWalletId,
  }) async {
    deleted.add(
        (transaction: transaction, destinationWalletId: destinationWalletId));
  }

  @override
  Stream<List<TransactionEntity>> watchTransactionsByMonth(
    int idaccount,
    int year,
    int month,
  ) =>
      const Stream.empty();
}
