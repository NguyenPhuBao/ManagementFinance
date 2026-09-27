# Còn lệch sau `eceb6c9`: tên mô hình ba phiên bản, hằng nợ, ba câu tài liệu, và ba chỗ mã của snapshot

**Ngày:** 2026-09-27 · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat` @ `8bbdd97` (fast-forward tới `main`)
**Loại:** mục 1–4 **sửa chữ** trong tài liệu backend quản; mục 5–7 báo **lỗi mã** để backend tự xếp lịch. Client không
sửa tệp nào của backend. Đơn trước `DA-XONG/CHATBOT_AI_SOAT_SAU_422DEBF.md` client đã soát: 8/9 mục xong, cảm ơn — đơn này
chỉ gom phần còn lại và phần mới lộ ra khi đo thật.

---

## Tệp cần đọc

Số dòng là của bản `8bbdd97`, sẽ trôi sau mỗi lần sửa — xin `grep` theo cụm chữ.

| Tệp | Chỗ | Mục |
|---|---|---|
| `docs/AI/ChatbotAI.md` | dòng 57, 277 (*2.0*); 119, 261, 411, 436 (*2.5*); 113; 189 | 1, 3, 2 |
| `Project.md` | §11.43 dòng 2738 (*3.8*), 2744, 2758 | 1, 2, 4 |
| `docs/AI/AI_ARCHITECTURE_DIAGRAM.md` | dòng 98 (*2.5*) | 1 |
| `docs/Deploy/CloudDeploy.md` | dòng 126 (*2.5*) | 1 |
| `docs/AI/ChatbotAI_Moblie.md` | §2.1 khối SSE (`event: done`) và mục *"Mã lỗi & Cơ chế dự phòng"* | 5 |
| `src/Admin-web/src/pages/ai/AICopilotPage.jsx` | dòng 161 (*2.5*) | 1 |
| `src/Backend/modules/ai/features/chatbot/chatbot.service.js` | dòng 3 (*2.0*), 122 (*3.8*) | 1 |
| `src/Backend/modules/ai/features/chatbot/snapshot/financial.snapshot.service.js` | dòng 78–85 (từ khoá 50/30/20), 239–242 (truy vấn ngân sách), 303–311 (cảnh báo), 319 và 333 (hằng nợ), 353–361 (nhánh lỗi) | 2, 6, 7 |
| `src/Backend/modules/ai/features/chatbot/tools/tools.executor.js` | dòng 81 (`maskPII(tx.note)` không truyền `userName`), 78 (`amount` không làm tròn) | 3 |
| `src/Backend/utils/masking.util.js` | dòng 173–177 (che họ tên chỉ khi có `options.userName`) | 3 |

Phép đo ở mục 6–7 chạy bằng `new FinancialSnapshotService().generateSnapshot(10, { bypassCache: true })` từ `src/Backend`
trên CSDL dev ngày 2026-09-27, sau `npm install`.

---

## 1. Tên mô hình Gemini của chatbot mang ba phiên bản

Commit `69a5f91` đổi mặc định sang `gemini-3.8-flash` ở **hai** chỗ (`chatbot.service.js:122`, `Project.md:2738`), còn
các chỗ khác cùng nói về **chatbot** vẫn ghi:

| Phiên bản | Chỗ |
|---|---|
| 2.0 | `ChatbotAI.md:57` (*"gửi thẳng tới Gemini 2.0 Flash"*), `:277`; `chatbot.service.js:3` (chú thích đầu tệp) |
| 2.5 | `ChatbotAI.md:119, 261, 411, 436`; `AI_ARCHITECTURE_DIAGRAM.md:98`; `CloudDeploy.md:126`; `AICopilotPage.jsx:161` (nhãn hiện cho người dùng) |
| 3.8 | `chatbot.service.js:122`; `Project.md:2738` |

OCR và phân loại tầng 3 dùng `vision.extractor.js` / `llm.classifier.js` với tên riêng — **không** nằm trong đơn này.

**Đề nghị:** một tên, ghi ở một chỗ (`process.env.GEMINI_MODEL` + mặc định trong mã) và các tài liệu dẫn *"theo
`GEMINI_MODEL`, mặc định X"* thay vì chép số. Client **không kiểm được** `gemini-3.8-flash` có tồn tại trên API không
(máy dev không có `GEMINI_API_KEY`); nếu không tồn tại thì mọi lượt chat rơi vào fallback qua circuit breaker và người
dùng chỉ thấy thông báo lỗi.

---

## 2. Hằng nợ (7.4 của đơn trước) vẫn chưa sửa, tài liệu vẫn kể là chỉ số

- `financial.snapshot.service.js:319` truyền `debtToIncomeRatio: 0.1` — **hằng**, nên phần "nợ" của điểm FHS (tối đa 20
  điểm ở thang này) giống nhau cho mọi tài khoản.
- `:333` `hasHighInterestDebt: false` — hằng.
- `Project.md:2744` ghi *"Chỉ số Quỹ khẩn cấp (`emergencyFundMonths`) và Tỷ lệ nợ trên thu nhập (`debtToIncomeRatio`)"*
  như hai chỉ số tính ra; `ChatbotAI.md:189` cho ví dụ `"hasHighInterestDebt": true` — giá trị mã **không bao giờ** trả.

**Đề nghị:** hoặc tính từ dữ liệu có (khoản `Vay/no` chiều tiền vào trên thu nhập hợp lệ trong cùng cửa sổ — đủ cho
`debtToIncomeRatio`; `hasHighInterestDebt` thì CSDL **không có** lãi suất, nên bỏ hẳn trường ấy), hoặc bỏ hai trường khỏi
snapshot và khỏi hai câu tài liệu. Đừng giữ hằng dưới tên một chỉ số.

---

## 3. `ChatbotAI.md:113` hứa hai điều mã không làm

Ô sơ đồ ghi *"PII Masking & Anonymizer — Khử toàn bộ tên riêng, STK, SĐT, làm tròn số"*:

- **Làm tròn số:** `tools.executor.js:78` gửi `Math.abs(Number(tx.amount))` — số tiền **chính xác từng đồng** của từng
  giao dịch; snapshot thì đã gộp thành `%`. Không chỗ nào làm tròn.
- **Tên riêng:** `masking.util.js:173–177` chỉ che họ tên khi chỗ gọi truyền `options.userName`; `grep "maskPII("` trong
  `modules/ai/features/chatbot` ra **năm** chỗ gọi, **không** chỗ nào truyền. Tên danh mục, tên hoá đơn, tên trong ghi
  chú đi sang Gemini nguyên văn (trừ phần là dãy số hay email).

**Đề nghị:** sửa ô ấy thành điều mã làm — *"che STK, SĐT, email, CCCD, OTP, số thẻ (Luhn); số tiền tool gửi chính xác"* —
hoặc sửa mã cho khớp (truyền `userName` từ `req.user` ở ba đường vào của `chatbot.service.js`, và làm tròn số tiền tool về
bội 1.000 đ nếu muốn giữ chữ "làm tròn").

---

## 4. `Project.md:2758` vẫn tả hai endpoint và tên cũ

Nguyên văn: *"Gắn tại `/api/ai/chatbot` với 2 endpoint: `POST /chat/stream` (Rate limit 15 req/phút/user) và
`GET /financial-health` (lấy ngay chỉ số FHS)"*. Mã có **ba** route: `POST /chat/stream`, `GET /snapshot` (alias
`/financial-health`), `POST /chat`. `ChatbotAI.md:291, 370` đã sửa đúng ở `eceb6c9`; câu này bị sót.

---

## 5. `ChatbotAI_Moblie.md` chưa tả `done.fallback` — thứ duy nhất client phân biệt được lỗi với câu trả lời

Từ `eceb6c9`, khi thiếu `GEMINI_API_KEY`, Gemini lỗi, hoặc circuit breaker mở, server phát thông báo dưới dạng **`delta`
bình thường** rồi `done` mang `{"fallback": true, "reason": "…"}` (`chatbot.service.js` `_streamFallbackResponse`).
`ChatbotAI_Moblie.md` §2.1 chỉ tả `done: {"responseTimeMs": 720}`, và mục *"Mã lỗi & Cơ chế dự phòng"* nói *"Backend gửi
trực tiếp thông báo hệ thống"* mà không nói **client nhận biết bằng gì**. Nếu client lưu lịch sử chat (bảng
`LocalChatMessages` tệp ấy đề nghị), thông báo lỗi sẽ được lưu như một câu trả lời của mô hình và gửi lại trong `history`
ở lượt sau.

**Đề nghị:** ghi vào §2.1 hình dạng `done` của cả hai nhánh, kèm câu *"client không lưu lượt có `done.fallback === true`
vào lịch sử"*. Tốt hơn nữa (tuỳ backend): phát nhánh ấy bằng `event: notice` riêng thay vì `delta`, để client không
phải đợi tới `done` mới biết những chữ vừa hiện không phải câu trả lời.

---

## 6. Mã: nhánh lỗi của `generateSnapshot` vẫn bịa số (cùng loại 7.3 đã sửa cho fallback chat)

`financial.snapshot.service.js:353–361`: khi truy vấn lỗi, trả `healthScore: 65`, `needs 50 / wants 30 / savings 20`,
`emergencyFundMonths: 1.5` — những con số **không đến từ dữ liệu nào**, đi qua `anonymizeSnapshot` rồi vào `meta` của
SSE, vào prompt của Gemini, và vào thẻ FHS của Admin-web như số thật. Fallback chat đã đổi sang thông báo minh bạch ở
`eceb6c9`; chỗ này bị sót.

**Đề nghị:** trả `null` (hoặc `{ error: true, reason }`) và để chỗ gọi quyết: `handleGetSnapshot` trả 503 có `code`,
`streamChatResponse` bỏ snapshot khỏi prompt và ghi `meta.snapshotLoaded: false` (trường ấy đã có).

---

## 7. Mã: hai chỗ làm sai con số của snapshot, đo được trên tài khoản 10

### 7.1 Cảnh báo ngân sách không lọc kỳ, một danh mục báo hai lần

`:239–242` lấy **mọi** ngân sách `delete_at IS NULL`, không lọc theo kỳ hay cờ hết hạn; `:303–311` duyệt từng hàng.
Tài khoản 10 trả:

```
"overBudgetAlerts": ["Di chuyển đã chạm 143% hạn mức", "Di chuyển đã chạm 570% hạn mức", "Giáo dục đã chạm 90% hạn mức"]
```

Hai dòng "Di chuyển" là hai hàng ngân sách của cùng danh mục — ít nhất một hàng đã qua kỳ. Client lọc `isExpired` và chỉ
xét kỳ chứa `now` (`watchBudgets(now:)`); tài liệu client từng vấp đúng chỗ này (`docs/ANALYTICS_FEATURE.md`, *"% ngân
sách … phải lọc `isExpired`"*).

**Đề nghị:** lọc ngân sách còn hiệu lực tại `now` (theo `Start_date`/`End_date` hoặc cờ tương đương) trước khi duyệt; mỗi
danh mục tối đa một dòng cảnh báo.

### 7.2 50/30/20 xếp theo từ khoá nên bỏ sót phần lớn chi tiêu

`:78–85` xếp nhóm bằng danh sách từ khoá trên **tên danh mục**; danh mục không khớp từ khoá nào **rơi ngoài cả ba nhóm**.
Tài khoản 10:

```
"budgetAllocation": {"needs_essential": "0%", "wants_lifestyle": "6%", "savings_debt": "0%"}
"topExpenseCategories": [Di chuyển 42%, Chi khác 36%, Mua sắm 7%]
```

*"Di chuyển"* không khớp `'đi lại'`, *"Chi khác"* không khớp gì — 78 % chi tiêu biến mất khỏi cơ cấu, và `savingsRatio`
suy từ `savings_percent` nên điểm FHS lệch theo. Bộ danh mục **mặc định** của server có 13 hàng với tên cố định
(`Ăn uống`, `Di chuyển`, `Mua sắm`, `Giáo dục`, `Giải trí`, `Nhà cửa`, `Y tế`, `Chi khác`, …) — từ khoá nên bắt đầu từ
đúng bộ ấy, và danh mục không khớp cần một nhóm **mặc định** (đề nghị *wants*) thay vì bị bỏ. Danh mục người dùng tự
đặt thì không cách nào xếp đúng bằng tên; đó là giới hạn nên **ghi rõ** trong `ChatbotAI.md` thay vì để con số trông
như đã phân loại đủ.

---

## 8. Nghiệm thu

Sau khi sửa, chạy từ gốc repo:

```bash
# Mục 1 — một tên mô hình cho chatbot (giả định giữ 3.8; chọn tên khác thì đảo mẫu)
grep -rn -e "Gemini 2.0" -e "gemini-2.0" -e "Gemini 2.5" -e "gemini-2.5" \
  docs/AI/ChatbotAI.md docs/AI/ChatbotAI_Moblie.md docs/AI/AI_ARCHITECTURE_DIAGRAM.md docs/Deploy/CloudDeploy.md \
  src/Backend/modules/ai/features/chatbot src/Admin-web/src/pages/ai        # 0 dòng

# Mục 2 — không còn hằng dưới tên chỉ số
grep -n "debtToIncomeRatio: 0.1\|hasHighInterestDebt: false" \
  src/Backend/modules/ai/features/chatbot/snapshot/financial.snapshot.service.js   # 0 dòng

# Mục 3 — ô sơ đồ nói đúng
grep -n "làm tròn số\|Khử toàn bộ tên riêng" docs/AI/ChatbotAI.md               # 0 dòng

# Mục 4 — không còn "2 endpoint"
grep -n "với 2 endpoint" Project.md                                              # 0 dòng

# Mục 5 — done.fallback có trong tài liệu client
grep -n "fallback" docs/AI/ChatbotAI_Moblie.md                                   # ≥ 1 dòng

# Mục 6 — nhánh lỗi thôi trả 65
grep -n "healthScore: 65" src/Backend/modules/ai/features/chatbot/snapshot/financial.snapshot.service.js   # 0 dòng
```

Mục 7 client sẽ đo lại bằng chính lời gọi `generateSnapshot(10, { bypassCache: true })`: mỗi danh mục tối đa một dòng
cảnh báo, và tổng ba nhóm 50/30/20 tiến gần tổng chi trên thu nhập.
