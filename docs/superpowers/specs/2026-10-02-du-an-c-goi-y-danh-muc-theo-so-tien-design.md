# Dự án C, việc đầu — gợi ý danh mục theo số tiền khi ghi chú không giúp được — thiết kế

**Ngày:** 2026-10-02. **Trạng thái:** 📝 người dùng **duyệt thiết kế trong chat** (sáu lượt AskUserQuestion); bản viết này
chờ người dùng đọc lại. Chưa có kế hoạch, chưa có dòng mã nào.

Dự án C là dự án thứ ba của bộ A → B → C (mục 10.3 `docs/AI_EDGE_FEATURE.md`): *app học trên máy của từng người, mở
rộng khuôn B1*. Nó gồm nhiều việc độc lập, mỗi việc một spec; đây là việc **đầu tiên** người dùng chọn. Ba việc còn lại
ở mục 9.

## 1. Vì sao

Màn Thêm giao dịch có thẻ *"Gợi ý danh mục"* từ B1, nhưng thẻ ấy chỉ chạy khi ô ghi chú có chữ: mô hình B1 học từ ghi
chú, bảng từ khoá khớp trên ghi chú. Ghi chú trống thì không có gợi ý nào (`_onNoteChanged` thoát ngay khi
`note.isEmpty`).

Đo trên CSDL dev ngày 2026-10-02, tài khoản 10 (55 giao dịch sống, 52 trong tháng 9):

| | Số hàng |
|---|---|
| Khoản thu / chi (`Type = Transaction`) | 43 |
| … có danh mục | 39 |
| … có ghi chú | 25 |
| … **không** ghi chú | **18** |

Tức khoảng bốn phần mười khoản nhập tay nằm ngoài tầm của B1. Và mục 5d `docs/CATEGORY_RATIONALE.md` đã ghi: dữ liệu
thật gần như không có ghi chú tự gõ, nên gợi ý học từ ghi chú **im** ở phần lớn trường hợp.

**Giờ không dùng được.** `_selectedDate` khởi tạo bằng `DateTime.now()` và `showDatePicker` trả về 00:00, nên giờ lưu
trong giao dịch là **giờ nhập**, không phải giờ chi. Người dùng chốt bỏ tín hiệu giờ.

**Thị trường.** Wallet (BudgetBakers) học từ cách người dùng tự gắn danh mục và có *mẫu giao dịch* (tên, ví, danh mục,
số tiền) cho khoản nhập lại; Spendee và Money Lover tự gắn danh mục chủ yếu cho giao dịch kéo từ ngân hàng / SMS (dựa
tên nơi bán). Không tìm thấy app nhập tay nào công bố việc đoán danh mục chỉ từ số tiền. *Mẫu giao dịch* là thứ gần
nhất và phổ biến nhất — ghi ở mục 9, không làm lần này.

## 2. Quyết định người dùng chốt

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Việc đầu của dự án C | **Gợi ý danh mục khi không ghi chú** |
| 2 | Tín hiệu | **Số tiền + thứ + ví.** Không giờ |
| 3 | Cách hiện | **Thẻ gợi ý như B1** (Chọn / Bỏ qua). Không tự điền sẵn danh mục |
| 4 | Phạm vi | Màn Thêm giao dịch: ghi chú trống, **và** ghi chú có chữ mà B1 lẫn từ khoá đều im. Không làm màn Gắn danh mục nhanh, không làm form biến động số dư |
| 5 | Cách học | **Naive Bayes ba tín hiệu** — cùng khuôn B1. Không chọn *đếm quanh ±20 %*, không chọn *khớp đúng số tiền* |
| 6 | Thứ | Gom hai nhóm **ngày thường / cuối tuần** (không dùng bảy giá trị) |
| 7 | Chốt cho câu lý do | Danh mục gợi ý phải **dẫn đầu bậc tiền** với ít nhất 3 khoản |
| 8 | Ngưỡng dừng khi đo | Gợi ý hiện ra đúng dưới **60 %** trên CSDL thật → dừng, hỏi người dùng |

## 3. Hành vi trên màn Thêm giao dịch

### 3.1 Khi nào thẻ hiện

Thẻ nguồn *số tiền* hiện khi **mọi** điều sau đúng:

- chưa chọn danh mục (`_selectedCategory == null`);
- đoạn đang chọn là Chi tiêu hoặc Thu nhập (không phải Chuyển khoản);
- không ở chế độ sửa (`_editing == null`) và form không mở từ biến động số dư (`_bienDong == null`);
- số tiền là **một con số lớn hơn 0** — đang gõ dở phép tính (`30+`) thì chưa tính;
- ghi chú trống, **hoặc** ghi chú có chữ mà B1 và bảng từ khoá đều trả `null`.

Thứ tự nguồn của thẻ: **B1 → từ khoá → số tiền**. Ghi chú có chữ thì vẫn chạy B1 và từ khoá trước như hôm nay; nguồn số
tiền chỉ là lớp cuối.

### 3.2 Lúc nào tính lại

- Sau khi người dùng dừng gõ số tiền **300 ms** (cùng độ trễ `_doTreGoiY` của ghi chú).
- Khi đổi ví, đổi ngày, đổi đoạn Chi tiêu ↔ Thu nhập.
- Khi ghi chú đổi (đường `_onNoteChanged` → `_loadSuggestion` rơi xuống nguồn số tiền).
- Sau khi ô *Nhập nhanh* điền xong mà danh mục còn trống.

Mỗi lượt tính kiểm lại trạng thái form trước khi `setState`, cùng nếp `_loadSuggestion`: giữa lúc hẹn và lúc tính người
dùng có thể đã chọn danh mục hoặc đổi số tiền.

### 3.3 Thẻ

Đúng widget `_buildSuggestionCard` hiện có (tiêu đề *Gợi ý danh mục*, tên danh mục, câu lý do, *Bỏ qua* / *Chọn danh mục
này*), nằm ngay dưới hàng *Danh mục*. Chỉ khác **câu lý do**:

- *"Khoản từ 20.000 đ đến 50.000 đ bạn thường ghi cho Ăn uống (6/7 lần)."*
- bậc thấp nhất: *"Khoản dưới 10.000 đ bạn thường ghi cho Di chuyển (4/5 lần)."*

Số tiền in qua `CurrencyFormatter.format` (test quét 11 cấm nối `đ` tay). `6/7` = số mẫu của danh mục ấy ở bậc ấy / số
mẫu của bậc ấy, **cùng chiều** với đoạn đang chọn. Không cần màn Stitch mới: không thêm khối giao diện nào.

*Chọn danh mục này* đi qua `_chonDanhMuc` như mọi nguồn — nên luật *ví hay dùng theo danh mục* vẫn chạy sau đó.

### 3.4 Phản hồi và thôi gợi ý

Ghi vào bảng cục bộ sẵn có `GoiYDanhMucPhanHois` với `nguon = 'so_tien'`, `amTietChinh` = **mã bậc** (mục 4.2):

| Người dùng làm | `ketQua` |
|---|---|
| Bấm *Chọn danh mục này* | `chon` |
| Bấm *Bỏ qua* | `bo_qua` |
| Thẻ đang hiện, người dùng chọn danh mục **khác** rồi lưu | `khac` |
| Thẻ bị huỷ vì số tiền sang bậc khác, đổi đoạn, đổi ghi chú | không ghi — không phải phán xét |

**Hai** lần `bo_qua` cùng cặp (mã bậc, danh mục) → thôi gợi ý cặp ấy. Mở lại khi người dùng tự lưu **ba** giao dịch có
ngày sau lần bỏ qua cuối, ở đúng bậc ấy, cho đúng danh mục ấy. Hai hằng dùng lại của B1 (`kSoLanBoQuaThoiGoiY`,
`kSoMauMoLai`). Tập tắt của nguồn `so_tien` **riêng**: bỏ qua thẻ số tiền không tắt thẻ B1, và ngược lại.

## 4. Phép học

### 4.1 Mẫu

Một mẫu = một giao dịch thoả cả bốn điều:

- có danh mục, chưa xoá;
- `type` là `thu` hoặc `chi` (không `transfer`);
- không do máy sinh — dùng nguyên `laGhiChuMay` của B1 (trả hoá đơn, nạp / rút mục tiêu, điều chỉnh số dư, số dư ban
  đầu);
- số tiền lớn hơn 0.

