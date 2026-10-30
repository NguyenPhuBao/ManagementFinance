/// Câu lỗi của mảng gia đình — MỘT chỗ (spec 2026-10-23 mục 7.1). Dart thuần: phép đọc lỗi HTTP → [LoaiLoiNha] ở
/// `data/datasources/household_api.dart` (`loaiLoiNhaTu`); repository ném [LoiNha] nên giao diện không thấy Dio. Không in
/// mã, URL, số (bài học `cauLoiTai`).
library;

enum LoaiLoiNha {
  maKhongCo,
  maHetHan,
  maDaDung,
  daONhaKhac,
  nhaDu,
  khongONha,
  khongPhaiChu,
  chuPhaiChuyen,
  nhaChiXem,
  nhaDaGiaiTan,

  /// Đích của đổi vai / mời ra / chuyển chủ không còn ở nhà (`MEMBER_NOT_IN_HOUSEHOLD` / `TARGET_NOT_IN_HOUSEHOLD`).
  thanhVienKhongONha,

  /// Lời mời email gửi cho tài khoản có email khác (`01` mục 2.2 — thư bị chuyển tiếp).
  loiMoiKhongPhaiCuaBan,
  loiMoiDaTuChoi,

  /// Quá 20 thư / nhà / 24 giờ hoặc 5 thư / giờ (`04` mục 2 #13).
  guiMoiQuaNhieu,
  emailKhongHopLe,
  canPremium,

  /// `FEATURE_DISABLED`: Basic bị tắt quyền HOẶC Premium bị admin tạm ngừng — mã không phân biệt được (B1, người dùng chốt
  /// 2026-10-27: Premium tạm ngừng KHÔNG được mời nâng cấp) ⇒ câu trung tính; lát 2 chọn câu theo `trangThaiQuyen`.
  tinhNangKhongMo,
  phienHetHan,
  mayChu,
  matMang,
  khac,
}

/// Lỗi đã phân loại mà `NhaRepository` ném.
class LoiNha implements Exception {
  const LoiNha(this.loai);

  final LoaiLoiNha loai;

  @override
  String toString() => 'LoiNha(${loai.name})';
}

LoaiLoiNha loaiLoiNhaCua(Object e) => e is LoiNha ? e.loai : LoaiLoiNha.khac;

/// `code` ở cấp gốc thân 4xx → loại; mã lạ / thiếu → `null` (nơi gọi rơi về [LoaiLoiNha.khac]).
///
/// ĐỌC CẢ HAI bộ tên tới khi backend chốt bảng mã (đơn 57.7): tên tài liệu (đơn 50 C.3, `docs/Family/01` mục 2.5) và tên
/// mã đang chạy ở `177dd0e1` (`docs/Family/04` mục 2). `HOUSEHOLD_NOT_ACTIVE` gộp ReadOnly + Dissolved → đọc là chỉ xem rồi
/// làm mới `/me` (người dùng chốt 2026-10-28) — trạng thái thật về sau một vòng mạng. `CANNOT_*` (tự đổi vai / tự mời ra /
/// tự chuyển chủ) không có loại: form không cho chọn chính mình, tới đây là lỗi lập trình → `khac`.
LoaiLoiNha? loaiLoiTuMa(String? ma) => switch (ma) {
      'HOUSEHOLD_INVITE_INVALID' || 'HOUSEHOLD_INVITE_NOT_FOUND' || 'INVALID_INVITE_CODE' => LoaiLoiNha.maKhongCo,
      'HOUSEHOLD_INVITE_EXPIRED' => LoaiLoiNha.maHetHan,
      'HOUSEHOLD_INVITE_USED' => LoaiLoiNha.maDaDung,
      'HOUSEHOLD_ALREADY_IN_ONE' => LoaiLoiNha.daONhaKhac,
      'HOUSEHOLD_FULL' => LoaiLoiNha.nhaDu,
      'HOUSEHOLD_NOT_FOUND' || 'NOT_IN_HOUSEHOLD' => LoaiLoiNha.khongONha,
      'HOUSEHOLD_NOT_OWNER' || 'FORBIDDEN_NOT_OWNER' => LoaiLoiNha.khongPhaiChu,
      'HOUSEHOLD_OWNER_MUST_TRANSFER' || 'OWNER_CANNOT_LEAVE' => LoaiLoiNha.chuPhaiChuyen,
      'HOUSEHOLD_READ_ONLY' || 'HOUSEHOLD_NOT_ACTIVE' => LoaiLoiNha.nhaChiXem,
      'HOUSEHOLD_CLOSED' => LoaiLoiNha.nhaDaGiaiTan,
      'MEMBER_NOT_IN_HOUSEHOLD' || 'TARGET_NOT_IN_HOUSEHOLD' => LoaiLoiNha.thanhVienKhongONha,
      'HOUSEHOLD_INVITE_WRONG_ACCOUNT' => LoaiLoiNha.loiMoiKhongPhaiCuaBan,
      'HOUSEHOLD_INVITE_DECLINED' => LoaiLoiNha.loiMoiDaTuChoi,
      'HOUSEHOLD_INVITE_RATE_LIMIT' => LoaiLoiNha.guiMoiQuaNhieu,
      'INVALID_EMAIL' => LoaiLoiNha.emailKhongHopLe,
      'PREMIUM_REQUIRED' => LoaiLoiNha.canPremium,
      'FEATURE_DISABLED' => LoaiLoiNha.tinhNangKhongMo,
      _ => null,
    };

