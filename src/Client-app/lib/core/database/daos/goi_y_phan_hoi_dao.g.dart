// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goi_y_phan_hoi_dao.dart';

// ignore_for_file: type=lint
mixin _$GoiYPhanHoiDaoMixin on DatabaseAccessor<AppDatabase> {
  $GoiYDanhMucPhanHoisTable get goiYDanhMucPhanHois =>
      attachedDatabase.goiYDanhMucPhanHois;
  GoiYPhanHoiDaoManager get managers => GoiYPhanHoiDaoManager(this);
}

class GoiYPhanHoiDaoManager {
  final _$GoiYPhanHoiDaoMixin _db;
  GoiYPhanHoiDaoManager(this._db);
  $$GoiYDanhMucPhanHoisTableTableManager get goiYDanhMucPhanHois =>
      $$GoiYDanhMucPhanHoisTableTableManager(
          _db.attachedDatabase, _db.goiYDanhMucPhanHois);
}