Có hay không có ghi chú đều tính: tín hiệu ở đây là số tiền, không phải chữ. Toàn bộ sổ, không cắt cửa sổ thời gian (như
B1).

Mỗi mẫu mang: danh mục, **chiều** (`thu` / `chi`), bậc tiền, nhóm thứ, ví, ngày.

### 4.2 Ba đặc trưng

| Đặc trưng | Giá trị |
|---|---|
| **Bậc tiền** | Thang 1·2·5 × 10^k. Bậc của số tiền `x` là `[a, b)` với `a` là mốc thang lớn nhất không vượt `x`, `b` là mốc kế. Dưới 10.000 là **một** bậc `[0, 10.000)`. Không có trần. Ví dụ: 35.000 → `[20.000, 50.000)`; 50.000 → `[50.000, 100.000)`; 3.000.000 → `[2.000.000, 5.000.000)`. **Mã bậc** = `"<a>-<b>"` bằng số nguyên đồng (`"20000-50000"`, `"0-10000"`) |
| **Nhóm thứ** | `ngay_thuong` (thứ Hai – thứ Sáu) · `cuoi_tuan` (thứ Bảy, Chủ nhật) — theo ngày của giao dịch |
| **Ví** | `walletId` |

So biên bằng ngưỡng **nửa đồng** (`amount` là `double`).

### 4.3 Đoán

Đầu vào: chiều của đoạn đang chọn, số tiền, ngày, ví trên form, tập danh mục hợp lệ, tập cặp đang tắt.

1. Chỉ dùng mẫu **cùng chiều**. Số tiền không mang nghĩa chiều, nên đoạn Chi / Thu là thông tin chiều duy nhất: 9.000.000
   dưới đoạn Thu là *Lương*, dưới đoạn Chi là *Nhà cửa*.
2. Naive Bayes phân loại với làm trơn Laplace, trên mọi danh mục có mẫu cùng chiều:
   `điểm(c) = log N(c)/N + Σ_f log (N(f = v, c) + 1) / (N(c) + K_f)`, `K_f` = số giá trị khác nhau của đặc trưng `f`
   trong các mẫu cùng chiều (ít nhất 2).
3. Hậu nghiệm tính trên **mọi** danh mục đã học; `hopLe` chỉ lọc ứng viên — cùng lý lẽ B1 (tính trên phần còn lại là đẩy
   danh mục duy nhất còn sống lên 100 %). `hopLe` = `hopLeTheoChieu(chiều, selectableChildrenAll)`.

Trả `null` — thẻ **im** — khi bất kỳ điều nào sau đúng:

| Chốt | Ngưỡng |
|---|---|
| Sổ mỏng | dưới `kToiThieuMauTong` = 10 mẫu cùng chiều |
| Danh mục đứng đầu ít mẫu | dưới `kToiThieuMauDanhMuc` = 3 |
| Hậu nghiệm thấp | dưới `kNguongXacSuat` = 0,6 |
| Hoà ở đỉnh | hai ứng viên cùng điểm |
| **Không dẫn đầu bậc tiền** | danh mục đoán có dưới 3 mẫu ở đúng bậc ấy, **hoặc** có danh mục khác (cùng chiều) nhiều mẫu bằng hoặc hơn ở bậc ấy |
| Cặp đang tắt | (mã bậc, danh mục) ∈ tập tắt |

Chốt *dẫn đầu bậc tiền* là chốt riêng của nguồn này: thiếu nó thì một gợi ý thắng nhờ ví và thứ sẽ in *"(2/9 lần)"* —
câu lý do nói ngược gợi ý.

Ba hằng ngưỡng **dùng lại** của `phan_loai_ghi_chu.dart`, không khai bản thứ hai.

## 5. Vị trí mã

