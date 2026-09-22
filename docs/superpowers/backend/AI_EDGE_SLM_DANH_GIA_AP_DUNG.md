# Đánh giá áp dụng `AI_Edge-SLM.md/Client-app.md` vào Client-app

**Ngày:** 2026-09-18 · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat` @ `9052483`
**Tài liệu được đánh giá:** [`docs/AI/AI_Edge-SLM.md/Client-app.md`](../../AI/AI_Edge-SLM.md/Client-app.md)
(448 dòng, NPBao viết, bản `fcc20b5` ngày 2026-09-13)
**Loại:** tài liệu tham khảo cho người dùng, **không phải** yêu cầu làm việc. Người dùng chốt
*"hiện tại chưa cần làm"* cùng ngày; mọi lộ trình dưới đây là phương án để cân nhắc.

> ⚠️ **Đính chính 2026-09-19 — người dùng đã gỡ lệnh hoãn và duyệt thiết kế thi công.** Thiết kế
> đã chốt ở [`../specs/2026-09-19-ai-edge-slm-design.md`](../specs/2026-09-19-ai-edge-slm-design.md);
> tệp này giữ nguyên làm bản đánh giá gốc. Hai điều **đo được** ngày 2026-09-19 làm lệch mục 3.4,
> 15 và 16 bên dưới:
>
> 1. Gói `flutter_gemma` (bọc MediaPipe LLM Inference) **không hỗ trợ Gemma 3 4B**. Danh sách mô
>    hình văn bản của gói: Gemma 3 1B / 270M, Gemma 3n E2B / E4B, **Gemma 4 E2B (≈2,4 GB) / E4B
>    (≈4,3 GB)**. Khuyến nghị "Gemma 3 4B int4 kèm Gemma 3 1B dự phòng" ở mục 16 vì thế **không
>    dùng được**; bậc thang mới là ~~**Gemma 4 E4B (≥ 8 GB RAM) → E2B (4–8 GB) → mẫu câu**~~
>    🛑 **đính chính lần hai 2026-09-20**: spike P1 đo trên máy thật cho thấy **ngưỡng RAM không
>    phân biệt được hai mô hình** — trên GPU cả hai chỉ tốn ~0,96 GB — nên người dùng chốt
>    **Gemma 4 E2B cho MỌI máy, bỏ hẳn E4B**. Bảng đo: `docs/AI_EDGE_FEATURE.md` mục 8. Hai bản
>    Gemma 4 ở kho `litert-community` **công khai**; Gemma 3 1B **gated** (cần token HuggingFace) nên
>    bị bỏ khỏi bậc thang. Cỡ Gemma 3n E4B ở bảng mục 15 (4,5 GB) cũng sai — gói ghi **6,5 GB**.
> 2. Bản `flutter_gemma` 1.8.3 đòi **Flutter ≥ 3.44, Dart ≥ 3.12**; dự án ở 3.41.5 / 3.11.3.
>    Người dùng chốt **nâng Flutter** (stable mới nhất 3.47) thay vì dùng bản 0.13.6.
>
> Và một ràng buộc: tệp `.litertlm` **chỉ chạy arm64-v8a**, nên máy ảo x86_64 không bao giờ nạp
> được mô hình — nhánh rơi về mẫu câu là đường mặc định ở máy ảo.

> **Cách đo.** Đọc mã client trên nhánh `TranQuangDat` sau khi gỡ phần client của liên kết
> ngân hàng (`4685271`); đo lược đồ Drift thật (`app_database.dart`, `tables/`); đo dữ liệu thật
> trên PostgreSQL dev bằng Prisma (chỉ đọc); đối chiếu với phương án A ở mục 9.1
> [`AI_ARCHITECTURE_REVIEW.md`](AI_ARCHITECTURE_REVIEW.md) và với lượt soát trước
> [`DA-XONG/AI_EDGE_SLM_CLIENT_MISMATCH.md`](DA-XONG/AI_EDGE_SLM_CLIENT_MISMATCH.md). Mọi con số
> đếm bằng script, ghi kèm ngày.

---

## 0. Kết luận trong năm câu

1. **Áp dụng được, nhưng chỉ hai trong ba lớp của tài liệu, và không theo nguyên văn.**
2. Lớp **Edge tất định** (Tầng 1–2 phần chạy được với dữ liệu mỏng) **làm được ngay**, vì phần lớn
   đã có sẵn trong app dưới dạng hàm thuần có test.
3. Lớp **SLM diễn giải trên máy** (Tầng 3) **làm được trong khuôn đồ án** nếu một spike đo mô hình
   đạt trên máy thật. Với máy demo Snapdragon 8 Gen 3 / 12 GB (người dùng cho biết cùng ngày), phần
   "chạy được" gần như chắc; spike chỉ còn đo **chất lượng tiếng Việt và nhiệt** — mục 15, 16.
4. Lớp **học thói quen bằng thống kê** (hệ số biến thiên, elasticity, EMA, xu hướng) **chưa áp dụng
   được**: dữ liệu thật chưa đủ để bất kỳ công thức nào cho ra kết quả có nghĩa.
5. Nguyên tắc cốt lõi của tài liệu, *"số liệu từ tầng tất định, SLM chỉ diễn giải, không tính"*,
   **khớp hoàn toàn** với phương án A đã chốt và với cách app đang làm. Đây là điểm mạnh nhất của
   tài liệu, và là thứ nên giữ nguyên khi trình bày với hội đồng.

---

## 1. Tài liệu nói gì

Bốn phần, tự xưng là *"Nguồn sự thật"* cho một AI điều phối ngân sách chạy trên máy.

| Phần | Nội dung |
|---|---|
| **I. Ý tưởng** | AI trên máy học thói quen chi tiêu, chấm điểm "thiết yếu" cho từng danh mục; khi một danh mục sắp thâm hụt thì đề xuất cắt bớt từ danh mục ít thiết yếu bù sang. Ba tầng: thống kê, suy luận, diễn giải. Lý do không để SLM tự học từ giao dịch thô: mô hình nhỏ yếu về số học, phải kiểm toán được, context window có hạn |
| **II. Thiết kế** | **Tầng 1**: chín đặc trưng theo danh mục (trung bình 3/6 tháng, chi hiện tại, dự phóng, hệ số biến thiên, tính đều đặn, xu hướng, tần suất, mẫu theo thứ, tỉ lệ sau ngày lương), chạy incremental kiểu Welford. **Tầng 2**: essentiality từ ba trọng số, phát hiện thâm hụt, xếp hạng nguồn bù theo `slack × (1 − essentiality)`, thuật toán tham lam với trần cắt 25%, ràng buộc tỉ lệ tiết kiệm, học ngầm từ việc từ chối qua EMA. **Tầng 3**: SLM trên máy (Gemma / MediaPipe) chỉ diễn giải JSON, có bộ kiểm số bịa và mẫu câu dự phòng. Lộ trình MVP (mẫu câu) → V2 (SLM) → V3 (học) → V4 (LP) |
| **III. 39 luật A–H** | A làm sạch (outlier, một lần, hoàn tiền, chưa phân loại, lump-sum); B kích hoạt cảnh báo (cold start, ngưỡng kép, cửa sổ 48h, khoá đầu tháng, dự phóng Bayesian, chống quá tải); C chọn nguồn bù (bảo vệ, ghi đè tay, trần cắt động, đệm, ngưỡng có nghĩa, xếp hạng, cạn nguồn); D mục tiêu và thu nhập biến động; E tương tác và học ngầm; F riêng tư; G làm tròn; H hiệu năng và bảng cục bộ. Đếm bằng máy: 6+6+7+5+5+3+3+4 = **39** |
| **IV. Ba bảng SQLite cục bộ** | `local_category_features`, `local_rebalancing_feedback`, `local_ai_alert_history`, không đồng bộ |

Sáu chỗ lệch mà lượt soát 2026-09-13 chỉ ra (quy ước dấu tiền, ba cột chưa có, `saving_goal_ratio`,
`income`, mô hình ngân sách, F2 mã hoá) **đã được backend chèn cảnh báo** vào đúng chỗ (dòng 62,
83, 123, 201, 343, 368). Đó là điểm cộng thật, và tài liệu này **không lặp lại** sáu chỗ ấy.

---

## 2. Điều kiện dữ liệu, đo ngày 2026-09-18

| Phép đo trên PostgreSQL dev | Kết quả |
|---|---|
| Giao dịch toàn hệ thống (chưa xoá mềm) | **52** |
| Tài khoản đông nhất | 33 giao dịch, trải 3 tháng |
| Danh mục đông nhất | **5** giao dịch |
| Ngân sách đang sống | **3**, cả ba đều gắn danh mục |

Hệ quả cho từng công thức của tài liệu:

| Công thức | Cần gì | Với dữ liệu trên |
|---|---|---|
| B1 cold-start guard | ≥ 2 tháng dữ liệu mỗi danh mục | Không danh mục nào qua |
| `CV` (hệ số biến thiên) | độ lệch chuẩn của chi theo tháng | Không tính được với 1–3 điểm |
| `elasticity` | "các tháng thâm hụt trong quá khứ" | Không có tháng nào |
| `trend_slope` | 3–6 điểm tháng | Không đủ điểm |
| `avg_income_3m` | 3 tháng thu nhập | Chỉ tài khoản 10 có, và gồm cả giao dịch ngày tương lai |
| Tái phân bổ giữa danh mục | mỗi danh mục một `budget_limit` | 3 ngân sách trên toàn hệ thống, bài toán gần như không có ứng viên |

Mọi thứ rơi về prior mặc định. Hệ thống sẽ không học gì, chỉ nói theo prior, và người dùng
không phân biệt được với một câu mẫu. Đây chính là lý do ngày 2026-09-17 thông báo **khoản chi
lớn** chọn ngưỡng người dùng đặt thay vì thống kê (mục 5f `NOTIFICATION_FEATURE.md`).

---

## 3. Đối chiếu từng tầng với mã thật

### 3.1. Khớp, nên giữ

- Nguyên tắc *"số từ tầng tất định, SLM chỉ diễn giải"* trùng khít phương án A (mục 9.1
  `AI_ARCHITECTURE_REVIEW.md`) và với cách app đang làm: mọi phép tính là hàm thuần có test.
- Ba bảng cục bộ **không đồng bộ** đúng khuôn bảng `AppNotifications` (quy tắc 9 `CLAUDE.md`).
- E1 chờ duyệt, E2 chấp nhận từng phần, G3 thẻ số liệu đối soát: hợp tinh thần app.
- Bộ chắn cho mô hình (kiểm số trong câu trả lời, rơi về mẫu câu, blocklist chủ đề): thiết kế tốt
  và rẻ.
- Các "góc khuất" (B4 bẫy chia số ngày nhỏ, C4 đệm nguồn bù, C5 ngưỡng có nghĩa, B6 chống quá tải)
  đều là lỗi thật đã được lường trước.
- Lộ trình MVP dùng mẫu câu trước, SLM sau: **đúng thứ tự**.

### 3.2. Tầng 1 — cái gì đã có, cái gì phải mượn

Chín đặc trưng chia hai nhóm:

| Nhóm | Đặc trưng | Hiện trạng ở client |
|---|---|---|
| Tính được với dữ liệu mỏng | chi hiện tại, dự phóng, tần suất, ngân sách còn lại | **Đã có**: `budget/domain/budget_pace.dart` (`budgetPaceOf`: ngày còn lại, nên chi mỗi ngày, chi "đáng lẽ", trạng thái nhanh/chậm, theo kỳ tuỳ ý chứ không khoá tháng dương lịch); `analytics/domain/bao_cao_xuat.dart` (`soLieuNhanhCua`, `topKhoanChi`) |
| Cần lịch sử dài | trung bình 3/6 tháng, CV, đều đặn, xu hướng, mẫu theo thứ, sau ngày lương | **Chưa có, và chưa nên làm** (mục 2). Khi làm thì thêm vào cùng tầng domain đã có test, không dựng bảng cache riêng |

⚠️ **Ba chỗ Tầng 1 phải MƯỢN hàm sẵn có thay vì tự viết**, vì dự án giữ nếp *một định nghĩa duy
nhất cho mỗi phép tính*:

| Phép tính | Hàm đã có | Tài liệu đang nói gì | Hậu quả nếu làm theo tài liệu |
|---|---|---|---|
| Thu nhập | `analytics/domain/dong_tien_tu_do.dart` → `thuNhapCua()`: tổng thu **trừ** tiền đi vay, thu nợ, khoản vay/nợ vào | D1: cộng mọi giao dịch `type = 'thu'` | Tháng nào vay tiền thì thu nhập vọt lên, `income × (1 − ratio)` cho phép chi nhiều hơn đúng lúc mắc nợ. Bẫy đã trả giá ở mục 3.24 `ANALYTICS_FEATURE.md` |
| Hàng nào vào thống kê | `analytics/domain/khoan_vao_thong_ke.dart` → loại khoản chuyển, điều chỉnh số dư, mở sổ | Mục 1.2 chỉ nói `{id, amount, category_id, timestamp}` | "Chi hiện tại" đếm việc tạo ví 20 triệu thành vừa chi 20 triệu |
| Chi cố định | bảng `Bills` (hoá đơn định kỳ, `anchorDay`, `periodEnd`) và `Goals.autoDeposit*` | A6 suy lump-sum từ `txn_frequency <= 2` và `regularity >= 0.8` | Suy đoán thống kê trong khi nguồn tin cậy hơn đã có; tài liệu **không nhắc tới bảng hoá đơn lần nào** |

### 3.3. Tầng 2 — phần chạy được và phần phải bỏ

**Chạy được:**

- Thâm hụt: từ `BudgetPace.status == fast` và `BudgetEntity.isOverBudget` đã có.
- Nguồn bù: ngân sách **khác cùng kỳ** còn dư địa trên ngưỡng C4. Với 3 ngân sách thì tập ứng viên
  rất nhỏ, nhưng đúng.
- Essentiality: **người dùng đánh dấu** theo luật C2 ("Cố định / Không đụng vào") cộng prior theo
  `classify` và nhóm cha của danh mục. Hoãn CV, elasticity, EMA tới khi có sáu tháng dữ liệu,
  đúng câu *"luật thống kê thêm vào cạnh ngưỡng, không thay ngưỡng"* ở mục 9.1b.
- Học từ phản hồi: giữ **một** bảng cục bộ ghi chấp nhận / từ chối / sửa (E3), để sau này có dữ
  liệu mà dùng. Phép cập nhật E4 thì chưa.

**Phải bỏ hoặc gộp:**

| Luật | Vì sao |
|---|---|
| **A1** outlier theo `3 × avg_spend` | Lật quyết định 2026-09-17: khoản chi lớn dùng **ngưỡng người dùng đặt**, vì một ngưỡng người dùng đặt không thể báo động giả; luật thống kê im hàng tháng rồi nổ bừa khi vừa đủ mẫu |
| **A2** cột `is_one_time` do người dùng bấm | Thêm ô vào màn Thêm giao dịch vốn đã đông (chiều tiền, ví, danh mục, ghi chú, hoá đơn, mục tiêu); cột **không đi qua đồng bộ** nên hai máy lệch nhau, cùng bẫy `allow_negative` cục bộ (G27) |
| **B2, B3, B6** ngưỡng kép, cửa sổ 48h, tối đa 1 push/tuần | Bộ luật thông báo hiện hành (`core/notification/notification_rules.dart`) đã có `budgetNearLimit`/`budgetOverspent` với `thresholdWarningPercent` người dùng đặt, khoá chống trùng theo kỳ, `silenceBefore`. Làm bộ thứ hai là **hai bộ cảnh báo ngân sách không biết nhau**; gộp thành một `NotificationKind` mới với khoá `budgetRebalance:<budgetId>:<kỳ>` |
| **§2.4 / D5** `saving_goal_ratio` | Tài liệu tự đề xuất phương án (b) suy từ mục tiêu còn hạn — hợp lý; nhưng D3 lại nói tỉ lệ ấy *"do người dùng toàn quyền thiết lập"*. Nếu suy ra thì không phải người dùng đặt: mâu thuẫn nội bộ nhỏ, phải chốt một trong hai |

⚠️ **Mô hình ngân sách vẫn chưa chốt.** Cảnh báo ở dòng 123 để ba câu hỏi mở (ngân sách tổng
tính sao, kỳ không phải tháng quy về `month` thế nào, ngân sách hết hạn loại ra sao). Chưa trả lời
thì Tầng 2 nguyên văn chưa thi công được dù muốn. Với lộ trình ở mục 5, ba câu ấy tự biến mất vì
mượn `currentPeriod` của `BudgetEntity`.

### 3.4. Tầng 3 — phần đáng làm nhất

Mọi con số Tầng 3 cần **đã có sẵn**, tính trên máy, không mạng:

| Màn | Con số tất định đã có |
|---|---|
| Trang chủ | tổng số dư, thu chi tháng, khoản chi lớn |
| Ngân sách | nhịp chi, ngày còn lại, nên chi mỗi ngày, vượt hay chưa |
| Phân tích | so kỳ trước, cùng kỳ năm trước, tỉ lệ tiết kiệm, dự báo 30 ngày, top 5 khoản chi, thác nước, tổng tài sản theo thời gian |
| Mục tiêu | tiến độ, chậm hay đúng kế hoạch, chuỗi kỳ nạp, cột mốc |
| Hoá đơn | sắp đến hạn, quá hạn, tổng phải trả |
| Ví | ví âm, ví sắp cạn |

App **đã có** vài câu nhận xét tất định: *"Để dành 93% thu nhập"*, dòng *"so với kỳ trước"*, câu
cảnh báo ví thiếu trong dự báo, *"Không có dữ liệu T9 2025"*. Việc còn lại là nhân rộng cái đã
có ra mọi màn và cho nó một bộ mặt thống nhất.

**Cách dựng:** một giao diện `NhanXet` cho từng màn, đầu vào là gói số nhỏ đã tính (typed, không
phải JSON tự do), đầu ra là câu. **Hai bản thi công cắm cùng chỗ:**

1. **Mẫu câu** (template): làm trước, chạy tức thì, offline, test được trọn vẹn kể cả nhánh *"chưa
   đủ dữ liệu"*. Đây đã là Edge AI theo đúng định nghĩa tài liệu.
2. **SLM trên máy**: cắm sau, cùng đầu vào, có **bộ kiểm số** (mọi con số trong câu phải có trong
   gói số, sai thì rơi về mẫu), chạy trong isolate, cache câu theo dấu vân của gói số.

Câu phải đi kèm **thẻ số liệu** (G3), và mỗi khối là giao diện mới nên phải **lên Stitch trước**.

**Hiện trạng nền tảng cho SLM** (đo 2026-09-18):

| Thứ cần | Hiện trạng |
|---|---|
| Gói suy luận trong `pubspec.yaml` | **Không có** (không tflite, onnx, mediapipe, llama, gemma) |
| Isolate / `compute()` trong `lib/` | **0 chỗ** |
| Màn Trợ lý AI | `ai_chat_page.dart` 436 dòng, chỉ import `material`, `go_router`, `app_colors` — **hoàn toàn tĩnh**, đúng như tài liệu ghi ở dòng 289 |
| Thư mục iOS | có `ios/Runner`, nhưng chưa build |

**Lựa chọn mô hình** — tài liệu gợi ý Gemma 2B nén 4 bit; cỡ ấy hơn một gigabyte và thừa cho
việc diễn giải:

| Mô hình | Cỡ tệp xấp xỉ | Ghi chú |
|---|---|---|
| **Gemma 3 1B, int4** | trên dưới nửa gigabyte | Qua MediaPipe LLM Inference (Android API 24+), có gói Flutter cộng đồng bọc sẵn. Bậc **dự phòng** cho máy yếu |
| Qwen 2.5 0.5B, Q4 | dưới nửa gigabyte | Qua llama.cpp; tiếng Việt yếu hơn |
| Gemma 3n E2B | khoảng ba gigabyte | Quá nặng cho việc này |

⚠️ Bảng trên viết cho mốc "máy tầm trung". Sau khi biết máy demo là **Snapdragon 8 Gen 3 / 12 GB**,
khuyến nghị chính đổi thành **Gemma 3 4B int4** với 1B làm bậc dự phòng — bậc thang đầy đủ và lý do
ở mục **15** và **16**.

Mô hình **tải về lần đầu**, không đóng vào APK. Ngưỡng RAM ở luật H3 (dưới 1 GB thì rơi về mẫu)
**thấp**: mô hình 1 tỉ tham số cần khoảng 1,5 GB lúc chạy, ngưỡng nên quanh 2 GB trống.

### 3.5. Bảng cục bộ

Tài liệu định ba bảng. **Chỉ cần một**:

> ✅ **Backend đã sửa đặc tả theo đúng kết luận này ở `b147fee` (2026-09-22):** H4 và Phần IV nay
> khai **một** bảng `ai_rebalancing_feedbacks` (tên Drift thật của client, khác tên
> `local_rebalancing_feedback` mà bảng dưới đây dùng), bỏ hẳn hai bảng kia. Client thi công đúng
> thế ở schema **v24**, cộng cột cục bộ `categories.ai_co_dinh`.

| Bảng | Kết luận | Lý do |
|---|---|---|
| `local_category_features` | **Bỏ** | Với vài trăm hàng, tính tại chỗ từ `watchKy` rẻ hơn cache. Và bảng **tự mâu thuẫn**: khoá chính là `category_id` nhưng có cột `month`, tức mỗi danh mục chỉ giữ được **một** tháng, trong khi `avg_spend_6m` và `CV` cần lịch sử theo tháng. Nếu giữ, khoá phải là cặp `(category_id, month)` |
| `local_rebalancing_feedback` | **Giữ** | Nguồn dữ liệu duy nhất cho phần học sau này; không có thì sáu tháng nữa vẫn trắng tay |
| `local_ai_alert_history` | **Bỏ** | Bảng `AppNotifications` đã làm việc ấy (khoá chống trùng, `silenceBefore`) |

---

## 4. Tài liệu cần sửa chữ — năm chỗ

Tệp do backend viết nên chỗ sửa đi qua kênh `CAN-LAM/` khi người dùng quyết định làm. Ghi ở đây
để không quên.

| Chỗ | Đang nói gì | Sai ở đâu |
|---|---|---|
| **F1** (dòng 367) | *"Toàn bộ dữ liệu giao dịch thô … hoàn toàn không được phép rời khỏi thiết bị"*; dẫn PCI-DSS | Giao dịch thô **đồng bộ hai chiều** lên PostgreSQL qua `/sync/push` từ ngày đầu — đó là kiến trúc offline-first. Chỉ JSON đặc trưng và kế hoạch mới ở lại máy. PCI-DSS là chuẩn về **dữ liệu thẻ thanh toán**, không liên quan; "tuân thủ 100%" là tuyên bố không kiểm được |
| **D1** (dòng 343) | `avg_income_3m` cộng giao dịch `type = 'thu'` theo tháng | Không loại tiền đi vay và thu nợ; phải mượn `thuNhapCua()` (mục 3.2) |
| **Bảng đặc trưng** (dòng 406–421) | `category_id VARCHAR(36) PRIMARY KEY` kèm `month` | Khoá không chứa tháng (mục 3.5) |
| **Dòng 83 và 402** | *"schema hiện tại v21"* | Thật là **v23** (`app_database.dart:59`, đo 2026-09-18) |
| **Mục 3.4** (dòng 274) | *"Apple Foundation Models (iOS 18+)"* | Khung ấy ra ở **iOS 26** |

---

## 5. Lộ trình khả thi cho đồ án

Ba bước, mỗi bước tự đứng được. Không đổi schema đồng bộ, không thêm trường payload ở bước nào.

| Bước | Việc | Cỡ | Điều kiện |
|---|---|---|---|
| **1. Nhận xét theo màn bằng mẫu câu** | Chọn bốn màn có số sẵn (Ngân sách, Phân tích, Mục tiêu, Trang chủ). Mỗi màn một khối câu + thẻ số liệu, đọc số từ hàm domain đã có, nhánh *"chưa đủ dữ liệu"* trung thực. Lên Stitch trước | vừa | Không có |
| **2. Spike đo SLM** | Nạp Gemma 3 1B int4 qua MediaPipe trên máy ảo và **một máy thật tầm trung**. Đo: thời gian nạp, thời gian một câu trả lời, RAM đỉnh, nhiệt. **Không giữ mã** | nhỏ, 1–2 ngày | Không có |
| **3. Cắm SLM vào giao diện bước 1** | Isolate, tải mô hình lần đầu, cache câu theo dấu vân gói số, bộ kiểm số, rơi về mẫu khi pin thấp / máy yếu / chưa tải. Màn Trợ lý AI nhận thêm hỏi đáp tự do trên cùng gói số | vừa | Bước 2 đạt |

Phần **học thói quen** (CV, elasticity, EMA, E4) xếp **sau đồ án**, khi có sáu tháng dữ liệu; trình
bày như giai đoạn tiếp theo, với luật C2 để người dùng tự đánh dấu trong khi chờ.

**Hai loại "câu do AI đưa ra"**, nếu muốn mở rộng bước 1:

- **Về chi tiêu**: làm được ngay, con số đã có (bảng ở mục 3.4).
- **Về cách dùng chức năng** (hay mở gì, chưa từng đặt ngân sách, lâu không ghi): làm được nhưng
  **chưa có dữ liệu** — app không ghi người dùng mở màn nào. Cần một bảng sự kiện cục bộ mới,
  không đồng bộ. Đó là nguồn dữ liệu mới, tách thành việc riêng.

---

## 6. Ba phương án, và khuyến nghị

| Phương án | Mô tả | Ưu | Nhược | Khuyến nghị |
|---|---|---|---|---|
| **1. Edge mỏng + mẫu câu, SLM sau khi đo** | Mục 5 | Làm được trong đồ án; không tạo bản định nghĩa thứ hai; không lật quyết định nào đã trả giá; test được | Phần "học" hoãn; SLM tuỳ kết quả spike | ✅ **Chọn** |
| **2. Tầng 3 qua Gemini trên server** | Client tính gói số, gửi lên một endpoint, Gemini viết câu (Pipeline B đảo chiều của phương án A) | Câu tự nhiên hơn mẫu; không tải mô hình; gói số không chứa giao dịch thô nên rủi ro thấp | Trái F1/F3 của tài liệu, cần hộp thoại đồng ý; cần một việc nhỏ phía backend; không còn "on-device" | Dự phòng nếu spike bước 2 không đạt |
| **3. Thi công nguyên văn 39 luật + SLM trên máy** | Theo tài liệu | Đủ từ khoá | Không luật thống kê nào có dữ liệu để chạy; gói mô hình lớn; chưa có isolate; sinh bộ định nghĩa thứ hai cho bốn phép tính đã có; hai bộ cảnh báo ngân sách song song | ❌ Không |

---

## 7. Rủi ro và cách chặn

| Rủi ro | Chặn bằng |
|---|---|
| Mô hình bịa số | Bộ kiểm số: mọi con số trong câu phải có trong gói số; sai thì rơi về mẫu. **Đây là câu hội đồng sẽ hỏi** |
| Dữ liệu mỏng làm câu vô nghĩa | Mỗi câu có nhánh "chưa đủ dữ liệu"; **nền bằng 0 là ca thường**, không bịa "tăng 100%" (bài học so cùng kỳ năm trước) |
| Sinh câu mỗi lần màn dựng lại | Stream phát lại sau mỗi chu kỳ đồng bộ. Cache theo dấu vân gói số; hiện mẫu ngay, thay bằng câu mô hình khi xong |
| Hai bộ luật cảnh báo lệch nhau | Câu trên màn đọc chính `notification_rules.dart`, không dựng bộ thứ hai |
| Bản định nghĩa thứ hai | Mọi số trong câu lấy từ hàm domain; lớp câu **không tính** |
| Tốn pin, nóng máy | H2 giữ nguyên: pin thấp thì mẫu câu |
| Cột cục bộ mới lệch giữa hai máy | Không thêm cột vào bảng giao dịch (bỏ A2) |

---

## 8. "Edge AI kết hợp SLM" nằm ở đâu — câu trả lời thẳng

Hai chữ ấy nằm ở **hai tầng khác nhau**, đúng như chính tài liệu tách:

- **Edge AI** = Tầng 1–2: thống kê và luật chạy trên máy, không mạng. **Đây mới là phần "thông
  minh"**: chấm điểm thiết yếu, tìm thâm hụt, chọn nguồn bù, học từ từ chối.
- **SLM** = Tầng 3, và chỉ Tầng 3: nhận JSON đã tính xong, viết thành câu tiếng Việt, trả lời câu
  hỏi tự do trên JSON ấy. **Không tính, không học.**
- **"Kết hợp"** = đường ống: máy tính số, mô hình kể chuyện về số. Bỏ mô hình thì số vẫn đúng
  nhưng câu thành mẫu cứng. Bỏ tầng thống kê thì mô hình không có gì để kể, hoặc bịa.

Phương án 1 ở mục 6 **giữ trọn Edge AI** và **cắm SLM ở bước 3**. Nếu dừng ở bước 1 thì **không
còn SLM**, chỉ còn Edge AI theo nghĩa hẹp; nếu đồ án cần chứng minh chữ SLM, bước 2 và 3 là bắt
buộc.

**Điều nên nói thật với hội đồng:** phần "học thói quen" là thống kê và luật, không phải mô hình
ngôn ngữ; mô hình chỉ diễn giải. Đó là lập luận **mạnh hơn** chứ không yếu hơn: mô hình nhỏ trên
máy yếu về số học, nên giao số cho tầng tất định có test là thiết kế đúng. Chính tài liệu đặt ra
nguyên tắc ấy, và phương án A của dự án đã chốt cùng hướng, nên áp dụng Edge SLM theo cách trên
không mâu thuẫn với quyết định nào đã có.

---

## 9. Tóm lại

**Áp dụng được** nếu hiểu Edge SLM là *"máy tính số, mô hình kể chuyện về số"*: làm mẫu câu trước,
đo mô hình trước khi hứa, mượn hàm đã có thay vì viết lại, gộp cảnh báo vào bộ luật hiện hành.

**Không áp dụng được** nếu hiểu là thi công nguyên văn 39 luật với phần học thống kê, vì dữ liệu
chưa có để nó chạy, và vì nó tạo ra bộ định nghĩa thứ hai cho bốn phép tính app đã có một định
nghĩa duy nhất.

---

# PHẦN BỔ SUNG — thảo luận tiếp cùng ngày 2026-09-18

> Các mục 10–16 ghi lại lượt hỏi đáp sau khi bản trên được viết. Chúng **không sửa** kết luận ở
> mục 0–9, chỉ trả lời năm câu hỏi nối tiếp: nhược điểm giải quyết được không, mô hình đã phù hợp
> chưa, thế nào là "đã áp dụng", hệ thống có đạt được không, và dùng mô hình nào.

---

## 10. Giải quyết các nhược điểm đã nêu

Mười hai nhược điểm về thiết kế và tài liệu **đều có lời giải**, phần lớn là mượn thứ đã có thay vì
dựng mới. Nhược điểm về dữ liệu **không có lời giải bằng mã**, chỉ có cách sống chung.

### 10.1. Giải quyết trọn bằng thiết kế, không tốn thêm gì đáng kể

| Nhược điểm | Cách giải |
|---|---|
| Bản định nghĩa thứ hai cho thu nhập, loại khoản, chi cố định | Tầng 1 gọi thẳng `thuNhapCua`, `khoanVaoThongKe`, `budgetPaceOf`, bảng `Bills`. Thêm một **test quét `lib/`** cấm lớp AI chứa `type == 'thu'` hay `!= 'transfer'` — nếp dự án đã dùng chín lần |
| B2, B3, B6 thành bộ cảnh báo thứ hai | Thêm **một** `NotificationKind` vào `notification_rules.dart`. Ngưỡng kép = `thresholdWarningPercent` người dùng đặt + mức tuyệt đối. Cửa sổ 48 giờ = khoá theo kỳ đã có. Trần một lần/tuần = khoá theo tuần ISO, y hệt Tổng kết tuần |
| A1 lật quyết định khoản chi lớn | Giữ ý A1 ("loại khỏi baseline, vẫn tính vào tháng này"), đổi nguồn ngưỡng: `nguongChiLon` người dùng đặt thay vì `3 × avg_spend` |
| A2 cột mới không đồng bộ | Không thêm cột. Khoản vượt ngưỡng chi lớn tự coi là "một lần" cho baseline. Nếu thật cần cờ người dùng bấm: đặt ở menu hành động của giao dịch, không thêm ô ở màn Thêm, và xin backend một cột đi qua đồng bộ |
| D3 mâu thuẫn với cách suy tỉ lệ tiết kiệm | Chọn suy từ mục tiêu còn hạn. Sửa D3 thành "AI không sửa số tiền đích hay hạn của mục tiêu" |
| F1 sai kiến trúc | Thu hẹp cam kết về đúng thứ có thật: gói số, kế hoạch, bảng phản hồi không rời máy. Bỏ PCI-DSS, giữ Nghị định 13 |
| Bảng cache khoá sai | Bỏ bảng, tính tại chỗ. Nếu sau này cần cache: khoá `(category_id, month)` |
| Sinh câu mỗi lần màn dựng lại | Cache theo dấu vân gói số. Hiện mẫu câu ngay, thay bằng câu mô hình khi xong |
| Ba câu hỏi mở về ngân sách | Ngân sách tổng = trần toàn cục cho D5, không là nguồn bù. Kỳ = `currentPeriod` của chính ngân sách, gói số theo ngân sách chứ không theo tháng. Hết hạn thì loại. Cả ba biến mất khi mượn hàm sẵn có |

### 10.2. Giải quyết được, có chi phí phải cân

| Nhược điểm | Cách giải | Chi phí |
|---|---|---|
| Ít ngân sách nên tái phân bổ không có ứng viên | Đổi đầu ra: không có nguồn bù thì đề xuất **"đặt ngân sách cho danh mục X"** từ chi trung bình. Tái phân bổ là bước hai sau khi có vài ngân sách | Một luồng gợi ý tạo ngân sách, cần Stitch |
| Tầng 3 chưa có nền | Gói Flutter bọc MediaPipe; mô hình tải lần đầu qua Wi-Fi có tiến độ; `Isolate.run`; ngưỡng RAM đọc từ thông tin thiết bị; iOS bỏ ở đồ án | Spike 1–2 ngày |
| Mô hình bịa số | Ba lớp: (1) số đưa vào prompt **đã định dạng sẵn** để mô hình chép nguyên; (2) bộ kiểm số so mọi con số trong câu với tập số của gói; (3) nếu vẫn lo, đổi vai mô hình từ **sinh câu** sang **chọn câu** trong vài mẫu ứng viên rồi điền chỗ trống — triệt tiêu bịa số, mất phần tự nhiên, chỉ dùng cho câu có tiền | Lớp 3 tuỳ chọn |
| Câu về cách dùng chức năng thiếu dữ liệu | Một bảng sự kiện cục bộ, ghi ở **một** chỗ là observer của router, mỗi lần mở màn một hàng. Không đồng bộ. Nói rõ trong phần riêng tư | Nhỏ, nhưng là nguồn dữ liệu mới |
| Phương án 2 trái F1/F3 | Làm lai: có mô hình trên máy thì dùng, không thì hỏi đồng ý rồi gửi **gói số** lên Gemini. Gói số không chứa giao dịch thô | Một endpoint backend qua `CAN-LAM/` |

### 10.3. Không giải quyết được bằng mã: dữ liệu mỏng

Người dùng thật cần sáu tháng để luật thống kê có nghĩa. Bốn cách giảm nhẹ, hai cách cuối đáng làm:

1. **Ngưỡng theo bậc thay vì công tắc.** Dưới 2 tháng: prior theo nhóm danh mục. 2–5 tháng: trộn
   prior với số đo theo trọng số số tháng, `(n·đo + k·prior)/(n+k)` — phép cập nhật Bayes mà tài
   liệu nhắc ở 1.4 nhưng chưa viết thành công thức. Từ 6 tháng: số đo.
2. **Biến cold start thành tính năng.** Luật C2 cho người dùng tự đánh dấu "cố định" ngay từ đầu;
   chi cố định lấy từ hoá đơn và trích tự động.
3. **Nhập lịch sử từ tệp.** App đã xuất CSV; thêm nhập CSV là người dùng có sáu tháng trong một
   phút. Tính năng thật, không chỉ để trình diễn. Phải đi qua `addTransaction` để số dư và đồng bộ
   không lệch.
4. **Tài khoản trình diễn có dữ liệu mô phỏng.** Sinh 6–12 tháng giao dịch bằng script, đẩy qua
   đúng đường đồng bộ; dùng để test luật thống kê bằng chuỗi tổng hợp và để trình bày. **Phải nói
   rõ là mô phỏng.**

---

## 11. Sau khi áp lời giải, mô hình đã phù hợp chưa

Ba mệnh đề khác nhau:

- **Kiến trúc ba tầng: phù hợp ngay từ đầu, không cần đổi.**
- **Đặc tả 39 luật như đang viết: chưa.** Xếp từng luật sau khi áp lời giải, đếm tay trên bảng
  của tài liệu:

| Nhóm | Số luật | Giữ nguyên | Sửa | Hoãn hoặc bỏ |
|---|---|---|---|---|
| A làm sạch | 6 | A3, A4 | A1, A2, A6 | A5 |
| B cảnh báo | 6 | B4 | B1, B2, B3, B5, B6 | |
| C nguồn bù | 7 | cả 7 | | |
| D mục tiêu, thu nhập | 5 | D5 | D1, D3 | D2, D4 |
| E tương tác | 5 | E1, E2, E3, E5 | | E4 |
| F riêng tư | 3 | F2, F3 | F1 | |
| G làm tròn | 3 | cả 3 | | |
| H hiệu năng | 4 | H1, H2 | H3, H4 | |
| **Tổng** | **39** | **22** | **13** | **4** |

  17/39 luật phải đổi hoặc chờ. Nhưng cột "Sửa" phần lớn là **đổi nguồn** chứ không đổi ý: ý của
  luật đúng, cách thực hiện sai chỗ.

- **Sau khi sửa: phù hợp, với ba điều kiện.** (1) Spike đo mô hình đạt trên máy thật. (2) Chấp nhận
  bốn luật hoãn — phần cá nhân hoá theo thời gian — trình diễn qua dữ liệu mô phỏng và nói rõ. (3)
  Tài liệu được viết lại theo bảng trên **trước** khi thi công, qua `CAN-LAM/`.

**Trường hợp vẫn không phù hợp:** nếu mục tiêu đồ án là chứng minh AI **đã học được** thói quen của
người dùng thật tính đến ngày bảo vệ. Nếu mục tiêu là chứng minh **kiến trúc đúng và chạy được**,
với diễn giải thật trên máy và phần học thiết kế sẵn chờ dữ liệu, thì phù hợp.

---

## 12. Spike đạt không có nghĩa là đã áp dụng

Spike đạt chỉ trả lời "**có thể** đưa SLM lên máy này". Hiện trạng: hệ thống **chưa áp dụng phần
nào** — không gói suy luận, không isolate, màn Trợ lý AI tĩnh, không luật nào thi công. Thứ tự đúng:
spike → bước 1 → bước 3 → mới gọi là đã áp dụng. Dừng ở bước 1 là mới có Edge, chưa có SLM.

---

## 13. Mười bảy điều kiện để được xem là đã áp dụng

**Định nghĩa.** Client được xem là đã áp dụng AI Edge-SLM khi trên máy người dùng có (a) một tầng
tất định sinh gói số từ dữ liệu cục bộ, (b) một mô hình ngôn ngữ nhỏ chạy trên chính máy ấy diễn
giải gói số thành câu, và (c) giữa hai tầng có bộ chắn bảo đảm mô hình không tự tính và không bịa.
Thiếu một vế là chưa.

| # | Điều kiện bắt buộc | Kiểm bằng gì |
|---|---|---|
| **Tầng Edge tất định** | | |
| 1 | Gói số theo màn cho ≥ 2 màn, mọi con số lấy từ hàm domain đã có, không tính lại | Test quét `lib/` cấm lớp AI chứa phép so `type` hay `transfer`; test đối chiếu gói số = số màn đang hiện |
| 2 | Luật phát hiện thâm hụt và chọn nguồn bù chạy trên ngân sách thật | Test thuần ba ca: có nguồn bù, cạn nguồn bù, không có ngân sách |
| 3 | Người dùng đánh dấu được danh mục "cố định" và luật tôn trọng cờ | Test: danh mục có cờ không bao giờ là nguồn bù dù dư địa lớn |
| 4 | Bảng phản hồi cục bộ ghi chấp nhận / từ chối / sửa | Không nằm trong `SyncEntityType`; test quét cấm lọt vào đường đồng bộ |
| 5 | Câu có nhánh "chưa đủ dữ liệu" trung thực | Test tài khoản rỗng và nền bằng 0: không câu nào in phần trăm |
| **Tầng SLM trên máy** | | |
| 6 | Mô hình tải về và chạy **trên thiết bị**, không gọi mạng khi suy luận | Tắt mạng máy ảo rồi hỏi, vẫn trả lời; không request nào đi ra |
| 7 | Suy luận trong isolate, giao diện không đứng | Đo khung hình khi sinh câu; `lib/` có `Isolate.run` ở đúng một chỗ |
| 8 | Thời gian trả lời đo được trên **máy thật**, ghi kèm cấu hình | Bảng đo: nạp, câu đầu, câu tiếp, RAM đỉnh |
| **Kết hợp và bộ chắn** | | |
| 9 | Mô hình chỉ nhận gói số, không nhận giao dịch thô | Đầu vào lớp gọi mô hình là kiểu gói số, không tham chiếu bảng giao dịch |
| 10 | Bộ kiểm số: mọi con số trong câu phải có trong gói số, sai thì rơi về mẫu | Test với câu bịa có chủ ý: bị chặn, mẫu hiện ra |
| 11 | Rơi về mẫu khi mô hình chưa tải / máy yếu / pin thấp / lỗi runtime | Test từng nhánh; máy ảo: gỡ tệp mô hình, câu mẫu vẫn hiện |
| 12 | Câu luôn kèm thẻ số liệu, số trên thẻ bằng số trong gói | Widget test đối chiếu |
| 13 | Câu cache theo dấu vân gói số, không sinh lại sau mỗi chu kỳ đồng bộ | Phát lại stream với dữ liệu không đổi: mô hình không được gọi lần hai |
| **Riêng tư, sản phẩm, bằng chứng** | | |
| 14 | Không đổi schema đồng bộ, không thêm trường payload | `sync_payload_contract_test.dart` không đổi |
| 15 | Khối giao diện mới có màn Stitch trước khi dựng | Mã màn ghi trong tài liệu |
| 16 | Nghiệm thu máy ảo 411dp và một máy thật, có ảnh chụp | Khối bàn giao ở mục 14 `PROJECT_CONTEXT.md` |
| 17 | `flutter test` và `flutter analyze` ở mức nền | Con số trong tài liệu bàn giao |

**Không bắt buộc:** phần học thói quen theo thời gian (CV, elasticity, EMA — giai đoạn sau, trình
diễn trên dữ liệu mô phỏng được); đủ 39 luật (35 luật đã điều chỉnh là đủ); iOS; hỏi đáp tự do
trong màn Trợ lý AI (có thì tốt, câu theo màn mới là cốt lõi).

**Không được tính là đã áp dụng:** spike chạy mô hình rời; Tầng 3 chỉ có mẫu câu (đó là Edge, chưa
SLM); gửi gói số lên Gemini server (phương án 2); mô hình nhận giao dịch thô và tự tính; câu sinh
ra không có bộ kiểm số.

---

## 14. Hệ thống có đạt được 17 điều kiện không

**Có, với xác suất cao ở 14 điều kiện và một ẩn số thật ở 3 điều kiện** (6, 7, 8), và ẩn số ấy đo
được trong hai ngày.

| Điều kiện | Dựa vào gì đã có |
|---|---|
| 1, 2, 5 | Nhịp chi, dự báo 30 ngày, thu nhập, top khoản chi là hàm thuần có test; nhánh "chưa đủ dữ liệu" có tiền lệ ở so cùng kỳ năm trước |
| 3 | Cùng khuôn cờ `allow_negative` (G27, 2026-09-17) |
| 4, 14 | Cùng khuôn bảng thông báo; đã có bảy test quét canh cột cục bộ không lọt vào đồng bộ |
| 9–13 | Thuần Dart, test trọn vẹn, không phụ thuộc mô hình; cache theo dấu vân là bài học stream phát lại ở trang Phân tích |
| 15–17 | Quy trình đã chạy cho mọi tính năng từ đầu tháng |

Ước lượng bước 1 cộng bộ chắn: **một tới hai tuần** theo nhịp hiện tại, tính cả Stitch, test và
nghiệm thu máy ảo.

Ba câu chưa có đáp án cho 6–8: gói Flutter bọc MediaPipe có chạy với bản Flutter và `minSdk` của
dự án không; máy thật nạp mô hình mất bao lâu và ăn bao nhiêu RAM; **chất lượng tiếng Việt** có
hơn mẫu câu không. Ba kịch bản sau spike:

| Kết quả spike | Hệ quả |
|---|---|
| Nạp < 10 s, trả lời < 5 s, tiếng Việt đọc được | Làm bước 3, đạt đủ 17 |
| Chạy được nhưng chậm hoặc tiếng Việt kém | Vẫn đạt 17 về kỹ thuật; đổi vai mô hình từ sinh câu sang chọn câu để giữ chất lượng |
| Không chạy trên máy thật | Không đạt 6–8. Hai lối: máy cao hơn, hoặc phương án 2 — khi ấy phải gọi đúng tên là *Edge + diễn giải trên server*, không phải Edge-SLM |

Phần khó về kiến trúc đã xong từ trước khi ai nghĩ tới AI: mọi con số đã có một định nghĩa duy nhất
và có test. Phần còn lại của tầng Edge là ghép. Rủi ro duy nhất nằm gọn ở ba điều kiện về mô hình,
và là rủi ro **đo được rẻ**. Thứ tự đúng: spike → bước 1 song song sửa tài liệu → bước 3. Điều
không dám hứa: chất lượng câu tiếng Việt của mô hình nhỏ — chỉ spike trả lời được.

---

## 15. Máy demo Snapdragon 8 Gen 3 / 12 GB — khả thi và bậc thang mô hình

Cấu hình ấy là máy **đầu bảng**, cao hơn nhiều mốc "tầm trung". Ba điều kiện 6–8 từ ẩn số thành gần
như chắc về mặt **chạy được**; ẩn số còn lại là **chất lượng tiếng Việt** và **nhiệt** khi dùng lâu.

Trần thực tế trên 12 GB: khoảng 4 tỉ tham số nén 4 bit. Con số cỡ tệp là xấp xỉ, phải đo lại khi tải:

| Mô hình | Cỡ tệp xấp xỉ | Tiếng Việt | Ghi chú cho 8 Gen 3 |
|---|---|---|---|
| Gemma 3 1B, int4 | trên dưới 0,5 GB | đọc được, hay lủng củng | Nạp nhanh; chất lượng là giới hạn |
| Gemma 2 2B, int4 | ≈ 1,3 GB | khá | Gói MediaPipe hỗ trợ lâu đời nhất |
| Gemma 3n E2B | ≈ 3 GB | khá | Thiết kế cho di động đa phương thức; cần MediaPipe / LiteRT mới |
| **Gemma 3 4B, int4** | ≈ 2,5–3 GB | **tốt** | Bước nhảy chất lượng lớn nhất; vài token/giây với GPU, đủ cho vài câu |
| Gemma 3n E4B | ≈ 4,5 GB | tốt | Nặng hơn 4B mà chất lượng văn bản tương đương |
| Qwen 2.5 / Qwen 3 cỡ 1,5–4B, GGUF | 1–3 GB | **tốt**, thường nhỉnh hơn ở tiếng Việt | Qua llama.cpp, tốn công tích hợp hơn |

Bước nhảy đáng kể nhất nằm giữa 1B và 4B; trên 4B lợi ích giảm dần trên di động.

**Ba thứ vẫn phải giữ dù máy mạnh:** (1) **mô hình chọn theo máy, không ghi cứng** — dưới 4 GB
RAM dùng mẫu câu, 4–8 GB dùng 1B, trên 8 GB dùng 4B; máy demo chạy 4B, người dùng máy yếu vẫn có câu,
và đây là câu trả lời cho "máy thường thì sao"; (2) bộ kiểm số **không được nới** vì mô hình lớn
hơn; (3) **nói rõ máy demo là đầu bảng** — bảng đo ở điều kiện 8 nên có hai cột, máy demo và một máy
tầm trung nếu mượn được.

**Hai rủi ro mới khi lên mô hình lớn:** **tải về** (3 GB chỉ qua Wi-Fi, có tiến độ, có nút huỷ, mẫu
câu chạy trong lúc chờ) và **nhiệt** (8 Gen 3 chạy 4B liên tục vài phút sẽ tự giảm xung; câu theo màn
không sao vì sinh vài câu rồi nghỉ, hỏi đáp tự do kéo dài cần giới hạn độ dài và giữ H2 — spike nên
hỏi liên tiếp mười câu rồi so tốc độ câu thứ mười với câu đầu).

Với máy này, spike đổi mục đích từ "kiểm khả thi" sang "chọn mô hình và đo nhiệt". Mười bảy điều
kiện không đổi.

---

## 16. Chọn mô hình: Gemma 3 4B int4, kèm Gemma 3 1B dự phòng

**Lựa chọn:** **Gemma 3 4B nén 4 bit, chạy qua MediaPipe LLM Inference, kèm Gemma 3 1B cùng họ làm
bậc dự phòng cho máy yếu.**

**Vì sao:**

- **Tiếng Việt đủ tốt cho việc diễn giải.** Gemma 3 huấn luyện đa ngôn ngữ; bậc 4B là chỗ câu tiếng
  Việt bắt đầu trôi chảy. Việc của Tầng 3 là viết hai ba câu từ một gói số, nên 4B đủ và 1B thiếu.
- **Cùng họ với bậc dự phòng.** 1B và 4B cùng họ Gemma 3: cùng định dạng prompt, cùng runtime, cùng
  cách tải. Cấu hình theo RAM chỉ đổi tên tệp. Trộn Gemma với Qwen là hai runtime, hai kiểu prompt,
  gấp đôi chỗ hỏng.
- **Runtime chính chủ trên Android.** MediaPipe LLM Inference do Google làm cho họ Gemma, có gói
  Flutter cộng đồng bọc sẵn, dùng GPU trên 8 Gen 3. Ít công tích hợp nhất.
- **Cỡ tệp chịu được** (≈ 2,5–3 GB, tải một lần qua Wi-Fi) và **giấy phép** Gemma cho dùng trong
  sản phẩm.

**Vì sao không chọn hai ứng viên kia:**

| Ứng viên | Lý do xếp sau |
|---|---|
| Qwen 2.5 / Qwen 3 cỡ 3–4B | Tiếng Việt nhỉnh hơn một chút, nhưng phải tự tích hợp llama.cpp vào Flutter và không có bậc dự phòng cùng họ trên MediaPipe. Chênh chất lượng không bù được chênh công. **Phương án B** nếu spike cho thấy Gemma 3 4B viết tiếng Việt tệ hơn mong đợi |
| Gemma 3n E2B / E4B | Mạnh ở ảnh và âm thanh, thứ Tầng 3 không dùng; nặng hơn Gemma 3 4B mà văn bản tương đương; cần runtime mới hơn |

**Cách dùng cụ thể:**

- Nhiệt độ sinh ≈ 0,2 để câu ổn định giữa các lần và bộ kiểm số dễ làm việc.
- Prompt hệ thống cố định theo mục 3.2 của tài liệu, cộng hai ví dụ mẫu gói số → câu chuẩn. Số đưa
  vào prompt **đã định dạng sẵn** thành chuỗi tiếng Việt để mô hình chép nguyên.
- Giới hạn độ dài trả lời: ≈ 120 token cho câu theo màn, ≈ 300 cho hỏi đáp tự do.
- Nạp mô hình **một lần** khi mở app trên nền, giữ trong bộ nhớ suốt phiên. Không nạp lại mỗi màn.

**Spike phải xác nhận trước khi chốt — hai thứ, một ngày:** (1) câu tiếng Việt của 4B có hơn 1B
rõ rệt trên chính gói số của app không — nếu không, dùng 1B cho nhẹ; (2) mười câu liên tiếp trên
8 Gen 3 có giữ được tốc độ không — nếu tụt mạnh, giữ 4B cho câu theo màn và giới hạn hỏi đáp tự do.
