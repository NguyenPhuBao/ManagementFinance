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

> 🔄 **ĐỔI LẦN HAI (người dùng duyệt 2026-09-30 đêm) — AI hiểu ý + điền ô, luật thành lưới kiểm và đường dự phòng: xem
> §8.** Mọi câu "chỉ luật / không mô hình" ở §1–§7 là của bản đầu.
>
> 🚧 **§8 — MÃ XONG Task 1–4 ngày 2026-10-01** (`3442495` → `24226cf`), **chưa đo Realme** (Task 5). Mục **9.43**
> `AI_EDGE_FEATURE.md`. **Bốn chỗ bản thi công khác §8**, đều có ca test + bản sai có chủ ý:
> (1) §8.3 *ví*: tên enum của AI khớp một ví **chưa đủ** — còn phải **câu nhắc ví** (chữ *ví* trần / viết tắt tên
> ví, `cauNhacViTheoTen` của C2); C2 đo Realme 9/10 câu mô hình tự điền ví mặc định.
> (2) §8.3 *ngày gốc*: chữ số phải nằm **ngoài đoạn số tiền** (số 5 của *"5 triệu"*).
> (3) §8.3 *hạn*: danh sách từ chỉ thời gian so **có dấu** khi câu có dấu (*tôi* ≠ *tới*, *cưới* ≠ *cuối*); bộ
> không dấu không có `toi`; thêm *tuần · quý*.
> (4) §8.4 *Huỷ*: lượt **dừng** (câu theo mẫu → thẻ luật; câu khác → *"Đã huỷ."*), **không** về vòng hỏi đáp —
> **chờ người dùng xác nhận**.
>
> ✅ **THI CÔNG XONG 2026-09-30 đêm** (`51d6a3c` → `89f2112`), nghiệm thu Realme: ba lệnh → thẻ < 1 s, ba form đúng;
> câu hỏi gần giống lệnh đi vòng tool như cũ — mục **9.42** `AI_EDGE_FEATURE.md`. Stitch thẻ lệnh gửi (timeout), chưa hiện
> lúc ấy; ✅ hiện ngày 2026-10-01: **`59454c61be704c2f882f8f625917951c`** — đối chiếu ở cuối §8.4.
>
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

---

## 8. ĐỔI LẦN HAI — AI hiểu ý + điền ô (người dùng duyệt 2026-09-30 đêm)

Sau khi dùng bản "chỉ luật" (§1–§7, thi công `51d6a3c` → `89f2112`), người dùng phản hồi: *"tôi muốn tạo bằng AI mới
đúng thay vì chỉ lệnh như này"*. Ba lựa chọn chốt bằng câu hỏi chọn:

1. **AI hiểu ý + điền ô** — nhận cả câu nói tự nhiên không theo mẫu (*"tôi muốn để dành 50 triệu mua xe trước hè năm
   sau"*, *"mỗi tháng trả tiền nhà 3 triệu vào mùng 5"*), luật thành **lưới kiểm** (khuôn C2 `docCauGiaoDich(ai:)`).
2. **Luật làm dự phòng** khi máy chưa có mô hình / tắt AI — bộ luật §2–§3 giữ nguyên cho câu theo mẫu *"tạo …"*.
3. **Cổng rộng + phiên AI riêng** — không thêm tool vào phiên sáu tool (trần token: phiên sáu tool đã 6.980 ký tự khai
   báo, chín tool từng vỡ trần — mục 9.34 `AI_EDGE_FEATURE.md`), không hai lượt sinh cho mọi câu.

§1 *"Chỉ luật … trả lời tức thì"* và §5 *"Không mô hình"* **hết hiệu lực** cho đường có mô hình; §2 bộ nhận lệnh và §3 bộ
đọc ô ở lại làm **đường dự phòng** và **lưới kiểm**.

### 8.1 Cổng rộng — `coVeLenhTao(String cau)` (`ai_edge/domain/lenh_tao.dart`, luật, không mô hình)

`true` ⇔ `loaiLenhTao(cau) != null` **hoặc** đủ ba vế:
- **không** từ hỏi (cùng `_tuHoi` của §2 + dấu `?`);
- nhắc một **đối tượng tạo được**: *hoá đơn · mục tiêu · ngân sách · để dành · tiết kiệm · dành dụm · quỹ · định kỳ ·
  hằng/mỗi/hàng + tuần/tháng/quý/năm*;
- có **tín hiệu muốn tạo**: động từ *tạo · thêm · đặt · lập · muốn · lên kế hoạch · nhắc* ở bất cứ đâu, **hoặc** một số
  tiền đọc được (`cachDocSoTien` khác rỗng).

So trên âm tiết bỏ dấu (`amTietKhongDau`). ⭐ Lưới **72 câu cổng F** (`kBang72Cau`) → `false` hết (ca test). Câu lọt cổng
mà mô hình không gọi tool nào → đi vòng hỏi đáp như cũ (chỉ tốn thêm một lượt chờ — đó là giá của cổng rộng).

### 8.2 Phiên AI — `DocLenhBangAi` (`ai_chat/data/doc_lenh_bang_ai.dart`)

Khuôn `DocCauBangAi` (C2, `transaction/data/doc_cau_bang_ai.dart`): cùng `SlmRuntime`, `sanSang` / `duongTep`, nạp một
`Future` dùng chung, `huy()`, thời hạn **45 s**, canary phiên có tool (`quaCanary`); mọi hỏng hóc trả `null`. Đặt ở
`ai_chat/` vì danh mục **chi** do bên gọi lọc (test quét 14). Lời hệ thống kèm **ngày hôm nay** (đọc *"hè năm sau"*,
*"cuối năm"*).

Ba tool, **đúng một** lời gọi mong đợi (không gọi tool = "không phải lệnh tạo"):

| Tool | Tham số (tất cả `required`, rỗng / 0 khi câu không nói) |
|---|---|
| `tao_hoa_don` | `ten` · `so_tien` (integer, đồng) · `chu_ky` (enum `tuan · thang · quy · nam`) · `ngay_goc` (integer 0–31) · `vi` (enum tên ví hoạt động + `''`) · `danh_muc` (enum tên danh mục chi + `''`) |
| `tao_muc_tieu` | `ten` · `so_tien_dich` (integer) · `han` (dd/mm/yyyy hoặc `''`) |
| `dat_ngan_sach` | `danh_muc` (enum tên danh mục chi + `''`) · `han_muc` (integer) |

⚠️ **Tầng 4:** không tool nào có tham số tự trả / trích tự động / lặp lại tự động. Kết quả thô: `KetQuaLenhAi` (loại +
các ô chuỗi / số thô). Trước khi thi công giao diện, **spike Realme** đo `toolsJsonCua(ba khai báo)` với enum danh mục
thật (≤ trần đo — hằng `kTranToolsJsonLenhDaDo` trong test, cùng khuôn `kTranToolsJsonDaDo`).

### 8.3 Lưới kiểm — `lenhTaoTuAi(cau, ai, {now, vi, danhMucChi})` (`ai_edge/domain/lenh_tao.dart`)

Kết quả AI **không bao giờ dùng thẳng**. Đọc luật trước (bộ đọc §3 trên chính câu), rồi AI chỉ **lấp ô luật để trống**,
mỗi ô qua một chốt:

| Ô | Luật đọc được | Luật để trống → nhận của AI khi |
|---|---|---|
| loại | câu theo mẫu §2 (`loaiLenhTao`) → loại của luật, AI **không đổi** | — (loại theo tool AI gọi) |
| số tiền / số tiền đích / hạn mức | luật thắng (kể cả khi số AI là một cách đọc hợp lệ) | câu có con số ấy: `cachDocSoTien(cau)` chứa nó (lệch ≤ 0,5), < 1e13 |
| tên (hoá đơn, mục tiêu) | — (AI đọc tên tốt hơn luật với câu tự nhiên) | tên AI **là đoạn con** của câu (so `removeVietnameseTones` + `normalizeCategoryName`), không chứa chữ số tiền; rỗng → dùng tên luật §3 |
| hạn mục tiêu | luật thắng | ngày hợp lệ (`ngayHopLe`), **sau** hôm nay, ≤ 50 năm, và câu có từ chỉ thời gian (*tháng · năm · tết · hè · cuối · đầu · trước · đến · trong · ngày · /*) |
| chu kỳ hoá đơn | luật thắng (`_mauChuKy`) | enum hợp lệ; không có → tháng |
| ngày gốc | luật thắng (`_mauNgayGoc`) | 1–31 **và** chữ số ấy có trong câu |
| ví / danh mục | tên luật tìm thấy trong câu (`timTenTrongCau`) thắng | tên enum của AI khớp **một** mục (`_idCua`) |
| tầng 4 (`nhacTuTra`) | chỉ luật | — |

Trả `LenhTao` (cùng ba lớp §3) kèm **`nguon`**: `ai` khi ít nhất một ô do AI lấp, ngược lại `luat` — thẻ ghi dòng
nguồn đúng thứ đã xảy ra (cùng tinh thần C2 *"Đọc bằng AI chỉ khi AI đổi một ô"*).

### 8.4 Màn chat

| Tình huống | Hành vi |
|---|---|
| có mô hình, `coVeLenhTao` | dòng chỉ báo *"Đang đọc lệnh bằng AI…"* kèm **Huỷ**; `DocLenhBangAi` → `lenhTaoTuAi` → thẻ, dòng nguồn **"Đọc bằng AI"** / **"Đọc bằng luật"** |
| có mô hình, AI trả `null` (hỏng / quá hạn / huỷ / không gọi tool) | câu theo mẫu §2 → thẻ luật; câu khác → vòng hỏi đáp như cũ |
| chưa có mô hình | câu theo mẫu §2 → thẻ luật (**"Đọc bằng luật"**); câu khác → câu cố định `cauKhoaHoiDap` (như bản §4) |
| không lọt cổng | vòng hỏi đáp như cũ (không phiên lệnh) |

- Thứ tự trong `_hoi`: cổng **trước** chặn chủ đề / định tuyến như bản §4.
- Log `[SLM][lenh] …` (thời gian, tool gọi, ô AI lấp).
- Thẻ: thay dòng *"Lệnh tạo · không cần mô hình"* bằng dòng nguồn; phần còn lại như bản §4.
- Stitch: dòng chỉ báo + dòng nguồn vẽ vào màn thẻ lệnh (màn *"Trợ lý AI - Thẻ lệnh tạo hoá đơn"*, gửi 2026-09-30, timeout,
  chưa hiện lúc viết) — **trước** Task giao diện.
  ✅ **Màn đã hiện — `59454c61be704c2f882f8f625917951c`** (kiểm 2026-10-01, tải HTML + ảnh). Nó vẽ **bản luật** (§4): chưa
  có dòng chỉ báo lẫn dòng nguồn. Đối chiếu với thẻ đã dựng (`ai_chat_page.dart` `_theLenhTao`), **bốn** chỗ lệch:
  (1) Stitch **không avatar**, thẻ rộng hết hàng, bo 12 đều — mã giữ avatar + bong bóng bo lệch như mọi tin của trợ lý
  (**lệch có chủ ý**: một màn chat một kiểu bong bóng); (2) dòng ô thiếu là **hộp nền nhạt + biểu tượng `help_outline`** —
  mã là chữ trần; (3) nút có **mũi tên `arrow_forward`** sau chữ — mã chỉ có chữ; (4) biểu tượng `receipt_long` nằm trong
  **ô vuông nền nhạt 24 dp** — mã là biểu tượng trần. Chữ: Stitch *"bạn **chọn** trong form"* cho ví, mã *"bạn **điền**
  trong form"* cho mọi ô (giữ một câu — ô thiếu có thể là số tiền, không "chọn" được). (2)–(4) sửa ở Task giao diện (T4)
  khi thẻ đổi dòng đầu thành dòng nguồn.

### 8.5 Giá và giới hạn (nói rõ với người dùng khi duyệt)

- Thẻ hiện sau **~15–20 s** trên Realme (CPU) thay vì < 1 s; máy không mô hình vẫn dùng được câu theo mẫu.
- Câu tự nhiên **không chạm cổng** (không nhắc đối tượng tạo được) → không nhận là lệnh — giới hạn cố ý của cổng luật.
- Câu hỏi lọt cổng (vd *"để dành mỗi tháng 2 triệu thì đủ không"* — có *"không"* nên KHÔNG lọt; nhưng câu hỏi không từ
  hỏi thì có thể lọt) tốn thêm một lượt sinh trước khi về vòng hỏi đáp.

### 8.6 Kiểm thử

- **Cổng:** mười câu tự nhiên → `true`; mười câu hỏi gần giống → `false`; ⭐ 72 câu cổng F → `false`; bản sai bỏ vế từ hỏi
  phải làm ca đỏ.
- **Lưới kiểm** (bảng 8.3, mỗi dòng một ca + bản sai có chủ ý): AI bịa số không có trong câu → bỏ; AI tên có chữ ngoài câu
  → dùng tên luật; AI đổi loại của câu theo mẫu → giữ loại luật; hạn quá khứ / câu không có từ thời gian → bỏ; ngày gốc
  không có trong câu → bỏ; `nguon` đúng.
- **Phiên AI** (runtime giả, khuôn `doc_cau_bang_ai_test.dart`): đúng ba khai báo, không khoá nào chứa `tu_tra` / `auto` /
  `trich`; enum rỗng thêm `''`; 30 danh mục + 5 ví vẫn dưới trần; hỏng / quá hạn / huỷ → `null`.
- **Màn chat:** bảng 8.4 mỗi dòng một ca (đếm số lần mở phiên / gọi `onHoi`).
- **Spike Realme trước giao diện:** `tools_json` ba tool; mười câu tự nhiên (năm hoá đơn / mục tiêu / ngân sách có mẫu,
  năm không mẫu) — báo cáo bảng *câu · thẻ hiện ra · đánh giá*.
- **Nghiệm thu Realme:** mười câu trên + ba câu hỏi gần giống lệnh + một lần Huỷ; không Lưu trừ khi người dùng đồng ý.

### 8.7 Tài liệu

`AI_EDGE_FEATURE.md` mục mới *9.43 C3 đổi lần hai* (+ sửa 9.42: "chỉ luật" thành đường dự phòng); `CLAUDE.md` hàng AI
Edge-SLM; mục 14 `PROJECT_CONTEXT.md`.
