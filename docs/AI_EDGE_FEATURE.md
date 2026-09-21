# AI Edge-SLM trên Client-app — tài liệu tính năng

**Trạng thái:** P0 xong (`03fe03a`) · **P1 spike XONG 2026-09-20** (đo trên OnePlus 13R / Snapdragon 8 Gen 3 — bảng đo mục **8**; người dùng chốt **E2B cho mọi máy**) · **P2 XONG — trọn 17 task** (Task 14 gắn khối Nhận xét vào bốn màn, đóng A6; Task 15 thẻ + sheet kế hoạch tái phân bổ, nghiệm thu máy ảo đầu-cuối tới PostgreSQL — cả hai 2026-09-19; **Task 16** thông báo `budgetRebalance` 2026-09-20, mục **5g** `NOTIFICATION_FEATURE.md`; **Task 17** nghiệm thu tổng + tài liệu bàn giao 2026-09-20, mục **7.4**) ·
**P3: kế hoạch đã viết, CHƯA thi công** — điều kiện của nó (P1 đạt, P2 xong) nay đã đủ.
**Spec đã duyệt:** `docs/superpowers/specs/2026-09-19-ai-edge-slm-design.md` — ⚠️ đọc **mục 8
dưới đây trước mục 4.1 của spec**: P1 đã lật bậc thang ở đó, và spec mục 4.1 nay mang banner 🛑.
**Kế hoạch:** `docs/superpowers/plans/2026-09-19-ai-edge-p0-nang-flutter.md`,
`…-p2-tang-edge-mau-cau.md`, `…/2026-09-20-ai-edge-p3-cam-slm.md` (10 task).
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
  ⚠️ **Vế "không học thống kê" là ảnh chụp của P0–P3, và người dùng đã chốt ngược lại ngày
  2026-09-20**: bốn việc học ở **tầng số** sẽ làm (mục **11.4**), với điều kiện mỗi luật có **ngưỡng
  mẫu tối thiểu, dưới ngưỡng thì im**. Vế **không huấn luyện mô hình ngôn ngữ** thì vẫn đứng nguyên và
  có lý lẽ đầy đủ ở mục **10.3** — hai chuyện khác hẳn nhau, đừng gộp.

## 2. Quyết định kèm lý do

| Quyết định | Lý do | Ngày |
|---|---|---|
| Nâng Flutter 3.41.5 → 3.47.5 trước mọi việc AI | `flutter_gemma` 1.8.3 đòi ≥ 3.44; bản cũ 0.13.6 thiếu Gemma 4 | 2026-09-19 |
| ~~Bậc thang mô hình Gemma 4 E4B (≥ 8 GB RAM) → E2B (4–8 GB) → mẫu câu~~ 🛑 **ĐÃ THAY 2026-09-20**, xem hàng dưới | Gói không chạy Gemma 3 4B; Gemma 3 1B gated (cần token HuggingFace nhúng app) nên bỏ; hai bản Gemma 4 ở `litert-community` công khai. ⚠️ Vế *"hai bản Gemma 4 công khai"* vẫn đúng; vế **bậc thang theo RAM** thì P1 lật (mục 8.5) | 2026-09-19 |
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
| **E2B cho mọi máy; E4B bỏ hẳn** — thay bậc thang theo RAM của spec mục 4.1 | P1 đo trên máy thật: trên GPU hai mô hình tốn RAM **bằng nhau** (0,96 vs 0,97 GB) nên ngưỡng RAM không phân biệt được gì; E2B nhanh **gấp đôi**, tệp nhẹ hơn **1 GB**, tiếng Việt không thua. Mục **8.5** | 2026-09-20 |
| Chỉ tải tệp `‹model›.litertlm` chuẩn, **không** dùng biến thể `-gpu.litertlm` | bản `-gpu` **không nạp được** trên engine FFI Android dù tệp nguyên vẹn, và lỗi nó ném (*"Model may be invalid"*) dẫn người đọc đi sai hướng. Mục **8.2** | 2026-09-20 |
| P3 bắt máy không chạy được bằng **`try/catch` quanh `getActiveModel`**, không tự đọc ABI | gói tự nêu tên ABI trong thông báo lỗi; và lỗi ném ở bước **nạp** chứ không ở `install()`. Mục **8.3** | 2026-09-20 |
| Thêm **`flutter_gemma_litertlm`** cạnh `flutter_gemma` | core **không kèm engine nào**; thiếu nó thì `getActiveModel()` ném lỗi "add the engine package" | 2026-09-20 |
| **Lối B cho P3**: mô hình phục vụ **một chỗ duy nhất** — màn Trợ lý AI; bốn khối Nhận xét **giữ mẫu câu** | P1 đo: câu mô hình ở khối Nhận xét **gần bằng** mẫu câu (khác giọng văn, không khác thông tin — mẫu câu còn gọn hơn), mà giá là **2,3 s mỗi khối + 2,41 GB** tải. Mô hình chỉ hơn hẳn ở **hỏi đáp tự do**. Thi hành bằng cách **không đăng ký `BoDienGiai`** vào DI — đảo ngược bằng một commit | 2026-09-21 |
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
| 4.10 | **Đếm "pixel vàng" để tìm tràn bố cục phải bắt VÀNG THUẦN `#FFFF00`, không phải một dải vàng** — sọc cảnh báo của Flutter đúng màu ấy, còn một dải rộng sẽ bắt luôn emoji 💡 của khối Nhận xét (529 px), biểu tượng ⚠ của khối Dự báo (1030 px) và **ô cam trong bảng chọn màu danh mục** (4111 px, màu `(245,158,11)`) | hỏng theo **hai chiều**: dải rộng cho dương tính giả nên người đo đi tìm một cái tràn không tồn tại; mà nếu quen với những con số ấy thì một sọc tràn thật cũng chìm vào chúng. Đo 2026-09-20: 21 ảnh, dải rộng cho 6305 px, vàng thuần cho **0** | — |
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

### 7.4 Nghiệm thu TỔNG — Task 17 (2026-09-20, `emulator-5554`, tài khoản 10, backend dev chạy)

Lượt cuối của P2: đi qua **sáu** chỗ người dùng gặp tầng Edge, trên bản APK có đủ
Task 0–16.

