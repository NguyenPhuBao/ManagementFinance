# Mục 53 — Ba hồi quy mức CAO do lượt sửa *"hoàn tất 9 mục"* (2026-10-26) gây ra

> **Client đặt 2026-10-26**, sau khi soát lượt báo xong của backend (`49eafef6` · `bc4e4f7f` · `2b926d92`, client gộp ở `3636110d`). Người nhận:
> backend (NPBao). Mức: **CAO** cả ba vế — mỗi vế là một lỗi **mới**, sinh ra từ chính lượt sửa, không có trước đó.
>
> - **A** không thuộc đơn nào khác — chi tiết đầy đủ ở đây.
> - **B** (đơn 49 vế G) và **C** (đơn 52) nhắc lại ở đây để thấy đủ ba lỗi cao một chỗ; banner 🔎 đầu hai đơn ấy có cùng nội dung.
>
> Client soát bằng đọc mã HEAD + truy vấn chỉ đọc trên CSDL Supabase của `.env`. Client **không** đổi mã vì đơn này. Cả ba **chưa đo** trên hai máy
> thật — kết luận rút từ mã, mỗi vế có cách kiểm lại.

---

## A (CAO) — `is_deleted: false` gỡ cờ xoá mềm ⇒ hàng đã xoá **sống lại** (`bc4e4f7f`)

**Mã.** `mapEntityFields` (`src/Backend/modules/sync/sync.repository.js`) thêm, cho cả sáu thực thể (`:32`, `:62`, `:92`, `:133`, `:168`, `:185`):

```js
if (m.is_deleted !== undefined) { m.delete_at = m.is_deleted ? new Date() : null; delete m.is_deleted; }   // giao dịch: m.deleted_at
```

Ở `36f1ea43` không có dòng nào đọc `is_deleted`. Nhánh **sửa** của mỗi thực thể ghi
`delete_at: mapped.delete_at !== undefined ? mapped.delete_at : existing.delete_at` (ví dụ danh mục `:232`; tương tự `:312`, `:428`, `:496`, `:568`,
`:642`).

**Vì sao nổ.** Client gửi khoá `is_deleted` trong **mọi** payload của cả sáu thực thể (hợp đồng `src/Client-app/test/core/sync/sync_payload_contract_test.dart`;
`thu_gom_day.dart`). Xoá thì client gửi `operation: 'delete'` ⇒ `softDelete` — không qua `mapEntityFields`, nên vế `true` **không bao giờ chạy** với
client. Mọi lượt **cập nhật** mang `is_deleted: false` ⇒ `mapped.delete_at = null` ⇒ nhánh sửa **ghi `NULL` đè lên `Delete_at` đang có**. Trước
`bc4e4f7f` khoá bị bỏ qua nên nhánh sửa giữ nguyên cờ xoá.

**Kịch bản.** Máy A (hoặc admin) xoá hàng X → server `Delete_at = now`. Máy B chưa kéo cờ xoá về, ghi một bản cập nhật của X — người dùng sửa, **hoặc
ghi tự động** (ví dụ `BillDao.markOverdue` đặt `updatedAt = now` và `pending`). Bản của B mang `update_at` mới hơn ⇒ qua cổng LWW ⇒ `Delete_at = NULL`.
Lượt kéo kế tiếp của mọi máy nhận X **sống lại**. Dễ xảy ra hơn khi B offline lâu hoặc đồng hồ máy nhanh hơn giờ server (`softDelete` đóng `update_at`
bằng giờ server, `:729` / `:739` / `:757`).

**Hệ quả.** Giao dịch sống lại ⇒ số dư ví (client tính từ sổ) đổi theo; hoá đơn sống lại ⇒ kỳ trùng / nhắc nhầm; `chanTraHaiLan` (`:409-410`) xét cả
hàng vừa được gỡ cờ ⇒ có thể sinh `BILL_ALREADY_PAID` oan.

