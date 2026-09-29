# C1 — Gắn danh mục hàng loạt cho giao dịch chưa phân loại — thiết kế

**Ngày:** 2026-09-28 (tối). **Người dùng duyệt** bản thiết kế trong chat cùng ngày, với các lựa chọn: lối vào là **thẻ trên
trang Sổ giao dịch** · **tick sẵn** dòng đoán được · chỉ xét **khoản chưa có danh mục** · **có** ghi phản hồi vào bảng B1.
Nhóm C đổi **bất biến ④** thành *"không tool nào ghi **thẳng**"*: AI điền sẵn, người dùng xác nhận mới ghi. Người dùng
duyệt đích danh cùng buổi; tầng hậu quả 4 và thao tác xoá vẫn cấm. Thứ tự nhóm C: **C1** → C2 → D1 → C3 → C4.
**Phụ thuộc B1** (mô hình học từ ghi chú, bảng phản hồi v25). **Không đổi schema.**

> **Soát với mã B1 đã thi công (2026-09-29, trước Task 1).** Ba chỗ đổi so với bản trên: (1) thẻ §3 đọc **stream**
> `transactionDao.watchAll` qua `demChuaGan`, không nạp một lần — nên nó tự đổi sau lần áp dụng, lần pull đồng bộ và lần
> thêm giao dịch; (2) route §4 là route **con** `gan-danh-muc` của `/transactions`, đặt lên navigator gốc
> (`parentNavigatorKey`), cùng khuôn `/analytics/export`; (3) ô danh mục §4 mở một **bảng chọn riêng** chỉ gồm danh mục
> hợp lệ theo chiều, vì trang *Chọn danh mục* có sẵn mở đủ ba tab và không lọc được theo chiều tiền.

## 1. Vì sao

Sổ có những giao dịch không danh mục: kéo về từ server (17 hàng trống danh mục đo 2026-09-10), hoặc người dùng lưu vội.
Khảo sát 2026-09-20 đếm được 15/39. Chúng vẫn vào thống kê (`khoanVaoThongKe` giữ khoản chưa phân loại), nhưng nằm ở
lát *"Chưa phân loại"*, nên donut, ngân sách theo danh mục và B3 đều mù với chúng. B1 đã có mô hình đoán danh mục từ
ghi chú. C1 cho mô hình ấy chạy trên các giao dịch **đã có**.

Đây là việc có hậu quả **thấp nhất** trong nhóm C (tầng 1): đổi danh mục không đổi số tiền, không đổi số dư, và sửa lại
được từng dòng.

## 2. Chọn giao dịch và dự đoán — `lib/features/category/domain/gan_hang_loat.dart`

`List<DongGanDanhMuc> dungDanhSachGan({required List<Transaction> giaoDich, required List<Category> danhMuc, required BoPhanLoaiGhiChu? mo, required Set<(String, String)> tatCap})`

- **Xét** giao dịch khi: chưa xoá (`!isDeleted && deletedAt == null`), `categoryId == null`, `type != 'transfer'`, **và**
  `!laGhiChuMay(ghiChu, loai, categoryId)`. Hàm `laGhiChuMay` là của B1, gom mọi nhận dạng khoản do máy sinh (điều chỉnh
  số dư, mở sổ, nạp/rút mục tiêu, trả hoá đơn); **không** viết luật thứ hai. Những khoản ấy cố ý không có danh mục.
- **Danh mục hợp lệ theo chiều tiền:** khoản `chi` → danh mục `classify ∈ {chi, vay_no}`; khoản `thu` →
  `{thu, vay_no}`. Chỉ danh mục **chưa xoá**, **chọn được**: cùng tập mà màn Thêm giao dịch cho chọn
  (`selectableChildrenAll`), để C1 không gắn vào một danh mục cha hay danh mục khuôn toàn cục. Thiếu bộ lọc chiều thì
  mô hình (học trên cả ba phân loại) có thể gắn *"Lương"* cho một khoản chi.
- **Dự đoán:** `mo?.doan(ghiChu, hopLe: …, tatCap: tatCap)`. `mo == null` (chưa đủ 10 mẫu, luật của B1) → mọi dòng
  không có dự đoán. Có dự đoán thì dòng mang `categoryId`, `xacSuat`, và câu lý do `cauLyDoHoc(...)` của B1.
- Kết quả xếp: dòng **có** dự đoán trước (xác suất giảm dần), rồi dòng không có (ngày mới nhất trước).
- `int demChuaGan(List<Transaction> giaoDich)` dùng **cùng** điều kiện *xét* ở trên. Thẻ ở Sổ giao dịch đọc nó, và hàm
  trả 0 thì thẻ ẩn. Một định nghĩa, nên thẻ không bao giờ hứa N dòng mà màn duyệt hiện số khác.

## 3. Lối vào — thẻ trên trang Sổ giao dịch

- Trên `TransactionPage`, **trên** danh sách, khi `demChuaGan > 0`: *"Có {N} giao dịch chưa có danh mục"* với nút **Gắn
  nhanh**. Đếm trên **toàn bộ** sổ của tài khoản, không theo kỳ đang xem: thẻ nói về việc dọn sổ, không nói về kỳ.
