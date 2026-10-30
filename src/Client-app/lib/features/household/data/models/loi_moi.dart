/// Mã mời, bản xem trước mã, lời mời gửi tới tôi và kết quả mời qua email (spec gia đình 2026-10-23 mục 5.2–5.3; `docs/Family/01`
/// mục 2; `04` mục 2 — #3, #4, #6, #13, #14).
library;

import '../../domain/ma_moi.dart';
import '../../domain/vai_nha.dart';

class MaMoiEntity {
  const MaMoiEntity({
    required this.ma,
    required this.vai,
    this.hetHan,
    this.email,
    this.taoLuc,
    this.trangThai = TrangThaiLoiMoi.dangCho,
  });

  final String ma;

  /// `Member` hoặc `Viewer` — chủ không mời được vai chủ.
  final VaiNha vai;
  final DateTime? hetHan;

  /// Khác `null` = lời mời qua email (#13); `null` = mã thường (#3).
  final String? email;
  final DateTime? taoLuc;

  /// #4 trả cả lời mời email đã từ chối / huỷ / dùng / hết hạn (đơn 57.8.5) — chỉ [conHieuLuc] mới lên danh sách mã còn
  /// hiệu lực của màn Mời (lát 2).
  final TrangThaiLoiMoi trangThai;

  bool get conHieuLuc => trangThai == TrangThaiLoiMoi.dangCho;
}

/// Thiếu / rỗng `code` → `null`: không mã thì không có gì để chia sẻ.
MaMoiEntity? maMoiTuJson(Map<String, Object?> j) {
  final ma = j['code']?.toString();
  if (ma == null || ma.isEmpty) return null;
  return MaMoiEntity(
    ma: ma,
    vai: vaiNhaTuServer(j['role']?.toString()),
    hetHan: _ngay(j['expiresAt']),
    email: j['email']?.toString(),
    taoLuc: _ngay(j['createAt']),
    trangThai: trangThaiLoiMoiTuServer(j['status']?.toString()),
  );
}

/// Lời mời gửi tới tôi — #14 `GET /households/invitations` (`01` mục 2.4). Server `177dd0e1` không trả `memberCount` /
/// `maxMembers` (đơn 57.8.6) → `null`, không bịa.
class LoiMoiToiEntity {
  const LoiMoiToiEntity({
    required this.ma,
    required this.tenNha,
    required this.tenNguoiMoi,
    required this.vai,
    this.hetHan,
    this.soThanhVien,
    this.toiDa,
  });

  final String ma;
  final String tenNha;
  final String tenNguoiMoi;
  final VaiNha vai;
  final DateTime? hetHan;
  final int? soThanhVien;
  final int? toiDa;
}

/// Thiếu / rỗng `code` → `null`: không mã thì không chấp nhận / từ chối được.
LoiMoiToiEntity? loiMoiToiTuJson(Map<String, Object?> j) {
  final ma = j['code']?.toString();
  if (ma == null || ma.isEmpty) return null;
  return LoiMoiToiEntity(
    ma: ma,
    tenNha: j['householdName']?.toString() ?? '',
    tenNguoiMoi: j['inviterName']?.toString() ?? '',
    vai: vaiNhaTuServer(j['role']?.toString()),
    hetHan: _ngay(j['expiresAt']),
    soThanhVien: _soNguyen(j['memberCount']),
    toiDa: _soNguyen(j['maxMembers']),
  );
}

/// Thân `202` của #13 — luôn cùng hình dạng dù email có tài khoản hay không (`01` mục 2.2, chống dò email). Màn Mời (lát 2)
/// chỉ hiện *"Đã gửi lời mời tới …"*.
class KetQuaMoiEmail {
  const KetQuaMoiEmail({required this.email, required this.vai, this.hetHan});

  final String email;
  final VaiNha vai;
  final DateTime? hetHan;
}

/// Không bao giờ ném — trường thiếu rơi về mặc định.
KetQuaMoiEmail ketQuaMoiEmailTuJson(Map<String, Object?> j) => KetQuaMoiEmail(
      email: j['email']?.toString() ?? '',
      vai: vaiNhaTuServer(j['role']?.toString()),
      hetHan: _ngay(j['expiresAt']),
    );

class XemTruocLoiMoi {
  const XemTruocLoiMoi({
    required this.tenNha,
    required this.tenChuNha,
    required this.soThanhVien,
    required this.toiDa,
    required this.vai,
    this.hetHan,
  });

  final String tenNha;
  final String tenChuNha;
  final int soThanhVien;
  final int toiDa;

  /// Vai sẽ nhận khi tham gia.
  final VaiNha vai;
  final DateTime? hetHan;
}

/// Không bao giờ ném — trường thiếu rơi về mặc định.
XemTruocLoiMoi xemTruocTuJson(Map<String, Object?> j) => XemTruocLoiMoi(
      tenNha: j['householdName']?.toString() ?? '',
      tenChuNha: j['ownerName']?.toString() ?? '',
      soThanhVien: _soNguyen(j['memberCount']) ?? 0,
      toiDa: _soNguyen(j['maxMembers']) ?? kToiDaThanhVienMacDinh,
      vai: vaiNhaTuServer(j['role']?.toString()),
      hetHan: _ngay(j['expiresAt']),
    );

int? _soNguyen(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

DateTime? _ngay(Object? v) => v is String ? DateTime.tryParse(v) : null;
