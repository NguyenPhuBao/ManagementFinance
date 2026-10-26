# Gia đình — 02b. Hạn mức chi của từng thành viên

> **Ngày:** 2026-10-26 · **Trạng thái:** thiết kế người dùng đã duyệt, chưa có mã · **Người đọc:** backend, PO, client.
> **Cần trước:** `02A` (ví chung, khoản của nhà, rút). Quyết định gốc: `00_TONG_QUAN.md` mục 2 — #9 chỉ Chủ nhà đặt, #10 vượt thì **cảnh báo +
> báo Chủ nhà**, #13 lưu trên server kèm trạng thái nhà, #16 Thành viên chỉ thấy hạn mức của mình.

---

## 1. Mục đích

Chủ nhà giới hạn mỗi Thành viên được chi bao nhiêu từ mỗi ví chung trong một kỳ (ngày / tuần / tháng), tổng hoặc theo danh mục. App **không
chặn** — FlowMoney ghi sổ, không giữ tiền; chặn ghi chỉ làm sổ sai với tiền đã tiêu thật — mà **cảnh báo** người chi và **báo** Chủ nhà.

## 2. Người dùng thấy gì

**Chủ nhà** — Chi tiết ví chung → **Hạn mức** → danh sách Thành viên (Chủ nhà không có hạn mức; Chỉ xem không chi được). Chạm một người:

- **Hạn mức chung** của ví: số tiền + kỳ *Ngày / Tuần / Tháng*, hoặc *Không giới hạn* (mặc định).
- **Theo danh mục** (tuỳ chọn, nhiều dòng): danh mục chi của nhà + số tiền + kỳ riêng. Ví dụ: chung 2.000.000 đ / tháng; *Giải trí*
  300.000 đ / tháng; *Ăn vặt* 30.000 đ / ngày.
- Mỗi dòng hiện **đã dùng / hạn mức** của kỳ hiện tại (thanh tiến độ).
- Lưu cần mạng (như đổi vai); offline ⇒ nút Lưu khoá kèm câu *"Cần kết nối mạng để đổi hạn mức"*.

**Thành viên** —

- Chi tiết ví chung có thẻ **"Hạn mức của bạn"** (chỉ của mình): mỗi dòng đã dùng / hạn mức, còn lại, kỳ.
- **Form chi** (chế độ nhà) và **form rút**: dưới ô số tiền có dòng *"Còn 400.000 đ trong hạn mức tháng này"* (dòng chung; nếu danh mục đang
  chọn có dòng riêng thì hiện dòng nào **còn ít hơn**).
- **Bấm Lưu mà vượt** (dòng chung hoặc dòng của danh mục đang chọn) ⇒ hộp *"Vượt hạn mức tháng này 200.000 đ — vẫn ghi?"* (nhiều dòng vượt
  thì liệt kê từng dòng: *"Giải trí: vượt 50.000 đ"*), hai nút **Ghi** / **Huỷ**. *Ghi* ⇒ lưu như thường.
- **Sửa** một khoản cũ lên số lớn hơn, hoặc đổi danh mục / ví / ngày của nó, cũng kiểm lại (số đã dùng tính **trừ** chính khoản đang sửa).

**Chỉ xem** — không thấy hạn mức của ai.

## 3. Mô hình

Một **dòng hạn mức** = `(ví chung, thành viên, danh mục | trống, kỳ, số tiền)`.

- `danh mục` trống = **dòng chung** của ví — nhiều nhất **một** dòng chung cho mỗi (ví, thành viên).
- Mỗi (ví, thành viên, danh mục) nhiều nhất một dòng. Kỳ của các dòng độc lập nhau.
- Danh mục phải là **danh mục chi của nhà** (phân loại `chi`).
- Số tiền: > 0, tối đa 13 chữ số phần nguyên (`numeric(15,2)` — trần như mọi ô tiền, `GioiHanSoChuSo`).
- Chỉ áp cho vai **Thành viên**. Người đổi sang Chỉ xem / rời / bị mời ra / thành Chủ nhà (chuyển chủ) ⇒ server xoá dòng của họ.

## 4. Kỳ

