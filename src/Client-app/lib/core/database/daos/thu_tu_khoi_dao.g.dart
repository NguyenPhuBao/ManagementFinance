// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thu_tu_khoi_dao.dart';

// ignore_for_file: type=lint
mixin _$ThuTuKhoiDaoMixin on DatabaseAccessor<AppDatabase> {
  $PhanTichGiayXemsTable get phanTichGiayXems =>
      attachedDatabase.phanTichGiayXems;
  $PhanTichThuTuPhanHoisTable get phanTichThuTuPhanHois =>
      attachedDatabase.phanTichThuTuPhanHois;
  ThuTuKhoiDaoManager get managers => ThuTuKhoiDaoManager(this);
}

class ThuTuKhoiDaoManager {
  final _$ThuTuKhoiDaoMixin _db;
  ThuTuKhoiDaoManager(this._db);
  $$PhanTichGiayXemsTableTableManager get phanTichGiayXems =>
      $$PhanTichGiayXemsTableTableManager(
          _db.attachedDatabase, _db.phanTichGiayXems);
  $$PhanTichThuTuPhanHoisTableTableManager get phanTichThuTuPhanHois =>
      $$PhanTichThuTuPhanHoisTableTableManager(
          _db.attachedDatabase, _db.phanTichThuTuPhanHois);
}
