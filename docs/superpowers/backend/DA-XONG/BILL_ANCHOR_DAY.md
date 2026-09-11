# Xin một cột: `bill.Anchor_day`

**Trạng thái:** client đã làm xong phần của mình (DB v18, 2026-09-08). Cột đang
là **cục bộ**, nên hoá đơn đi qua đường đồng bộ mất thông tin này. Xin thêm cột
tương ứng phía backend để nâng lên mức đồng bộ — client không phải sửa gì ngoài
việc thêm tên trường vào payload.

---

## 1. Vấn đề

Chuỗi hoá đơn lặp **nối đuôi nhau**: ngày bắt đầu của kỳ sau là ngày đến hạn của
kỳ trước. Nên số ngày người dùng chọn ban đầu **biến mất sau kỳ thứ hai**.

Hệ quả: nhìn vào một hoá đơn đến hạn 28/02, không có cách nào biết nó thuộc
chuỗi nào trong hai chuỗi dưới đây — mà hai chuỗi ấy phải đi tiếp khác nhau:

| Chuỗi | Người dùng chọn | Kỳ kế tiếp phải là |
|---|---|---|
| bắt đầu 31/01 | ngày 31 | **31/03** |
| bắt đầu 28/02 | ngày 28 | **28/03** |

Client trước đây **đoán** bằng quy tắc *"mốc rơi đúng ngày cuối tháng thì kỳ sau
cũng rơi vào ngày cuối tháng"*. Cú đoán ấy sai với người đăng ký lần đầu vào
28/02 — họ muốn ngày 28 và nhận về 31/03, 30/04… Người dùng báo lỗi này ngày
2026-09-08. Nó còn phụ thuộc năm nhuận: 28/02/2026 bị đẩy lên 31/03 còn
28/02/2028 thì không, vì năm nhuận 28/02 không phải cuối tháng — cùng một ngày
người dùng chọn, hai kết quả khác nhau.

Cách sửa là **lưu ngày gốc** thay vì đoán lại. Đây cũng đúng mô hình mà ngân
sách đã dùng từ đầu (`advancePeriodFrom(anchor, steps)` neo vào mốc gốc, không
cộng dồn), nên sau thay đổi này ba vùng ngày tháng của app nói cùng một thứ
tiếng.

## 2. Cột xin thêm

```sql
ALTER TABLE "bill" ADD COLUMN "Anchor_day" SMALLINT
  CHECK ("Anchor_day" IS NULL OR ("Anchor_day" BETWEEN 1 AND 31));
```

- **Kiểu:** số nguyên nhỏ, **nullable**.
- **Ý nghĩa:** ngày trong tháng mà người dùng thật sự chọn khi tạo hoá đơn.
- **NULL nghĩa là gì:** *chưa biết* — hoá đơn tạo bởi bản client cũ hoặc bởi
  Admin-web. Client khi ấy neo vào ngày của mốc hiện tại, tức giữ nguyên hành vi
  cũ. **Đừng đặt mặc định khác NULL**: một giá trị mặc định ở đây là khẳng định
  ý định mà người dùng chưa từng nói.
- **Không cần migration dữ liệu phía server.** Client tự suy cho hàng cũ của
  mình (từ ngày đến hạn đang lưu, để không đổi hạn của hoá đơn nào). Nếu backend
  muốn làm tương tự thì công thức là `EXTRACT(DAY FROM "Due_date")`, và nó phải
  chạy **một lần**, không phải mỗi lần cập nhật.

## 3. Ràng buộc cần giữ

Chỉ một điều: **cột này không bao giờ được server tự tính lại.** Nó là *ý định
của người dùng*, không phải giá trị suy ra từ ngày. Tính lại từ `Due_date` ở mỗi
lần cập nhật sẽ phá đúng thứ nó sinh ra để giữ — hoá đơn ngày 31 sau khi đi qua
tháng Hai có `Due_date` là 28/02, và tính lại sẽ chốt nó ở 28 vĩnh viễn.

## 4. Phía client sẽ làm gì khi có cột

Thêm `anchor_day` vào payload đẩy và nhánh kéo của thực thể `bill`, cập nhật
`sync_payload_contract_test.dart` **cùng lúc** (quy tắc 4 — tên trường sai thì
hỏng im lặng), rồi gỡ ghi chú "cột cục bộ" ở `Bills.anchorDay`.

## 5. Vì sao không dùng RRULE (RFC 5545)

Đã cân nhắc và loại, ghi lại để khỏi bàn lại:

- RFC 5545 **bỏ qua** occurrence rơi vào ngày không tồn tại (*"MUST be ignored
  and MUST NOT be counted as part of the recurrence set"*), nên
  `FREQ=MONTHLY;BYMONTHDAY=31` sẽ **không sinh kỳ nào cho tháng Hai** — hoá đơn
  biến mất. Với lịch hẹn thì chấp nhận được; với hoá đơn tài chính thì không.
- App chỉ có bốn chu kỳ cố định, không cần sức biểu đạt của `BYDAY`/`BYSETPOS`/
  `EXDATE`.
- Đổi `Time_recurrence` sang chuỗi RRULE là sửa hợp đồng đồng bộ ở cả ba phía
  (client, backend, Admin-web) cho một thứ mà một cột số nguyên giải quyết xong.

## 6. Điều cột này KHÔNG giải quyết

Ngày gốc phân biệt được *"ngày 28"* với *"ngày 31"*, nhưng **không** phân biệt
được *"ngày 31"* với *"ngày cuối tháng"*. Thực tế hai ý định này gần trùng nhau —
gốc 31 kẹp lại chính là ngày cuối tháng ở mọi tháng — nên khác biệt chỉ lộ ra với
người muốn "cuối tháng" mà lại đăng ký đúng vào tháng Hai.

Nếu sau này cần chặt hơn, cách đúng là **hỏi thẳng người dùng** bằng một công tắc
trên form (`Is_last_day_of_month BOOLEAN`), chứ không phải đoán lại lần nữa từ dữ
liệu. Chưa xin cột ấy vì chưa có nhu cầu đo được.
