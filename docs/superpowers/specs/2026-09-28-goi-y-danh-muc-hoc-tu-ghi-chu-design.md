# B1 — Gợi ý danh mục học từ ghi chú (Naive Bayes cục bộ) — thiết kế

**Ngày:** 2026-09-28. **Người dùng duyệt** ba phần thiết kế trong chat (brainstorm, cùng buổi đo cổng F trên Realme).
Đây là dự án con **đầu tiên** của mảng máy học — lộ trình đầy đủ ở mục 7.

## 1. Vì sao, và vì sao làm trước

Màn Thêm giao dịch đã có thẻ *"Gợi ý danh mục"*: gõ ghi chú, chờ 300 ms, khớp **bảng từ khoá** của người dùng
(`CategorySuggestionEngine`, `category/data/services/category_suggestion_engine.dart`). Thẻ ấy **không học** — từ khoá
phải có người gõ vào — và **không ghi lại** việc người dùng bấm *Chọn* hay *Bỏ qua*.

Trong năm hướng máy học người dùng muốn làm, đây là hướng **duy nhất có dữ liệu học ngay hôm nay**: mỗi giao dịch đã lưu
có ghi chú + danh mục người dùng tự chốt là **một mẫu có nhãn**. Bốn hướng kia cần nhiều tháng dữ liệu (giao dịch sớm
nhất của cả CSDL là 02/09/2026) hoặc cần ghi phản ứng mà app chưa ghi. Người dùng chốt thứ tự *"theo dữ liệu sẵn có"*.

Đối chiếu thị trường: YNAB nhớ *người nhận → danh mục*; Copilot Money học từ những lần người dùng đổi danh mục; Monarch
kết hợp luật + học máy. B1 cùng họ Copilot — học từ chính các lần người dùng tự chốt danh mục — nhưng chạy **trên máy**.

## 2. Ba quyết định người dùng chốt

| Câu hỏi | Chốt |
|---|---|
| Đoán được thì làm gì | **Gợi ý trên thẻ sẵn có** — người dùng vẫn bấm *Chọn* / *Bỏ qua*; **không** tự chọn sẵn. Đoán sai tốn một cú chạm, không ghi sai gì |
| Ghi phản hồi không | **Có** — bảng cục bộ schema **v25**, không đồng bộ |
| Thuật toán | **Naive Bayes đa thức** trên âm tiết ghi chú, làm trơn Laplace |
| Thẻ nói lý do không | **Có** — dòng lý do sẵn có của thẻ đổi chữ theo nguồn; **không** vẽ lại Stitch (màn `20700200…` *"Thêm giao dịch - Gợi ý danh mục AI"* đã có đúng bố cục ấy) |

## 3. Kiến trúc

### 3.1 Hàm thuần — `lib/features/category/domain/phan_loai_ghi_chu.dart` (mới)

Đặt ở `category/domain/`, **không** ở `ai_edge/`: nó đọc sổ giao dịch, thứ test quét 14 cấm trong `ai_edge/`.

- **`List<MauGhiChu> mauHocTu(Iterable<({String loai, String? categoryId, String? ghiChu})> giaoDich)`** — mẫu có nhãn.
  Bỏ: không danh mục; ghi chú rỗng sau trim; `loai == 'transfer'`; và ghi chú **do máy sinh** — một hàm
  `laGhiChuMay(ghiChu, loai, categoryId)` gom mọi nhận dạng **đã có**, không viết lại chuỗi nào:
  `laKhoanDieuChinh`, `laKhoanMoSo` (qua `khoanVaoThongKe`), tiền tố `kGhiChuNapMucTieu`, `kGhiChuRutMucTieu`,
  `'Tích lũy nhận từ '` (tiền tố cũ ở `transaction_owner.dart`), `kGhiChuTraHoaDon`. Ghi chú máy gắn chứ không phải
  người dùng gõ — học chúng là dạy mô hình rằng *"thanh toán hóa đơn"* là một danh mục.
