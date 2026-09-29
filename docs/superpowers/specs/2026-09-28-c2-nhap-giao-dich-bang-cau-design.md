# C2 — Nhập giao dịch bằng câu (ô "Nhập nhanh" ở màn Thêm giao dịch) — thiết kế

**Ngày:** 2026-09-28 (tối). **Người dùng duyệt** bản thiết kế trong chat cùng ngày, với các lựa chọn: ô **"Nhập nhanh" ở
màn Thêm giao dịch** (không ở màn Trợ lý AI) · **chỉ luật**, không mô hình · **một câu một khoản** · nhận cả bốn cách nói
tiền: *k / nghìn / ngàn*, *tr / triệu / củ*, *lít / xị (= 100.000)*, và *số viết bằng chữ*. Bất biến ④ nhóm C: *"không tool
nào ghi thẳng"*, tức form điền sẵn và người dùng bấm **Lưu**. Tầng hậu quả 3. Thứ tự nhóm C: C1 → **C2** → D1 → C3 → C4.
**Phụ thuộc B1** (đoán danh mục). **Không đổi schema.**

> **Soát với mã B1 + C1 đã thi công (2026-09-29, trước Task 1).** Sáu chỗ đổi so với bản trên; ba chỗ đầu người dùng
> chọn bằng câu hỏi chọn cùng ngày, ba chỗ sau là nếp sẵn của dự án:
> 1. **Bộ đọc số bằng chữ đầy đủ, một định nghĩa cho ba nơi (§2.6).** Đo bằng test tạm: bộ đọc của `kiem_so` trả **rỗng**
>    cho *"năm mươi nghìn"*, *"hai mươi lăm nghìn"*, *"nam muoi nghin"* (không có hàng chục *mươi*); và có một **bản thứ
>    hai** ở `chinh_tham_so.dart` (chữ bỏ dấu, cho ngưỡng tiền câu hỏi) cũng không đọc hàng chục — *"dưới năm mươi
>    nghìn"* ra **không ngưỡng nào** trong khi *"dưới 50k"* ra 50.000. Nên T1 không "dời không đổi hành vi" mà dựng **một**
>    bộ đọc đầy đủ ở `core/utils/so_bang_chu.dart` (hàng chục *mươi*, *mốt / tư / lăm / nhăm*, *linh / lẻ*; có dấu và
>    không dấu), và **cả** `kiem_so` lẫn `chinh_tham_so` gọi lại nó. Hệ quả cố ý: `kiemSo` chặt hơn (số chữ hàng chục nay
>    được kiểm), Trợ lý AI đọc được ngưỡng viết bằng chữ. Mọi ca test cũ của hai tệp ấy phải xanh không sửa kỳ vọng.
> 2. **Lọc chiều của B1 theo nếp màn (§2.5).** Màn Thêm giao dịch cho B1 đoán trên **cả ba** phân loại (đoạn Chi/Thu chỉ
>    là lối vào, danh mục kéo đoạn theo — `_loadSuggestion`). Nên chỉ lọc `hopLeTheoChieu` khi câu **nói rõ** chiều
>    (`loai != null`); câu không nói thì B1 chọn trên mọi danh mục chọn được, như thẻ gợi ý. Không còn tham số
>    `loaiHienTai` cho phép lọc.
> 3. **Danh mục điền từ B1 ghi phản hồi như thẻ gợi ý.** Lưu với đúng danh mục đoán → `chon`; đổi → `khac`. Nên
>    `KetQuaDocCau` mang cả `DoanDanhMuc? doan` (cần `cumBoDau` cho `CategorySuggestion`), và màn đặt `_choPhanXu` sau khi
>    điền.
> 4. **Tìm tên trong câu (§2.4, §2.5):** `khopTheoTen` so **trọn chuỗi**, không tìm tên nằm giữa câu. Hàm tìm tên trong câu
>    là `tenNeuTrongCau` (`ai_edge/domain/chinh_tham_so.dart`: khớp trọn từ trên chữ bỏ dấu, tên dài trước, tên ngắn
>    dưới 5 ký tự chỉ nhận ngay sau từ loại) — dời ra `core/utils/khop_ten.dart`, `ai_edge` gọi lại. Ví dùng từ loại
>    *"ví"*; danh mục dùng *"danh mục"* (tên danh mục ngắn như *"Học"* chỉ đọc được khi câu viết *"danh mục học"*; còn
>    lại rơi về B1).
> 5. **`kyTuCauHoi` không đọc *"hôm qua"* (§2.3):** nó đọc kỳ nêu cụ thể (tháng 8, quý 2, từ … đến …); *"hôm qua"* đi qua
>    mã kỳ `hom_qua` → `kyTuMa`. Nên `kyTuCauHoi` **không đổi** (nhánh ⚠️ của kế hoạch T2). Thứ dùng chung là `ngayHopLe`
>    (kiểm ngày tồn tại trên lịch) — dời ra `core/utils/ngay_trong_cau.dart`, `ma_ky.dart` gọi lại.
> 6. **Đổi chiều trên màn đi qua `_chonHuong` (§3),** không gán thẳng `_huong`: `_chonHuong` bỏ danh mục thuộc chiều kia,
>    gán thẳng là để danh mục chi đứng dưới đoạn Thu. Test bố cục có thêm ca **bàn phím hệ thống đang mở** (G58: 16 phím
>    ẩn khi `viewInsets.bottom > 0`, mà ô Nhập nhanh là ô chữ). Nghiệm thu trên **Realme** (máy thật đang cắm), không máy ảo.

