# C3 — Lệnh "tạo hoá đơn / mục tiêu / ngân sách" ở màn Trợ lý AI — thiết kế

**Ngày:** 2026-09-28 (tối). **Người dùng duyệt** bản thiết kế trong chat cùng ngày, với các lựa chọn: lệnh gõ ở **màn Trợ
lý AI** · **chỉ luật** (không mô hình) · làm cho **cả ba**: hoá đơn, mục tiêu tiết kiệm, ngân sách. Bất biến ④ nhóm C:
*"không tool nào ghi thẳng"*, tức trợ lý chỉ mở form điền sẵn và người dùng bấm **Lưu**. Tầng hậu quả 2. Thứ tự: C1 → C2 →
D1 → **C3** → C4. **Phụ thuộc C2** (bộ đọc số tiền / ngày / `khopTheoTen`) và **B2** (`/bills/add` nhận query điền sẵn).
**Không đổi schema.**

> ⚠️ **Soát với mã C2 đã thi công (2026-09-30, phiên soát tài liệu — spec này viết 28/09, trước C2).** Tên thật của bộ đọc
> C2: ngày **`timNgayTrongCau`** (`core/utils/ngay_trong_cau.dart`, trả `({ngay, batDau, ketThuc})`); số chữ
> **`timSoBangChu`** (`core/utils/so_bang_chu.dart`, có vị trí); **tên nêu trong câu** là `timTenTrongCau` /
> `tenNeuTrongCau` (`core/utils/khop_ten.dart`) — **`khopTheoTen` so TRỌN chuỗi**, chỉ dùng cho tên đã tách sẵn (tham số
> tool), không tìm được tên nằm giữa câu. ⚠️ **Bộ chọn số tiền của C2 (`_chonSoTien`, bốn cách nói + ưu tiên có đơn vị) là
> RIÊNG TƯ** trong `transaction/domain/doc_cau_giao_dich.dart`: C3 muốn *"cùng bộ đọc"* (§2.1) và *"vị trí trả về"* thì phải
> mở nó ra thành hàm công khai (một định nghĩa — đừng chép), việc của C3. `ai_edge/` import được `transaction/domain/`
> (test quét 14 `ai_edge_khong_tinh_test.dart` cấm **chuỗi** trong dòng mã, không cấm import) — nhưng ⚠️ chín chuỗi nó cấm
> gồm cả **`walletId`** (cùng `'thu'`, `'chi'`, `'transfer'`, `transactionDao`, `db.transactions`, `.type ==`, `amount <`,
> `amount >`): trường `LenhTaoHoaDon.walletId` của §2 đặt ở `ai_edge/domain/lenh_tao.dart` sẽ làm test ấy đỏ — đổi tên
> trường hoặc đặt tệp ngoài `ai_edge/` (như C2 đặt `DocCauBangAi` ở `transaction/data/`). Soát lại lần nữa trước Task 1 —
> C2 còn quyết định *"ĐỔI LẦN HAI"* chưa thi công (không đụng bộ đọc, chỉ đổi lúc nào gọi AI).

> ✅ **Soát lần hai trước Task 1 (2026-09-30 đêm)** — sau C2 đổi lần hai, D1, gợi ý chuyển khoản:
> (1) mở `_chonSoTien` thành hàm công khai trong `doc_cau_giao_dich.dart` (một định nghĩa); (2) trường ví / danh mục của
> lệnh tên **`idVi` / `idDanhMuc`** (test quét 14 cấm chuỗi `walletId` trong `ai_edge/`), khoá query vẫn `wallet` /
> `category`; (3) lưới 72 câu import thẳng **`kBang72Cau`** (`test/features/ai_edge/domain/dinh_tuyen_72_cau_test.dart`);
> (4) `/budget/rules` **không** nhận chu kỳ → bỏ `cycle` (đúng §4 "không nhận thì bỏ"); (5) ⚠️ **ô nhập màn Trợ lý bị khoá
> khi chưa có mô hình** (`enabled: _coMoHinh`) — mâu thuẫn với "chạy trên máy không có mô hình" ở §1. **Người dùng chốt:
> mở ô nhập** — câu là lệnh tạo thì chạy như thường; câu khác khi chưa có mô hình trả **một câu cố định** "cần tải mô
> hình", băng nhắc tải vẫn hiện.

