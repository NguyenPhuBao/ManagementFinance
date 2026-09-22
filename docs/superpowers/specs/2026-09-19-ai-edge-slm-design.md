# AI Edge-SLM trên Client-app — thiết kế

**Ngày:** 2026-09-19 · **Nhánh:** `TranQuangDat` @ `88f22a7` · **Trạng thái:** đã duyệt (người dùng
duyệt bản trình bày bảy mục cùng ngày; tệp này là bản viết ra của đúng bảy mục ấy).

**Nguồn:** đặc tả gốc [`docs/AI/AI_Edge-SLM.md/Client-app.md`](../../AI/AI_Edge-SLM.md/Client-app.md)
(NPBao, `fcc20b5`); bản đánh giá
[`docs/superpowers/backend/AI_EDGE_SLM_DANH_GIA_AP_DUNG.md`](../backend/AI_EDGE_SLM_DANH_GIA_AP_DUNG.md)
(2026-09-18, mục 13 = 17 điều kiện để được xem là "đã áp dụng"). Tệp này **không lặp lại** hai tài
liệu ấy; nó ghi những gì đã **chốt** để thi công, và đánh dấu ⚠️ ở chỗ **khác** bản đánh giá.

---

## 0. Năm quyết định của người dùng ngày 2026-09-19

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Runtime | **Nâng Flutter lên ≥ 3.44** (stable mới nhất là 3.47) để dùng `flutter_gemma` **1.8.3**. Không ở lại 3.41 với bản 0.13.6, không tự tích hợp llama.cpp |
| 2 | Máy thật | Máy Snapdragon 8 Gen 3 / 12 GB **cắm USB vào máy dev**, Claude chạy qua adb |
| 3 | Phạm vi màn | **Bốn màn**: Ngân sách, Phân tích, Trang chủ, Mục tiêu tiết kiệm |
| 4 | Tầng 2 | **Làm đủ**: thâm hụt + nguồn bù + kế hoạch chờ duyệt + bảng phản hồi + cờ "Cố định" |
| 5 | Trợ lý AI | **4 chip theo gói số + hỏi đáp tự do** trên cùng gói số, qua cùng bộ kiểm số; không ảnh, không mic |

Hai điều **đo được** cùng ngày làm lệch bản đánh giá 18/09 (đã chèn banner vào tệp ấy):

- `flutter_gemma` **không chạy Gemma 3 4B**. Danh sách mô hình văn bản của gói: Gemma 3 1B / 270M,
  Gemma 3n E2B / E4B, **Gemma 4 E2B (≈2,4 GB) / E4B (≈4,3 GB)**. Hai bản Gemma 4 ở kho
  `litert-community` **công khai**, không cần token HuggingFace; Gemma 3 1B và Gemma 3n thì **gated**.
- Bản 1.8.3 đòi **Flutter ≥ 3.44, Dart ≥ 3.12**; dự án ở 3.41.5 / 3.11.3. Bản cũ nhất còn hợp
  là 0.13.6 (2026-04-18, Flutter ≥ 3.24).
- Tệp `.litertlm` **chỉ chạy arm64-v8a**. Máy ảo x86_64 **không bao giờ** nạp được mô hình →
  nhánh rơi về mẫu câu là đường mặc định ở máy ảo, và là nơi nghiệm thu nhánh ấy.

---

## 1. Lộ trình bốn giai đoạn

