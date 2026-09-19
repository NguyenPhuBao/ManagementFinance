# AI Edge-SLM trên Client-app — tài liệu tính năng

**Trạng thái:** P0 xong (`03fe03a`) · **P2 đang làm — xong Task 0–13** (dừng theo yêu cầu người dùng tối 2026-09-19; còn Task 14–17: gắn khối vào bốn màn, sheet kế hoạch, thông báo, nghiệm thu) ·
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

## 8. Bảng đo P1 / P3

(để trống ở P2; P1 điền: máy, mô hình, thời gian nạp, câu đầu, câu tiếp, RAM đỉnh, 10 câu liên
tiếp, chất lượng tiếng Việt trên 3 gói số thật)
