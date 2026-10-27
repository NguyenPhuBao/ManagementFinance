# Gia đình — 02a. Ví chung, góp / rút quỹ, bảng góp, dòng hoạt động

> **Ngày:** 2026-10-26 · **Trạng thái:** thiết kế người dùng đã duyệt, chưa có mã · **Người đọc:** backend, PO, client.
> **Cần trước:** phần 1 (`01_NEN_MONG.md` + đơn 50). Quyết định gốc: `00_TONG_QUAN.md` mục 2 (#12 cặp hai khoản, #14 nửa riêng tính là
> chi *"Góp quỹ gia đình"*, #15 người ghi + Chủ nhà sửa / xoá).

---

## 1. Mục đích và phạm vi

Nhà có **nhiều ví chung**; cả nhà **chi** từ ví chung; mỗi người **góp** từ ví riêng vào ví chung và **rút** về ví riêng; ai cũng thấy
**ai góp bao nhiêu** và **dòng hoạt động** của nhà.

**Không thuộc 2a:** hạn mức (`02B` — 2a chỉ chừa chỗ: rút tính vào hạn mức), định mức góp và tự góp (`02C`), ngân sách / báo cáo (`02D`),
mục tiêu (`03`), Nhập nhanh / quét ảnh / giọng nói ở chế độ nhà.

## 2. Ví chung

- Là hàng `wallet` có `Idhousehold` (đơn 50 B) — **không** bảng mới. Chỉ **Chủ nhà** tạo / sửa / lưu trữ / xoá (`01` mục 3).
- **Tên** duy nhất trong nhà (`uq_wallet_household_name_active` — đơn 50 B); client so bằng `normalizeCategoryName` như ví riêng.
- **Loại:** Tiền mặt / Ngân hàng / Tiết kiệm (`WalletType` — ba loại chọn được như ví riêng); màu, biểu tượng như ví riêng.
- **Không bao giờ là ví mặc định** (`chk_wallet_household_not_default` — đơn 50 B); không có công tắc *"Tính vào tổng tài sản"* (tổng cá
  nhân không gồm ví chung — quyết định #5).
- **Số dư ban đầu:** giao dịch neo *"Số dư ban đầu"* như ví riêng (id tất định từ `walletId`, chỉ máy tạo ví đặt neo; máy khác nhận qua
  kéo về — thứ tự G85 áp nguyên). Neo **không** tính là tiền góp của ai.
- **Đối soát số dư** (sửa số dư ở màn Sửa ví chung): sinh khoản điều chỉnh của nhà như ví riêng (`DieuChinhSoDuService`) — Chủ nhà.
- **Còn giao dịch thì không xoá được, chỉ lưu trữ** (luật G45 của ví riêng); lưu trữ ⇒ ẩn khỏi bộ chọn ví của nhà, giữ trong danh sách.
- **Trần số ví chung** mỗi nhà: `household.maxSharedWallets` (đề xuất **10**, đếm ví chung **đang hoạt động** — không lưu trữ, chưa xoá).
  Client chặn trước ở nút *Tạo ví chung*; server thi hành khi **tạo** qua `/sync/push` ⇒ lỗi đẩy vĩnh viễn **`HOUSEHOLD_WALLET_LIMIT`**.
  **Không** tính vào trần 3 ví của gói Basic (trần cá nhân đếm `getActive` — chỉ ví riêng).
- **Không hiện** trong bất kỳ bộ chọn ví cá nhân nào (bộ chọn đọc `idhousehold IS NULL` — spec 2026-10-23 mục 7.2).

## 3. Bảy loại hàng — một định nghĩa phân loại

Mọi màn và mọi phép tính của gia đình phân loại một giao dịch qua **một** hàm domain (`features/household/domain/loai_khoan_nha.dart`),
từ bốn trường đã có / sẽ có: `idhousehold`, `fundPairId` (cột mới, mục 5), `type`, và nhận dạng neo / điều chỉnh sẵn có.

| Loại | `idhousehold` | `fundPairId` | `type` | Ai ghi | Hiện ở |
|---|---|---|---|---|---|
| **Chi của nhà** | nhà H | trống | `chi` | Owner, Member | Nhà mình |
| **Thu khác** vào quỹ (quà, lãi…) | nhà H | trống | `thu` (không phải neo / điều chỉnh) | Owner, Member | Nhà mình |
| **Chuyển** giữa hai ví chung | nhà H | trống | `transfer` | Owner | Nhà mình |
| **Góp — nửa của nhà** | nhà H | có | `thu` | Owner, Member | Nhà mình (*"Minh góp"*) |
| **Rút — nửa của nhà** | nhà H | có | `chi` | Owner, Member | Nhà mình (*"Minh rút"*) |
| **Góp — nửa riêng** | trống | có | `chi` | (tự sinh cùng nửa của nhà) | màn cá nhân (*"Góp quỹ · Tiền chợ"*) |
| **Rút — nửa riêng** | trống | có | `thu` | (tự sinh cùng nửa của nhà) | màn cá nhân (*"Rút quỹ · Tiền chợ"*) |

Neo *Số dư ban đầu* và khoản *Điều chỉnh số dư* của ví chung đi theo nhận dạng sẵn có (`so_du_mo_so.dart`, `dieu_chinh_so_du.dart`), không
vào bảng trên và không vào thống kê của nhà.

## 4. Ghi khoản của nhà — *chế độ nhà* của form Thêm giao dịch

- Mở từ khu **Nhà mình** (nút *Chi* / *Thu* ở Chi tiết ví chung hoặc ở Nhà mình), **không** từ nút + của thanh dưới (nút ấy giữ cho dữ liệu
  cá nhân — quyết định #5).
- Dùng lại trang Thêm giao dịch + `ThemGiaoDichCubit` với **nguồn dữ liệu của nhà**: bộ chọn ví chỉ có ví chung của nhà đang hoạt động;
  danh mục chỉ danh mục của nhà; *Chuyển khoản* chỉ hiện cho Chủ nhà và chỉ giữa hai ví chung.
- **Không có** ở chế độ nhà (2a): Nhập nhanh, quét ảnh, giọng nói, gợi ý danh mục học theo cá nhân (B1), tách khoản. Bộ học B1 của người
  dùng **không** học từ khoản của nhà.
- Lưu ⇒ hàng `transaction` với `idhousehold` = nhà, `idaccount` = người ghi (từ phiên — quy tắc 2).
- Nhà `ReadOnly` / vai `Viewer` ⇒ các nút ghi không hiện (đọc trạng thái nhà trước khi mở form — spec 2026-10-23 mục 5.6).

## 5. Góp và rút — cặp hai khoản

### 5.1 Người dùng thấy gì

**Góp** (Chủ nhà, Thành viên) — màn *Góp vào quỹ* mở từ Chi tiết ví chung: ví chung đích · số tiền (bàn phím số tiền, trần 13 chữ số) ·
**ví riêng nguồn** (mặc định ví mặc định cá nhân) **hoặc** *"Tiền mặt trao tay — không trừ ví nào"* · ngày · ghi chú. Ví riêng nguồn không
đủ tiền ⇒ cảnh báo số dư như form giao dịch hiện có (không chặn).

**Rút** (Chủ nhà, Thành viên) — màn *Rút về ví riêng*: ví chung nguồn · số tiền · ví riêng đích · ngày · ghi chú. Rút của Thành viên **tính
vào hạn mức chi** của họ ở ví ấy (`02B`) — nếu không, rút về ví riêng rồi tiêu là lối đi vòng hạn mức.

### 5.2 Hai nửa trong dữ liệu

Minh góp 2.000.000 đ từ *Ví MB* vào *Tiền chợ*:

| | Nửa riêng | Nửa của nhà |
|---|---|---|
| `id` | UUID v4 mới | UUID v4 mới |
| `fundPairId` | **P** (UUID v4 mới, chung cho cặp) | **P** |
| `idhousehold` | trống | H |
| `idaccount` | Minh (phiên) | Minh (phiên) |
| `walletId` | Ví MB | Tiền chợ |
| `type` / số tiền | `chi` 2.000.000 | `thu` 2.000.000 |
| `categoryId` | trống | trống |
| `note` | *"Góp quỹ · Tiền chợ"* + ghi chú người dùng | ghi chú người dùng |
| `date` | ngày đã chọn | cùng ngày |
| Về máy nào | các máy của Minh | máy mọi thành viên |

- Rút là chiều ngược: nửa của nhà `chi` khỏi ví chung, nửa riêng `thu` vào ví riêng, ghi chú *"Rút quỹ · …"*.
- *"Tiền mặt trao tay"* ⇒ **chỉ** nửa của nhà (vẫn mang `fundPairId` — để được nhận là *góp*, và để bảng góp tính cho người ghi).
- Hai nửa ghi trong **một giao tác Drift** (khuôn `addTransactions` của tách khoản — neo số dư trước khi ghi), rồi đồng bộ như mọi
  giao dịch. Server **không** cần biết hai nửa là một cặp; nó chỉ lưu và trả cột `Idfund_pair`.
- Nhận dạng *khoản góp / rút* luôn qua `fundPairId`, **không** qua tiền tố ghi chú (tên ví chung đổi thì ghi chú cũ vẫn mang tên cũ —
  không sao).

## 6. Giữ hai nửa khớp nhau

| Tình huống | Xử lý | Ở đâu |
|---|---|---|
| Người góp sửa khoản góp (khi còn là thành viên, nhà `Active`) | Form góp mở cả cặp; lưu đổi **cả hai** nửa trong một giao tác. Mở nửa riêng từ Sổ giao dịch cá nhân cũng vào form góp | client |
| Người góp xoá | Xoá mềm cả hai nửa; hộp xác nhận *"Quỹ Tiền chợ cũng giảm 2.000.000 đ"* | client |
| **Chủ nhà xoá** nửa của nhà của người khác (sửa ghi nhầm — Chủ nhà **không sửa** được, `01` mục 3) | Máy người góp, khi kéo về thấy nửa của nhà mang cờ xoá mà nửa riêng còn sống: **đọc lại trạng thái nhà trước**; nhà vẫn `Active` và mình vẫn là thành viên ⇒ xoá mềm nửa riêng (tiền về ví riêng) + thông báo *"Chủ nhà đã xoá khoản góp … — đã trả tiền về Ví MB"*. Không đọc được (offline) ⇒ hoãn tới lượt sau | `household/application` |
| **Server từ chối** nửa của nhà (`HOUSEHOLD_NOT_MEMBER` · `_READ_ONLY` · `_CLOSED` · `_SCOPE_MISMATCH` · `_ROLE_FORBIDDEN`) | Bộ nghe `pushResultStream` gỡ nửa riêng (xoá mềm, tính lại số dư) + thông báo *"Chưa góp được vào quỹ Tiền chợ — đã trả tiền về Ví MB"*. Chịu được **hai** lượt phát cho cùng một thất bại (cam kết thứ tự của `SyncEngine`) | `household/application` (khuôn `BillPaymentConflictResolver`) |
| Rời nhà / bị mời ra / nhà giải tán | **Giữ** nửa riêng — tiền đã thật sự đưa ra. Đường dọn 2 (spec 2026-10-23 mục 4.6) chỉ xoá hàng của nhà trên máy; nửa riêng còn lại thành khoản riêng thường (vẫn hiện nhãn *"Góp quỹ gia đình"*), sửa / xoá như khoản riêng | client |
| Kéo về thấy nửa của nhà bị xoá **vì giải tán** | Không gỡ nửa riêng: phép đọc lại trạng thái nhà ở dòng *Chủ nhà xoá* thấy nhà `Dissolved` / mình không còn ở ⇒ không gỡ | client |

**Thông báo** (nhóm *Gia đình*, mặc định bật, trên máy **người góp**):

| Loại | Khi | Khoá chống trùng | Câu |
|---|---|---|---|
| `gopQuyBiTraVe` | server từ chối nửa của nhà, nửa riêng đã gỡ | `gopTraVe:<fundPairId>` | *"Chưa góp được vào quỹ {Tiền chợ} — đã trả tiền về {Ví MB}"* |
| `gopQuyBiXoa` | Chủ nhà xoá nửa của nhà, nửa riêng đã gỡ | `gopBiXoa:<fundPairId>` | *"Chủ nhà đã xoá khoản góp vào {Tiền chợ} — đã trả tiền về {Ví MB}"* |

Khoá theo mã cặp ⇒ hai lượt phát của `pushResultStream` cho cùng một thất bại chỉ ra một thông báo.

## 7. Số liệu

### 7.1 Số dư ví chung

`SoDuViService` (nơi duy nhất ghi `balance`) tính ví chung từ **hàng của nhà** của ví ấy: Σ thu − Σ chi − Σ chuyển đi + Σ chuyển đến, như
ví riêng. Mọi máy trong nhà có cùng tập hàng của nhà ⇒ cùng số. Tính lại sau mỗi lần kéo về (như ví riêng).

### 7.2 Nửa riêng trong số liệu cá nhân (quyết định #14)

- Nửa riêng của **góp** là **chi**, của **rút** là **thu** — đi qua `khoanVaoThongKe` như khoản thường (thẻ tổng Sổ giao dịch, Trang chủ,
  Phân tích, ngân sách **tổng** cá nhân đều tính).
- Không có danh mục thật: các khối gom theo danh mục (donut, thác nước, danh sách danh mục, Xu hướng) gom nửa riêng vào **nhãn ảo**
  *"Góp quỹ gia đình"* / *"Rút quỹ gia đình"* (nhận qua `fundPairId`, không phải danh mục — không đồng bộ, không chọn được trong bảng chọn).
  Ngân sách **theo danh mục** không tính chúng.
- *"Thu nhập"* (`thuNhapCua` — định nghĩa duy nhất, ANALYTICS 3.24) **không** gồm nửa riêng của rút (tiền quay về, không phải tiền kiếm
  được — cùng lý do loại tiền đi vay); *tổng thu* thì gồm.
- **Không** là mẫu học / khoản cần gắn: `laGhiChuMay` (B1, đề xuất từ khoá) và `xetGan` (thẻ *"Có N giao dịch chưa có danh mục"*, C1) bỏ
  mọi hàng có `fundPairId` — nếu không, thẻ C1 sẽ đếm mọi khoản góp là *"chưa có danh mục"*.

### 7.3 Số liệu của nhà

Định nghĩa ở `household/domain/` (một chỗ mỗi phép), dùng cho bảng góp, dòng hoạt động, báo cáo (`02D`), hạn mức (`02B`):

- **Tiền vào quỹ** = góp (nửa của nhà) + thu khác. **Chi của nhà** = chi của nhà (loại 1). Rút, chuyển, neo, điều chỉnh: không phải chi
  của nhà — ngân sách chung (`02D`) và báo cáo dùng đúng định nghĩa này. ⚠️ **Hạn mức** (`02B` mục 5) cố ý **cộng thêm rút** vào dòng chung (rút
  là tiền rời quỹ về tay một người — không cộng là lối đi vòng hạn mức); định nghĩa riêng ở đó, không sửa định nghĩa *chi của nhà*.
- Mọi phép cộng theo kỳ dùng biên **`[from, to)`** như Sổ giao dịch.

## 8. Bảng ai góp bao nhiêu

Ở Chi tiết ví chung (theo ví) và Nhà mình (cả nhà). Mỗi người — thành viên đang ở, rồi người đã rời có khoản trong ví (tên lấy từ
`formerMembers`, kèm *"(đã rời)"*):

| Cột | Định nghĩa (cho một ví, hoặc mọi ví chung khi xem cả nhà) |
|---|---|
| Góp tháng này | Σ góp (nửa của nhà) do người ấy ghi, ngày trong tháng hiện tại |
| Góp từ trước tới nay | Σ góp do người ấy ghi, mọi ngày |
| Đã rút | Σ rút (nửa của nhà) do người ấy ghi, mọi ngày |
| Đã chi tháng này | Σ chi của nhà do người ấy ghi, tháng hiện tại |

Ai cũng xem được bảng này (Chỉ xem cũng vậy). Cột định mức (đủ / thiếu) thêm ở `02C` với luật riêng tư của nó.

## 9. Dòng hoạt động

- Danh sách mọi khoản của nhà (bảy loại trừ hai nửa riêng — nửa riêng không bao giờ có trên máy người khác), mới nhất trước theo ngày
  giao dịch rồi giờ sửa. Mỗi dòng: *"{tên} {chi / thu / góp / rút / chuyển} {số tiền} · {danh mục} · {ví}"*.
- Lọc theo người, theo ví. Chạm một dòng ⇒ chi tiết khoản (sửa / xoá theo `01` mục 3).
- Đọc từ SQLite đã đồng bộ (stream) — không bảng mới, không API mới. Vào / rời nhà **không** nằm trong dòng (không có dữ liệu sự kiện ấy
  trên máy — ngoài phạm vi).

## 10. Màn hình (đưa lên Stitch trước khi làm)

1. **Nhà mình** (có nhà) — thêm khối *Ví chung*: tổng quỹ + danh sách ví chung (số dư); nút *Tạo ví chung* (Chủ nhà); lối vào *Hoạt động*.
2. **Tạo / Sửa ví chung** — dùng lại form ví ở chế độ nhà (không *Mặc định*, không *Tính vào tổng*, không *Cho phép âm*); `03` thêm công
   tắc mục tiêu vào màn này.
3. **Chi tiết ví chung** — số dư; nút *Chi · Thu · Góp · Rút* (theo vai); hai tab *Giao dịch* · *Bảng góp*.
4. **Góp vào quỹ** / **Rút về ví riêng** — một trang hai chế độ.
5. **Thêm giao dịch — chế độ nhà** — dùng lại trang có sẵn.
6. **Hoạt động** — danh sách + bộ lọc người / ví.
7. **Hộp xác nhận xoá khoản góp / rút.**

Bố cục kiểm ở **360 dp**, có ca bàn phím hệ thống mở (bẫy G58); số tiền lớn nhất 13 chữ số trong mọi ô / dòng (bẫy *đặt trần là phải thử bố
cục với giá trị lớn nhất*).

## 11. Đồng bộ và việc backend

- **Cột mới** `transaction."Idfund_pair" VARCHAR(36) NULL` + chỉ mục `("Idfund_pair") WHERE "Idfund_pair" IS NOT NULL`. Không khoá ngoại
  (không trỏ tới hàng nào).
- **Khoá payload** `idfund_pair` (cùng kiểu `idwallet_transfer` / `idgoal`): `mapEntityFields` nhận ở **mọi khối `data` của nhánh tạo và sửa**
  giao dịch (đơn 50 D.2 — thiếu là bị bỏ qua im lặng); `/sync/pull` trả khoá (chuỗi hoặc `null`). Hàng riêng **và** hàng của nhà đều được mang.
- **Luật:** `Idfund_pair` không được đặt trên `Transfer` ⇒ `HOUSEHOLD_SCOPE_MISMATCH`; hàng của nhà có `Idfund_pair` chỉ **người ghi** được
  sửa (`01` mục 3 — Chủ nhà chỉ xoá). Server **không cần** kiểm hai nửa có khớp nhau — client giữ khớp (mục 6); câu hỏi Q-A3.
- **Trần ví chung:** tạo `wallet` có `Idhousehold` khi nhà đã có `maxSharedWallets` ví chung đang hoạt động ⇒ `HOUSEHOLD_WALLET_LIMIT`
  (vĩnh viễn). `maxSharedWallets` trả trong `household` của `/me` (`01` mục 4); nguồn: cột trên `household` hoặc giới hạn gói của chủ
  (`limits.household_wallets`) — backend chọn (Q-A2).
- **`/me` thêm `formerMembers`** (`01` mục 4).
- Không sự kiện mới; `sync.completed` tới mọi thành viên (đơn 50 F) là đủ cho ví chung và dòng hoạt động.

## 12. Phía client (để ước lượng — chi tiết ở kế hoạch thi công)

- **Drift v33** — cột `transactions.fund_pair_id` (TEXT NULL), **đồng bộ** (không phải cột cục bộ — quét 15 không áp); bước di trú + fixture
  của test di trú cũ. Hợp đồng `sync_payload_contract_test.dart` thêm `idfund_pair`; nhánh kéo về `Value.absent()` khi server không trả khoá.
- **`features/household/`** (luật vị trí tệp mục 8 `KIEN_TRUC_CLIENT_APP.md`):
  - `domain/` — `loai_khoan_nha.dart` (bảng mục 3, **một** định nghĩa), `so_lieu_nha.dart` (tiền vào quỹ / chi của nhà), `bang_gop.dart`,
    `hoat_dong_nha.dart` — Dart thuần, không import Drift.
  - `application/` — `GopQuyService` (ghi / sửa / xoá cặp trong một giao tác), `GopQuyConflictResolver` (từ chối khi đẩy), bộ gỡ nửa riêng khi
    nửa của nhà bị xoá (mục 6). Đăng ký DI và **bắt đầu nghe** cùng chỗ với `BillPaymentConflictResolver` (quét 5 có khuôn tương tự).
  - `presentation/` — trang *Nhà mình* (khối ví chung), *Chi tiết ví chung*, *Góp / Rút*, *Hoạt động*; Cubit riêng mỗi trang.
- **Mảng có sẵn chạm tới:** `wallet` (đọc ví chung của nhà — quét 2 phân loại thêm *bộ chọn ví của nhà*), `transaction` (form chế độ nhà;
  `laGhiChuMay` / `xetGan` / nhãn ảo; `khoanVaoThongKe` không đổi chữ ký nếu nhãn ảo làm ở tầng gom), `analytics` (nhãn ảo), `notification`
  (`gopQuyBiTraVe`, `gopQuyBiXoa` — mục 6).
- **Chiều phụ thuộc:** `household/domain` **không** import `notification`; luật thông báo của gia đình ở `notification/domain` đọc kiểu thuần
  của `household/domain` (chiều `notification → household`) — giữ đồ thị mảng không vòng (quét 29).
- Thêm `HOUSEHOLD_WALLET_LIMIT` vào `_permanentCodes` cùng lượt `HOUSEHOLD_ROLE_FORBIDDEN` (`01` mục 3) — ✅ **đã thêm 2026-10-27**,
  trước khi backend chấp nhận tên.

## 13. Kiểm thử và nghiệm thu

- **Domain (test như tài liệu):** `loai_khoan_nha_test` — một ca mỗi ô bảng mục 3 + neo / điều chỉnh không lọt; bảng góp (người đã rời, tiền
  mặt trao tay, rút); số liệu nhà với biên `[from, to)`.
- **Application:** `GopQuyService` — hai nửa cùng giao tác (lỗi giữa chừng không để lại nửa nào), sửa đổi cả hai, xoá cả hai; resolver —
  từ chối ⇒ gỡ nửa riêng một lần dù hai lượt phát; bộ gỡ khi Chủ nhà xoá — ba ca (nhà `Active` ⇒ gỡ; giải tán ⇒ không; offline ⇒ hoãn).
- **Số liệu cá nhân:** thẻ tổng Sổ = Trang chủ có khoản góp; donut có lát *"Góp quỹ gia đình"*; `thuNhapCua` không gồm rút; thẻ C1 không
  đếm khoản góp; B1 không học.
- **Số dư:** ví chung kéo về từ máy khác (neo + G85); hai máy cùng ra một số.
- **Widget:** sáu màn ở 360 dp, bàn phím mở, số 13 chữ số.
- **Nghiệm thu hai máy thật, hai tài khoản:** Chủ nhà tạo hai ví chung → Thành viên góp từ ví riêng → máy Chủ nhà thấy *"… góp"*, số dư khớp;
  Thành viên chi → bảng góp / dòng hoạt động đổi trên cả hai máy; Chủ nhà xoá một khoản góp → máy Thành viên trả tiền về ví riêng; mời ra
  Thành viên khi họ đang offline có khoản góp chờ đẩy → máy họ nhận *"Chưa góp được…"*, ví riêng đúng số; Trang chủ / Phân tích cá nhân của
  Thành viên có lát *"Góp quỹ gia đình"*, không có khoản chi của nhà.

## 14. Câu hỏi để thảo luận

- **Q-A1** — Tên `Idfund_pair` / `idfund_pair` được chứ? (Client chỉ cần một chuỗi chung cho hai nửa.)
- **Q-A2** — Trần ví chung: một cột `household."Max_shared_wallets"` (admin chỉnh từng nhà) hay giới hạn gói `household_wallets` (chỉnh theo
  gói)? Client chỉ đọc `household.maxSharedWallets`.
- **Q-A3** — Backend có muốn kiểm thêm *"hàng riêng có `Idfund_pair` phải cùng `Idaccount` với hàng của nhà mang cùng mã"* không? Client
  không cần (mỗi người chỉ tạo cặp của chính mình) — để trống là bớt một truy vấn mỗi lần đẩy.

## 15. Trả lời / thảo luận

*(Chờ backend / PO.)*
