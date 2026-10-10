/// Lớp bọc cho tầng giao diện (spec bịt điểm rò 2026-10-10, mục 4.5): trang cầm `sl<GanDanhMucNguon>()` thay
/// cho `sl<AppDatabase>()`. Luật ở `taiDuLieuGan` / `apDungGan` đã có test riêng; đây chỉ canh lớp bọc gọi đúng hàm.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/gan_danh_muc_nguon.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _GiaoDichGia implements TransactionRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('tai() trả dữ liệu dựng từ CSDL — không ném khi sổ rỗng', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final nguon = GanDanhMucNguon(
      db: db,
      danhMuc: CategoryManagementRepositoryImpl(db: db, syncEngine: null),
      giaoDich: _GiaoDichGia(),
      phanHoi: null,
    );
    await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w1', idaccount: 10, name: 'Tiền mặt', updatedAt: DateTime(2026, 10, 10)));
    final kq = await nguon.tai(10);
    expect(kq.dong, isEmpty);
    expect(kq.tenVi, {'w1': 'Tiền mặt'},
        reason: 'lớp bọc phải đưa đúng bảng tra tên ví cho dòng phụ "ngày · ví"');
  });
}
