# G88 gạch 4 (hạ tầng `core` thôi import mảng) + quét 28 (`domain` không import tầng trên) — thiết kế

> **Trạng thái:** thiết kế **người dùng duyệt từng phần 2026-10-15** (phần 1 gạch 4 · phần 2 quét 28 · phần 3 thứ tự + nghiệm
> thu). **Chưa có kế hoạch, chưa thi công** — người dùng chốt *"viết bàn giao cho phiên sau thực hiện"*; lối thi công (agent con
> mỗi task hay inline) **chưa chọn** — phiên sau hỏi. Không bật backend dev cho đợt này (người dùng chốt).
>
> Mọi số đo ở đây đo bằng máy ở HEAD `f06ad54e`/`fce511a1` (mã `lib/` không đổi **hành vi** từ `08effea7` — soát lại ở
> `a2892281`: ba tệp đổi sau mốc ấy, cả ba chỉ ở dòng chú thích, commit `7d55b900`), ngày 2026-10-15. Thi công thì **đo lại**,
> đừng chép.

**Người dùng thấy gì khác trên app:** không gì cả. Đợt này đổi chiều phụ thuộc giữa các thư mục, không đổi hành vi, không đổi
giao diện, không đổi lược đồ / payload đồng bộ. Sau đợt, **G88 đóng hẳn** (gạch 1, 2, 3, 5, 6 đã đóng trước đó).

---

## 1. Phạm vi

1. **G88 gạch 4** (`docs/CLIENT_APP_KNOWN_GAPS.md` G88 mục 4): 18 dòng `import` trong hạ tầng `lib/core` (ngoài bốn điểm ghép)
   trỏ vào `features/` → còn **8** dòng **hợp lệ theo luật mới** "core được đọc hằng số / hàm thuần của mảng" (quyết định người
   dùng 2026-10-11, ghi ở G88 mục 4 📝).
2. **Quét 28** — test quét mới: `features/*/domain/` không import `presentation/`, và trong `data/` chỉ được import
   `data/models/`. Năm tệp đang vi phạm được sửa trong đợt (người dùng chọn phạm vi *"cấm cả hai chiều"*).

**Ngoài phạm vi (giữ là nợ có tên):** vòng phụ thuộc chéo mảng `bill/domain/bill_status.dart` → `notification/domain/notification_rules.dart`
→ `bill/domain/*` (ghi ở `KIEN_TRUC_CLIENT_APP.md` mục 9); regex quét 27 còn hở (`is X ?`, `case X(`, `export drift`).

## 2. Hiện trạng đo được

### 2.1 Mười tám dòng gạch 4 (vòng `for` + `grep -cE "^(import|export) .*features/"` từng tệp)

