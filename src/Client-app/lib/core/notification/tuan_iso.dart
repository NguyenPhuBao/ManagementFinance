/// Tuần theo ISO-8601, cho khoá chống trùng của thông báo Tổng kết tuần.
///
/// Dart **không có sẵn** phép này, và nó không phải phép chia cho 7: tuần ISO
/// bắt đầu thứ Hai, và **tuần 1 là tuần chứa thứ Năm đầu tiên của năm**. Hệ quả
/// là năm của một tuần ISO có thể khác `date.year` ở cả hai chiều —
/// 31/12/2025 thuộc `2026-W01`, còn 01/01/2021 thuộc `2020-W53`.
///
/// Sai một tuần ở đây nghĩa là hoặc báo hai lần cho cùng một tuần, hoặc bỏ sót
/// hẳn một tuần. Cả hai đều **im lặng** — không exception, không log.
library;

/// Số ngày trong tuần theo ISO: thứ Hai = 1 … Chủ nhật = 7.
///
/// `DateTime.weekday` của Dart đã dùng đúng quy ước này; hàm này tồn tại để
/// những chỗ dưới đọc ra được ý định thay vì một con số trần.
int _thuISO(DateTime d) => d.weekday;

DateTime _ngayGon(DateTime d) => DateTime(d.year, d.month, d.day);

/// Năm và số tuần ISO của [d].
///
/// Phép tính đi qua **thứ Năm của chính tuần ấy**: theo định nghĩa ISO, thứ Năm
/// luôn nằm trong năm mà tuần đó thuộc về. Tìm được thứ Năm là biết ngay cả năm
/// lẫn số thứ tự tuần, không cần bảng tra và không có ca đặc biệt nào.
({int nam, int tuan}) tuanISO(DateTime d) {
  final ngay = _ngayGon(d);
  final thuNam = ngay.add(Duration(days: 4 - _thuISO(ngay)));

  final dauNam = DateTime(thuNam.year, 1, 1);
  // `difference` trên hai mốc cùng 00:00 nên `inDays` không bị lệch bởi giờ.
  final thuTuTrongNam = thuNam.difference(dauNam).inDays + 1;

  return (nam: thuNam.year, tuan: (thuTuTrongNam - 1) ~/ 7 + 1);
}

/// Khoá tuần dạng `2026-W37` — thành phần của `dedupeKey`.
///
/// Số tuần **đệm 0** cho đủ hai chữ số: không đệm thì "2024-W1" và "2024-W10"
/// sắp xếp lẫn lộn, và ai đọc cột `dedupeKey` bằng mắt cũng phải đoán.
String khoaTuan(DateTime d) {
  final t = tuanISO(d);
  return '${t.nam}-W${t.tuan.toString().padLeft(2, '0')}';
}

/// Tuần **đã khép lại** ngay trước tuần chứa [now], biên `[from, to)`.
///
/// Biên `to` là **mở**, cùng quy ước với mọi phép cắt khoảng khác trong app
/// (`getExpenses`, `tongThuChi`): lấy Chủ nhật 23:59:59 thì một khoản ghi lúc
/// 23:59:59.5 rơi ra ngoài mọi tuần.
///
/// Đứng ở Chủ nhật vẫn trả về tuần trước đó, vì Chủ nhật còn nằm **trong** tuần
/// hiện tại — tổng kết một tuần chưa kết thúc là nói về việc chưa xảy ra xong.
({DateTime from, DateTime to}) tuanTruoc(DateTime now) {
  final homNay = _ngayGon(now);
  final thuHaiTuanNay = homNay.subtract(Duration(days: _thuISO(homNay) - 1));
  return (
    from: thuHaiTuanNay.subtract(const Duration(days: 7)),
    to: thuHaiTuanNay,
  );
}
