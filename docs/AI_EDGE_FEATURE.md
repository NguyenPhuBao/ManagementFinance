# AI Edge-SLM trên Client-app — tài liệu tính năng

**Trạng thái:** P0 xong (`03fe03a`) · **P2 đang làm — xong Task 0–16** (Task 14 gắn khối Nhận xét vào bốn màn, đóng A6; Task 15 thẻ + sheet kế hoạch tái phân bổ, nghiệm thu máy ảo đầu-cuối tới PostgreSQL — cả hai 2026-09-19; **Task 16** thông báo `budgetRebalance` 2026-09-20, mục **5g** `NOTIFICATION_FEATURE.md`; **còn Task 17**: nghiệm thu tổng + tài liệu bàn giao P2) ·
P1 spike chờ máy thật · P3 chưa bắt đầu.
**Spec đã duyệt:** `docs/superpowers/specs/2026-09-19-ai-edge-slm-design.md`.
**Kế hoạch:** `docs/superpowers/plans/2026-09-19-ai-edge-p0-nang-flutter.md`,
`…-p2-tang-edge-mau-cau.md`; P3 viết sau spike.
**Bản đánh giá gốc:** `docs/superpowers/backend/AI_EDGE_SLM_DANH_GIA_AP_DUNG.md` (2026-09-18, có
banner đính chính ngày 19). **Đặc tả gốc** do backend viết: `docs/AI/AI_Edge-SLM.md/Client-app.md`
(chỉ đọc; chỗ sai xin sửa qua `docs/superpowers/backend/CAN-LAM/AI_EDGE_SLM_SUA_TAI_LIEU.md`).

> Tài liệu này là **nguồn sự thật phía client** cho mảng AI. Mỗi task của kế hoạch điền vào đây
> ngay trong task, không dồn cuối. Mọi con số ghi kèm ngày đếm.

---

## 1. Tính năng này là gì, và KHÔNG phải là gì

**Một câu:** *máy tính số, mô hình kể chuyện về số.*

- **Tầng Edge tất định (P2):** mỗi màn dựng một **gói số typed** từ hàm domain **đã có** của app
  (`budgetPaceOf`, `thuNhapCua`, `tyLeTietKiem`, `phanTramSoVoi`, `duBaoCua`, `topKhoanChi`,
  `GoalEntity.progress/isBehindSchedule`, `pickHomeBudget`) → **câu nhận xét** bằng mẫu câu + **thẻ số
  liệu**. Tầng 2 trên trang Ngân sách: phát hiện **thâm hụt** → tìm **nguồn bù** → **kế hoạch chờ
  duyệt** (tick từng dòng, áp dụng mới sửa hạn mức).
- **Tầng SLM trên máy (P3):** cùng gói số, mô hình Gemma 4 qua `flutter_gemma` chỉ **diễn giải**;
  mọi con số trong câu phải có trong gói (bộ kiểm số), sai thì rơi về mẫu câu. Máy yếu, máy ảo,
  chưa tải mô hình → mẫu câu, không toast lỗi.
- **KHÔNG phải:** không học thống kê (CV, elasticity, EMA) vì dữ liệu thật chưa đủ; không bảng cache
  đặc trưng; không gửi giao dịch thô đi đâu; **không đổi schema đồng bộ, không thêm trường payload**.

## 2. Quyết định kèm lý do

