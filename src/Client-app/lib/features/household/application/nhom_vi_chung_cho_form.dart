/// Hàm nạp của `ViChungChoFormNguon` (spec 2026-11-16 mục 2.2): nhà hiện tại mà tôi ĐƯỢC ghi khoản, kèm ví chung đang hoạt
/// động. Chờ kho trước khi đọc vai (khuôn G92 — trong khe mở app `nha == null`).
library;

import '../../transaction/data/them_giao_dich_nguon.dart';
import '../../transaction/data/vi_chung_cho_form_nguon.dart';
import '../../wallet/data/models/wallet_entity.dart';
import '../data/repositories/nha_repository.dart';
import '../domain/quyen_nha.dart';
import 'quyen_hien_tai.dart';

/// Route bộ chọn danh mục của nhà khi form `/add` đang ở chế độ nhà — con của `/add` (`app_router.dart`).
const String kDuongChonDanhMucNhaTuAdd = '/add/nha-category';

Future<NhomViChung?> napNhomViChung({
  required NhaRepository nha,
  required Future<List<WalletEntity>> Function(int idNha) viChung,
  required ThemGiaoDichNguon Function(int idNha) nguon,
}) async {
  await nha.choNapKho();
  final t = nha.hienTai;
  final n = t.nha;
  if (n == null || !duocLamViecNha(ViecNha.ghiKhoan, vai: t.vai, trangThai: n.trangThai)) return null;
  final vi = await viChung(n.id);
  if (vi.isEmpty) return null;
  return NhomViChung(
    idNha: n.id,
    tenNha: n.ten,
    vi: vi,
    nguon: nguon(n.id),
    conDuocGhi: () => conDuocLamViecNha(nha, n.id, ViecNha.ghiKhoan),
    duongChonDanhMuc: kDuongChonDanhMucNhaTuAdd,
  );
}
