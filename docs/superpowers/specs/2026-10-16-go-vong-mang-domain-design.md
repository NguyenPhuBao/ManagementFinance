# Gỡ vòng phụ thuộc cụm {analytics, bill, category, transaction} ở tầng domain

- **Ngày:** 2026-10-16 (khuya) · nhánh `TranQuangDat` · HEAD lúc đo `d9b69d24`
- **Trạng thái:** người dùng duyệt thiết kế trong phiên; spec này chờ duyệt bản viết.
- **Phạm vi:** chỉ `src/Client-app` và tài liệu client. Không đổi hành vi, giao diện, dữ liệu, đồng bộ hay schema.

## 1. Bối cảnh

Quét 29 (`test/core/ui/domain_khong_vong_mang_test.dart`, 2026-10-16) dựng đồ thị cấp mảng từ chỉ thị `import` / `export` /
`part` của các tệp dưới `lib/features/*/domain/`. Cạnh `A->B` nằm trên vòng khi A và B cùng một thành phần liên thông mạnh.
Mọi cạnh trên vòng phải nằm trong danh sách chờ `conCho`, và danh sách ấy chỉ được giảm. Hiện nó giữ **mười cạnh** của
cụm {analytics, bill, category, transaction}: bốn cặp hai chiều và hai cạnh một chiều. Nợ có tên tương ứng ở KIEN_TRUC
mục 9 là *"bốn cặp hai chiều"*.

Mục tiêu đợt này: **rút hết mười cạnh, để `conCho` rỗng**. Cách làm là dời luật thuần về mảng của dữ liệu nó đọc (khuôn
`bill/domain/bill_nhac_truoc.dart`), dời nguyên văn, không viết lại logic.

## 2. Quyết định đã chốt (người dùng, 2026-10-16)

1. **Chiều phụ thuộc chuẩn:** `analytics → bill → transaction → category`. Cụ thể:
   - analytics được đọc ba mảng kia;
   - bill được đọc transaction và category;
   - transaction được đọc category;
   - category không đọc mảng nào trong cụm.

   Mảng ngoài cụm (goal, wallet) giữ nguyên quan hệ.
2. **Phạm vi:** cả ba lát trong một đợt; mỗi lát một commit.
3. **Lát 3 theo hình dạng "tách theo dữ liệu hàm đọc"**, không dời nguyên bốn tệp. Lý do đo được:
   `category/data/models/category_suggestion.dart` và `category/data/goi_y_phan_hoi_store.dart` đọc các hằng
   `kNguonGoiY*` / `kKetQuaGoiY*` của `phan_loai_ghi_chu.dart`. Dời nguyên tệp sang transaction sẽ sinh vòng ẩn
   `transaction/domain → category/data/models → transaction/domain`, mà quét 29 không thấy vì nó chỉ đọc nguồn `domain/`.

Không thêm luật quét mới. Với các cạnh xuôi chiều đang có (`analytics→{bill,category,transaction}`, `bill→transaction`,
`transaction→category`), bất kỳ cạnh ngược chiều nào thêm sau này đều khép một vòng, nên luật hiện có của quét 29 đỏ.

## 3. Bản đồ mười cạnh (đo trên `d9b69d24`)

| Cạnh | Chỉ thị gây ra |
|---|---|
| `analytics->bill` | `analytics/domain/du_bao_dong_tien.dart` → `bill_entity`, `bill_ky_ke_tiep`, `bill_pay_status` |
| `analytics->category` | `phan_loai_dong_tien.dart`, `vai_vay_no.dart` → `category/domain/category_classify.dart` |
| `analytics->transaction` | `analytics/domain/khoan_vao_thong_ke.dart` → `transaction/domain/transaction_owner.dart` |
| `bill->transaction` | `bill/domain/de_xuat_hoa_don.dart`, `dien_san_hoa_don.dart` → `transaction/domain/khoan_lap.dart`; `de_xuat_hoa_don` → `TransactionEntity` |
| `category->analytics` | `category/domain/phan_loai_ghi_chu.dart` → `analytics/domain/khoan_vao_thong_ke.dart` |
| `category->bill` | `phan_loai_ghi_chu.dart` → `bill/domain/bill_note.dart` (chỉ để lấy `kGhiChuTraHoaDon`) |
| `category->transaction` | `phan_loai_ghi_chu.dart` → `transaction_owner.dart` (cho `laGhiChuMay`); `phan_loai_so_tien.dart` → `transaction/domain/khoang_tien.dart` (chỉ `kDungSaiTien`); `gan_hang_loat.dart` → `TransactionEntity` |
| `transaction->analytics` | `transaction_filter.dart`, `tim_giao_dich.dart`, `khoan_lap.dart` → `khoan_vao_thong_ke.dart`; `tim_giao_dich.dart` → `analytics/data/models/lua_chon_loc.dart` |
| `transaction->bill` | `transaction_owner.dart` → `bill_note.dart` (`kGhiChuTraHoaDon`); `khoan_lap.dart` → `bill/domain/bill_recurrence.dart` (`kBillCycle*`) |
| `transaction->category` | `transaction_lookup.dart`, `doc_cau_giao_dich.dart`, `dien_san_bien_dong.dart` → `CategoryEntity`, B1, bộ gợi ý |

