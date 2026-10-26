# Gia đình — 02c. Định mức góp hằng tháng, nhắc góp, tự góp định kỳ

> **Ngày:** 2026-10-26 · **Trạng thái:** thiết kế người dùng đã duyệt, chưa có mã · **Người đọc:** backend, PO, client.
> **Cần trước:** `02A` (góp / rút là cặp hai khoản). Quyết định gốc: `00_TONG_QUAN.md` mục 2 — #9 Chủ nhà cấu hình, #13 cài đặt lưu trên server
> kèm trạng thái nhà, #16 (áp tương tự cho định mức) Thành viên chỉ thấy của mình.

---

## 1. Mục đích

Chủ nhà đặt **mỗi người góp bao nhiêu mỗi tháng** vào từng ví chung và **hạn góp**; app cho thấy ai đủ / thiếu, **nhắc** người chưa góp đủ, và mỗi
người có thể bật **tự góp** để app tự ghi khoản góp hằng tháng (ghi sổ — không chuyển tiền thật, như trích tiền tự động của mục tiêu).

## 2. Định mức góp

- **Ai đặt:** Chủ nhà. **Áp cho:** Chủ nhà và Thành viên (Chỉ xem không ghi được nên không có định mức).
- **Một dòng định mức** = `(ví chung, người, số tiền mỗi tháng)`. Không có = không yêu cầu.
- **Hạn góp:** một **ngày N** cho cả nhà (1–31, mặc định **5**); tháng không có ngày N ⇒ ngày cuối tháng (tháng 2, năm nhuận — nếp *test lịch
  tháng ngắn*).
- **Đã góp (ròng) trong tháng** của một người vào một ví = Σ **góp — nửa của nhà** do người ấy ghi − Σ **rút — nửa của nhà** do người ấy ghi,
  ngày trong tháng lịch hiện tại, chặn dưới ở 0 (`02A` mục 3). Gồm cả *tiền mặt trao tay* và tự góp. Trừ rút để *"góp 5 triệu rồi rút 5 triệu"*
  không được tính là đủ.
- **Đủ** khi đã góp (ròng) ≥ định mức; **thiếu** = định mức − đã góp.

**Bảng đủ / thiếu** — thêm cột vào **bảng góp** (`02A` mục 8): *"3.000.000 / 5.000.000 đ — thiếu 2.000.000 đ"* hoặc *"Đủ"*. Riêng tư như hạn mức:
Chủ nhà thấy cột định mức của mọi người; Thành viên chỉ thấy của mình (cột *đã góp* thì cả nhà vẫn thấy — `02A`). Chủ nhà đặt định mức ở màn
**Định mức góp** (Chi tiết ví chung hoặc Nhà mình): danh sách người × ví + ô hạn góp N. Lưu cần mạng.

## 3. Nhắc góp (nhóm *Gia đình*, mặc định **bật**)

| Loại | Trên máy | Khi | Khoá chống trùng | Câu |
|---|---|---|---|---|
| `gopConThieu` | người có định mức | từ ngày N, lúc ≥ 08:00, còn thiếu | `gopThieu:<idvi>:<yyyy-MM>` | *"Tháng 10 bạn còn thiếu tiền góp vào {Tiền chợ}"* |
| `gopChuaDuTongHop` | Chủ nhà | từ ngày N, lúc ≥ 08:00, có ≥ 1 người còn thiếu ở ≥ 1 ví | `gopChuaDu:<yyyy-MM>` | *"{2} người chưa góp đủ tháng 10"* |

- **Một lần mỗi tháng** (người dùng chọn — không nhắc lặp). Câu không mang số tiền.
- Chạy trong vòng quét thông báo hiện có (trong app + lượt nền); tính trên dữ liệu đã đồng bộ ⇒ khoản góp của người khác chưa kéo về thì máy Chủ
  nhà còn đếm là thiếu (`00` nguyên tắc 5).
- Góp đủ sau khi đã nhắc: không thông báo gì thêm (thẻ đủ / thiếu tự đổi).

## 4. Tự góp định kỳ

### 4.1 Người dùng thấy gì

Mỗi người (Chủ nhà, Thành viên) tự bật cho **mình** ở Chi tiết ví chung → **Tự góp**: *"Mỗi tháng ngày {N}, góp {X} từ {Ví MB} vào {Tiền
chợ}"*. Có lối tắt từ thẻ định mức: *"Bật tự góp đủ định mức"* điền sẵn số tiền = định mức, ngày = hạn góp. Một người có thể có nhiều cấu hình
(mỗi ví chung một cái hoặc hơn), tối đa 10. Lưu / bật / tắt cần mạng. **Không cần Premium** — nhà đã do Chủ nhà trả.

