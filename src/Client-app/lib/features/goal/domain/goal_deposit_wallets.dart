/// Ví nguồn mặc định cho phiếu nạp tiền vào mục tiêu.
///
/// Ví **nhận** không nằm trong phép chọn này: nó là thuộc tính cố định của mục
/// tiêu, chọn một lần lúc tạo và chỉ đổi qua "Đổi ví nhận". Phiếu nạp vì thế chỉ
/// còn một ô chọn.
///
/// ## Vì sao ví nguồn không được trùng ví nhận
///
/// Chuyển tiền từ một ví sang chính nó không đổi số dư nào, nhưng tiến độ mục
/// tiêu vẫn tăng — mục tiêu tự đầy lên từ hư không. `depositToGoal` cũng chặn
/// cặp này bằng [ArgumentError]; hàm ở đây là lớp chặn phía giao diện, để người
/// dùng không bao giờ nhìn thấy lựa chọn sai.
///
/// Trả `null` khi **không có ví nguồn nào dùng được** — tài khoản chỉ có đúng
/// một ví và nó đang là ví nhận, hoặc chưa có ví nào. Nơi gọi phải chặn phiếu
/// lại kèm lời nhắc tạo thêm ví, chứ không mở phiếu rồi để nút xác nhận nổ.
String? viNguonMacDinh({
  required List<String> viCoSan,
  required String? viNhan,
}) {
  for (final vi in viCoSan) {
    if (vi != viNhan) return vi;
  }
  return null;
}