- **`List<String> amTiet(String ghiChu)`** — `normalizeCategoryName` → `removeVietnameseTones` (đúng chỗ của nó: đây là
  **gợi ý**, quy tắc 7 `CLAUDE.md`) → tách ở mọi ký tự không phải chữ/số → bỏ âm tiết **toàn chữ số** (*"500k"* giữ
  vì có chữ; *"9"*, *"2026"* bỏ) → khử trùng trong một ghi chú (một ghi chú nói *"cafe cafe"* không phải hai lần bằng
  chứng).
- **`BoPhanLoaiGhiChu.hoc(List<MauGhiChu> mau)`** — **Naive Bayes đa thức nhị phân hoá** (biến thể chuẩn cho văn bản
  ngắn: đếm theo *số ghi chú chứa âm tiết*, không theo số lần lặp). Đếm `N(c)` (số mẫu của danh mục), `N(t, c)` (số mẫu
  của `c` chứa âm tiết `t`), `S(c) = Σ_t N(t, c)`, từ vựng `V`.
- **`DoanDanhMuc? doan(String ghiChu, {required Set<String> hopLe, Set<(String, String)> tatCap = const {}})`**:
  - điểm `log(N(c) / tổng mẫu) + Σ_t log((N(t,c) + 1) / (S(c) + |V|))` (làm trơn Laplace) trên các âm tiết `t` của ghi
    chú **đã gặp trong V** — âm tiết lạ bỏ qua, không phải bằng chứng; chỉ cho `c ∈ hopLe`; chuẩn hoá (softmax trên các
    điểm) ra xác suất hậu nghiệm;
  - **`null` = chưa đủ để nói** khi: tổng mẫu < **10**; không âm tiết nào của ghi chú có trong `V`; danh mục đứng đầu có
    < **3** mẫu; xác suất đứng đầu < **0,6**; hoà ở đỉnh; hoặc cặp *(âm tiết đóng góp nhiều nhất, danh mục)* nằm trong
    `tatCap` (xem 3.3);
  - có kết quả thì mang `categoryId`, `xacSuat`, **`amTietChinh`** (âm tiết có `N(t,c)/N(t)` lớn nhất trong ghi chú,
    hoà thì âm tiết dài hơn), **`soLanCung`** = `N(t,c)`, **`soLanTong`** = `N(t)` (số mẫu chứa `t`, mọi danh mục).
- **`String cauLyDoHoc(DoanDanhMuc d, {required String ghiChuGoc, required String tenDanhMuc})`** — *"Bạn thường ghi
  “grab” cho Di chuyển (6/7 lần)."* ⚠️ Âm tiết in ra là **dạng người dùng đã gõ** trong `ghiChuGoc` (tìm lại đoạn có dấu
  khớp âm tiết bỏ dấu), không phải dạng bỏ dấu dùng để học — in *"ca phe"* khi họ gõ *"cà phê"* trông như máy lỗi.

Ngưỡng là hằng có tên và docstring nêu lý do (`kToiThieuMauTong = 10`, `kToiThieuMauDanhMuc = 3`,
`kNguongXacSuat = 0.6`), cùng khuôn `kToiThieuMauViHayDung` / `kTiLeApDaoViHayDung` của `vi_hay_dung.dart`.

### 3.2 Màn Thêm giao dịch

- Lượt đọc sổ giao dịch **đã có** ở `_loadViHayDung` (`transactionDao.getAll`) học thêm `BoPhanLoaiGhiChu` — **một**
  lần đọc cho hai bảng. Có tham số tiêm (`boPhanLoai`) như `viHayDung` để widget test không đụng SQLite.
