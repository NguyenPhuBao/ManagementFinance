# Bịt các điểm rò kiến trúc của Client-app — giữ feature-first, hàm thuần, test quét

> Ngày 2026-10-10 · nhánh `TranQuangDat` · người dùng duyệt từng phần trong chat (brainstorm, AskUserQuestion) ngay sau
> bản đánh giá kiến trúc cùng ngày. **Người dùng app không thấy gì khác** ở mọi việc trong spec này; khác biệt chỉ ở mã,
> bộ test, CI và tài liệu. Mọi con số đo bằng script ngày 2026-10-10 trên `src/Client-app`.

## 1. Vì sao, và người dùng thấy gì khác

Bản đánh giá kiến trúc 2026-10-10 kết luận Client-app là **feature-first, ba tầng data / domain / presentation,
offline-first**, với hai chữ ký thật: luật nghiệp vụ là hàm thuần có đúng một định nghĩa được 21 test quét toàn `lib/`
canh giữ, và mọi ranh giới nền tảng là cổng có bản giả. Kiến trúc ấy **giữ nguyên**. Spec này chỉ bịt bốn chỗ cây bị méo
mà bản đánh giá đo được:

| Chỗ méo | Số đo |
|---|---|
| Trang gọi thẳng CSDL qua service locator, đi vòng repository | `sl<AppDatabase>()` 29 lần ở 17 tệp `presentation` |
| Hai trang khổng lồ gánh cả khối lẽ ra là widget riêng | `analytics_page` 4.208 dòng · `add_transaction_page` 3.105 dòng |
| `AuthBloc` vừa giữ trạng thái vừa làm điểm ghép phiên | 560 dòng · 12 handler · 23 lần `sl<` · import 7 mảng khác |
| Không có máy nào ngoài máy dev chạy test; tài liệu kiến trúc tả sai | 0 workflow CI · `Project.md` mục 3.3 ghi *"mỗi màn hình một BLoC"* trong khi có 3 Bloc, 7 Cubit, 289 `setState` |

Người dùng không thấy gì khác trên màn hình. Thứ đổi là: trang không còn cầm CSDL, hai trang lớn thành widget theo khối,
Bloc chỉ còn trạng thái, và có máy khác kiểm mã sau mỗi commit.

## 2. Các quyết định đã chốt

| # | Câu hỏi | Chọn | Loại |
|---|---|---|---|
| 1 | Mức thay đổi | **Bịt điểm rò, giữ kiến trúc hiện tại** | chuyển hẳn sang Clean Architecture · chỉ tài liệu cho báo cáo |
| 2 | Phạm vi | **Cả bốn việc**: UI thôi gọi CSDL + test quét · tách hai trang · rút điều phối phiên · CI + tài liệu | — |
| 3 | Nghiệm thu giao diện | **Máy ảo 411 dp, so ảnh trước/sau**; OnePlus một lượt cuối khi cắm | OnePlus mọi màn · chỉ `flutter test` |
| 4 | Thứ tự với việc dở | **Push 16 commit, tái cấu trúc ngay, Task 10 (nghiệm thu chạy nền) sau**; cùng nhánh `TranQuangDat` | Task 10 trước · nhánh riêng |
| 5 | Việc 1 | **A — qua repository của mảng + `ThongBaoNguon`**; phương thức mới trả đúng kiểu chỗ gọi đang dùng (hàng Drift) | nguồn đọc theo màn · chỉ tiêm DAO qua constructor |
| 6 | Việc 2 | **A — tách widget theo khối, trạng thái ở lại trang**; trần 1.200 dòng có danh sách miễn trừ | Cubit/controller cho Thêm giao dịch · `part` |
| 7 | Việc 3 | **A — `PhienDieuPhoi` hai pha ở `core/auth`**, Bloc giữ thứ tự emit và chốt `_vanLaPhien` | nghe `AuthBloc.stream` ở `main.dart` · chỉ đổi `sl<` thành constructor |
| 8 | Việc 4 | **A — GitHub Actions cho Client-app**, analyze không fatal info/warning + so mức nền 20, `flutter test`; người dùng **cho phép đích danh** tạo tệp ở `.github/workflows/` | git hook · cả hai |
| 9 | `Project.md` mục 3.3 | **Đơn CAN-LAM 42**, không sửa thẳng — tệp do backend viết (48/50 commit) | — |
| 10 | Entity cho 14 mảng, cấm import kiểu Drift ở UI | **Không làm** trong đợt này; ghi nợ | — |

## 3. Nguyên tắc chung và thứ tự thi công

**Bất biến của cả đợt**

- Không đổi hành vi người dùng, không đổi schema (vẫn v30), không đổi payload đồng bộ, không thêm gói pub.
- Mọi luật "một định nghĩa duy nhất" giữ nguyên chỗ; không chép luật ra chỗ mới khi dời mã.
- Mỗi task một hoặc vài commit nhỏ; sau mỗi commit `flutter test` xanh và `flutter analyze` không vượt mức nền **20**.
- Mỗi chốt mới đều thành **test quét** để không tái phạm (22, 23, 24 — nối tiếp 21 test đã có).
- Chỉ sửa `src/Client-app`, `docs/`, và đúng một tệp `.github/workflows/client-app.yml` theo cho phép đích danh.
- Mã thử `lib/features/ai_chat/spike/` không nằm trong `presentation`, ngoài phạm vi.

**Thứ tự**

