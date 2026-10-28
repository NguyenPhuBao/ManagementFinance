/// Mã mời 8 ký tự (spec gia đình 2026-10-23 mục 3.1; đơn 50 C.2): chữ in hoa + số, bỏ `0 O 1 I` dễ nhầm.
library;

const kBangKyTuMaMoi = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const kDoDaiMaMoi = 8;

/// Chữ người dùng gõ / dán: in hoa, bỏ khoảng trắng và gạch nối (`abcd-2345`, `ABCD 2345`).
String chuanHoaMaMoi(String s) => s.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');

/// Đúng dạng để gửi server — sai dạng thì khỏi tốn một vòng mạng (và một lượt giới hạn tần suất, đơn 50 C.4).
bool maMoiHopLe(String ma) => ma.length == kDoDaiMaMoi && ma.split('').every(kBangKyTuMaMoi.contains);

/// Trạng thái một lời mời ở `GET /households/invites` (`docs/Family/04` mục 2 #4; `household.service.js` `getHouseholdInvites`):
/// mã thường chỉ về khi còn hiệu lực, lời mời email về cả đã từ chối / huỷ / dùng / hết hạn trong 7 ngày (đơn 57.8.5). Chỉ
/// [dangCho] mới là "mã còn hiệu lực" của màn Mời.
enum TrangThaiLoiMoi { dangCho, daTuChoi, daHuy, daDung, hetHan }

/// Thiếu / `Pending` → [TrangThaiLoiMoi.dangCho] (hình dạng cũ không có `status`); chữ lạ → [TrangThaiLoiMoi.hetHan] — đọc chữ
/// lạ là "còn hiệu lực" thì nút Huỷ trỏ vào mã server đã bỏ (quyền ít nhất, cùng lý lẽ `vaiNhaTuServer`).
TrangThaiLoiMoi trangThaiLoiMoiTuServer(String? s) => switch (s) {
      null || 'Pending' => TrangThaiLoiMoi.dangCho,
      'Declined' => TrangThaiLoiMoi.daTuChoi,
      'Revoked' => TrangThaiLoiMoi.daHuy,
      'Used' => TrangThaiLoiMoi.daDung,
      'Expired' => TrangThaiLoiMoi.hetHan,
      _ => TrangThaiLoiMoi.hetHan,
    };
