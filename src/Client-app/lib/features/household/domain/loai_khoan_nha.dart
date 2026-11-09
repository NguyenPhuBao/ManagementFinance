/// MỘT định nghĩa phân loại khoản của gia đình (`docs/Family/02A` mục 3). Nhận dạng góp / rút qua
/// [TransactionEntity.fundPairId], không qua tiền tố ghi chú (tên ví đổi thì ghi chú cũ mang tên cũ).
library;

import '../../transaction/data/models/transaction_entity.dart';
import '../../transaction/domain/khoan_vao_thong_ke.dart';

enum LoaiKhoanNha { chiNha, thuKhac, chuyen, gopNha, rutNha, gopRieng, rutRieng, khongTinh, khoanThuong }

LoaiKhoanNha phanLoaiKhoanNha(TransactionEntity t) {
  final coCap = t.fundPairId != null;
  if (t.idhousehold == null) {
    if (!coCap) return LoaiKhoanNha.khoanThuong;
    return t.type == 'thu' ? LoaiKhoanNha.rutRieng : LoaiKhoanNha.gopRieng;
  }
  if (coCap) return t.type == 'thu' ? LoaiKhoanNha.gopNha : LoaiKhoanNha.rutNha;
  if (t.type == 'transfer') return LoaiKhoanNha.chuyen;
  if (!khoanVaoThongKe(loai: t.type, categoryId: t.categoryId, ghiChu: t.note)) return LoaiKhoanNha.khongTinh;
  return t.type == 'thu' ? LoaiKhoanNha.thuKhac : LoaiKhoanNha.chiNha;
}
