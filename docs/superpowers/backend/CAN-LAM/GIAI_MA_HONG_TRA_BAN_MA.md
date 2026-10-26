# Giải mã AES-256-GCM hỏng thì backend trả NGUYÊN BẢN MÃ cho client — client ghi đè ghi chú bằng `enc:…` (mục 52)

> 🔎 **Client soát lượt báo xong 2026-10-26** (`49eafef6` · `bc4e4f7f` · `2b926d92`, gộp `3636110d`; đọc mã HEAD, CSDL Supabase của `.env` chỉ `SELECT`): **vế `/sync/pull` đóng — chuyển lại `CAN-LAM/` với phạm vi HẸP dưới đây** (đừng làm lại phần đã đạt).
> - **Đạt:** `decrypt()` ném `Error` `code='DECRYPT_FAILED'` (`crypto.util.js:98-100`, `:116-119`); `/sync/pull` (`restoreSafeNote`,
>   `sync.repository.js:12-15`) ⇒ `sync.controller.js:67-74` trả **HTTP 500** `{success:false, code:'DECRYPT_FAILED', message, timestamp}` cho cả
>   lượt.
> - **(CAO — mới, do chính lượt sửa) `encrypt()` vẫn giữ nguyên mọi chuỗi dạng `enc:a:b:c`** (`crypto.util.js:65-67`) trong khi `decrypt()` nay
>   ném ⇒ người dùng gõ ghi chú `enc:1:2:3` (qua `filterSensitiveNote` không đổi) là **mọi lượt `/sync/pull` của tài khoản ấy trả 500, trên mọi
>   máy**; số điện thoại `enc:a:b:c` (9 ký tự, qua `updateProfileSchema` — `auth.validation.js:43`) là **đăng nhập 500 vĩnh viễn**. Client nuốt
>   lỗi kéo ⇒ kéo về đứng im lặng, máy đăng nhập mới không có dữ liệu. Xin: `encrypt()` luôn mã hoá đầu vào của người dùng (đánh dấu bản mã bằng
>   cách khác, hoặc chỉ coi là bản mã khi giải được). Gom cùng đơn 53.
> - **`auth` — một phần:** có ném nhưng 500 **không** mang `code` (`ResponseHandler.error`, `response-handler.js:15-26`) — `auth.service.js:238`,
>   `:316`, `:455` (đăng nhập), `:733-734`, `:756-757`, `auth.repository.js:18-19`.
> - **Log** không ghi bảng + khoá chính của hàng hỏng (đơn xin, để dọn được).
> - Còn nuốt lỗi: `maskTransactionDescription` (`masking.util.js:160-169` — bản mã đi vào prompt Gemini qua `tools.executor.js:82`),
>   `dedup.repository.js:11-17`. `maskPhone` / `maskAccountNumber` / `maskAddress` trả chuỗi che sẵn (không lộ bản mã — chấp nhận được).
> - **Việc 2–3 — chưa:** khoá đúng cho `PersonFinance`, xác nhận khoá trên Render.

> 🔎 **Client soát lại 2026-10-26** (`main` @ `5bb258ff`; đơn chỉ lên `main` qua PR #160 tối 2026-10-25, sau commit backend
> mới nhất `36f1ea43`): **chưa làm.** `utils/crypto.util.js` không đổi từ 2026-10-16: sai định dạng `return str` (:98), giải
> hỏng `return str` (:114); `encrypt()` :65 vẫn giữ nguyên mọi chuỗi `isEncrypted` (`:125` chỉ đếm `split(':').length === 4`).
> Các chỗ gọi (`auth.repository.js:18-19`, `auth.service.js`, `sync.repository.js:14`, `bank.repository.js:243`,
> `dedup.repository.js`) chưa kiểm lỗi giải mã.

**Ngày:** 2026-10-24 · **Phía gửi:** Client-app · **Nhánh:** `TranQuangDat`
**Loại:** đơn xin sửa mã backend — mức **cao** (làm hỏng dữ liệu người dùng trên máy, im lặng). Không đổi lược đồ, không đổi
hình dạng API khi giải mã thành công. Mã backend client **chỉ đọc** (quy tắc 1 `CLAUDE.md`); mọi khẳng định dưới đây đo ngày
2026-10-24 bằng đọc mã trên HEAD `TranQuangDat` và bằng CSDL thật của máy Realme (tài khoản 10).

## Chuyện đã xảy ra (đo được)

1. Backend dev chạy trên CSDL cục bộ `PersonFinance` (biến môi trường `DATABASE_URL` / `DIRECT_URL`), **còn khoá mã hoá lấy
   từ `src/Backend/.env`** — khoá thật 64 ký tự hex, là khoá của dữ liệu Supabase.
2. Dữ liệu của `PersonFinance` lại được mã hoá bằng **khoá dev mặc định** viết trong `utils/crypto.util.js` (`RAW_KEY` khi
   `DATA_ENCRYPTION_KEY` trống). Đo: lấy 65 chuỗi `enc:…` app nhận về, giải bằng khoá mặc định → **65/65** giải được và khớp
   **từng ký tự** với ghi chú gốc client giữ trong bản sao CSDL trước đó; giải bằng khoá của `.env` → **0/65**.
3. Mỗi lần giải hỏng, `decrypt()` (`utils/crypto.util.js` dòng ~112–115) ghi log *"Lỗi giải mã AES-256-GCM"* rồi
   **`return str`** — tức trả nguyên `enc:<iv>:<tag>:<bản mã>`. Log backend dev đếm được **66** dòng ấy trong lượt chạy.
4. `/sync/pull` gửi chuỗi ấy trong trường `note`. Client ghi đè: **64 giao dịch + 1 hoá đơn** của tài khoản 10 trên máy hiện
   ghi chú dạng `enc:24…2106…` (Trang chủ, Sổ giao dịch).