| Giai đoạn | Việc | Điều kiện | Cỡ |
|---|---|---|---|
| **P0 — Nâng Flutter** | 3.41.5 → 3.47. **Một commit riêng, chưa đụng gì tới AI.** Kiểm: `flutter pub get`, `build_runner`, toàn bộ test (mốc 2960), `flutter analyze` (mốc 25), `flutter build apk --debug`, máy ảo mở app và đăng nhập. Chỗ dễ vỡ: `fl_chart 1.2.0` ghim cứng, `intl ^0.20.2` đi kèm `flutter_localizations`, `drift`/`sqlite3_flutter_libs`, `flutter_local_notifications`. Cập nhật `CLAUDE.md` (mốc test/analyze nếu đổi) và mục 14 `PROJECT_CONTEXT.md` | Không | 0,5 ngày |
| **P1 — Spike mô hình** | Mã **vứt đi** (thư mục ngoài `lib/` hoặc nhánh riêng, không commit). `flutter_gemma 1.8.3`, tải Gemma 4 **E4B** và **E2B** lên máy 8 Gen 3 qua adb. Đo: thời gian nạp, câu đầu, câu tiếp, RAM đỉnh, **10 câu liên tiếp** (nhiệt — so tốc độ câu 10 với câu 1), chất lượng tiếng Việt trên **3 gói số thật** của app. Máy ảo x86_64 xác nhận đường "không nạp được". Kết quả là **bảng đo** ghi vào `docs/AI_EDGE_FEATURE.md`, và chốt bậc thang mục 4 | Máy cắm USB | 1 ngày |
| **P2 — Tầng Edge + mẫu câu** | Toàn bộ mục 2, 3, 5 (trừ màn Cài đặt AI và Trợ lý AI). **Chạy trọn không cần mô hình.** Mở giai đoạn bằng tài liệu: `docs/AI_EDGE_FEATURE.md` (client) và tài liệu `CAN-LAM/` cho backend | P0 xong | 1–2 tuần |
| **P3 — Cắm SLM** | Mục 4: runtime, tải mô hình, bậc thang, bộ kiểm số, cache, màn Trợ lý AI, màn Cài đặt AI | P1 đạt, P2 xong | 1 tuần |

P1 chỉ là điều kiện của P3; P2 không chờ P1. Thứ tự thực tế: P0 → (P1 khi có máy) → P2 → P3.

---

## 2. Gói số và câu nhận xét (Tầng 1 + Tầng 3 bản mẫu câu)

### 2.1. Vị trí mã

```
lib/features/ai_edge/
  domain/
    goi_so.dart            # GoiSo (lớp cha) + SoLieu (nhãn, số thô, chuỗi đã định dạng)
    goi_so_ngan_sach.dart  # GoiSoNganSach  ← budgetPaceOf, BudgetEntity, TaiPhanBo
    goi_so_phan_tich.dart  # GoiSoPhanTich  ← ThongKeKy: phanTramSoVoi, tyLeTietKiem, duBao, topKhoanChi
    goi_so_muc_tieu.dart   # GoiSoMucTieu   ← GoalEntity.progress/isBehindSchedule/daysLeft, goal_stats
    goi_so_trang_chu.dart  # GoiSoTrangChu  ← TongThuChi tháng này, viTinhVaoTong, pickHomeBudget
    nhan_xet.dart          # NhanXet (câu, thẻ số liệu, mức)
    bo_dien_giai.dart      # abstract BoDienGiai { Future<NhanXet> dienGiai(GoiSo) }
    mau_cau.dart           # MauCau implements BoDienGiai — thuần, đồng bộ bên trong
    dau_van.dart           # dauVanCua(GoiSo) → String (khoá cache)
    tai_phan_bo.dart       # Tầng 2 — mục 3
    kiem_so.dart           # bộ kiểm số — mục 4.4 (dùng chung cho mẫu và SLM)
  data/
    slm_runtime.dart       # P3 — tệp DUY NHẤT import flutter_gemma
    slm_dien_giai.dart     # P3 — Slm implements BoDienGiai, bọc runtime + kiểm số + cache + rơi về mẫu
    slm_cache.dart         # P3
    mo_hinh_tai_ve.dart    # P3 — tải/xoá mô hình, bậc thang theo RAM
  presentation/
    widgets/khoi_nhan_xet.dart        # khối dùng chung cho 4 màn
    widgets/the_so_lieu.dart          # thẻ số liệu (G3)
    pages/ke_hoach_tai_phan_bo_sheet.dart
    pages/cai_dat_ai_page.dart        # P3
```

Màn Trợ lý AI giữ nguyên chỗ `lib/features/ai_chat/`, đọc `ai_edge`.