## 1. Vì sao

Tạo một hoá đơn định kỳ hôm nay cần mở drawer → Hoá đơn → nút thêm → điền năm sáu ô. Người dùng đã quen nói với Trợ lý AI.
Một câu *"tạo hoá đơn Netflix 100k ngày 5 hằng tháng"* nên dẫn thẳng tới form đã điền. **Chỉ luật**, nên trả lời tức thì
(không lượt sinh 15–40 s), chạy trên máy không có mô hình, và không bịa số.

## 2. Nhận ra lệnh — `lib/features/ai_edge/domain/lenh_tao.dart`

`LenhTao? lenhTaoTheoCauHoi(String cau)`. Đặt ở `ai_edge/domain` cạnh `congCuTheoCauHoi` vì nó là **định tuyến câu của
trợ lý**. Phần **đọc số tiền / ngày** gọi hàm của C2 ở `core/utils` / `transaction/domain`: không đọc sổ giao dịch, nên
không phạm test quét 14.

- So trên chữ bỏ dấu, trọn âm tiết. **Là lệnh** ⇔ câu (bỏ tiền tố *hãy / giúp tôi / giúp mình / cho tôi / làm ơn*)
  **bắt đầu** bằng *tạo / thêm / đặt / lập* **và** ngay sau (cách ≤ 2 từ) là *hoá đơn* / *mục tiêu* / *ngân sách*
  **và** câu **không** có từ hỏi: *bao nhiêu · nào · nên · không · có nên · là gì · ?*.
- *"nên đặt ngân sách ăn uống bao nhiêu"* → `null` (câu hỏi, đi tool gợi ý hạn mức như hôm nay); *"đặt ngân sách ăn uống
  3 triệu mỗi tháng"* → lệnh ngân sách.
- ⭐ **Lưới an toàn:** ca test chạy **cả 72 câu cổng F** (`kBang72Cau` của kế hoạch A2 nếu đã có, không thì danh sách câu
  trong chính tệp test) và đòi `lenhTaoTheoCauHoi(c) == null` với **mọi** câu. Nhận nhầm một câu hỏi thành lệnh là câu
  hỏi ấy mất câu trả lời.

## 3. Đọc các ô

`sealed class LenhTao` với ba lớp con; trường nào `null` là *không đọc được*, form để trống ô ấy.

| Lớp | Trường | Cách đọc |
|---|---|---|
| `LenhTaoHoaDon` | `ten`, `soTien`, `chuKy` (`kBillCycle*`), `ngayGoc`, `walletId`, `categoryId`, `nhacTuTra` | tên = cụm sau *"hoá đơn"* tới trước số tiền / chữ chu kỳ / chữ ngày; chu kỳ = *hằng / mỗi / hàng* + *tuần / tháng / quý / năm* (mặc định **tháng** khi câu không nêu); ngày gốc = *"ngày N"* (1–31); ví / danh mục = `khopTheoTen` như C2 |
| `LenhTaoMucTieu` | `ten`, `soTienDich`, `han` | tên = cụm sau *"mục tiêu"*; hạn = *"trước / đến tháng M [năm Y / năm sau]"* → ngày cuối tháng ấy, *"trong N tháng"* → `now + N tháng` (kẹp ngày cuối tháng), *"đến dd/mm/yyyy"* |
| `LenhTaoNganSach` | `categoryId` (**bắt buộc**), `hanMuc`, `chuKy` | danh mục = `khopTheoTen` trên danh mục **chi** chọn được; không khớp → `categoryId = null` và thẻ nói *"Chưa rõ danh mục"*; chu kỳ mặc định tháng |

- Số tiền: **cùng** bộ đọc của C2 (bốn cách nói, ưu tiên có đơn vị, số trần ≥ 1.000).
- ⚠️ **Tầng 4 cấm:** câu có *tự trả / tự động thanh toán / trích tự động / tự động trích* → `nhacTuTra = true`, **chỉ**
  để thẻ nói *"Tự trả phải bật trong form"*. Deeplink **không** mang tham số bật tự trả hay trích tự động, và form **không**
  đọc tham số ấy dù có.