| Bước | Việc | Chạm vào | Chốt bằng |
|---|---|---|---|
| 0 | CI | `.github/workflows/client-app.yml` | lần chạy đầu xanh trên GitHub |
| 1 | UI thôi gọi CSDL | 17 tệp `presentation`, 4 interface + 1 nguồn, 3 lớp giả ở 2 tệp test, DI | test quét 22 |
| 2 | Rút điều phối phiên | `auth_bloc.dart`, `core/auth/`, DI, test auth | test quét 24 + chủ sở hữu `start` |
| 3 | Tách hai trang | `analytics_page`, `add_transaction_page`, ~20 tệp widget mới | test quét 23, ảnh trước/sau |
| 4 | Tài liệu | `docs/KIEN_TRUC_CLIENT_APP.md`, README, đơn CAN-LAM 42, `CLAUDE.md`, `PROJECT_CONTEXT.md`, `CLIENT_APP_KNOWN_GAPS.md` | soát chéo với mã |

CI đi trước để mọi commit sau đều được máy khác kiểm. Việc 1 trước việc 2 vì nó sửa đúng các tệp mà việc 2 sẽ dời.
Tài liệu cuối để tả đúng cây sau khi đổi. Bộ ảnh gốc chụp **trước bước 1**.

## 4. Việc 1 — UI thôi gọi thẳng CSDL

### 4.1 Nguyên tắc

Trang chỉ được cầm **repository của mảng** hoặc **một nguồn đã đăng ký DI**; lối xuống DAO chỉ còn ở tầng `data` và
`core`. Repository được thêm **phương thức chuyển tiếp** đúng tên DAO đang gọi, không đổi nghĩa, không thêm luật.

**Kiểu trả về:** phương thức mới trả **đúng kiểu chỗ gọi đang dùng**, tức hàng Drift (`Wallet`, `Transaction`,
`Category`, `Bill`), vì 17 trang này đang cầm `List<Wallet>` / `List<Transaction>` và truyền vào `TransactionLookup`,
`BillPaymentSheet`, `thuChiThangCua`, vốn đều nhận hàng Drift. Trả Entity sẽ lan kiểu sang hàng chục widget và fixture
test, vượt phạm vi quyết định 10. Tên phương thức mang hậu tố **`Rows`** để lộ rõ nó trả hàng Drift, khác với các phương
thức Entity có sẵn. `BillRepository` vốn đã trả hàng Drift nên không cần hậu tố.

### 4.2 Bản đồ 29 chỗ gọi

| Nhóm | Chỗ gọi (tệp:dòng) | Đích |
|---|---|---|
| Ví cho bộ chọn | `bill_add_page:98`, `bill_edit_page:85`, `bill_actions:17`, `goal_detail_page:239, 331, 524`, `add_transaction_page:689` | `WalletRepository.getActiveRows` **mới** |
| Ví tra tên | `bill_page:88` (getAll), `goal_detail_page:195, 213` (getById), `transaction_page:133` (watchAll) | `WalletRepository.getAllRows` / `getRowById` / `watchAllRows` **mới** |
| Danh mục cho bộ chọn | `bill_add_page:98`, `bill_edit_page:85` (`getCategoryRows(id, 'chi')`) | `CategoryManagementRepository.selectableChildren` **có sẵn** |
| Danh mục tra tên | `bill_page:88` (getBangTraTen), `bill_actions:17` (getById), `transaction_page:133` (watchAll) | `loadBangTraTen` / `getRowById` / `watchAllRows` **mới** |
| Giao dịch | `add_transaction_page:532, 799` (getAll), `home_page:638` (watchAll), `transaction_page:133` (watchAll → `demChuaGan`) | `TransactionRepository.getAllRows` / `watchAllRows` **mới** |
| Hoá đơn | `bill_detail_page:62` (getById) | `BillRepository.getById` **mới** |
| Mục tiêu | `goal_detail_page:213` (`goalDao.getAll`) | `GoalRepository.getGoals` **có sẵn** |
| Thông báo | `goal_page:169`, `home_page:255`, `profile_page:36` (watchUnreadCount), `notification_panel:34` (watchFeed), `notification_center_page:135` (dao đủ 10 lối), `add_transaction_page:499` (getAll), `:558` (xoaCung), `transaction_page:133` (watchDemBienDong) | `ThongBaoNguon` **mới** (4.4) |
| Truyền `db` cho hàm tự do | `gan_danh_muc_page:89` (`taiDuLieuGan`), `:96` (`apDungGan`) | lớp `GanDanhMucNguon` (4.5) |
| Phản hồi AI | `budget_page:87` (`aiFeedbackDao.ghi`) | `TaiPhanBoNguon.ghiPhanHoi` **mới** (4.5) |
| Spike SQL | `ai_chat_page:446` (`chaySpikeSql(db:)`) | spike tự lấy `db`, trang không truyền (4.5) |
| AuthBloc | `auth_bloc:201` (`purgeDataForAccount`), `:548` (`purgeDataForOtherAccounts`) | sang việc 3 (`PhienDieuPhoi.xoaDuLieu`, `moPhienCucBo`) |
| Trang chủ | `home_page:40` (`final db = sl<AppDatabase>()` dùng cho các stream ở 110–185) | `WalletRepository.watchAllRows`, `TransactionRepository.watchAllRows`, `CategoryManagementRepository.watchAllRows` |

### 4.3 Phương thức mới