Hai thứ **cố ý nằm ngoài** `ai_edge/` (chốt khi viết kế hoạch P2, 2026-09-19): DAO bảng phản hồi ở
`lib/core/database/daos/ai_feedback_dao.dart` theo nếp mọi DAO của dự án; và nguồn dữ liệu Tầng 2
`lib/features/budget/data/tai_phan_bo_nguon.dart` (cờ Cố định, TB 3 tháng, thu nhập 3 tháng, phản
hồi cũ) — nó đọc bảng giao dịch để tính thu nhập, mà test quét 14 cấm `ai_edge/` chạm bảng ấy. Lớp AI
chỉ nhận gói `DuLieuTaiPhanBo` đã dựng xong.

### 2.2. Gói số

`GoiSo` là **kiểu typed** theo màn, không phải JSON tự do. Mỗi gói mang:

- các trường số thô cần cho luật và mẫu câu;
- `List<SoLieu>`: nhãn + số thô + **chuỗi đã định dạng** qua `CurrencyFormatter` (`"3.200.000 đ"`,
  `"35%"`) — danh sách này là **ba thứ cùng lúc**: thẻ số liệu (G3), tập cho phép của bộ kiểm số,
  và phần đưa vào prompt để mô hình chép nguyên;
- `dauVan`: hash của các số thô, sắp xếp theo nhãn → khoá cache.

**Nguồn duy nhất của mọi con số** là hàm domain đã có (bảng ở mục 2.1). Lớp `ai_edge` **không**
đọc bảng giao dịch, không so `type`, không tra ví. Có **test quét** `lib/features/ai_edge/` cấm
các chuỗi `'thu'`, `'chi'`, `'transfer'`, `walletId`, `transactionDao` (danh sách hằng trong test).

Gói số dựng **ở tầng presentation của từng màn** từ state sẵn có (`BudgetView`, `ThongKeKy`,
`GoalEntity`, số liệu trang chủ) — không thêm nguồn stream nào, không đụng repository.

### 2.3. Câu nhận xét

```dart
enum MucNhanXet { binhThuong, canhBao, thieuDuLieu }
class NhanXet { final String cau; final List<SoLieu> theSoLieu; final MucNhanXet muc; final bool tuMoHinh; }
```

- Nhánh **thiếu dữ liệu** là một câu thật ("Chưa đủ dữ liệu tháng này để nhận xét"), không ẩn khối.
- **Nền bằng 0 không bao giờ in phần trăm** (bài học so cùng kỳ năm trước).
- Mẫu câu theo màn (bản đầu, sẽ tinh chỉnh khi thấy trên máy ảo):

| Màn | Câu chính | Điều kiện nhánh |
|---|---|---|
| Ngân sách | "Bạn đã dùng {spent} / {amount} ({percent}), còn {daysLeft} ngày — nên chi tối đa {perDay} mỗi ngày." + câu tái phân bổ nếu có kế hoạch | không ngân sách → thiếu dữ liệu; `isOverBudget` → mức cảnh báo |
| Phân tích | "Kỳ này chi {chi}, {tăng/giảm percent} so với kỳ trước; để dành {tyLe} thu nhập." + dự báo 30 ngày nếu có cam kết | kỳ rỗng / kỳ trước bằng 0 → bỏ vế phần trăm; `tyLeTietKiem == null` → bỏ vế để dành |
| Mục tiêu | "{tên}: {percent}, còn {remaining}; {đúng/chậm} kế hoạch." cho mục tiêu ưu tiên cao nhất chưa xong | không mục tiêu → thiếu dữ liệu; `isBehindSchedule` → cảnh báo |
| Trang chủ | "Tháng này thu {thu}, chi {chi}, còn lại {conLai}." + một ngân sách căng nhất nếu có | tháng chưa có giao dịch → thiếu dữ liệu |

Khối Nhận xét luôn hiện **thẻ số liệu** dưới câu; câu do mô hình sinh có nhãn nhỏ "AI" (`tuMoHinh`).

---

## 3. Tầng 2 — tái phân bổ

### 3.1. Luật (đã điều chỉnh theo bảng mục 11 của bản đánh giá)