| Quyết định | Lý do | Ngày |
|---|---|---|
| Nâng Flutter 3.41.5 → 3.47.5 trước mọi việc AI | `flutter_gemma` 1.8.3 đòi ≥ 3.44; bản cũ 0.13.6 thiếu Gemma 4 | 2026-09-19 |
| Bậc thang mô hình Gemma 4 E4B (≥ 8 GB RAM) → E2B (4–8 GB) → mẫu câu | Gói không chạy Gemma 3 4B; Gemma 3 1B gated (cần token HuggingFace nhúng app) nên bỏ; hai bản Gemma 4 ở `litert-community` công khai | 2026-09-19 |
| Lớp `ai_edge` **không tính**, chỉ nhận số | Bản định nghĩa thứ hai là thứ sinh bẫy A8 #8 (thu nhập gồm tiền đi vay); test quét 14 canh | 2026-09-19 |
| Nguồn dữ liệu Tầng 2 đặt ở `budget/data/`, không ở `ai_edge/` | Nó đọc bảng giao dịch để tính thu nhập 3 tháng, mà test quét 14 cấm `ai_edge/` chạm bảng ấy | 2026-09-19 |
| Thông báo tái phân bổ nhận **cả kế hoạch** đã tính | Thẻ trên màn và thông báo dùng đúng một phép tính, không thể nói hai chuyện | 2026-09-19 |
| Nguồn bù xếp theo **dư địa** | essentiality = 0,5 cho mọi danh mục (chưa có thống kê) nên C6 quy về dư địa; cờ Cố định là lớp bảo vệ duy nhất và thắng tuyệt đối | 2026-09-19 |
| Bỏ D5 (trần Σ hạn mức ≤ thu nhập × (1 − tỉ lệ tiết kiệm)) | tái phân bổ giữ tổng hạn mức không đổi nên không thể vi phạm | 2026-09-19 |
| Mỗi lượt **một** kế hoạch, cho ngân sách thâm hụt lớn nhất | người dùng duyệt từng dòng; nhiều kế hoạch là nhiều sheet chồng nhau | 2026-09-19 |
| Ngân sách nhận xét ở Trang chủ và trang Ngân sách = `pickHomeBudget` (căng nhất) | cùng luật với thẻ Ngân sách của Trang chủ, hai chỗ không nói về hai ngân sách khác nhau | 2026-09-19 |
| Tỉ lệ tiết kiệm âm đổi nhãn "Vượt thu nhập" (trị tuyệt đối) | "để dành −720,0%" không ai hiểu; "chi vượt thu nhập 720,0%" thì có | 2026-09-19 |
| Khối Nhận xét ở Ngân sách và Mục tiêu **không dựng khi danh sách rỗng**; ở Phân tích đi theo `_KhoiTong` (kỳ rỗng không dựng) | tab rỗng của hai trang đã có khung rỗng nói đúng câu "chưa có ngân sách / mục tiêu" — thêm thẻ Nhận xét nói y hệt là hai thẻ một câu. Biến thể "thiếu dữ liệu" của Stitch dành cho Trang chủ, nơi thẻ luôn hiện | 2026-09-19 |
| Trang chủ: khối bọc **ba** `StreamBuilder` riêng (`_buildNhanXet`) thay vì kéo vào `StreamBuilder` giao dịch phía trên | khối đứng cuối trang sau thẻ Mục tiêu và Ngân sách; đưa hai thẻ ấy vào trong stream giao dịch là dựng lại chúng — và mở lại stream của chúng — theo mỗi giao dịch. Thu/chi tháng qua **`thuChiThangCua`** (hàm thuần mới, `home/domain/`) mà `TheSoLieuThang` cũng đọc, tổng số dư qua `_tongTaiSan` mà thẻ tài sản cũng đọc — "số trên thẻ = số trong gói" bằng **một định nghĩa**, không phải hai vòng lặp chép tay | 2026-09-19 |
| Sheet kế hoạch có **ba lối ra, ba nghĩa**: Áp dụng = `updateBudget` từng bên + ghi phản hồi từng dòng; Bỏ qua = chỉ ghi `rejected`; vuốt/chạm nền = **không ghi gì** | "chưa quyết" không phải "từ chối": ghi `rejected` khi người dùng chỉ tắt sheet là dạy luật C3 một điều họ không nói, và kế hoạch vẫn hiện lại ở lượt sau | 2026-09-19 |
| Áp dụng đi qua `BudgetRepository.updateBudget` với `copyWith(amount:)`, **không** ghi thẳng DAO | hạn mức mới đi đúng đường đồng bộ như mọi lần sửa tay (`syncStatus` pending + `scheduleSync`); đo máy ảo: `2/2 synced`, PostgreSQL đổi ngay | 2026-09-19 |
| Thẻ **không** có nút "Tăng hạn mức ngân sách" dù Stitch vẽ; thiếu nguồn bù mà **không còn dòng nào** thì cũng không có "Xem kế hoạch" | ngoài phạm vi P2; một nút không đi đâu là nút chết (`khong_co_nut_chet_test`), và sheet rỗng là ngõ cụt | 2026-09-19 |
| Khối Nhận xét nói về ngân sách **căng nhất** (`pickHomeBudget`), thẻ kế hoạch nói về ngân sách **thâm hụt dự phóng lớn nhất** — hai thứ **có thể là hai ngân sách khác nhau** | đo máy ảo 2026-09-19: khối mở đầu "Giáo dục: đã dùng 45.000 / 50.000 (90,0%)" rồi nối "Di chuyển dự kiến vượt…". Đây là hai luật có sẵn ghép lại, không phải lỗi; muốn một ngân sách thì đổi `pickHomeBudget`, không đổi gói số | 2026-09-19 |
| Thông báo `budgetRebalance` khoá theo **tuần ISO**, không theo ngân sách | kế hoạch là hàm của dự phóng, mà dự phóng là hàm của `spent`: khoá bám vào ngân sách hay số tiền là mỗi lượt quét một thông báo mới, mà quét nổ vài lần mỗi ngày | 2026-09-20 |
| Câu thông báo **không nêu số** (tên ngân sách thì có) | con số duy nhất đúng là con số *tại lúc mở trang*; in vào thông báo là hứa một điều sai ngay khi người dùng tiêu tiếp, mà thông báo nằm lại cả tuần | 2026-09-20 |
| Kế hoạch hết nguồn bù **vẫn báo**, bằng câu khác | đó là ca đáng báo nhất (không cứu được bằng san sẻ) và thẻ trên trang vẫn hiện; nhưng `TheKeHoach` giấu nút "Xem kế hoạch" khi `dong` rỗng, nên câu mời xem là lời hứa suông | 2026-09-20 |
| Công tắc **nhóm Ngân sách** là cửa chặn phép đọc (khác `largeExpense` có ngưỡng riêng) | loại này không có công tắc riêng; dựng kế hoạch là đọc toàn bộ sổ giao dịch + một `suggestAmount` mỗi ngân sách, trả giá chừng ấy cho một kết quả bị lọc bỏ là lãng phí im lặng | 2026-09-20 |
| `KeHoachTaiPhanBoLoader` nhận **`budgets` đã nạp**, khác mọi loader khác của scanner | vòng quét vừa đọc đúng danh sách ấy cho bộ luật ngân sách; đọc lần hai là hai **ảnh chụp khác nhau** của cùng dữ liệu, và hai thông báo sinh cùng lượt sẽ nói về hai trạng thái — cả hai trông hợp lý | 2026-09-20 |
| (điền tiếp theo từng task) | | |

