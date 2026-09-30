# Đề xuất thêm từ khoá từ thói quen — thiết kế

**Ngày:** 2026-09-30. **Người dùng duyệt** bản thiết kế trong chat cùng ngày bằng câu hỏi chọn (bốn câu: nơi hiện, ngưỡng,
xung đột, bỏ qua) rồi duyệt toàn bản. Việc riêng **ngay sau C2, trước D1** (người dùng chốt 2026-09-30 sau lượt đo C2).
Bất biến ④ nhóm C: **chỉ đề xuất, bấm mới ghi**. Tầng hậu quả 2 (sửa dữ liệu cấu hình, đảo được trong trang Từ khoá).
**Không đổi schema. Không thêm trường đồng bộ** — từ khoá vốn đi trong payload danh mục.

## 1. Vì sao

Bộ từ khoá của danh mục **không học** — từ khoá phải có người gõ vào trang *Từ khoá của tôi*, và trên dữ liệu thật hầu như
không ai gõ (B1 ra đời vì thế, mục 5d `CATEGORY_RATIONALE.md`). Nhưng từ khoá lại là lớp **rẻ nhất, tất định nhất** trong
thứ tự đoán danh mục của Nhập nhanh (*tên → B1 → từ khoá → AI*): nó không cần 10 mẫu như B1, không cần ~18 s như AI, và
người dùng đọc hiểu được vì sao (*"Khớp với ‘xăng’ trong ghi chú"*). Người dùng đề xuất: *"khi người dùng không nhập từ
khoá vào danh mục nhưng họ thường lặp đi lặp lại từ khoá đó với 1 danh mục cụ thể thì sẽ đề xuất thêm từ khoá vào danh mục
đó"*. Và một lỗi cụ thể cần lối sửa trên máy: từ khoá **mặc định** `grab` nằm ở Ăn uống (seed backend, đơn
`CAN-LAM/SEED_TU_KHOA_GRAB.md` chỉ sửa cho tài khoản **mới**) trong khi người dùng ghi *grab* cho Di chuyển — đo C2 lượt 3:
*"grab 35k"* → Ăn uống qua từ khoá.

## 2. Hành vi

### 2.1 Khi nào hiện

Ở màn Thêm giao dịch, **đường tạo mới và sửa**, mỗi khi form **có danh mục** (người dùng chọn tay, thẻ gợi ý, B1, từ khoá,
AI, Nhập nhanh — không phân biệt nguồn) **và** ghi chú có một **cụm** thoả cả bốn điều kiện — hiện **một** dòng ngay dưới
hàng Danh mục:

> ➕ Thêm **‘trà sữa’** làm từ khoá của **Ăn uống**? **[Thêm] [✕]**

1. **Thói quen** (cùng ngưỡng B1, người dùng chốt): cụm đi với danh mục ấy **≥ 3 lần** và chiếm **≥ 60 %** số lần cụm ấy
   xuất hiện trong mẫu học — **tính cả lần đang nhập** (giao dịch đang gõ cộng vào mẫu; đường sửa thì thay mẫu cũ của chính
   giao dịch ấy). Mẫu học = `mauHocTu` của B1: giao dịch có danh mục, ghi chú người dùng gõ (không phải ghi chú máy sinh).
2. **Chưa là từ khoá của danh mục ấy** (so `_normalizeKeyword` của DAO: chữ thường, gom khoảng trắng, **giữ dấu** — và so
   thêm bản bỏ dấu, vì bộ so từ khoá có bước bỏ dấu).
3. Cặp (cụm, danh mục) **không đang bị tắt** (§2.4).
4. Cụm **đáng làm từ khoá** (§2.2).

Chỉ **một** đề xuất mỗi lượt — cụm dài nhất thoả; hoà thì cụm đứng trước trong ghi chú. Dòng **biến mất** khi ghi chú hoặc
danh mục đổi làm điều kiện không còn thoả; hiện lại khi thoả lại. Không hiện ở đoạn Chuyển khoản (không có danh mục).

**Xung đột** (người dùng chốt: *đề xuất CHUYỂN*): cụm đang là từ khoá của **một** danh mục khác `K` →

> ↪ **‘grab’** đang là từ khoá của **Ăn uống** — chuyển sang **Di chuyển**? **[Chuyển] [✕]**