| Tệp | Việc |
|---|---|
| `lib/features/category/domain/phan_loai_so_tien.dart` (mới, thuần) | `bacTienCua` · `maBac` · `nhomThuCua` · `MauSoTien` · `mauSoTienTu` · `BoPhanLoaiSoTien.hoc` / `.doan` · `DoanSoTien` · `cauLyDoSoTien` · `tatCapSoTienTu` · hằng `kNguonGoiYSoTien = 'so_tien'` |
| `lib/features/transaction/presentation/pages/add_transaction_page.dart` | học trong `_loadViHayDung` (cùng **một** lượt đọc sổ với ví hay dùng và B1) · hẹn tính khi số tiền / ví / ngày / đoạn đổi · `_loadSuggestion` rơi xuống nguồn số tiền · đường ghi chú trống · nạp tập tắt trong `_napTatCap` · `_choPhanXu` huỷ khi bậc đổi |
| `lib/core/database/tables/goi_y_phan_hoi_table.dart` | chỉ sửa chú thích cột `nguon` (thêm `so_tien`) |
| `test/features/category/domain/phan_loai_so_tien_test.dart` (mới) | mục 7.1 |
| `test/features/transaction/presentation/add_transaction_goi_y_so_tien_test.dart` (mới) | mục 7.2 |
| `test/tool/do_goi_y_so_tien_test.dart` (mới, `skip`) | mục 7.3 |

Đặt ở `category/domain/`, không ở `ai_edge/`: nó đọc sổ giao dịch và so chiều tiền, thứ test quét 14 cấm trong
`ai_edge/`. Cùng chỗ với `phan_loai_ghi_chu.dart`.

`tatCapTu` của B1 gắn với `MauGhiChu` (đếm mẫu chứa cụm âm tiết), nên nguồn số tiền có hàm riêng `tatCapSoTienTu` cùng
luật, đếm mẫu theo bậc. Hai hằng số lần dùng chung.

## 6. Thứ không đổi

- Schema (vẫn v27), payload đồng bộ, `pubspec`, bảng `GoiYDanhMucPhanHois` (chỉ thêm một giá trị cho cột chuỗi `nguon`).
- B1, bảng từ khoá, đề xuất thêm từ khoá, ví hay dùng theo danh mục, ô Nhập nhanh, màn Gắn danh mục nhanh, form biến động.
- Không gọi Gemma: đây là tầng số (mục 10.3 `AI_EDGE_FEATURE.md` — cá nhân hoá nằm ở tầng số, không ở mô hình ngôn ngữ).
- Không ghi thẳng: thẻ chỉ đề nghị, người dùng bấm *Chọn* rồi bấm ✓ mới lưu.

## 7. Kiểm thử và đo

Mỗi ca canh thử bằng **bản sai có chủ ý**; ca xanh ngay là ca chưa canh gì.

### 7.1 Hàm thuần

- Biên bậc tiền: 9.999 · 10.000 · 19.999 · 20.000 · 49.999 · 50.000 · 1.000.000 · 13 chữ số; đuôi lẻ `double`.
- Nhóm thứ: thứ Sáu / thứ Bảy / Chủ nhật / thứ Hai; ngày 29/02.
- Mẫu: bỏ chuyển khoản, khoản máy sinh, khoản không danh mục, khoản đã xoá; **giữ** khoản không ghi chú.
- Từng chốt im ở mục 4.3, mỗi chốt một ca; ca dương cho từng chốt vừa đủ ngưỡng.
- Chiều: cùng bậc tiền, đoạn Chi và đoạn Thu ra hai danh mục khác nhau; danh mục vay/nợ có mẫu ở cả hai chiều.
- `hopLe` lọc ứng viên nhưng không đổi hậu nghiệm.
- Câu lý do: bậc thường, bậc thấp nhất, con số `c/t` đúng theo chiều.
- Thôi gợi ý: một lần bỏ qua chưa tắt; hai lần thì tắt; ba mẫu mới cùng bậc cùng danh mục thì mở lại; mẫu khác bậc
  không mở; phản hồi của nguồn `hoc` không tắt nguồn `so_tien`.

### 7.2 Màn Thêm giao dịch

- Ghi chú trống + số tiền → thẻ hiện với câu lý do theo bậc.
- B1 lên tiếng → thẻ B1; từ khoá lên tiếng → thẻ từ khoá; cả hai im → thẻ số tiền.
- Không hiện khi: đã có danh mục · Chuyển khoản · đang sửa · form biến động · số tiền 0 · phép tính dở.
- Đổi đoạn Chi → Thu: thẻ đổi theo (hoặc biến mất).
- *Chọn* → danh mục được điền, ghi `chon` nguồn `so_tien`; *Bỏ qua* → ghi `bo_qua`; lưu với danh mục khác → `khac`; đổi
  số tiền sang bậc khác rồi lưu → không ghi.
