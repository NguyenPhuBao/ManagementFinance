**Ngày:** 2026-09-22 (tối muộn) · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat` @ `1db8b5c`
**Tệp xin sửa:** `docs/AI/AI_Edge-SLM.md/Client-app.md` (NPBao, bản `b147fee` ngày 2026-09-22) —
tệp do backend quản nên client **không tự sửa**, kể cả một dòng.
**Việc xin:** **chỉ sửa chữ.** Không đổi mã backend, không migration, không trường payload mới.

---

## 0. Trước hết: lượt sửa `b147fee` đã làm đúng phần được xin

Lệnh nghiệm thu mà tệp `AI_EDGE_SLM_SUA_TAI_LIEU.md` đặt ra đã chạy lại hôm nay và ra **0 dòng**:

```bash
grep -n "v21\|PCI-DSS\|iOS 18\|Gemma 2B\|2B, quantized\|3 \* avg_spend\|local_category_features\|local_ai_alert_history" "docs/AI/AI_Edge-SLM.md/Client-app.md"
```

Cả năm điểm của đơn cũ đều đã sửa, thuật ngữ *Edge AI* đã đồng bộ (`grep "AI Edge"` trong `docs/AI/`
ra **0** dòng), và `Standard_RAG.md` §6 đã chốt lối ①. Hai tệp xin ấy client chuyển sang `DA-XONG/`
cùng lượt này.

Đơn này là **vòng hai**, mở ra vì một lượt đối chiếu lại toàn bộ tài liệu với mã client hôm nay tìm
được **11 chỗ** nữa — trong đó **4 cặp là tài liệu tự nói ngược chính nó**, và cả bốn cặp đều nằm
trong phạm vi lượt sửa vừa rồi. *(Bổ sung 2026-09-23: thêm **một** chỗ — mục **3.6**, dòng 290 tả
màn chat là "chưa nối API nào" — lượt soát ngày 22 bỏ sót; nay là 12.)*

🛑 **Một chỗ trong số đó là lỗi của client, không phải của backend** — xem mục 2. Backend đã chép
**đúng nguyên văn** câu mà client đưa; câu ấy lạc hậu vì client đổi mã hai ngày sau khi nộp đơn mà
quên sửa đơn còn đang nằm trong hàng đợi.

Số dòng dưới đây là của bản `b147fee`. Xin `grep` theo cụm chữ vì dòng sẽ trôi sau mỗi lần sửa.

---

## 1. Bốn cặp tài liệu tự nói ngược chính nó

Mỗi cặp là hai câu **trong cùng một tệp**, cùng nói về một thứ, và nói ngược nhau. Người đọc sau
không có cách nào biết câu nào mới đúng.

### 1.1 Chọn mô hình theo RAM hay không — §3.4 (dòng 278) ⟷ H3 (dòng 394)

| Dòng | Đang nói gì |
|---|---|
| **278** (§3.4) | *"**Không** chọn mô hình theo RAM thiết bị: phép đo cho thấy RAM đỉnh phụ thuộc **backend** (GPU ~0,96 GB, CPU 1,7–3,3 GB) chứ không phụ thuộc cỡ mô hình."* |
| **394** (H3) | *"Với các thiết bị có **RAM khả dụng < 4.0 GB** … Tầng 3 tự động chuyển sang bộ sinh câu mẫu."* |

**Mã client không đọc RAM ở đâu cả.** Quét `lib/` không có `availableRam` / `memoryInfo` /
`totalMem`. Bậc thang thật là:

1. `try/catch` quanh `getActiveModel()` — gói `flutter_gemma` tự nêu tên ABI, `install()` vẫn thành
   công rồi mới hỏng ở bước nạp, nên không tự đọc ABI được.
2. **Canary GPU** (`lib/features/ai_edge/domain/canary_gpu.dart`) — ghi một dấu trước
   `getActiveModel`, xoá trong `finally`; dấu còn sót ở lần mở sau nghĩa là lượt trước **sập
   native**, và máy ấy đi CPU vĩnh viễn. Cần canary vì crash native **không phải exception**:
   `try/catch` không bắt được (đo thật trên Mali-G77, `slm_runtime.dart:76-77`).
3. Không phải `arm64-v8a`, chưa tải mô hình, hoặc runtime lỗi → mẫu câu.

**Câu thay thế đề nghị cho H3:**

> Khi thiết bị không phải kiến trúc `arm64-v8a`, chưa tải mô hình, hoặc thư viện suy luận SLM gặp
> lỗi runtime → Tầng 1 và Tầng 2 vẫn chạy bình thường, Tầng 3 tự động chuyển sang bộ sinh câu mẫu
> **Template String Engine** mà không gây crash app hay báo lỗi kỹ thuật. **Không dùng ngưỡng RAM
> làm điều kiện** (xem §3.4): nạp GPU có thể sập ở tầng native — nơi `try/catch` của Dart không với
> tới — nên điều kiện thật là một **dấu canary** ghi trước khi nạp và xoá sau khi nạp xong; dấu còn
> sót ở lần mở sau nghĩa là lượt trước đã sập, và máy ấy chuyển sang CPU.

### 1.2 `saving_goal_ratio` đã chốt hay chưa — D3 (dòng 346) ⟷ dòng 202

| Dòng | Đang nói gì |
|---|---|
| **202** | *"`saving_goal_ratio` **chưa tồn tại** ở client … **Trước khi D3/D5 chạy được, phải chốt** một trong hai: (a) thêm một thiết lập … hoặc (b) suy … từ tổng số tiền các mục tiêu **còn hạn**…"* |
| **346** (D3) | *"Tỷ lệ mục tiêu tiết kiệm (`saving_goal_ratio`) **được suy trực tiếp** từ các mục tiêu còn hạn trong bảng `Goals`."* |

Dòng 346 đọc như **đã chốt phương án (b)**, dòng 202 vẫn nói **chưa chốt**. Và **client chưa có hàm
nào** làm việc ấy: `tyLeTietKiem` (`features/analytics/domain/dong_tien_tu_do.dart:78`) là **tỉ lệ
để dành thực tế** — `(thu nhập − chi) / thu nhập`, dùng cho một dòng ở trang Phân tích — chứ không
phải tỉ lệ *mục tiêu*, và nó không đọc bảng `Goals`.

**Đề nghị:** chọn một trong hai, rồi sửa **cả hai dòng** cho khớp.

- Nếu chốt (b): giữ D3 như hiện tại, và **sửa dòng 202** thành *"Phương án (b) đã được chốt (xem
  D3); client chưa thi công — chưa có hàm nào suy `saving_goal_ratio` từ `Goals` tính tới
  2026-09-22."*
- Nếu chưa chốt: sửa D3 thành *"`saving_goal_ratio` **chưa chốt nguồn** (xem lưu ý ở Phần II). AI
  tuyệt đối không sửa số tiền đích hay thời hạn của mục tiêu."*

Client nghiêng về **(b)**, vì nó không cần schema mới và đọc được ngay từ `Goals.targetDate` +
`autoDepositAmount`.

### 1.3 Nguồn của `is_recurring_hint` — §1.2 (dòng 84) ⟷ dòng 79

| Dòng | Đang nói gì |
|---|---|
| **79** | *"`is_recurring_hint` (nếu **người dùng đã gắn nhãn** "định kỳ")"* |
| **84** | *"`is_recurring_hint` được **suy trực tiếp từ bảng `Bills`** và lịch trích tự động của `Goals`"* |

Một trường, hai nguồn khác hẳn nhau: một cái do người dùng bấm, một cái suy ra. **Đề nghị** sửa
dòng 79 cho khớp dòng 84 — client không có nhãn "định kỳ" nào cho người dùng bấm, và cũng không
định thêm.

### 1.4 Cửa sổ thu nhập — B5 (dòng 321) ⟷ D1 (dòng 344)

Cặp này là mục 2 dưới đây, vì nó có thêm một lớp nữa.

---

## 2. 🛑 Chỗ client đưa sai — D1 (dòng 344), xin sửa lại

**Đây là lỗi của client, xin nhận trước.** Đơn `AI_EDGE_SLM_SUA_TAI_LIEU.md` (viết `ee9256b`, ngày
**2026-09-19**) đề nghị nguyên văn câu *"trung bình **ba tháng liền trước** của thu nhập"*, và
backend đã chép đúng câu ấy vào D1. Nhưng client **đổi mã ngày 2026-09-21** — sau khi nộp đơn hai
ngày — và quên rằng đơn vẫn đang nằm trong hàng đợi.

Điều trớ trêu: **chính backend đã viết đúng ở B5 (dòng 321)**, ngay trong cùng lượt sửa:

> *"mức chi mượn từ `BudgetRepository.suggestAmount` (cửa sổ cuộn ≤ 90 ngày) … **(Lưu ý: Không dùng
> cửa sổ 3 tháng lịch cố định vì dễ bị rỗng trên dữ liệu thật)**."*

Câu ấy đúng, và D1 ngay dưới nó thì nói ngược.

**Vì sao chuyện này không phải chi tiết vụn:** cửa sổ "ba tháng lịch liền trước" là thứ đã **chết im
lặng suốt hai tuần** trên chính dự án này. Giao dịch sớm nhất trong **toàn bộ** CSDL là
**02/09/2026**, nên ba tháng lịch đã đóng luôn rỗng trên **mọi** tài khoản: gợi ý hạn mức chưa từng
hiện một con số nào từ 2026-09-06 tới 2026-09-21, và phép neo ngưỡng theo thu nhập luôn rơi về sàn
`50.000 đ` — tức nó đúng từng dòng mã mà **chưa từng có hiệu lực**. Bộ test không bắt được vì nó
dựng sẵn ba tháng dữ liệu; thứ bắt được là một phép đo trên CSDL thật.

**Mã hiện tại** — `lib/features/budget/domain/cua_so_nhin_lai.dart` là **định nghĩa duy nhất**, và
`TaiPhanBoNguonImpl._thuNhapMoiThang` (`features/budget/data/tai_phan_bo_nguon.dart:106-152`) dùng
đúng nó:

- Cửa sổ là `[from, now)` với `from = max(now − 90 ngày, giao dịch đầu tiên của TÀI KHOẢN)`.
- Dưới **14** ngày trả `null` và người gọi **im hẳn** — `null` nghĩa là *chưa đủ để nói*, không phải
  *bằng 0*.
- Quy về mức tháng bằng `tổng / số ngày × 30`.
- Luật thu nhập **giữ nguyên**: vẫn đi qua `thuNhapCua` (tổng thu trừ tiền đi vay, thu nợ và khoản
  vay/nợ tiền vào). Chỉ **cửa sổ** đổi.

**Câu thay thế đề nghị cho D1:**

> Giá trị `income` đưa vào Tầng 2 là **thu nhập quy về mức mỗi tháng, suy từ một cửa sổ nhìn lại
> cuộn theo ngày** — `[max(now − 90 ngày, giao dịch đầu tiên của tài khoản), now)`, quy về tháng
> bằng `tổng / số ngày × 30`; dưới 14 ngày dữ liệu thì **không trả số nào** và bên gọi im hẳn.
> Định nghĩa duy nhất ở `features/budget/domain/cua_so_nhin_lai.dart`. Luật thu nhập theo
> `thuNhapCua` (`features/analytics/domain/dong_tien_tu_do.dart`): tổng thu trừ tiền đi vay, thu nợ
> và khoản vay/nợ tiền vào. Không lưu vào bảng riêng; tính tại chỗ.
> ⚠️ **Không dùng "ba tháng lịch liền trước"** — cùng lý do đã ghi ở B5: trên dữ liệu thật con số ấy
> rỗng, và một hàm đúng từng dòng mà đầu vào rỗng thì vẫn vô dụng, **im lặng**.

---

## 3. Sáu chỗ lệch mã client đang chạy *(năm chỗ ngày 22 + mục 3.6 bổ sung 2026-09-23)*

### 3.1 B2 (dòng 318) — thi hành ở đâu

Đang nói: *"Thi hành trực tiếp trong **bộ luật thông báo hiện hành (`notification_rules.dart`)**,
không dựng thêm bộ cảnh báo thứ hai."*

Vế sau đúng, vế trước **sai chỗ**. Ngưỡng kép nằm ở
`lib/features/ai_edge/domain/tai_phan_bo.dart:24-25`:

```dart
const double kNguongThamHutTiLe = 0.10;
const double kNguongThamHutTuyetDoi = 50000;
```

`notification_rules.dart` **nhận** kế hoạch đã dựng chứ không tự tính — chính chú thích của nó
(`:196`) nói thế, và nói cả lý do: *"Tính lại ở đây là bản thứ hai của một luật 39 điều — hai bản sẽ
nói hai chuyện khác nhau trên cùng một màn hình, im lặng."*

**Câu thay thế:** *"Thi hành ở `features/ai_edge/domain/tai_phan_bo.dart` (`kNguongThamHutTiLe`,
`kNguongThamHutTuyetDoi`) — **định nghĩa duy nhất**. Bộ luật thông báo `notification_rules.dart`
**nhận** kế hoạch đã dựng từ `taiPhanBoCua` chứ không tự tính lại, để trang Ngân sách và thông báo
không bao giờ nói hai con số khác nhau."*

⚠️ Hai hằng ấy nay là **sàn** chứ không phải giá trị cố định — xem 3.4.

### 3.2 D5 (dòng 348) — client **cố ý bỏ**

Đang mô tả như một quy tắc đang áp dụng. Mã nói ngược, và nói rõ lý do
(`tai_phan_bo.dart:10-12`):

> *"**D5 bỏ**: tái phân bổ giữ tổng hạn mức không đổi (cắt X thì cộng X), nên trần
> `Σ hạn mức ≤ thu nhập × (1 − tỉ lệ tiết kiệm)` không thể bị vi phạm bởi bước này."*

Tức D5 không sai về nguyên tắc — nó **không áp dụng được cho bước tái phân bổ**, vì bước ấy là một
phép chuyển chỗ có tổng bằng 0. Nó chỉ có nghĩa cho một bước *đặt hạn mức mới*, thứ client chưa làm.

**Đề nghị:** giữ D5 nhưng thêm *"(Không áp cho bước tái phân bổ: bước ấy giữ tổng hạn mức không đổi
— cắt X thì cộng X — nên trần không thể bị vi phạm. D5 dành cho bước đặt hạn mức mới, chưa thi
công.)"*

### 3.3 H1 (dòng 392) — `Isolate` / `compute()` chưa dùng ở đâu

Đang nói: *"**BẮT BUỘC PHẢI CHẠY TRONG DART ISOLATE / `compute()`**. Tuyệt đối không chạy trên Main
UI Thread."*

Quét `lib/`: **0 chỗ** gọi `compute(` hay `Isolate.` trong mảng AI (hai chỗ duy nhất nhắc `Isolate`
nằm ở `core/notification/`, là background isolate của thông báo hệ điều hành — không liên quan).

Thực tế đo được:

- **Tầng 1–2** là hàm thuần chạy trên main isolate. Chúng đọc vài trăm hàng, không đo được độ giật
  nào trên máy thật.
- **Tầng 3** không cần isolate Dart: `flutter_gemma` chạy qua platform channel nên suy luận đã nằm ở
  **thread native** rồi. Bảng đo mục 9 `AI_EDGE_FEATURE.md`: nạp 8.654 ms, câu đầu 3.291 ms, mà UI
  vẫn nhận thao tác suốt lượt sinh.

**Đề nghị:** hoặc đánh dấu *(Hoãn — chưa cần, xem lý do)*, hoặc sửa thành mô tả đúng:

> Tầng 3 chạy ở thread native của thư viện suy luận (platform channel), nên không cần Dart Isolate.
> Tầng 1–2 là hàm thuần trên main isolate: chúng đọc vài trăm hàng và chưa đo được độ giật nào. Nếu
> về sau tầng 1 phải quét toàn bộ lịch sử nhiều năm thì chuyển sang `compute()`, và đó là lúc quy
> tắc này có hiệu lực.

### 3.4 G1 (dòng 380) — bước làm tròn nay **neo theo thu nhập**

Đang nói: *"bắt buộc phải làm tròn đến bội số của **10.000đ** (hoặc 50.000đ)"*.

Từ 2026-09-21 client neo **ba** ngưỡng và **bước làm tròn** vào thu nhập, qua một phép duy nhất
`_neo(thuNhap, tiLe, san) = max(tiLe × thu nhập, san)`
(`features/ai_edge/domain/tai_phan_bo.dart:57-92`). Hằng cũ thành **sàn**:

| Thứ | Tỉ lệ theo thu nhập | Sàn (hằng cũ) |
|---|---|---|
| `nguongCoNghia` (C5) | 1 % | 50.000 đ |
| `nguongThamHutTuyetDoi` (B2) | 1 % | 50.000 đ |
| `duDiaToiThieu` (C4) | 2 % | 100.000 đ |
| `buocLamTron` (G1) | 0,2 % | 10.000 đ |

Lý do: một hằng tuyệt đối là một câu nói *"mọi người dùng giống nhau"*. Người thu nhập 5 triệu và
người 50 triệu từng dùng chung ngưỡng thâm hụt 50.000 đ. Bước làm tròn còn đi qua `buocTron` để rơi
vào họ 1·2·2,5·5 × 10^k, nên nó không ra những bước lẻ như 13.000.

**Đề nghị:** *"làm tròn đến bội số của bước `buocLamTron = max(0,2 % thu nhập mỗi tháng, 10.000đ)`,
quy về họ 1·2·2,5·5 × 10^k. 10.000đ là **sàn**, áp cho tài khoản chưa có thu nhập hoặc thu nhập
thấp."*

### 3.5 F3 (dòng 370) — không có cơ chế "không cấp quyền Socket/HTTP"

Đang nói: *"Thư viện suy luận mô hình SLM (MediaPipe / llama.cpp) **được cấu hình** chạy ở chế độ
Offline 100%, **không cấp quyền mở Socket hay HTTP Request** ra Internet."*

Không có cấu hình nào như vậy, và không thể có: quyền `INTERNET` là của **cả app**, và app **bắt
buộc** phải có nó để đồng bộ (`android/app/src/main/AndroidManifest.xml:25` — quyền này từng chỉ khai
ở `debug/`, làm mọi bản `--release` mất mạng im lặng; đó là một trong bốn lỗi của lượt nghiệm thu
2026-09-22).

Bảo đảm **thật** của F3 gồm ba thứ, và cả ba kiểm được:

1. **Phép đo trên máy thật:** cắt sạch mạng, mô hình vẫn trả lời trong **1.898 ms** với **0 request
   đi ra** (mục 9 `AI_EDGE_FEATURE.md`).
2. **Một test quét `lib/`** (`features/ai_edge/chi_mot_noi_import_gemma_test.dart`) cấm mọi tệp trừ
   `slm_runtime.dart` import `flutter_gemma` — nên đường gọi mô hình chỉ có một cửa.
3. Gói không nhận URL nào: nó nạp từ **tệp cục bộ** đã tải sẵn.

**Câu thay thế:** *"Thư viện suy luận SLM không thực hiện bất kỳ lời gọi mạng nào — nó nạp mô hình
từ tệp cục bộ đã tải sẵn. Bảo đảm bằng ba lớp: (1) phép đo trên máy thật khi cắt mạng — vẫn trả lời,
0 request đi ra; (2) test quét cấm mọi tệp trừ một tệp runtime duy nhất được import gói suy luận;
(3) không có URL nào trong đường gọi mô hình. ⚠️ Không mô tả đây là "không cấp quyền mạng": quyền
`INTERNET` là của cả ứng dụng và **bắt buộc phải có** cho đồng bộ offline-first."*

### 3.6 Dòng 290 — màn chat *"chưa nối API nào"* *(bổ sung 2026-09-23; lượt soát ngày 22 bỏ sót)*

Đang nói: *"Màn hình chat `lib/features/ai_chat/presentation/pages/ai_chat_page.dart` (436 dòng) đã
tồn tại sẵn trên client và **chưa nối API nào**. Tầng 3 nên tích hợp trực tiếp vào màn hình này thay
vì dựng mới."*

Vế sau **đã làm đúng như đề nghị**; vế đầu sai từ 2026-09-22 và sai thêm từ 2026-09-23:

1. **2026-09-22 (P3):** màn chat nối mô hình Gemma 4 E2B trên máy — hỏi đáp tự do, chữ hiện dần theo
   câu, ba lớp chắn `kiemSo` / `kiemNhan` / `kiemGiong` trước khi hiện (`AI_EDGE_FEATURE.md` mục 9).
2. **2026-09-23 (chặng 4b):** màn đi **bậc tool** — mô hình tự chọn một trong **bốn tool chỉ đọc**
   (`danh_sach_ngan_sach` · `danh_sach_hoa_don` · `danh_sach_vi` · `chi_tieu_theo_ky` — đổi tên thành
   `tong_ket_thu_chi_ky` ngày 2026-09-24 chiều), app chạy hàm
   domain có sẵn và trả hàng có tên; chưa tool nào chạy thì rơi về đường P3 (`AI_EDGE_FEATURE.md`
   mục 9.14). Vẫn **không** gọi API server nào: mọi thứ chạy trên máy.
   **2026-09-24 (bước 2):** thêm ba tool chỉ đọc — `danh_sach_muc_tieu` · `goi_y_han_muc` · `tim_giao_dich`
   — nên bậc tool nay có **bảy** tool; vẫn không tool nào ghi và không gọi API server nào
   (`AI_EDGE_FEATURE.md` mục 9.17).
   **2026-09-24 (bước 2b):** câu *"chưa tool nào chạy thì rơi về đường P3"* nay có thêm một nhánh — mô hình
   **có** gọi tool mà **mọi** lời gọi bị tool từ chối (tham số sai) thì màn hiện một **mẫu câu trung thực** nêu
   lý do (*"Chưa tra được số liệu cho câu này: …"*), **không** rơi về đường P3 (`AI_EDGE_FEATURE.md` mục 9.18).
   **2026-09-24 (bước 2c):** thêm một nhánh nữa — tool tìm giao dịch chạy được nhưng **0 khoản** khớp bộ lọc
   mô hình đã điền thì màn hiện **mẫu câu nêu bộ lọc** (*"Tháng này, ghi chú chứa "chi", đến 1.000.000 đ — không
   có giao dịch nào khớp."*), không hiện chữ của mô hình và cũng không rơi về đường P3 (mục 9.19).
3. Con số "436 dòng" là của bản tĩnh cũ; tệp nay dài hơn nhiều (`wc -l` trước khi trích).

**Câu thay thế:** *"Tầng 3 được tích hợp vào màn chat có sẵn `lib/features/ai_chat/presentation/pages/
ai_chat_page.dart` (không dựng màn mới): hỏi đáp tự do trên máy, mô hình chọn tool chỉ đọc để lấy dữ
liệu theo tên, mọi con số kiểm với dữ liệu trước khi hiện. Không gọi API server nào."*

---

## 4. Hai chỗ nên đánh dấu *(Hoãn)* cho nhất quán

Lượt sửa vừa rồi đã đánh dấu *(Hoãn — giai đoạn sau đồ án)* cho **A5, D2, D4, E4** — rất rõ ràng và
client hoan nghênh cách ấy. Nhưng còn hai quy tắc cùng trạng thái mà không được đánh dấu, nên người
đọc tưởng chúng đang chạy:

| Mã | Dòng | Trạng thái thật ở client |
|---|---|---|
| **H2** — pin < 15 % / thermal throttling | 393 | **Chưa có mã.** Quét `lib/features/ai_edge/` không có tham chiếu pin hay nhiệt độ nào. |
| **H1** — Isolate | 392 | Xem 3.3 — hoặc hoãn, hoặc sửa thành mô tả đúng. |

---

## 5. Một cảnh báo thiết kế, không phải lỗi tài liệu — A1 / A2 (dòng 304–305)

Hai luật nay neo vào `nguongChiLon` (ngưỡng Khoản chi lớn, người dùng đặt). Client đồng ý hướng
này — nó đúng với dữ liệu thật, vì tài khoản thật chỉ có **8 ngày** dữ liệu và danh mục đông nhất
chỉ **5** giao dịch (đo 2026-09-17), nên một luật thống kê sẽ im hàng tháng rồi nổ bừa ngay khi vừa
đủ mẫu.

Nhưng xin ghi thêm một câu cảnh báo, vì nó là loại hỏng **im lặng**:

> ⚠️ `nguongChiLon` **mặc định bằng 0, nghĩa là tắt** (`NotificationPrefs`, cùng khuôn
> `nguongSoDuThap`). Với người dùng chưa đặt ngưỡng, A1 và A2 **không lọc giao dịch nào** — baseline
> nhận cả khoản mua xe máy. Đó là hành vi đúng (không có ngưỡng thì không có "bất thường"), nhưng
> Tầng 1 phải coi `nguongChiLon == 0` là *"không áp A1/A2"* chứ không phải *"mọi khoản đều vượt
> ngưỡng 0"* — đọc nhầm chiều là loại sạch mọi giao dịch khỏi baseline.

Ngoài ra A1/A2/A6 và §1.2 mô tả tầng 1 mà client **chưa thi công** (mảng `ai_edge/` hiện chưa tham
chiếu `nguongChiLon`, `Bills` hay `Goals` trong `tai_phan_bo.dart`). Đó không phải lỗi tài liệu —
đặc tả được phép đi trước — nhưng nếu tiện thì một dòng *"Tầng 1 chưa thi công tính tới
2026-09-22"* ở đầu nhóm A sẽ giúp người đọc sau khỏi đi tìm mã không tồn tại.

---

## 6. Kiểm lại bằng gì

Sau khi sửa, bốn lệnh sau phải ra **0** dòng:

```bash
F="docs/AI/AI_Edge-SLM.md/Client-app.md"

# 1. Không còn ngưỡng RAM làm điều kiện rơi bậc, không còn "ba tháng liền trước"
grep -n "RAM khả dụng < 4.0 GB\|ba tháng liền trước" "$F"

# 2. Không còn nói ngưỡng thâm hụt thi hành trong bộ luật thông báo
grep -n "Thi hành trực tiếp trong \*\*bộ luật thông báo" "$F"

# 3. Không còn khẳng định "không cấp quyền" mạng, không còn bắt buộc Isolate
grep -n "không cấp quyền mở Socket\|BẮT BUỘC PHẢI CHẠY TRONG DART ISOLATE" "$F"

# 4. (bổ sung 2026-09-23) Không còn tả màn chat là chưa nối gì
grep -n "chưa nối API nào" "$F"
```

Và một phép kiểm **chéo** — hai câu về cửa sổ thu nhập phải cùng nói một chuyện:

```bash
grep -n "cửa sổ cuộn\|3 tháng lịch\|ba tháng" "$F"
```

Client sẽ chạy lại cả năm lệnh sau khi backend báo xong, và đối chiếu từng mục 1–5 với mã như lượt
này.

---

## 7. Không xin gì thêm

Không đổi mã backend, không migration, không trường payload mới, không đổi schema. Mọi mục ở trên
là **sửa chữ trong một tệp tài liệu**.

Hai mục cần backend **quyết** chứ không chỉ sửa chữ:

1. **`saving_goal_ratio`** (1.2) — chốt phương án (a) hay (b). Client nghiêng về (b).
2. **H1 / H2** (mục 4) — đánh dấu *(Hoãn)* hay sửa thành mô tả đúng. Client nghiêng về sửa H1 thành
   mô tả đúng (vì lý do "không cần isolate" là một kết luận đã đo được, đáng ghi lại), và đánh dấu
   *(Hoãn)* cho H2.
