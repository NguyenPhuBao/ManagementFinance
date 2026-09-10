import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../transaction/data/repositories/transaction_repository.dart';
import '../../domain/dieu_chinh_so_du.dart';
import '../../domain/wallet_status.dart';

/// Điều chỉnh số dư ví (đối soát) — đường ghi.
///
/// Người dùng đếm ví ngoài đời rồi nhập **số dư thực tế**; lớp này sinh một
/// khoản bù để lịch sử giao dịch khớp lại với số ấy. Luật tính và phép nhận
/// dạng nằm ở `domain/dieu_chinh_so_du.dart`; lớp này chỉ nối nó với CSDL.
///
/// ## Vì sao đi qua `TransactionRepository` chứ không `updateBalance`
///
/// Ghi thẳng số dư là **đúng cái hố** mà tính năng này sinh ra để bịt: ô số dư
/// ở màn Sửa ví vốn ghi đè `balance`, nên số dư trôi khỏi lịch sử giao dịch mà
/// không có dòng nào giải thích. Đi qua `addTransaction` thì phép cộng trừ số
/// dư **và phép hoàn lại khi xoá** đều dùng lại `_applyBalances` đã có, đúng cả
/// hai chiều — người dùng xoá nhầm khoản bù là số dư quay lại như cũ.
///
/// Đây cũng là lý do khoản bù là `thu`/`chi` chứ không phải `transfer`:
/// `_applyBalances` **cố ý không động vào ví nào** khi khoản chuyển thiếu ví
/// đích ("đừng trừ một nửa").
class DieuChinhSoDuService {
  DieuChinhSoDuService({
    required AppDatabase db,
    required TransactionRepository transactionRepository,
  })  : _db = db,
        _txRepo = transactionRepository;

  final AppDatabase _db;
  final TransactionRepository _txRepo;

  static const _uuid = Uuid();

  /// Đưa số dư ví về [soDuThucTe] bằng một khoản bù.
  ///
  /// Không làm gì khi hai số đã bằng nhau. Ném [CacheException] khi ví không
  /// còn hoặc ví **đã lưu trữ**.
  Future<void> dieuChinh({
    required String walletId,
    required double soDuThucTe,
    required String lyDo,
    DateTime? vaoLuc,
  }) async {
    final vi = await _db.walletDao.getById(walletId);
    if (vi == null) {
      throw const CacheException('Không tìm thấy ví cần điều chỉnh số dư.');
    }

    // Lưu trữ là ĐÓNG BĂNG: không ghi giao dịch mới. Cho đối soát ví lưu trữ là
    // mở lại đúng cánh cửa vừa đóng ở tính năng trước.
    if (!WalletStatus.laHoatDong(vi.status)) {
      throw CacheException(
          'Ví "${vi.name}" đang được lưu trữ nên không ghi thêm giao dịch. '
          'Hãy bỏ lưu trữ trước khi đối soát số dư.');
    }

    final khoan = tinhKhoanDieuChinh(
      soDuHienTai: vi.balance,
      soDuThucTe: soDuThucTe,
    );
    // `null` là "không có gì để ghi". Ghi một khoản 0đ sẽ vỡ
    // `chk_transaction_nonzero_amount` của PostgreSQL rồi kẹt hàng đợi đẩy.
    if (khoan == null) return;

    final luc = vaoLuc ?? DateTime.now();
    await _txRepo.addTransaction(TransactionEntity(
      id: _uuid.v4(),
      walletId: walletId,
      idaccount: vi.idaccount,
      // KHÔNG danh mục — đây là chân cấu trúc của phép nhận dạng, thứ giao diện
      // thêm giao dịch không tạo ra được (nó bắt buộc chọn danh mục).
      categoryId: null,
      amount: khoan.soTien,
      type: khoan.loai,
      note: ghiChuDieuChinh(lyDo),
      date: luc,
      syncStatus: 'pending',
      updatedAt: luc,
    ));
  }
}