Kiểm trước: `goal/domain` và `wallet/domain` không import mảng nào trong cụm. Vì thế việc `khoan_vao_thong_ke` kéo theo
`→ goal` và `→ wallet` khi về transaction không mở vòng mới.

## 4. Thiết kế từng lát

Luật chung cho cả ba lát:

- Dời bằng `git mv` khi dời nguyên tệp, để giữ lịch sử.
- **Không `export` lại** từ chỗ cũ — theo nếp của repo (`lua_chon_loc.dart`: *"Không `export` lại"*); mọi nơi dùng sửa import.
- Nội dung dời **nguyên văn**, kể cả chú thích. Chỉ sửa câu chú thích nào nêu vị trí cũ hoặc lý do đặt tệp ở mảng cũ.

### Lát 1 — analytics ra khỏi vòng (rút 5 cạnh)

**Dời:**

1. `lib/features/analytics/domain/khoan_vao_thong_ke.dart` → `lib/features/transaction/domain/khoan_vao_thong_ke.dart`.
   - Trong tệp: `'../../transaction/domain/transaction_owner.dart'` → `'transaction_owner.dart'`. Các import goal / wallet
     cùng độ sâu nên giữ nguyên.
   - Nơi import (lib):
     - sáu tệp cùng thư mục cũ: `bao_cao_xuat`, `chi_bat_thuong`, `phan_loai_dong_tien`, `thong_ke_thang`,
       `uoc_tinh_chi_tuy_y`, `vai_vay_no` — đổi từ `'khoan_vao_thong_ke.dart'`;
     - `analytics/data/repositories/analytics_repository_impl.dart`;
     - `notification/domain/notification_rules.dart`;
     - `category/domain/phan_loai_ghi_chu.dart`;
     - `transaction/domain/transaction_filter.dart`, `tim_giao_dich.dart`, `khoan_lap.dart` — đổi thành `'khoan_vao_thong_ke.dart'`.
   - Test: `test/features/analytics/khoan_vao_thong_ke_test.dart` → `test/features/transaction/domain/khoan_vao_thong_ke_test.dart`.
2. `lib/features/analytics/data/models/lua_chon_loc.dart` → `lib/features/transaction/data/models/lua_chon_loc.dart`.
   - Nơi import (lib): `analytics/presentation/pages/export_report_page.dart`,
     `analytics/data/repositories/bao_cao_repository.dart`, `bao_cao_repository_impl.dart`,
     `transaction/domain/tim_giao_dich.dart`.
   - Test: `analytics/export_report_page_test.dart`, `transaction/domain/tim_giao_dich_test.dart`,
     `ai_edge/data/cong_cu_truy_van_test.dart`.
   - Câu đầu tệp ghi thêm lần dời này (2026-10-16, quét 29).

**Sau lát:** analytics vẫn đọc ba mảng kia, nhưng không mảng nào trong cụm đọc ngược lại nó, nên analytics rời thành phần
liên thông mạnh. Năm cạnh phải rút: `analytics->bill`, `analytics->category`, `analytics->transaction`,
`category->analytics`, `transaction->analytics`. Còn lại năm: `bill->transaction`, `category->bill`,
`category->transaction`, `transaction->bill`, `transaction->category`.

### Lát 2 — bill ↔ transaction (rút 3 cạnh)

