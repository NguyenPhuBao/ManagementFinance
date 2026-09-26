# Soát sau gộp `422debf`: tài liệu chatbot AI và bảng 10 chức năng còn lệch mã ở chín chỗ

**Ngày:** 2026-09-26 · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat` @ `610353f` (đã gộp `main` @ `422debf`)
**Loại:** chủ yếu **sửa chữ** trong tài liệu backend quản; mục 7 báo **lỗi mã** để backend tự xếp lịch; mục 8 xin **một
xác nhận**. Client không sửa tệp nào của backend, kể cả một dòng.

---

## Tệp cần đọc

Mọi đường dẫn tính từ gốc repo, đã kiểm tồn tại ngày 2026-09-26. Số dòng là của bản `422debf`; dòng sẽ trôi sau mỗi lần
sửa, nên xin `grep` theo cụm chữ.

**Tài liệu backend cần sửa:**

| Tệp | Chỗ | Mục của đơn |
|---|---|---|
| `docs/AI/LogicBusinessAI.md` | bảng 10 chức năng dòng 32, 33, 36; §4 mục 2 (dòng 76–77) | 1, 2 |
| `Project.md` | §8.5 dòng 1610, 1611, 1614; §11.39 dòng 2684; §11.41 (dòng 2697 và 2770); §11.42 dòng 2722, 2723, 2726; §11.43 dòng 2734–2770 | 1, 2, 4, 6 |
| `docs/AI/ORC.md` | khối "CẬP NHẬT PHÂN CHIA TRÁCH NHIỆM", dòng 73 | 1 |
| `docs/AI/ChatbotAI.md` | dòng 4, 24, 57, 111–119, 256–279, 293, 340–390 | 2, 3, 4 |
| `docs/AI/ChatbotAI_Moblie.md` | dòng 40, 45–64, 194 | 3 |
| `docs/AI/AI_ARCHITECTURE_DIAGRAM.md` | dòng 87, 98 | 5 |
| `docs/superpowers/backend/DA-XONG/README.md` | dòng 84 | 6 |

**Mã backend làm bằng chứng (chỉ đọc):**

| Tệp | Chứng minh điều gì | Mục |
|---|---|---|
| `src/Backend/modules/ai/features/chatbot/chatbot.routes.js` | ba route: `POST /chat/stream`, `GET /snapshot`, `POST /chat`; rate limit của `express-rate-limit`, không có store Redis | 3, 4 |
| `src/Backend/modules/ai/features/chatbot/chatbot.controller.js` | hình dạng các sự kiện SSE `meta` / `delta` / `done` / `error` | 3 |
| `src/Backend/modules/ai/features/chatbot/chatbot.service.js` | `require('@google/generative-ai')` ở dòng 6; mô hình mặc định `gemini-2.5-flash` (dòng 117); `history.slice(-6)` (dòng 132); nhánh fallback (dòng 36–60, 199–211) | 3, 4, 7 |
| `src/Backend/modules/ai/features/chatbot/chatbot.validation.js` | 400 khi `message` rỗng hoặc dài hơn 2000 ký tự | 3 |
| `src/Backend/modules/ai/features/chatbot/snapshot/financial.snapshot.service.js` | cách tính FHS, 50/30/20, quỹ khẩn cấp; cửa sổ 90 ngày; `debtToIncomeRatio: 0.1` | 4, 7 |
| `src/Backend/modules/ai/features/chatbot/tools/tools.executor.js` | tool gửi số tiền từng giao dịch và ghi chú sau `maskPII`; `calculatePeriodDifference` | 4, 7 |
| `src/Backend/modules/ai/features/chatbot/privacy/pii.masker.js` | `maskPII` chỉ gọi `maskTransactionDescription` (che số và email) | 4 |
| `src/Admin-web/src/api/chatbot.api.js` | đọc `delta.content`; gọi `GET /ai/chatbot/financial-health` | 3, 7 |
| `src/Backend/tests/unit/financial.snapshot.test.js` | fixture dựng khoản chi bằng số **dương** | 7 |

**Đơn đã đóng liên quan:** `docs/superpowers/backend/DA-XONG/CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md` §5 (phản hồi 5 câu hỏi)
và `DA-XONG/AI_PHAN_DINH_10_CHUC_NANG_SOAT_C47E6E2.md`.

---

## 0. Tóm tắt

Client đã soát lại bốn đơn backend đóng ở `422debf`:

| Đơn | Kết quả client soát |
|---|---|
| `AI_EDGE_SLM_SOAT_SAU_B147FEE.md` (vòng hai) | ✅ **Đủ 12 chỗ.** Bốn lệnh nghiệm thu ra 0 dòng; B5 và D1 nay nói cùng một cửa sổ cuộn; câu G1 mới khớp mã client (`buocLamTron`). |
| `AI_PHAN_DINH_10_CHUC_NANG_SOAT_C47E6E2.md` | ✅ Ba lệnh nghiệm thu ra 0 dòng; chức năng 7 chốt lối A. Còn lệch mới, xem mục 1 và 2. |
| `CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md` | ✅ Duyệt 5/5. Client sẽ thêm màn xin đồng ý như backend yêu cầu khi thi công. |
| `CLIENT_BO_LIEN_KET_NGAN_HANG.md` | ⚠️ Năm chỗ tài liệu đơn xin sửa **vẫn nguyên** — xem mục 8. |

Lượt soát ấy còn tìm ra các chỗ dưới đây. Mục 1 là **lỗi của client**.

| # | Nhóm | Mức |
|---|---|---|
| 1 | Chức năng 3 nói ngược phản hồi backend vừa duyệt (do câu client đề nghị) | sửa chữ |
| 2 | Chức năng 4 và 7 mang **bốn** trạng thái khác nhau ở bốn chỗ | sửa chữ |
| 3 | **Ba** hợp đồng API khác nhau cho cùng một chatbot (mã, `ChatbotAI.md`, `ChatbotAI_Moblie.md`) | sửa chữ |
| 4 | `ChatbotAI.md` và `Project.md` §11.43 tả những thành phần không có trong mã | sửa chữ |
| 5 | Sơ đồ nối "Financial Health" vào Gemini | sửa chữ |
| 6 | Ba chỗ lặt vặt trong `Project.md` và `DA-XONG/README.md` | sửa chữ |
| 7 | Lỗi mã làm sai các con số mà tài liệu ghi "đã hoàn thành" | báo lỗi |
| 8 | Đơn bỏ liên kết ngân hàng đóng mà năm chỗ tài liệu chưa đổi | xin xác nhận |

---

## 1. 🛑 Chức năng 3 nói ngược phản hồi đã duyệt — lỗi do client đề nghị

Đơn `AI_PHAN_DINH_10_CHUC_NANG_SOAT_C47E6E2.md` (mục 4.3) đề nghị câu: *"Chỉ cần khi có OCR phía client … Kênh ngân
hàng và SMS đã bỏ."* Backend chép đúng câu ấy. Nhưng **cùng ngày** client nộp đơn `CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md`,
và backend đã duyệt ở §5.5 của đơn ấy: *"Cơ chế gộp trùng SMS/thông báo app … chính là hiện thân thực tế của Chức năng 3
(Deduplication) phía Client."* Hai câu nay nằm trong tài liệu và nói ngược nhau. Lỗi ở client: viết đơn thứ hai mà quên
sửa câu đề nghị ở đơn thứ nhất.

**Bốn chỗ đang ghi câu cũ:**

| Tệp | Dòng | Nguyên văn đang ghi |
|---|---|---|
| `LogicBusinessAI.md` | 32 | *"Khử trùng lặp trên client chỉ cần khi và nếu client làm OCR … Kênh ngân hàng và SMS đã dừng/bỏ."* |
| `LogicBusinessAI.md` | 76–77 | *"Phía Client chỉ cần khi triển khai tính năng OCR. Kênh liên kết ngân hàng và SMS server đã dừng."* |
| `Project.md` | 1610, 2722 | *"… khi có OCR; Kênh ngân hàng và SMS đã dừng/bỏ."* |
| `ORC.md` | 73 | *"Phía Client-app chỉ cần triển khai khi làm OCR (tránh quét trùng 1 biên lai)."* |

**Câu đề nghị thay thế** (cho ô mô tả chức năng 3; ba chỗ còn lại rút gọn theo):

> **Client-app:** gộp trùng tin biến động số dư đọc **trên máy** — SMS và thông báo app ngân hàng qua
> `NotificationListenerService` (đã duyệt, `DA-XONG/CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md` §5) — và nhắc khi sổ đã có
> khoản cùng số tiền trong ngày. Chống quét trùng **biên lai** sẽ đặc tả cùng spec OCR phía client. Kênh liên kết ngân
> hàng (SePay) và SMS **phía server** vẫn dừng. **Backend** giữ `dedup.service.js` cho `POST /api/ai/ocr/parse`.
>
> Trạng thái: ⬜ **Chưa làm tại Client** — đang thiết kế tính năng đọc biến động số dư trên máy.

---

## 2. Chức năng 4 và 7: bốn chỗ, bốn trạng thái

| Chỗ | Chức năng 4 (chatbot) | Chức năng 7 (FHS) |
|---|---|---|
| `LogicBusinessAI.md` dòng 33, 36 | 🟡 Đang xây dựng tại Backend | 🟡 Đang xây dựng tại Backend |
| `Project.md` §8.5 dòng 1611, 1614 | 🔴 Chưa hoàn thành | 🔴 Chưa hoàn thành |
| `Project.md` §11.42 dòng 2723, 2726 | 🟢 Đã hoàn thành (Backend + Admin-web) | 🟢 Đã hoàn thành (Backend + Admin-web) |
| `ChatbotAI.md` dòng 4 | 🟢 Đã triển khai xong Backend & Admin-web | — |

Cả bốn đều viết trong cùng lượt `422debf`. Xin chọn **một** trạng thái và ghi giống nhau ở cả bốn chỗ. Khi chọn, lưu ý
hiện trạng đo được trên máy dev ngày 2026-09-26 (chi tiết ở mục 7):

- Backend **không khởi động được** cho tới khi chạy `npm install`, vì thiếu gói `@google/generative-ai` (7.6).
- `.env` dev **không có** `GEMINI_API_KEY`, nên mọi câu hỏi đều nhận cùng một đoạn văn mẫu (7.3).
- Trang Copilot của Admin-web **không hiện chữ** và gọi một route không tồn tại (7.5).
- FHS tính sai dấu trên dữ liệu thật (7.1).

Và phía client: màn Trợ lý AI **chưa nối** chatbot trực tuyến. Việc `ChatbotAI_Moblie.md` giao cho client đang chờ người
dùng quyết, chưa có kế hoạch.

---

## 3. Ba hợp đồng API khác nhau cho cùng một chatbot

Client cần **một** hợp đồng để làm theo nếu nhận việc. Hôm nay có ba, cộng một bản thứ tư là cách Admin-web đọc:

| Điểm | Mã server (thật) | `ChatbotAI.md` | `ChatbotAI_Moblie.md` | Admin-web `chatbot.api.js` |
|---|---|---|---|---|
| Endpoint FHS | `GET /api/ai/chatbot/snapshot` | `GET …/financial-health` (dòng 293, 367) | `GET …/snapshot` | `GET …/financial-health` (dòng 128) |
| Khoá chữ của `delta` | `{"text": …}` | `{"content": …}` (dòng ~355) | `{"text": …}` | đọc `content` (dòng 89) |
| `meta` | `{snapshotLoaded, healthScore, snapshot}` | `{fhs: {score, classification, metrics}, ragSnippets}` (dòng 352) | `{snapshotLoaded, healthScore, topExpense}` (dòng 46) | chuyển nguyên cho trang |
| `done` | `{responseTimeMs}` ở nhánh Gemini; `{status:"completed"}` ở nhánh fallback; `{error}` khi fallback cũng hỏng | — | `{status, responseTimeMs}` (dòng 58) | — |
| Lỗi Gemini | **không** trả 503: phát đoạn văn fallback dưới dạng `delta` bình thường | circuit breaker trả lỗi (dòng 272) | `503` + gợi ý chuyển offline (dòng 64) | đọc `event: error` |
| Giới hạn đầu vào | 400 nếu `message` rỗng hoặc > 2000 ký tự, `history` không phải mảng | — | không nhắc | — |
| `history` | server chỉ giữ **6** tin cuối | — | *"6–10 tin"* (dòng 40) | — |

**Đề nghị:** lấy **mã server** làm nguồn sự thật (hoặc sửa mã, rồi sửa tài liệu theo), cập nhật hai tài liệu theo đúng một
hợp đồng. Cột Admin-web là lỗi mã, xem 7.5.

Riêng `ChatbotAI_Moblie.md` dòng 194 *"Tạo bảng `LocalChatMessages` trên Drift SQLite v24"*: thêm một bảng là nâng schema
lên **v25**. Chi tiết lược đồ phía client sẽ do client chốt nếu nhận việc; đề nghị bỏ số phiên bản khỏi câu ấy.

---

## 4. `ChatbotAI.md` và `Project.md` §11.43 tả những thứ không có trong mã

`grep -rniE "redis|circuit|cache" src/Backend/modules/ai/features/chatbot` chỉ ra đúng **một** dòng (header
`Cache-Control` của SSE, `chatbot.controller.js:23`).

| Tài liệu nói | Mã làm |
|---|---|
| *"Redis Token-Bucket Limiter"* (`ChatbotAI.md` dòng 111, 256, 264) | `express-rate-limit` **mặc định bộ nhớ trong tiến trình**, không có store Redis |
| *"Semantic Cache trên Redis (TTL 1h)"*, *"Snapshot Cache (TTL 120s)"* (dòng 267–268) | không có cache nào; mỗi lượt chat tính snapshot từ đầu |
| *"Circuit Breaker: 5 lần lỗi / 1 phút → OPEN 30 giây"* (dòng 261, 272) | không có; lỗi nào cũng rơi vào nhánh fallback |
| *"PII Masking & Anonymizer — Khử toàn bộ tên riêng, STK, SĐT, làm tròn số"* (dòng 113) | `maskPII` chỉ che dãy số và email. Tên danh mục, tên hoá đơn do người dùng đặt đi sang Gemini nguyên văn, trừ phần là dãy số hay email; tool `get_category_transactions` gửi **số tiền từng giao dịch, không làm tròn** |
| *"Gemini không thể và không được phép nhìn thấy … tên tiệm cụ thể, nội dung chuyển khoản nhạy cảm"* (dòng 24) | tool gửi **ghi chú giao dịch** sau `maskPII`. Module chatbot không gọi hàm giải mã nào: ghi chú nằm trong CSDL ở dạng nào thì đi sang Gemini ở dạng ấy (máy dev không đặt `DATA_ENCRYPTION_KEY`) |
| *"Toàn bộ số liệu tài chính trong Snapshot và Tools … đều được làm mờ (anonymize) và che giấu ghi chú giao dịch"* (`Project.md` §11.43) | như hai dòng trên: snapshot có gộp, **tools thì không** |
| *"Google Gemini 2.0 Flash"* (dòng 57, 119, 279) | chatbot dùng `process.env.GEMINI_MODEL \|\| 'gemini-2.5-flash'` (`Project.md` §11.43 ghi đúng 2.5) |
| *"Công thức thu nhập thực tế chuẩn `thuNhapCua`"* (`Project.md` §11.43) | `calculateValidIncome` loại theo **từ khoá tên danh mục** (`'vay'`, `'nợ'`, `'mượn'`…). `thuNhapCua` của client loại theo **phân loại** `vay_no` và chiều tiền; đổi tên danh mục là hai bên lệch |
| *"Tỷ lệ nợ trên thu nhập (`debtToIncomeRatio`)"* (`ChatbotAI.md` dòng 381, `Project.md` §11.43) | truyền **hằng** `0.1` vào hàm chấm điểm; không có trong kết quả trả về. `hasHighInterestDebt` luôn `false` |

⚠️ Hai dòng về riêng tư ở trên cũng là chỗ **quyết định F1** (mục 1.3 đơn `AI_PHAN_DINH…`) hiện ra trong mã: chatbot trực
tuyến gửi sang Google cả **số tiền từng giao dịch** lẫn **ghi chú** khi Gemini gọi tool. Client không đề nghị đổi mã. Chỉ xin
tài liệu **tả đúng** điều mã đang làm, và ghi quyết định F1 kèm ngày chốt.

---

## 5. Sơ đồ: "Financial Health" không gọi Gemini

`AI_ARCHITECTURE_DIAGRAM.md` dòng 87 vẽ `Health --> Gemini`; dòng 98 viết *"đánh giá sức khỏe tài chính … kết hợp trí tuệ
Google Gemini"*. Trong mã, `GET /snapshot` tính FHS **tất định** (`financial.snapshot.service.js`) và không gọi mô hình
nào. Gemini chỉ **đọc** điểm ấy khi viết câu trả lời chat.

**Đề nghị:** bỏ mũi tên `Health --> Gemini`, hoặc thay bằng `Health --> Chat` (snapshot đi vào ngữ cảnh của trợ lý).

---

## 6. Ba chỗ lặt vặt

| Tệp | Dòng | Chỗ lệch | Đề nghị |
|---|---|---|---|
| `Project.md` | 2697 và 2770 | **Hai** mục cùng số `### 11.41` (Edge AI và Múi giờ) | đánh lại số mục Múi giờ |
| `Project.md` | 2684 (§11.39) | D1 *"thu nhập theo `thuNhapCua()`, **TB 3 tháng liền trước**"* — nói ngược D1 đã sửa trong `AI_Edge-SLM.md/Client-app.md` (cửa sổ cuộn theo ngày) | chép câu D1 mới, hoặc ghi "xem D1 của đặc tả" |
| `DA-XONG/README.md` | 84 | trỏ *"vòng hai `CAN-LAM/AI_EDGE_SLM_SOAT_SAU_B147FEE.md`"* — tệp ấy nay ở `DA-XONG/` | đổi đường dẫn |