Đầu vào: `List<BudgetView>` đang chạy (`!isExpired(now)`), `now`, cờ Cố định theo `categoryId`,
`ThuNhap3Thang` (trung bình `thuNhapCua` ba tháng liền trước, có thể 0), bảng phản hồi.

Ghi chú mô hình dữ liệu: `addBudget` từ chối `categoryId == null`, nên mọi ngân sách người dùng
tạo được đều gắn danh mục; hàng `categoryId == null` (nếu kéo về từ server) **bỏ qua** ở Tầng 2.

| Bước | Luật | Công thức |
|---|---|---|
| Dự phóng | B4 + B5 gộp | `daysElapsed = daysTotal − daysLeft`. Nếu `daysElapsed ≥ 5`: `duPhong = spent × daysTotal / daysElapsed`. Nếu `< 5`: `duPhong = spent + tb3Thang × daysLeft / daysTotal`, với `tb3Thang` mượn phép của `BudgetRepository.suggestAmount` (tổng chi 3 tháng trước / 3); không có lịch sử (`null`) → **chỉ** báo khi đã `isOverBudget` |
| Thâm hụt | B2 | `thamHut = duPhong − amount`; là thâm hụt khi `thamHut ≥ 0.10 × amount` **và** `thamHut ≥ 50.000` |
| Nguồn bù | C1/C2/C4 | ngân sách khác đang chạy, **không** có cờ Cố định, `duDia = amount − duPhong ≥ 100.000` |
| Xếp hạng | C6 ⚠️ | `score = duDia × (1 − essentiality)`, mà essentiality của **mọi** danh mục = 0,5 (chưa có thống kê), nên **quy về xếp theo dư địa** — nói thẳng trong tài liệu |
| Trần cắt | C3 | `catToiDa = 0.25 × duDia`; **0,15** nếu bảng phản hồi ghi danh mục ấy có dòng `accepted`/`modified` ở **hai kỳ ngân sách liền trước** |
| Làm tròn | G1 | `round(x / 10000) × 10000` |
| Ngưỡng có nghĩa | C5 | bỏ dòng nếu `cat < max(0.01 × thuNhap3Thang, 50.000)` |
| Cạn nguồn | C7 | tổng cắt < thâm hụt → `trangThai = thieuNguonBu`, `soThieu = thamHut − tổng cắt` |
| Trần tổng | D5 | **bỏ**: tái phân bổ giữ tổng hạn mức không đổi nên không thể vi phạm |

Đầu ra: `KeHoachTaiPhanBo { nganSachThieu, thamHut, dong: [DongTaiPhanBo(nguon, soTien)], trangThai, soThieu }`.
Hàm thuần `taiPhanBoCua(...)` ở `tai_phan_bo.dart`, không đọc đồng hồ, không chạm CSDL.

### 3.2. Kế hoạch chờ duyệt (E1/E2/E3)

- **Không bao giờ** tự sửa ngân sách. Thẻ trên trang Ngân sách (tab đang chạy) hiện tóm tắt; chạm
  mở sheet `ke_hoach_tai_phan_bo_sheet.dart` liệt kê từng dòng "bớt {soTien} từ {nguon} sang
  {thieu}", **tick từng dòng**, **sửa được số** (ô tiền có trần chữ số như mọi ô tiền), nút **Áp dụng**.
- Áp dụng: với mỗi dòng được tick, `updateBudget(nguon.copyWith(amount: amount − x))` và
  `updateBudget(thieu.copyWith(amount: amount + Σx))`. Đi qua `BudgetRepository.updateBudget` để đồng
  bộ và ràng buộc "một ngân sách mỗi danh mục" giữ nguyên. Tổng hạn mức không đổi.
- Mỗi dòng ghi **một** hàng `AiRebalancingFeedback`: `accepted` (tick, giữ số) / `modified` (tick,
  đổi số) / `rejected` (không tick, hoặc đóng sheet bằng nút "Bỏ qua"). Đóng sheet bằng vuốt thì
  **không ghi** — người dùng chưa quyết.
- E5: thẻ màu theo `trangThai` (đủ nguồn bù → màu ngân sách bình thường; thiếu → `AppColors.error`).

