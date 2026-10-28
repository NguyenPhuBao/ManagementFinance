/// `CategoryEntity.fromDrift` — Entity Danh mục, kiểu duy nhất từ repository trở lên (spec Entity Danh mục 2026-10-15, 4.1).
/// Đếm cột bằng máy: Entity = cột bảng − 4 (`isLocalOnly` · `syncRetryCount` · `syncError` · `syncBlockedUntil`).
/// Đẳng thức theo giá trị là bắt buộc: `DropdownButton<CategoryEntity>` ở Thêm / Sửa hoá đơn so `value` với `items` bằng `==`.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final moc = DateTime(2026, 10, 15, 7);
  // Mọi trường khác mặc định của Entity (icon 'category', colour '#4CAF50', bốn cờ false, parentId null, syncStatus 'pending').
  Category hang({String id = 'c-1'}) => Category(
        id: id,
        idaccount: 10,
        name: 'Ăn uống',
        classify: 'thu',
        icon: 'food',
        colour: '#123456',
        isDefault: true,
        isDeleted: true,
        parentId: 'g-1',
        isGroup: true,
        isLocalOnly: true,
        aiCoDinh: true,
        deletedAt: moc,
        syncStatus: 'synced',
        syncRetryCount: 3,
        syncError: 'lỗi',
        syncBlockedUntil: moc,
        updatedAt: moc,
      );

  test('fromDrift chép đủ 14 trường, không chép 5 cột ngoài Entity', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final e = CategoryEntity.fromDrift(hang());
    expect(e.props.length, db.categories.$columns.length - 5,
        reason:
            'Thêm cột vào bảng Categories thì quyết định: vào Entity, hay ghi vào danh sách 5 cột không chép.');
    expect(e.id, 'c-1');
    expect(e.idaccount, 10);
    expect(e.name, 'Ăn uống');
    expect(e.classify, 'thu');
    expect(e.icon, 'food');
    expect(e.colour, '#123456');
    expect(e.isDefault, isTrue);
    expect(e.isDeleted, isTrue);
    expect(e.parentId, 'g-1');
    expect(e.isGroup, isTrue);
    expect(e.aiCoDinh, isTrue);
    expect(e.syncStatus, 'synced');
    expect(e.updatedAt, moc);
    expect(e.deletedAt, moc,
        reason: 'Luật ẩn theo khuôn (spec 2026-10-27 mục 3) so `deletedAt` của KHUÔN với kMocAnTheoKhuon.');
  });

  test(
      'đẳng thức theo giá trị — hai bản map từ cùng hàng là ==, khác id thì không',
      () {
    expect(CategoryEntity.fromDrift(hang()), CategoryEntity.fromDrift(hang()),
        reason:
            'Dropdown danh mục ở Thêm / Sửa hoá đơn mất lựa chọn trong im lặng nếu Entity so theo danh tính.');
    expect(CategoryEntity.fromDrift(hang()).hashCode,
        CategoryEntity.fromDrift(hang()).hashCode);
    expect(CategoryEntity.fromDrift(hang()),
        isNot(CategoryEntity.fromDrift(hang(id: 'c-2'))));
  });
}