### 4.2 Bộ chạy — khuôn trích tiền tự động của mục tiêu

- Chạy trong `NotificationScanner.scan()` — khi app mở **và** từ lượt nền WorkManager (Android, `lib/core/nen/` — spec 2026-10-10 tự chuyển tiền
  chạy nền), dưới **khoá thuê** `khoa_tu_chuyen_tiens` (v30) như bộ trích mục tiêu và bộ tự trả hoá đơn.
- **Kỳ:** ngày N mỗi tháng lúc **08:00** (N vượt số ngày của tháng ⇒ ngày cuối tháng). **Mốc gốc** = `enabledAt` (lúc bật — server ghi): không
  bao giờ chạy kỳ **trước** lúc bật (bật hôm 20 với N = 1 thì kỳ đầu là ngày 1 tháng sau). **Trả bù tối đa 3 kỳ** mỗi lượt (bỏ app lâu).
- **Mỗi kỳ ghi một cặp góp** (`02A` mục 5) với id **tất định**: mã cặp `P = uuidv5(ns, "<configId>|<kỳ ms UTC>")`, nửa riêng
  `uuidv5(ns, "rieng|…")`, nửa của nhà `uuidv5(ns, "nha|…")` — namespace riêng, không chung với khoản mở sổ / khoản trích mục tiêu. Hai máy của
  cùng một người cùng chạy một kỳ ⇒ cùng id ⇒ server ghép làm một (LWW) — cùng lý lẽ `idKhoanTrichTuDong`.
- **Đã chạy kỳ này chưa** = trên máy đã có hàng mang id nửa của nhà của kỳ ấy (kể cả đã xoá mềm — người dùng xoá khoản tự góp thì không bị tạo
  lại). **Không** cần cột *lần chạy cuối* ở server.
- Ghi chú nửa riêng *"Góp quỹ · Tiền chợ (tự động)"* — hậu tố *(tự động)* như khoản trích mục tiêu (3.25 `GOAL_FEATURE.md`); ngày khoản = mốc kỳ.
- **Ví riêng không đủ tiền** ⇒ không ghi kỳ ấy, giữ để lượt sau thử lại, thông báo *"Tự góp chưa chạy được — Ví MB không đủ tiền"* (một lần mỗi
  kỳ). Không góp một phần.
- **Tạm dừng — giữ công tắc** (luật *"Tạm dừng"* đã có của tự trả / tự trích): không còn là thành viên · nhà `ReadOnly` / `Dissolved` · vai đổi
  sang Chỉ xem · ví chung bị lưu trữ / xoá · ví riêng nguồn bị lưu trữ / xoá. Dòng cấu hình hiện *"Tạm dừng — {lý do}"*.

### 4.3 Thông báo (nhóm *Gia đình*)

| Loại | Mặc định | Khoá | Câu |
|---|---|---|---|
| `tuGopDaChay` | bật | `tuGop:<configId>:<mã kỳ>` | *"Đã góp {X} vào {Tiền chợ} (tự động)"* |
| `tuGopKhongChay` | bật | `tuGopLoi:<configId>:<mã kỳ>` | *"Tự góp vào {Tiền chợ} chưa chạy được — {lý do}"* |

## 5. Việc backend

### 5.1 CSDL (SQL nháp)