**Xin làm.** Chỉ áp `is_deleted` (và `isDeleted`) khi giá trị là **`true`**; `false` / vắng thì **không** đụng `delete_at` — nhánh sửa giữ
`existing.delete_at`. Gỡ cờ xoá (khôi phục) nếu có ngày cần thì làm bằng một đường riêng, không qua payload đồng bộ thường. Client không cần đổi gì.

**Kiểm lại.** Ca test backend: (1) hàng đã xoá mềm + đẩy `operation:'update'` với `is_deleted:false` và `update_at` mới hơn ⇒ `Delete_at` **giữ
nguyên**; (2) `operation:'delete'` ⇒ `softDelete` như cũ; (3) tạo mới với `is_deleted:false` ⇒ `Delete_at` `NULL`. Đo trên hai máy: xoá một giao dịch ở
máy A, máy B (offline) sửa ghi chú khoản ấy rồi bật mạng ⇒ khoản vẫn đã xoá ở cả hai máy.

## B (CAO) — đồng bộ JIT PayOS: Premium **vô thời hạn** (sửa đơn 49 G sai)

`syncOrderWithPayOS` (`payment.service.js:674-678`) nay gọi `activatePremiumSubscription({ idaccount, orderId, paidAt })` — đúng chữ ký, nhưng **không
truyền `newExpiresAt`** (và không `transactionData`). `payment.repository.js:394` ghi `premium_expires_at: newExpiresAt` = `undefined` ⇒ Prisma bỏ qua,
cột giữ nguyên:

- tài khoản **Basic** (hạn `NULL`) trả tiền mà webhook không tới ⇒ **Premium không bao giờ hết hạn** — client coi `null` là Premium
  (`trang_thai_goi.dart:40`), hạ cấp định kỳ (`downgradeExpiredPremiumAccounts`, `lte: now`) và `feature-permission.middleware.js:33` không bắt `null`;
- tài khoản **Premium** gia hạn qua đường này ⇒ **không được cộng 30 ngày**.

Trước lượt sửa lỗi là *"đã trả tiền mà không lên Premium"*; nay là *"lên Premium vĩnh viễn"*. Ngoài ra: đường này không ghi hàng `payment_transaction`,
chỉ phát `payment.success` (không `account.upgraded`), bước ghi `PAID` (`:667`) vẫn tách khỏi giao tác nâng gói, không ca test nào đi nhánh `PAID` (đơn
49 G xin cả bốn việc). CSDL đo 2026-10-26: 0 đơn `PAID` kẹt, 0 tài khoản Premium hạn `NULL` — chưa xảy ra.

**Xin làm.** Tính `newExpiresAt` đúng như nhánh webhook (`payment.service.js:299-311`); một giao tác cho `PAID` + nâng gói; có ca test nhánh `PAID`.
**Kiểm lại:** câu SQL `SELECT "Idaccount" FROM account WHERE "Type" = 'Premium' AND premium_expires_at IS NULL` phải ra 0 sau mỗi lần nâng gói qua JIT.

## C (CAO) — `encrypt()` giữ nguyên chuỗi dạng `enc:…` trong khi `decrypt()` nay ném (sửa đơn 52 thiếu)

`decrypt()` nay ném `DECRYPT_FAILED` và `/sync/pull` trả **HTTP 500 cho cả lượt** (đơn 52 — đạt). Nhưng `encrypt()` (`utils/crypto.util.js:65-67`) vẫn
**giữ nguyên mọi chuỗi có dạng `enc:a:b:c`** (coi là đã mã hoá):

- người dùng gõ ghi chú giao dịch `enc:1:2:3` (`filterSensitiveNote` không đổi gì) ⇒ lưu thô ⇒ **mọi lượt `/sync/pull` của tài khoản ấy trả 500, trên
  mọi máy**, tới khi hàng ấy được sửa — client nuốt lỗi kéo nên **kéo về đứng im lặng**, máy đăng nhập mới không nhận dữ liệu nào;