| Tệp `lib/core/…` | Dòng | Import | Dùng để |
|---|---|---|---|
| `sync/sync_engine.dart` (2.166 dòng) | :8 | `bill/domain/bill_recurrence.dart` | hằng chu kỳ (`kBillCycleMonth`) khi kéo hoá đơn |
| | :13 | `wallet/domain/wallet_status.dart` | `WalletStatus.tuKhoa(...)` khi kéo ví |
| | :14 | `bill/domain/bill_pay_status.dart` | `kBillPayed` khi kéo hoá đơn |
| | :21 | `goal/domain/uu_tien_hop_le.dart` | `uuTienHopLe(...)` hai chiều |
| | :10 | `wallet/data/so_du_vi_service.dart` | `_soDuVi.datNeoNhieuVi` (:689), `tinhLaiNhieuVi` (:1150) |
| | :11 | `wallet/data/tha_vi_bi_giu.dart` | `ThaViBiGiu(db: _db).tha(id)` (:1227) |
| | :12 | `wallet/data/vi_trung_ten_nguon.dart` | `_viTrungTen.viCanTha` (:1226), `viDangBiGiu` + `ViTrungTenNguonImpl.banGhiBiGiuTuHang` (:1232) → `giu.vi/hoaDon/mucTieu/giaoDich` (:1299 :1341 :1397 :1455 :1521) |
| `sync/noi_bo_nghe_ket_qua_day.dart` (19 dòng) | :1–2 | `bill/application/bill_payment_conflict_resolver.dart`, `wallet/application/vi_trung_ten_resolver.dart` | chỉ nối hai bộ nghe vào `pushResultStream`; gọi từ `main.dart:64`, `core/nen/chay_nen.dart:37` |
| `sync/sync_payload_normalizer.dart` | :1–2 | `wallet/domain/wallet_status.dart`, `wallet_type.dart` | hằng loại / trạng thái ví |
| `database/daos/other_daos.dart` | :2 | `bill/domain/bill_pay_status.dart` | hằng trạng thái trả trong SQL |
| `database/daos/wallet_dao.dart` | :2 | `wallet/domain/wallet_status.dart` | hằng trạng thái ví trong SQL |
| `nen/lich_nen.dart` (92 dòng) | :5–8 | `bill/domain/bill_pay_status`, `goal/data/models/goal_entity`, `goal/domain/goal_auto_deposit`, `bill/data/models/bill_entity` | hàm thuần `lichNenKeTiep({bills, goals, now, gioNhac, phutNhac, traDuoc, trichDuoc})` tính mốc lượt nền tự chuyển tiền; lớp `LichNen` (hạ tầng) đã nhận hook `tinh` |
| `ocr/kho_anh_quet.dart` (107 dòng) | :17 | `transaction/domain/doc_mon_hang.dart` | `luuMon` / `docMon` lưu `List<MonHang>` cạnh ảnh quét |

`SyncEngine` **đã** nhận `SoDuViService? soDuVi`, `ViTrungTenNguon? viTrungTen` qua constructor (:259–262), nhưng tự dựng bản
thật khi `null` — chính vế mặc định ấy là lý do phải import. DI (`injection_container.dart` :166) không truyền hai tham số ấy.
Test dựng `SyncEngine(` **41** lần ở **26** tệp.

Năm tệp `domain` mà `core` đọc đều **thuần**: `wallet_status`, `wallet_type`, `bill_recurrence`, `uu_tien_hop_le` không import gì;
`bill_pay_status` chỉ import `../data/models/bill_entity.dart` (vị từ `conPhaiTra(BillEntity)`).

`KhoAnhQuet` chỉ được dùng ở `core/di`, `features/transaction/{data,presentation}` (và test của chúng) — không tệp `core` nào khác.

### 2.2 Năm tệp `domain` vi phạm quét 28

| Tệp | Import vi phạm | Thứ mượn |
|---|---|---|
| `ai_edge/domain/goi_so_trang_chu.dart` :10 | `home/presentation/widgets/home_budget_card.dart` `show pickHomeBudget` | hàm thuần `BudgetView? pickHomeBudget(List<BudgetView>, DateTime)` (khai ở `home_budget_card.dart:16`, Dart thuần, chỉ dùng `BudgetView` của `budget/data/models/budget_entity.dart`) |
| `ai_edge/domain/goi_so_ngan_sach.dart` :11 | như trên | như trên |
| `ai_edge/domain/goi_so_phan_tich.dart` :10 | `analytics/data/repositories/analytics_repository.dart` | `DongDanhMuc` (:17), `ThongKeKy` (:68), `DongChiBatThuong` (typedef :13) — khai **trong** tệp interface repository |
| `ai_edge/domain/hang_tong_quan.dart` :18 | như trên | như trên |
| `transaction/domain/tim_giao_dich.dart` :14 | `analytics/data/repositories/bao_cao_repository.dart` | `LuaChonLoc` (:8) |

Không tệp `domain` nào import Flutter (đo 2026-10-15) — không thêm luật cho chiều ấy. Chiều `domain → application/` đã có
quét 25 luật 7.

## 3. Thiết kế gạch 4

