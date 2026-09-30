/// Điền sẵn form tạo mục tiêu từ query `/goals/add?name&target&deadline` — C3 (lệnh tạo ở màn Trợ lý AI, spec
/// `2026-09-28-c3-lenh-tao-hoa-don-muc-tieu-ngan-sach-design.md` §4). Hàm thuần, khuôn `dienSanTuQuery` của B2: query
/// hỏng thì bỏ đúng trường ấy, không ném — route đọc query từ URL, một đường dẫn sửa tay không được làm đổ trang.
library;

typedef DienSanMucTieu = ({String? ten, double? soTienDich, DateTime? han});

final RegExp _ngayIso = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// `null` khi query không có khoá nào của mình — form trống như khi mở thường.
DienSanMucTieu? dienSanMucTieuTuQuery(Map<String, String> q) {
  if (!q.keys.any(const {'name', 'target', 'deadline'}.contains)) return null;
  final ten = q['name']?.trim();
  final tien = double.tryParse(q['target'] ?? '');
  final han = q['deadline'] ?? '';
  final ngay = _ngayIso.hasMatch(han) ? DateTime.tryParse(han) : null;
  return (
    ten: (ten == null || ten.isEmpty) ? null : ten,
    // Dưới 13 chữ số: cột tiền là numeric(15,2) (trần `kSoChuSoToiDaSoTien`).
    soTienDich: (tien != null && tien > 0 && tien < 1e13) ? tien : null,
    // `DateTime.tryParse` nhận cả "2027-02-30" (tràn sang tháng 3) — so ngược để loại.
    han: ngay != null && ngay.toIso8601String().startsWith(han) ? ngay : null,
  );
}