### 3.3. Schema v24 — hai thứ cục bộ

| Thứ | Khuôn mẫu | Ghi chú |
|---|---|---|
| Cột `categories.ai_co_dinh` (`BoolColumn`, mặc định `false`) | `wallets.allow_negative` (v23, G27) | Bật ở màn sửa danh mục (`category_add_page.dart`), nhãn "Cố định — AI không đề xuất cắt". Không đi qua đồng bộ; `categoryForPush` không đọc nó; nhánh kéo về không chạm nó (`insertAllOnConflictUpdate` chỉ ghi cột có trong payload — kiểm bằng test) |
| Bảng `AiRebalancingFeedback` | `AppNotifications` (quy tắc 9) | Cột: `id`, `idaccount`, `createdAt`, `deficitBudgetId`, `donorBudgetId`, `donorCategoryId`, `suggestedAmount`, `actualAmount`, `action` (`accepted`/`rejected`/`modified`), `periodFrom`, `periodTo`. **Không** `syncStatus`/`syncError`/`updatedAt`/`isDeleted`. `purgeDataForOtherAccounts` xoá theo `idaccount` |

Migration v24: `addColumn` + `createTable`, không đổi cột nào khác. **Test quét `lib/` thứ 14**
cấm `aiCoDinh`/`ai_co_dinh`/`AiRebalancingFeedback` xuất hiện trong `sync_engine.dart`,
`sync_payload_normalizer.dart`, và `SyncEntityType`. `sync_payload_contract_test.dart` **không đổi**.

**Không** dựng `local_category_features` (tính tại chỗ) và `local_ai_alert_history` (bảng
`AppNotifications` đã làm việc ấy).

### 3.4. Thông báo

Một `NotificationKind.budgetRebalance` thêm vào `notification_rules.dart`, sinh bởi luật mới
`_rebalanceCandidates` đọc trường mới `NotificationRuleInput.keHoachTaiPhanBo` (`KeHoachTaiPhanBo?`,
do bộ quét nạp qua hook `loadKeHoach`, cùng khuôn `loadChiLon`) — kế hoạch tính bằng **đúng** hàm và
nguồn dữ liệu mà trang Ngân sách dùng, nên thông báo và thẻ trên màn không thể nói hai chuyện. Khoá **`budgetRebalance:<năm-ISO>-W<tuần-ISO>`** → tối đa **một** thông báo đẩy
mỗi tuần (B6), bất kể bao nhiêu ngân sách thâm hụt; câu chữ **không nêu số**; deeplink `/budget`
(route gốc ngoài shell → `push`, đúng `nhanhThanhTab`). Xếp nhóm **Ngân sách**, tôn trọng
`silenceBefore`. Thẻ trên màn thì luôn hiện (thụ động), không qua bộ luật.

---

## 4. Tầng 3 — SLM trên máy (P3)

> 🛑 **BẢNG 4.1 DƯỚI ĐÂY ĐÃ LỖI THỜI TỪ 2026-09-20.** P1 spike đo trên máy thật
> (OnePlus 13R / Snapdragon 8 Gen 3) và người dùng chốt **E2B cho MỌI máy, bỏ hẳn
> E4B** — bảng đo và bậc thang mới ở **mục 8** `docs/AI_EDGE_FEATURE.md`.
> Chính mục 4.1 này đã dự liệu điều đó: *"P1 có thể đổi con số ngưỡng; bảng này là
> điểm xuất phát"*. Giữ nguyên văn ở đây làm ảnh chụp của giả định trước khi đo —
> **đừng thi công theo nó**. Hai số sai rõ nhất: cỡ tệp thật là E4B **3,41 GB** /
> E2B **2,41 GB**, và trên GPU **cả hai** chỉ tốn ~**0,96 GB** RAM đỉnh chứ không
> phải vài GB — tức ngưỡng "RAM thiết bị" không phân biệt được hai mô hình.

### 4.1. Bậc thang mô hình ⚠️ — ĐÃ THAY, xem banner trên