1. **Hằng `kGhiChuTraHoaDon`** (cùng chú thích của nó) dời từ `bill/domain/bill_note.dart` sang
   `transaction/domain/transaction_owner.dart`, đặt cạnh `kGhiChuNapMucTieuCu`.
   - `bill_note.dart` giữ hàm `ghiChuTraHoaDon()` và import hằng từ `../../transaction/domain/transaction_owner.dart`.
     Đây là cạnh `bill→transaction`, xuôi chiều.
   - `transaction_owner.dart` bỏ import `bill_note`.
   - Nơi dùng hằng phải import `transaction_owner.dart`: `category/domain/phan_loai_ghi_chu.dart` (bỏ import `bill_note`),
     `analytics/data/repositories/analytics_repository_impl.dart`, và các test đang lấy hằng qua `bill_note` (bốn tệp
     `test/features/category/domain/*`, `bill/data/repositories/bill_repository_impl_test.dart` — xét từng tệp xem dùng hằng
     hay hàm).
   - Chú thích nêu `kGhiChuTraHoaDon` (`core/database/tables/transactions_table.dart`, `bill_repository.dart`) chỉ nêu tên,
     không nêu đường dẫn, nên không phải sửa. Không chạy `build_runner`.
   - So với hằng tiền tố mục tiêu: goal giữ hằng của nó (`goal_history_direction.dart`) và transaction đọc goal được, vì
     goal không đọc sổ giao dịch. Bill **có** đọc sổ (B2), nên bill không thể làm "mảng cấp hằng" một chiều như goal. Lý
     do này ghi vào chú thích tại chỗ.
2. `lib/features/transaction/domain/khoan_lap.dart` → `lib/features/bill/domain/khoan_lap.dart`. Đầu tệp đã tự nhận là
   *"Khoản chi lặp (B2) … để gợi ý biến nó thành hoá đơn"*, và trường ra (`chuKy` = `kBillCycle*`, `ngayGoc` = `anchorDay`)
   là khái niệm của hoá đơn.
   - Trong tệp:
     - `'../../bill/domain/bill_recurrence.dart'` → `'bill_recurrence.dart'`;
     - `'../data/models/transaction_entity.dart'` → `'../../transaction/data/models/transaction_entity.dart'`;
     - `khoan_vao_thong_ke` (đã ở transaction sau lát 1) → `'../../transaction/domain/khoan_vao_thong_ke.dart'`.
   - Nơi import (lib):
     - `bill/domain/de_xuat_hoa_don.dart` và `dien_san_hoa_don.dart` — đổi thành `'khoan_lap.dart'`;
     - `bill/data/de_xuat_hoa_don_nguon.dart`;
     - `bill/presentation/widgets/the_khoan_lap.dart`;
     - `analytics/data/repositories/analytics_repository_impl.dart` (`show khoaNhomCua`).
   - Test: `test/features/transaction/domain/khoan_lap_test.dart` → `test/features/bill/domain/khoan_lap_test.dart`. Bốn
     test khác đổi import: `bill/presentation/the_khoan_lap_test.dart`,
     `bill/presentation/pages/bill_page_khoan_lap_test.dart`, `bill/domain/dien_san_hoa_don_test.dart`,
     `bill/domain/de_xuat_hoa_don_test.dart`.

**Sau lát:** transaction không còn đọc bill; category không còn đọc bill (hằng nay đến từ transaction). Bill vẫn đọc
transaction, nhưng không còn đường ngược về, nên bill rời thành phần liên thông mạnh. Ba cạnh phải rút:
`bill->transaction`, `category->bill`, `transaction->bill`. Còn lại hai: `category->transaction`, `transaction->category`.

### Lát 3 — category ↔ transaction (rút 2 cạnh cuối)

Chỉ những hàm đọc sổ giao dịch mới sang transaction. Mô hình học và các hằng nguồn ở lại category.

1. **`kDungSaiTien`** (cùng chú thích) dời từ `transaction/domain/khoang_tien.dart` sang tệp mới
   `lib/core/utils/dung_sai_tien.dart`.
   - Vì sao `core/utils`: đây là ngưỡng nửa đồng của tiền dạng `double` — thuộc hạ tầng tiền, không của mảng nào.
     `core/utils` là chủ đề có sẵn, nên không thêm chủ đề `core` mới; tệp không import `features/`.
   - Nơi dùng sửa import: `khoang_tien.dart`, `tach_giao_dich.dart`, `tim_giao_dich.dart`,
     `transaction/presentation/widgets/sheet_them_phan.dart`, `category/domain/phan_loai_so_tien.dart`, cùng test nào dùng
     hằng này.
2. **`laGhiChuMay`** dời từ `category/domain/phan_loai_ghi_chu.dart` sang `transaction/domain/khoan_vao_thong_ke.dart`,
   đặt ngay sau `khoanVaoThongKe`. Hai hàm cùng trả lời câu *"hàng sổ này là loại gì"*.
   - Các hằng nó cần đã có sẵn trong tệp đích: tiền tố mục tiêu (goal), `kGhiChuTraHoaDon` và `kGhiChuNapMucTieuCu`
     (`transaction_owner`).