| Tệp | Cách xử lý | Dòng `features/` sau đợt |
|---|---|---|
| `sync_engine` :8 :13 :14 :21 · `sync_payload_normalizer` :1–2 · `other_daos` :2 · `wallet_dao` :2 | **Hợp thức hoá** — luật mới ở 3.6 | 8, hợp lệ |
| `sync_engine` :10–12 | Hai **cổng** khai ở `core/sync/` (3.1); `SyncEngine` nhận chúng **bắt buộc**; DI truyền bản thật của mảng ví | 0 |
| `noi_bo_nghe_ket_qua_day` | Gộp hàm `noiBoNgheKetQuaDay()` vào `core/di/injection_container.dart` (điểm ghép); xoá tệp; `main.dart` và `chay_nen.dart` đổi dòng import (3.2) | 0 |
| `lich_nen` | Tách phép tính về `bill/domain` + `goal/domain`; `core/nen` chỉ gộp (3.3) | 0 |
| `kho_anh_quet` | Dời nguyên văn (`git mv`) sang `features/transaction/data/datasources/kho_anh_quet.dart` (3.4) | 0 |

### 3.1 Hai cổng của `SyncEngine`

- `lib/core/sync/cong_so_du_vi.dart` — `abstract interface class CongSoDuVi` với đúng hai phương thức engine gọi:
  `Future<void> datNeoNhieuVi(Iterable<String> walletIds)` và `Future<void> tinhLaiNhieuVi(Iterable<String> walletIds)`
  (chữ ký y `SoDuViService` :59, :73). `SoDuViService` (`wallet/data/`) **`implements CongSoDuVi`** — `data → core` hợp lệ.
- `lib/core/sync/cong_vi_bi_giu.dart` — `abstract interface class CongViBiGiu` cho đúng hai việc engine làm:
  1. thả ví mang cờ mà không còn cặp (thay vòng `viCanTha` + `ThaViBiGiu(...).tha` ở :1226–1228) — chạy **trước** khi đọc hàng chờ,
     giữ nguyên thứ tự hiện tại;
  2. trả tập id bản ghi phải giữ khỏi lô đẩy từ hàng chờ đẩy (thay :1232–1238). Kiểu trả là **record** khai ở `core/sync`
     (`({Set<String> vi, Set<String> hoaDon, Set<String> mucTieu, Set<String> giaoDich})`) để engine không cần `BanGhiBiGiu`
     của `wallet/domain`; tham số là hàng Drift `Bill` / `Goal` / `Transaction` (core/sync được cầm hàng Drift).
  Bản thi hành ở `wallet/data/` (bọc `ViTrungTenNguonImpl` + `ThaViBiGiu` + `banGhiBiGiuTuHang` — **không đổi** phép tính).
  ⚠️ Giữ cam kết G63: engine **không** nhắc tên cột cờ (`bi_tu_choi_trung_ten`) — test quét hiện có canh.
- Constructor: `required CongSoDuVi soDuVi, required CongViBiGiu viBiGiu` — **bắt buộc**, không mặc định. Thiếu là lỗi biên dịch
  (một tham số tuỳ chọn `null` = bỏ bước sẽ là hỏng im lặng). DI (:166) truyền `sl<SoDuViService>()` và bản thi hành ví.
- Test: **một** helper mới ở `test/helpers/` (vd. `taoSyncEngineThu({dioClient, db, …})`) — mọi chỗ dựng `SyncEngine(` trong
  `test/` (41 chỗ ở 26 tệp, đo 2026-10-15) đi qua nó, không tệp nào tự truyền hai cổng. Helper mặc định dùng **bản thật** dựng
  trên `db` (`SoDuViService(db:)` + bản thi hành ví) và nhận hai cổng tuỳ chọn cho ca muốn tiêm bản giả — mặc định ấy là bản
  thật, **không** phải no-op (mục 9). **Không ca nào đổi kỳ vọng.**
