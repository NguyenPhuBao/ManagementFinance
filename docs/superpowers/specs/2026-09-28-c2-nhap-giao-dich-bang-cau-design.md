# C2 — Nhập giao dịch bằng câu (ô "Nhập nhanh" ở màn Thêm giao dịch) — thiết kế

**Ngày:** 2026-09-28 (tối). **Người dùng duyệt** bản thiết kế trong chat cùng ngày, với các lựa chọn: ô **"Nhập nhanh" ở
màn Thêm giao dịch** (không ở màn Trợ lý AI) · **chỉ luật**, không mô hình · **một câu một khoản** · nhận cả bốn cách nói
tiền: *k / nghìn / ngàn*, *tr / triệu / củ*, *lít / xị (= 100.000)*, và *số viết bằng chữ*. Bất biến ④ nhóm C: *"không tool
nào ghi thẳng"*, tức form điền sẵn và người dùng bấm **Lưu**. Tầng hậu quả 3. Thứ tự nhóm C: C1 → **C2** → D1 → C3 → C4.
**Phụ thuộc B1** (đoán danh mục). **Không đổi schema.**

## 1. Vì sao

Ghi một khoản chi hôm nay tốn: chọn loại, gõ tiền trên bàn phím tự vẽ, chọn danh mục, chọn ví, đổi ngày, gõ ghi chú, tức
năm sáu thao tác. Người dùng nói bằng câu (*"hôm qua ăn phở 45k ví tiền mặt"*) nhanh hơn nhiều. D1 (đọc biến động số dư)
và C4 (giọng nói, chụp hoá đơn) sẽ dùng **chung** bộ đọc câu và đường điền sẵn này.

**Chỉ luật** (người dùng chốt): nhanh (< 50 ms), chạy trên mọi máy kể cả máy không có mô hình, và **không bao giờ bịa
số**. Ô nào luật không đọc được thì để nguyên.

## 2. Hàm thuần — `lib/features/transaction/domain/doc_cau_giao_dich.dart`

`KetQuaDocCau docCauGiaoDich(String cau, {required DateTime now, required List<Wallet> vi, required List<Category> chonDuoc, BoPhanLoaiGhiChu? mo, Set<(String, String)> tatCap = const {}})`

`KetQuaDocCau { double? soTien; String? loai; DateTime? ngay; String? walletId; String? categoryId; String? lyDoDanhMuc; String ghiChu; List<String> canhBao; }`
Mọi trường `null` nghĩa là *không đọc được*, và form **giữ nguyên** ô ấy.

### 2.1 Số tiền

Tách câu thành các **cụm tiền** theo thứ tự xuất hiện, ưu tiên cụm có đơn vị:

| Dạng | Giá trị |
|---|---|
| `45k`, `45 k`, `45 nghìn`, `45 ngàn`, `45 nghin`, `45 ngan` | × 1.000 |
| `2tr`, `2 tr`, `2 triệu`, `2 trieu`, `2 củ`, `2 cu` | × 1.000.000 |
| `1tr2` / `1tr200` | 1.200.000 (phần sau `tr` là phần lẻ theo **hàng trăm nghìn** nếu một chữ số, theo nghìn nếu ba chữ số) |
| `1,2 triệu`, `1.5tr` | 1.200.000, 1.500.000 (phẩy **hoặc** chấm thập phân khi đứng trước đơn vị triệu) |
| `2 lít`, `2 lit`, `3 xị`, `3 xi` | × 100.000 |
| số viết bằng chữ: *"năm mươi nghìn"*, *"một triệu rưỡi"* | bộ đọc số bằng chữ (§2.6) |
| số trần có chấm nghìn / không chấm: `45.000`, `45000` | chỉ nhận khi **≥ 1.000** |

- Số trần < 1.000 **không** đọc (người dùng chốt): *"2 ly cà phê"* là số lượng.
- ⚠️ *"lít"* còn là đơn vị xăng. Có **nhiều** cụm tiền thì cụm **k / nghìn / tr / số trần ≥ 1.000** được ưu tiên trước
  *lít / xị*: *"đổ 2 lít xăng 50k"* → 50.000. Chỉ có cụm *lít / xị* thì mới dùng nó.
- Sau ưu tiên mà còn ≥ 2 cụm cùng hạng → lấy cụm **đầu** và thêm cảnh báo *"Câu có nhiều số tiền — mình chỉ điền khoản
  đầu."* (một câu một khoản, người dùng chốt).
- Kết quả ≤ 0 hoặc > 13 chữ số (`kSoChuSoToiDaSoTien`, trần cột `numeric(15,2)`) → không đọc, kèm cảnh báo.

### 2.2 Loại (chi / thu)

- Câu chứa từ thu (so trọn âm tiết trên chữ bỏ dấu): *nhận, được, lương, thưởng, thu, bán, hoàn tiền, hoàn, lãi* →
  `'thu'`. Không có → `null` (form **giữ** loại đang chọn; mặc định của form là chi).