## 4. Trả lời ở màn Trợ lý AI

- `hoiBangCongCu` (hoặc lớp gọi nó ở màn chat) gọi `lenhTaoTheoCauHoi` **trước** mọi thứ khác: trước chặn chủ đề, trước
  định tuyến tool, trước mở phiên mô hình. Có lệnh → **không** mở phiên, **không** gọi mô hình; trả một tin nhắn loại mới
  `TinLenhTao` (không phải `NhanXet` / câu mô hình), log `[SLM] lệnh tạo <loại> → form`.
- Thẻ trong chat: *"Mình hiểu là: Tạo hoá đơn **Netflix** · 100.000 đ · hằng tháng, ngày 5"* (tiền qua
  `CurrencyFormatter`, chỉ in ô đọc được), dòng nhắc cho ô thiếu (*"Chưa rõ số tiền — bạn điền trong form"*), dòng tầng 4
  nếu có, nút **Mở form tạo {hoá đơn / mục tiêu / ngân sách}**.
- Đích:
  - hoá đơn → `/bills/add?name&amount&cycle&anchor&category&wallet` (query của B2; **không** `start`: hoá đơn mới bắt đầu
    hôm nay, còn hạn kỳ đầu tính từ ngày gốc);
  - mục tiêu → `/goals/add?name&target&deadline` (**mở mới**: `GoalAddPage` hôm nay chỉ nhận `goalId`);
  - ngân sách → `/budget/rules?category&amount` (đã có) cộng `cycle` nếu form ngân sách nhận được chu kỳ tháng / tuần; không
    nhận thì bỏ.
- Điều hướng bằng `push` (route ngoài shell) và quay về màn chat giữ nguyên lịch sử.
- ⚠️ Thẻ trong chat là giao diện mới → **Stitch trước**.

## 5. Không làm

Không mô hình. Không tự lưu. Không bật tự trả / trích tự động (tầng 4). Không sửa / xoá bản ghi có sẵn bằng lệnh. Không
lệnh cho giao dịch (đã có ô Nhập nhanh của C2). Không đổi schema.

## 6. Kiểm thử

- **Nhận lệnh:** mười câu lệnh (đủ ba loại, có / không tiền tố lịch sự, có dấu / không dấu) → đúng loại; mười câu hỏi gần
  giống (*"nên đặt ngân sách…"*, *"hoá đơn nào…"*, *"mục tiêu nào…"*, *"tạo hoá đơn thế nào?"*) → `null`; ⭐ 72 câu cổng F →
  `null` hết.
- **Đọc ô:** hoá đơn: tên / tiền / *hằng tuần* / *hằng năm* / *ngày 31*; mục tiêu: *"trước tháng 6 năm sau"* đọc ngày
  28/9/2026 → 30/6/2027; *"trong 12 tháng"* từ 31/1 → cuối tháng 1 năm sau; **tháng 2 năm nhuận**; ngân sách: danh mục
  khớp / không khớp; tầng 4: *"tự trả"* → `nhacTuTra`, deeplink không có tham số tự trả.
- **Màn chat:** câu lệnh → thẻ hiện ngay, **không** mở phiên mô hình (bản giả `SlmRuntime` đếm số lần mở = 0); bấm nút →
  push đúng URL; câu hỏi thường vẫn đi vòng tool như cũ.
- **Form mục tiêu:** query đủ → ba ô điền đúng; query hỏng → form trống, không ném; đường **sửa** mục tiêu không đọc query.
- **Máy thật:** năm câu lệnh gõ trên Realme → thẻ hiện < 1 s → form đúng → Lưu.

## 7. Tài liệu đi kèm

`AI_EDGE_FEATURE.md`: mục mới *Lệnh tạo (C3)* (thứ tự trước vòng tool, lưới 72 câu, chặn tầng 4). `GOAL_FEATURE.md`:
form mục tiêu nhận query điền sẵn. `CLAUDE.md` hàng *Đụng vào AI Edge-SLM*.
