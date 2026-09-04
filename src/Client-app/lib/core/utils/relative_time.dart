/// Mô tả một mốc thời gian theo lối nói tự nhiên: "10 phút trước", "Hôm qua".
///
/// [now] tiêm được để test không phụ thuộc đồng hồ máy.
///
/// ## Vì sao so theo NGÀY LỊCH chứ không theo hiệu số
///
/// 23:59 hôm qua nhìn từ 00:01 hôm nay chỉ cách hai phút. Trả "2 phút trước"
/// cho một việc xảy ra *hôm qua* là đọc sai — người dùng nghĩ theo ngày, không
/// theo hiệu số. Vì vậy nhánh "Hôm qua" được quyết bằng phép so ngày, và chỉ
/// những mốc **cùng ngày** mới rơi vào nhánh phút/giờ.
String relativeTimeVi(DateTime when, {DateTime? now}) {
  final bayGio = now ?? DateTime.now();

  // Mốc ở tương lai: lệch đồng hồ giữa máy và server là chuyện có thật, và
  // "-3 giờ trước" là thứ không ai đọc được.
  if (!when.isBefore(bayGio)) return 'Vừa xong';

  final homNay = DateTime(bayGio.year, bayGio.month, bayGio.day);
  final ngayCuaMoc = DateTime(when.year, when.month, when.day);
  final soNgay = homNay.difference(ngayCuaMoc).inDays;

  if (soNgay >= 2) {
    return '${_hai(when.day)}/${_hai(when.month)}/${when.year}';
  }
  if (soNgay == 1) return 'Hôm qua';

  // Cùng ngày.
  final phut = bayGio.difference(when).inMinutes;
  if (phut < 1) return 'Vừa xong';
  if (phut < 60) return '$phut phút trước';
  return '${bayGio.difference(when).inHours} giờ trước';
}

String _hai(int v) => v.toString().padLeft(2, '0');
