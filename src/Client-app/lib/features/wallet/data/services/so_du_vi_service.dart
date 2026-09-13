import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/so_du_mo_so.dart';
import '../../domain/wallet_type.dart';

/// Nơi **DUY NHẤT** ghi `wallets.balance`.
///
/// ## Vì sao lớp này tồn tại
///
/// Trước 2026-09-13, `balance` là một **giá trị tuyệt đối đồng bộ theo LWW**, và
/// đó là đường **duy nhất** để máy B biết máy A vừa tiêu tiền — nhánh pull giao
/// dịch không hề đụng số dư (đo: 0 dòng). Mất update là **tất yếu** với LWW trên
/// một giá trị tích luỹ: máy trả hoá đơn → trừ ví → push ví xung đột → pull ghi
/// đè bằng con số server → **lần trừ biến mất không dấu vết**, mà hàng vừa bị
/// đánh dấu `synced` nên cũng không còn gì để đẩy lại. Đo thật trên hai máy ảo
/// (**G37**).
///
/// Nay `balance` là **cache của một công thức**: tổng sổ giao dịch của ví
/// (`TransactionDao.tongTheoVi`). Vì sổ **đã đồng bộ đúng**, hai máy có cùng tập
/// giao dịch sẽ tính ra cùng một số — xung đột LWW không phá được nữa, vì không
/// còn gì để mất.
///
/// Thiết kế: `docs/superpowers/specs/2026-09-13-so-du-vi-suy-tu-so-giao-dich-design.md`.
class SoDuViService {
  SoDuViService({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  /// Tính lại số dư của [walletId] từ sổ và ghi vào `wallets.balance`.
  ///
  /// ⚠️ **Tự đặt neo nếu ví chưa có**, TRƯỚC khi tính. Không có bước ấy thì công
  /// thức thiếu đúng phần neo và trả về một số sai hẳn — ví dựng với số dư
  /// 1.000.000 rồi trả một hoá đơn 350.000 sẽ ra **−350.000** thay vì 650.000.
  /// Đây không phải trường hợp hiếm: **mọi** ví trong bộ test đều dựng thẳng qua
  /// `walletDao.insert`, không đi qua đường tạo ví, nên không ví nào có neo sẵn.
  ///
  /// Một hàm tên là "tính lại" mà lại ghi thêm một hàng là điều cần nói rõ: nó
  /// được chấp nhận vì bước ấy **luỹ đẳng** và là **điều kiện tiên quyết** của
  /// phép tính, không phải tác dụng phụ.
  Future<void> tinhLaiSoDu(String walletId) async {
    final vi = await _db.walletDao.getById(walletId);
    if (vi == null) return;

    // Ví ngân hàng: server tự ghi số dư từ SePay (`workers/bank.worker.js:213`),
    // và số dư ngân hàng thật có thể khác tổng sổ — phí, lãi, giao dịch chưa về.
    // Tính lại rồi ghi đè là xoá đúng con số server vừa ghi.
    if (WalletType.tuKhoa(vi.type) == WalletType.banking) return;

    await _datNeoNeuThieu(vi);

    final tong = await _db.transactionDao.tongTheoVi(walletId);
    if ((tong - vi.balance).abs() < _nguongBangNhau) return;
    await _db.walletDao.updateBalance(walletId, tong);
  }

  /// Tính lại cho nhiều ví; id trùng nhau chỉ chạy một lần.
  Future<void> tinhLaiNhieuVi(Iterable<String> walletIds) async {
    for (final id in walletIds.toSet()) {
      await tinhLaiSoDu(id);
    }
  }

  /// Sinh khoản mở sổ cho [vi] nếu nó chưa có. **Luỹ đẳng.**
  Future<void> _datNeoNeuThieu(Wallet vi) async {
    final idNeo = idKhoanMoSo(vi.id);

    // `getById` của giao dịch đọc **cả hàng đã xoá mềm** — đúng ý ở đây: người
    // dùng lỡ xoá khoản mở sổ thì cũng không được sinh lại, nếu không số dư
    // nhảy lên đúng bằng phần neo ở mỗi lần quét.
    if (await _db.transactionDao.getById(idNeo) != null) return;

    final daCo = await _db.transactionDao.tongTheoVi(vi.id);
    final neo = vi.balance - daCo;
    if (neo.abs() < _nguongBangNhau) return;

    final now = DateTime.now();
    await _db.transactionDao.insert(TransactionsCompanion.insert(
      id: idNeo,
      walletId: vi.id,
      idaccount: vi.idaccount,
      // Số tiền luôn DƯƠNG, chiều nằm ở `type` — đúng quy ước của bảng
      // `transactions` và của `_applyBalances`.
      amount: neo.abs(),
      type: neo > 0 ? 'thu' : 'chi',
      note: Value(ghiChuMoSo()),
      date: now,
      syncStatus: const Value('pending'),
      updatedAt: now,
    ));
  }
}

/// Ngưỡng coi hai số dư là bằng nhau, tính bằng **đồng** — cùng giá trị và cùng
/// lý do với `wallet/domain/dieu_chinh_so_du.dart`: số dư là `double` và mọi
/// phép cộng dồn trên `double` đều để lại đuôi lẻ. Ghi lại vô điều kiện là hàng
/// ví luôn ở `pending` — đẩy lên rồi lại `pending` — một vòng lặp đẩy vô tận mà
/// không có lỗi nào báo ra.
const double _nguongBangNhau = 0.5;