- `_loadSuggestion`: **mô hình học đi trước**; `doan` trả `null` thì rơi về `suggestionEngine.suggest` như hôm nay.
  `hopLe` = mọi danh mục `selectableChildrenAll` trả về (cả ba phân loại) — ⚠️ **khác** bản trình trong chat (*"theo chiều
  Chi/Thu đang chọn"*): màn hiện tại cố ý không khoanh vùng gợi ý theo đoạn Chi/Thu vì chiều tiền suy từ danh mục; B1 theo
  nếp ấy.
- `CategorySuggestion` thêm **nguồn** (`hoc` | `tuKhoa`) và **câu lý do** đã dựng sẵn; `_buildSuggestionCard` in câu lý do
  thay cho chuỗi cứng *"Khớp với “…” trong ghi chú."* (câu ấy chuyển thành `cauLyDoTuKhoa` cho nguồn từ khoá).
- Mọi điều kiện huỷ gợi ý hiện có giữ nguyên (đổi đoạn, chuyển khoản, đã chọn danh mục, ghi chú đổi trong lúc chờ).

### 3.3 Bảng phản hồi cục bộ — schema **v25**

`GoiYDanhMucPhanHois` (`core/database/tables/goi_y_phan_hoi_table.dart`, khuôn `ai_feedback_table.dart`), **không**
`syncStatus` / `updatedAt` / `isDeleted`:

| Cột | Ý nghĩa |
|---|---|
| `id` | UUID |
| `idaccount` | từ phiên đăng nhập (quy tắc 2) |
| `createdAt` | lúc có kết quả |
| `nguon` | `hoc` \| `tu_khoa` |
| `amTietChinh` | âm tiết đã bỏ dấu (nguồn `hoc`), hoặc từ khoá khớp (nguồn `tu_khoa`) |
| `goiYCategoryId` | danh mục đã gợi ý |
| `ketQua` | `chon` \| `bo_qua` \| `khac` |
| `chonCategoryId` | danh mục cuối cùng lưu cùng giao dịch (`khac`), `null` khi bỏ qua mà không lưu |

- **Ghi lúc nào:** bấm *Chọn* → `chon`; bấm *Bỏ qua* → `bo_qua`; thẻ **đang hiện** mà người dùng chọn danh mục khác qua
  bảng chọn rồi lưu → `khac`. Thẻ bị huỷ vì đổi ghi chú / đổi đoạn → **không** ghi (không phải phán xét của người dùng).
- **Dùng vào:** (1) đo tỉ lệ gợi ý đúng thật; (2) **thôi gợi ý** một cặp *(amTietChinh, goiYCategoryId)* nguồn `hoc` đã có
  **2** hàng `bo_qua` → `tatCap` của `doan`.
- **Mở lại** (thêm lúc viết spec, **người dùng duyệt** 2026-09-28): cặp đã thôi gợi ý **mở lại** khi
  người dùng tự lưu **3** giao dịch mới cùng âm tiết cho đúng danh mục đó (bằng chứng mới thắng lời từ chối cũ), đếm trên
  giao dịch có `date` sau hàng `bo_qua` cuối. Không có luật này thì một lần bỏ qua lúc mới dùng app khoá cặp ấy **vĩnh
  viễn**, kể cả khi thói quen đã rõ.
- Migration `from < 25` → `createTable`; `purgeDataForOtherAccounts` và `purgeDataForAccount` xoá bảng mới; **test quét 15**
  thêm tên bảng / lớp / cột vào danh sách cấm ở ba tệp đồng bộ và hợp đồng payload.

### 3.4 Giao diện

Bố cục thẻ giữ nguyên (tiêu đề, tên danh mục, **dòng lý do**, *Bỏ qua* / *Chọn danh mục này*). Chỉ chữ dòng lý do đổi:

- nguồn học: *"Bạn thường ghi “grab” cho Di chuyển (6/7 lần)."*
- nguồn từ khoá: *"Khớp với “cafe” trong ghi chú."* (giữ nguyên câu hôm nay)

Nghiệm thu máy ảo 411dp: câu lý do dài (tên danh mục dài + âm tiết dài) không tràn; thẻ dùng `Text` có ngắt dòng sẵn.

## 4. Kiểm thử

- **`phan_loai_ghi_chu_test.dart`**: phép tính NB trên bộ mẫu nhỏ **tính tay được** (ghi lại phép tính trong `reason:`);
  mỗi ngưỡng một ca đứng ngay dưới / ngay trên ngưỡng; từng loại ghi chú máy bị loại; *"cà phê"* ≡ *"ca phe"*; bỏ âm tiết
  số; `hopLe` loại danh mục đã xoá; hoà → `null`; `tatCap` chặn và mở lại sau 3 mẫu mới; `cauLyDoHoc` in dạng có dấu.
  Mỗi chốt thử bằng **bản sai có chủ ý** (nếp của dự án).
- **Widget test** (`add_transaction_goi_y_hoc_test.dart`): gợi ý học hiện kèm câu lý do; mô hình `null` → thẻ từ khoá như
  cũ; ba loại phản hồi ghi đúng hàng; huỷ vì đổi ghi chú không ghi; đang sửa giao dịch không gợi ý.
- **Schema**: test migration v24 → v25; `schema_v24_test` và `bill_schema_v21_test` (đang khoá phiên bản) đổi theo.

## 5. Đo trên dữ liệu thật — con số cho đồ án

Test công cụ `test/tool/do_goi_y_danh_muc_test.dart` (skip mặc định, chạy tay, khuôn `kiem_csdl_that_test.dart`,
`FLOWMONEY_DB` + `FLOWMONEY_IDACCOUNT`): **leave-one-out** trên mọi mẫu của tài khoản — học trên mọi mẫu trừ một, đoán
mẫu ấy. Báo:

- **độ phủ** — phần trăm mẫu được gợi ý (không `null`);
- **độ đúng** — trong số được gợi ý, phần trăm trúng danh mục người dùng đã chốt;
- cùng hai số cho **bộ từ khoá cũ** trên cùng mẫu, để biết B1 có hơn không.

CSDL chép từ **máy ảo bản debug** (bản release trên Realme không `run-as` được). Khi app đã chạy thật một thời gian, bảng
phản hồi cho thêm **tỉ lệ chấp nhận thật** (`chon` / tổng).

## 6. Xử lý lỗi và giới hạn cố ý

- Học mô hình ném lỗi hoặc sổ rỗng → `null`, rơi về từ khoá, không toast.
- Chi phí: học `O(tổng âm tiết)` một lần khi mở màn; vài trăm giao dịch là không đáng kể. **Không** giới hạn số giao dịch
  học — YAGNI; đo lại khi có tài khoản vài nghìn giao dịch.
- **Không** tự chọn sẵn danh mục, **không** gợi ý khi chưa gõ ghi chú (tín hiệu số tiền / giờ / ví — để sau nếu cần),
  **không** đồng bộ mô hình hay phản hồi giữa hai máy (mỗi máy tự học từ sổ đã đồng bộ, nên kết quả gần như nhau).

## 7. Lộ trình các phần còn lại (người dùng chốt 2026-09-28)

**A1 → A2 · A3 · A4 → B1 → B5a → B2 → B3 → B4 → B5b.** Nhóm A là sửa mã có sẵn — mỗi việc trình thiết kế ngắn trong chat
khi tới lượt; nhóm B mỗi dự án con một vòng brainstorm → spec → kế hoạch riêng.

| # | Việc | Ghi chú |
|---|---|---|
| A1 | Vòng sửa theo kết quả cổng F | Chờ chấm (mục 9.36 `AI_EDGE_FEATURE.md`); báo hướng sửa trước khi sửa |
| A2 | Định tuyến câu cũ về phiên một tool | Chữa hỏng chuỗi số (bẫy 4.51); so với mốc cổng F |
| A3 | Tool dự báo in hai hàng quá hạn trùng | Gộp ở tool, không đụng `duBaoCua` của trang Phân tích |
| A4 | Toast *"Một số thay đổi chưa lên được máy chủ"* | Điều tra hàng đợi đồng bộ |
| **B1** | **Gợi ý danh mục học từ ghi chú** | **Spec này** |
| B5a | Ghi phản ứng với thông báo | Hạ tầng: `readAt` đang lẫn "đọc" với "mở"; chạm thông báo hệ điều hành / *Hoãn* chưa ghi gì. Làm sớm để dữ liệu tích dần |
| B2 | Khoản lặp → gợi ý tạo hoá đơn | Cần ≥ 2–3 chu kỳ; kiểm bằng dữ liệu dựng trong test |
| B3 | Chi bất thường theo danh mục | Cần nhiều tháng; nền là `chuoiTheoDanhMuc`, chưa có độ lệch chuẩn ở đâu |
| B4 | Dự báo chi kỳ tới | Cần nhiều tháng; dự báo 30 ngày hiện **cố ý** không đoán chi tuỳ ý (người dùng chốt 2026-09-16) — B4 phải là quyết định mới, không lặng lẽ lật cái cũ |
| B5b | Học giờ / tần suất thông báo | Cần B5a tích đủ; **không đụng `dedupeKey`** |