- ⚠️ *"thu"* trong *"thu nợ"* thuộc vay/nợ: câu có *nợ / vay* thì **không** đặt loại (để người dùng chọn), vì chiều tiền
  của vay/nợ đọc từ danh mục + ô *Chiều tiền* (mục 3.22 `ANALYTICS_FEATURE.md`).

### 2.3 Ngày

- `hôm nay`, `sáng nay`, `trưa nay`, `chiều nay`, `tối nay` → hôm nay; `hôm qua` → hôm qua; `hôm kia` → hai ngày trước;
  `thứ 2` … `thứ 7`, `chủ nhật` / `cn` → ngày gần nhất **trong quá khứ hoặc hôm nay** có thứ ấy; `5/9`, `05/09`, `ngày 5/9`
  → ngày ấy của **năm hiện tại** (không hợp lệ thì bỏ; nếu rơi vào tương lai quá 7 ngày thì lùi một năm).
- Không nêu → `null` (form giữ ngày của nó). Giờ trong ngày giữ như form (chỉ đổi phần ngày).
- **Một định nghĩa:** phép đọc ngày tách thành `DateTime? ngayTrongCau(String cau, DateTime now)` ở
  `core/utils/ngay_trong_cau.dart`. `kyTuCauHoi` (`ai_edge/domain/ma_ky.dart`) **gọi lại** hàm ấy cho các chữ một ngày
  (*hôm nay / hôm qua / hôm kia*), để app không có hai định nghĩa của *"hôm qua"*.

### 2.4 Ví

- Tên ví nêu trong câu → `khopTheoTen` (`core/utils/khop_ten.dart`) trên các ví **đang hoạt động** (`getActive`, bộ chọn
  ví, không phải `getAll`: test quét `wallet_picker_sources_test` sẽ đòi phân loại chỗ gọi). Khớp đúng một → ví ấy.
- *"tiền mặt"* / *"tien mat"* mà không khớp tên nào → ví loại `cash` nếu có **đúng một**.
- Không đọc được → `null`.

### 2.5 Danh mục

- Tên danh mục nêu trong câu (`khopTheoTen` trên `chonDuoc`, lọc theo chiều tiền như C1 `hopLeTheoChieu`) → danh mục ấy,
  `lyDoDanhMuc = null`.
- Không nêu → `mo?.doan(ghiChu, hopLe: …, tatCap: tatCap)` của B1 trên **ghi chú đã rút** (§2.7). Có kết quả thì kèm
  `cauLyDoHoc`.
- Chiều tiền dùng cho bộ lọc: `loai` đọc được ở 2.2, không có thì loại đang chọn trên form (tham số `loaiHienTai` truyền
  vào hàm).

### 2.6 Bộ đọc số bằng chữ — dời ra `core/utils/so_bang_chu.dart`

`_mauSoChu`, `_giaTriSoChu`, `_soChu`, `_donViChu` hôm nay là phần riêng tư của `ai_edge/domain/kiem_so.dart`. Mảng
`transaction` không được import `ai_edge`. Dời thành `List<({int batDau, int ketThuc, double giaTri})> timSoBangChu(String cau)`
ở `core/utils/so_bang_chu.dart`, và `kiem_so.dart` gọi lại. **Không đổi hành vi** của `kiemSo`: toàn bộ test của nó xanh
nguyên, kể cả các ca bẫy 4.42 (*"một triệu"*, lượng từ mơ hồ, *"500 nghìn"* giữ cách đọc cũ).

### 2.7 Ghi chú

Câu gốc, **bỏ** các đoạn đã dùng cho số tiền, ngày và ví (kèm chữ *"ví"*, *"bằng"*, *"bằng ví"* đứng ngay trước tên ví),
gom khoảng trắng, bỏ dấu câu thừa ở hai đầu, **giữ nguyên** dấu và chữ hoa. *"hôm qua ăn phở 45k ví tiền mặt"* → *"ăn
phở"*. Tên danh mục nêu trong câu **giữ lại** trong ghi chú (*"45k ăn uống với bạn"* → *"ăn uống với bạn"*), vì đó thường
là nội dung người dùng muốn nhớ.

## 3. Giao diện — màn Thêm giao dịch

- Ô **"Nhập nhanh"** ở **đầu** màn, **chỉ ở đường tạo mới** (màn sửa giao dịch không có). Gợi ý: *"VD: hôm qua ăn phở 45k
  tiền mặt"*. Bấm **Điền** (hoặc Enter) thì chạy `docCauGiaoDich`.
- Ghi đè **chỉ** những ô đọc được: số tiền (qua **đúng** đường bàn phím tự vẽ đang dùng, để trạng thái biểu thức và trần
  13 chữ số của `themPhimSoTien` nhất quán), loại, ngày, ví (⚠️ đánh dấu *"người dùng đã tự đặt ví"* để luật ví hay dùng
  theo danh mục, mục 1.2, **không** đè lại), danh mục, ghi chú.