- `test/features/wallet/vi_trung_ten_cuc_bo_test.dart` (G63 — đường đồng bộ không nhắc tên cột cờ): thêm
  `lib/core/sync/cong_vi_bi_giu.dart` vào danh sách `duongDongBo` (+1 ca) và sửa docstring dòng 4 (engine hỏi qua
  `CongViBiGiu`, không còn qua `ViTrungTenNguon`).

### 3.2 `noiBoNgheKetQuaDay` về DI

Hàm 19 dòng chỉ gọi `sl<…Resolver>().batDauNghe(sl<SyncEngine>().pushResultStream)` — bản chất là ghép. Gộp nguyên văn (cả
docstring) vào `injection_container.dart`; DI đã import cả hai resolver (đăng ký chúng). Giữ cam kết: gọi **đúng một lần** mỗi
engine Dart, ở `main.dart` và `chay_nen.dart` (hai điểm ghép). Quét 5 (`bill_conflict_resolver_wiring_test`) và
`vi_trung_ten_resolver_wiring_test` phải xanh sau bước này — chạy riêng hai tệp.

Hai test đọc **đường tệp** cũ bằng chuỗi — đổi đường sang `lib/core/di/injection_container.dart`, giữ nguyên phép kiểm:
`test/core/nen/noi_bo_nghe_hai_noi_test.dart` :23 (tệp **định nghĩa** được miễn khỏi phép cấm gọi `batDauNghe`) và
`test/features/wallet/vi_trung_ten_resolver_wiring_test.dart` :25 (đọc hàm nối chung để đòi `batDauNghe`); docstring dòng 1
của tệp sau nhắc tên hàm, không nhắc đường — giữ. Ca 1 của `noi_bo_nghe_hai_noi_test` (đòi chuỗi `noiBoNgheKetQuaDay();` ở
`main.dart` + `chay_nen.dart`) không đổi.

### 3.3 Tách `lichNenKeTiep`

- `bill/domain/` — hàm thuần tính phần hoá đơn: nhận `List<BillEntity>`, `now`, `gioNhac`, `phutNhac`; trả
  `({DateTime? moc, bool coTuDong})` (record **cấu trúc** — không import `core/nen`). Thân là nhánh `if (traDuoc)` hiện tại, nguyên văn.
- `goal/domain/` — hàm thuần tính phần mục tiêu: nhận `List<GoalEntity>`, `now`; trả cùng record. Thân là nhánh `if (trichDuoc)`.
- `core/nen/lich_nen.dart` — giữ `typedef LichNenKeTiep`, lớp `LichNen`, thêm hàm gộp thuần (mốc = nhỏ nhất trong các mốc
  khác `null` — mỗi phần đã lọc `isAfter(now)`; `coTuDong` = OR). Bỏ bốn import `features/`.
- DI (`tinh:` ~:568) gọi hai hàm (bỏ qua phần không có quyền — `traDuoc` / `trichDuoc` hiện là tham số, chuyển thành điều kiện ở DI)
  rồi gộp. Phép chọn mốc và hai ⚠️ trong docstring cũ (không hẹn "ngay" kỳ đã tới hạn; `coTuDong` giữ lượt định kỳ) đi theo hàm.
- Test `test/core/nen/lich_nen_test.dart` (170 dòng): ca của từng phần dời về `test/features/{bill,goal}/domain/`, ca gộp ở lại;
  **kỳ vọng giữ nguyên** (có thể giữ một ca tổ hợp gọi hai hàm + gộp để canh hành vi cũ).
- Tên tệp / hàm chốt ở kế hoạch (gợi ý: `bill/domain/moc_tu_tra_nen.dart` · `goal/domain/moc_trich_nen.dart`).

### 3.4 `kho_anh_quet` về mảng giao dịch

`git mv lib/core/ocr/kho_anh_quet.dart lib/features/transaction/data/datasources/kho_anh_quet.dart` + test
`test/core/ocr/kho_anh_quet_test.dart` → `test/features/transaction/data/datasources/`; import tính lại bằng script
`doi_duong_import.dart` (đã vá C1, ở scratchpad phiên trước — viết lại nếu mất). Không đổi tên lớp / hằng `kThuMucAnhQuet`.
`core/ocr` còn bộ đọc ML Kit + `ten_tep_bien_lai`.