| Màn | Đo được |
|---|---|
| **Trang chủ** (khối nền tối) | *"Tháng này thu 15.145.000 đ, chi 2.141.000 đ, còn lại 13.004.000 đ. Ngân sách Giáo dục đã dùng 90,0%."* — năm thẻ số liệu, mọi con số **khớp thẻ ngay phía trên** |
| **Phân tích** | khối đứng ngay sau "Số dư còn lại": *"Kỳ này chi 2.141.000 đ; để dành 85,4% thu nhập. Một tháng tới có 14 cam kết phải trả, tổng 665.000 đ. Khoản chi lớn nhất 800.000 đ."* |
| **Mục tiêu** | *"MuaXe: 55,0%, còn thiếu 899.000 đ, còn 585 ngày; đúng kế hoạch."* — khớp thẻ mục tiêu đầu danh sách |
| **Ngân sách** | khối Nhận xét (ngân sách **căng nhất** = Giáo dục 90,0%) + thẻ **Đề xuất cân đối** (ngân sách **thâm hụt lớn nhất** = Di chuyển) — hai ngân sách **khác nhau**, đúng như mục 2 ghi |
| **Sheet kế hoạch** | *"Kế hoạch cân đối ngân sách · Di chuyển · thâm hụt dự kiến 110.526 đ"*, một dòng *Mua sắm · dư địa 755.263 đ · −120.000*, **"Tổng bù: 120.000 đ / 110.526 đ · 100% CÂN ĐỐI"**. Vuốt tắt → **không ghi phản hồi nào** (lối ra thứ ba) |
| **Sửa danh mục** | công tắc *"Cố định — AI không đề xuất cắt"* kèm chip **"Chỉ lưu trên máy này"** và câu giải thích; tắt sẵn |

Cộng **thông báo `budgetRebalance`** đã nghiệm thu riêng ở mục 7.3.

**Tràn bố cục: 0.** Đo trên **21** ảnh (`t16_01–12`, `t17_01–09`, scratchpad) — 0
pixel vàng thuần `#FFFF00`. ⚠️ Một dải vàng rộng cho **6305** px trên cùng bộ ảnh,
toàn bộ là emoji 💡, biểu tượng ⚠ và ô cam của bảng chọn màu danh mục — xem bẫy
**4.10**. **Logcat: 0** dòng lỗi/cảnh báo của `flutter`.

**Trọn bộ test 3106/3106 pass, 1 skip** (3 phút 49 giây, chạy song song với
`flutter build apk`); `flutter analyze` **26 issue, 0 error** — mức nền.

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

## 8. Bảng đo P1 (2026-09-20) — ✅ ĐÃ ĐO TRÊN MÁY THẬT

**Máy:** OnePlus 13R `CPH2691`, SoC **SM8650 = Snapdragon 8 Gen 3** (QTI), `arm64-v8a`,
RAM **10,95 GB** (`MemTotal` 11.483.184 kB), Android **16** / SDK 36, trống 110 GB.
Pin 31–34 %, **đang sạc**; nhiệt CPU nghỉ ~35 °C.

**Cách đo:** app spike riêng (`D:/flowmoney-spike`, **mã vứt đi, không commit**),
`flutter_gemma 1.8.3` + `flutter_gemma_litertlm 1.7.0`, `maxTokens: 1024`,
`temperature: 0.2`. Prompt = prompt hệ thống **nguyên văn** mục 3.2 đặc tả gốc + **hai** ví
dụ few-shot + gói số dạng `Nhãn: chuỗi`. Ba gói số là số **thật** của tài khoản 10 (đúng
những con số khối Nhận xét đang hiện). RAM đỉnh = `TOTAL PSS` của `dumpsys meminfo`, lấy
mẫu 3 s/lần trong suốt lượt chạy.

### 8.1 Bốn tổ hợp chạy được

| Mô hình | Tệp | Backend | Nạp | Ba gói (ms) | 10 câu, TB | Câu 1 → câu 10 | **RAM đỉnh** |
|---|---|---|---|---|---|---|---|
| **E4B** | `gemma-4-E4B-it.litertlm` 3,41 GB | **GPU** | 9.944 ms | 5.425 / 5.097 / 2.734 | **4.668 ms** | 4.596 → 4.678 (**+1,8 %**) | **0,97 GB** |
| E4B | nt | CPU | 10.499 ms | 8.226 / 7.968 / 5.848 | 12.675 ms | 12.704 → 8.943 (−29,6 %) | **3,27 GB** |
| **E2B** | `gemma-4-E2B-it.litertlm` 2,41 GB | **GPU** | 9.131 ms | 3.486 / 2.293 / 1.383 | **2.329 ms** | 2.335 → 2.279 (**−2,4 %**) | **0,96 GB** |
| E2B | nt | CPU | **4.516 ms** | 3.839 / 3.420 / 2.336 | 3.313 ms | 3.288 → 3.355 (+2,0 %) | 1,73 GB |
| E2B | nt | **NPU** | 8.626 ms | 14.542 / 8.821 / 6.049 | 8.430 ms | 8.837 → 8.438 (−4,5 %) | **3,24 GB** |

⚠️ **Hàng NPU đo ngày 2026-09-21 (chặng 0.1), và nó KHÔNG phải một cải thiện** — NPU
**chậm hơn GPU 3,6 lần** (8.430 ms so với 2.329 ms) và tốn RAM **gấp 3,4 lần** (3,24 GB so
với 0,96 GB), tức tệ hơn **cả CPU** ở cả hai mặt. Đây là hàng đo để **đóng một câu hỏi**,
không phải để đổi bậc thang: bậc thang mục 8.5 **giữ nguyên**, không thêm nhánh NPU.

Ba điều đi kèm, đọc trước khi có ai định thử lại NPU:

1. **Nó CHẠY THẬT, không phải rơi về CPU.** Nhật ký cho thấy gói tự giải nén bộ thư viện
   Qualcomm (`libQnnHtp.so`, `libQnnHtpV73/V75/V79/V81*`) vào `code_cache/npu_libs` rồi
   đăng ký `NpuAccelerator`. Nên con số chậm là con số **của NPU**, không phải của một
   lần rơi nhánh âm thầm.
2. ⚠️ **Lần đăng ký ĐẦU thất bại, lần thứ hai mới được** —
   `npu_registry.cc:34] NPU accelerator could not be loaded and registered:
   kLiteRtStatusErrorInvalidArgument`, rồi ngay sau đó `npu_registry.cc:30] NPU
   accelerator registered.` Ai đọc logcat mà dừng ở dòng cảnh báo đầu sẽ kết luận nhầm là
   NPU không chạy được.
