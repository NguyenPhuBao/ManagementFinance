// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_dao.dart';

// ignore_for_file: type=lint
mixin _$CategoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $CategoryKeywordsTable get categoryKeywords =>
      attachedDatabase.categoryKeywords;
  $CategoryGroupMembershipsTable get categoryGroupMemberships =>
      attachedDatabase.categoryGroupMemberships;
  CategoryDaoManager get managers => CategoryDaoManager(this);
}

class CategoryDaoManager {
  final _$CategoryDaoMixin _db;
  CategoryDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$CategoryKeywordsTableTableManager get categoryKeywords =>
      $$CategoryKeywordsTableTableManager(
          _db.attachedDatabase, _db.categoryKeywords);
  $$CategoryGroupMembershipsTableTableManager get categoryGroupMemberships =>
      $$CategoryGroupMembershipsTableTableManager(
          _db.attachedDatabase, _db.categoryGroupMemberships);
}