### 3.5 Đo sau gạch 4 (kỳ vọng, ghi số thật khi thi công)

Hạ tầng ngoài điểm ghép: **18 → 8** (đúng 8 dòng của 3.6). DI tăng vài dòng (import hai hàm lịch, đường mới `kho_anh_quet`,
bản thi hành cổng ví) — điểm ghép, không trần. Bốn điểm ghép không đổi danh sách.

### 3.6 Luật "core được đọc hằng số thuần của mảng" (quét 25)

- `conChoCoreImport` (ratchet chỉ-được-giảm, hôm nay 7 mục / 18 dòng) **bỏ**, thay bằng hằng **`domainThuanChoCore`** — danh sách
  cố định **5 tệp**: `features/wallet/domain/wallet_status.dart`, `wallet/domain/wallet_type.dart`,
  `bill/domain/bill_pay_status.dart`, `bill/domain/bill_recurrence.dart`, `goal/domain/uu_tien_hop_le.dart`.
- Luật: tệp `lib/core/**` ngoài `diemGhep` chỉ được `import`/`export` `features/` khi đích nằm trong `domainThuanChoCore`.
- Ca kiểm độ thuần: mỗi tệp trong danh sách chỉ import `dart:` hoặc `data/models/` **của chính mảng nó** (bắt được khi ai đó thêm
  import nặng vào một tệp hằng số mà `core` đang đọc).
- Bản sai có chủ ý: (a) thêm `import '../../features/goal/data/models/goal_entity.dart';` vào một tệp `core/sync` → đỏ; (b) thêm
  `import 'package:flutter/foundation.dart';` vào `uu_tien_hop_le.dart` → ca thuần đỏ. Sao lưu tệp trước, khôi phục từ bản sao.
- Thêm tệp vào danh sách = sửa test = có người soát. Docstring ghi lý do (quyết định 2026-10-11).

## 4. Thiết kế quét 28

- Tệp `test/core/ui/domain_khong_import_tang_tren_test.dart` (số **28** — tiếp theo của bảng *Test quét `lib/`* trong `CLAUDE.md`).
- Quét mọi `.dart` dưới `lib/features/*/domain/`, bỏ dòng chú thích như quét 27 (`boChuThich`); nhận import nháy đơn / kép,
  `package:flowmoney/…` lẫn đường tương đối, BOM (khuôn quét 25 luật 5 / 7).
  - **Luật 1:** không import đường chứa `/presentation/`.
  - **Luật 2:** đường chứa `/data/` thì phải chứa `/data/models/`.
- Ca tiền đề: số tệp domain thấy được > **80** (đo 2026-10-15 bằng `find lib/features -path "*/domain/*" -name "*.dart"`:
  **175** — sàn ≈ nửa; đo lại lúc viết test).
- Danh sách chờ `conCho` (chỉ-được-giảm, "sạch mà quên rút thì đỏ") khởi đầu đúng 5 tệp của 2.2 → rỗng ở cuối bước sửa.
- Bản sai: thêm `import '../presentation/…'` vào một tệp domain → luật 1 đỏ; thêm import `data/repositories/…` → luật 2 đỏ.

**Năm chỗ sửa (dời nguyên văn, không đổi tên):**

1. `pickHomeBudget` (+ docstring) → **`lib/features/budget/domain/pick_home_budget.dart`**; `home_budget_card.dart` bỏ thân hàm,
   import tệp mới; hai tệp `ai_edge/domain` import `../../budget/domain/pick_home_budget.dart`. Nhóm ca test của hàm (hiện trong
   `test/features/home/presentation/widgets/home_budget_card_test.dart`, nếu tách được) dời về `test/features/budget/domain/`.