## 3. Vị trí mã

Theo spec mục 2.1 — cập nhật ở đây khi lệch:

```
lib/features/ai_edge/
  domain/   goi_so.dart · goi_so_{ngan_sach,phan_tich,muc_tieu,trang_chu}.dart · nhan_xet.dart
            bo_dien_giai.dart · mau_cau.dart · dau_van.dart · tai_phan_bo.dart · kiem_so.dart
            ap_dung_ke_hoach.dart
  data/     (P3) slm_runtime.dart — tệp DUY NHẤT import flutter_gemma · slm_dien_giai.dart · slm_cache.dart · mo_hinh_tai_ve.dart
  presentation/widgets/ khoi_nhan_xet.dart · the_so_lieu.dart · the_ke_hoach.dart
  presentation/pages/   ke_hoach_tai_phan_bo_sheet.dart · (P3) cai_dat_ai_page.dart
lib/features/budget/data/tai_phan_bo_nguon.dart   — nguồn dữ liệu Tầng 2 (cờ Cố định, TB 3 tháng, thu nhập 3 tháng, phản hồi cũ)
lib/core/database/tables/ai_feedback_table.dart   — bảng AiRebalancingFeedbacks (cục bộ)
lib/core/database/daos/ai_feedback_dao.dart
lib/features/ai_chat/                             — màn Trợ lý AI (P3), đọc ai_edge
```

## 4. Bẫy — đọc trước khi sửa

