import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../vi_trung_ten_nguon.dart';

/// "Thả" một ví khỏi trạng thái bị giữ vì trùng tên (G63): gỡ cờ + mốc chặn,
/// và **làm mới giờ sửa** của ví cùng mọi bản ghi đang chờ từng bị giữ vì nó.
///
/// Vế sau là thứ nghiệm thu hai máy ảo 2026-10-05 bắt được (bước 4 — Đổi tên):
/// máy kia thấy ví đã đổi tên với số dư 0 đ và không có giao dịch nào. Kéo về là
/// **tăng dần** theo `update_at` lớn nhất đã thấy, còn server giữ nguyên giờ ghi
/// của máy; bản ghi ghi lúc offline rồi bị giữ tới khi được thả lên server với
/// giờ **cũ hơn** mốc kéo về của máy kia → không bao giờ được kéo. Gộp không
/// dính vì `GopViService` vốn ghi lại các bản ghi ấy.
///
/// ⚠️ Từ **G67** (2026-10-08) mốc kéo về theo giờ-**server** (`maxSince`), nên lý
/// do trên chỉ còn đúng với server chưa có migration 20. Làm mới giờ sửa vẫn
/// giữ: vô hại (bản ghi đang chờ, chưa ai khác có), và là lưới cho server cũ.
///
/// Hai chỗ gọi: Đổi tên (datasource ví — tên đổi trên ví mang cờ) và engine
/// (ví mang cờ mà không còn ví cùng tên — ví kia bị xoá / đổi tên ở máy khác).
/// Tập bản ghi lấy từ chính `banGhiBiGiu` — không có luật "dính tới ví" thứ hai.
/// Chỉ hàng **đang chờ** bị đổi giờ: hàng đã đồng bộ thì máy kia đã có.
class ThaViBiGiu {
  ThaViBiGiu({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  Future<void> tha(String idVi) async {
    await _db.transaction(() async {
      final vi = await _db.walletDao.getById(idVi);
      if (vi == null) return;
      final bayGio = DateTime.now();
      await _db.walletDao.goCoTrungTen(idVi);
      await (_db.update(_db.wallets)..where((t) => t.id.equals(idVi)))
          .write(WalletsCompanion(updatedAt: Value(bayGio)));

      final giu = ViTrungTenNguonImpl.banGhiBiGiuTuHang(
        viBiGiu: {idVi},
        hoaDon: await _db.billDao.getPending(vi.idaccount),
        mucTieu: await _db.goalDao.getPending(vi.idaccount),
        giaoDich: await _db.transactionDao.getPending(vi.idaccount),
      );
      if (giu.giaoDich.isNotEmpty) {
        await (_db.update(_db.transactions)
              ..where((t) => t.id.isIn(giu.giaoDich)))
            .write(TransactionsCompanion(updatedAt: Value(bayGio)));
      }
      if (giu.hoaDon.isNotEmpty) {
        await (_db.update(_db.bills)..where((t) => t.id.isIn(giu.hoaDon)))
            .write(BillsCompanion(updatedAt: Value(bayGio)));
      }
      if (giu.mucTieu.isNotEmpty) {
        await (_db.update(_db.goals)..where((t) => t.id.isIn(giu.mucTieu)))
            .write(GoalsCompanion(updatedAt: Value(bayGio)));
      }
    });
  }
}