| Kỳ | Từ (gồm) | Tới (không gồm) |
|---|---|---|
| Ngày | 00:00 hôm nay | 00:00 hôm sau |
| Tuần | 00:00 Thứ Hai tuần ISO hiện tại | 00:00 Thứ Hai tuần sau |
| Tháng | 00:00 ngày 1 | 00:00 ngày 1 tháng sau |

- Theo **giờ của máy** (app giả định Asia/Ho_Chi_Minh như mọi phép theo ngày khác); tuần ISO dùng lại `tuan_iso.dart` (năm ISO khác năm
  dương lịch ở hai chiều — bẫy đã biết).
- **Một** hàm kỳ (`household/domain/ky_han_muc.dart`) cho form, màn hạn mức, luật thông báo. Biên `[from, to)` như Sổ giao dịch.

## 5. "Đã dùng" — một định nghĩa

`daDungHanMuc(dòng, khoảnCủaNhà, kỳ)` (`household/domain/han_muc.dart`):

- **Dòng chung:** Σ số tiền mọi khoản của nhà, chưa xoá, có `walletId` = ví, `idaccount` (người ghi) = thành viên, ngày trong kỳ, loại
  **Chi của nhà** hoặc **Rút — nửa của nhà** (`02A` mục 3).
- **Dòng danh mục:** như trên nhưng chỉ **Chi của nhà** có `categoryId` **đúng bằng** danh mục ấy — cùng luật khớp với ngân sách theo danh
  mục (`khoanThuocNganSach`: khớp đúng id, không gộp danh mục con). Rút không có danh mục nên chỉ vào dòng chung.
- **Còn lại** = hạn mức − đã dùng (âm khi đã vượt — hiện số âm, không kẹp về 0).
- Khoản ghi **trước** khi dòng hạn mức được đặt mà nằm trong kỳ hiện tại **vẫn tính** (hạn mức là của kỳ, không phải từ lúc đặt).

## 6. Thông báo (nhóm *Gia đình*, mặc định **bật**)

| Loại | Trên máy | Khi | Khoá chống trùng | Câu (không mang số tiền) |
|---|---|---|---|---|
| `hanMucSapHet` | Thành viên | đã dùng của một dòng **lần đầu ≥ 80%** trong kỳ (và < 100%) | `hanMuc80:<idvi>:<dòng>:<mã kỳ>` | *"Bạn đã dùng gần hết hạn mức {Tiền chợ} {tháng này}"* |
| `hanMucVuot` | **Chủ nhà** | đã dùng của một dòng của một Thành viên **vượt 100%** trong kỳ | `hanMucVuot:<idvi>:<idaccount>:<dòng>:<mã kỳ>` | *"{An} đã vượt hạn mức {Tiền chợ} {tháng này}"* |

- `<dòng>` = `chung` hoặc id danh mục; `<mã kỳ>` = `2026-10-26` / `2026-W43` / `2026-10`.
- **Mỗi dòng mỗi kỳ báo một lần** — các khoản vượt tiếp sau trong cùng kỳ không báo thêm (chống ồn); kỳ sau báo lại nếu lại vượt.
- Hai luật chạy trong vòng quét thông báo hiện có (`NotificationScanner`, trong app + lượt nền WorkManager) trên dữ liệu đã đồng bộ. Máy Chủ
  nhà biết có khoản vượt khi **kéo được nó về** (`00` nguyên tắc 6): ngay khi app đang mở (socket `sync.completed` tới mọi thành viên), hoặc
  ở lượt nền kế tiếp / lần mở app.
- Không báo ngược về quá khứ: luật bỏ qua kỳ đã qua và khoản **kéo về lần đầu** khi mới vào nhà (`keoLaiToanBo`) — dùng mốc *im lặng trước*
  (`silenceBefore`) như *Khoản chi lớn* (5f `NOTIFICATION_FEATURE.md`), mốc = lúc vào nhà.

## 7. Việc backend

### 7.1 CSDL (SQL nháp)