| RAM thiết bị | Mô hình | Cỡ |
|---|---|---|
| ≥ 8 GB | Gemma 4 **E4B** | ≈ 4,3 GB |
| 4 – 8 GB | Gemma 4 **E2B** | ≈ 2,4 GB |
| < 4 GB · không arm64 (máy ảo) · chưa tải · lỗi runtime · pin < 15 % | **Mẫu câu**, không toast lỗi (H3) | — |

Bỏ Gemma 3 1B khỏi bậc thang: nó gated, cần token HuggingFace nhúng trong app. RAM đọc bằng
`ActivityManager.getMemoryInfo` qua một kênh nhỏ trong `MainActivity` (cùng chỗ với kênh
`flowmoney/luu_tep`) — không thêm gói `device_info_plus`. Pin đọc qua `Battery` của Android cùng
kênh ấy. **P1 có thể đổi con số ngưỡng**; bảng này là điểm xuất phát.

### 4.2. Tải mô hình

Chỉ khi người dùng bấm ở **màn Cài đặt AI**: hiện dung lượng, đòi Wi-Fi (`connectivity_plus` đã
có), tiến độ, huỷ được, xoá được. Tải qua `FlutterGemma.installModel(...).fromNetwork(url)` với URL
`litert-community` công khai, **không** token. Mô hình **không** đóng vào APK. Trong lúc chưa tải,
mọi khối Nhận xét chạy mẫu câu.

### 4.3. Suy luận

- Prompt hệ thống cố định (mục 3.2 đặc tả gốc) + **hai** ví dụ gói số → câu chuẩn + gói số dạng
  dòng `Nhãn: chuỗi đã định dạng`. Nhiệt độ **0,2**; trần **120** token cho câu theo màn, **300** cho
  hỏi đáp tự do.
- Nạp **lười** ở lần đầu một khối cần, giữ suốt phiên ⚠️ (bản đánh giá nói nạp lúc mở app: người
  chưa tải mô hình không nên trả RAM).
- MediaPipe chạy trên luồng native; Dart chỉ `await`. **Không** dựng `Isolate.run` ⚠️; điều kiện 7
  của mục 13 kiểm bằng **khung hình trên máy thật** khi sinh câu (bảng đo P1/P3).
- Chỉ **`slm_runtime.dart`** được import `flutter_gemma` (test quét, cùng khuôn `realtime_socket.dart`).

### 4.4. Bộ chắn — `kiem_so.dart`

`kiemSo(cau, goiSo) → bool`: trích **mọi** chuỗi số trong câu (mẫu: chữ số có thể kèm `.` ngăn
nghìn, `,` thập phân, hậu tố `%` hoặc ` đ`), chuẩn hoá về số, mỗi số phải trùng một `SoLieu.soTho`
của gói (sai số nửa đồng / 0,05 điểm phần trăm). Lệch → **rơi về mẫu câu**, ghi `debugPrint`. Có ca
test với câu bịa có chủ ý. Hỏi đáp tự do thêm **blocklist chủ đề** (đầu tư, chứng khoán, tiền mã hoá,
vay ngân hàng, thuế) → trả câu cố định "Mình chỉ nhận xét được trên số liệu của bạn trong app".

### 4.5. Cache

`slm_cache.dart`: `Map<dauVan, cau>` trong bộ nhớ + tệp JSON nhỏ ở thư mục app (≤ 200 mục, LRU).
Stream phát lại với gói số không đổi → **không gọi mô hình lần hai** (test canh bằng bộ đếm lời
gọi). Khối hiện **mẫu câu ngay**, thay bằng câu mô hình khi xong.

### 4.6. Màn Trợ lý AI

Dùng màn Stitch `75abffa9` có sẵn, bỏ nút ảnh/mic. Bốn chip = bốn gói số theo màn (`Tình hình ngân
sách`, `Phân tích chi tiêu tháng này`, `Dự báo tiết kiệm` = gói mục tiêu, `Gợi ý cắt giảm chi phí` =
kế hoạch tái phân bổ). Ô nhập tự do: gửi câu hỏi + **gói tổng hợp** (bốn gói) cho SLM, qua kiểm số
và blocklist; **không có mô hình thì ô nhập bị khoá** kèm dòng dẫn tới màn Cài đặt AI. Trả lời hiện
kèm thẻ số liệu. Không lưu lịch sử hội thoại qua phiên.