3. ⚠️ **NPU bỏ qua tham số lấy mẫu.** Chính gói in ra: *"the NPU executor samples greedily
   and never reads them — output is deterministic argmax"*. Tức `temperature` của spec
   **không có tác dụng** trên nhánh này — một lý do nữa để không dùng nó.

**Nhiệt: không thành vấn đề.** Sau 13 câu liên tiếp, CPU đi từ 35,2 °C lên **37,1 °C**, pin
giữ 30,4 °C. Ba trong bốn tổ hợp có câu 10 **nhanh bằng hoặc hơn** câu 1 — không thấy
throttle. Riêng E4B/CPU dao động rất mạnh (8.508 – 21.723 ms, ±150 %) nhưng theo chiều
*nhanh dần*, tức là warm-up chứ không phải nóng lên.

### 8.2 ⚠️ Tệp `-gpu.litertlm` KHÔNG nạp được, dù tệp nguyên vẹn

`gemma-4-E4B-it-gpu.litertlm` (2,77 GB) ném `BackendInitException: all FFI backends
failed … Failed to create engine. Model may be invalid` với **cả hai** backend. Kích thước
tệp khớp từng byte ở cả ba nơi (máy tính → `/sdcard` → thư mục app: 2.969.059.328), nên
**không phải hỏng khi chép**. Biến thể `-gpu` của litert-community dành cho đường khác
(web/desktop), không phải engine FFI Android.

**Kết luận thực dụng: chỉ tải bản `‹model›.litertlm` chuẩn.** Bản `-gpu` nhẹ hơn 0,6 GB
nhưng vô dụng, và thông báo lỗi của nó (*"Model may be invalid"*) dẫn người đọc đi sai
hướng — sẽ mất hàng giờ kiểm tra tải hỏng.

### 8.3 ✅ Máy ảo x86_64 rơi về mẫu câu — và lỗi ĐỌC ĐƯỢC

Cùng APK, cùng tệp mô hình, trên `emulator-5554` (`x86_64`):

```
Unsupported operation: flutter_gemma .litertlm models require an arm64-v8a
Android device (got android_x64). Use a `.task` MediaPipe model on this ABI
or run on an arm64-v8a device / Apple Silicon emulator.
```

Gói tự nêu tên ABI, nên **P3 không cần tự đọc ABI**: một `try/catch` quanh
`getActiveModel` là đủ để rơi về mẫu câu. Lỗi ném ở bước **nạp**, sau khi `install()` đã
thành công (265 ms) — tức `install()` **không** phải chỗ phát hiện máy không chạy được.

### 8.4 Chất lượng tiếng Việt — cả hai mô hình đều đạt

Câu sinh ra (gói Ngân sách, số thật):

- **E4B/GPU:** *"Giáo dục đã chi 45.000 đ / 50.000 đ (90,0%), còn 11 ngày, mỗi ngày 455 đ,
  thâm hụt 110.526 đ, nguồn bù 1."*
- **E2B/GPU:** *"Ngân sách Giáo dục đã chi 45.000 đ trên hạn mức 50.000 đ (90,0%), còn 11
  ngày, với mức chi mỗi ngày là 455 đ và thâm hụt 110.526 đ."*