2. `DongDanhMuc`, `ThongKeKy`, `typedef DongChiBatThuong` → **`lib/features/analytics/data/models/thong_ke_ky.dart`**;
   `LuaChonLoc` → **`lib/features/analytics/data/models/lua_chon_loc.dart`** (tiền lệ `BudgetView` ở `data/models`).
   **Không** `export` lại từ tệp repository (khuôn shim mà phán quyết C5 đợt Thông báo đã bác) — mọi chỗ dùng (≈ 20 lib +
   13 test, đo bằng `grep -rlw` 2026-10-15) đổi / thêm dòng import. Hai tệp interface repository import tệp models mới.

## 5. Thứ tự thi công (mỗi bước một commit)

0. Bộ ảnh "trước" trên máy ảo (APK đang cài `adedaef8…` dựng ở `08effea7` — mã `lib/` không đổi tới HEAD; kiểm SHA trước khi tin;
   bộ ảnh "trước" đợt Thông báo không dùng lại được nếu màn khác — chụp mới các màn ở 6).
1. Quét 28 + `conCho` 5 tệp.
2. `pickHomeBudget` → `budget/domain` (chờ −2).
3. Kiểu Phân tích → `analytics/data/models` + đổi import (chờ −3 → rỗng).
4. `kho_anh_quet` → `transaction/data/datasources` (hạ tầng 18 → 17).
5. `noiBoNgheKetQuaDay` → DI (→ 15).
6. Hai cổng `SyncEngine` + helper test (→ 12). **Toàn bộ `flutter test`.**
7. Tách `lich_nen` (→ 8). **Toàn bộ `flutter test`.**
8. Quét 25: `conChoCoreImport` → `domainThuanChoCore` + ca thuần + bản sai. **Toàn bộ `flutter test`.**
9. Đo, tài liệu (mục 8), bộ ảnh "sau", review toàn nhánh.

Bước 4–7 mỗi bước **rút đúng mục / số dòng** của tệp vừa sạch khỏi `conChoCoreImport` (`vi_tri_tep_theo_luat_test.dart` :52–64)
trong cùng commit — ratchet *"sạch mà quên rút thì đỏ"*; bước 8 mới bỏ hẳn hằng ấy.

Mỗi bước: test vùng vừa sửa xanh, `flutter analyze` = **20**, không ca nào đổi kỳ vọng. Mốc nền: **7.075 pass / 10 skip**;
cuối đợt kỳ vọng thêm số ca của quét 28 (+ ca thuần ở quét 25) — ghi số thật.

## 6. Nghiệm thu

- **Máy ảo, ảnh trước / sau** (khuôn đợt Thông báo — 18 màn, `am start -W`, demo mode, chuỗi thao tác cố định): Trang chủ (thẻ
  ngân sách + khối Nhận xét), Ngân sách (khối Nhận xét), Phân tích (khối tổng, cơ cấu, chi bất thường), Xuất báo cáo (bộ lọc),
  Sổ giao dịch, Thêm giao dịch, Trợ lý AI một câu tổng quan (máy ảo rơi về mẫu câu — vẫn dựng gói số). So SHA-1 + đếm pixel
  khác (bỏ 100 hàng đầu), vàng `#FFFF00` = 0; mọi cặp lệch phải giải thích được.
- **Logcat:** 0 `E/flutter`; có dòng khởi động `SyncEngine` (đẩy / kéo thất bại vì backend tắt là **bình thường**); lịch nền
  (`LichNen` / kênh tự chuyển tiền) không ném. DI nối sai là app chết lúc mở — bước này bắt lỗi nối dây.
- **Không bật backend** (người dùng chốt 2026-10-15) — đồng bộ phủ bằng bộ test (engine thật, nhiều tệp sync); lỗ ghi vào biên
  bản: đẩy / kéo thật với máy chủ, lượt nền WorkManager thật.

## 7. Đối chiếu luật kiến trúc (`KIEN_TRUC_CLIENT_APP.md` mục 4 · 8, quét 22–28)

