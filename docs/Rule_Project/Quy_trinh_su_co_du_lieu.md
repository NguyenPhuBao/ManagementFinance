# Quy trình xử lý sự cố dữ liệu cá nhân (thông báo trong 72 giờ)

Căn cứ: Luật Bảo vệ dữ liệu cá nhân 2025 (91/2025/QH15) Điều 23; Nghị định 356/2025/NĐ-CP; Nghị định 330/2026/NĐ-CP (không thông báo cơ quan chuyên trách: phạt 20–40 triệu đồng). Mức xác minh: `Khao_sat_phap_ly_2026-11.md`. Ngày lập: 2026-11-13.

## 1. Thế nào là sự cố phải xử lý theo quy trình này

Mọi trường hợp dữ liệu cá nhân bị truy cập, sửa, xóa, sao chép, tiết lộ trái phép, hoặc bị mất, có thể gây tổn hại tới an ninh, trật tự hoặc tính mạng, sức khỏe, danh dự, tài sản của người dùng. Ví dụ trong FlowMoney:
- Lộ CSDL, bản sao lưu, khóa `DATA_ENCRYPTION_KEY` / `BLIND_INDEX_SECRET` / `JWT_*`.
- Tài khoản admin bị chiếm, có lượt "Xem IP đầy đủ" hoặc xuất dữ liệu không do admin thực hiện.
- AIOps phát hiện tấn công thành công vào API dữ liệu người dùng (không chỉ dò quét bị chặn).
- Bên xử lý (nhà cung cấp hạ tầng, dịch vụ AI, email, thanh toán) báo lộ dữ liệu của FlowMoney.

## 2. Mốc thời gian

| Mốc | Việc | Ai |
|---|---|---|
| T0 | Thời điểm **phát hiện** (không phải thời điểm xảy ra). Ghi ngay vào sổ sự cố: T0, người phát hiện, nguồn (AIOps, nhật ký, người dùng báo, bên xử lý báo) | Người phát hiện |
| T0 → T0 + 4 giờ | Ngăn chặn: thu hồi phiên (`refreshtoken`), khóa tài khoản liên quan, cách ly IP qua AIOps, xoay khóa / mật khẩu bị lộ, bật bảo trì khẩn cấp nếu cần | Quản trị hệ thống |
| T0 → T0 + 24 giờ | Đánh giá: loại dữ liệu (cơ bản / nhạy cảm, theo `Data_Security.md` mục 2), số người dùng bị ảnh hưởng (truy vấn CSDL), khả năng tổn hại, nguyên nhân sơ bộ | Chủ dự án + quản trị hệ thống |
| **≤ T0 + 72 giờ** | **Thông báo cơ quan chuyên trách bảo vệ dữ liệu cá nhân** (Bộ Công an; tên đơn vị tiếp nhận và cổng gửi: cần xác minh theo văn bản hướng dẫn Luật 91/2025) nếu sự cố có thể gây tổn hại | Chủ dự án |
| Sau khi đánh giá | Thông báo người dùng bị ảnh hưởng khi dữ liệu nhạy cảm (tài chính, lịch sử truy cập) bị lộ: thông báo trong app + email, nêu dữ liệu nào, việc người dùng nên làm (đổi mật khẩu…) | Chủ dự án |
| Sau sự cố | Ghi biên bản: nguyên nhân gốc, biện pháp khắc phục, test hồi quy, cập nhật tài liệu | Quản trị hệ thống |

## 3. Nội dung thông báo cơ quan chuyên trách (tối thiểu)

1. Mô tả sự cố: thời điểm xảy ra (nếu biết), thời điểm phát hiện, cách phát hiện.
2. Loại dữ liệu, số lượng người dùng và bản ghi bị ảnh hưởng.
3. Hậu quả có thể xảy ra.
4. Biện pháp đã và sẽ thực hiện.
5. Đầu mối liên hệ.
Nếu chưa đủ thông tin trước hạn 72 giờ: gửi thông báo ban đầu, bổ sung sau. Nộp muộn phải ghi lý do.

## 4. Công cụ trong hệ thống

- Nhật ký kiểm toán (Admin-web → Nhật ký) và lịch sử AIOps (sự cố, cách ly, điều tra) để dựng lại diễn biến.
- Lượt "Xem IP đầy đủ" đều có trong nhật ký (`Xem IP đầy đủ (người dùng #…, thiết bị #…)`), dùng để phát hiện truy cập bất thường vào dữ liệu nhạy cảm.
- Màn hình "Sự cố dữ liệu" có đồng hồ 72 giờ ở Admin-web: kế hoạch T4, chưa có. Trong lúc chờ, ghi sổ sự cố bằng tài liệu này.

## 5. Sổ sự cố

| Mã | T0 | Mô tả | Dữ liệu / số người | Đã báo cơ quan (giờ) | Đã báo người dùng | Đóng |
|---|---|---|---|---|---|---|
| (chưa có) | | | | | | |