5. Không chỉ là chữ rác: client mã hoá **ý nghĩa** vào `transaction.Note` (`docs/superpowers/backend/TRANSACTION_NOTE_ENCODING.md`)
   — khoản *"Số dư ban đầu"* 200.000 đ mất tiền tố, nên thẻ Thu nhập tháng 10 của máy nói **200.000 đ** thay vì **0 đ**; ba khoản
   *"Thanh toán hóa đơn: …"* và năm khoản *"Tích lũy / Rút từ mục tiêu: …"* cũng mất nghĩa.

Client đã khôi phục 65 ghi chú trên máy từ bản sao (người dùng chọn). Server **không** hỏng gì: hàng trên `PersonFinance` vẫn là
bản mã đúng của khoá dev.

## Vì sao `return str` là sai ở mọi môi trường

Chuỗi trả về **trông như dữ liệu hợp lệ** (một chuỗi không rỗng), nên mọi chỗ gọi đều dùng tiếp: client lưu nó, thống kê đọc
sai nghĩa, và nếu người dùng sửa giao dịch thì client đẩy chính bản mã lên lại (`encrypt()` thấy `isEncrypted` nên giữ nguyên
— may là không hỏng thêm). Trên production, chỉ cần một lần khoá lệch (xoay khoá, đặt sai biến trên Render, khôi phục bản sao
từ môi trường khác) là **mọi** thiết bị kéo về bản mã và ghi đè ghi chú thật — không lỗi nào hiện ra.

Cùng khuôn ở chỗ khác: `auth.service.js` / `auth.repository.js` giải mã `phone`, `address` (hồ sơ — màn *Thông tin cá nhân*
của client sẽ hiện `enc:…`, và người dùng bấm Lưu là gửi bản mã lên), `masking.util.js`, `bank.repository.js`,
`ai/features/dedup/dedup.repository.js`.

## Ràng buộc phía client — đọc trước khi chọn cách sửa

Nhánh kéo về của client (`src/Client-app/lib/core/sync/anh_xa_keo_ve.dart`) đọc `note` là
`Value(t['note']?.toString() ?? '')` cho giao dịch, hoá đơn (hai chỗ), mục tiêu:

| Backend trả gì khi giải hỏng | Client làm gì | Hậu quả |
|---|---|---|
| Bản mã (hiện tại) | Ghi bản mã vào ghi chú | Hỏng nội dung + sai thống kê (trên) |
| `null` / bỏ khoá `note` | Ghi **chuỗi rỗng** | **Xoá** ghi chú thật trên máy |
| Lượt `/sync/pull` trả **mã lỗi HTTP (5xx)** | Không ghi gì, giữ mốc kéo về, thử lại ở chu kỳ sau | Không mất gì; đồng bộ dừng tới khi sửa khoá |

Nên với client hiện tại, **chỉ phương án cuối là không phá dữ liệu**.

## Xin làm

1. **(cao) `decrypt()` không trả bản mã khi hỏng.** Đề xuất: ném lỗi có mã (vd. `DECRYPT_FAILED`) để tầng service / controller
   trả **5xx** cho cả request (với `/sync/pull`: cả lượt kéo, kèm `code`), log kèm bảng + khoá chính của hàng — **không** trả
   một phần dữ liệu, không `null`, không bỏ trường (bảng trên). Áp cho mọi chỗ gọi liệt kê ở trên, kể cả hồ sơ (`phone`,
   `address`): trả bản mã hay `null` cho màn hồ sơ đều dẫn tới người dùng lưu đè.
2. **(vừa) Khoá của CSDL dev `PersonFinance`.** Chọn một và ghi vào tài liệu chạy backend: (a) chạy backend cho `PersonFinance`
   với `DATA_ENCRYPTION_KEY` = khoá dev mặc định của `crypto.util.js`, hoặc (b) script mã hoá lại dữ liệu `PersonFinance` sang
   khoá của `.env` (đọc bằng khoá cũ, ghi bằng khoá mới, mỗi bảng một giao tác). Client chỉ cần **một khoá đúng cho mỗi CSDL**.
3. **(vừa) Production:** xác nhận `DATA_ENCRYPTION_KEY` trên Render đúng khoá đã mã hoá dữ liệu Supabase (một câu truy vấn đếm
   số hàng giải hỏng — bên dưới — trả 0).
4. **(thấp)** `encrypt()` giữ nguyên mọi chuỗi có dạng `enc:a:b:c` (`isEncrypted`). Người dùng gõ ghi chú đúng dạng ấy thì nó
   được lưu **không mã hoá**; client đẩy lại bản mã của khoá khác cũng được nhận như hợp lệ. Cân nhắc kiểm thêm độ dài hex của
   iv (24) / tag (32), hoặc mã hoá lại khi giải bằng khoá hiện tại hỏng.

## Kiểm lại

- Script đếm hàng giải hỏng theo khoá đang cấu hình (chạy từ `src/Backend`, chỉ đọc): duyệt các cột đã mã hoá
  (`transaction."Note"`, `bill."Note"`, `user.phone`, `user.address`, …), đếm số hàng `isEncrypted(x) && decrypt ném lỗi`.
  Mong đợi: **0** trên Supabase với khoá Render; trên `PersonFinance` = 0 sau khi làm việc 2.
- Chạy backend với khoá **sai** có chủ ý → `GET /api/sync/pull` trả 5xx + `code`, **không** có chuỗi `enc:` nào trong thân
  phản hồi; `GET /api/auth/profile` cũng không trả `enc:`.
- Phía client đối chiếu được: sau lượt kéo với khoá sai, `SELECT count(*) FROM transactions WHERE note LIKE 'enc:%'` trên
  CSDL máy vẫn **0**.