| Interface | Phương thức | Trả về | Chuyển tiếp tới |
|---|---|---|---|
| `WalletRepository` | `getActiveRows(int idaccount)` | `Future<List<Wallet>>` | `walletDao.getActive` |
| `WalletRepository` | `getAllRows(int idaccount)` | `Future<List<Wallet>>` | `walletDao.getAll` |
| `WalletRepository` | `watchAllRows(int idaccount)` | `Stream<List<Wallet>>` | `walletDao.watchAll` |
| `WalletRepository` | `getRowById(String id)` | `Future<Wallet?>` | `walletDao.getById` |
| `TransactionRepository` | `getAllRows(int idaccount)` | `Future<List<Transaction>>` | `transactionDao.getAll` |
| `TransactionRepository` | `watchAllRows(int idaccount)` | `Stream<List<Transaction>>` | `transactionDao.watchAll` |
| `CategoryManagementRepository` | `loadBangTraTen(int accountId)` | `Future<List<Category>>` | `categoryDao.getBangTraTen` |
| `CategoryManagementRepository` | `watchAllRows(int accountId)` | `Stream<List<Category>>` | `categoryDao.watchAll` |
| `CategoryManagementRepository` | `getRowById(String id)` | `Future<Category?>` | `categoryDao.getById` |
| `BillRepository` | `getById(String id)` | `Future<Bill?>` | `billDao.getById` |
| `TaiPhanBoNguon` | `ghiPhanHoi(AiRebalancingFeedbacksCompanion)` | `Future<void>` | `aiFeedbackDao.ghi` |

Mười một phương thức, không phương thức nào mang luật: chúng chỉ dời **chỗ cầm DAO** từ trang về tầng data. Chỗ nào
`WalletLocalDataSource` đã có phương thức tương ứng (`getActive`, `getAll`, `watchAll`, `getById`) thì repository đi qua
datasource; chỗ chưa có thì datasource thêm lối chuyển tiếp trước. Test quét `wallet_picker_sources_test` đòi **phân loại
tay** mọi chỗ đọc danh sách ví là *bộ chọn* hay *bảng tra tên*: bảy chỗ chuyển sang `getActiveRows` và bốn chỗ sang
`getAllRows` / `watchAllRows` phải được ghi vào bảng phân loại của nó, cùng lý do như bản gốc.

### 4.4 `ThongBaoNguon`

Mảng thông báo không có tầng `data` (logic ở `core/notification`, giao diện ở `features/notification/presentation`), nên
cổng đặt ở **`lib/core/notification/thong_bao_nguon.dart`**: `abstract class ThongBaoNguon` với đúng mười hai lối giao
diện đang dùng của `NotificationDao`:

```
Stream<int>                   watchUnreadCount(int idaccount)
Stream<List<AppNotification>> watchFeed(int idaccount, {int limit})
Future<List<AppNotification>> getAll(int idaccount)
Stream<int>                   watchDemBienDong(int idaccount)
Future<void>                  markRead(...)      Future<void> markAllRead(...)   Future<void> markUnread(...)
Future<void>                  khoaChuaDoc(...)   Future<void> dismiss(...)        Future<void> khoiPhuc(...)
Future<void>                  insertIfAbsent(...) Future<void> xoaCung(int idaccount, String khoa)
```

Chữ ký từng lối chép **y nguyên** từ `NotificationDao`. Bản thi hành `ThongBaoNguonDrift(NotificationDao)` chỉ chuyển
tiếp; đăng ký `registerLazySingleton<ThongBaoNguon>` trong DI, cả chế độ app lẫn chế độ nền. `NotificationCenterPage`
đổi tham số tiêm `dao` thành `nguon` (kiểu `ThongBaoNguon?`), `NotificationPanel` và `NotificationBell` ở Trang chủ /
Mục tiêu / Cá nhân đọc qua `sl<ThongBaoNguon>()`. Đây là cổng mỏng cùng khuôn `OsNotifier`, **không** mang luật mới;
`BadgeUpdater` và `NotificationScanner` ở `core` vẫn cầm DAO như cũ.

### 4.5 Ba chỗ truyền `db` hoặc hàm tự do

- **Gắn danh mục hàng loạt.** Hai hàm tự do `taiDuLieuGan({db, danhMuc, phanHoi, idaccount})` và `apDungGan({db, repo,
  dong, categoryId})` ở `category/data/gan_danh_muc_nguon.dart` gói lại thành lớp `GanDanhMucNguon` nhận `AppDatabase`,
  `CategoryManagementRepository`, `TransactionRepository`, `GoiYPhanHoiStore?` qua constructor, hai phương thức `tai(id)` và
  `apDung(dong, categoryId)`; đăng ký DI; trang gọi `sl<GanDanhMucNguon>()`. Hàm thuần `xetGan`, `demChuaGan`,
  `hopLeTheoChieu` ở `domain` không đổi.
- **Phản hồi kế hoạch cân đối.** `TaiPhanBoNguon` (đã có interface + `TaiPhanBoNguonImpl` cầm `db`) thêm `ghiPhanHoi`;
  `budget_page` truyền `sl<TaiPhanBoNguon>().ghiPhanHoi`. Bốn lớp giả `implements TaiPhanBoNguon` thêm stub.
- **Spike SQL.** `chaySpikeSql` bỏ tham số `db`, tự lấy `sl<AppDatabase>()` bên trong `ai_chat/spike/spike_sql.dart`
  (thư mục `spike/` không phải `presentation`). Mã này chỉ sống sau `--dart-define=SPIKE_SQL=true`.

### 4.6 Chi phí thật: 3 lớp giả ở 2 tệp (đo lại 2026-10-10)

Bộ test dùng lớp giả viết tay `implements <Interface>`. Đếm theo interface ra 55 lượt (ví 19, hoá đơn 18, giao dịch 11,
`TaiPhanBoNguon` 4, danh mục 3) nhưng đó là **đếm trùng**: `bo_cong_cu_test` và vài tệp khác giả nhiều interface, nên
thật ra là **49 tệp**. Trong 49 tệp ấy **47 đã có `noSuchMethod`** nên thêm phương thức trừu tượng **không** làm chúng vỡ
biên dịch. Chỉ hai tệp cần stub:

| Tệp | Lớp giả | Phương thức cần stub |
|---|---|---|
| `test/features/wallet/wallet_cubit_total_test.dart` | `_Repo implements WalletRepository` | `getActiveRows`, `getAllRows`, `watchAllRows`, `getRowById` |
| `test/features/category/presentation/category_test_fakes.dart` | `FakeCategoryRepository`, `FakeTransactionRepository` | `loadBangTraTen`, `watchAllRows`, `getRowById` · `getAllRows`, `watchAllRows` |

Stub viết tay `=> throw UnimplementedError()`, có `@override`; ném lỗi là cố ý: lớp giả nào bị gọi tới phương thức mới mà
chưa chuẩn bị thì test đỏ rõ, không im lặng. Bài học ghi lại: **đếm tệp bằng `sort -u`**, không cộng dồn theo interface.

### 4.7 Test quét 22

`test/core/ui/presentation_khong_cham_csdl_test.dart` — quét mọi tệp dưới `lib/features/*/presentation/` và
`lib/shared/`, đỏ khi gặp:

- chuỗi `sl<AppDatabase>`, hoặc
- lối truy cập DAO: biểu thức khớp `\.(wallet|transaction|category|budget|bill|goal|notification|notificationEvent|aiFeedback|goiYPhanHoi|goiYHoaDon|thuTuKhoi|khoaTuChuyenTien)Dao\b`.

Danh sách miễn trừ **rỗng** khi việc 1 kết thúc. Ca tiền đề: phép quét phải thấy ≥ 1 tệp `presentation`, để không xanh
giả khi chạy sai thư mục. **Không** cấm import `core/database/` vì UI còn cầm kiểu hàng Drift (quyết định 10).

## 5. Việc 2 — Tách hai trang khổng lồ

### 5.1 Trang Phân tích, 4.208 dòng

Hiện là 40 lớp riêng tư trong một tệp, đã chia thành 9 cụm `CumKhoi`. Dời ra `lib/features/analytics/presentation/widgets/phan_tich/`,
mỗi cụm một tệp; lớp bỏ dấu gạch dưới để công khai; **giữ nguyên** `Key`, chuỗi chữ và cấu trúc cây widget.

| Tệp mới | Lớp chuyển sang | Ước lượng dòng |
|---|---|---|
| `header_phan_tich.dart` | `Header`, `TieuDeTrang`, `NutXuat`, `ChonPhamVi`, `Rong` | 230 |
| `khoi_tong.dart` | `KhoiTong`, `HangChipSoSanh`, `TheTong`, `TheConLai` | 300 |
| `khoi_xu_huong.dart` | `KhoiXuHuong`, `ChonDanhMucXuHuong`, `ChipDanhMuc`, `ChuGiaiDuong` | 510 |
| `khoi_dong_tien_tu_do.dart` | `KhoiDongTienTuDo` | 270 |
| `khoi_du_bao.dart` | `KhoiDuBao`, `BaConSoDuBao`, `DongSo`, `DongViThieu`, `ChuGiaiDuBao`, `MucChuGiai`, `NetChuGiai`, `BieuDoDuBao`, `DongCamKet`, `NhanNho` | 580 |
| `khoi_dong_tien.dart` | `KhoiDongTien`, `KhoiThacNuoc` | 360 |
| `khoi_so_lieu_nhanh.dart` | `KhoiSoLieuNhanh` | 140 |
| `khoi_lich.dart` | `KhoiLich`, `OLich`, `ChuGiaiNhiet`, `TomTatNgay` | 280 |
| `khoi_theo_vi.dart` | `KhoiTheoVi` | 80 |
| `khoi_top_chi.dart` | `KhoiTopChi` | 130 |
| `khoi_vay_no.dart` | `KhoiVayNo`, `KhoiVayNoKhac` | 230 |
| `khoi_co_cau.dart` | `KhoiDonut`, `Donut`, `ChuGiaiDonut`, `DanhSachDanhMuc`, `DongDanhMuc` | 500 |
| `khoi_tong_tai_san.dart` | `KhoiTongTaiSan`, `BieuDoTaiSan` | 240 |
| `analytics_page.dart` còn lại | `AnalyticsPage`, `NoiDung` với `_cacCum`, `_xepCum` | ~350 |

Lớp quá ngắn tên (`_O`, `_ChuGiai`) đổi thành `OLich`, `ChuGiaiDonut` để không trùng khi công khai. Đã kiểm ngày
2026-10-10: không lớp công khai nào trong `lib/` đang mang các tên dự định.

### 5.2 Trang Thêm giao dịch, 3.105 dòng

Trạng thái 61 trường **ở lại** `_AddTransactionPageState` (quyết định 6). Mười lăm hàm `_build…` và bảng chọn ví thành
widget nhận giá trị + callback, đặt ở `lib/features/transaction/presentation/widgets/them_giao_dich/`:

| Tệp mới | Thay cho | Nhận |
|---|---|---|
| `ban_phim_so.dart` | `_buildNumericKeyboard`, `_buildKeyContent` | `onKey`, cờ đã có số tiền |
| `khoi_so_tien.dart` | `_buildAmountDisplay`, `_buildSegmentControl`, `_buildSegmentButton` | chuỗi số tiền, chiều, `onChonHuong`, `onChamSoTien` |
| `the_form.dart` | `_buildFormCard`, `_buildFormRow`, `_buildDebtDirectionRow`, `_directionChip` | mọi giá trị form + callback mở bộ chọn |
| `dai_nguon_bien_dong.dart` | `_buildDaiNguon`, `_buildChonSoTien`, `_buildGoiYChuyen`, `_buildNhacTrung` | `DienSanBienDong`, gợi ý, callback |
| `o_nhap_nhanh.dart` | `_buildNhapNhanh` | controller, trạng thái đọc AI, callback |
| `the_goi_y.dart` | `_buildSuggestionCard`, `_buildDeXuatTuKhoa` | gợi ý, đề xuất, callback |
| `bang_chon_vi.dart` | `_showWalletPickerBottomSheet` | danh sách ví, ví đang chọn, callback |

Phần dời đi khoảng 1.300 dòng; trang còn khoảng **1.800 dòng toàn logic**. Xuống nữa cần controller riêng, là hướng B
người dùng để lại; ghi là **nợ có tên** (mục 10).

### 5.3 Quy tắc dời mã

- Dời **nguyên văn** thân widget; chỉ đổi tham chiếu trường `_x` thành tham số. Không "sửa tiện tay" bố cục hay chữ.
- Giữ mọi `Key(...)`, chuỗi hiển thị, thứ tự con trong `Column`/`Row`, và khoảng cách 24 giữa cụm của trang Phân tích.
- Widget mới **không** import `core/di`; dữ liệu đi qua tham số. Chỗ nào cụm đang gọi `context.read<AnalyticsCubit>()`
  thì giữ, vì Cubit đến từ cây widget chứ không từ `sl`.
- Mỗi tệp mới có docstring một đoạn nói nó là khối nào của trang nào.
- 28 tệp test import `add_transaction_page.dart` và 2 tệp import `analytics_page.dart` chỉ dựng lớp trang công khai và
  tìm bằng `Key` (38 lần ở test Phân tích) hoặc chữ; lớp riêng tư vốn không tham chiếu được từ test, nên đổi tên công khai
  không chạm test. Đây là lý do việc 2 **không** đổi test có sẵn; nếu buộc phải đổi một kỳ vọng, đó là dấu hiệu hành vi
  đã đổi, phải dừng và soát.

### 5.4 Test quét 23

`test/core/ui/tep_presentation_khong_qua_dai_test.dart`: tệp `.dart` dưới `lib/features/*/presentation/` không quá
**1.200 dòng**. Danh sách miễn trừ ghi **trần riêng từng tệp, chỉ được giảm** (cùng khuôn danh sách có số đếm của
`khong_co_nut_chet_test`):

| Tệp | Trần sau đợt này |
|---|---|
| `transaction/presentation/pages/add_transaction_page.dart` | 1.800 |
| `notification/presentation/pages/notification_settings_page.dart` | 1.615 |
| `goal/presentation/pages/goal_add_page.dart` | 1.570 |
| `goal/presentation/pages/goal_detail_page.dart` | 1.483 |
| `analytics/presentation/pages/report_preview_page.dart` | 1.270 |

Số trần của bốn tệp cuối là số dòng đo ngày 2026-10-10; ai làm chúng dài hơn là test đỏ. Tách xong tệp nào thì rút
tên khỏi danh sách.

## 6. Việc 3 — Rút điều phối phiên khỏi `AuthBloc`

### 6.1 Interface

`lib/core/auth/phien_dieu_phoi.dart`:

```dart
abstract class PhienDieuPhoi {
  /// Gộp `SyncEngine.sessionInvalidStream` + `AuthInterceptor.sessionExpiredStream`. Bloc hỏi lại server trước khi đăng xuất.
  Stream<void> get phienCoTheChet;
  /// Gộp `RealtimeChannel.buocDangXuat` + `AuthInterceptor.taiKhoanBiTuChoi` — lời từ chối mang lý do, không hỏi lại.
  Stream<ThongBaoBuocDangXuat> get buocDangXuat;

  /// Pha cục bộ, TRƯỚC AuthSuccess, cả mở app lẫn đăng nhập: `purgeDataForOtherAccounts` rồi xoá cache SLM nếu có
  /// hàng bị dọn; `PersonalDefaultCategories.convertLegacyRows`; `NotificationScanner.start`.
  Future<void> moPhienCucBo(int idaccount);
  /// `RealtimeChannel.start`. Tách khỏi [batDongBo] vì Bloc kiểm `_vanLaPhien` giữa hai bước.
  Future<void> batThoiGianThuc(int idaccount);
  /// `SyncEngine.start`; [cho] = true đợi chu kỳ đầu rồi `DefaultCategorySeeder.seedForAccount` + `scheduleSync` nếu
  /// có bản sao mới (đăng nhập); false thì không đợi, nối việc tạo bản sao vào `.then` (mở app). Chỉ tạo khi
  /// `hasCompletedPull`.
  Future<void> batDongBo(int idaccount, {required bool cho});
  /// Chỉ sau đăng nhập mới: `DefaultAccountDataInitializer.ensureForAccount`; đặt lại `AnTheChoXoa` và
  /// `AnNhacViTrungTen` về false.
  Future<void> sauDangNhap(int idaccount);
  /// Dừng mọi thứ sống theo phiên: `SyncEngine.stop`, `NotificationScanner.stop` (kèm `cancelAll`),
  /// `RealtimeChannel.stop`, `KhoAnhQuet.xoaHet`.
  Future<void> dongPhien();
  /// `AppDatabase.purgeDataForAccount(idaccount)` — chỉ gọi từ đường cưỡng chế khi `daXoa` và nguồn khác `lamMoi`.
  Future<void> xoaDuLieu(int idaccount);
}
```