- Dưới ô: một dòng tóm tắt *"Đã điền: 45.000 đ · Hôm qua · Tiền mặt · Ăn uống"* (tiền qua `CurrencyFormatter`), kèm
  cảnh báo nếu có, và câu lý do danh mục nếu đến từ B1. Không đọc được gì → *"Mình chưa đọc được câu này — bạn điền tay
  nhé."*
- Người dùng xem lại rồi bấm **Lưu** như thường. **Không** tự lưu.
- ⚠️ Giao diện mới → **Stitch trước**. ⚠️ Màn Thêm giao dịch có bẫy bố cục đã biết (số 13 chữ số ngắt dòng, `FittedBox`)
  và bàn phím tự vẽ. Ô mới không được đẩy bàn phím ra khỏi màn ở khổ 360 × 640.

## 4. Không làm

Không mô hình. Không tách nhiều khoản. Không ở màn Trợ lý AI. Không tự lưu. Không đổi schema.

## 5. Giới hạn nói trước

- Câu tự do quá xa khuôn (*"cái hôm đi Đà Lạt tốn mấy trăm"*) → không đọc được số, người dùng điền tay.
- *"thứ 2"* luôn là thứ Hai **gần nhất đã qua hoặc hôm nay**; nói về thứ Hai tuần sau thì phải chọn ngày tay.
- Ví trùng tên gần nhau (*"Tiết kiệm"* và *"Tiết kiệm 2"*) → `khopTheoTen` có thể không ra đúng một, và ô ví giữ nguyên.

## 6. Kiểm thử

- **`docCauGiaoDich` (hàm thuần), mỗi dạng ở §2.1 một ca:** `45k`, `45 nghìn`, `45 ngàn`, `2tr`, `1tr2`, `1tr200`,
  `1,2 triệu`, `2 củ`, `2 lít`, `3 xị`, *"năm mươi nghìn"*, *"một triệu rưỡi"*, `45.000`, `45000`; `"2 ly cà phê"` → `null`;
  *"đổ 2 lít xăng 50k"* → 50.000; *"ăn sáng 30k, grab 50k"* → 30.000 + cảnh báo; 14 chữ số → `null` + cảnh báo.
- **Loại:** *"nhận lương 9tr"* → thu; *"thu nợ anh Nam 500k"* → `null`; câu trơn → `null`.
- **Ngày:** hôm nay / hôm qua / hôm kia; *"thứ 2"* khi hôm nay thứ Tư → thứ Hai tuần này; khi hôm nay thứ Hai → hôm nay;
  `31/2` → `null`; đọc ngày 3/1/2027, `30/12` → 30/12/**2026** (30/12/2027 ở tương lai quá 7 ngày nên lùi một năm);
  đọc ngày 3/1/2027, `5/1` → 5/1/2027 (tương lai 2 ngày, giữ). Tháng ngắn, năm nhuận: `29/2` năm thường → `null`, năm
  nhuận → hợp lệ.
- **Ví / danh mục:** tên ví trong câu; *"tiền mặt"* với một và với hai ví cash; tên danh mục trong câu thắng B1; danh mục
  thu không được chọn cho khoản chi.
- **Ghi chú:** các ví dụ ở §2.7.
- **`so_bang_chu` (phép dời):** toàn bộ test `kiem_so_test` xanh không sửa kỳ vọng.
- **`ngayTrongCau` + `kyTuCauHoi`:** test `ma_ky_test` và `chinh_tham_so_test` xanh không sửa kỳ vọng.
- **Widget màn Thêm giao dịch:** gõ câu → bấm *Điền* → các ô đúng, dòng tóm tắt đúng; ô không đọc được giữ giá trị cũ;
  màn **sửa** giao dịch không có ô; khổ 360 × 640 không tràn; bấm *Lưu* ra đúng giao dịch (khuôn `so_tien_thap_phan_test`
  dựng `GoRouter` thật vì lưu xong trang `pop`).
- **Máy ảo:** mười câu thật kiểu người dùng hay gõ, đếm số ô điền đúng. Đây là phép đo, không phải cổng; ghi bảng vào tài
  liệu.

## 7. Tài liệu đi kèm

Tài liệu tính năng giao dịch (hoặc mục mới trong `PROJECT_CONTEXT.md` mục 14): bảng quy đổi §2.1, luật ưu tiên *lít*,
giới hạn §5. `AI_EDGE_FEATURE.md`: `so_bang_chu` và `ngay_trong_cau` dời ra `core/utils`. `CLAUDE.md` hàng *Đụng vào ô nhập
TIỀN* (một câu: ô Nhập nhanh đi qua cùng đường bàn phím tự vẽ).