| # | Bẫy | Vì sao im lặng | Ca test canh |
|---|---|---|---|
| 4.1 | **Câu mẫu không được chứa chữ số ngoài gói** — nhãn kỳ (`T9 2026`), tiêu đề khoản chi (`Bữa trưa 12/09`), hằng số "30 ngày" đều bị bộ kiểm số chặn, và khi ấy P3 sẽ rơi về một câu mẫu **cũng bị chặn** | bộ kiểm số không phân biệt số "trang trí" với số bịa; câu mẫu vẫn hiện bình thường ở P2 nên không ai thấy cho tới khi SLM rơi về nó | mỗi tệp `goi_so_*_test.dart` có ca *"mẫu câu tự qua bộ kiểm số ở mọi nhánh"* |
| 4.2 | **Số của câu tóm tắt kế hoạch phải vào `soLieu` của gói Ngân sách** (`Thâm hụt`, `Nguồn bù`, `Bù được`, `Còn thiếu`) | `cauTomTat` nối vào đuôi câu nhận xét; thiếu số liệu thì bộ kiểm số chặn chính câu mẫu, cùng lý do 4.1 | `goi_so_ngan_sach_test.dart` *"có kế hoạch → … vẫn qua bộ kiểm số"* |
| 4.3 | **Bộ kiểm số phải bắt dấu âm** — `soPhanTram(-8.3)` in `-8,3%`; regex không bắt dấu thì "giảm 8,3%" và "tăng 8,3%" cùng qua | mất dấu là đảo nghĩa tăng/giảm mà bộ kiểm vẫn cho qua | `kiem_so_test.dart` *"trichSo giữ dấu âm"* |
| 4.5 | **Test của trang chứa khối phải tìm chuỗi TRONG thẻ, không trên cả trang** — khối in đúng con số của thẻ bên cạnh (đó là mục đích), nên `find.textContaining('125.000')` ở `budget_tabs_view_test` nay thấy **hai** chỗ; và khối làm trang cao hơn nên `tap` vào chip Xu hướng dưới mép 600dp của khung test **không trúng gì mà không đỏ** (chỉ một dòng Warning) | `findsOneWidget` đỏ ngay thì còn thấy; cú chạm hụt thì ca xanh nửa chừng ở khẳng định sau | `budget_tabs_view_test` bọc `find.descendant(of: Dismissible)`; `analytics_page_test` "bật một chip" gọi `ensureVisible` trước `tap` |
| 4.6 | **Thẻ mục tiêu có sẵn tràn 150px ở 411dp với font Ahem** (`goal_page.dart` hàng số tiền + phần trăm) — có từ trước Task 14, trên máy thật font thường vừa. Ca test trang Mục tiêu vì thế **không** khẳng định `takeException() == null` cho cả trang | bẫy 4.4 của `ANALYTICS_FEATURE.md`: font test rộng gấp đôi | khối có ca 411dp riêng ở `khoi_nhan_xet_test.dart` |
| 4.7 | **Ô tiền của sheet phải vẽ lại dấu chấm ngăn nghìn khi gõ** — giá trị điền sẵn là `formatSoThoi` ("210.000") còn bộ lọc chỉ-chữ-số biến số người dùng gõ thành "150000": hai kiểu hiển thị sống chung trong một ô, chỉ máy ảo thấy (`enterText` của test không nhìn) | không lỗi, không tràn; `_ChiChuSo` nay định dạng lại sau mỗi lần gõ, `onChanged` bỏ dấu chấm trước `double.parse` | `ke_hoach_sheet_test` "sửa số một dòng → tổng bù đổi" vẫn đi qua vì nó parse chuỗi đã bỏ dấu |
| 4.8 | **Tổng bù cộng cả số vượt dư địa** (để người dùng thấy con số mình vừa gõ) nhưng nút Áp dụng tắt riêng bằng `_hopLe`; bỏ vế `_hopLe` là nút bật với một dòng vượt dư địa, rồi `hanMucMoi` ném `ArgumentError` và sheet chỉ hiện dòng lỗi đỏ | bản sai có chủ ý làm đúng một ca đỏ | `ke_hoach_sheet_test` "số vượt dư địa → báo lỗi và nút Áp dụng tắt" |
| 4.9 | **Đọc SQLite máy ảo phải chép cả `-wal` và `-shm`** — tệp `flowmoney.db` chính có mốc sửa cũ hàng giờ, mọi hàng mới (kể cả bảng v24) nằm trong WAL; chép mỗi tệp chính thì `no such table: ai_rebalancing_feedbacks` trông như migration chưa chạy | cách đo: `adb exec-out "run-as com.flowmoney.flowmoney cat app_flutter/flowmoney.db"` ba lần cho ba đuôi, rồi `sqlite3` của Python | — |
| 4.4 | **Luật "đã bị cắt hai kỳ liền trước" (C3) chỉ kích hoạt khi ngân sách đã tồn tại ≥ 3 kỳ** — `recentPeriods` trả một kỳ cho ngân sách tạo tháng này, và luật im lặng | không lỗi; chỉ là trần 25 % thay vì 15 % | `tai_phan_bo_test.dart` *"đã bị cắt hai kỳ liền trước → trần 15 %"* có cả hai fixture |

## 5. Màn Stitch

| Màn | Id | Ngày | Nghiệm thu |
|---|---|---|---|
| Khối Nhận xét — bốn biến thể (+ thẻ thiếu dữ liệu) | `b396533ba02042b390377137144eedf8` | 2026-09-19 | người dùng OK cùng ngày. ⚠️ Lượt gọi trả `timeout`, màn hiện sau vài phút — không gọi lại. API ghi `DESKTOP` 2560px dù truyền `MOBILE`; thân vẽ trong cột 390px |
| Thẻ + sheet kế hoạch tái phân bổ (ba khối: thẻ tóm tắt · sheet · thẻ thiếu nguồn bù) | `f02861d93e7a46ef8183a0b27e9e03d6` | 2026-09-19 | người dùng OK cùng ngày. Stitch vẽ thêm nút "Tăng hạn mức ngân sách" ở thẻ thiếu nguồn bù — bản thi công **không** dựng nút ấy (ngoài phạm vi P2) |
| Công tắc Cố định ở màn Sửa danh mục | `a5a6ecb39151491d8e847a75d7c0a7ad` | 2026-09-19 | người dùng OK cùng ngày. Thẻ nằm giữa khối màu và khối từ khoá, chip "Chỉ lưu trên máy này" |
| (P3) Màn Cài đặt AI | | | |
| Trợ lý AI (có sẵn) | `75abffa956bb4da99a112df704f2d487` | trước 2026-09-19 | có sẵn; P3 bỏ nút ảnh/mic |

