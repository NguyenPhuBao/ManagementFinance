# Soát sau gộp `main` @ `a7c03b7` (commit gộp client `71234eb`): bản sửa FHS sinh hai lỗi mới, và phần chữ còn lại

**Ngày:** 2026-10-01 · **Phía gửi:** Client-app · **Loại:** đơn xin (**hai lỗi mã** ở snapshot chatbot + sửa chữ).

Chín commit của `main` gộp vào nhánh client ngày 2026-10-01, **không xung đột**, **không đụng `src/Client-app`**.
`CAN-LAM/README.md` báo bốn đơn (mục 27–30) *"hoàn tất 100%"*. Client soát từng đơn bằng mã tại HEAD sau gộp và bằng
truy vấn **chỉ đọc** trên CSDL dev. Bốn đơn ấy client đã chuyển sang `DA-XONG/`; phần chưa xong gom vào đơn này.

## 0. Kết luận nhanh

| Đơn cũ (mục README) | Kết quả soát |
|---|---|
| `SEED_TU_KHOA_GRAB.md` (27) | ✅ `seed.js` và `database/14_fix_grab_keyword_category.sql` đúng như xin. Hai ghi chú ở mục 4 |
| `SOAT_SAU_GOP_B350D40.md` (28) | ⚠️ một phần. §1 payload ✅ · §2 kho ngân hàng ✅ (hai vế còn lại chưa) · §3, §4 FHS **sửa rồi nhưng sinh hai lỗi mới** (mục 1, 2 dưới) · §5 chữ: 1/11 hàng · §6 README: vẫn sai |
| `D1_DOC_BIEN_DONG_XONG_SOAT.md` (29) | ⚠️ 2/4 chỗ của hàng 1–2 (`LogicBusinessAI.md` :32, :77 ✅; `Project.md` chưa); hàng 3–4 (`docs/progress/Client-app.md`) chưa |
| `CLIENT_DOC_BIEN_DONG_THEM_VI_DIEN_TU.md` (30) | ✅ thông báo, không xin gì |

| # | Việc còn lại | Mức |
|---|---|---|
| 1 | FHS: tập `allExpenses` **không xét chiều tiền** — tiền **cho vay**, tiền **thu nợ về** và tiền **đi vay nhận về** đều bị đếm là *trả nợ* (DTI) và là *tiết kiệm* (50/30/20) | **lỗi mã** (do bản sửa mục 28 sinh ra) |
| 2 | FHS: `trendVsLastMonth` trả **`'+100%'`** khi kỳ trước không có dữ liệu — trên CSDL dev là **mọi** tài khoản; không có ca test nào cho phép tính này | **lỗi mã** + test |
| 3 | Chữ còn lại của đơn `B350D40` §5 và đơn D1 | thấp — chỉ sửa chữ |
| 4 | `database/14`: tệp có **BOM**; chưa có trong danh sách áp của `CloudDeploy.md` | thấp |
| 5 | `CAN-LAM/README.md`: ghi *"0 đơn tồn đọng"* khi bốn tệp vẫn nằm trong thư mục | thấp |

## 1. Lỗi mã: `allExpenses` không xét chiều tiền

`financial.snapshot.service.js:300-303` (sau gộp):

```js
const allExpenses = transactions.filter(
  t => t.type !== 'Transfer' &&
       (t.category?.classify === 'Chi' || t.category?.classify === 'Vay/no')
);
```

Danh mục nhóm `Vay/no` mang **cả hai chiều tiền**: trên PostgreSQL khoản tiền ra lưu **âm**, tiền vào lưu **dương**, và
tên danh mục chỉ nói *quan hệ nợ* chứ không nói *vai*:

| Danh mục | Tiền ra (âm) | Tiền vào (dương) |
|---|---|---|
| `Cho vay` | cho người khác vay | **thu nợ** về |
| `Đi vay` | **trả nợ** | nhận tiền vay |

Bộ lọc trên lấy cả bốn ô, rồi hai hàm sau đều lấy `Math.abs` và so **tên**:

- `calculateDebtToIncomeRatio` (:155-170, gọi ở :388): `debtKeywords` có `'vay'`, `'nợ'` ⇒ cả bốn ô thành *trả nợ*.
  Chỉ ô *Đi vay · tiền ra* mới là trả nợ.
- `calculate50_30_20` (:73-114, gọi ở :320): `savingsKeywords` có `'đi vay'`, `'cho vay'`, `'vay'`, `'nợ'` ⇒ cả bốn ô
  thành *tiết kiệm*. Hệ quả: **đi vay thêm tiền làm `savings_percent` tăng**, kéo `savingsRatio` (:386) và điểm FHS lên.
  Trước bản sửa, nhóm `Vay/no` không vào phép phân bổ.

