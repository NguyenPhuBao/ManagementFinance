import '../../goal/domain/goal_history_direction.dart';
import '../data/models/transaction_entity.dart';

/// Thực thể "sở hữu" hệ quả của một giao dịch — và vì thế là nơi DUY NHẤT
/// được phép xoá nó.
///
/// Sổ giao dịch chỉ biết hoàn số dư ví. Khoản nạp/rút mục tiêu còn bộ đếm
/// `current_amount` và cờ `is_completed` ở bảng goal; khoản trả hoá đơn còn cờ
/// Payed và hoá đơn kỳ kế tiếp. Xoá rời ở sổ thì những thứ ấy đứng nguyên —
/// đã thấy trên máy ảo 2026-09-06: xoá hai khoản nạp, tiến độ MuaXe vẫn
/// 1.100.000 trong khi lịch sử chỉ còn 900.000.
enum TransactionOwner { transaction, goal, bill }

/// Tiền tố của nửa "thu" trong cặp hai hàng rời mà bản app trước 2026-09-05
/// ghi cho mỗi lần nạp mục tiêu ("Tích lũy nhận từ Tiền mặt: MuaXe"). Không
/// còn được sinh ra, nhưng vẫn nằm trong dữ liệu thật. Chỉ để nhận diện,
/// KHÔNG dùng để ghi.
const String kGhiChuNapMucTieuCu = 'Tích lũy nhận từ ';

/// Tiền tố ghi chú của giao dịch chi do luồng trả hoá đơn sinh ra.
///
/// Hai việc: là cách **ghi** (`BillRepositoryImpl.payBill` ghi cả tiền tố lẫn `transactions.billId` trong một giao
/// tác), và là dấu nhận **hàng kiểu cũ** — khoản trả ghi trước schema v16 (2026-09-06), hoặc ghi từ 06/09 tới 12/09
/// rồi kéo về máy khác, mang tiền tố mà `billId` NULL. Mối nối chính của khoản trả với hoá đơn là `billId` (đồng bộ
/// dưới tên `idbill` từ 2026-09-12): [transactionOwnerOf] khoá theo `billId`, KHÔNG theo tiền tố (việc 4c,
/// 2026-10-17) — ghi chú hỏng lúc kéo về (`enc:…`) không làm mất khoá, ghi chú người dùng gõ trùng tiền tố không bị
/// khoá nhầm. Tiền tố còn là dấu "ghi chú do máy viết" của `laGhiChuMay`.
///
/// Ở đây từ 2026-10-16 (trước ở `bill/domain/bill_note.dart`, quét 29): hằng là cách MÃ HOÁ ghi chú của hàng sổ.
/// Bill đọc sổ giao dịch (B2 — `bill/domain/khoan_lap.dart`) nên không làm được nơi cấp hằng một chiều cho
/// transaction như goal (`goal_history_direction.dart` — goal không đọc sổ).
const String kGhiChuTraHoaDon = 'Thanh toán hóa đơn: ';

/// Ai sở hữu [transaction] — bảng luật ở spec 4c mục 3.1
/// (`docs/superpowers/specs/2026-10-17-chu-so-huu-khoan-tra-hoa-don-design.md`).
///
/// [hoaDonDaXoa]: hoá đơn mà `billId` trỏ tới CÓ trên máy và đã xoá mềm (trang hỏi `HoaDonDaXoaNguon` lúc thao tác).
/// Mặc định `false` — nơi chưa hỏi cổng coi khoản có `billId` là còn khoá: chưa biết thì không mở.
TransactionOwner transactionOwnerOf(
  TransactionEntity transaction, {
  bool hoaDonDaXoa = false,
}) {
  if (transaction.goalId != null) return TransactionOwner.goal;
  // `goal_id` đồng bộ từ 2026-09-07, nhưng hàng cũ trên server vẫn mang NULL
  // (G18) — với chúng, ghi chú là dấu hiệu duy nhất để nhận ra.
  // So TIỀN TỐ, không so "chứa", để ghi chú người dùng gõ không bị nhận nhầm.
  final note = transaction.note;
  if (note.startsWith(kGhiChuNapMucTieu) ||
      note.startsWith(kGhiChuRutMucTieu) ||
      note.startsWith(kGhiChuNapMucTieuCu)) {
    return TransactionOwner.goal;
  }
  // Khoá theo `billId`, KHÔNG xét ghi chú: ghi chú hỏng / mã hoá lúc kéo về vẫn khoá. Hoá đơn đã xoá (khoản mồ côi)
  // thì mở — nút Hoàn tác mất theo hoá đơn. Tiền tố không `billId` (kiểu cũ) cũng mở: không có đường Hoàn tác.
  if (transaction.billId != null && !hoaDonDaXoa) return TransactionOwner.bill;
  return TransactionOwner.transaction;
}

/// Câu chỉ đường khi sổ giao dịch từ chối xoá; `null` nghĩa là xoá được.
String? lyDoKhongXoaTaiSo(TransactionOwner owner) => switch (owner) {
      TransactionOwner.transaction => null,
      TransactionOwner.goal =>
        'Khoản này thuộc mục tiêu tiết kiệm — dùng "Rút" trong trang mục tiêu '
            'để tiến độ đổi theo.',
      TransactionOwner.bill =>
        'Khoản này là thanh toán hoá đơn — không xoá được từ sổ giao dịch.',
    };

/// Câu cảnh báo khi xoá ở sổ một khoản trả hoá đơn ĐÃ MỞ KHOÁ — khoản mồ côi (hàng 3 bảng spec 3.1) hoặc khoản kiểu
/// cũ (hàng 4); `null` với mọi khoản khác, kể cả khoản đang khoá (câu của nó là [lyDoKhongXoaTaiSo]).
///
/// Câu chữ ở MỘT chỗ: hộp xác nhận khi vuốt (Sổ giao dịch) dùng nguyên câu này, bảng chi tiết ghép nó trước câu chung
/// ([cauXacNhanXoaGiaoDich]). So tiền tố bằng `startsWith` trên ghi chú thô — cùng phép với `laGhiChuMay`.
String? canhBaoXoaTaiSo(
  TransactionEntity transaction, {
  bool hoaDonDaXoa = false,
}) {
  if (transactionOwnerOf(transaction, hoaDonDaXoa: hoaDonDaXoa) !=
      TransactionOwner.transaction) {
    return null;
  }
  // Tới đây mà còn `billId` thì chỉ có thể là hoá đơn đã xoá.
  if (transaction.billId != null) {
    return 'Hoá đơn của khoản này đã xoá — xoá ở đây chỉ trả tiền về ví.';
  }
  if (transaction.note.startsWith(kGhiChuTraHoaDon)) {
    return 'Khoản trả hoá đơn ghi bằng bản cũ — xoá ở đây chỉ trả tiền về ví, '
        'hoá đơn vẫn ghi là đã trả.';
  }
  return null;
}

/// Nội dung hộp "Xoá giao dịch?" của bảng chi tiết (Sổ giao dịch, Chi tiết ngân sách): câu cảnh báo (nếu có) đứng
/// trước câu chung — một định nghĩa cho cả hai trang.
String cauXacNhanXoaGiaoDich(
  TransactionEntity transaction, {
  bool hoaDonDaXoa = false,
}) {
  const chung = 'Số dư ví sẽ được hoàn lại. Không hoàn tác được.';
  final canhBao = canhBaoXoaTaiSo(transaction, hoaDonDaXoa: hoaDonDaXoa);
  return canhBao == null ? chung : '$canhBao $chung';
}