3. **`mauHocTu`** (từ `phan_loai_ghi_chu.dart`) và **`mauSoTienTu`** (từ `phan_loai_so_tien.dart`) dời sang tệp mới
   `lib/features/transaction/domain/mau_hoc_danh_muc.dart`.
   - Hai hàm biến hàng sổ thành mẫu học cho hai bộ phân loại danh mục.
   - Tệp mới import category: `MauGhiChu`, `amTietCua` từ `phan_loai_ghi_chu`; `MauSoTien`, `bacTienCua`, `maBacCua`,
     `nhomThuCua` từ `phan_loai_so_tien`. Nó import `laGhiChuMay` từ `khoan_vao_thong_ke`.
4. **`gan_hang_loat.dart`** `git mv` sang `lib/features/transaction/domain/gan_hang_loat.dart`.
   - Đi theo tệp: `xetGan`, `demChuaGan`, `DongGanDanhMuc`, `dungDanhSachGan`, `phanHoiGan`, `cauKetQuaGan`.
   - Riêng **`hopLeTheoChieu`** (chỉ đọc `CategoryEntity`) dời sang `category/domain/category_classify.dart`. Tệp ấy thêm
     import `../data/models/category_entity.dart`, được phép theo quét 28.
5. **Ở lại category:** `BoPhanLoaiGhiChu`, `DoanDanhMuc`, `MauGhiChu`, `amTietCua`, `tuGocCua`, `cauLyDoHoc`, `tatCapTu`,
   các hằng `kNguonGoiY*` / `kNguonDeXuatTuKhoa` / `kKetQuaGoiY*` / ngưỡng; mô hình bậc tiền (`BoPhanLoaiSoTien`,
   `bacTienCua`, `MauSoTien`…); `de_xuat_tu_khoa.dart` (không đổi).
   - `phan_loai_ghi_chu.dart` bỏ bốn import goal, transaction, analytics, bill.
   - `phan_loai_so_tien.dart` bỏ import `khoang_tien`, thay bằng `core/utils/dung_sai_tien.dart`.
6. **Nơi dùng đổi import** (lib) — ký hiệu nào dời thì import theo chỗ mới:
   - `transaction/data/them_giao_dich_nguon.dart` (`mauHocTu`, `mauSoTienTu`);
   - `transaction/presentation/bloc/them_giao_dich_cubit.dart` (`hopLeTheoChieu`);
   - `transaction/presentation/pages/transaction_page.dart`, `quet_anh_page.dart`;
   - `transaction/domain/doc_cau_giao_dich.dart`, `dien_san_bien_dong.dart`;
   - `category/data/gan_danh_muc_nguon.dart`;
   - `category/presentation/pages/gan_danh_muc_page.dart`.

   Ba nơi `category/data` và `category/presentation` đọc `transaction/domain` sau lát này nằm ngoài phạm vi quét 29
   (nguồn chỉ `domain/`). Chúng là bộ ghép của màn Gắn danh mục, không phải luật thuần.
7. **Test** — tách theo hàm, giữ nguyên nội dung từng ca:
   - nhóm `'laGhiChuMay / mauHocTu'` của `phan_loai_ghi_chu_test.dart` và nhóm `'mauSoTienTu'` của
     `phan_loai_so_tien_test.dart` → `test/features/transaction/domain/mau_hoc_danh_muc_test.dart`. Hàm dựng dữ liệu riêng
     của tệp gốc thì chép theo.
   - `gan_hang_loat_test.dart` `git mv` sang `test/features/transaction/domain/`; nhóm `'hopLeTheoChieu'` →
     `test/features/category/domain/category_classify_test.dart`.
   - Các test khác chỉ sửa import (danh sách ở mục 5).

**Sau lát:** `category/domain` không còn chỉ thị nào trỏ vào analytics, bill hay transaction. **`conCho` rỗng.**

## 5. Test và phép kiểm

- **Bất biến số ca:** dời và tách test không thêm, không bớt ca. Sau mỗi lát: `flutter test` = **7.146 pass / 10 skip /
  0 fail** (mốc 2026-10-16 khuya), `flutter analyze` = **20** (mức nền, `MUC_NEN` không đổi). Lệch một ca là sót hoặc
  trùng.
- **Bằng chứng mỗi lát (thứ tự bắt buộc):**
  1. Dời và sửa import xong, **chưa** sửa `conCho`.
  2. Chạy quét 29: phải đỏ **đúng** các dòng *"… đã gỡ — rút khỏi conCho"* của lát (5 · 3 · 2), không dòng
     *"nằm trên một vòng"* nào. Đây là bằng chứng cạnh đã mất thật.
  3. Rút các cạnh ấy khỏi `conCho` trong cùng commit, chạy lại cho xanh.
