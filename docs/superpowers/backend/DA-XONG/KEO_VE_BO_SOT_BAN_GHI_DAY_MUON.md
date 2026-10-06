# Kéo về bỏ sót bản ghi được đẩy MUỘN hơn giờ ghi của nó (mục 37)

**Người viết:** Client-app · **Ngày:** 2026-10-05 · **Mức:** cao (mất dữ liệu trên máy khác, im lặng, không tự lành)
**Xin Backend:** tách *giờ ghi của máy* (dùng cho LWW) khỏi *giờ server nhận bản ghi* (dùng cho kéo về). Không đổi
hành vi LWW, không đổi payload đẩy.

---

## 1. Hiện tượng (đo thật, 2026-10-05)

Nghiệm thu G63 (ví trùng tên giữa hai máy) trên **hai máy ảo cùng tài khoản thử 27** (`thug63`), backend dev nhánh
`TranQuangDat` @ `614634f` (client) / mã backend của `main` @ `b38367e`.

1. Máy B **offline**, ghi hai giao dịch lúc **14:43:31** và **14:43:53** (giờ VN; server lưu `07:43:31Z`, `07:43:53Z`).
2. Máy A kéo về lúc 14:44:27 → mốc kéo về của A = **`07:44:27Z`**.
3. Hai giao dịch của B lên server lúc **14:45:32** — muộn hơn giờ ghi của chúng (B offline / bị giữ trước đó).
4. Máy A hỏi `GET /api/sync/pull?since=2026-10-05T07:44:27Z` → server lọc `update_at > since` → **không bao giờ** trả hai
   giao dịch ấy (giờ của chúng là 07:43, nhỏ hơn mốc).

Kết quả trên máy A: ví *"Vi doi ten (2)"* hiện **0 đ, không có giao dịch nào**, trong khi PostgreSQL có đủ (số dư
199.000 đ). Truy vấn đọc lại để kiểm:

```sql
SELECT "Idtran","Amount","Update_at" FROM transaction WHERE "Idwallet"='17ff436c-7361-4bd5-b93b-39b27c22e8d2';
-- 200000 · 2026-10-05 07:43:31 ;  -1000 · 2026-10-05 07:43:53   (cả hai đều < mốc 07:44:27 của máy A)
```

Máy A **không tự lành**: mốc chỉ tiến, không lùi; chỉ cài lại app (CSDL cục bộ rỗng → kéo toàn bộ) mới nhận được.

## 2. Gốc

`src/Backend/modules/sync/sync.repository.js` dùng **cùng một cột** `update_at` cho hai việc khác nhau:

| Việc | Chỗ | Cần giờ nào |
|---|---|---|
| LWW — bản nào mới hơn thắng | `:186` `if (new Date(mapped.update_at) > new Date(existing.update_at))` (và các nhánh tương tự ở mọi thực thể) | giờ **ghi trên máy** (đúng như hiện nay) |
| Kéo về tăng dần | `:216`, `:285`… `update_at: since ? { gt: new Date(since) } : undefined` | giờ **server nhận** bản ghi |

`update_at` được lấy nguyên từ payload (`m.update_at = new Date(m.updatedAt)`, `:26`, `:48`…), nên mọi bản ghi tới server
**muộn hơn giờ ghi** — máy offline lâu, máy bị chặn bởi giãn cách, bản ghi bị giữ chờ người dùng xử lý — đều có thể rơi
dưới mốc của một máy khác đã kéo trong khoảng ấy. Đây không phải lệch múi giờ: mọi bên đều so theo UTC.

> ⚠️ **Đừng sửa bằng cách ghi `update_at = now()` lúc nhận.** Làm vậy là đổi luật LWW: bản sửa cũ đẩy muộn sẽ **thắng**
> bản sửa mới hơn đã có trên server.

## 3. Đề xuất

1. Thêm một cột **giờ server** cho mọi bảng đồng bộ (`category`, `wallet`, `transaction`, `budget`, `bill`, `goal`), ví
   dụ `Server_update_at timestamp(6) NOT NULL DEFAULT now()`, kèm index `(Idaccount, Server_update_at)`.
2. Mọi lần **ghi** từ `/sync/push` (tạo, cập nhật, xoá mềm — kể cả nhánh LWW thua thì **không** đổi) đặt
   `Server_update_at = now()`. Các đường ghi khác của server (Admin-web, job nền) cũng đặt — nếu không, sửa từ Admin-web
   sẽ không tới máy.
3. `/sync/pull` lọc `Server_update_at > since` thay cho `update_at > since`, sắp theo `Server_update_at`, và trả thêm khoá
   `server_update_at` trên từng hàng. `maxSince` (`sync.service.js:271-274`) đổi sang `Server_update_at`.
4. Giữ nguyên `update_at` trong payload trả về — client vẫn dùng nó cho LWW cục bộ.
5. Migration điền `Server_update_at = update_at` cho hàng cũ (không làm mất gì: hàng cũ vốn đã được kéo theo giá trị ấy).

Theo quy ước `src/Backend/database/N_*.sql` của `docs/Rule_Project/Rule_project.md` §3.2 (tệp kế tiếp sau `18`), kèm
`prisma generate` vì `schema.prisma` đổi.

## 4. Phía client sẽ làm gì (sau khi backend xong)

`SyncEngine._newestUpdateAt` (`src/Client-app/lib/core/sync/sync_engine.dart`) đang lấy mốc = `update_at` lớn nhất trong
dữ liệu vừa kéo. Client sẽ đổi sang `server_update_at` (rơi về `update_at` khi server chưa trả khoá mới — để chạy được với
backend cũ). Client **không** làm trước: đổi một bên là bỏ sót theo kiểu khác.

**Đã làm ở client trong lúc chờ (2026-10-05, `3544cc4`):** riêng ca G63 — ví bị giữ vì trùng tên được thả (Đổi tên, hoặc ví
kia bị xoá ở máy khác) — client làm mới giờ sửa của mọi bản ghi từng bị giữ trước khi đẩy, nên ca ấy không còn dính. Ca
chung (máy offline lâu rồi đẩy muộn) client không chữa được: giờ sửa là dữ liệu LWW của chính bản ghi.

## 5. Câu hỏi (có mặc định)

1. Tên cột — mặc định `Server_update_at`. Backend chọn tên khác thì ghi lại ở đây.
2. Có cần một lần **kéo lại toàn bộ** cho máy đã bỏ sót không? Mặc định: client tự xoá mốc đã lưu một lần khi thấy server
   trả `server_update_at` lần đầu (kéo lại toàn bộ một lượt) — backend không phải làm gì.

## 6. Kiểm lại sau khi sửa

Hai máy cùng tài khoản: máy B offline ghi một giao dịch; máy A sửa một thứ bất kỳ rồi kéo về; máy B online đẩy lên; máy A
kéo về → phải thấy giao dịch của B. Truy vấn: `SELECT "Update_at","Server_update_at" FROM transaction WHERE "Idtran"=…` —
`Server_update_at` phải **sau** `Update_at`.
