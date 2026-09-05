/// Mốc sớm nhất mà bộ chọn ngày của trang **sửa** mục tiêu được phép hiển thị.
///
/// ## Vì sao cần một hàm riêng
///
/// Trang **tạo** đặt thẳng `firstDate: DateTime.now()` — hợp lý, vì mục tiêu
/// mới thì không có lý do gì đặt hạn định lùi về quá khứ.
///
/// Trang **sửa** thì khác: `initialDate` là hạn định đang có của mục tiêu, và
/// hạn ấy có thể đã trôi qua. `showDatePicker` ném **assertion** khi
/// `initialDate` nằm trước `firstDate`, và assertion ấy là **màn đỏ ngay khi
/// bấm vào ô hạn định**, không phải một thông báo lỗi. Nó rơi trúng đúng những
/// mục tiêu người dùng cần sửa nhất — những cái đã quá hạn.
///
/// Phép so ở mức **ngày**, không ở mức thời điểm: hạn định lưu lúc 8 giờ sáng
/// hôm nay vẫn là hôm nay lúc 14 giờ 30, và so `DateTime` thô sẽ lùi lịch một
/// cách vô cớ. Cùng nguyên tắc với `GoalEntity.daysLeft`.
DateTime ngayNhoNhatChoLich(DateTime hanHienTai, DateTime homNay) {
  final hanTheoNgay = DateTime(hanHienTai.year, hanHienTai.month, hanHienTai.day);
  final homNayTheoNgay = DateTime(homNay.year, homNay.month, homNay.day);
  return hanTheoNgay.isBefore(homNayTheoNgay) ? hanTheoNgay : homNayTheoNgay;
}
