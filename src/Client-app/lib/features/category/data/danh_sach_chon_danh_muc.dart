/// Cửa DUY NHẤT của *danh sách để CHỌN* danh mục — mọi bộ chọn (màn Danh mục, Chọn danh mục, form Hoá đơn / Ngân sách,
/// AI, C1, C3…) đi qua đây, nên bản sao **đang ẩn theo khuôn** (`dangAnTheoKhuon`, spec 2026-10-27 mục 4) không lọt vào
/// đâu. Test quét 40 canh. Bảng TRA tên (`getBangTraTen`, `watchAll`) KHÔNG đi qua đây — lịch sử giữ tên.
library;

import '../../../core/database/app_database.dart';
import '../domain/ban_sao_mac_dinh.dart';
import 'models/category_entity.dart';

Future<List<Category>> hangChonDuoc(AppDatabase db, int accountId, String classify) async =>
    _boHangAn(await db.categoryDao.getCategoryRows(accountId, classify));

/// Phát lại khi hàng khuôn đổi (admin xoá / khôi phục — về qua kéo về): DAO đọc hàng + khuôn trong một truy vấn.
Stream<List<Category>> theoDoiHangChonDuoc(AppDatabase db, int accountId, String classify) =>
    db.categoryDao.watchCategoryRows(accountId, classify).map(_boHangAn);

/// Hàng của tài khoản tách đôi: [chon] — đúng [hangChonDuoc]; [an] — đúng những hàng mọi bộ chọn bỏ đi (`dangAnTheoKhuon`).
/// [an] nuôi mục *"Đang tạm ngừng"* của màn Danh mục (G110), nơi duy nhất người dùng thấy và đổi tên được chúng.
typedef HangChonVaAn = ({List<Category> chon, List<Category> an});

Future<HangChonVaAn> hangChonVaAn(AppDatabase db, int accountId, String classify) async =>
    _tach(await db.categoryDao.getCategoryRows(accountId, classify));

Stream<HangChonVaAn> theoDoiHangChonVaAn(AppDatabase db, int accountId, String classify) =>
    db.categoryDao.watchCategoryRows(accountId, classify).map(_tach);

List<Category> _boHangAn(({List<Category> rows, List<Category> khuon}) kq) => _tach(kq).chon;

HangChonVaAn _tach(({List<Category> rows, List<Category> khuon}) kq) {
  final khuon = kq.khuon.map(CategoryEntity.fromDrift).toList();
  final chon = <Category>[];
  final an = <Category>[];
  for (final r in kq.rows) {
    (dangAnTheoKhuon(CategoryEntity.fromDrift(r), khuon) ? an : chon).add(r);
  }
  return (chon: chon, an: an);
}
