# `Server_update_at` đang chứa HAI đồng hồ lệch nhau 7 giờ (mục 40)

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

## 3. Cách sửa — Backend chọn

Chỉ cần mọi đường ghi cho ra **cùng một** đồng hồ UTC. Ba lối, lối nào cũng được:

- **(a) Sửa trigger** (nhỏ nhất): trong `set_server_update_at()` đổi thành
  `NEW."Server_update_at" = (now() AT TIME ZONE 'UTC');`. Nên đổi luôn `DEFAULT` của sáu cột thành
  `(now() AT TIME ZONE 'UTC')`, vì đường nào bỏ trống cột cũng sẽ rơi vào `DEFAULT CURRENT_TIMESTAMP`, tức giờ phiên.
- **(b) Đặt múi giờ phiên là UTC** (`ALTER DATABASE … SET timezone = 'UTC'`, hoặc `options=-c timezone=UTC` trong chuỗi
  kết nối). ⚠️ Lối này đổi kết quả của **mọi** `now()` / `CURRENT_TIMESTAMP` khác đang dùng trong SQL tay
  (AIOps, `database/*.sql`, báo cáo), nên phải soát những chỗ ấy.
- **(c) Đổi cột sang `timestamptz`**. Lối này đúng nhất về nghĩa, nhưng phải sửa `schema.prisma` (`@db.Timestamptz(6)`)
  và chạy `generate`.

Hàng đã bị ghi `+7h` trong khoảng từ khi áp `database/20` tới khi sửa: trên CSDL dev chưa có hàng nào (backend dev chưa
chạy lại sau khi áp). Môi trường khác đã áp 20 và chạy thì cần kéo lùi, ví dụ
`UPDATE … SET "Server_update_at" = "Server_update_at" - interval '7 hours' WHERE "Server_update_at" > now() AT TIME ZONE 'UTC'`
(chạy **trước** khi bật trigger mới, hoặc tạm tắt trigger, vì UPDATE này cũng kích trigger).

## 4. Kiểm lại

```sql
BEGIN;
UPDATE "wallet" SET "Update_at" = "Update_at" WHERE "Idwallet" = (SELECT "Idwallet" FROM "wallet" LIMIT 1)
  RETURNING "Server_update_at"::text AS server, (now() AT TIME ZONE 'UTC')::text AS utc_now;
ROLLBACK;
```
`server` và `utc_now` phải lệch nhau **vài mili giây**, không phải 7 tiếng. Rồi chạy lại một phép `wallet.create` qua
Prisma trong giao tác ROLLBACK: `Server_update_at` phải bằng giá trị gửi lên (UTC).

## 5. Sau khi Backend sửa — việc của client (không xin backend)

Client hiện vẫn lấy mốc kéo về = `update_at` **lớn nhất trong dữ liệu vừa nhận** (`sync_engine.dart`, đoạn
`_newestUpdateAt`), tức giờ **của máy**. Backend nay lọc theo `Server_update_at`, nên khi đồng hồ một máy chạy nhanh vài
phút, mốc của máy ấy có thể vượt những hàng server chưa giao — vẫn đúng hình G67. Client sẽ đổi mốc sang `maxSince` của
phản hồi `/sync/pull`, kèm test chứng minh mốc lấy từ phản hồi chứ không lấy từ `update_at` của hàng, rồi chạy lại
nghiệm thu hai máy của G63. Việc ấy **chờ** mục này, vì `maxSince` hôm nay có thể mang giá trị +7 tiếng.

Một câu hỏi có mặc định: `maxSince` trả theo **từng entity**. Client dự định giữ **một** mốc bằng giá trị **nhỏ nhất**
trong các entity có dữ liệu (an toàn, cùng lắm kéo lại một ít). Nếu backend muốn client giữ mốc riêng từng entity,
xin ghi rõ.
