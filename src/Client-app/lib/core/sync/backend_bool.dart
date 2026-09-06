/// Đọc một giá trị đúng/sai từ JSON của backend.
///
/// ## Vì sao cần hàm này
///
/// Backend **không nhất quán** ở chỗ tuần tự hoá boolean, ngay trong cùng một
/// bảng `goal`:
///
/// - `Status_complete` là `VarChar(20)` mặc định `"False"` — một **chuỗi**.
/// - `Recurrence` là `Boolean` — boolean **thật**.
///
/// Nhánh kéo về từng so khớp cứng từng kiểu: `g['status_complete'] == 'True'`
/// và `g['recurrence'] == true`. Cả hai đều đúng với dữ liệu hôm nay và cả hai
/// đều hỏng **trong im lặng** nếu phía kia đổi cách gửi: không exception,
/// không log, chỉ là một mục tiêu bỗng dưng "chưa hoàn thành" hoặc mất cờ lặp
/// lại. Đúng loại hỏng mà quy tắc 4 trong `CLAUDE.md` cảnh báo.
///
/// ## Ranh giới: nới ở chỗ ĐỌC, không nới ở chỗ ghi
///
/// Hàm này chỉ dùng cho nhánh **kéo về**. Payload đẩy vẫn gửi đúng một dạng —
/// nới lỏng cả hai đầu là mất luôn khả năng phát hiện khi hai phía lệch nhau.
///
/// Chỉ nhận bốn dạng đã biết: boolean thật, chuỗi `"true"` (không phân biệt hoa
/// thường, bỏ qua khoảng trắng thừa), số `1`, và chuỗi `"1"`. **Không** đoán
/// thêm `"yes"`/`"y"`/`"on"` — mỗi dạng đoán thêm là một chỗ để giá trị rác trở
/// thành "đã hoàn thành", trong khi backend chưa từng gửi chúng.
///
/// Mọi thứ khác — kể cả `null` và kiểu lạ — là `false`. Ném ở đây là để một bản
/// ghi hỏng giết cả lượt kéo về.
bool doiSangBool(dynamic giaTri) {
  if (giaTri is bool) return giaTri;
  if (giaTri is num) return giaTri == 1;
  if (giaTri is String) {
    final gon = giaTri.trim().toLowerCase();
    return gon == 'true' || gon == '1';
  }
  return false;
}