---

## 5. Giao diện và Stitch

**Bốn màn Stitch mới**, vẽ ở đầu P2 (ba màn đầu) và đầu P3 (màn cuối), người dùng nghiệm thu trên
Stitch trước khi dựng Flutter (memory `dua-man-moi-len-stitch`):

1. Khối "Nhận xét" — một màn ghép bốn biến thể (Ngân sách · Phân tích · Trang chủ · Mục tiêu),
   gồm câu, thẻ số liệu, nhãn "AI", trạng thái thiếu dữ liệu.
2. Thẻ + sheet kế hoạch tái phân bổ (tick từng dòng, sửa số, Áp dụng / Bỏ qua, hai màu trạng thái).
3. Công tắc "Cố định" trong màn Thêm/Sửa danh mục (`fa15f342` là màn hiện có).
4. Màn Cài đặt AI: trạng thái mô hình, nút tải (dung lượng, Wi-Fi), tiến độ, xoá, công tắc "Dùng AI
   trên máy".

Trang chủ: khối Nhận xét **thay** thẻ "Insight AI" chữ tĩnh → đóng **A6**. Màn Trợ lý AI: 5 handler
rỗng được nối hoặc gỡ → đóng phần ấy của **A11** (cập nhật danh sách trong
`khong_co_nut_chet_test.dart`). Không đổi cấu trúc menu.

Ba bẫy giao diện phải nghiệm thu máy ảo 411dp: bố cục khối ở cả bốn màn với câu dài nhất, sheet với
số dòng lớn, và trang Phân tích vốn đã 13 khối — khối Nhận xét đứng **ngay dưới hai thẻ tổng**.

---

## 6. Kiểm thử và nghiệm thu

TDD từng bước, test đỏ trước; ca xanh ngay từ đầu phải thử **bản sai có chủ ý**.

**Tầng thuần** (phần lớn test): luật thâm hụt (dưới/trên 5 ngày, không lịch sử, ngưỡng kép),
nguồn bù (có · cạn · không ngân sách · cờ Cố định thắng dư địa lớn · trần 25 %/15 % · làm tròn ·
ngưỡng có nghĩa), mẫu câu bốn màn (kể cả thiếu dữ liệu, nền 0 không in %), `dauVanCua` (đổi một số
là đổi khoá, đổi thứ tự không đổi khoá), `kiemSo` (câu bịa bị chặn, số đúng lọt, `%` và `đ`),
cache (không gọi lần hai), bậc thang RAM, blocklist.

**Ba test quét `lib/` mới**: (14) `ai_edge` không chứa phép so chiều tiền / không đọc bảng giao
dịch; (15) hai thứ cục bộ v24 không lọt vào đường đồng bộ; (16) chỉ `slm_runtime.dart` import
`flutter_gemma`. Cộng cập nhật `khong_co_nut_chet_test.dart` và `o_nhap_tien_co_tran_test.dart` (ô
sửa số trong sheet).

**Widget test**: thẻ số liệu in đúng chuỗi của gói; sheet tick từng dòng và tổng thay đổi; khối ẩn
nhãn "AI" khi câu từ mẫu; Trang chủ không còn "Insight AI".

**Máy ảo 411dp**: bố cục bốn màn, sheet, nhánh mẫu câu (mô hình không nạp được ở x86_64).
**Máy thật**: bảng đo P1 và P3 (nạp, câu đầu, câu tiếp, RAM, khung hình, 10 câu liên tiếp), tắt
mạng vẫn trả lời, không request nào đi ra (điều kiện 6–8, 16).

`sync_payload_contract_test.dart` **không đổi**; `flutter test`/`flutter analyze` ở mức nền.

---

## 7. Tài liệu và cách chia kế hoạch

- **Mới**: `docs/AI_EDGE_FEATURE.md` (client) — quyết định kèm lý do, bảng đo, bẫy; viết khung
  ngay đầu P2 và cập nhật theo từng task.
