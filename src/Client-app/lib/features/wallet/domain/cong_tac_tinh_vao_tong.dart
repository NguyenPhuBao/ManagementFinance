/// Công tắc *"Tính vào tổng tài sản"* (Sửa ví) / *"Tính vào tổng số dư tài sản"* (Thêm ví) có cho đổi không — **định
/// nghĩa duy nhất**, hai màn cùng gọi (B1 quyền `wallet_exclude_total`; I3 người dùng chốt 2026-10-28).
///
/// Quyền chỉ chặn LOẠI MỚI (luật chung của phân quyền theo gói: hạ cấp giữ dữ liệu, chỉ chặn tạo / bật mới). Neo vào giá
/// trị ĐÃ LƯU, không vào giá trị đang chọn trên form: ví đã lưu là "không tính" thì công tắc mở cả hai chiều tới khi Lưu —
/// tắt lại trước khi Lưu chỉ là trả về giá trị cũ, không phải một lần loại mới; neo vào giá trị đang chọn thì bật lại xong là
/// khoá ngay, chạm nhầm không gỡ được. Ví mới (màn Thêm) truyền [daLuuTinhVaoTong] `true`: mọi "không tính" ở đó là loại mới.
///
/// Nhận `bool coQuyen` thay vì đọc gói: tầng domain của ví không phụ thuộc `premium/` (quét 29).
bool doiDuocTinhVaoTong({required bool coQuyen, required bool daLuuTinhVaoTong}) => coQuyen || !daLuuTinhVaoTong;