## 6. Schema v24 (2026-09-19)

| Thứ | Ở đâu | Khuôn mẫu | Ghi chú |
|---|---|---|---|
| Cột `categories.ai_co_dinh` (`BoolColumn`, mặc định `false`) | `tables/categories_table.dart` | `wallets.allow_negative` (v23, G27) | Cờ "Cố định — AI không đề xuất cắt" (luật C2). Bật ở màn Thêm/Sửa danh mục (`_TheCoDinh`, key `cong-tac-ai-co-dinh`); ẩn ở màn chỉ-từ-khoá của danh mục mặc định. Đi qua `CategoryChildDraft.aiCoDinh` → `saveChild` |
| Bảng `AiRebalancingFeedbacks` | `tables/ai_feedback_table.dart`, DAO `daos/ai_feedback_dao.dart` (`ghi`, `getAll`) | `AppNotifications` (quy tắc 9) | 11 cột, **không** `syncStatus`/`syncError`/`updatedAt`/`isDeleted`. `purgeDataForOtherAccounts` và `purgeDataForAccount` xoá theo `idaccount` (nay **mười** bảng) |

Migration `from < 24`: `addColumn` + `createTable`, không điền hàng cũ. **Test quét thứ 15**
(`test/features/ai_edge/ai_edge_cuc_bo_khong_dong_bo_test.dart`) cấm năm chuỗi (`aiCoDinh`,
`ai_co_dinh`, `AiRebalancingFeedback`, `ai_rebalancing_feedbacks`, `aiRebalancingFeedbacks`) trong
`sync_engine.dart`, `sync_payload_normalizer.dart`, `sync_models.dart` và trong hợp đồng payload —
**không** bỏ dòng chú thích (khác test 14): một chú thích nhắc tên cột ở đường đồng bộ là dấu hiệu ai
đó định đưa nó vào. Bản sai có chủ ý (`final String banSaiCoChuY = 'ai_co_dinh';` cuối
`sync_engine.dart`) làm nó đỏ đúng dòng ngày 2026-09-19. `sync_payload_contract_test.dart` không đổi.

⚠️ **Hai bẫy của lượt này**: (1) data class Drift `Category` đòi thêm tham số bắt buộc → **7** chỗ
dựng `Category(...)` bằng tay trong test phải thêm `aiCoDinh: false` (cùng việc cơ học của G27);
(2) `categoryDao.insert` là **`insertOrReplace`** — `saveChild` không gán `aiCoDinh` thì mỗi lần
sửa tên danh mục lặng lẽ **tắt cờ**; có ca test canh (*"sửa tên mà vẫn truyền cờ bật → cờ còn"*).

## 7. Kiểm thử