Bản thi hành `PhienDieuPhoiThat` ở `lib/core/auth/phien_dieu_phoi_that.dart` nhận qua constructor **bốn dịch vụ của
`core`** (`SyncEngine?`, `RealtimeChannel?`, `NotificationScanner?`, `AuthInterceptor?`) và **hook hàm** cho mọi việc thuộc
mảng khác, để `core/auth` **không import `features/`**:

| Hook | Kiểu | DI nối tới |
|---|---|---|
| `donTaiKhoanKhac` | `Future<int> Function(int)` | `AppDatabase.purgeDataForOtherAccounts` |
| `xoaBanSao` | `Future<int> Function(int)` | `AppDatabase.purgeDataForAccount` |
| `xoaCacheSlm` | `Future<void> Function()?` | `SlmCache.xoaHet` |
| `chuyenHangSeedCu` | `Future<void> Function(int)?` | `PersonalDefaultCategories.convertLegacyRows` |
| `taoBanSaoDanhMuc` | `Future<int> Function(int)?` | `DefaultCategorySeeder.seedForAccount` |
| `seedTaiKhoanMoi` | `Future<void> Function(int)?` | `DefaultAccountDataInitializer.ensureForAccount` |
| `xoaAnhQuet` | `Future<void> Function()?` | `KhoAnhQuet.xoaHet` |
| `datLaiCoGiaoDien` | `void Function()?` | đặt `AnTheChoXoa` và `AnNhacViTrungTen` về `false` |

Dịch vụ hay hook nào hôm nay đứng sau `sl.isRegistered<...>()` thì là tham số **nullable** và bỏ qua khi `null`, giữ đúng
hành vi. Khi `SyncEngine` là `null` thì `moPhienCucBo`, `batThoiGianThuc`, `batDongBo` và phần seed của `sauDangNhap`
không làm gì — đúng với khối `if (sl.isRegistered<SyncEngine>())` đang bao quanh chúng. Hai stream gộp dựng bằng một
`StreamController.broadcast` mỗi luồng, nghe từng nguồn, đóng ở `dispose()`; không thêm gói. Test bộ điều phối vì thế
chỉ cần closure ghi nhật ký cho hook và ba lớp spy có sẵn trong test auth.

### 6.2 `AuthBloc` sau khi đổi

| Handler | Trước | Sau |
|---|---|---|
| constructor | 4 subscription qua `sl<SyncEngine>`, `sl<AuthInterceptor>`, `sl<RealtimeChannel>` | 2 subscription: `phien.phienCoTheChet` → `SessionInvalidated`; `phien.buocDangXuat` → `TaiKhoanBiBuocDangXuat` |
| `_onAuthCheckRequested` | purge, convertLegacy, scanner.start, emit, verify, realtime.start, `_vanLaPhien`, engine.start không đợi + seed | `moPhienCucBo` · emit · verify · `batThoiGianThuc` · `_vanLaPhien` · `batDongBo(cho: false)` |
| `_onLoginSubmitted` | purge, convertLegacy, scanner, realtime, engine đợi, seed, initializer, hai cờ | `moPhienCucBo` · `batThoiGianThuc` · `batDongBo(cho: true)` · `sauDangNhap` · emit |
| `_onLogoutRequested` | `_dungMoiThuCuaPhien` + logout | `dongPhien` + logout |
| `_onSessionInvalidated` | verify + `_dungMoiThuCuaPhien` + logout | verify + `dongPhien` + logout |
| `_onTaiKhoanBiBuocDangXuat` | `_dungMoiThuCuaPhien`, purge có điều kiện, `xoaPhienTrenMay` | `dongPhien`, `xoaDuLieu` cùng điều kiện, `xoaPhienTrenMay` |
| `_dungMoiThuCuaPhien`, `_taoBanSaoDanhMuc`, `_donDuLieuTaiKhoanKhac` | ba hàm riêng trong Bloc | **xoá**, logic nằm trong `PhienDieuPhoiThat` |

Thứ tự emit, cờ `_dangBuocDangXuat`, `_thongBaoBuocDangXuat`, `_phatChuaDangNhap`, và mọi phép kiểm `_vanLaPhien` sau
`await` **giữ nguyên vị trí** — chúng là quyết định về trạng thái phiên, thuộc Bloc. Điều kiện *không xoá dữ liệu khi
nguồn là `lamMoi`* (G36, người dùng chốt giữ 2026-09-13) **giữ nguyên trong Bloc**; bộ điều phối chỉ thi hành `xoaDuLieu`.

### 6.3 DI và constructor

`AuthBloc({required AuthRepository authRepository, PhienDieuPhoi? phien, DefaultAccountDataInitializer?
defaultAccountDataInitializer})`. `phien == null` nghĩa là *không điều phối gì*, đúng hành vi hôm nay khi `sl` chưa đăng
ký dịch vụ, nên **41 tệp test** đang dựng `AuthBloc(` trần không phải đổi. Tham số `defaultAccountDataInitializer` giữ cho
tương thích; khi có `phien` thì `sauDangNhap` làm việc seed và tham số ấy bị bỏ qua (docstring nói rõ). DI đăng ký
`PhienDieuPhoiThat` là lazy singleton rồi truyền vào `AuthBloc` (factory).

Nhờ hook, `core/auth/` **không import `features/`**; việc nối hook tới `SlmCache`, seeder, initializer, hai cờ giao diện
nằm ở `injection_container.dart`, đúng chỗ điểm ghép hiện có. Số dòng `core` import `features` vì thế **giảm**, không tăng.

### 6.4 Test