Ngữ pháp đúng, giọng tự nhiên, **mọi con số lấy từ gói** — không thấy bịa số ở lượt nào
trong 52 câu đã sinh. E2B thậm chí đọc trôi hơn (*"trên hạn mức"*, *"với mức chi mỗi ngày
là"*) trong khi E4B liệt kê khô hơn.

⚠️ **Cả hai đều mắc cùng một lỗi, và đó là lỗi của PROMPT chứ không của mô hình:** chúng
**đọc hết mọi dòng** trong gói, kể cả dòng vô nghĩa với người đọc — E4B nói *"nguồn bù 1"*.
P3 phải hoặc lọc gói trước khi bơm vào prompt, hoặc nói rõ trong prompt là được phép bỏ
qua dòng không đáng nhắc.

### 8.5 Điều P1 lật của bản thiết kế

| Giả định trong spec (mục 4.1) | Phép đo nói gì |
|---|---|
| Bậc thang theo **RAM thiết bị**: ≥ 8 GB → E4B, 4–8 GB → E2B | RAM đỉnh **không** phụ thuộc mô hình mà phụ thuộc **backend**: trên GPU, E4B tốn **0,97 GB** còn E2B **0,96 GB** — bằng nhau. Ngưỡng 8 GB dựa trên con số CPU (3,27 GB) và **quá chặt** cho đường GPU |
| E4B ≈ 4,3 GB, E2B ≈ 2,4 GB | tệp chuẩn: E4B **3,41 GB**, E2B **2,41 GB** (bản `-gpu` nhẹ hơn nhưng **không dùng được**, xem 8.2) |
| `flutter_gemma` là gói duy nhất cần thêm | core **không kèm engine nào**; `.litertlm` đòi thêm **`flutter_gemma_litertlm`** |
| Ngưỡng rơi về mẫu câu: RAM < 4 GB hoặc không arm64 | vế "không arm64" đúng và **gói tự báo** (8.3). Vế RAM thì đo được là rộng rãi hơn nhiều so với giả định |

### ✅ BẬC THANG MỚI — người dùng chốt 2026-09-20

**E2B cho MỌI máy; E4B bỏ hẳn.**

| Điều kiện | Mô hình | Backend |
|---|---|---|
| arm64-v8a, GPU dựng được | **E2B** | GPU |
| arm64-v8a, GPU hỏng, RAM ≥ 4 GB | E2B | CPU |
| còn lại (x86_64, RAM thấp, chưa tải, pin yếu, lỗi runtime) | **mẫu câu** | — |

Lý lẽ: E2B/GPU **nhanh gấp đôi** E4B/GPU (2,3 s vs 4,7 s), tốn RAM **bằng nhau**, tệp nhẹ
hơn **1 GB**, và chất lượng tiếng Việt trên đúng việc này — diễn giải một gói số đã tính
sẵn — **không thua**. E4B chỉ hơn nếu về sau cần suy luận nhiều bước, thứ kiến trúc
"máy tính số, mô hình kể chuyện" cố ý không giao cho mô hình.

⚠️ **Spec đã duyệt (mục 4.1) vẫn ghi bậc thang CŨ.** Chính spec ấy nói *"P1 có thể
đổi con số ngưỡng; bảng này là điểm xuất phát"* — và P1 đã đổi. Ai đọc spec mà không
đọc mục này sẽ lặng lẽ cài lại E4B.

### 8.6 ⚠️ Bốn cái bẫy của việc đưa mô hình lên máy

Không cái nào là lỗi Flutter, nhưng cái thứ hai tốn nhiều thời gian nhất:

1. `/data/local/tmp/models` — adb ghi được, **app sandbox không đọc được**.
2. `/sdcard/Android/data/‹pkg›/files/` — `adb push` in *"1 file pushed, 0 skipped"* kèm tốc
   độ và **exit 0**, mà thư mục vẫn **rỗng**: scoped storage nuốt sạch, không một dòng lỗi.
   **Đừng tin mã thoát của `adb push` ở đây — phải `ls` lại.**
3. `/sdcard/Download/…` ghi được, nhưng app cần All files access, mà ROM OnePlus **chặn**
   `appops set` từ shell (`uid 2000 does not have MANAGE_APP_OPS_MODES`).
4. ✅ Đường đi được: push vào `/sdcard/Download`, rồi
   `adb shell "cat … | run-as ‹pkg› sh -c 'cat > files/models/…'"` — `cat` chạy dưới shell
   (đọc được sdcard), `run-as` ghi dưới uid app. 2 GB mất **12 giây**, và **không hỏng byte
   nào** (kiểm bằng kích thước: khớp từng byte).

Cộng hai cái bẫy của chính lượt dựng spike: chú thích XML trong `AndroidManifest.xml`
**không được chứa hai dấu gạch ngang** (`--uid` trong một ví dụ lệnh làm manifest merger
chết với *"Error parsing"*), và **logcat trôi nhanh hơn một lượt đo** — số liệu đọc trên
**màn hình app** mới đủ, `adb logcat -d` chỉ còn vài dòng cuối.

### 8.7 Ảnh và âm thanh (chặng 0.2, đo 2026-09-21) — ✅ CẢ HAI CHẠY ĐƯỢC

P1 chỉ đo **văn bản**. Ba câu hỏi của chặng 0.2 nay có đáp án, và đáp án **tốt hơn dự
đoán**: nhánh đọc hoá đơn là **khả thi về mặt kỹ thuật**.

Cùng máy, cùng tệp `gemma-4-E2B-it.litertlm`, `maxTokens: 2048` (ảnh ăn token, 1024 chật).
Pin 85–86 % **đang sạc**; nhiệt pin đi từ **33,1 °C** lúc bắt đầu tới **34,8 °C** sau trọn
cả chặng 0 (NPU + bốn lượt đa phương thức) — **nhiệt vẫn không thành vấn đề**, đúng như 8.1.
Ảnh bơm bằng `Message.withImage`, âm thanh bằng `Message.withAudio`, bật qua
`getActiveModel(supportImage:/supportAudio:)`.

| Lượt | Backend | Nạp | Ba/hai câu hỏi (ms) | **RAM đỉnh** |
|---|---|---|---|---|
| Ảnh **sạch** 73,6 KB | GPU | 9.352 ms | 6.263 / 4.858 / 11.574 | **1,66 GB** |
| Ảnh **mờ** 50,0 KB | GPU | 4.431 ms | 5.787 / 4.631 / 11.744 | *(không lấy mẫu)* |
| Ảnh **sạch** | CPU | 4.423 ms | 6.946 / 5.719 / 14.513 | **2,64 GB** |
| Âm thanh 2,89 s | GPU | 4.235 ms | 2.086 / 943 | **1,05 GB** |

**Giá của đa phương thức, tính theo RAM:** ảnh **+0,70 GB** so với văn bản (1,66 so với
0,96 GB trên GPU), âm thanh chỉ **+0,09 GB**. Cả hai vẫn **dưới** mức CPU-văn bản
(1,73 GB), nên không mở ra ngưỡng RAM mới nào.

**Chất lượng đọc hoá đơn — số thì đúng, chữ thì sai dấu.** Cả **ba** lượt ảnh đều trả về
tổng tiền **`191.862`** chính xác, và **mọi** con số dòng hàng đều đúng. Chỗ sai chỉ nằm ở
**chữ có dấu**: `sầu riêng` đọc thành *"sả riêng"* (GPU) và *"sáu riêng"* (ảnh mờ),
`thối lại` thành *"thống lại"* / *"thôi lại"*.

⚠️ **Ảnh mờ KHÔNG tệ hơn ảnh sạch** — cùng đọc đúng `191.862`, cùng đúng mọi dòng hàng,
thời gian chênh không đáng kể. Phép đo dựng hai ảnh để kẹp lấy khả năng thật, và kết quả
là hai đầu kẹp **trùng nhau**; mức nhoè này chưa chạm tới giới hạn của mô hình.

⚠️ **Nhưng đây là cận trên, đừng đọc thành lời hứa.** Ảnh là ảnh **dựng bằng máy** (PIL,
phông Roboto, chữ thẳng hàng, nền đều) chứ không phải ảnh **chụp** một tờ in nhiệt thật —
không có nếp gấp, loá đèn, nghiêng phối cảnh, mực phai không đều hay phông chữ máy in
nhiệt. Con số ở đây trả lời *"mô hình có đọc nổi tiếng Việt có dấu không"* (có), **không**
trả lời *"đọc nổi hoá đơn trong túi người dùng không"*. Muốn biết vế sau thì phải đo lại
bằng ảnh chụp thật.

**Âm thanh: đi thẳng qua Gemma, không cần mô hình thứ hai.** `supportAudio: true` nhận
thẳng WAV 16 kHz mono. Câu thử *"Hôm nay tôi ăn trưa hết bốn mươi nghìn đồng"* (giọng tổng
hợp `Microsoft An`, vi-VN):

- Chép lại: *"Hôm nay tôi ăn chưa hết 40.000đ."* — sai **một** chữ (`trưa` → `chưa`), và
  tự đổi *"bốn mươi nghìn đồng"* thành **`40.000đ`**.
- Rút ý định: **`40000đ | ăn trưa`** — **đúng cả hai vế**.

⚠️ Chỗ đáng chú ý nhất: câu thứ hai trả về `ăn trưa` **đúng**, trong khi bản chép lại của
chính nó nói `ăn chưa`. Tức **đừng bắt mô hình chép lại rồi mới phân tích bản chép** — hỏi
thẳng thứ mình cần thì nó dùng chính âm thanh, còn đi qua bản chép là tự chuốc thêm một
nguồn sai. Điều này áp thẳng cho chặng 2.2 (nhập giao dịch bằng câu).

⚠️ **Giọng tổng hợp sạch hơn giọng người** — cùng lối "cận trên" như ảnh dựng. Chưa đo với
giọng thật, chưa đo trong tiếng ồn.

⚠️ **Đọc mã gói 1.8.3 thì thấy HAI đường âm thanh khác nhau, đừng lẫn:** `supportAudio`
bơm byte thẳng vào Gemma (đường vừa đo), còn `FlutterGemma.installStt()` cài một mô hình
**riêng** (`.tflite` + tokenizer, ví dụ Moonshine) qua `SttInstallationBuilder`. Đường thứ
hai **chưa đo**. Chú thích của gói ở `getActiveModel` còn ghi `supportAudio` là *"for
Gemma 3n E4B"* — **câu ấy đã cũ**, phép đo này cho thấy nó chạy trên Gemma 4 E2B.

🛑 **Không phép đo nào ở đây mở một hạng mục.** Đọc hoá đơn và nhập bằng giọng nói đều
**chưa có trong kế hoạch**; mục này chỉ đóng hai câu hỏi để khi nào tới lượt thì không
phải đo lại. Riêng "đọc hoá đơn" còn vướng chiều **ghi** (mục 10.5) và cần ảnh chụp thật.

## 9. Bảng đo P3

(để trống; P3 điền: khung hình khi sinh câu, cache, tỉ lệ rơi về mẫu câu do bộ kiểm số)

---

## 10. Mảng này THỰC CHẤT là gì (2026-09-20)

Viết sau một lượt trao đổi dài với người dùng, khi họ hỏi thẳng *"AI Edge + SLM có
tác dụng gì"* và *"sao không huấn luyện để nó hiểu người dùng"*. Mục này trả lời sẵn
những câu ấy cho người đọc sau — kể cả chính người viết lúc làm báo cáo.

### 10.1 Gọi đúng tên từng phần

**"AI Edge" ở đây là một hệ luật, không phải học máy.** Bóc ra có hai thứ: tầng 1 là
thống kê mô tả (trung bình 3 tháng, dự phóng tuyến tính `spent × daysTotal / daysElapsed`,
tổng theo danh mục), tầng 2 là 39 luật A–H viết tay. Không mạng nơ-ron, không huấn
luyện, không suy luận xác suất — đây là **hệ chuyên gia**, công nghệ thập niên 1980,
chạy trên máy người dùng. Chữ "Edge" chỉ nói nó chạy ở client chứ không ở server.

**"SLM" là một bộ sinh câu.** Gemma 4 E2B nhận một bảng số **đã tính xong** và viết
lại thành câu tiếng Việt — ngành gọi là *data-to-text*. Nó không đọc giao dịch, không
tính, không được tạo ra con số nào; `kiemSo` chặn.

⚠️ **Cái tên "AI" gánh hai nghĩa**, và đó là gốc của mọi hiểu nhầm: nếu "AI" nghĩa là
*máy học từ dữ liệu* thì mảng này **không phải** AI; nếu nghĩa là *máy làm việc vốn
cần người* (đọc bảng số rồi viết nhận xét) thì nó **là**. Đặc tả gốc dùng nghĩa thứ hai.

**Nó không phải gì:** không tự khám phá ra điều gì mới — mọi thứ nó "biết" là do người
viết luật đặt vào. Và nó không giỏi lên theo thời gian, trừ đúng hai chỗ đã cài cơ chế
học: `suggestAmount` (TB 3 tháng) và luật C3 (đã cắt hai kỳ liền thì cắt nhẹ hơn).

**Chỗ đáng giá nhất của thiết kế** là lõi *máy tính số, mô hình kể chuyện* cộng với
`kiemSo` thi hành nó: **mô hình không bao giờ nói ra một con số mà hệ luật chưa tính**.
Nhiều sản phẩm AI tài chính để mô hình đọc thẳng dữ liệu rồi tự tính — nó bịa, người
dùng tin. Ở đây điều đó không xảy ra được **về mặt cấu trúc**, chứ không phải nhờ mô
hình ngoan. Nói gọn: *nó không thông minh, nhưng nó đúng — và với một app quản lý tiền,
đúng đáng giá hơn thông minh.*

### 10.2 Vì sao đặt trên client chứ không gọi API server

| | |
|---|---|
| **Pháp lý (cứng nhất)** | F1 đặc tả gốc: dữ liệu giao dịch **không được rời thiết bị**; Nghị định 13/2023/NĐ-CP. Gọi API ngoài là gửi sổ chi tiêu của người dùng cho bên thứ ba |
| **Kiến trúc** | app offline-first, SQLite trên máy là bản gốc. Tính năng cần mạng sẽ là thứ **duy nhất** chết khi mất mạng |
| **Thực tế của dự án** | backend là **vùng chỉ đọc**. Toàn bộ P2 không đụng một dòng nào ở `src/Backend` |
| **Vận hành** | API LLM tính tiền theo token; mô hình trên máy tốn 0 đồng sau khi tải |

Cái giá: mô hình yếu hơn hẳn server, tốn 2,41 GB máy người dùng, chỉ chạy arm64.
Chấp nhận được **vì ba dòng đầu là ràng buộc, không phải sở thích**.

### 10.3 ⚠️ Vì sao KHÔNG huấn luyện mô hình để cá nhân hoá

Người dùng hỏi hai lần, nên ghi lại lý lẽ:

**Trọng số không phải nơi chứa hiểu biết về người dùng.** Fine-tune đổi *cách mô hình
viết*, không đổi *những gì nó biết về bạn* — cái đó đến từ **context bơm vào prompt**.
Fine-tune trên 39 giao dịch của một người thì mô hình không nhớ nổi chúng một cách đáng
tin, lại có nguy cơ quên khả năng tiếng Việt chung. Bơm gói số vào prompt thì chính xác
100%, tức thì, và **kiểm được** bằng `kiemSo`.

Ba rào cản nữa: **pháp lý** (huấn luyện tập trung = gửi dữ liệu đi = phạm F1); **kỹ
thuật** (`flutter_gemma` nạp được trọng số LoRA có sẵn qua `loraPath` nhưng **không có
API huấn luyện nào** — quét cả `lib/` của gói ngày 2026-09-20); **quy mô** (fine-tune
per-user = mỗi người một lượt GPU và một file trọng số).

✅ **Thứ khả thi và nên làm**: mô hình **nhỏ** (naive Bayes, hồi quy, đếm tần suất) học
trên máy — vài chục KB, huấn luyện vài trăm mẫu trong mili giây, viết Dart thuần. Chúng
cho ra **con số**, rồi con số đi vào gói, rồi mô hình kể lại. Chỗ cắm đã đúng sẵn:
`GoiSo` không quan tâm số đến từ hệ luật hay từ mô hình đã học.

Chỗ duy nhất fine-tune đáng giá: **một lần cho cả app, không per-user** — dạy giọng văn
để giảm tỉ lệ bị `kiemSo` chặn. Điều kiện (mục 3.5 đặc tả gốc) là *prompt-only đã lộ
giới hạn*, mà P1 đo được **52 câu, không câu nào bịa số** → **chưa tới lúc**.

### 10.4 Mười tiêu chí cho AI chạy trên client

Rút từ chính thiết kế này; cột cuối là hiện trạng đo ngày 2026-09-20.

| Nhóm | Tiêu chí | Hiện trạng |
|---|---|---|
| **Không làm hỏng thứ đang chạy** | Chạy được khi **không có mô hình** — bản không-mô-hình là bản *chính* | ✅ `MauCau` mặc định; không đăng ký `BoDienGiai` thì app chạy y nguyên |
| | Rơi về bản thấp hơn **im lặng** — không toast, không dialog | ✅ năm nhánh, chỉ `debugPrint` |
| | Không chặn giao diện — hiện mẫu câu ngay, thay khi mô hình xong | ✅ kế hoạch P3; spec cấm `Isolate.run` |
| | Cache — cùng dữ liệu không gọi mô hình lần hai | ✅ P3 Task 3, LRU 200 mục theo dấu vân |
| **Không nói sai** | Bộ chắn giữa mô hình và người dùng | ✅ `kiemSo` |
| | Luôn hiện nguồn số cạnh câu | ✅ thẻ số liệu luôn của gói |
| | Nhãn "AI" chỉ khi câu thật từ mô hình | ✅ `NhanXet.tuMoHinh` |
| **Người dùng làm chủ** | Tải hay không, xoá được, tắt được | ✅ màn Cài đặt AI (P3) |
| | **Chiều GHI phải có xác nhận** | ❌ chưa có — chỉ cần khi mở chiều ghi |
| **Đo được** | Số liệu trên máy thật | ✅ bảng đo P1 |

> **Một câu:** *AI trên client phải là lớp trang trí trên một hệ thống vốn đã chạy đúng
> khi không có nó — và không bao giờ được nói ra một con số mà hệ thống ấy chưa tính.*

### 10.5 ⚠️ Chiều GHI — bốn tầng hậu quả

Chiều ghi **đã tồn tại**: sheet kế hoạch tái phân bổ (P2 Task 15) sửa hạn mức ngân sách
rồi đẩy lên PostgreSQL. Chỉ là quyết định đến từ hệ luật chứ không từ mô hình — và nó
đã có đúng khuôn xác nhận để bắt chước (tick từng dòng, sửa được số, ba lối ra).

Ranh giới nên vẽ theo **hậu quả nếu AI sai**, không theo độ khó kỹ thuật:

| Tầng | Việc | Sai thì sao | Xác nhận |
|---|---|---|---|
| 1 | sửa phân loại (danh mục, từ khoá) | số liệu lệch, sửa lại được | duyệt **cả lô** |
| 2 | tạo mốc theo dõi (ngân sách, mục tiêu, hoá đơn) | nhiễu, không mất tiền | một hộp thoại có số |
| 3 | tạo bản ghi tiền (giao dịch, trả hoá đơn) | **số dư ví sai**, kéo theo mọi thứ | **từng cái**, hiện rõ số |
| 4 | bật `auto_pay` / trích tự động | **tiền thật rời ví lúc người dùng vắng mặt** | 🛑 **AI không chạm** — chỉ dẫn tới công tắc |

⚠️ **`kiemSo` KHÔNG dùng được ở chiều ghi.** Nó chặn mô hình bịa số nhờ có gói số để
đối chiếu; ở chiều ghi không có gói nào — số đến từ câu người dùng. Bộ chắn thay thế
chỉ có một dạng đúng: **không bao giờ ghi thẳng, luôn hiện form điền sẵn.**

⚠️ **Form xác nhận phải hiện LỆNH, không hiện LỜI.** Mô hình có thể nói một đằng gọi
một nẻo — viết *"tạo hoá đơn tiền điện 500 nghìn"* trong khi tham số thật là
`soTien: 5000000`. Form phải dựng từ **tham số hàm**, không từ câu mô hình viết.

Ba thứ **không có hàm nào cả**: bật công tắc tự chuyển tiền, **xoá bất cứ gì**, và
đụng vào đồng bộ / xác thực.

---

## 11. Bản đồ năng lực — AI làm được gì trong hệ thống (khảo sát 2026-09-20)

Quét bằng máy, không theo trí nhớ.

| Đo | Số |
|---|---|
| Mảng tính năng (`lib/features/`) | **13** |
| Route khai trong `app_router.dart` | **43** (41 tuyệt đối + 2 tương đối) |
| Bảng Drift | **10** |
| **Hàm domain thuần** (`*/domain/*.dart`) | **66** |
| Gói số AI đang dùng | **4** |
| Lời gọi biểu đồ `fl_chart` | 8 (→ **9** khối người dùng thấy) |

### ⭐ Phát hiện chính: app đã tính sẵn 66 thứ, AI mới nói ra 4

Tỉ lệ khai thác **dưới 10%**. Mỗi hàm trong `*/domain/` là một phép tính **đã xong, đã
có test, đã đúng** — AI chỉ cần gói lại thành `GoiSo` là nói ra được, không phải tính
lại gì. Phần lớn việc phía trước **không phải "thêm AI", mà là "gói lại thứ đã tính"**.

Hai mảng lớn nhất app đang trống:

- **`goal` — 31 tệp, 14 hàm domain, AI mới dùng 1.** Bỏ qua `goal_forecast`,
  `goal_stats`, `goal_progress_series`, `goal_wallet_shortfall`, `goal_deposit_warning`.
- **`bill` — 27 tệp, 10 hàm domain, AI chưa chạm gì.** Không một gói số nào cho hoá đơn,
  dù đã có `bill_ky_ke_tiep`, `bill_status` (năm trạng thái), `bill_chain`, `bill_an_han`.

### Bảng theo mảng

| Mảng | Số đã có sẵn | AI làm được | Chiều | Ưu tiên |
|---|---|---|---|---|
| **transaction** | `transaction_filter`, `transaction_lookup` | nhập bằng câu · tìm kiếm bằng câu · gắn danh mục hàng loạt | ghi 3 / đọc / ghi 1 | ⭐⭐⭐ |
| **category** | `CategorySuggestionEngine`, cột `keyword` | học từ khoá từ lịch sử · phân loại tự động | ghi 1 | ⭐⭐⭐ |
| **bill** | 10 hàm domain, **chưa dùng** | gói số hoá đơn · phát hiện hoá đơn định kỳ · dự đoán số tiền kỳ tới · tạo hoá đơn bằng lệnh | đọc + ghi 2 | ⭐⭐⭐ |
| **goal** | 14 hàm domain, **mới dùng 1** | giải thích vì sao trễ · ví thiếu tiền trích · dự báo ngày đạt · tạo mục tiêu bằng lệnh | đọc + ghi 2 | ⭐⭐ |
| **analytics** | `thac_nuoc`, `tong_tai_san`, `lich_chi_tieu`, `moc_so_sanh`, `dong_tien_tu_do`… | **giải thích 9 biểu đồ** · chọn khối đáng xem | đọc | ⭐⭐ |
| **analytics / vay-nợ** | `vai_vay_no` | **dư nợ theo người** — đọc tên từ ghi chú | đọc | ⭐⭐ |
| **budget** | `budget_pace`, `budget_impact`, `budget_history` | đã có nhận xét + kế hoạch; thêm: đề xuất tạo ngân sách | đọc + ghi 2 | ⭐ |
| **wallet** | `vi_tinh_vao_tong`, `dieu_chinh_so_du` | giải thích vì sao số dư lệch | đọc | ⭐ |
| **notification** | 19 loại | chọn loại nào đáng bắn ra hệ điều hành | đọc | ⭐ |
| **analytics / báo cáo** | `bao_cao_xuat`, `xuat_tep` | tóm tắt đầu PDF — ⚠️ xem 11.2 | đọc | cân nhắc |
| **home** | `thu_chi_thang` | đã có | — | — |
| **auth · profile · sync** | — | **không có đất** | — | 🛑 |

### 11.1 ⚠️ "AI hiểu biểu đồ" — đừng dùng vision

Biểu đồ được vẽ **từ dữ liệu đang nằm sẵn trong máy**. Cho mô hình nhìn ảnh biểu đồ là
bắt nó đọc ngược lại thứ mình vừa vẽ: chậm hơn, tốn RAM hơn, và **đoán số từ pixel thì
sai được** — trong khi đưa thẳng dữ liệu thì chính xác 100% và `kiemSo` kiểm được.

Vision dành cho ảnh **không có dữ liệu đi kèm** (hoá đơn giấy, ảnh chụp app khác), không
phải cho biểu đồ của chính mình.

⚠️ **Điều kiện bắt buộc:** gói số của biểu đồ phải **tính sẵn mọi thứ đáng nói** — kỳ
cao nhất, kỳ thấp nhất, % thay đổi kỳ cuối, trung bình, xu hướng. Đưa chuỗi giá trị trần
thì mô hình sẽ **tự tính** ("tăng 25%"), con số ấy không có trong gói, `kiemSo` chặn, câu
rơi về mẫu — hỏng **im lặng**, trông như mô hình không hoạt động.

### 11.2 Hai chỗ khuyên cân nhắc kỹ

**Tóm tắt đầu báo cáo PDF.** Nghe hợp lý (PDF có 10 khối số mà không câu tổng kết) nhưng
rủi ro hơn mọi chỗ khác: PDF **đi ra ngoài**, gửi cho người khác — câu sai ở đó không ai
kiểm lại được. Và font Roboto nhúng **thiếu glyph**: `→ ▲ ▼` từng bị gói `pdf` bỏ đi im
lặng suốt từ 2026-09-09. Câu do mô hình sinh có thể chứa ký tự ngoài ASCII không lường
trước. Nếu làm thì **bắt buộc** chạy câu qua bộ quét glyph đã có ở `xuat_tep_test.dart`.

**AI viết câu thông báo.** Không nên: thông báo cần ngắn, đoán được, và `dedupeKey` phải
ổn định — câu mô hình sinh mỗi lần một khác thì chống trùng hỏng. Nhưng AI **chọn loại
nào đáng bắn ra hệ điều hành** thì hợp lý.

### 11.3 Năm việc đáng nhất, theo thứ tự

1. **Gắn danh mục hàng loạt** — vá 38% dữ liệu đang mù (15/39 giao dịch của tài khoản
   thật chưa gắn danh mục, đo 2026-09-20), rủi ro thấp nhất (sửa, không tạo; không đụng
   tiền), và **tự sinh dữ liệu huấn luyện cho chính nó**: mỗi lần người dùng duyệt hay
   sửa một đề xuất là một mẫu có nhãn.
2. **Nhập bằng câu** (*"hôm nay tôi đã ăn sáng 40k"*) — việc người dùng làm nhiều nhất;
   bản luật (regex + `CategorySuggestionEngine` đã có) chạy được **không cần mô hình**,
   mô hình chỉ làm nó hiểu câu lạ. ⚠️ Chốt bảng quy đổi `k` / `củ` / `chai` và **hiện rõ
   số đã hiểu** trên form.
3. **Gói số cho hoá đơn** — mảng 27 tệp mà AI chưa chạm; chỉ cần gói lại 10 hàm đã có.
4. **Trợ lý ra lệnh** (tầng 0 + 2) — tạo hoá đơn, mục tiêu, ngân sách bằng câu nói, qua
   function calling. ⚠️ Đo **tỉ lệ chọn đúng hàm** trước khi mở tầng 3: mô hình 2,3 tỉ
   tham số chọn sai thường xuyên hơn mô hình lớn, và *"tạo tiết kiệm 5 triệu"* có thể là
   ba hàm khác nhau. Phép đo ấy cũng là một bảng số cho báo cáo.
5. **Giải thích biểu đồ** — chín lần cùng một việc (mỗi khối một hàm dựng gói số), nhưng
   mạnh nhất khi demo.

### 11.4 Việc đã chốt nhưng chưa làm

Bốn việc cá nhân hoá ở tầng số, người dùng chọn cả bốn ngày 2026-09-20 (xem memory
`ai-ca-nhan-hoa-cho-tung-nguoi-dung`): học mức thiết yếu từ phản hồi · tự đề xuất bật cờ
Cố định · học nhịp chi theo ngày trong tháng · phát hiện khoản chi bất thường theo danh
mục.

⚠️ **Luật chung cho cả bốn:** mỗi luật có **ngưỡng mẫu tối thiểu, dưới ngưỡng thì im
lặng hoàn toàn**, rồi tự bật khi đủ. Không có ngưỡng thì luật sẽ "im hàng tháng rồi nổ
bừa ngay khi vừa đủ mẫu" — đúng sai lầm mà mục 5f `NOTIFICATION_FEATURE.md` đã loại một
lần. Chỗ trống rõ nhất để cắm: **essentiality đang để cứng 0,5** cho mọi danh mục
(`tai_phan_bo.dart`), khiến phép xếp hạng C6 quy về xếp theo dư địa — mà bảng
`AiRebalancingFeedbacks` **đã ghi sẵn** dữ liệu để học.

### 11.5 Năm chỗ cá nhân hoá được nữa — tìm bằng cách quét HẰNG SỐ

Cách tìm: **mỗi hằng số cứng trong `lib/` là một câu nói "mọi người dùng giống nhau"**.
Quét bằng máy ngày 2026-09-20. ⚠️ **Bốn trong năm nhóm dưới không cần mô hình gì cả** —
chúng là đếm tần suất và neo theo một con số đã có, đúng kết luận mục 10.3: *cá nhân hoá
nằm ở tầng số, không ở mô hình*.

#### ⭐ (1) App đã cá nhân hoá MỘT ngưỡng, năm cái kia thì cứng

Luật tái phân bổ có sáu ngưỡng; đúng **một** cái neo theo người dùng:

```dart
nguongCoNghia = max(1% thuNhap3Thang, 50.000)   // ← đã cá nhân hoá
```

Năm cái còn lại là số tuyệt đối cho mọi người (`tai_phan_bo.dart`):

| Hằng | Giá trị | Vấn đề |
|---|---|---|
| `kNguongThamHutTuyetDoi` | 50.000 đ | người thu nhập 5 triệu và người 50 triệu **dùng chung một con số** |
| `kDuDiaToiThieu` | 100.000 đ | nt |
| `kBuocLamTron` | 10.000 đ | người tiêu lớn thấy đề xuất lẻ tẻ |
| `kNguongThamHutTiLe` | 10 % | tỉ lệ — có thể hợp lý cho mọi người |
| `kTranCat` / `kTranCatDaBiCat` | 25 % / 15 % | nt |

Với người thu nhập 50 triệu, thâm hụt 50.000 đ là tiền lẻ — mà app vẫn dựng cả một kế
hoạch cắt giảm cho nó. Đây là **sự không nhất quán app đã tự tạo ra**, và nó lộ ra chính
vì `nguongCoNghia` làm đúng.

**Sửa rẻ nhất trong cả mục 11:** cho ba hằng đầu đi qua cùng phép neo. Không cần AI,
không cần dữ liệu mới — `thuNhap3Thang` đã có sẵn trong `DuLieuTaiPhanBo`. Hai hằng cuối
là **tỉ lệ** nên giữ nguyên là hợp lý.

#### ⭐ (2) Ví chọn sẵn theo ngữ cảnh

`chonViChonSan` (`transaction/domain/vi_chon_san.dart`) chọn **ví mặc định**, rơi về ví
đầu danh sách — **giống nhau mọi lúc**, không theo danh mục, không theo giờ.

Thói quen thật thì có mẫu: ăn uống trả tiền mặt, mua sắm online trả ví ngân hàng. Học
bằng **đếm tần suất** (*"danh mục Ăn uống → 9/10 lần dùng ví Tiền mặt"*), cùng loại phép
tính với `suggestAmount`. Giảm **một cú chạm mỗi lần nhập giao dịch** — mà nhập giao dịch
là việc làm nhiều nhất trong app.

#### (3) Ngưỡng cảnh báo ngân sách 70 % / 90 %

`budget_visuals.dart`: `_cautionAt = 0.70`, `_criticalAt = 0.90` — cứng cho mọi người.
Nhưng 70 % vào ngày 20 là bình thường, còn 70 % vào ngày 5 là báo động.

⭐ **Ghép thẳng với việc #3 của mục 11.4** (học nhịp chi theo ngày trong tháng): nhịp chi
không chỉ dùng để dự phóng cuối kỳ mà còn để **dịch ngưỡng cảnh báo** theo từng người.
Một phép học, hai chỗ dùng.

#### (4) Thứ tự khối trang Phân tích

Trang có **10 khối mang tiêu đề** (đếm `_tieuDeKhoi` ngày 2026-09-20), thứ tự giống nhau
với mọi người. Người không có mục tiêu tiết kiệm vẫn cuộn qua khối mục tiêu.

Hai mức: **rẻ** — soát lại khối nào chưa tự ẩn khi không có dữ liệu (nhiều khối đã ẩn);
**học** — đếm khối nào người dùng hay cuộn tới rồi dừng, đưa lên trên. Trang chủ đã làm
một phần: `pickHomeBudget` chọn ngân sách **căng nhất** thay vì ngân sách đầu tiên.

#### (5) Tần suất thông báo theo phản ứng

19 loại, hiện đối xử như nhau. Nhưng người dùng **đã nói cho ta biết** họ nghĩ gì: loại
nào hay bị vuốt bỏ ngay, loại nào hay được chạm vào.

⚠️ **Không đụng `dedupeKey`** — chống trùng phải giữ nguyên; chỉ đổi việc *có bắn ra hệ
điều hành hay không*. Và giữ nguyên `luonBao`: bốn loại báo "app vừa rút tiền của bạn"
không bao giờ được giảm tần suất.