- Bố cục 360 × 640 khi 16 phím số đang mở, dựng bằng `AppTheme.lightTheme` (bẫy 4.11) — không tràn.

### 7.3 Công cụ đo trên CSDL thật

`test/tool/do_goi_y_so_tien_test.dart`, `skip`, chạy tay với `FLOWMONEY_DB` / `FLOWMONEY_IDACCOUNT` (cùng khuôn
`do_goi_y_danh_muc_test.dart`). **Phát lại theo thời gian**: với giao dịch thứ *i*, học từ các giao dịch có ngày trước
nó, đoán, so với danh mục thật. In: số khoản xét · số lần gợi ý · đúng · sai · tỉ lệ đúng, tách theo có / không ghi chú.

⚠️ Lấy ứng viên qua `selectableChildrenAll` như màn (bài học của công cụ đo B1, `9f407e6`).

### 7.4 Cổng ra

1. `flutter test` trọn bộ xanh, `flutter analyze` giữ mức nền 26.
2. Công cụ đo chạy trên CSDL của máy đang cắm và ghi nguyên kết quả vào tài liệu. **Tỉ lệ đúng dưới 60 %** (trên ít
   nhất 5 lần gợi ý) → dừng, hỏi người dùng. Dưới 5 lần gợi ý → ghi *"chưa đủ để nói"*, không coi là đạt hay trượt.
3. Nghiệm thu máy đang cắm, chấm theo thứ hiện ra trên màn. Tài khoản đang đăng nhập trên OnePlus (id 26) mới có 5 giao
   dịch nên thẻ im; muốn thấy thẻ thật cần khoảng 12 giao dịch thử — **hỏi người dùng trước khi tạo**.

## 8. Rủi ro đã biết

- **Thẻ nằm dưới vùng nhìn thấy.** Ở 360 dp, khi 16 phím số đang mở, thẻ (dưới hàng *Danh mục*) có thể bị che; người
  dùng chỉ thấy khi cuộn hoặc ẩn bàn phím. `flutter test` không thấy được — kiểm trên máy thật. Nếu thẻ không ai thấy
  thì báo người dùng trước khi sửa bố cục.
- **Dữ liệu mỏng.** Tài khoản lớn nhất có 39 mẫu trong một tháng; phần lớn lượt đoán sẽ im. Đó là hành vi đúng (mỗi luật
  học có ngưỡng, dưới ngưỡng thì im hẳn), nhưng nghĩa là giá trị thật chỉ đo được sau vài tháng dùng.
- **Naive Bayes coi ba tín hiệu độc lập** — ví và danh mục thật ra tương quan (luật ví hay dùng theo danh mục đặt ví từ
  danh mục), nên hậu nghiệm có thể tự tin quá. Chốt *dẫn đầu bậc tiền* chặn phần lớn; công cụ đo cho biết phần còn lại.
- **Biên bậc.** 49.000 và 51.000 rơi hai bậc. Chấp nhận (người dùng chọn hướng A dù đã nghe nhược điểm này).
- **Vòng lặp học sai.** Gợi ý sai mà người dùng bấm *Chọn* thành mẫu, củng cố chính cái sai. Cùng câu hỏi mở của C2 (spec
  C2 §8 câu 8, người dùng chọn *theo dõi sau đo*); ở đây chốt *Bỏ qua hai lần* và ngưỡng 0,6 là hai lực cản.

## 9. Ngoài phạm vi

- **Mẫu giao dịch** kiểu Wallet (một chạm điền cả danh mục + số tiền + ví cho khoản quen) — việc riêng, cần Stitch.
- Màn *Gắn danh mục nhanh* và form *biến động số dư* dùng nguồn số tiền — người dùng không chọn lần này.
- Tín hiệu giờ; thứ theo bảy giá trị.
- Ba việc còn lại của dự án C, mỗi việc một spec khi tới lượt: ngưỡng cảnh báo ngân sách theo nhịp chi riêng (cần ≥ 3
  tháng dữ liệu) · thứ tự khối trang Phân tích · thông báo theo phản ứng.
- Học mức thiết yếu từ `AiRebalancingFeedbacks`, tự đề xuất cờ Cố định (mục 11.4 `AI_EDGE_FEATURE.md`).