- **Mới**: `docs/superpowers/backend/CAN-LAM/AI_EDGE_SLM_SUA_TAI_LIEU.md` — xin backend sửa 5 chỗ
  (mục 4 bản đánh giá) và viết lại 39 luật theo bảng mục 11 (22 giữ / 13 sửa / 4 hoãn), cộng đính
  chính mô hình (Gemma 3 4B → Gemma 4). Không xin đổi mã, không xin schema.
- **Sửa**: banner đính chính đầu `AI_EDGE_SLM_DANH_GIA_AP_DUNG.md` (đã làm 2026-09-19); mục 14
  `PROJECT_CONTEXT.md`; hàng mới "Đụng vào AI Edge-SLM" ở bảng "Đọc gì trước khi làm" `CLAUDE.md`;
  `docs/NOTIFICATION_FEATURE.md` (loại thứ 19); `docs/CLIENT_APP_KNOWN_GAPS.md` (A6, A11).
- **Kế hoạch thi công**: ba tệp riêng ở `docs/superpowers/plans/` — `P0` nâng Flutter, `P2` tầng
  Edge, `P3` SLM. P1 không có kế hoạch, chỉ có bảng đo. Thi công **inline trong phiên**, commit
  sau mỗi task, tài liệu cập nhật trong chính task.

---

## 8. Đối chiếu 17 điều kiện (mục 13 bản đánh giá)

| # | Điều kiện | Đóng ở |
|---|---|---|
| 1 | Gói số ≥ 2 màn từ hàm domain | P2 mục 2 (4 màn), test quét 14 |
| 2 | Thâm hụt + nguồn bù trên ngân sách thật | P2 mục 3.1 |
| 3 | Cờ Cố định, luật tôn trọng | P2 mục 3.3 |
| 4 | Bảng phản hồi cục bộ, không đồng bộ | P2 mục 3.3, test quét 15 |
| 5 | Nhánh thiếu dữ liệu trung thực | P2 mục 2.3 |
| 6 | Mô hình chạy trên máy, không mạng | P3, đo máy thật |
| 7 | Giao diện không đứng | P3, đo khung hình ⚠️ (không `Isolate.run`) |
| 8 | Thời gian đo trên máy thật | P1 + P3 bảng đo |
| 9 | Mô hình chỉ nhận gói số | P3 mục 4.3 (kiểu đầu vào là `GoiSo`) |
| 10 | Bộ kiểm số | P2 viết, P3 dùng — mục 4.4 |
| 11 | Rơi về mẫu | mục 4.1, máy ảo nghiệm thu |
| 12 | Thẻ số liệu bằng số gói | mục 2.2, widget test |
| 13 | Cache theo dấu vân | mục 4.5 |
| 14 | Không đổi schema đồng bộ | v24 chỉ cục bộ; hợp đồng payload không đổi |
| 15 | Stitch trước | mục 5 |
| 16 | Máy ảo + máy thật, ảnh chụp | mục 6 |
| 17 | test/analyze mức nền | mọi task |

---

## 9. Rủi ro còn lại

| Rủi ro | Chặn |
|---|---|
| Nâng Flutter vỡ gói ghim | P0 tách riêng, commit riêng, có thể hoàn tác một commit |
| Gemma 4 E4B tiếng Việt kém hoặc quá nóng | P1 đo trước; nếu kém → E2B hoặc đổi vai mô hình sang **chọn câu** trong vài mẫu (mục 10.2 bản đánh giá) |
| Tải 4,3 GB thất bại giữa chừng | HuggingFace CDN không resume; gói có retry; người dùng huỷ/tải lại; mẫu câu chạy trong lúc chờ |
| Người dùng có ít ngân sách nên hiếm khi có nguồn bù | Trạng thái `thieuNguonBu` là câu thật; **không** làm luồng "gợi ý tạo ngân sách" ở lượt này (để sau) |
| Stream phát lại sau đồng bộ gọi mô hình liên tục | cache theo dấu vân, test bộ đếm |
| Hai bộ cảnh báo ngân sách | chỉ thêm một `NotificationKind` vào bộ luật hiện hành |
