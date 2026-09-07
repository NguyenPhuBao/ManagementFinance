# Tổng kết tuần — thiết kế, và lý do hoãn

> **Trạng thái: hoãn có chủ ý, 2026-09-07.** Không một dòng mã nào được viết.
> Tài liệu này tồn tại để phiên sau không phải bàn lại từ đầu — câu chữ đã
> chốt với người dùng, hình dạng kỹ thuật đã dò xong, và điều kiện để bắt đầu
> đã ghi rõ.

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
| `/analytics/export`, `/export-report` | `ExportReportPage` — cùng tình trạng, 0 tham chiếu dữ liệu |
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
  nhưng đó là một việc riêng, lớn hơn hẳn, và vùng `analytics` hiện **không có
  tệp test nào**.

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

Chừng nào chưa có, đừng dựng thông báo này — kể cả với một chỗ đến tạm.

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

## 5. Câu hỏi còn mở — phải chốt trước khi viết mã

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

### b) Biên tuần

Khuyến nghị: **thứ Hai → Chủ nhật** (quy ước Việt Nam), và luật chỉ nhìn **một
tuần liền trước**, không quét ngược nhiều tuần. Chỉ nhìn một tuần thì cửa sổ
`silenceBefore` (30 ngày) không bao giờ phải gánh việc chặn lũ, và `createdAt`
đặt bằng **thời điểm kết thúc tuần** để phép lọc ấy so đúng.

### c) Tuần trống thì sao?

Khuyến nghị: **không báo**. Tổng kết của việc không có gì là nhiễu thuần tuý —
và đây đúng là dữ liệu duy nhất mà luật cần đọc (mục 4).

---

## 6. Việc đã làm trong phiên 2026-09-07

Chỉ có tài liệu này. Không có mã, không có test, không có gì phải hoàn tác.

Ba việc kiểm trên máy ảo của cùng phiên (`khoaNhom`, thông báo khi app đóng
hoàn toàn, giờ im lặng) nằm ở `docs/NOTIFICATION_FEATURE.md` mục 5c và mục 8,
không liên quan tới tài liệu này.

⚠️ Thư mục `docs/superpowers/specs/` bị `.gitignore` **dòng 67** chặn — tệp này
phải `git add -f`, nếu không nó biến mất âm thầm.
