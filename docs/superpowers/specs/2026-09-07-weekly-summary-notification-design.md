# Tổng kết tuần — thiết kế, và lý do hoãn

> **Trạng thái: ĐANG LÀM, từ 2026-09-09.** Bốn câu hỏi mở đã chốt với người
> dùng (mục 5), và điều kiện ở mục 3 **đã đủ** — xem ghi chú 2026-09-09 ở đó.
>
> Từ 2026-09-07 tới 2026-09-09 tài liệu này ở trạng thái *hoãn có chủ ý*: câu
> chữ đã chốt, hình dạng kỹ thuật đã dò xong, nhưng chỗ thông báo dẫn tới chưa
> tồn tại.

Loại thông báo này đứng **đầu** danh sách việc còn lại của mảng thông báo:
Monarch và Capital One đều có, FlowMoney thiếu hẳn. Nó bị hoãn không phải vì
khó, mà vì **chỗ nó dẫn tới chưa tồn tại**.

---

## 1. Vì sao hoãn

Câu chữ người dùng chọn là một lời mời: *"Xem lại bạn đã tiêu vào đâu."* Một
thông báo như thế chỉ có giá trị bằng đúng cái màn hình nó mở ra. Mà màn hình
ấy hiện chưa có.

**Đo được ngày 2026-09-07:**

| Đường dẫn | Trạng thái |
|---|---|
| `/analytics` | `AnalyticsPage` là `StatelessWidget` chỉ import `material.dart`, `app_colors.dart`, `go_router`. **Không** một tham chiếu `Bloc`/`Repository`/`Dao`/`context.read` nào. Mọi con số viết cứng trong mã: `'Tháng này (T6 2026)'`, `'+25.000.000đ'`, `'Tăng 12% so với T5'` |
| `/analytics/export`, `/export-report` | `ExportReportPage` — **đã đọc dữ liệu thật từ 2026-09-09** (lát 2c), mở màn `ReportPreviewPage` và xuất được tệp PDF/CSV |
| `/transactions` | **Dữ liệu thật**, có dòng tổng thu/chi/net và bộ lọc. Nhưng xem theo **THÁNG** (`_selectedMonthDate`) |
| `/home` | **Dữ liệu thật** — giao dịch gần đây, tổng thu/chi tháng |

Không có chỗ nào trong app xem được **một tuần**.

Người dùng đã quyết (2026-09-07): **chuẩn bị tài liệu, làm sau, khi phần thống
kê/báo cáo đã có thật.**

### Phương án đã cân nhắc và loại bỏ

- **Trỏ tạm vào `/transactions`.** Trang xem theo tháng, nên tuần vừa kết thúc
  nằm lẫn trong tháng và người dùng phải tự nhặt ra. Tệ hơn: một tuần **vắt qua
  hai tháng** (thứ Hai 29/06 → Chủ nhật 05/07) thì họ chỉ thấy một nửa, mà
  không có gì trên màn hình nói cho họ biết là đang thiếu. Một lời mời dẫn tới
  chỗ sai còn hại hơn không mời.
- **Trỏ vào `/home`.** Thật nhưng nhạt: chạm vào thông báo rồi quay về đúng chỗ
  vừa đứng thì gần như không đi đâu cả.
- **Nối trang Phân tích vào dữ liệu thật trước.** Đúng chỗ đáng lẽ phải đến,
  nhưng đó là một việc riêng, lớn hơn hẳn — và lúc viết spec, vùng `analytics`
  không có tệp test nào. **Việc ấy đã làm xong 2026-09-08** (lát 2a, 4 tệp
  test — `docs/ANALYTICS_FEATURE.md`), nhưng trang ấy hiện theo **tháng**, nên
  điều kiện ở mục 3 vẫn chưa đủ.

---

## 2. Quyết định đã chốt với người dùng (2026-09-07)

**Câu chữ — tối giản, không nêu số:**

```
Tổng kết tuần
Tuần qua đã khép lại. Xem lại bạn đã tiêu vào đâu.
```

