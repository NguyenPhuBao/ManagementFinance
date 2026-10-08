# `Server_update_at` đang chứa HAI đồng hồ lệch nhau 7 giờ (mục 40)

> **TRẠNG THÁI (2026-10-07):** ✅ **ĐÃ XỬ LÝ XONG 100% BẰNG MIGRATION 21.**  
> - Đã sửa Trigger function `set_server_update_at()` trả về `(now() AT TIME ZONE 'UTC')`.  
> - Đã sửa `DEFAULT` của 6 cột `Server_update_at` trên 6 bảng đồng bộ thành `(now() AT TIME ZONE 'UTC')`.  
> - Đã cập nhật file `database/20_add_server_update_at_sync_tables.sql` và tạo `database/21_fix_server_update_at_utc.sql`.  
> - Đã thực thi trực tiếp trên CSDL Cloud Supabase qua script `src/Backend/scripts/apply_migration_21.js`.  
> - Đã thẩm tra qua script `src/Backend/scripts/verify_utc_clock.js`: Trong môi trường giả lập `timezone = 'Asia/Bangkok'`, độ lệch giữa Trigger `Server_update_at` và `(now() AT TIME ZONE 'UTC')` là **0 ms** (triệt tiêu hoàn toàn độ lệch 7 giờ).  
> - Toàn bộ 246/246 tests của Backend PASS 100%.

**Người viết:** Client-app · **Ngày:** 2026-10-07 · **Mức:** cao — **chặn** việc client chuyển mốc kéo về sang giờ
server, tức chặn việc đóng G67 / mục 37.
**Xin Backend:** cho mọi đường ghi `Server_update_at` dùng **cùng một** đồng hồ (UTC, như mọi cột `timestamp(6)` khác
mà Prisma đọc/ghi). Không đổi LWW, không đổi payload.

---

## 1. Hiện tượng (đo thật trên CSDL dev, 2026-10-07)

CSDL dev `localhost/PersonFinance` vừa áp `database/20` (một giao tác, sáu bảng, đủ cột · chỉ mục · trigger), mã backend
`main` @ `1edab22`, `prisma generate` theo `schema.prisma` hiện tại. Mọi phép thử dưới đây chạy trong giao tác rồi
**ROLLBACK** — không để lại dữ liệu.

| Đo | Kết quả |
|---|---|
| `current_setting('TimeZone')` | **`Asia/Bangkok`** (+07) |
| `now()` / `now() AT TIME ZONE 'UTC'` / `CURRENT_TIMESTAMP::timestamp` | `18:26:46+07` / `11:26:46` / **`18:26:46`** |
| **INSERT** qua Prisma (`wallet.create`, `server_update_at: new Date()`) | gửi `11:27:04Z` → lưu **`11:27:04`** (UTC, khớp `Update_at`) |
| **UPDATE** qua Prisma (`wallet.update`, `server_update_at: new Date()` — đúng khuôn `sync.repository.js`) | gửi `11:26:46Z` → lưu **`18:26:46`** |

Đường UPDATE bị trigger `set_server_update_at()` (BEFORE UPDATE) ghi đè bằng `CURRENT_TIMESTAMP`. Kiểu cột là
`timestamp` **không múi giờ**, nên `CURRENT_TIMESTAMP` bị đổi sang **giờ phiên** (`Asia/Bangkok`) rồi cắt múi giờ —
trong khi Prisma luôn ghi/đọc cột `timestamp(6)` như **UTC**. Kết quả: cùng một cột, hàng mới chèn mang giờ UTC, hàng
vừa sửa mang giờ **+7 tiếng**.

(Hàng cũ không bị ảnh hưởng: bước 2 của migration chép `Update_at` sang — đo: 507/507 hàng `Server_update_at = Update_at`.)

## 2. Hệ quả

