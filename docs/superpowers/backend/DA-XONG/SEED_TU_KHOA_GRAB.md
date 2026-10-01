# Xin sửa seed: từ khoá mặc định `grab` gắn cho Ăn uống làm mọi ghi chú "grab …" bị xếp nhầm

**Ngày:** 2026-09-29 · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat`
**Loại:** xin đổi **dữ liệu seed** của hai danh mục mặc định. **Không** đổi lược đồ, **không** trường đồng bộ mới,
client **không** phải đổi mã. Người dùng (PO phía client) duyệt viết đơn này ngày 2026-09-29.

---

## Tệp cần đọc

| Tệp | Vì sao |
|---|---|
| `src/Backend/prisma/seed.js:14–15` | hai dòng seed đang gây nhầm |
| `src/Backend/modules/ai/features/classify/pipeline/keyword.matcher.js` | Tầng 1 phân loại của backend — khớp **chuỗi con** |
| `src/Backend/modules/ai/features/classify/pipeline/training-data.csv:11` | dữ liệu huấn luyện của chính backend gán `"grab di lam"` → **Di chuyển** |
| `docs/CATEGORY_RATIONALE.md` mục 5d | số đo phía client (B1 — gợi ý danh mục học từ ghi chú) |

---

## 1. Đo được gì

**Seed hiện tại** (`seed.js:14–15`):

```js
{ id: '8e06aaf6-…', name: 'Ăn uống',   keyword: 'an uong, food, grab' },
{ id: '08639bd7-…', name: 'Di chuyển', keyword: 'di chuyen, xang, grabcar' },
```

Cả hai bộ so khớp từ khoá đều coi là khớp khi **văn bản chứa từ khoá**:

- phía client: `CategorySuggestionEngine` (`text.contains(keyword)`), thẻ *"Gợi ý danh mục"* ở màn Thêm giao dịch;
- phía backend: `keyword.matcher.js` dòng 68–69 (`fullSearchText.includes(kw)`), Tầng 1 của F012.

Nên mọi ghi chú dạng *"grab đi làm"*, *"grab về nhà"* — cách người Việt thường ghi một cuốc xe — chứa `grab` mà không
chứa `grabcar`, và bị xếp **Ăn uống**:

- **Client, Realme, 2026-09-29:** 6 giao dịch ghi chú *"grab …"* người dùng tự chốt **Di chuyển** → bộ từ khoá gợi ý
  **Ăn uống** cả 6 lần (**đúng 0/6**, đo leave-one-out bằng `test/tool/do_goi_y_danh_muc_test.dart`).
- **Backend, đọc mã:** với `"grab di lam"`, Tầng 1 trả **Ăn uống** độ tin 0,99 (`grab` không dấu nên khớp ngay ở
  nhánh có dấu, dòng 68 và 80), trong khi
  `training-data.csv:11` của chính backend ghi `"grab di lam",Di chuyen`. Hai nguồn sự thật của backend nói ngược nhau.

## 2. Đề nghị

Đổi seed hai dòng:

```js
{ id: '8e06aaf6-…', name: 'Ăn uống',   keyword: 'an uong, food, grabfood' },
{ id: '08639bd7-…', name: 'Di chuyển', keyword: 'di chuyen, xang, grab, grabcar' },
```

Kiểm bằng tay với luật hiện có của **cả hai** bộ so khớp (từ khoá dài hơn thắng):

| Ghi chú | Khớp | Kết quả |
|---|---|---|
| `grab di lam` | Di chuyển {`grab`} | **Di chuyển** ✅ (nay: Ăn uống) |
| `grabcar ve nha` | Di chuyển {`grab`, `grabcar`} | **Di chuyển** ✅ |
| `grabfood com trua` | Di chuyển {`grab`} · Ăn uống {`food`, `grabfood`} | **Ăn uống** ✅ — nhiều từ khoá hơn (client) / `grabfood` dài hơn (backend) |

Và cập nhật hai hàng mặc định toàn cục trên CSDL đang chạy, theo quy ước `src/Backend/database/N_*.sql`
(`docs/Rule_Project/Rule_project.md` §3.2; số kế tiếp do backend chọn):

```sql
UPDATE category SET "Keyword" = 'an uong, food, grabfood',       "Update_at" = now()
 WHERE "Idcategory" = '8e06aaf6-4608-4cb3-8770-2c2c1eae25b6' AND "Is_default" = true;
UPDATE category SET "Keyword" = 'di chuyen, xang, grab, grabcar', "Update_at" = now()
 WHERE "Idcategory" = '08639bd7-ef8f-4c58-ae8a-7f58198ad79b' AND "Is_default" = true;
```

## 3. Phạm vi hiệu lực — điều cần biết trước khi làm

- **Chỉ tài khoản / máy MỚI nhận bộ mới.** Client gieo từ khoá của danh mục kéo về **chỉ khi danh mục ấy chưa có từ
  khoá nào trên máy** (`_gieoTuKhoaKhiTrong`, `src/Client-app/lib/core/sync/sync_engine.dart`) — cố ý, để thao tác xoá từ
  khoá của người dùng không bị hồi sinh. Máy đã gieo giữ nguyên `grab` → Ăn uống cho tới khi người dùng tự sửa ở màn
  Quản lý danh mục.
- **Bản sao danh mục của từng tài khoản** (hàng `Is_default = false` tạo từ khuôn, từ 2026-09-07) mang cột `Keyword` riêng
  do client đẩy lên — hai câu `UPDATE` trên **không** đụng tới chúng (lọc `Is_default = true`).
- Người dùng đã có lịch sử thì phía client **đã tự sửa được** từ 2026-09-29: gợi ý học từ ghi chú (B1) đi **trước** bộ từ
  khoá (Realme: gợi ý học phủ 11/12 mẫu và đúng cả 11; thẻ hiện *"Bạn thường ghi “grab” cho Di chuyển (5/5 lần)"*).
  Đơn này cần cho **người dùng mới** — đúng lúc B1 chưa có gì để học.

## 4. Câu hỏi cho backend

| # | Câu hỏi | Mặc định của client |
|---|---|---|
| 1 | Đổi seed + cập nhật hai hàng mặc định như mục 2? | **có** |
| 2 | Có sửa luôn từ khoá trên **bản sao** danh mục của tài khoản đã tồn tại không? | **không** — đó là dữ liệu riêng của người dùng, sửa được trong app |
| 3 | Tầng 2–3 của F012 (`nlp.matcher.js`, `llm.classifier.js`) hay dữ liệu huấn luyện có chỗ nào khác gán `grab` cho Ăn uống không? | backend tự soát |

## 5. Kiểm lại

```bash
grep -n "grab" src/Backend/prisma/seed.js
# Ăn uống không còn `grab` đứng riêng; Di chuyển có `grab`
```

```sql
SELECT "NameCategory", "Keyword" FROM category
 WHERE "Idcategory" IN ('8e06aaf6-4608-4cb3-8770-2c2c1eae25b6', '08639bd7-ef8f-4c58-ae8a-7f58198ad79b');
-- Ăn uống | an uong, food, grabfood
-- Di chuyển | di chuyen, xang, grab, grabcar
```

Phía client, sau khi backend báo xong: đăng ký một tài khoản **mới** trên máy chưa từng đăng nhập, mở Thêm giao dịch,
gõ *"grab di lam"* → thẻ gợi ý phải là **Di chuyển** (*"Khớp với “grab” trong ghi chú."*). Client báo lại kết quả trong
một đơn soát như các lần trước.