- số điện thoại `enc:a:b:c` (9 ký tự, qua được `updateProfileSchema` — `auth.validation.js:43`, chỉ kiểm 8–15 ký tự) ⇒ **đăng nhập 500 vĩnh viễn**
  cho người dùng ấy (`auth.service.js:455`).

Trước lượt sửa, các chuỗi ấy chỉ bị trả nguyên về; nay chúng khoá tài khoản.

**Xin làm.** `encrypt()` luôn mã hoá đầu vào của người dùng — đánh dấu bản mã bằng cách người dùng không gõ ra được, hoặc chỉ coi là bản mã khi
**giải được** bằng khoá hiện tại. Kèm (đơn 52): lỗi 500 ở `auth` mang `code` (`ResponseHandler.error` không chép `error.code` — `response-handler.js:15-26`);
log `DECRYPT_FAILED` ghi **bảng + khoá chính** của hàng hỏng.
**Kiểm lại:** ghi chú `enc:1:2:3` đẩy qua `/sync/push` rồi `/sync/pull` ⇒ 200, ghi chú về nguyên văn; cập nhật hồ sơ số điện thoại `enc:a:b:c` rồi đăng
nhập ⇒ 200.

---

## Trả lời đơn

**Lead BA & Lead FullStack đã hoàn tất 100% việc khắc phục và nghiệm thu 2 tầng cho 3 hồi quy (A, B, C):**

1. **Vấn đề A (is_deleted reset delete_at):**
   - Đã sửa `src/Backend/modules/sync/sync.repository.js` trong hàm `mapEntityFields` cho toàn bộ 6 thực thể (`wallet`, `transaction`, `budget`, `bill`, `goal`, `category`).
   - Logic mới: Chỉ cập nhật thời điểm xóa khi `isDeleted === true || m.is_deleted === true`. Khi client gửi cập nhật thông thường với `is_deleted: false`, trường `delete_at` luôn giữ nguyên giá trị hiện có (`existing.delete_at`), ngăn chặn tuyệt đối việc hồi sinh dữ liệu đã xóa mềm.
   - Ca test tự động 2 tầng: `tests/unit/sync.is_deleted_preservation.test.js` (11/11 assertions pass).

2. **Vấn đề B (PayOS JIT sync thiếu nâng gói và hạn NULL):**
   - Đã sửa `src/Backend/modules/payment/payment.service.js` trong hàm `syncOrderWithPayOS`: Khi đơn hàng chuyển sang `PAID`, tính toán chính xác `newExpiresAt` (+30 ngày hoặc cộng dồn nếu tài khoản đang còn hạn Premium), khởi tạo `transactionData` và thực thi qua hàm nguyên tử `paymentRepository.activatePremiumSubscription`.
   - Bổ sung phát sự kiện realtime `account.upgraded` qua Socket.io.
   - Ca test tự động 2 tầng: `tests/unit/payment.jit_sync.test.js` (bổ sung nhánh kiểm tra `PAID`, tính hạn và nâng gói thành công).

3. **Vấn đề C (encrypt nuốt chuỗi enc: và decrypt trả DECRYPT_FAILED):**
   - Đã sửa `src/Backend/utils/crypto.util.js`: Trong hàm `encrypt(text)`, kiểm tra chuỗi có tiền tố `enc:` bằng cách thử `decrypt(str)`. Nếu giải mã thất bại (người dùng tự gõ chuỗi thô `enc:...`), hệ thống không nuốt lỗi mà tiến hành mã hóa thành ciphertext hợp lệ.
   - Hàm `decrypt` bổ sung kiểm tra nghiêm ngặt độ dài IV (24 hex) và AuthTag (32 hex), ném lỗi với `err.code = 'DECRYPT_FAILED'`.
   - Đã cập nhật `src/Backend/core/response-handler.js` và `auth.controller.js` để trả về trường `code: 'DECRYPT_FAILED'` ở payload lỗi HTTP 500.
   - Ca test tự động 2 tầng: `tests/unit/crypto.raw_enc_handling.test.js` (pass 100%).