Cụm là từ khoá của **hai** danh mục khác trở lên → không đề xuất (§4).

### 2.2 Cụm nào

Đếm như B1 — trên **âm tiết bỏ dấu** (`amTietCua`), cụm là dãy âm tiết **liền nhau** trong ghi chú hiện tại; với mỗi dãy,
`N(cụm, c)` = số mẫu của danh mục `c` chứa dãy ấy liền nhau, `N(cụm)` = số mẫu chứa dãy ấy. Chọn dãy **dài nhất** thoả
ngưỡng §2.1. Nhưng **từ khoá lưu là chữ người dùng gõ, có dấu**, lấy đúng đoạn tương ứng trong ghi chú hiện tại (*"trà sữa"*,
không *"tra sua"*) — trang Từ khoá đang lưu từ khoá có dấu và bộ so ưu tiên khớp có dấu.

**Chặn cụm không đáng làm từ khoá** (tôi đặt, người dùng duyệt): bộ so từ khoá `CategorySuggestionEngine` khớp theo
**chuỗi con** (*"ăn"* khớp cả *"căn hộ"*, *"đi"* khớp *"điện"*), nên từ khoá ngắn hoặc chung là bẫy cho chính người dùng:
- Cụm **dưới 3 chữ cái** (bỏ dấu, không tính khoảng trắng) → không đề xuất.
- Cụm chỉ gồm **chữ chung** → không đề xuất: *ăn, uống, mua, bán, trả, đóng, nạp, tiền, đi, cho, với, và, của, hết, mất,
  tốn, cái, con, chiếc, lần, hôm, nay, qua, này, nữa, thêm, rồi, đã, đang, sẽ, là, có, không, được, bị, về, ra, vào, lên,
  xuống, ở, tại, từ, đến, sang* (danh sách `kChuChung`, một chuỗi tách lúc chạy — cùng nếp `kTuChucNang` của Trợ lý AI;
  đây là danh sách khởi điểm, sửa theo số đo). Cụm có ít nhất một chữ **không** chung thì được (*"ăn phở"* được vì *phở*).
- Cụm là **số** (*"500k"*, *"2tr"*) → không (số không phải từ khoá; `amTietCua` đã bỏ chữ toàn số, còn *"500k"* thì chặn ở đây).

### 2.3 Bấm Thêm / Chuyển

**Ghi ngay** (tôi đặt, người dùng duyệt — không chờ ✓ lưu giao dịch): dòng đổi thành *"✓ Đã thêm ‘trà sữa’ vào Ăn uống"*
(hoặc *"✓ Đã chuyển ‘grab’ sang Di chuyển"*), không nút, **tự ẩn sau 2 giây** (người dùng chốt 2026-09-30 khi duyệt
màn Stitch `8ca1338e16704004b6c4ae4313e465c6` — bản đầu spec ghi *"mờ đi"*, giữ tại chỗ). Sau khi thêm, cụm đã là từ khoá
nên dòng không hiện lại. **Thêm** = `saveKeywords(categoryId, [...cũ, mới])`.
**Chuyển** = `saveKeywords(K, cũ − cụm)` rồi `saveKeywords(c, [...cũ, cụm])` — hai lời gọi, **bỏ ở danh mục cũ trước**
để không có khoảnh khắc cụm thuộc hai danh mục (bộ so coi hai danh mục khớp ngang nhau là **hoà** → thôi đoán).
Không toast: dòng tại chỗ đã là xác nhận (memory `thong-bao-toi-gian`).

Ghi **phản hồi** `chon` vào bảng cục bộ `GoiYDanhMucPhanHois` (schema v25, không đổi): `nguon = 'de_xuat_tu_khoa'` (hằng
mới `kNguonDeXuatTuKhoa`, cạnh `hoc` / `tu_khoa`), `amTietChinh` = cụm bỏ dấu, `goiYCategoryId = c`, `chonCategoryId = c`.

### 2.4 Bấm ✕ và lưu luôn