/// Lỗi cho thấy trạng thái nhà ĐÃ ĐỔI ở nơi khác (bị mời ra, nhà giải tán / chỉ xem, đã vào nhà ở máy khác, đích của thao
/// tác đã rời) — repository làm mới trạng thái sau khi ném lỗi.
bool loiChoThayNhaDaDoi(LoaiLoiNha l) => switch (l) {
      LoaiLoiNha.daONhaKhac ||
      LoaiLoiNha.khongONha ||
      LoaiLoiNha.khongPhaiChu ||
      LoaiLoiNha.nhaChiXem ||
      LoaiLoiNha.nhaDaGiaiTan ||
      LoaiLoiNha.thanhVienKhongONha =>
        true,
      _ => false,
    };

/// Năm mã ĐẨY của gia đình (spec 4.2, đơn 50 D.3, `docs/Family/01` mục 3) — gặp một mã là trạng thái nhà / vai trên máy đã
/// cũ, repository làm mới. `HOUSEHOLD_WALLET_LIMIT` (cũng vĩnh viễn) KHÔNG ở đây: trần ví chung không nói gì về vai. Khớp TAY
/// với `_permanentCodes` của `core/sync/gui_lo_dong_bo.dart` (core không import mảng) — `cau_loi_nha_test` đọc tệp ấy để so.
const kMaDayLoiNha = {
  'HOUSEHOLD_NOT_MEMBER',
  'HOUSEHOLD_READ_ONLY',
  'HOUSEHOLD_CLOSED',
  'HOUSEHOLD_SCOPE_MISMATCH',
  'HOUSEHOLD_ROLE_FORBIDDEN',
};

String cauLoiNha(LoaiLoiNha l) => switch (l) {
      LoaiLoiNha.maKhongCo => 'Mã mời không đúng hoặc đã bị huỷ.',
      LoaiLoiNha.maHetHan => 'Mã mời đã hết hạn. Nhờ chủ nhà tạo mã mới.',
      LoaiLoiNha.maDaDung => 'Mã mời này đã được dùng.',
      LoaiLoiNha.daONhaKhac => 'Bạn đang ở một nhà khác. Rời nhà hiện tại trước.',
      LoaiLoiNha.nhaDu => 'Nhà đã đủ người.',
      LoaiLoiNha.khongONha => 'Bạn chưa ở nhà nào.',
      LoaiLoiNha.khongPhaiChu => 'Chỉ chủ nhà làm được việc này.',
      LoaiLoiNha.chuPhaiChuyen => 'Chuyển quyền chủ nhà hoặc giải tán trước.',
      LoaiLoiNha.nhaChiXem => 'Nhà đang ở chế độ chỉ xem — chủ nhà cần gia hạn Premium.',
      LoaiLoiNha.nhaDaGiaiTan => 'Nhà này đã giải tán.',
      LoaiLoiNha.thanhVienKhongONha => 'Người này không còn ở trong nhà.',
      LoaiLoiNha.loiMoiKhongPhaiCuaBan => 'Lời mời này gửi cho một tài khoản khác.',
      LoaiLoiNha.loiMoiDaTuChoi => 'Bạn đã từ chối lời mời này.',
      LoaiLoiNha.guiMoiQuaNhieu => 'Nhà này đã gửi quá nhiều lời mời. Thử lại sau.',
      LoaiLoiNha.emailKhongHopLe => 'Địa chỉ email không hợp lệ.',
      LoaiLoiNha.canPremium => 'Tạo nhà cần gói Premium.',
      LoaiLoiNha.tinhNangKhongMo => 'Tính năng gia đình hiện không dùng được với tài khoản này.',
      LoaiLoiNha.phienHetHan => 'Phiên đăng nhập hết hạn. Hãy đăng nhập lại.',
      LoaiLoiNha.mayChu => 'Máy chủ chưa phản hồi. Thử lại sau.',
      LoaiLoiNha.matMang => 'Cần có mạng để làm việc này.',
      LoaiLoiNha.khac => 'Có lỗi xảy ra. Thử lại sau.',
    };