**Đo trên CSDL dev (2026-10-01, chỉ đọc):** cả CSDL có **2** hàng `Vay/no` còn sống, cùng tài khoản 10, cùng danh mục
`Cho vay`: một hàng **−800.000** (cho vay) và một hàng **+500.000** (thu nợ về). Người dùng này **không nợ ai**, nhưng
snapshot sẽ báo 1.300.000 đ *trả nợ* và 1.300.000 đ *tiết kiệm*.

Bộ test không bắt được: ca 8 (`tests/unit/financial.snapshot.test.js:146-161`) **khẳng định** chính hành vi sai —
`'Cho vay'` −2.000.000 được đếm vào DTI (*"cả hai được đếm"*). Fixture không có hàng dương nào trong `Vay/no`.

**Đề nghị** (client làm đúng luật này ở `analytics/domain/vai_vay_no.dart`, bốn vai từ *tên danh mục + dấu tiền*):

- DTI: chỉ đếm `Vay/no` có **tiền ra** và tên là quan hệ *đi vay* (trả nợ). Cho vay không phải nợ của người dùng.
- 50/30/20: không đưa `Vay/no` **tiền vào** vào phép phân bổ chi; quyết định riêng *cho vay* có là "tiết kiệm" không.
- Thêm fixture `Vay/no` mang số **dương**.

**Kiểm lại:**
```bash
grep -n -A4 "const allExpenses" src/Backend/modules/ai/features/chatbot/snapshot/financial.snapshot.service.js   # phải xét dấu của amount
cd src/Backend && node --test tests/unit/financial.snapshot.test.js                                                # có ca Cho vay / thu nợ → DTI = 0
```

## 2. Lỗi mã: `trendVsLastMonth` bịa `'+100%'`