1. **Kéo lại thừa trong 7 tiếng.** Mọi bản ghi được sửa (đẩy lại, xoá mềm, LWW thắng) có `Server_update_at` nằm
   "ở tương lai" 7 tiếng so với mốc `since` của máy, nên `/sync/pull` trả lại nó ở **mọi** chu kỳ trong 7 tiếng.
   Không mất dữ liệu, chỉ tốn băng thông — đây là hiện trạng với client hiện nay.
2. **`orderBy server_update_at` + `maxSince = hàng cuối` sai thứ tự** khi hàng chèn và hàng sửa nằm trên hai đồng hồ:
   một hàng sửa lúc 10:00 xếp **sau** hàng chèn lúc 16:00.
3. **Mất dữ liệu ngay khi client dùng `maxSince`.** Mục 37 sinh ra để client lấy mốc kéo về theo giờ server. Nếu client
   lấy `maxSince` hôm nay, mốc sẽ là một giá trị +7 tiếng (bị kẹp về giờ máy). Mọi hàng **chèn** (giờ UTC) tới server
   trong khoảng ấy nằm dưới mốc, và **không bao giờ** được kéo về. Đó đúng là G67, chỉ khác nguyên nhân.

Vì hệ quả 3, client **chưa** đổi mốc kéo về (xem mục 4).

## 3. Cách sửa — Backend đã chọn Phương án (a)

Đã thi hành **Phương án (a)** thông qua Migration 21:
- Trong trigger function `set_server_update_at()` đổi thành: `NEW."Server_update_at" = (now() AT TIME ZONE 'UTC');`.
- Đổi `DEFAULT` của 6 cột sang `(now() AT TIME ZONE 'UTC')`.
- Quét và sửa dữ liệu nếu có bản ghi > `now() AT TIME ZONE 'UTC'`.
- Kết quả: Toàn bộ luồng ghi (Prisma INSERT/UPDATE, Trigger UPDATE, và DEFAULT INSERT) đều dùng chung đồng hồ UTC 100%, không phụ thuộc vào múi giờ của phiên kết nối (`Asia/Bangkok` hay `UTC`).

## 4. Kiểm lại thực tế

Đo đạc thực tế bằng script `src/Backend/scripts/verify_utc_clock.js` trên kết nối `Asia/Bangkok`:
```
📌 Múi giờ phiên hiện tại: Asia/Bangkok
⏱️ Giá trị Server_update_at qua Trigger: 2026-10-07 13:14:23.739919
⏱️ Giá trị (now() AT TIME ZONE 'UTC'):   2026-10-07 13:14:23.739919
📊 Độ lệch tuyệt đối: 0 ms
✅ XÁC NHẬN: Trigger đã ghi đúng UTC! Không còn lệch 7 giờ (+25,200,000 ms)!

⏱️ Giá trị DEFAULT Server_update_at: 2026-10-07 13:14:24.005742
⏱️ Giá trị (now() AT TIME ZONE 'UTC'):  2026-10-07 13:14:24.005742
📊 Độ lệch DEFAULT: 0 ms
✅ XÁC NHẬN: DEFAULT đã ghi đúng UTC!
```

## 5. Phản hồi cho Client-app

> **Phản hồi câu hỏi mục 5:**  
> *"Một câu hỏi có mặc định: maxSince trả theo từng entity. Client dự định giữ một mốc bằng giá trị nhỏ nhất trong các entity có dữ liệu (an toàn, cùng lắm kéo lại một ít). Nếu backend muốn client giữ mốc riêng từng entity, xin ghi rõ."*
>
> 👉 **Backend xác nhận:** **Client giữ 1 mốc bằng giá trị nhỏ nhất `min(maxSince)` trong các entity có dữ liệu là HOÀN TOÀN CHUẨN XÁC VÀ AN TOÀN NHẤT.**  
> Lý do: Tuyến API `GET /api/sync/pull` hiện nhận query parameter `since` duy nhất cho toàn bộ request. Do đó, việc Client chọn mốc nhỏ nhất (`min`) sẽ đảm bảo không có bất kỳ entity nào bị lọt bản ghi khi kéo delta. Client có thể tiến hành chuyển mốc kéo về sang `maxSince` theo kế hoạch.
