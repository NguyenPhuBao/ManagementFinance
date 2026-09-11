import '../../bill/domain/bill_note.dart';
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

TransactionOwner transactionOwnerOf(TransactionEntity transaction) {
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
  if (note.startsWith(kGhiChuTraHoaDon)) return TransactionOwner.bill;
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