- Không có giao dịch nào như vậy → không dựng gì.
- ⚠️ Thêm một khối vào đầu trang là đổi ngữ cảnh của mọi ca test cuộn tới cuối trang ấy (bài học chặng 1.3, 1.5 và G48).
  Chạy lại toàn bộ test của trang và sửa bằng `ensureVisible`, không sửa kỳ vọng.

## 4. Màn duyệt — route `/transactions/gan-danh-muc`

- Route **ngoài** shell, **push** từ tab Giao dịch (push từ trong shell ra ngoài là an toàn; bẫy 7.8 là chiều ngược lại).
- Mỗi dòng: ngày (`dd/MM`) · ghi chú · số tiền (qua `CurrencyFormatter`, có dấu theo chiều) · ô danh mục (bấm mở bảng chọn
  danh mục có sẵn, lọc theo chiều như §2) · ô tick. Dòng có dự đoán thì **tick sẵn**, ô danh mục điền sẵn, và câu lý do
  dưới ghi chú. Dòng không có dự đoán thì trống và không tick; chọn danh mục thì tự tick.
- Thanh đáy: **Áp dụng {số dòng đang tick}**. Không dòng nào tick thì nút tắt.
- Áp dụng xong: `pop` về Sổ giao dịch, kèm toast *"Đã gắn danh mục cho {N} giao dịch"* (nếu dự án có toast chung thì dùng
  nó, tối giản theo nếp thông báo tạm thời).
- ⚠️ Giao diện mới (thẻ + màn) → **Stitch trước**.

## 5. Áp dụng và phản hồi

- Mỗi dòng đang tick: `TransactionRepository.updateTransaction(before, after)` với `after = before.copyWith(categoryId: …)`.
  Đường ấy lo đồng bộ (`syncStatus: 'pending'`, mốc `updatedAt` mới) và số dư (không đổi, vì chỉ danh mục đổi). Không ghi
  thẳng DAO.
- Phản hồi vào `GoiYDanhMucPhanHois` (B1, v25), `nguon = 'hoc'`, **chỉ** cho dòng **có** dự đoán và **đang tick**:
  danh mục cuối = dự đoán → `ketQua = 'chon'`; khác → `'khac'` kèm `chonCategoryId`. Dòng bỏ tick **không** ghi, vì bỏ
  tick là *"chưa muốn sửa dòng này"*, không phải *"dự đoán sai"*. Dòng không có dự đoán không ghi.
- Lỗi một dòng không chặn các dòng sau. Cuối lượt, toast nói số dòng thành công. Có dòng hỏng thì thêm *"… , {k} dòng
  chưa lưu được"*.

## 6. Giới hạn nói trước

- Chưa có B1 thì C1 **không** làm được: nó không có mô hình của riêng mình.
- Khoản chưa phân loại mà **không có ghi chú** thì không đoán được. Người dùng vẫn chọn tay được trên cùng màn.
- Mô hình học từ chính sổ của người dùng. Sổ ít mẫu (< 10 khoản có danh mục + ghi chú) → mọi dòng không có dự đoán, và
  màn thành một công cụ gắn tay hàng loạt. Như thế vẫn có ích, và là hành vi đúng.

## 7. Kiểm thử

- **`dungDanhSachGan` / `demChuaGan`:** loại khoản có danh mục, transfer, điều chỉnh số dư, mở sổ, nạp/rút mục tiêu, trả
  hoá đơn, đã xoá; khoản chi không bao giờ được đoán sang danh mục `thu` (dựng mô hình có mẫu *"grab" → Lương* áp đảo mà
  vẫn phải ra `null` hoặc danh mục chi); `mo == null` → mọi dòng không có dự đoán; thứ tự; hai hàm đếm cùng một tập.
- **Thẻ Sổ giao dịch:** N > 0 → thẻ với đúng N; N = 0 → không thẻ; mọi ca cũ của trang xanh (sau `ensureVisible`).
- **Màn duyệt:** dòng có dự đoán tick sẵn và có câu lý do; chọn danh mục cho dòng trống → tự tick; nút *Áp dụng* đếm
  đúng; bấm → `updateTransaction` gọi đúng số lần với đúng `categoryId`; phản hồi đúng `chon` / `khac`, không có hàng cho
  dòng bỏ tick; khổ 411 dp, ghi chú dài không tràn.
- **Máy ảo:** tài khoản thử có vài khoản *"grab"* đã gắn Di chuyển và vài khoản *"grab"* chưa gắn → thẻ hiện, màn tick sẵn,
  áp dụng, lát *"Chưa phân loại"* ở trang Phân tích giảm đúng.

## 8. Tài liệu đi kèm

`docs/CATEGORY_RATIONALE.md` hoặc tài liệu tính năng danh mục: mục *Gắn danh mục hàng loạt (C1)*. `AI_EDGE_FEATURE.md`:
nhóm C bắt đầu, bất biến ④ nay là *"không tool nào ghi thẳng"*, kèm ngày duyệt. `CLAUDE.md` hàng *Đụng vào danh mục*.
`PROJECT_CONTEXT.md` mục 14.