---

## 7. Lỗi mã làm sai các con số tài liệu ghi "đã hoàn thành"

Client chưa gọi chatbot, nên không lỗi nào chặn client. Ghi lại vì chúng làm sai **đúng những con số** mà tài liệu mô tả
và mà `ChatbotAI_Moblie.md` giao client hiển thị.

### 7.1 Khoản chi lưu **âm** trên PostgreSQL, mã chatbot cộng như số dương

Đo 2026-09-26 bằng truy vấn **đọc** trên CSDL dev:

```sql
SELECT c."Classify", t."Type", sign(t."Amount"), count(*)
FROM "transaction" t LEFT JOIN category c ON c."Idcategory" = t."Idcategory"
WHERE t."Deleted_at" IS NULL GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;
```

Kết quả: **23/23** hàng `Chi` mang số **âm**, **6/6** hàng `Thu` mang số dương. Client đẩy số tiền kèm dấu theo chiều tiền.
Hệ quả trong `financial.snapshot.service.js` với dữ liệu thật:

| Chỗ | Mã | Kết quả trên dữ liệu thật |
|---|---|---|
| `avgMonthlyExpense` | `totalExpense > 0 ? … : 0` | tổng chi âm → **0** → `emergencyFundMonths` luôn **0** |
| `calculate50_30_20` | chia tổng từng nhóm cho thu nhập | tỉ lệ **âm** khi có thu nhập, **0/0/0** khi không có |
| Top 3 danh mục chi | `sort((a, b) => b[1] - a[1])` | danh mục chi **ít nhất** lên đầu |
| `compare_spending_periods` (`tools.executor.js`) | `diff = p1 − p2`; `%` chỉ tính khi `p2 > 0` | chi **tăng** thành `trend: "decreased"`; phần trăm luôn `"0%"` |