| Tệp | Ca | Canh gì | Ngày |
|---|---|---|---|
| `test/features/ai_edge/domain/goi_so_test.dart` | 3 | định dạng số liệu: `đ` có cách, phần trăm 1 chữ số thập phân (G2), số âm giữ dấu | 2026-09-19 |
| `test/features/ai_edge/domain/dau_van_test.dart` | 4 | dấu vân đổi theo số và màn, **không** đổi theo thứ tự | 2026-09-19 |
| `test/features/ai_edge/ai_edge_khong_tinh_test.dart` | 1 | **test quét `lib/` thứ 14** — `ai_edge/` không chứa `'thu'`/`'chi'`/`'transfer'`/`walletId`/`transactionDao`/`.type ==`/`amount <`/`amount >`; bỏ dòng chú thích. Bản sai có chủ ý (`final String banSaiCoChuY = 'thu';` ở `goi_so.dart:81`) làm nó đỏ đúng dòng ngày 2026-09-19, gỡ → xanh | 2026-09-19 |
| `test/features/ai_edge/domain/kiem_so_test.dart` | 9 | bộ kiểm số: câu bịa bị chặn, ±0,5 đ, ±0,05 điểm %, **dấu âm**, loại số phải khớp | 2026-09-19 |
| `test/features/ai_edge/domain/goi_so_ngan_sach_test.dart` | 7 | gói Ngân sách (căng nhất qua `pickHomeBudget`), câu vượt/chưa vượt, **mẫu câu tự qua bộ kiểm số**, có kế hoạch vẫn qua | 2026-09-19 |
| `test/features/ai_edge/domain/goi_so_phan_tich_test.dart` | 10 | gói Phân tích: nền 0 không in %, tỉ lệ âm → "vượt thu nhập", cam kết, khoản lớn nhất không in tiêu đề | 2026-09-19 |
| `test/features/ai_edge/domain/goi_so_muc_tieu_test.dart` | 6 | gói Mục tiêu: chậm/đúng/quá hạn, phần tử đầu của đang theo đuổi | 2026-09-19 |
| `test/features/ai_edge/domain/goi_so_trang_chu_test.dart` | 6 | gói Trang chủ nhận số của trang; số 0 không mang dấu; ngân sách căng nhất | 2026-09-19 |
| `test/features/ai_edge/domain/tai_phan_bo_test.dart` | 15 | Tầng 2: dự phóng, ngưỡng kép, nguồn bù theo dư địa, cờ Cố định, dư địa ≥ 100k, trần 15 % (cần ≥ 3 kỳ), làm tròn, ngưỡng có nghĩa, cạn nguồn, hụt lớn nhất, `categoryId` null | 2026-09-19 |
| `test/core/database/schema_v24_test.dart` | 6 | v24: cột `ai_co_dinh`, bảng phản hồi không cột đồng bộ, DAO, hai hàm purge | 2026-09-19 |
| `test/features/ai_edge/ai_edge_cuc_bo_khong_dong_bo_test.dart` | 2 | **test quét thứ 15** — hai thứ v24 không lọt vào ba tệp đồng bộ và hợp đồng payload; bản sai có chủ ý đỏ đúng dòng | 2026-09-19 |
| `test/features/category/category_ai_co_dinh_test.dart` | 7 | cờ Cố định: `saveChild` ghi/giữ cờ (`insertOrReplace`), công tắc ở màn Sửa danh mục (cuộn tới bằng `scrollUntilVisible` — ListView lười dựng), ẩn ở màn chỉ-từ-khoá, 411dp không tràn | 2026-09-19 |
| `test/features/ai_edge/presentation/khoi_nhan_xet_test.dart` | 7 | khối Nhận xét: mẫu câu hiện ngay, câu mô hình thay sau + nhãn AI, thiếu dữ liệu không thẻ, 200 ký tự không tràn, lỗi bộ diễn giải giữ mẫu, viền cảnh báo, nền tối | 2026-09-19 |
| `test/features/budget/data/tai_phan_bo_nguon_test.dart` | 5 | nguồn Tầng 2: cờ Cố định bỏ hàng xoá mềm, thu nhập 3 tháng **không đếm đi vay**, TB 3 tháng theo `budget.id`, phản hồi cũ | 2026-09-19 |
| `test/features/budget/budget_cubit_ke_hoach_test.dart` | 5 | `BudgetCubit`: không nguồn → đồng bộ như cũ; có nguồn → kế hoạch; cờ Cố định; nguồn lỗi vẫn `BudgetLoaded`; lượt nạp chậm không đè lượt mới | 2026-09-19 |
| `test/features/budget/budget_khoi_nhan_xet_test.dart` | 6 | Task 14 — trang Ngân sách: một khối, câu đúng số của state (33,3 %, còn 16 ngày), nói về ngân sách **căng nhất**, có `keHoach` thì nối câu tóm tắt (tìm **trong khối**, vì thẻ cũng in câu ấy), rỗng thì không dựng. Task 15: +2 ca — thẻ đứng dưới khối và chạm "Xem kế hoạch" gọi `onXemKeHoach` với **đúng** kế hoạch của state; không có callback thì không nút | 2026-09-19 |
| `test/features/analytics/analytics_page_test.dart` (+2) | 2 | Task 14 — trang Phân tích: khối sau "Số dư còn lại" trước Xu hướng, câu "tăng 25,0% so với kỳ trước"; kỳ rỗng không dựng. Đặt trong tệp có sẵn để dùng lại helper `_tk` | 2026-09-19 |
| `test/features/goal/goal_khoi_nhan_xet_test.dart` | 2 | Task 14 — trang Mục tiêu (dựng `GoalPage` thật): câu "MuaXe: 55,0%, còn thiếu 900.000 đ"; chỉ có mục tiêu hoàn thành thì không dựng. ⚠️ tháo cây ở **cuối thân test**, không qua `addTearDown` (khung kiểm "Pending timers" trước tearDown) | 2026-09-19 |
| `test/features/home/home_khoi_nhan_xet_test.dart` | 2 | Task 14 — Trang chủ (quét nguồn, cùng lối `trang_chu_gon_test`): hết "Insight AI"/"Thêm thêm"/`_buildInsightCard`; có `KhoiNhanXet(` + `GoiSoTrangChu.tu(` + `nenToi: true` | 2026-09-19 |

