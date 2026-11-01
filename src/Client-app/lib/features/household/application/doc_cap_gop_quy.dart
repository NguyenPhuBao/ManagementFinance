import '../../transaction/data/cap_gop_quy_nguon.dart';
import '../../transaction/data/models/transaction_entity.dart';
import '../data/models/nha_cua_toi.dart';
import '../domain/cau_xoa_khoan_gop.dart';
import '../domain/quyen_nha.dart';

/// Hàm đọc của `CapGopQuyNguon` (nối ở DI): nửa RIÊNG [t] của khoản góp / rút có còn cặp để giữ khớp không (đợt 1B Task 9).
///
/// Chỉ xét nửa riêng (`fundPairId` có, `idhousehold` null). Có cặp khi nửa của nhà còn trên máy VÀ còn thuộc đúng nhà đang
/// ở — sau khi rời nhà nửa nhà đã gỡ khỏi máy, nửa riêng là khoản thường (`02A` mục 6). Lỗi đọc ném ra để cổng nuốt thành
/// `null` (khoản đi đường thường).
///
/// [docCap] = `GopQuyService.docCap`, [nhaHienTai] = `NhaRepository.hienTai`, [tenVi] = tên ví theo mã (`null` khi không có).
/// Máy này là máy NGƯỜI GHI (chỉ ở đó có nửa riêng), nên câu hộp luôn có ví riêng và không có `tenNguoiKhac`.
Future<CapGopQuy?> docCapGopQuy(
  TransactionEntity t, {
  required Future<({TransactionEntity? rieng, TransactionEntity? nha})> Function(String maCap) docCap,
  required NhaCuaToi Function() nhaHienTai,
  required Future<String?> Function(String walletId) tenVi,
}) async {
  final maCap = t.fundPairId;
  if (maCap == null || t.idhousehold != null) return null;
  final cap = await docCap(maCap);
  final nuaNha = cap.nha;
  final hienTai = nhaHienTai();
  if (nuaNha == null || hienTai.nha == null || hienTai.nha!.id != nuaNha.idhousehold) return null;
  final gop = t.type == 'chi';
  // Cặp ĐÃ xác nhận có. Lỗi đọc TÊN ví (chỉ để dựng câu) không được rơi về đường xoá một nửa — đó là lệch cặp thật: tên quỹ
  // về `ví chung`, tên ví riêng về câu chung không nêu ví (`tenViRieng: null`). Lỗi đọc CẶP ở trên vẫn ném (brief Task 9).
  Future<String?> tenHoacNull(String id) async {
    try {
      return await tenVi(id);
    } catch (_) {
      return null;
    }
  }

  final tenQuy = await tenHoacNull(nuaNha.walletId) ?? 'ví chung';
  String? tenRieng;
  try {
    tenRieng = await tenVi(t.walletId) ?? 'ví riêng';
  } catch (_) {
    tenRieng = null;
  }
  return CapGopQuy(
    maCap: maCap,
    laGop: gop,
    cauXoa: cauXoaKhoanGop(gop: gop, tenQuy: tenQuy, soTien: t.amount, tenViRieng: tenRieng),
    choThaoTac: duocLamViecNha(ViecNha.ghiKhoan, vai: hienTai.vai, trangThai: hienTai.nha!.trangThai),
  );
}