```sql
ALTER TABLE "household" ADD COLUMN IF NOT EXISTS "Contribution_due_day" SMALLINT NOT NULL DEFAULT 5;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_household_due_day') THEN
    ALTER TABLE "household" ADD CONSTRAINT "chk_household_due_day" CHECK ("Contribution_due_day" BETWEEN 1 AND 31);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS "household_contribution_quota" (
  "Id"          SERIAL PRIMARY KEY,
  "Idhousehold" INT           NOT NULL REFERENCES "household"("Idhousehold"),
  "Idwallet"    VARCHAR(36)   NOT NULL REFERENCES "wallet"("Idwallet"),
  "Idaccount"   INT           NOT NULL REFERENCES "account"("Idaccount"),
  "Amount"      NUMERIC(15,2) NOT NULL CHECK ("Amount" > 0),
  "Update_at"   TIMESTAMP(6)  NOT NULL DEFAULT (now() AT TIME ZONE 'UTC')
);
CREATE UNIQUE INDEX IF NOT EXISTS "uq_household_quota" ON "household_contribution_quota" ("Idwallet", "Idaccount");

CREATE TABLE IF NOT EXISTS "household_auto_contribution" (
  "Id"              VARCHAR(36)   PRIMARY KEY,               -- client sinh (UUID) — dùng làm hạt giống id tất định
  "Idhousehold"     INT           NOT NULL REFERENCES "household"("Idhousehold"),
  "Idaccount"       INT           NOT NULL REFERENCES "account"("Idaccount"),
  "Idwallet"        VARCHAR(36)   NOT NULL REFERENCES "wallet"("Idwallet"),   -- ví chung đích
  "Source_idwallet" VARCHAR(36)   NOT NULL REFERENCES "wallet"("Idwallet"),   -- ví RIÊNG nguồn của chính Idaccount
  "Amount"          NUMERIC(15,2) NOT NULL CHECK ("Amount" > 0),
  "Day_of_month"    SMALLINT      NOT NULL CHECK ("Day_of_month" BETWEEN 1 AND 31),
  "Enabled"         BOOLEAN       NOT NULL DEFAULT TRUE,
  "Enabled_at"      TIMESTAMP(6)  NULL,                       -- server ghi lúc bật
  "Update_at"       TIMESTAMP(6)  NOT NULL DEFAULT (now() AT TIME ZONE 'UTC')
);
CREATE INDEX IF NOT EXISTS "idx_household_auto_contribution_account" ON "household_auto_contribution" ("Idaccount");
```

### 5.2 API

| # | Endpoint | Ai | Thân | Trả về |
|---|---|---|---|---|
| C1 | `PUT /api/households/quotas` | `Owner`, nhà `Active` | `{ dueDay: 1..31, items: [ { idwallet, idaccount, amount } ] }` — thay toàn bộ định mức của nhà | trạng thái nhà |
| C2 | `PUT /api/households/me/auto-contributions/:id` | `Owner` / `Member` của nhà `Active` | `{ idwallet, sourceWalletId, amount, dayOfMonth, enabled }` — tạo hoặc thay cấu hình của **chính mình** | trạng thái nhà |
| C3 | `DELETE /api/households/me/auto-contributions/:id` | chủ cấu hình | — | trạng thái nhà |

Kiểm C1: ví thuộc nhà, chưa xoá; người là thành viên đang ở vai `Owner` / `Member` (khác ⇒ `409 HOUSEHOLD_QUOTA_INVALID_TARGET`); không trùng
(ví, người); số tiền > 0, ≤ 13 chữ số. Kiểm C2: `idwallet` là ví chung của nhà, chưa xoá; `sourceWalletId` là ví **riêng** (`Idhousehold IS
NULL`) của **chính** người gọi, chưa xoá (khác ⇒ `409 HOUSEHOLD_AUTO_CONTRIBUTION_INVALID`); tối đa 10 cấu hình / người; `Enabled_at` = giờ server
khi tạo với `enabled: true` hoặc khi `false → true` (giữ nguyên khi chỉ sửa số tiền / ngày).

### 5.3 Trạng thái nhà

`GET /api/households/me` thêm:

```json
"contributionDueDay": 5,
"contributionQuotas": [ { "idwallet": "8a1c…", "idaccount": 25, "amount": 5000000, "updateAt": "…" } ],
"myAutoContributions": [
  { "id": "f3b0…", "idwallet": "8a1c…", "sourceWalletId": "77d2…", "amount": 2000000,
    "dayOfMonth": 1, "enabled": true, "enabledAt": "2026-10-26T04:00:00.000Z", "updateAt": "…" }
]
```

⚠️ Lọc ở server: `contributionQuotas` — `Owner` mọi dòng, `Member` dòng của mình, `Viewer` `[]`; `myAutoContributions` — **chỉ** của người hỏi
(chứa id ví riêng của họ — không bao giờ trả cho người khác).

### 5.4 Dọn và sự kiện

- Người rời / bị mời ra / đổi sang `Viewer` ⇒ xoá định mức + cấu hình tự góp của họ. Ví chung bị xoá mềm ⇒ xoá định mức + cấu hình trỏ nó.
  Giải tán ⇒ xoá hết. Ví riêng nguồn bị xoá mềm ⇒ giữ cấu hình (client tự *tạm dừng*), không cần backend làm gì.
- C1 và dọn ⇒ `household.changed` tới mọi thành viên. C2 / C3 ⇒ `household.changed` tới **chính tài khoản ấy** (để máy khác của họ làm mới).
- Server **không** chạy tự góp — client chạy (khoản là ghi sổ trên máy, đồng bộ như mọi khoản góp).

## 6. Phía client