Test `tests/unit/financial.snapshot.test.js` dựng khoản chi bằng số **dương** (dòng 29–31), nên nó xanh trong khi dữ liệu
thật sai.

### 7.2 Mẫu số 90 ngày cố định

`daysSpan = Math.max(14, (now − ninetyDaysAgo) / ngày)` luôn bằng **90**. Tài khoản mới 20 ngày tuổi bị chia cho 90 ngày,
nên chi mỗi tháng thấp đi **4,5 lần**, và quỹ khẩn cấp phình đúng chừng ấy (sau khi 7.1 được sửa). Client từng vấp đúng
bẫy này và sửa bằng `cuaSoNhinLai`: mẫu số là **tuổi dữ liệu của tài khoản**, `[max(now − 90 ngày, giao dịch đầu tiên),
now)`, dưới 14 ngày thì không trả số. Đó cũng là D1 hiện hành của `AI_Edge-SLM.md/Client-app.md`.

### 7.3 Nhánh fallback bịa số và phát như câu trả lời thật

Khi thiếu `GEMINI_API_KEY` hoặc Gemini lỗi, `_streamFallbackResponse` phát cùng một đoạn văn cho **mọi câu hỏi**, dưới dạng
`delta` bình thường. Client không phân biệt được nó với câu trả lời thật (xem hàng "Lỗi Gemini" ở mục 3). Đoạn văn ấy còn
thay số thật bằng số dựng sẵn:

```js
const score = snapshot.financialHealthScore || 70;
const emergency = snapshot.liquidityAndObligations?.emergencyFundMonths || 1.5;
```

Với 7.1, quỹ khẩn cấp thật là **0**, nên câu hiện ra *"khoảng 1.5 tháng"* là một con số **không đến từ dữ liệu nào**.
`generateSnapshot` cũng trả FHS cứng **65** và 50/30/20 khi truy vấn lỗi. Phía client, màn Trợ lý AI cấm đúng loại lỗi này
bằng lớp chắn `kiemSo`.

### 7.4 Hằng số trong điểm FHS

`debtToIncomeRatio: 0.1` và `hasHighInterestDebt: false` là hằng, nên phần "nợ" của điểm FHS giống nhau cho mọi tài khoản
(xem bảng mục 4).

### 7.5 Trang Copilot của Admin-web không hiện chữ và gọi route không tồn tại

`src/Admin-web/src/api/chatbot.api.js`:

- dòng 89 chỉ gọi `onDelta` khi `deltaData.content` có giá trị, mà server gửi `{"text": …}` → **không chữ nào hiện**;
- dòng 128 gọi `GET /ai/chatbot/financial-health`, mà `chatbot.routes.js` chỉ có `/snapshot` → **404**, thẻ FHS không có
  số.