- `test/core/auth/phien_dieu_phoi_that_test.dart`: dịch vụ giả ghi nhật ký lời gọi; kiểm thứ tự trong `moPhienCucBo`;
  *chỉ xoá cache SLM khi có hàng bị dọn*; *chỉ tạo bản sao khi `hasCompletedPull`*; `cho: true` đợi, `cho: false` không
  chặn; `dongPhien` gọi đủ bốn dịch vụ kể cả khi một dịch vụ `null`; `xoaDuLieu` gọi đúng id; hai stream gộp phát lại từ
  cả hai nguồn.
- Test `AuthBloc` hiện có (`session_validation_test`, `auth_bloc_buoc_dang_xuat_test`, …) đang đăng ký dịch vụ giả vào
  `sl` để kiểm thứ tự khởi động: chuyển sang dựng `PhienDieuPhoiThat` **từ chính các dịch vụ giả ấy** và truyền vào
  `AuthBloc(phien:)`, nên kỳ vọng về thứ tự còn nguyên giá trị; không hạ chuẩn ca nào.
- `sync_engine_start_owner_test` đổi chủ sở hữu được phép gọi `.start(idaccount:` sang `phien_dieu_phoi_that.dart` và
  **mở rộng** phép quét cho cả `RealtimeChannel.start` và `NotificationScanner.start` (ba hành động mở phiên, một chủ).
- **Test quét 24** `test/features/auth/auth_bloc_khong_sl_test.dart`: `auth_bloc.dart` không chứa `sl<`, không import
  `core/di/`.

## 7. Việc 4 — CI và tài liệu

### 7.1 Workflow `.github/workflows/client-app.yml`

Người dùng cho phép đích danh tạo tệp này (quyết định 8). Nội dung:

| Mục | Giá trị |
|---|---|
| Kích hoạt | `push` mọi nhánh và `pull_request` vào `main`, chỉ khi đổi `src/Client-app/**` hoặc chính tệp workflow |
| Đồng thời | `concurrency` theo nhánh, huỷ lượt cũ |
| Máy | `ubuntu-latest`, `timeout-minutes: 40`, `working-directory: src/Client-app` |
| Bước 1 | `actions/checkout@v4` |
| Bước 2 | `subosito/flutter-action@v2`, `flutter-version: 3.47.5`, `channel: stable`, `cache: true` |
| Bước 3 | `sudo apt-get update && sudo apt-get install -y libsqlite3-dev` — 140 tệp test dùng Drift in-memory |
| Bước 4 | `flutter pub get` (`pubspec.lock` đã trong git) |
| Bước 5 | `flutter analyze --no-fatal-infos --no-fatal-warnings` để không đỏ vì 20 cảnh báo nền |
| Bước 6 | đọc dòng `N issues found` của bước 5; **đỏ nếu N > 20**; hằng 20 ghi ngay trong workflow kèm chú thích "giảm dần, không tăng" |
| Bước 7 | `flutter test --reporter compact` |

Không chạy `build_runner` vì `.g.dart` đã commit; không build APK trong CI (Gradle quá chậm cho mỗi commit). Lần chạy đầu
là **bước dò**: test đọc đường dẫn, font `assets/fonts/Roboto-*.ttf`, tệp Android — sửa test hoặc ghi loại trừ **có lý
do**, không tắt test, không hạ ngưỡng.

### 7.2 Tài liệu

- **`docs/KIEN_TRUC_CLIENT_APP.md`** (mới, client sở hữu): tên kiến trúc; cây thư mục có chú giải và số tệp; tám luồng
  chính; bảng mối quan tâm xuyên suốt; ba chữ ký thật (một định nghĩa duy nhất, test quét, cổng + bộ chuyển); bảng 24 test
  quét sau đợt này; ưu / nhược điểm; **nợ còn lại có tên** (mục 10).
- **`src/Client-app/README.md`**: đoạn *Kiến trúc* ba câu trỏ sang tài liệu trên.
- **Đơn CAN-LAM 42** `docs/superpowers/backend/CAN-LAM/TAI_LIEU_KIEN_TRUC_CLIENT_APP.md`: xin backend sửa bảng
  `Project.md` mục 3.3, kèm câu thay thế từng dòng — *State Management: BLoC + Cubit cho 10 màn, trạng thái màn còn lại
  trong widget và stream Drift*; *Repository: interface ở tầng data, trả Entity hoặc hàng Drift tuỳ mảng*; thêm dòng
  *Test quét kiến trúc*, *Cổng nền tảng*, *Chạy nền WorkManager*. Cập nhật mục 0 của `CAN-LAM/README.md` (client được
  sửa, chốt 2026-10-05).
- `CLAUDE.md`, `PROJECT_CONTEXT.md`, `CLIENT_APP_KNOWN_GAPS.md`: mục 10.

## 8. Kiểm thử và nghiệm thu

**Mốc vào:** `flutter test` 6587/6587 (+9 skip), `flutter analyze` 20. Mỗi task chạy test của tệp liên quan; cuối mỗi việc
chạy toàn phần + analyze; ghi mốc mới vào `CLAUDE.md` theo nếp.

**Ca mới dự kiến:** test Drift cho `ThongBaoNguonDrift` và 11 phương thức mới (mỗi phương thức một ca chuyển tiếp đúng
DAO); ba test quét 22, 23, 24 (mỗi cái có ca tiền đề *phép quét thấy ít nhất một tệp*); khoảng 15 ca cho
`PhienDieuPhoiThat`; ca canh bảng phân loại của `wallet_picker_sources_test`.

**Ảnh trước / sau trên máy ảo 411 dp** (`emulator -avd FlowMoney_16G -gpu swangle`, bản debug, tài khoản 10, backend dev
chạy để dữ liệu giống nhau):