- `NhaRepository` nhớ `contributionDueDay`, `contributionQuotas`, `myAutoContributions`.
- `household/domain/`: `dinh_muc_gop.dart` (đã góp ròng, đủ / thiếu, ngày hạn của tháng), `ky_tu_gop.dart` (các kỳ tới hạn từ `enabledAt`, trần 3),
  `id_tu_gop.dart` (id tất định — namespace riêng), luật tạm dừng — Dart thuần.
- `household/application/tu_gop_runner.dart` — gọi `GopQuyService` (`02A`) với id tất định; trả sự kiện cho bộ quét thông báo (khuôn
  `GoalAutoDepositRunner` → `GoalAutoDepositEvent`). Nối vào `NotificationScanner.scan()` **cả** ở `main.dart` lẫn `chay_nen.dart` (bẫy *hai
  đường chạy* của tự chuyển tiền nền); lượt nền `GoiRepository.datTaiKhoan` trước khi quét như bộ hiện có.
- `NotificationKind` thêm `gopConThieu`, `gopChuaDuTongHop`, `tuGopDaChay`, `tuGopKhongChay` (nhóm `giaDinh`).
- Màn **Định mức góp** (Chủ nhà), **Tự góp** (mỗi người), cột đủ / thiếu trong bảng góp — đưa lên Stitch trước.

## 7. Ca biên

- **Đổi hạn góp N giữa tháng:** tháng hiện tại dùng N mới; đã nhắc rồi thì không nhắc lại (khoá theo tháng).
- **Đặt định mức sau ngày N:** nhắc ngay ở lượt quét kế (đã qua hạn).
- **Người mới vào giữa tháng:** định mức áp từ tháng đặt; Chủ nhà tự chọn đặt hay không.
- **Hai máy cùng một người, một máy offline:** máy offline có thể chạy kỳ trước khi kéo được cặp của máy kia ⇒ cùng id ⇒ một hàng trên server.
  Người dùng xoá khoản tự góp ở máy A trong khi máy B chưa kéo cờ xoá mà chạy kỳ ấy ⇒ có thể **hồi sinh** khoản đã xoá (cùng khe hở của bộ trích
  mục tiêu — chấp nhận, ghi ở đây).
- **Ví riêng nguồn cho phép âm** (cờ `allow_negative`): coi như luôn đủ tiền (giống cảnh báo số dư hiện có bỏ qua ví cho phép âm).

## 8. Kiểm thử và nghiệm thu

- **Domain:** đã góp ròng (rút trừ, chặn 0, tiền mặt trao tay, tự góp); ngày hạn tháng 2 / tháng 30 ngày với N = 31; kỳ tự góp từ `enabledAt`
  (bật sau ngày N ⇒ kỳ đầu tháng sau), trả bù 3; id tất định ổn định giữa hai máy khác múi giờ (băm ms UTC).
- **Runner:** chạy một kỳ ⇒ một cặp; chạy lại ⇒ không thêm; hàng đã xoá mềm ⇒ không tạo lại; ví riêng thiếu tiền ⇒ không ghi, sự kiện lỗi, lượt
  sau chạy khi đủ; tạm dừng theo từng lý do.
- **Thông báo:** nhắc một lần mỗi tháng mỗi ví; tổng hợp của Chủ nhà một lần mỗi tháng; không nhắc khi đủ.
- **Backend (đề xuất ca):** C2 với `sourceWalletId` của người khác / ví của nhà ⇒ 409; `/me` của Member không có định mức của người khác, không có
  `myAutoContributions` của ai khác; rời nhà ⇒ cấu hình biến mất.
- **Nghiệm thu hai máy thật:** Chủ nhà đặt định mức 3.000.000 đ / tháng, hạn ngày hôm nay → máy Thành viên nhận nhắc (sau 08:00) → Thành viên bật
  tự góp với kỳ hôm nay → đóng app, chờ lượt nền → khoản góp *(tự động)* xuất hiện ở cả hai máy, thẻ đổi *"Đủ"*.

## 9. Câu hỏi để thảo luận

- **Q-C1** — Hạn góp một ngày cho cả nhà (đề xuất) hay mỗi dòng định mức một ngày riêng?
- **Q-C2** — C1 thay toàn bộ định mức của nhà trong một lần — tiện cho màn *Định mức góp* một trang; backend có muốn tách theo ví?
- **Q-C3** — `Enabled_at` do server ghi (đề xuất — đồng hồ máy có thể sai) hay client gửi lên?

## 10. Trả lời / thảo luận

*(Chờ backend / PO.)*