| `test/features/ai_edge/domain/ap_dung_ke_hoach_test.dart` | 9 | Task 15 — `hanMucMoi`: hai nguồn trừ / thâm hụt cộng Σ, **Σ hạn mức không đổi** (bản sai "trừ thay vì cộng" làm 3 ca đỏ), rỗng khi không chọn, `ArgumentError` khi âm/vượt dư địa, id lạ bỏ qua; `phanHoiTu`: accepted/modified/rejected, `boQua` → mọi dòng rejected, hàng mang đủ khoá C3 và kỳ **của nguồn** | 2026-09-19 |
| `test/features/ai_edge/presentation/the_ke_hoach_test.dart` | 4 | Task 15 — thẻ: biến thể đủ nguồn bù (chip "Dự kiến vượt", `cauTomTat`, "Nguồn bù: …", nút gọi `onXem`), thiếu một phần (nhãn đỏ, chip số thiếu, dòng gợi ý, link phân tích), không nguồn nào → không nút, không `onXemPhanTich` → không link; **không** có "Tăng hạn mức" | 2026-09-19 |
| `test/features/ai_edge/presentation/ke_hoach_sheet_test.dart` | 9 | Task 15 — sheet thật qua `showModalBottomSheet`: tiêu đề/thâm hụt/hai dòng/100 %, cao **cố định 70 %**, bỏ tick và sửa số đổi tổng bù, ô tiền có `GioiHanSoChuSo`, Áp dụng → 2 `updateBudget` đúng hạn mức + 2 hàng (`modified`, `rejected`) + đóng, Bỏ qua → 0 update + 2 `rejected`, chạm nền → **0 hàng**, không tick → nút tắt, vượt dư địa → lỗi + nút tắt (bản sai bỏ `_hopLe` làm đúng ca này đỏ) | 2026-09-19 |

| `test/core/notification/notification_rules_rebalance_test.dart` | 13 | Task 16 — luật `budgetRebalance`: kế hoạch `null` thì im; khoá **chỉ có tuần ISO** (cùng tuần khác ngày → cùng khoá; sang tuần → khác; 31/12/2025 → `2026-W01`); `body` **không chứa chữ số** nhưng có tên; hết nguồn bù → câu khác, không mời "Xem kế hoạch"; nhóm `budget` và **chịu** công tắc; `silenceBefore`; cold start → `/budget` | 2026-09-20 |
| `test/core/notification/notification_scanner_test.dart` (+4) | 4 | Task 16 — **chỗ nối**: có kế hoạch → một hàng; hai lượt cùng tuần → một hàng; **loader không được gọi** khi tắt nhóm Ngân sách hoặc không có ngân sách — hai ca này **xanh ngay từ đầu** nên đã kiểm bằng bản sai có chủ ý (bỏ cả hai điều kiện → cả hai đỏ) | 2026-09-20 |
| `test/core/notification/notification_deeplink_test.dart` (sửa) | — | Task 16 — phép canh "đủ mọi loại" **tự đỏ** khi enum thêm giá trị: phải dựng thêm `keHoachTaiPhanBo` cho `tatCaUngVien()`. Đúng cách lưới ấy sinh ra để làm việc | 2026-09-20 |

### 7.3 Nghiệm thu máy ảo Task 16 (2026-09-20, `emulator-5554`, tài khoản 10, backend dev chạy)

Trạng thái đầu: **không** ngân sách nào thâm hụt đủ ngưỡng kép — trang Ngân sách
không có thẻ "Đề xuất cân đối", trung tâm thông báo không có hàng nào. Đúng: Task 15
đã áp dụng kế hoạch hôm trước nên thâm hụt đã được cân đối.

Tạo thâm hụt **thật** qua giao diện: một khoản chi **50.000 đ / Di chuyển** (ngân sách
305.000 / 450.000, đã qua 19/30 ngày → dự phóng 355.000 × 30/19 = 560.526, thâm hụt
**110.526 đ**). Kết quả đo được:

| Đo | Kết quả |
|---|---|
| Lượt quét sau khi đồng bộ xong | `[NotificationScanner] Quét xong cho tài khoản 10 — **1 hàng mới**` |
| Thẻ trong trung tâm thông báo | *"Đề xuất cân đối ngân sách — Di chuyển dự kiến vượt hạn mức. Xem kế hoạch bớt từ ngân sách khác. — Vừa xong"*, viền đỏ (warning), icon ngân sách. **Không một chữ số**, có tên ngân sách |
| Chạm vào thông báo | mở **đúng** trang Ngân sách, có nút Back (route chồng, đúng nhóm D) |
| Thẻ trên trang sau khi tới | *"ĐỀ XUẤT CÂN ĐỐI · Dự kiến vượt — Di chuyển dự kiến vượt **110.526 đ**. Bớt từ 1 ngân sách khác? · Nguồn bù: Mua sắm"* — **cùng một ngân sách** với thông báo, đúng cam kết một định nghĩa |
| Lượt quét thứ hai (đưa app vào nền rồi quay lại) | `— **0 hàng mới**`: khoá tuần chống trùng làm việc |
| Chip **Ngân sách** của trung tâm | lọc ra đủ **bốn** loại của nhóm: Đề xuất cân đối · Đã vượt · Sắp vượt · Khoản chi lớn |
| Tràn bố cục | **0 pixel vàng** trên cả **12** ảnh (`t16_01–12`, scratchpad) |
| Logcat | 0 exception của app (hai dòng `BluetoothPowerStatsCollector` là của Android) |