`npm run build` thành công không bắt được hai lỗi này, vì cả hai là lệch hợp đồng lúc chạy.

### 7.6 Backend dev không khởi động sau khi gộp

`chatbot.service.js:6` gọi `require('@google/generative-ai')` ở đầu tệp, và chuỗi nạp là `api/index.js` →
`api/ai.routes.js:9` → `chatbot.routes.js` → `chatbot.controller.js` → `chatbot.service.js`. Trên máy dev của client,
`require.resolve('@google/generative-ai')` trả `MODULE_NOT_FOUND`, nên `npm run dev` dừng ngay lúc nạp. `package.json` và
`package-lock.json` đã khai gói. Chỉ cần mỗi máy chạy `npm install` (hoặc `npm ci`) trong `src/Backend`; đề nghị ghi câu ấy
vào `docs/Deploy/CloudDeploy.md` hoặc `Project.md` §11.43, vì client dùng backend dev để đo đồng bộ.

---

## 8. Xin xác nhận: đơn bỏ liên kết ngân hàng

`CAN-LAM/README.md` mục 1 và `DA-XONG/README.md` mục 4 ghi đơn `CLIENT_BO_LIEN_KET_NGAN_HANG.md` đóng bằng *"PO duyệt
giữ nguyên mã nguồn và tài liệu làm baseline"*. Đơn ấy **không xin đổi mã** (mục 2 của đơn: *"Backend có phải làm gì về mã
không — không"*); nó xin sửa **năm chỗ tài liệu** đang tả phía client là có tính năng liên kết ngân hàng. Đo 2026-09-26:

| Tệp | Hiện trạng |
|---|---|
| `Project.md` | dòng 992 vẫn giao *"Liên kết ngân hàng — Backend + Mobile"*, không có dấu tạm dừng; dòng 1074–1075 có dấu ⏸️ nhưng vẫn ghi `Mobile` |
| `docs/progress/Client-app.md` | commit cuối 2026-09-10, không banner; mục 3 (Bank Inbox UI) còn nguyên |
| `docs/Rule_Project/Rule_project.md` | commit cuối 2026-09-13 |
| `docs/progress/Backend.md` | commit cuối 2026-09-21 (dừng Module Bank); hai dòng 60, 75 chưa đổi |
| `docs/Bank/Client-app.md` | commit cuối 2026-09-09, không banner |

Nếu giữ nguyên là **cố ý**, xin một dòng xác nhận trong `DA-XONG/CLIENT_BO_LIEN_KET_NGAN_HANG.md`; client sẽ ghi các tệp ấy
là ảnh chụp lịch sử trong tài liệu phía client. Nếu không cố ý, lệnh kiểm ở mục 4 của đơn ấy vẫn dùng được.

---

## 9. Nghiệm thu

Sau khi sửa, các lệnh sau (chạy từ gốc repo) phải ra **0** dòng:

```bash
# Mục 1 — không còn nói chức năng 3 "chỉ khi có OCR"
grep -n "chỉ cần khi và nếu client làm OCR\|chỉ cần khi triển khai tính năng OCR\|chỉ cần triển khai khi làm OCR\|khi có OCR; Kênh" \
  docs/AI/LogicBusinessAI.md Project.md docs/AI/ORC.md

# Mục 3 — một tên endpoint, một khoá chữ (hai lệnh dưới giả định giữ tên của mã: `/snapshot`, `text`;
# nếu backend chọn đổi mã sang `/financial-health` / `content` thì đảo lại mẫu tìm)
grep -rn "financial-health" docs/AI Project.md src/Admin-web/src
grep -n '"content"' docs/AI/ChatbotAI.md

# Mục 4 — không còn tả thành phần không có
grep -n "Redis Token-Bucket\|Semantic Cache\|Circuit Breaker\|làm tròn số" docs/AI/ChatbotAI.md

# Mục 5 — FHS không nối Gemini
grep -n "Health --> Gemini" docs/AI/AI_ARCHITECTURE_DIAGRAM.md

# Mục 6 — một mục 11.41
grep -c "^### 11.41" Project.md   # phải ra 1
```

Và mục 2: bốn chỗ ghi cùng một trạng thái cho chức năng 4 và 7.

Client sẽ chạy lại các lệnh trên sau khi backend báo xong, và đối chiếu mục 7 bằng chính truy vấn ở 7.1.
