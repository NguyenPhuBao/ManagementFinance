// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'khoa_tu_chuyen_tien_dao.dart';

// ignore_for_file: type=lint
mixin _$KhoaTuChuyenTienDaoMixin on DatabaseAccessor<AppDatabase> {
  $KhoaTuChuyenTiensTable get khoaTuChuyenTiens =>
      attachedDatabase.khoaTuChuyenTiens;
  KhoaTuChuyenTienDaoManager get managers => KhoaTuChuyenTienDaoManager(this);
}

class KhoaTuChuyenTienDaoManager {
  final _$KhoaTuChuyenTienDaoMixin _db;
  KhoaTuChuyenTienDaoManager(this._db);
  $$KhoaTuChuyenTiensTableTableManager get khoaTuChuyenTiens =>
      $$KhoaTuChuyenTiensTableTableManager(
          _db.attachedDatabase, _db.khoaTuChuyenTiens);
}