Ba phương án còn lại đã bị loại: so với tuần trước (*"chi ít hơn tuần trước
18%"*), thu và chi trần (*"thu 4,2 triệu · chi 3,1 triệu"*), và danh mục tiêu
nhiều nhất (*"chi nhiều nhất cho Ăn uống"*).

**Lý do:** đây là sở thích đã nêu nhiều lần của người dùng — thông báo tối
giản, nội dung chung chung, số liệu để trong app. Và nó đúng về bản chất: thông
báo là **cái cửa**, không phải bản báo cáo. Ghi chú trong kế hoạch gốc cũng nói
đúng điều này — *"nói gì trong một dòng mà không thành bảng số liệu"*.

**Hệ quả kỹ thuật quan trọng:** câu chữ ấy khiến bộ luật gần như **không cần dữ
liệu gì**. Nó chỉ cần biết tuần vừa rồi **có giao dịch nào không**. Không tổng
thu, không tổng chi, không gom theo danh mục. Toàn bộ chi phí của tính năng nằm
ở **chỗ đến**, không nằm ở luật — đó là lý do chỗ đến quyết định lịch làm, chứ
không phải ngược lại.

---

## 3. Điều kiện để bắt đầu

Một màn hình có **dữ liệu thật, phạm vi đúng một tuần**. Có thể là trang Phân
tích sau khi được nối vào dữ liệu, hoặc một màn tổng kết tuần riêng.

> **Cập nhật 2026-09-08:** tầng tổng hợp đã có — `tongThuChi` / `chiTheoDanhMuc`
> trong `lib/features/analytics/domain/thong_ke_thang.dart` nhận biên
> `[from, to)` bất kỳ, nên "một tuần" chỉ là một cặp mốc. Thứ còn thiếu là
> **màn hình** phạm vi tuần (trang Phân tích chọn theo tháng). Đó là một lát
> giao diện nhỏ, không còn là "việc riêng, lớn hơn hẳn" như mục 1 từng nói.

Chừng nào chưa có, đừng dựng thông báo này — kể cả với một chỗ đến tạm.

> **✅ Đã đủ — cập nhật 2026-09-09.** Lát 2c của mảng Phân tích (làm xong
> **sau** ghi chú 2026-09-08 ở trên) cho `ExportReportPage` một phạm vi
> **`PhamViThoiGian.tuyChinh`** với bộ chọn khoảng ngày, và `ReportPreviewPage`
> dựng trọn mười khối báo cáo cho **khoảng bất kỳ**. Màn hình phạm vi tuần vì
> thế đã tồn tại; không cần dựng màn mới, cũng không cần một thiết kế Stitch
> mới. Điều kiện ở mục này coi như đóng.

---

## 4. Hình dạng kỹ thuật — sáu chỗ phải chạm

Đã dò xong trên mã hiện tại. Thêm một `NotificationKind` là chạm đúng những chỗ
này, không hơn:

1. **`NotificationKind` trong `lib/core/notification/notification_rules.dart`**
   — thêm `weeklySummary`. ⚠️ `.name` được **ghi thẳng vào cột `kind`**, nên
   tên hằng là một **định dạng dữ liệu**: đổi tên về sau là bỏ rơi mọi hàng cũ.

2. **Một hàm luật thuần** `_weeklySummaryCandidates(input)`, rồi ghép vào
   `buildNotificationCandidates`. Hàm thuần, không đọc đồng hồ, không chạm CSDL
   — đây là nơi đặt gần như toàn bộ test.

3. **Khoá chống trùng** `weekly:<yyyy>-W<ww>` theo tuần ISO. ⚠️ Dart **không có
   sẵn** số tuần ISO; phải tự viết. Hai cái bẫy: tuần vắt qua giao thừa thuộc
   về **một** tuần ISO duy nhất, và **năm của tuần ISO không phải lúc nào cũng
   là `date.year`** (31/12/2025 nằm trong tuần 1 của năm 2026). Dự án này có
   quy ước phủ test cả tháng ngắn lẫn năm nhuận cho mọi logic ngày tháng —
   ranh giới năm là ca tương đương ở đây.

4. **`nhomCua()` trong `prefs/notification_prefs.dart`** — chọn nhóm.
   **Khuyến nghị: một nhóm MỚI** (`summary` — "Tổng kết"). Không dùng nhóm
   `system`: nhóm ấy đang là *"Đồng bộ hỏng và số dư ví âm"*, và ai tắt tổng
   kết tuần vì thấy phiền thì **không** có ý tắt luôn cảnh báo ví âm. Đây đúng
   là loại nhầm lẫn mà commit `dfb8721` đã phải đi sửa một lần.
   Kho tuỳ chọn lưu **nhóm bị TẮT** chứ không phải nhóm được bật, nên nhóm mới
   tự động **bật** với mọi bản ghi cũ — chính là lý do định dạng ấy được chọn.
   `luonBao()` phải trả `false`: đây không phải loại báo tiền rời ví.
   Thêm nhóm thì phải thêm một thẻ trong `notification_settings_page.dart`.

5. **`deeplinkTuDedupeKey()` trong `notification_deeplink.dart`** — thêm tiền
   tố `weekly`. Đây là bản **sao** có chủ ý của cột `deeplink` (cold start
   không tra CSDL được), và có test dựng ứng viên thật cho **cả 13 loại** rồi
   đối chiếu. Quên ánh xạ là test đỏ ngay — cố ý.

6. **Biểu tượng.** `_bieuTuong` switch theo `subjectType`, và nó bị **nhân đôi**
   ở `notification_panel.dart` và `notification_center_page.dart`. Một
   `subjectType` mới (ví dụ `'week'`) rơi vào nhánh mặc định `Icons.notifications_none`
   ở **cả hai**. Muốn biểu tượng riêng thì phải sửa hai chỗ — hoặc gộp chúng
   lại trước, việc ấy đằng nào cũng nên làm.

Kèm theo, ngoài sáu chỗ trên:

- **`NotificationRuleInput` thêm đúng một trường.** Với câu chữ đã chốt, trường
  ấy là một `bool` — *"tuần vừa kết thúc có ít nhất một giao dịch"* — chứ không
  phải tổng thu/chi. Giữ đầu vào hẹp đúng như lớp ấy đã tự đặt quy tắc cho
  `syncFailed`: *"là `bool` chứ không phải cả `SyncStatus`, vì bộ luật chỉ cần
  biết hỏng hay không, và thu hẹp đầu vào thì test không phải dựng một enum của
  tầng khác chỉ để hỏi một câu."*
- **`NotificationScanner` thêm một loader**, theo đúng khuôn `loadWallets` /
  `loadGoals` (tham số tuỳ chọn, mặc định rỗng).
- `TransactionDao` hiện chỉ có `getSummaryByMonth`; cần một phép đếm theo
  **khoảng** ngày. Với câu chữ đã chốt thì chỉ cần *có hay không*, đừng viết
  hàm tính tổng khi chưa ai dùng đến nó.

---

## 5. Câu hỏi đã chốt (2026-09-09)

> **Bốn câu, không phải năm.** Mục này vốn có **ba** câu (a, b, c); con số "5"
> đi qua ba tài liệu tóm tắt là đếm theo trí nhớ, đã sửa 2026-09-09. Câu **(d)**
> là câu thứ tư, phát hiện khi rà lại mã ngày 2026-09-09.

**Người dùng chốt 2026-09-09:** (a) theo phương án **giờ do người dùng chọn**;
(b), (c), (d) theo đề nghị.

### a) Nổ lúc nào, và có nổ khi app đóng không?

Đây là câu **quan trọng nhất**, và nó chưa được hỏi người dùng.

Bảng thông báo hiện có **ba mốc quét**: `start()`, `AppLifecycleState.resumed`,
và trạng thái kết thúc của `SyncEngine`. Cả ba đều đòi **người dùng mở app**.

Tổng kết tuần là loại thông báo **kéo người dùng quay lại**. Một thông báo kéo
người quay lại mà chỉ đến được với người **đã** quay lại thì gần như vô nghĩa.
Loại duy nhất hiện đi qua `ReminderScheduler` (tức nổ được khi app đóng hẳn) là
nhắc hoá đơn.

⚠️ Nếu chọn `ReminderScheduler`: **lịch đặt trước không đi qua giờ im lặng**
(quyết định ở mục 5c `NOTIFICATION_FEATURE.md`, có lý do). Nghĩa là mốc "thứ Hai
08:00" sẽ **kêu cả trong khung giờ im lặng** của người dùng. Đó là một quyết
định phải nói ra, không phải một tai nạn — và nó là điểm khác biệt thật giữa
tổng kết tuần và nhắc hoá đơn: giờ nhắc hoá đơn do người dùng tự chọn và đang
nhìn thấy trên màn hình, còn mốc tổng kết tuần là do app tự đặt.

### ✅ CHỐT (a): `ReminderScheduler`, và **giờ do người dùng chọn**

Người dùng chọn phương án tốn hơn thay vì mốc cố định 08:00 thứ Hai, và lý do
nằm ngay ở đoạn cảnh báo trên: điều khiến nhắc hoá đơn không phiền **không phải**
là giờ của nó, mà là việc giờ ấy **do người dùng đặt và đang nhìn thấy trên màn
hình**. Đặt một mốc cố định rồi để nó xuyên qua giờ im lặng là app tự quyết thay
người dùng đúng ở chỗ họ đã nói rằng họ quan tâm.

Hệ quả: cần **một ô cấu hình mới** trong trang Cài đặt thông báo — chọn *thứ*
trong tuần và *giờ*. Mặc định **thứ Hai 08:00** để bản cài mới vẫn có hành vi
hợp lý mà không bắt ai phải cấu hình trước.

Vì lịch nằm trong AlarmManager chứ không trong SQLite, đổi cấu hình phải **huỷ
lịch cũ rồi đặt lại** — cùng ràng buộc mà `NotificationScanner.stop()` phải gọi
`cancelAll()` (quy tắc 9 `CLAUDE.md`).

### b) Biên tuần

Khuyến nghị: **thứ Hai → Chủ nhật** (quy ước Việt Nam), và luật chỉ nhìn **một
tuần liền trước**, không quét ngược nhiều tuần. Chỉ nhìn một tuần thì cửa sổ
`silenceBefore` (30 ngày) không bao giờ phải gánh việc chặn lũ, và `createdAt`
đặt bằng **thời điểm kết thúc tuần** để phép lọc ấy so đúng.

### ✅ CHỐT (b): theo khuyến nghị.

### c) Tuần trống thì sao?

Khuyến nghị: **không báo**. Tổng kết của việc không có gì là nhiễu thuần tuý —
và đây đúng là dữ liệu duy nhất mà luật cần đọc (mục 4).

### ✅ CHỐT (c): theo khuyến nghị.

---

### d) Chạm vào thông báo thì mở đi đâu?

Câu này **không có trong bản 2026-09-07** — nó lộ ra khi rà lại mã ngày
2026-09-09. `ReportPreviewPage` nhận một đối tượng `BaoCao` **dựng sẵn** qua
`extra` của go_router, nên **khởi động nguội không mở thẳng nó được**: `extra`
không sống qua một tiến trình mới, và cold start thì không tra CSDL được (đó
đúng là lý do `deeplinkTuDedupeKey` tồn tại).

Hai đường:

- **Mở `/export-report` với phạm vi đặt sẵn là tuần vừa rồi** — thêm tham số
  truy vấn cho route, an toàn với khởi động nguội. Người dùng thấy trang đã
  chọn đúng tuần và bấm thêm một lần để xem báo cáo đầy đủ.
- **Route mới dựng thẳng báo cáo rồi hiện màn xem trước** — bớt một cú chạm,
  nhưng phải cho trang xem trước một lối vào cấp route tự dựng dữ liệu.

### ✅ CHỐT (d): đường thứ nhất.

`/export-report?from=<ISO>&to=<ISO>` đặt `PhamViThoiGian.tuyChinh` với đúng
khoảng ấy. Rẻ hơn nhiều, và trang Xuất báo cáo **đã hiện số thật** từ lát 2c nên
nó không phải một chỗ trống. Tham số đi qua **query string** chứ không qua
`extra`, đúng vì lý do cold start ở trên.

---

## 6. Việc đã làm trong phiên 2026-09-07

Chỉ có tài liệu này. Không có mã, không có test, không có gì phải hoàn tác.

Ba việc kiểm trên máy ảo của cùng phiên (`khoaNhom`, thông báo khi app đóng
hoàn toàn, giờ im lặng) nằm ở `docs/NOTIFICATION_FEATURE.md` mục 5c và mục 8,
không liên quan tới tài liệu này.

⚠️ Thư mục `docs/superpowers/specs/` bị `.gitignore` **dòng 67** chặn — tệp này
phải `git add -f`, nếu không nó biến mất âm thầm.
