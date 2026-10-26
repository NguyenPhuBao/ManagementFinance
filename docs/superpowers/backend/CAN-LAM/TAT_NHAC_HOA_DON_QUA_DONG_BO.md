# `/sync/push` ép `time_notification = NULL` của hoá đơn thành `'3'` (tạo mới) hoặc giữ giá trị cũ (cập nhật) — "tắt nhắc" của người dùng bị đảo lại sau một vòng đồng bộ (mục 45)

> 🔎 **Client soát lại 2026-10-26** (mã `main` @ `5bb258ff`): **chưa làm.** Đơn đã nằm trong lịch sử nhánh backend từ
> 2026-10-16; sau đó `sync.repository.js` được sửa hai lần (`2375e5db`, `36f1ea43`) mà không chạm ba chỗ này. Số dòng nay:
> **:117** `String(m.timeNotification)` · **:528** `|| '3'` · **:554** `?? existing.time_notification`. Các trường kề bên
> (`period_end`, `auto_pay`) đã dùng `!== undefined` — đúng khuôn đơn xin. CSDL Supabase của `.env` nay chỉ còn 1 hoá đơn sống
> nên phép đo dữ liệu của đơn (đo trên CSDL dev hôm 2026-10-16) không lặp lại được ở đó.

**Ngày:** 2026-10-16 · **Phía gửi:** Client-app · **Nhánh:** `TranQuangDat`
**Loại:** đơn xin — **một lỗi mức vừa**, sửa trong `src/Backend/modules/sync/sync.repository.js`. **Không** đổi lược đồ,
**không** đổi hình dạng payload `/sync/*`, **không** cần migration. Mọi khẳng định dưới đây đo bằng **đọc mã** (HEAD
`TranQuangDat`, tệp đổi lần cuối ở `2280efb1`) và **truy vấn chỉ đọc** trên CSDL dev ngày 2026-10-16. Client không chạy
backend, không sửa `src/Backend`.

## Vì sao client gửi đơn này

Ở client, cột hoá đơn `timeNotification` = **NULL nghĩa là người dùng TẮT nhắc trước hạn**: form Thêm hoá đơn ghi NULL khi
tắt công tắc "Nhắc trước hạn", form Sửa có lựa chọn "Không nhắc" = NULL, màn Chi tiết hiện "Không nhắc". Ngày 2026-10-16
người dùng chốt **"tắt là tắt thật"** — client nay không gửi thông báo "sắp đến hạn" và không đặt lịch nhắc hệ điều hành
cho hoá đơn mang NULL (commit `d657b065`). Nhưng giá trị NULL ấy **không sống được qua một vòng đồng bộ**, nên trên mọi
tài khoản có mạng, hoá đơn vừa tắt nhắc trở lại "nhắc trước 3 ngày" (hoặc số cũ) ở chu kỳ đồng bộ đầu tiên.

## Hiện tượng (đọc mã `sync.repository.js`)

Client đẩy khoá snake_case `'time_notification': null` (`core/sync/thu_gom_day.dart`, `collectPendingOps` — trước 2026-10-19 là `sync_engine.dart` ~:1475; payload hoá đơn 21 trường,
`sync_payload_contract_test.dart` khoá tên).

| Dòng | Nhánh | Mã hiện tại | Kết quả với `null` |
|---|---|---|---|
| ~:471 | **tạo** hoá đơn | `time_notification: mapped.time_notification \|\| '3'` | `null \|\| '3'` → **`'3'`** |
| ~:497 | **cập nhật** hoá đơn | `time_notification: mapped.time_notification ?? existing.time_notification` | `null ?? cũ` → **giữ giá trị cũ** |
| ~:98 | đổi camelCase → snake | `if (m.timeNotification !== undefined) { m.time_notification = String(m.timeNotification); … }` | client không gửi camelCase nên chưa chạm; nếu có ai gửi `timeNotification: null` thì thành **chuỗi `"null"`** |

Cả hai nhánh đặt `server_update_at: new Date()`, nên `/sync/pull` trả hàng ấy về ngay chu kỳ sau. Client ghi đè cột
(`BillDao.upsertAll`; nhánh kéo về đọc `bill['time_notification']`) → hoá đơn mang `'3'` (hoặc số cũ) trên máy → lời nhắc
quay lại, màn Chi tiết hiện "3 ngày".

**Đo CSDL dev 2026-10-16 (chỉ đọc):** 37 hoá đơn sống — `Time_notification = '3'` × 32, `'7'` × 5, **NULL × 0**. Con số
0 là **hệ quả** của phép ép trên (mọi lần tạo có NULL đều thành `'3'`), không phải bằng chứng chưa ai tắt nhắc.

Ba nhánh kề ngay bên dưới ở cùng hàm (`period_end`, `auto_pay`, `anchor_day`, `previous_bill_id`) đã dùng đúng khuôn
`!== undefined ? … : existing.…` — tức backend đã có quy ước *"vắng mặt = giữ nguyên, có mặt kể cả NULL = ghi"*; chỉ
`time_notification` còn dùng `||` / `??`.

## Xin làm

1. **~:471 (tạo):** `time_notification: mapped.time_notification !== undefined ? mapped.time_notification : '3'` — vắng khoá
   (client cũ / Admin-web không gửi) vẫn mặc định `'3'` như `@default("3")`; có khoá với NULL thì ghi NULL.
2. **~:497 (cập nhật):** `time_notification: mapped.time_notification !== undefined ? mapped.time_notification : existing.time_notification`
   — cùng khuôn `period_end` / `auto_pay` ngay dưới.
3. **~:98:** giữ NULL khi đổi tên: `m.time_notification = m.timeNotification === null ? null : String(m.timeNotification);`.

Không đổi gì ở `/sync/pull`: `findMany` luôn trả cột này, và NULL từ server đúng nghĩa là tắt nhắc ở client.

## Kiểm lại

- Đẩy một hoá đơn **mới** với `time_notification: null` → `SELECT "Time_notification" FROM bill WHERE "Idbill" = '<id>'` phải
  là `NULL` (hôm nay: `'3'`).
- Đẩy **cập nhật** (`update_at` mới hơn) một hoá đơn đang `'3'` với `time_notification: null` → cột thành `NULL` (hôm nay: giữ
  `'3'`).
- Đẩy cập nhật **không có khoá** `time_notification` → cột giữ nguyên (đường của client cũ / Admin-web).
- Sau khi sửa, phía client: tạo hoá đơn tắt nhắc trên máy A, chờ một chu kỳ đồng bộ → màn Chi tiết trên A và trên máy B
  cùng hiện "Không nhắc", không có thông báo "sắp đến hạn" (client đã làm phần của mình ở `d657b065`).

## Không chặn client

Client không đổi mã thêm vì đơn này. Tới khi backend sửa, tài liệu client ghi rõ giới hạn: *tắt nhắc chỉ giữ được trên
máy chưa đồng bộ hàng ấy* (mục 7b `docs/bill/BILL_DOCUMENTATION.md`, khối 🔕 mục 14 `docs/PROJECT_CONTEXT.md`).