**✕** → ghi phản hồi `bo_qua`, dòng ẩn cho lượt này. **Lưu giao dịch mà không bấm gì** → **không** ghi gì (khác thẻ gợi ý
danh mục — ở đây lưu luôn là chuyện thường, không phải câu trả lời). Luật tắt / mở **đúng luật B1** (người dùng chốt), áp
trên phản hồi nguồn `de_xuat_tu_khoa`: cặp (cụm, danh mục) có **≥ 2** lần `bo_qua` thì thôi đề xuất; mở lại khi có **≥ 3**
mẫu mới (ngày sau lần ✕ cuối) chứa cụm ấy cho danh mục ấy. Thi hành bằng chính `tatCapTu` — hàm ấy hôm nay lọc cứng
`p.nguon != kNguonGoiYHoc` (`phan_loai_ghi_chu.dart:264`); thêm tham số `nguon` (mặc định `kNguonGoiYHoc` để hai chỗ gọi cũ
không đổi), **không** chép luật ra chỗ thứ hai. Hai nguồn giữ **hai** tập tắt riêng: ✕ đề xuất từ khoá không tắt thẻ gợi
ý B1 của cùng cặp, và ngược lại.

### 2.5 Sau khi thêm

Lần nhập kế có cùng cụm: bước **từ khoá** trong thứ tự đoán danh mục bắt được ngay (thẻ gợi ý nguồn `tu_khoa`, ô Nhập
nhanh không phải gọi AI vì danh mục). Đó là mục tiêu của tính năng — đo ở §6.

## 3. Đồng bộ — sửa luôn một lỗ hổng sẵn có

Từ khoá lên server **trong payload danh mục** (`'keyword': list.join(',')`, `sync_engine.dart` ~1186; hợp đồng
`sync_payload_contract_test.dart` ~1159), không có thực thể riêng. Nhưng `CategoryManagementRepository.saveKeywords`
(~339) **không đánh dấu danh mục `pending` và không `scheduleSync()`** — chỉ `saveChild` làm thế. Hệ quả hôm nay: sửa từ khoá
ở trang *Từ khoá của tôi* **không lên server** cho tới khi danh mục bị sửa vì lý do khác; đổi máy là mất. Tính năng này
dựa hoàn toàn vào `saveKeywords`, nên **phải sửa**: `saveKeywords` đánh dấu danh mục `pending` (cập nhật `updatedAt`) và
`scheduleSync()`. Có ca test canh, và nghiệm thu đo tới PostgreSQL (`category."Keyword"`).

⚠️ **Giới hạn của đường đẩy, không sửa ở đây:** danh sách từ khoá **rỗng** thì client **không** gửi khoá `keyword` (gửi
chuỗi rỗng là xoá luôn từ khoá server tự học — chú thích ở `sync_engine.dart`), và nhánh kéo về `_gieoTuKhoaKhiTrong` **gieo
lại** từ khoá server khi danh mục trên máy **không còn từ khoá nào**. Nên **Chuyển** làm danh mục cũ **rỗng** thì từ khoá
cũ **quay lại sau lượt pull kế** — với `grab` không xảy ra (Ăn uống còn từ khoá khác), nhưng phải ghi ở §4 và trong dòng
xác nhận không hứa gì về máy khác.

## 4. Không làm / giới hạn nói trước

- Không đề xuất khi cụm đang là từ khoá của **≥ 2** danh mục khác (không biết bỏ ở đâu).
- Không đề xuất **bỏ** từ khoá (chỉ thêm / chuyển). Không đề xuất từ khoá cho danh mục **nhóm**.
- Không đề xuất ở màn Gắn danh mục hàng loạt (C1) — mỗi hàng một ghi chú, chỗ ấy chật; để sau nếu cần.
- Chuyển làm danh mục cũ rỗng → pull kế gieo lại (§3). Không sửa vì đụng luật đẩy/kéo của đồng bộ.
- Từ khoá vẫn được phép thuộc hai danh mục nếu người dùng tự thêm ở trang Từ khoá — tính năng này không siết.

## 5. Mã

- **Hàm thuần** `lib/features/category/domain/de_xuat_tu_khoa.dart`:
  `DeXuatTuKhoa? deXuatTuKhoa({required String ghiChu, required String categoryId, required List<MauGhiChu> mau,
  required Map<String, List<String>> tuKhoa, required Set<(String, String)> tatCap})` → `null` hoặc
  `({String tuKhoa, String cumBoDau, String categoryId, String? tuDanhMuc, int soLanCung, int soLanTong})`. `tuDanhMuc`
  khác `null` = đề xuất **chuyển**. Mẫu đang nhập do người gọi cộng vào `mau` (đường sửa: thay mẫu cùng giao dịch — cần
  `MauGhiChu` mang id giao dịch? **Không**: người gọi dựng lại `mau` từ sổ trừ giao dịch đang sửa rồi cộng bản mới).
  `kChuChung`, `kToiThieuChuCai = 3`; ngưỡng dùng lại `kToiThieuMauDanhMuc`, `kNguongXacSuat` của B1 — **một** định nghĩa
  thói quen.