⚠️ Khoản chi 50.000 đ ấy **để lại** trên tài khoản 10 (đã đẩy lên PostgreSQL): xóa đi là
thâm hụt biến mất và Task 17 không nghiệm thu lại được trạng thái này.

### 7.2 Nghiệm thu máy ảo Task 15 (2026-09-19 tối, `emulator-5554`, tài khoản 10, backend dev chạy)

Dữ liệu dựng bằng giao diện: ba ngân sách tháng **Di chuyển 300.000** (đã chi 305.000 — dự phóng
508.333 → thâm hụt **208.333**), **Mua sắm 1.000.000** (chi 60.000 → dư địa 900.000), **Ăn uống
500.000**. Ảnh ở scratchpad phiên, **0 pixel vàng** ở cả năm: `t15_b.png` (thẻ biến thể **thiếu
nguồn bù** khi mới chỉ có Di chuyển: "-208.333 đ", dòng "Không ngân sách nào còn dư địa…", link
"Xem phân tích chi tiêu"), `t15_the.png` (đủ nguồn bù: "Nguồn bù: Mua sắm" + "Xem kế hoạch"),
`t15_sheet.png` (một dòng, đề xuất **210.000** = làm tròn 10k của 208.333, "100% CÂN ĐỐI"),
`t15_sheet_edit2.png` (sửa thành 150.000 → "72% CÂN ĐỐI"), `t15_after.png` (sau Áp dụng).

Đo đầu-cuối sau Áp dụng: logcat `[SyncEngine] Sending batch 2 operations` → `2/2 synced`;
PostgreSQL `budget.TotalAmount`: Di chuyển **450.000**, Mua sắm **850.000** (Σ không đổi); SQLite
máy ảo `ai_rebalancing_feedbacks` có đúng **một** hàng `modified`, `suggested 210000`, `actual
150000`, kỳ 01/09–01/10 (đọc qua WAL — bẫy 4.9). Trang tính lại ngay: kế hoạch mới cho phần còn
thiếu **58.333** (150.000 < 208.333, đúng nghĩa "bù một phần").

### 7.1 Nghiệm thu máy ảo Task 14 (2026-09-19, `emulator-5554`, AVD `FlowMoney_16G`, tài khoản 10)

Bốn ảnh ở scratchpad phiên: `t14_home_bottom.png`, `t14_analytics.png`, `t14_goal.png`,
`t14_budget.png` — **0 pixel vàng thuần** ở cả bốn (đếm bằng PIL). Khối hiện đúng chỗ ở bốn màn và
câu chép **đúng số của thẻ bên cạnh**: Ngân sách *"Giáo dục: đã dùng 45.000 đ / 50.000 đ (90,0%), còn
12 ngày — nên chi tối đa 417 đ mỗi ngày"* khớp dòng "Nên chi 417 đ/ngày · còn 12 ngày" của thẻ; Mục
tiêu *"MuaXe: 55,0%, còn thiếu 899.000 đ, còn 586 ngày; đúng kế hoạch"*; Trang chủ nền tối *"Tháng
này thu 15.145.000 đ, chi 2.091.000 đ, còn lại 13.054.000 đ. Ngân sách Giáo dục đã dùng 90,0%"*.

⚠️ **Hai chỗ lệch nhìn thấy được, cả hai có từ trước và cố ý không vá trong Task 14:**

1. Trang chủ nói thu **15.145.000 đ**, trang Phân tích nói **15.135.000 đ** (chênh 10.000). Thẻ số
   liệu tháng của Trang chủ **cộng thô theo `type`** (kể cả khoản điều chỉnh số dư / mở sổ), còn Phân
   tích đi qua `khoanVaoThongKe`. Khối Nhận xét ở mỗi trang **chép đúng số của trang ấy** — đó là
   điều kiện 12 — nên hai khối nói hai số là *hệ quả* của hai thẻ đã nói hai số từ trước. Muốn hai
   trang khớp thì đổi `thuChiThangCua` (một chỗ), không đổi gói số.
2. Thẻ "Số dư còn lại" in "Để dành **86%**" (làm tròn nguyên) còn khối in "**85,7%**" (luật G2,
   một chữ số thập phân). Cùng một `tyLeTietKiem`, hai cách làm tròn.

## 8. Bảng đo P1 / P3

(để trống ở P2; P1 điền: máy, mô hình, thời gian nạp, câu đầu, câu tiếp, RAM đỉnh, 10 câu liên
tiếp, chất lượng tiếng Việt trên 3 gói số thật)
