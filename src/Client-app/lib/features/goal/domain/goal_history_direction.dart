/// Tiền tố ghi chú của khoản **nạp** vào mục tiêu.
const String kGhiChuNapMucTieu = 'Tích lũy mục tiêu: ';

/// Tiền tố ghi chú của khoản **rút** khỏi mục tiêu.
const String kGhiChuRutMucTieu = 'Rút từ mục tiêu: ';

/// Một hàng trong lịch sử mục tiêu là khoản **rút ra** hay khoản **nạp vào**.
///
/// Cả hai đều là giao dịch `'transfer'` mang cùng một `goal_id`, nên `type`
/// không phân biệt được.
///
/// ## Vì sao đọc ghi chú chứ không đọc vị trí ví
///
/// Cách hiển nhiên hơn là so ví: nạp thì ví tích lũy là ĐÍCH, rút thì nó là
/// NGUỒN. Cách ấy **sai với dữ liệu lịch sử**, vì nó diễn giải hàng cũ bằng cấu
/// hình **hiện tại** của mục tiêu. Đổi ví tích lũy một lần là mọi khoản nạp
/// trước đó có thể bỗng đọc thành khoản rút — đã gặp trên máy ảo ngày
/// 2026-09-05: một mục tiêu đổi ví xong thì cả hai dòng lịch sử đều hiện dấu
/// trừ, kể cả dòng người dùng thật sự đã gửi vào.
///
/// Tiền tố ghi chú thì do **chính app sinh ra** lúc ghi hàng, nằm luôn trong
/// hàng, đi qua được đồng bộ, và không đổi khi cấu hình mục tiêu đổi. Đây khác
/// hẳn với việc so **tên mục tiêu** trong ghi chú — thứ mà cột `goal_id` sinh ra
/// để thay thế: tên là dữ liệu người dùng đặt và không duy nhất, còn hai tiền tố
/// dưới đây là hằng số của mã nguồn, dùng chung cho cả nơi ghi lẫn nơi đọc.
///
/// Vị trí ví vẫn được dùng làm **phương án dự phòng** cho hàng không mang tiền
/// tố nào nhận ra được.
///
/// Vì sao đáng có hàm riêng: bỏ phép phân biệt này thì khoản rút hiện lên màn
/// hình giống hệt khoản nạp — cùng dấu `+`, cùng màu xanh — trong khi tiến độ
/// mục tiêu lại giảm. Người dùng thấy hai thứ nói ngược nhau trên cùng màn hình.
bool laKhoanRutKhoiMucTieu({
  required String ghiChu,
  required String viCuaHang,
  required String? viTichLuy,
}) {
  if (ghiChu.startsWith(kGhiChuRutMucTieu)) return true;
  if (ghiChu.startsWith(kGhiChuNapMucTieu)) return false;

  // Hàng lạ — không do luồng mục tiêu sinh ra, hoặc ghi chú đã bị sửa. Lúc này
  // vị trí ví là căn cứ duy nhất còn lại.
  if (viTichLuy == null || viTichLuy.isEmpty) return false;
  return viCuaHang == viTichLuy;
}

/// Hậu tố ghi chú của khoản nạp do **bộ trích tự động** ghi.
///
/// ## Vì sao là HẬU TỐ chứ không phải một tiền tố riêng
///
/// Khoản trích tự động và khoản nạp tay cố ý giống hệt nhau trên mọi cột (mục
/// 3.12 `GOAL_FEATURE.md`), và sự giống nhau ấy là thứ cho `laKhoanRutKhoiMucTieu`
/// ở trên đọc đúng chiều tiền cho cả hai bằng **một** tiền tố. Một tiền tố riêng
/// cho khoản tự động sẽ rơi khỏi cả hai nhánh `startsWith` và bị đọc chiều bằng
/// vị trí ví — đúng cái bẫy vừa gỡ. Hậu tố thì không đụng gì tới đầu chuỗi.
///
/// Ba đường khác đã bị loại, đừng dựng lại:
/// - **Suy từ `date != updatedAt`**: sai im lặng — `updateTransaction` bump
///   `updatedAt`, nên khoản nạp tay bị sửa về sau sẽ đọc thành tự động.
/// - **Một cột cục bộ trên `transactions`**: hàng kéo về từ server luôn trống,
///   nên máy thứ hai thấy mọi khoản là "tay" (cùng bệnh với bẫy 4.4 và G21).
/// - **Đổi tiền tố**: đâm thẳng vào bẫy 4.2.
///
/// Hạn chế phải nói ra: ghi chú **sửa được** (`updateTransaction`), nên nhãn có
/// thể mất. Mất thì đọc thành "tay" — rơi về mặc định an toàn, không phải về
/// một lời khẳng định sai.
const String kHauToTuDong = ' (tự động)';

/// Khoản nạp này do app tự chuyển tiền, hay do người dùng tự bấm?
///
/// Đòi **đủ cặp** tiền tố + hậu tố, không chỉ hậu tố. Ghi chú là dữ liệu sửa
/// được: người dùng gõ tay đúng ba chữ ấy vào một giao dịch bất kỳ không biến
/// nó thành khoản do app tự chuyển. Chỉ `GoalAutoDepositRunner` ghi ra đủ cặp.
///
/// Khoản **rút** không bao giờ tự động — không có đường nào trong app tự rút
/// tiền khỏi mục tiêu — nên tiền tố rút không được nhận ở đây.
///
/// Khoản ghi trước đợt này không có hậu tố nên đọc là **tay**. Đó là chủ ý:
/// đoán ngược cho lịch sử cũ là bịa ra một sự thật chưa từng được ghi lại. Nhãn
/// tự lành từ kỳ trích kế tiếp.
bool laKhoanTuDong(String ghiChu) =>
    ghiChu.startsWith(kGhiChuNapMucTieu) && ghiChu.endsWith(kHauToTuDong);

/// Ghi chú đã bỏ hậu tố, cho nơi nào hiện ghi chú **thô** làm tiêu đề dòng.
///
/// Trang chi tiết mục tiêu là một nơi như thế. Không cắt thì dòng ấy mang chữ
/// "(tự động)" hai lần — một trong tiêu đề, một trong chip — trong khi bảng
/// đầy đủ chỉ có chip.
///
/// Hai điều khiến nó không phải một `replaceAll`:
/// - Chỉ cắt khi [laKhoanTuDong] nhận. Chỗ nào không dán nhãn thì chỗ ấy cũng
///   không được xoá chữ, nếu không ba chữ người dùng tự gõ biến mất khỏi màn
///   hình mà không có gì thay thế.
/// - Cắt **đúng một lần, ở cuối**. Người dùng đặt tên mục tiêu là "Quỹ (tự
///   động)" thì `replaceAll` ăn luôn vào tên họ đặt.
String ghiChuKhongHauTo(String ghiChu) => laKhoanTuDong(ghiChu)
    ? ghiChu.substring(0, ghiChu.length - kHauToTuDong.length)
    : ghiChu;
