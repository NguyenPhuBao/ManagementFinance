/// Đăng ký vào `sl` các nguồn đọc mà TRANG nay lấy qua repository thay cho `sl<AppDatabase>()` (spec bịt điểm rò
/// 2026-10-10, việc 1). Mỗi lớp giả chỉ chuyển tiếp xuống DAO của chính [db] (map `fromDrift` cho repository trả Entity) — dữ liệu y như trước khi trang đổi lối đọc
/// — và `noSuchMethod` cho phần còn lại. Gọi NGAY SAU `sl.registerSingleton<AppDatabase>(db)`; kiểu nào test đã đăng ký
/// bản giả riêng thì giữ nguyên bản ấy.
library;

import 'package:flowmoney/features/category/data/danh_sach_chon_danh_muc.dart';
import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/bill/data/models/bill_entity.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/notification/data/repositories/thong_bao_repository.dart';
import 'package:flowmoney/features/notification/data/repositories/thong_bao_repository_impl.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';

class ViGia implements WalletRepository {
  ViGia(this.db);
  final AppDatabase db;
  @override
  Future<List<WalletEntity>> getActive(int idaccount) async =>
      (await db.walletDao.getActive(idaccount)).map(WalletEntity.fromDrift).toList();
  @override
  Future<List<WalletEntity>> getAll(int idaccount) async =>
      (await db.walletDao.getAll(idaccount)).map(WalletEntity.fromDrift).toList();
  @override
  Stream<List<WalletEntity>> watchAll(int idaccount) =>
      db.walletDao.watchAll(idaccount).map((rows) => rows.map(WalletEntity.fromDrift).toList());
  @override
  Future<WalletEntity?> getById(String id) async {
    final r = await db.walletDao.getById(id);
    return r == null ? null : WalletEntity.fromDrift(r);
  }
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GiaoDichGia implements TransactionRepository {
  GiaoDichGia(this.db);
  final AppDatabase db;
  @override
  Future<List<TransactionEntity>> getAll(int idaccount) async =>
      (await db.transactionDao.getAll(idaccount)).map(TransactionEntity.fromDrift).toList();
  @override
  Stream<List<TransactionEntity>> watchAll(int idaccount) =>
      db.transactionDao.watchAll(idaccount).map((rows) => rows.map(TransactionEntity.fromDrift).toList());
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class DanhMucGia implements CategoryManagementRepository {
  DanhMucGia(this.db);
  final AppDatabase db;
  @override
  Future<List<CategoryEntity>> loadBangTraTen({required int accountId}) async =>
      (await db.categoryDao.getBangTraTen(accountId)).map(CategoryEntity.fromDrift).toList();
  @override
  Stream<List<CategoryEntity>> watchAll({required int accountId}) =>
      db.categoryDao.watchAll(accountId).map((rows) => rows.map(CategoryEntity.fromDrift).toList());
  @override
  Future<CategoryEntity?> getById(String id) async {
    final r = await db.categoryDao.getById(id);
    return r == null ? null : CategoryEntity.fromDrift(r);
  }
  @override
  Future<List<CategoryEntity>> selectableChildren({required int accountId, required String classify}) async =>
      (await hangChonDuoc(db, accountId, classify))
          .where((c) => !c.isGroup)
          .map(CategoryEntity.fromDrift)
          .toList();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class HoaDonRowsGia implements BillRepository {
  HoaDonRowsGia(this.db);
  final AppDatabase db;
  @override
  Future<BillEntity?> getById(String id) async {
    final r = await db.billDao.getById(id);
    return r == null ? null : BillEntity.fromDrift(r);
  }
  @override
  Future<List<BillEntity>> getBills(int idaccount) async => [for (final r in await db.billDao.getAll(idaccount)) BillEntity.fromDrift(r)];
  @override
  Future<Map<String, TransactionEntity>> paymentsOf(int idaccount) async {
    final rows = await db.transactionDao.getBillPayments(idaccount);
    return {for (final e in rows.entries) e.key: TransactionEntity.fromDrift(e.value)};
  }
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class MucTieuRowsGia implements GoalRepository {
  MucTieuRowsGia(this.db);
  final AppDatabase db;
  @override
  Future<List<GoalEntity>> getGoals(int idaccount) async =>
      (await db.goalDao.getAll(idaccount)).map(GoalEntity.fromDrift).toList();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Đăng ký [moi] cho kiểu [T]. Bản giả của CHÍNH helper này (đã trỏ vào một [AppDatabase] cũ, thường đã đóng khi test
/// trước dọn) thì được thay bằng bản trỏ vào db hiện tại; bản giả riêng của test thì giữ nguyên.
void _dat<T extends Object>(T moi, bool Function(Object) laGiaCuaHelper) {
  if (sl.isRegistered<T>()) {
    if (!laGiaCuaHelper(sl<T>())) return;
    sl.unregister<T>();
  }
  sl.registerSingleton<T>(moi);
}

void dangKyNguonDocGia(AppDatabase db) {
  _dat<ThongBaoRepository>(ThongBaoRepositoryImpl(db.notificationDao), (o) => o is ThongBaoRepositoryImpl);
  _dat<WalletRepository>(ViGia(db), (o) => o is ViGia);
  _dat<TransactionRepository>(GiaoDichGia(db), (o) => o is GiaoDichGia);
  _dat<CategoryManagementRepository>(DanhMucGia(db), (o) => o is DanhMucGia);
  _dat<BillRepository>(HoaDonRowsGia(db), (o) => o is HoaDonRowsGia);
  _dat<GoalRepository>(MucTieuRowsGia(db), (o) => o is MucTieuRowsGia);
}