- **Đếm**: quét `mau` (công khai của `BoPhanLoaiGhiChu`), không mở private `_nt` — `_nt` đếm âm tiết lẻ, đây cần dãy liền.
- **Màn** `add_transaction_page.dart`: widget `_DongDeXuatTuKhoa` dưới hàng Danh mục; tính lại khi ghi chú (sau nhịp hoãn
  300 ms sẵn có) hoặc danh mục đổi; gọi `CategoryManagementRepository.saveKeywords`; phản hồi qua `GoiYPhanHoiStore.ghi`
  (store nhận `CategorySuggestion` — dựng một `CategorySuggestion(nguon: kNguonDeXuatTuKhoa, amTietChinh: cụm)`; nếu gượng
  thì thêm `ghiTho` cho store, một chỗ). `_tatCap` cho đề xuất đọc riêng theo nguồn.
- **Repository**: `saveKeywords` thêm `pending` + `scheduleSync()` (§3).
- **Stitch**: dòng đề xuất + trạng thái "Đã thêm" + biến thể "chuyển" — **vẽ trước khi dựng** (memory `dua-man-moi-len-stitch`).
  Màn nền: `8afdfe113cc84874b2009aa80fe755fd` (Thêm giao dịch có Nhập nhanh). ✅ Màn **`8ca1338e16704004b6c4ae4313e465c6`**
  *"Thêm giao dịch - Đề xuất thêm từ khoá"* (dòng đề xuất · "Đã thêm" · biến thể "chuyển") — người dùng duyệt 2026-09-30.

## 6. Kiểm thử

- `de_xuat_tu_khoa_test`: đủ 3/60 % → đề xuất; 2 lần → không; 3 lần nhưng 50 % → không; cụm dài nhất thắng; từ khoá lưu
  **có dấu** đúng đoạn ghi chú; đã là từ khoá (có dấu / bỏ dấu) → không; **chuyển** khi thuộc một danh mục khác, không khi
  thuộc hai; chữ chung / dưới 3 chữ cái / số → không; `tatCap` chặn; tính cả mẫu đang nhập; mẫu máy sinh không đếm.
- `category_management_repository_test`: `saveKeywords` đánh dấu `pending` + gọi `scheduleSync` (bản sai: bỏ hai dòng → đỏ).
- Widget: dòng hiện / ẩn theo ghi chú + danh mục; Thêm ghi từ khoá và phản hồi `chon`, dòng thành "Đã thêm"; Chuyển gọi hai
  lần `saveKeywords` đúng thứ tự; ✕ ghi `bo_qua`; lưu luôn không ghi; không hiện ở Chuyển khoản; theme thật, 360 × 640.
- Sweep test 15 (cục bộ không đồng bộ) không đổi — không bảng mới.
- **Nghiệm thu Realme**: ghi 3 khoản *"trà sữa"* cho Ăn uống → lần thứ 3 dòng hiện → Thêm → khoản thứ 4 Nhập nhanh *"trà
  sữa 40k"* ra Ăn uống **không gọi AI**; ca *grab*: dòng "chuyển" → Chuyển → *"grab 35k"* ra Di chuyển; đồng bộ lên
  PostgreSQL: `category."Keyword"` của Ăn uống chứa *trà sữa*, Di chuyển chứa *grab*, Ăn uống hết *grab*. Dọn dữ liệu thử
  bằng xoá mềm qua giao diện (quy tắc 5).

## 7. Tài liệu đi kèm

`CATEGORY_RATIONALE.md` (tiểu mục mới trong 5d hoặc 5f), `PROJECT_CONTEXT.md` mục 14, `CLAUDE.md` hàng *Đụng vào danh mục*
(thứ tự đoán danh mục và việc kế), `AI_EDGE_FEATURE.md` 9.41 (một dòng: từ khoá học được → AI ít phải đoán), kế hoạch
`2026-09-21-ai-viec-tiep-theo.md` và bản đồ nhóm B–D.
