/// Ví nào sẽ âm vì lần ghi này — để form Thêm / Sửa giao dịch HỎI LẠI trước khi lưu.
///
/// Người dùng chốt 2026-11-20: ví tắt "Cho phép số dư âm" mà một khoản làm số dư xuống dưới 0 thì hỏi *"Vẫn ghi?"* rồi
/// cho lưu — không chặn hẳn. Trước đó cờ chỉ tắt cảnh báo sau khi đã ghi (G27), nên ví vẫn âm mà không ai hỏi.
///
/// Vế trừ / cộng theo vai của ví khớp `TransactionDao.bienDongTheoVi` (thu +, chi −, chuyển: nguồn −, đích +). Số dư
/// truyền vào là số dư HIỆN TẠI — đã gồm khoản đang sửa ([truoc]), nên khoản cũ được trả lại trước khi cộng khoản mới.
/// Chỉ hỏi ví bị TRỪ thêm: khoản làm ví tăng không bao giờ là lý do hỏi, kể cả khi ví vẫn còn âm.
library;

import '../../../core/utils/dung_sai_tien.dart';
import '../data/models/transaction_entity.dart';

/// Ví đưa vào phép kiểm — tách khỏi `WalletEntity` để domain không đọc mảng ví.
class ViKiemAm {
  const ViKiemAm({required this.id, required this.ten, required this.soDu, required this.choPhepAm});
  final String id;
  final String ten;
  final double soDu;
  final bool choPhepAm;
}

/// Một ví sẽ âm, kèm số dư sau khi ghi.
class ViSeAm {
  const ViSeAm({required this.ten, required this.soDuSau});
  final String ten;
  final double soDuSau;
}

/// Biến động của [t] lên từng ví nó chạm tới (đã mang dấu).
Map<String, double> bienDongLenVi(TransactionEntity t) {
  final ra = <String, double>{};
  void cong(String id, double v) => ra[id] = (ra[id] ?? 0) + v;
  switch (t.type) {
    case 'thu':
      cong(t.walletId, t.amount);
    case 'chi':
      cong(t.walletId, -t.amount);
    case 'transfer':
      final den = t.walletTransfer;
      if (den == null) break;
      cong(t.walletId, -t.amount);
      cong(den, t.amount);
  }
  return ra;
}

/// Ví KHÔNG cho âm mà [moi] (thay cho [truoc] nếu đang sửa) làm số dư xuống dưới 0, theo thứ tự [vi].
List<ViSeAm> viSeAm({
  required Iterable<ViKiemAm> vi,
  required List<TransactionEntity> moi,
  TransactionEntity? truoc,
}) {
  final doi = <String, double>{};
  for (final t in moi) {
    bienDongLenVi(t).forEach((id, v) => doi[id] = (doi[id] ?? 0) + v);
  }
  if (truoc != null) {
    bienDongLenVi(truoc).forEach((id, v) => doi[id] = (doi[id] ?? 0) - v);
  }
  final ra = <ViSeAm>[];
  final daXet = <String>{};
  for (final w in vi) {
    if (w.choPhepAm || !daXet.add(w.id)) continue;
    final d = doi[w.id] ?? 0;
    if (d >= 0) continue;
    final sau = w.soDu + d;
    if (sau < -kDungSaiTien) ra.add(ViSeAm(ten: w.ten, soDuSau: sau));
  }
  return ra;
}
