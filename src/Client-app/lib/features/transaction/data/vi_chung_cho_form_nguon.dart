/// Cổng "ví chung chọn được ở form Thêm giao dịch thường" (spec 2026-11-16 mục 2.2). Mảng giao dịch không import gia đình:
/// hàm nạp dựng ở `household/application/nhom_vi_chung_cho_form.dart`, nối ở DI (khuôn `CapGopQuyNguon`).
library;

import '../../wallet/data/models/wallet_entity.dart';
import 'them_giao_dich_nguon.dart';

/// Nhà người dùng ĐƯỢC ghi khoản lúc nạp, cùng mọi thứ form cần để đổi sang chế độ nhà.
class NhomViChung {
  const NhomViChung({
    required this.idNha,
    required this.tenNha,
    required this.vi,
    required this.nguon,
    required this.conDuocGhi,
    required this.duongChonDanhMuc,
  });

  final int idNha;
  final String tenNha;

  /// Ví chung ĐANG HOẠT ĐỘNG — danh sách riêng, không bao giờ trộn vào ví cá nhân của form.
  final List<WalletEntity> vi;

  /// Nguồn của nhà (`ThemGiaoDichNguonNha`): danh mục nhà, mọi phép học / ghi phản hồi là no-op.
  final ThemGiaoDichNguon nguon;

  /// Hỏi lại quyền ghi khoản NGAY lúc Lưu (vai có thể đổi khi form mở — FINAL I-3).
  final bool Function() conDuocGhi;

  /// Route bộ chọn danh mục của nhà khi đang ở `/add`.
  final String duongChonDanhMuc;
}

class ViChungChoFormNguon {
  const ViChungChoFormNguon(this._nap);

  final Future<NhomViChung?> Function() _nap;

  /// `null` = không có nhóm ví chung (không ở nhà, không được ghi, không có ví chung, hoặc đọc hỏng — form mở như thường).
  Future<NhomViChung?> nap() async {
    try {
      return await _nap();
    } catch (_) {
      return null;
    }
  }
}
