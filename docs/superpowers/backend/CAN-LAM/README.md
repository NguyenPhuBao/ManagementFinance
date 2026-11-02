# Backend — việc cần làm

**Đọc và làm theo:** [`VIEC_BACKEND_CON_LAI.md`](./VIEC_BACKEND_CON_LAI.md). Đây là tệp việc duy nhất, chỉ có việc còn phải làm.

| Tệp | Là gì |
|---|---|
| `VIEC_BACKEND_CON_LAI.md` | 8 việc còn mở (3 mức CAO, 4 việc đi cùng nhánh gia đình), các bước làm, bảng trả lời |
| `KIEM-THU/ban_sua_66.patch` | Bản vá đã thử cho 66.1, 66.2, 66.3 (7 tệp) |
| `KIEM-THU/chay_kiem_66.js` | Kịch bản 9 ca của đơn 66, không cần CSDL: 3 / 9 trước khi vá, 9 / 9 sau khi vá |
| `KIEM-THU/chay_kiem_61.js` | Kịch bản 6 ca, không cần CSDL, đang đạt 6 / 6 |
| `KIEM-THU/chay_kiem_62.js` | Kịch bản 14 ca, không cần CSDL, đang đạt 14 / 14 |
| `KIEM-THU/webhook_tu_ky.js` | Gửi webhook PayOS tự ký vào backend dev, không có giao dịch ngân hàng |
| `KIEM-THU/chay_kiem_gia_dinh_2.js` | Kịch bản 32 ca của gia đình đợt 1A, 1B, 2; cần CSDL thử có `database/45`, `46` |
| `KIEM-THU/chay_kiem_pr174.js` | Kịch bản 24 ca, đang đạt 24 / 24 |
| `KIEM-THU/chay_kiem.js` | Kịch bản 50 ca của gia đình phần 1, đang đạt 50 / 50 (`npm run verify:household`) |
| `CLIENT_INTEGRATION_GUIDE.md` | Hướng dẫn PayOS của backend, không phải đơn việc |
| `LICH-SU/` | Tệp đơn gốc, không cập nhật |

Việc đã xong không ghi ở đây. Muốn xem thì dùng git và [`../DA-XONG/`](../DA-XONG/README.md).

Client-app **không sửa `src/Backend`**: mọi việc cần backend đều viết thành tài liệu ở đây. Nếu một việc đọc thấy vô lý hoặc tốn hơn dự kiến, hãy ghi lý do vào bảng trả lời, client sẽ đọc và tìm đường vòng ở phía mình.