| # | Màn | Trạng thái chụp |
|---|---|---|
| 1 | Trang chủ | đầu trang, cuộn tới khối Nhận xét |
| 2 | Sổ giao dịch | kỳ tháng, có thẻ tổng |
| 3 | Thêm giao dịch | trống · đã có số tiền (bàn phím ẩn) · bảng chọn ví mở |
| 4 | Phân tích | sáu vị trí cuộn phủ chín cụm |
| 5 | Hoá đơn | danh sách · thêm · sửa · chi tiết · bảng thanh toán |
| 6 | Mục tiêu | danh sách · chi tiết |
| 7 | Ngân sách | trang chính |
| 8 | Gắn danh mục | màn gắn (tạo một giao dịch không danh mục để có dữ liệu) |
| 9 | Trung tâm thông báo | danh sách |
| 10 | Cá nhân | trang chính |

Chụp **trước bước 1** và **sau bước 3** theo cùng kịch bản chạm (script scratchpad, toạ độ lấy từ `uiautomator dump` với
`MSYS_NO_PATHCONV=1`). So bằng PIL (có sẵn, 12.3.0): hiệu từng điểm ảnh sau khi che thanh trạng thái; đếm pixel vàng thuần
`#FFFF00` phải bằng 0. Mọi khác biệt phải giải thích được bằng dữ liệu đổi theo thời gian (giờ, số ngày còn lại); không
giải thích được thì là hồi quy và phải sửa trước khi commit việc 2. OnePlus một lượt cuối khi người dùng cắm máy, chụp
cùng mười màn.

## 9. Rủi ro và hoàn tác

| Rủi ro | Ứng phó |
|---|---|
| Lớp giả không biên dịch sau khi thêm phương thức | chỉ 2 tệp thiếu `noSuchMethod` (4.6); stub tay, `flutter analyze` bắt sót |
| Thứ tự khởi động phiên lệch khi dời sang bộ điều phối | test AuthBloc hiện có giữ nguyên kỳ vọng, chạy qua `PhienDieuPhoiThat` dựng từ dịch vụ giả; test riêng cho thứ tự |
| Tách widget đổi cây, lề, thứ tự con | dời nguyên văn, giữ `Key`; ảnh trước/sau là chốt |
| Tên lớp công khai mới trùng lớp có sẵn | đã kiểm 2026-10-10: không trùng; kiểm lại bằng grep trước khi đặt tên tệp mới |
| CI đỏ vì môi trường Linux | task dò riêng; sửa test hoặc ghi loại trừ có lý do |
| `wallet_picker_sources_test` đỏ vì chỗ đọc ví mới | phân loại tay 11 chỗ trong bảng của nó |
| Trang Thêm giao dịch vẫn 1.800 dòng | ghi nợ có tên; trần ratchet trong test quét 23 chặn phình thêm |

**Hoàn tác:** bốn việc độc lập, mỗi việc một chuỗi commit riêng; hỏng việc nào revert việc ấy. Không có migration, không
có thay đổi payload, nên không có bước hoàn tác dữ liệu.

## 10. Tài liệu phải sửa

- `CLAUDE.md`: hàng mới *"Đụng vào **presentation** (trang, widget, Bloc)"* — ba test quét 22–24, `ThongBaoNguon`,
  `PhienDieuPhoi`, trần dòng và danh sách miễn trừ; mốc test / analyze mới; dòng CI.
- `docs/PROJECT_CONTEXT.md` mục 9 (cấu trúc app) và mục 14 (khối *Bịt điểm rò kiến trúc 2026-10-10*).
- `docs/CLIENT_APP_KNOWN_GAPS.md` mục 1: một mục **G88 — nợ kiến trúc còn lại sau đợt 2026-10-10**, sáu gạch đầu dòng:
  Thêm giao dịch ~1.800 dòng (cần controller, hướng B); năm tệp miễn trừ trần dòng; UI còn cầm kiểu hàng Drift, Entity chỉ
  ở 4/14 mảng; 36 dòng hạ tầng (`notification_rules`, `sync_engine`, `notification_scanner`, DAO) import `features/`;
  `core/notification` (34 tệp) là một mảng nghiệp vụ nằm trong `core`, chỗ đúng là `features/notification/{data,domain}`;
  `data/services/` ở ví, hoá đơn, danh mục thực chất là tầng application chưa có tên — nếu cần tầng thứ tư thì đổi tên
  thư mục, không thêm tầng mới (người dùng hỏi 2026-10-10, trả lời: không thêm tầng).
- `docs/KIEN_TRUC_CLIENT_APP.md`, README Client-app, đơn CAN-LAM 42 + README `CAN-LAM/` mục 0 (mục 7.2).
- Docstring `AuthBloc`, `NotificationCenterPage`, `gan_danh_muc_nguon.dart` sửa theo hình dạng mới.

## 11. Ngoài phạm vi (cố ý không làm)

- Chuyển sang Clean Architecture đúng sách: domain sở hữu interface, lớp use case, Entity cho 14 mảng.
- Cấm `presentation` import kiểu hàng Drift.
- Controller / Cubit cho Thêm giao dịch (hướng B).
- Tách `SyncEngine` 2.166 dòng, gom 36 dòng hạ tầng import feature.
- Mã hoá SQLite, logger, hỗ trợ iOS cho các tính năng Android-only.
- Sửa thẳng `Project.md` hay `docs/Rule_Project/*` (vùng chỉ đọc của backend).
- Nghiệm thu Task 10 của tự chuyển tiền chạy nền — làm sau đợt này theo quyết định 4.