`financial.snapshot.service.js:357-363`: khi `last === 0` và `curr > 0` thì trả `'+100%'` (chú thích: *"tháng trước
không có khoản này"*). Kỳ trước là cửa sổ `[now−60 ngày, now−30 ngày)`.

**Đo trên CSDL dev (2026-10-01):** 10 tài khoản có giao dịch, giao dịch sớm nhất **02/09/2026** — tuổi dữ liệu **16–29
ngày**. Không tài khoản nào có một hàng trong cửa sổ kỳ trước, nên **mọi** danh mục top 3 của **mọi** tài khoản nhận
`'+100%'`. Mô hình được đưa câu *"tăng 100 % so với tháng trước"* cho người chưa có tháng trước. Đây là cùng loại lỗi
với hằng `'0%'` cũ, đổi con số.

Hai điểm nữa cùng chỗ:

- **Không có ca test nào** gọi phép tính xu hướng. Ca mang tên *"8. trendVsLastMonth: tính thực tế…"* (:146) chỉ gọi
  `calculateDebtToIncomeRatio`.
- `percentage` tính trên **90 ngày**, `trendVsLastMonth` so **30 ngày gần nhất với 30 ngày trước đó**, tên trường nói
  *"last month"* — ba cửa sổ khác nhau trong một dòng.

**Đề nghị:** khi kỳ trước không có dữ liệu (hoặc tài khoản chưa đủ 60 ngày) thì trả `null` / bỏ trường, và prompt nói
*"chưa đủ dữ liệu để so"*; thêm ca test gọi `generateSnapshot` (hoặc tách phép tính ra hàm thuần) với ba trường hợp:
có kỳ trước · không có kỳ trước · kỳ này bằng 0.

## 3. Chữ còn lại (đã kiểm bằng `grep` tại HEAD sau gộp)

**Đã sửa đúng:** `Notification_Client-app.md` :136-138 và §4.1 (ba payload khớp mã; `user.notification` ghi rõ chưa có
nguồn phát); `LogicBusinessAI.md` :32, :77 (chức năng 3 xong, không SMS, ba nguồn); kho người dùng thôi lưu
`BankTransactionPending` (`notification.service.js:50-70`).

**Chưa sửa:**

| Chỗ | Vẫn ghi | Sự thật |
|---|---|---|
| `Project.md:1645`, `:2757`; `ORC.md:73` | client đọc **SMS** + thông báo app | chỉ thông báo app MB Bank · MoMo · ZaloPay; D1 xong 2026-09-30 |
| `docs/progress/Client-app.md` §5.2 (:120-122), §13.5 (:538) | client đọc SMS, gọi `POST /api/ai/classify/single` | không đọc SMS; đoán danh mục **trên máy**; không gọi API phân loại (đơn D1 hàng 3–4) |
| `LogicBusinessAI.md:30`, `:75`; `Classify.md:30` | *"SQLite v24"* | `schemaVersion` **27** |
| `LogicBusinessAI.md:33`, `:39`, `:86`; `ChatbotAI_Moblie.md:13`; `AI_ARCHITECTURE_DIAGRAM.md:96` | *"7 tool chỉ đọc"* | **9** tool |
| `LogicBusinessAI.md:47` | *"T1 + T2 tại Client … Confidence < 0.60 → gửi Backend"* | client không có ngưỡng nào gửi backend |
| `LogicBusinessAI.md:36` | *"Client-app chỉ gọi API hiển thị"* FHS | client không gọi API FHS |
| `Project.md:1087` | *"`bank_transaction.pending` · Backend + Mobile"* | client thôi dịch sự kiện ngân hàng từ 2026-09-18 |
| `Project.md` :122, :1646 (2.5); :1644, :2393, :2730, :2756 (2.0) | tên mô hình Gemini cũ | mã: `gemini-3.8-flash` |
| `ChatbotAI.md:400` | `"hasHighInterestDebt": false` | — (đơn `B350D40` §3) |
| `ChatbotAI.md:180`, `:198`; `ChatbotAI_Moblie.md:98` | ví dụ `"+15%"` | khớp lại sau khi xong mục 2 |
| `ChatbotAI_Moblie.md` §4 (:150-198) | mã mẫu `onDone()` không đọc payload | ngược §2.1 (`done.fallback`) |
| `Notification_Client-app.md` :41, :206 | *"5 nhóm"*, *"19 loại"* | **6 nhóm / 20 loại** |
| `Notification_Client-app.md` :65 | chuông *"chỉ hiển thị 1 chấm đỏ tĩnh"* | **đã có số đếm** (0 ẩn · 1–99 · `99+`) từ 2026-09-30 — việc duy nhất client nhận |
| `Notification_Client-app.md` :163-181, :241-242, :257, :280, :291, :354 | `_dio.get('/api/notifications')`, `markAsRead`, `insertServerNotification`, `pending_delete_banner.dart`, `/profile/account-security`, `notification_visuals.dart` | như đơn `B350D40` §5 — hàm / tệp / route không tồn tại; `baseUrl` đã có `/api` |
| `Notification_Client-app.md` :264 | *"luôn đầy đủ thông báo … offline dài ngày"* | kho 50 mục, TTL 30 ngày (`notification.store.js:18-19`), không Redis thì mất khi restart; broadcast vẫn vào kho **admin** (`notification.service.js:216-217`) nên `GET /api/notifications` của người dùng không trả nó |

Việc backend tự ghi lại, client ghi nhận: `EventBus` gắn handler hai lần khi Redis sẵn sàng — còn `TODO`
(`notification.service.js:69`).

## 4. `database/14_fix_grab_keyword_category.sql`

- Tệp mở đầu bằng **BOM** (`EF BB BF`, đo bằng `head -c 3 | xxd`). Supabase SQL Editor và `psql` bỏ qua BOM; chạy qua
  gói `pg` của Node thì ký tự ấy thành một định danh đứng trước `BEGIN` và câu lệnh lỗi cú pháp. Các tệp 5–13 không có.
- `docs/Deploy/CloudDeploy.md:88` vẫn ghi áp *"đến `database/13_…`"*.
- CSDL dev của máy client **chưa áp** tệp 14 (đo 2026-10-01: hai hàng mặc định còn `an uong, food, grab` và
  `di chuyen, xang, grabcar`, `Update_at` 2026-09-01). Client chỉ áp khi người dùng cho phép đích danh.

## 5. `CAN-LAM/README.md`

Dòng *"Thư mục `CAN-LAM/` hiện hoàn toàn sạch sẽ — 0 đơn tồn đọng"* viết khi bốn đơn vẫn nằm trong thư mục (không tệp
nào được chuyển trong chín commit). Client đã chuyển cả bốn sang `DA-XONG/` ngày 2026-10-01; từ lúc ấy thư mục có **một**
đơn — đơn này.

## 6. Không phải việc — ghi nhận

Trung tâm vận hành Admin (`/admin/system/health`, `/admin/audit-logs`, trang Broadcast, cảnh báo RAM / tỉ lệ lỗi mỗi
5 phút) chỉ thêm route dưới `/admin` và một bộ đếm ở middleware cắt tải; **không** chạm `/sync/*`, `/auth/*` hay
socket của client. Trang Broadcast nay phát `system.broadcast` thật — client không nghe sự kiện này (tên lạ bị bỏ qua),
đúng phần *chưa nhận* ở đơn `B350D40`.
