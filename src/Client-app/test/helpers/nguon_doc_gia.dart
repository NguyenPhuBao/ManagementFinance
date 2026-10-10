/// Đăng ký vào `sl` các nguồn đọc mà TRANG nay lấy qua repository thay cho `sl<AppDatabase>()` (spec bịt điểm rò
/// 2026-10-10, việc 1). Mỗi lớp giả chỉ chuyển tiếp xuống DAO của chính [db] — dữ liệu y như trước khi trang đổi lối đọc
/// — và `noSuchMethod` cho phần còn lại. Gọi NGAY SAU `sl.registerSingleton<AppDatabase>(db)`; kiểu nào test đã đăng ký
/// bản giả riêng thì giữ nguyên bản ấy.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/notification/thong_bao_nguon.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';

class ViRowsGia implements WalletRepository {
  ViRowsGia(this.db);
  final AppDatabase db;
  @override
  Future<List<Wallet>> getActiveRows(int idaccount) => db.walletDao.getActive(idaccount);
  @override
  Future<List<Wallet>> getAllRows(int idaccount) => db.walletDao.getAll(idaccount);
  @override
  Stream<List<Wallet>> watchAllRows(int idaccount) => db.walletDao.watchAll(idaccount);
  @override
  Future<Wallet?> getRowById(String id) => db.walletDao.getById(id);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class GiaoDichRowsGia implements TransactionRepository {
  GiaoDichRowsGia(this.db);
  final AppDatabase db;
  @override
  Future<List<Transaction>> getAllRows(int idaccount) => db.transactionDao.getAll(idaccount);
  @override
  Stream<List<Transaction>> watchAllRows(int idaccount) => db.transactionDao.watchAll(idaccount);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class DanhMucRowsGia implements CategoryManagementRepository {
  DanhMucRowsGia(this.db);
  final AppDatabase db;
  @override
  Future<List<Category>> loadBangTraTen({required int accountId}) => db.categoryDao.getBangTraTen(accountId);
  @override
  Stream<List<Category>> watchAllRows({required int accountId}) => db.categoryDao.watchAll(accountId);
  @override
  Future<Category?> getRowById(String id) => db.categoryDao.getById(id);
  @override
  Future<List<Category>> getCategoryRows({required int accountId, required String classify}) =>
      db.categoryDao.getCategoryRows(accountId, classify);
  @override
  Future<List<Category>> selectableChildren({required int accountId, required String classify}) =>
      db.categoryDao.getCategoryRows(accountId, classify).then((ds) => ds.where((c) => !c.isGroup).toList());
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class HoaDonRowsGia implements BillRepository {
  HoaDonRowsGia(this.db);
  final AppDatabase db;
  @override
  Future<Bill?> getById(String id) => db.billDao.getById(id);
  @override
  Future<List<Bill>> getBills(int idaccount) => db.billDao.getAll(idaccount);
  @override
  Future<Map<String, Transaction>> paymentsOf(int idaccount) => db.transactionDao.getBillPayments(idaccount);
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
  _dat<ThongBaoNguon>(ThongBaoNguonDrift(db.notificationDao), (o) => o is ThongBaoNguonDrift);
  _dat<WalletRepository>(ViRowsGia(db), (o) => o is ViRowsGia);
  _dat<TransactionRepository>(GiaoDichRowsGia(db), (o) => o is GiaoDichRowsGia);
  _dat<CategoryManagementRepository>(DanhMucRowsGia(db), (o) => o is DanhMucRowsGia);
  _dat<BillRepository>(HoaDonRowsGia(db), (o) => o is HoaDonRowsGia);
  _dat<GoalRepository>(MucTieuRowsGia(db), (o) => o is MucTieuRowsGia);
}