```sql
CREATE TABLE IF NOT EXISTS "household_spending_limit" (
  "Id"          SERIAL PRIMARY KEY,
  "Idhousehold" INT          NOT NULL REFERENCES "household"("Idhousehold"),
  "Idwallet"    VARCHAR(36)  NOT NULL REFERENCES "wallet"("Idwallet"),
  "Idaccount"   INT          NOT NULL REFERENCES "account"("Idaccount"),
  "Idcategory"  VARCHAR(36)  NULL     REFERENCES "category"("Idcategory"),
  "Period"      VARCHAR(5)   NOT NULL,
  "Amount"      NUMERIC(15,2) NOT NULL,
  "Update_at"   TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  CONSTRAINT "chk_household_limit_period" CHECK ("Period" IN ('Day', 'Week', 'Month')),
  CONSTRAINT "chk_household_limit_amount" CHECK ("Amount" > 0)
);
CREATE UNIQUE INDEX IF NOT EXISTS "uq_household_limit_line"
  ON "household_spending_limit" ("Idwallet", "Idaccount", COALESCE("Idcategory", ''));
CREATE INDEX IF NOT EXISTS "idx_household_limit_household"
  ON "household_spending_limit" ("Idhousehold");
```

Xoá dòng là **xoá thật** ở bảng cấu hình này (không phải dữ liệu người dùng ghi sổ — không đồng bộ, không client nào giữ bản sao cần cờ
xoá); nếu backend muốn giữ lịch sử thì thêm `Delete_at`, client không đọc.

### 7.2 API

| # | Endpoint | Ai | Thân | Trả về |
|---|---|---|---|---|
| L1 | `PUT /api/households/wallets/:idwallet/limits/:idaccount` | `Owner`, nhà `Active` | `{ items: [ { idcategory: string \| null, period: 'Day' \| 'Week' \| 'Month', amount: number } ] }` — **thay toàn bộ** dòng của (ví, người); `items: []` = bỏ hết | trạng thái nhà (đơn 50 C.1, có `spendingLimits`) |

Kiểm: ví thuộc nhà, chưa xoá; `:idaccount` là thành viên đang ở với vai `Member` (khác ⇒ `409 HOUSEHOLD_LIMIT_INVALID_TARGET`); danh mục thuộc
nhà, phân loại chi, không trùng; ≤ 1 dòng `idcategory = null`; số tiền > 0, ≤ 13 chữ số phần nguyên; tối đa 20 dòng / (ví, người). Lỗi dạng
⇒ 400 `'Validation failed'` có sẵn. Không phải Chủ nhà ⇒ `403 HOUSEHOLD_NOT_OWNER`.

### 7.3 Trạng thái nhà

`GET /api/households/me` thêm:

```json
"spendingLimits": [
  { "idwallet": "8a1c…", "idaccount": 25, "idcategory": null,   "period": "Month", "amount": 2000000, "updateAt": "…" },
  { "idwallet": "8a1c…", "idaccount": 25, "idcategory": "c9e2…", "period": "Month", "amount": 300000,  "updateAt": "…" }
]
```

