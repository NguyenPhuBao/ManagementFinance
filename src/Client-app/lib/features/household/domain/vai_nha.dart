/// Ba vai cố định áp cho cả nhà (spec gia đình 2026-10-23 mục 1) và ba trạng thái nhà (mục 3.1) — Dart thuần, ánh xạ chữ
/// của server (đơn 50 mục 1, C.1). Cùng khuôn `premium/domain/trang_thai_don.dart`.
library;

enum VaiNha { chu, thanhVien, chiXem }

enum TrangThaiNha { hoatDong, chiXem, daGiaiTan }

/// Trần thành viên khi server chưa nói (spec 5.7). Trần thật là `maxMembers` của `/households/me`.
const kToiDaThanhVienMacDinh = 6;

/// Vai lạ / thiếu → [VaiNha.chiXem]: quyền ít nhất — đoán rộng là mở nút ghi cho người server sẽ từ chối.
VaiNha vaiNhaTuServer(String? s) => switch (s) {
      'Owner' => VaiNha.chu,
      'Member' => VaiNha.thanhVien,
      _ => VaiNha.chiXem,
    };

String khoaServerCuaVai(VaiNha v) => switch (v) {
      VaiNha.chu => 'Owner',
      VaiNha.thanhVien => 'Member',
      VaiNha.chiXem => 'Viewer',
    };

/// Trạng thái lạ / thiếu → [TrangThaiNha.chiXem]: xem được, không ghi — cùng lý lẽ với vai.
TrangThaiNha trangThaiNhaTuServer(String? s) => switch (s) {
      'Active' => TrangThaiNha.hoatDong,
      'Dissolved' => TrangThaiNha.daGiaiTan,
      _ => TrangThaiNha.chiXem,
    };

String khoaServerCuaTrangThai(TrangThaiNha t) => switch (t) {
      TrangThaiNha.hoatDong => 'Active',
      TrangThaiNha.chiXem => 'ReadOnly',
      TrangThaiNha.daGiaiTan => 'Dissolved',
    };

String tenVai(VaiNha v) => switch (v) {
      VaiNha.chu => 'Chủ nhà',
      VaiNha.thanhVien => 'Thành viên',
      VaiNha.chiXem => 'Chỉ xem',
    };
