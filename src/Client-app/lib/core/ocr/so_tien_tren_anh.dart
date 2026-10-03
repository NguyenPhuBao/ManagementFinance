/// Đọc con số tiền trong một dòng chữ lấy từ ảnh. Hàm thuần. Dời từ `features/ai_chat/spike/spike_c4.dart` ngày
/// 2026-10-02 (`docSoHoaDon`, `_tienTrenDong`) để bộ đọc biên lai dùng chung.
library;

final RegExp _so = RegExp(r'\d[\d.,]*\d|\d');

/// Một chuỗi số trên ảnh → số nguyên đồng. `.` / `,` theo sau bởi đúng 3 chữ số là ngăn nghìn; phần lẻ sau dấu cuối
/// (1–2 chữ số) bị bỏ. `null` khi không ra số.
int? docSoTrenAnh(String s) {
  final m = RegExp(r'^(\d{1,3}(?:[.,]\d{3})+)(?:[.,]\d{1,2})?$').firstMatch(s);
  if (m != null) return int.tryParse(m.group(1)!.replaceAll(RegExp(r'[.,]'), ''));
  final le = RegExp(r'^(\d+)[.,]\d{1,2}$').firstMatch(s);
  if (le != null) return int.tryParse(le.group(1)!);
  return int.tryParse(s);
}

/// Số tiền hợp lý trên một dòng: từ 1.000 đ, dưới 10 chữ số. Bỏ chuỗi bắt đầu bằng `0` (số điện thoại) và chuỗi liền
/// từ 9 chữ số không ngăn nghìn (mã vạch, mã số thuế, số tài khoản).
List<int> tienTrenDong(String dong) => [
      for (final m in _so.allMatches(dong))
        if (!(m.group(0)!.startsWith('0') && m.group(0)!.length > 1) &&
            !(m.group(0)!.length > 8 && !m.group(0)!.contains(RegExp(r'[.,]'))))
          if (docSoTrenAnh(m.group(0)!) case final v? when v >= 1000 && v < 1000000000) v,
    ];