⚠️ **Lọc theo người hỏi ở server** (quyết định #16): `Owner` ⇒ mọi dòng; `Member` ⇒ chỉ dòng có `Idaccount` = mình; `Viewer` ⇒ `[]`. Ẩn ở giao
diện mà vẫn trả trong phản hồi là lộ.

### 7.4 Dọn và sự kiện

- Xoá dòng của một người khi: đổi vai sang `Viewer` (C #8), chuyển chủ làm họ thành `Owner` (C #9), mời ra (C #10), rời (C #11); xoá mọi
  dòng của nhà khi giải tán (C #12); xoá dòng của một ví khi ví ấy bị xoá mềm.
- Mỗi lần L1 hoặc dọn ở trên ⇒ phát **`household.changed`** tới mọi thành viên (payload hộp đen — client chỉ gọi lại `/me`).
- **Không** kiểm hạn mức khi `/sync/push` — khoản chi là tiền đã tiêu thật; từ chối nó là làm sổ sai.

## 8. Phía client

- `NhaRepository` nhớ `spendingLimits` cùng trạng thái nhà (secure storage theo tài khoản — spec 2026-10-23 mục 5.8); offline dùng bản đã nhớ.
- `household/domain/`: `ky_han_muc.dart` (mục 4), `han_muc.dart` (`daDungHanMuc`, `kiemVuot(dòng[], khoản mới / khoản sửa)` ⇒ danh sách dòng
  vượt + số vượt) — Dart thuần, test như tài liệu.
- Form chi chế độ nhà / form rút: `ThemGiaoDichCubit` (chế độ nhà) và Cubit trang Rút gọi `kiemVuot` ở bước chuẩn bị lưu (cùng chỗ hỏi
  ngân sách *Chặn* của form cá nhân — một hộp xác nhận, không hai).
- Màn **Hạn mức** (Chủ nhà) + thẻ **Hạn mức của bạn** (Thành viên) — `household/presentation/`.
- `NotificationKind` thêm `hanMucSapHet`, `hanMucVuot` (nhóm `giaDinh` — hai `switch` không `default` + `tatCaUngVien()`).
- **Đưa lên Stitch trước:** màn Hạn mức (danh sách người + sửa một người), thẻ *Hạn mức của bạn*, dòng *Còn …* dưới ô số tiền, hộp *Vượt hạn mức*.

## 9. Ca biên và giới hạn chấp nhận

- **Dữ liệu chưa đầy đủ:** cảnh báo lúc Lưu chỉ thấy khoản đã có trên máy. Một Thành viên dùng hai máy cùng offline có thể vượt mà không được
  cảnh báo; máy Chủ nhà vẫn báo khi cả hai khoản về tới (quyết định #10 — chấp nhận).
- **Hạn mức vừa đổi ở server mà máy chưa làm mới:** form dùng bản đã nhớ; `household.changed` + làm mới khi `resumed` thu hẹp khe.
- **Ví bị lưu trữ:** không chi được ⇒ hạn mức không còn tác dụng; giữ dòng (bỏ lưu trữ là dùng lại).
- **Đổi giờ máy:** kỳ tính theo giờ máy — chỉnh giờ làm lệch kỳ trên máy ấy (như mọi phép theo ngày khác của app).
- **Khoản của người đã rời:** không còn dòng hạn mức ⇒ không tính, không báo.

## 10. Kiểm thử và nghiệm thu

- **Domain:** kỳ ngày / tuần (đầu năm ISO, tuần 53) / tháng (tháng 2, năm nhuận — nếp *test lịch tháng ngắn*); `daDungHanMuc` gồm rút ở dòng
  chung, không ở dòng danh mục; khoản trước lúc đặt hạn mức vẫn tính; sửa khoản trừ chính nó; nhiều dòng vượt cùng lúc.
- **Thông báo:** 80% một lần mỗi kỳ; vượt một lần mỗi (người, dòng, kỳ) trên máy Chủ nhà; không báo khoản kéo về lần đầu khi vào nhà.
- **Widget:** màn Hạn mức + hộp vượt ở 360 dp, số 13 chữ số.
- **Backend (đề xuất ca):** Member gọi L1 ⇒ 403; đích là Viewer ⇒ 409; `/me` của Member không chứa dòng người khác; đổi vai ⇒ dòng biến mất.
- **Nghiệm thu hai máy thật:** Chủ nhà đặt 100.000 đ / ngày cho Thành viên → máy Thành viên thấy *"Còn 100.000 đ"* → chi 90.000 đ ⇒ thông báo
  80% → chi tiếp 30.000 đ ⇒ hộp vượt → *Ghi* ⇒ máy Chủ nhà nhận *"… đã vượt hạn mức"*; Thành viên không thấy hạn mức của người khác (kể cả đọc
  phản hồi API).

## 11. Câu hỏi để thảo luận

- **Q-B1** — L1 thay toàn bộ dòng của một người trong một ví (đơn giản cho client, một lần lưu một màn). Backend thích PATCH từng dòng hơn?
- **Q-B2** — Trần 20 dòng / (ví, người) có cần không?
- **Q-B3** — Xoá thật hay `Delete_at` cho bảng cấu hình (mục 7.1)?

## 12. Trả lời / thảo luận

*(Chờ backend / PO.)*