- **Quét 29 cuối đợt:**
  - `conCho = <String>{}`, chú thích ghi *"rỗng từ 2026-10-16"*; giữ hằng làm khuôn danh sách chờ (thêm vào phải có lý do
    và ngày).
  - Docstring đổi câu *"mười cạnh"* thành lịch sử gỡ ba lát.
  - Ca tiền đề giữ ngưỡng; sửa con số trong `reason` (*"đo …: 179 tệp / 32 cạnh"*) theo số đo mới, kèm ngày.
- **Các quét khác phải xanh:**
  - quét 25 (vị trí tệp, test soi gương, `core` không import `features`);
  - quét 27 (domain không kiểu Drift);
  - quét 28 (domain không import tầng trên — `category_classify` → `data/models` của chính mảng là hợp lệ);
  - quét 14 (`ai_edge` không tự tính).
- **Không cần máy ảo**: không có thay đổi giao diện hay hành vi. Ba loại lỗi `flutter test` mù — tràn bố cục, điều hướng
  shell, thứ tự hai luồng — không bị chạm.

## 6. Tài liệu

Tài liệu **sống** sửa theo vị trí mới:

- `CLAUDE.md`:
  - hàng *Đụng vào danh mục* — `xetGan` / `hopLeTheoChieu` / `laGhiChuMay`;
  - hàng hoá đơn — `khoaNhomCua (transaction/domain/khoan_lap.dart)`;
  - hàng presentation — chỉ khi có nhắc;
  - hàng 29 bảng quét — `conCho` rỗng.
- `docs/KIEN_TRUC_CLIENT_APP.md`: mục 9 (nhược điểm và nợ có tên: *"bốn cặp hai chiều"* đóng) và hàng 29 bảng quét.
- `docs/PROJECT_CONTEXT.md`: khối mới ở mục 14.
- `docs/CATEGORY_RATIONALE.md`, `docs/bill/BILL_DOCUMENTATION.md`, `docs/ANALYTICS_FEATURE.md`,
  `docs/AI_EDGE_FEATURE.md`, `docs/BIEN_DONG_SO_DU_FEATURE.md`, `docs/CLIENT_APP_KNOWN_GAPS.md`.
- Chú thích trong `lib/` và `test/` nêu đường dẫn cũ.

Cách soát: grep **đường dẫn cũ** và **tên ký hiệu đã dời** (`analytics/domain/khoan_vao_thong_ke`,
`analytics/data/models/lua_chon_loc`, `transaction/domain/khoan_lap`, `category/domain/gan_hang_loat`, `bill_note` +
`kGhiChuTraHoaDon`, `laGhiChuMay`, `mauHocTu`, `mauSoTienTu`, `hopLeTheoChieu`, `kDungSaiTien`) trên toàn tài liệu sống.
Sửa mọi con số liên quan ở **mọi** chỗ trong cùng tệp; KIEN_TRUC có nhiều chỗ đếm.

**Giữ nguyên (ảnh chụp lịch sử):** spec và kế hoạch cũ trong `docs/superpowers/specs/`, `DA-XONG/`, các báo cáo đánh giá
cũ trong `docs/superpowers/backend/`. Các đơn CAN-LAM đang mở không nhắc đường dẫn nào trong số này (đo 2026-10-16).

## 7. Ngoài phạm vi

- Không gỡ cạnh xuôi chiều nào; không thêm luật "thứ bậc mảng" mới.
- Không đụng cạnh từ `application/` / `data/` / `presentation/` (quét 29 cố ý chỉ đọc `domain/`).
- Không đổi tên ký hiệu nào; không sửa logic; không đổi các test quét "chỉ một nơi import X" (16, 17, 18, 20, 26).
- Không push (người dùng chưa bảo).

## 8. Rủi ro

| Rủi ro | Chặn bằng |
|---|---|
| Sót một nơi import (chỉ thị xuống dòng, import có điều kiện) | `flutter analyze` + biên dịch test; quét 25/27/28 đọc chỉ thị qua `chi_thi_dart.dart` |
| Tách test làm rơi hoặc nhân đôi ca | bất biến 7.146 / 10 skip sau mỗi lát |
| Rút `conCho` mà cạnh chưa mất thật | bước 2 mục 5 — phải thấy dòng đỏ *"đã gỡ — rút"* trước khi sửa danh sách |
| Vòng ẩn qua `data/models` (lý do bỏ phương án dời nguyên tệp) | hằng nguồn ở lại category; kiểm bằng grep import `transaction/` trong `lib/features/category/data/models/` (kỳ vọng 0) |
| Tài liệu nói vị trí cũ | soát grep mục 6 |