| Tệp mới / dời | Hàng mục 8 | Chiều import | Khớp? |
|---|---|---|---|
| `core/sync/cong_so_du_vi.dart`, `cong_vi_bi_giu.dart` | hạ tầng không biết mảng → `core/<chủ đề>/` | core không import features | ✅ |
| bản thi hành `CongViBiGiu` ở `wallet/data/` | dịch vụ bị hạ tầng / repository gọi → `data/` (tiền lệ `so_du_vi_service`) | `data → core` | ✅ |
| hai hàm lịch ở `bill/domain`, `goal/domain` | hàm thuần → `domain/` | `domain → data/models` (Entity) | ✅ |
| `transaction/data/datasources/kho_anh_quet.dart` | datasource → `data/datasources/` | `data → domain` (`MonHang`) | ✅ |
| `budget/domain/pick_home_budget.dart` | hàm thuần → `domain/` | `domain → data/models` | ✅ |
| `analytics/data/models/thong_ke_ky.dart`, `lua_chon_loc.dart` | kiểu dữ liệu → `data/models/` | models ← repository / domain / presentation | ✅ |

Quét 23 (≤ 1.200 dòng `presentation`): không tệp `presentation` nào dài thêm (`home_budget_card` ngắn đi). G88: gạch 4 là chính
đợt này; gạch 1–3, 5, 6 đã đóng — không gạch nào bị cản / dời lại.

## 8. Tài liệu phải sửa (bước 9)

`CLAUDE.md` (bảng *Test quét `lib/`* hàng 25 — luật hằng thuần thay ratchet — và hàng **28** mới, *"Số tiếp theo là **29**"*;
hàng *Đụng vào presentation* — G88 đóng; mốc test), `docs/KIEN_TRUC_CLIENT_APP.md` (mục 4 hàng `core`: luật hằng thuần +
danh sách 5 tệp; mục 6 quét 25 / 28; mục 9 bỏ *"ba lệch domain → data/repositories"* và *"ai_edge/domain → presentation"*, giữ
vòng bill ↔ notification), `docs/CLIENT_APP_KNOWN_GAPS.md` (G88 **ĐÓNG** — khối ✅ gạch 4 + dòng tóm tắt + *Cập nhật*),
`docs/PROJECT_CONTEXT.md` (khối mới mục 14), `docs/QUET_ANH_FEATURE.md` / `docs/GOAL_FEATURE.md` / `docs/bill/BILL_DOCUMENTATION.md`
chỉ dòng `grep` ra đường dẫn cũ (`core/ocr/kho_anh_quet`, `lichNenKeTiep`, `noi_bo_nghe_ket_qua_day`, `pickHomeBudget`). Spec này:
thêm khối ✅ số đo + nghiệm thu.

## 9. Rủi ro hỏng im lặng

- **Cổng ví bỏ trống:** đã chặn bằng tham số **bắt buộc**. Đừng thêm mặc định "no-op" cho test tiện — đó chính là hỏng im lặng.
- **Thứ tự trong `_collectPendingOps`:** thả ví (bước 0) phải chạy **trước** khi đọc hàng chờ và trước phép tính bản ghi bị giữ —
  giữ y thứ tự :1226 → :1232 (bẫy G63: bước 1b quên lọc là vòng đồng bộ nóng).
- **Lịch nền:** phép gộp phải giữ đúng nghĩa *"chỉ mốc ở TƯƠNG LAI"* và *"`coTuDong` giữ lượt định kỳ kể cả khi không có mốc"*;
  bỏ quyền thì phần ấy **không** góp `coTuDong` (Basic không cần đánh thức máy).
- **Hai lần `noiBoNgheKetQuaDay`** trong cùng engine = hoàn tác chạy hai lượt cho một khoản chi (docstring cũ) — gộp vào DI không
  được biến nó thành gọi trong `registerLazySingleton` (chạy lại mỗi lần dựng).