## 1. Vì sao

Ghi một khoản chi hôm nay tốn: chọn loại, gõ tiền trên bàn phím tự vẽ, chọn danh mục, chọn ví, đổi ngày, gõ ghi chú, tức
năm sáu thao tác. Người dùng nói bằng câu (*"hôm qua ăn phở 45k ví tiền mặt"*) nhanh hơn nhiều. D1 (đọc biến động số dư)
và C4 (giọng nói, chụp hoá đơn) sẽ dùng **chung** bộ đọc câu và đường điền sẵn này.

**Chỉ luật** (người dùng chốt): nhanh (< 50 ms), chạy trên mọi máy kể cả máy không có mô hình, và **không bao giờ bịa
số**. Ô nào luật không đọc được thì để nguyên.

## 2. Hàm thuần — `lib/features/transaction/domain/doc_cau_giao_dich.dart`

`KetQuaDocCau docCauGiaoDich(String cau, {required DateTime now, required List<Wallet> vi, required List<Category> chonDuoc, BoPhanLoaiGhiChu? mo, Set<(String, String)> tatCap = const {}})`

`KetQuaDocCau { double? soTien; String? loai; DateTime? ngay; String? walletId; String? categoryId; DoanDanhMuc? doan; String? lyDoDanhMuc; String ghiChu; List<String> canhBao; }`
— `doan` khác `null` khi danh mục đến từ B1 (banner mục 3).
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
  `core/utils/ngay_trong_cau.dart`, cùng `ngayHopLe` (dời từ `ai_edge/domain/ma_ky.dart`, tệp ấy gọi lại).
  ⚠️ `kyTuCauHoi` **không** gọi `ngayTrongCau`: nó chỉ đọc kỳ nêu cụ thể, còn *"hôm qua"* của Trợ lý AI đi qua mã kỳ
  `hom_qua` → `kyTuMa` (banner mục 5) — hai phép không trùng định nghĩa.

### 2.4 Ví

- Tên ví nêu trong câu → `tenNeuTrongCau(cau, tenVi, tuLoai: 'ví')` (`core/utils/khop_ten.dart`, banner mục 4) trên các
  ví **đang hoạt động** (danh sách `_wallets` màn đã nạp bằng `getActive`, bộ chọn ví — không thêm chỗ đọc ví mới). Tên
  khớp đúng một ví → ví ấy.
- *"tiền mặt"* / *"tien mat"* mà không khớp tên nào → ví loại `cash` nếu có **đúng một**.
- Không đọc được → `null`.

### 2.5 Danh mục

- Tên danh mục nêu trong câu (`tenNeuTrongCau(cau, tên, tuLoai: 'danh mục')` trên tập hợp lệ) → danh mục ấy,
  `lyDoDanhMuc = null`, `doan = null`.
- Không nêu → `mo?.doan(ghiChu, hopLe: …, tatCap: tatCap)` của B1 trên **ghi chú đã rút** (§2.7). Có kết quả thì kèm
  `doan` và `cauLyDoHoc`.
- Tập hợp lệ (banner mục 2): `loai` đọc được ở 2.2 thì `hopLeTheoChieu(loai, chonDuoc)` của C1; không đọc được thì **mọi**
  danh mục chọn được (không nhóm, chưa xoá) — cùng nếp thẻ gợi ý của màn, danh mục kéo đoạn Chi/Thu theo.

### 2.6 Bộ đọc số bằng chữ — dời ra `core/utils/so_bang_chu.dart`

Hai bộ đọc riêng tư đang sống: `ai_edge/domain/kiem_so.dart` (chữ có dấu, kiểm câu trả lời) và
`ai_edge/domain/chinh_tham_so.dart` (chữ bỏ dấu, ngưỡng tiền câu hỏi). Cả hai **không** đọc hàng chục (banner mục 1).
Thay bằng **một** `List<({int batDau, int ketThuc, double giaTri})> timSoBangChu(String cau)` ở
`core/utils/so_bang_chu.dart`: đọc trên chữ đã bỏ dấu (nhận cả hai kiểu gõ), vị trí trả về theo câu gốc (câu NFC — bỏ dấu
giữ độ dài), `giaTri` là `NaN` cho lượng từ mơ hồ (*vài, mấy, dăm*). Hàng chục: *mười* (10) · *X mươi* (X·10) · sau
*mươi*: *mốt* (1), *tư* (4), *lăm / nhăm* (5) · *linh / lẻ* (0 chục) — *"hai mươi lăm nghìn"* = 25.000, *"một trăm linh
năm nghìn"* = 105.000. Từ số vẫn phải có **đơn vị** ngay sau cụm (*"năm nay"*, *"một khoản"* không phải số).
`kiem_so.dart` và `chinh_tham_so.dart` gọi lại; mọi test cũ của hai tệp xanh **không sửa kỳ vọng** (gồm các ca bẫy
4.42: *"một triệu"*, lượng từ mơ hồ, *"500 nghìn"* giữ cách đọc cũ — chữ số kèm đơn vị chữ không thuộc bộ đọc này).

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
