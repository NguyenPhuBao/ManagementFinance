// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'danh_muc_ai_doan_dao.dart';

// ignore_for_file: type=lint
mixin _$DanhMucAiDoanDaoMixin on DatabaseAccessor<AppDatabase> {
  $DanhMucAiDoansTable get danhMucAiDoans => attachedDatabase.danhMucAiDoans;
  DanhMucAiDoanDaoManager get managers => DanhMucAiDoanDaoManager(this);
}

class DanhMucAiDoanDaoManager {
  final _$DanhMucAiDoanDaoMixin _db;
  DanhMucAiDoanDaoManager(this._db);
  $$DanhMucAiDoansTableTableManager get danhMucAiDoans =>
      $$DanhMucAiDoansTableTableManager(
          _db.attachedDatabase, _db.danhMucAiDoans);
}
