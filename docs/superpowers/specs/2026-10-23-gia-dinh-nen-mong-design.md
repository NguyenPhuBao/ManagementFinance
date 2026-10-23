# Gia đình (nhà nhiều người) — spec 1/4: NỀN MÓNG + hợp đồng mô hình dữ liệu

> **Ngày:** 2026-10-23 · **Trạng thái:** thiết kế đã duyệt từng phần trong phiên brainstorming, chờ người dùng đọc spec ·
> **Phạm vi spec này:** nhà / thành viên / lời mời, ba vai, cửa Premium, luật đồng bộ theo phạm vi nhà, cột `idhousehold`.
> Ba phần con còn lại (quỹ chung · chi chung + ai nợ ai · mục tiêu chung) mỗi phần một spec + một đơn backend riêng, viết sau.
> **Phía server** do backend làm theo đơn CAN-LAM (người dùng chốt) — client không sửa `src/Backend` (quy tắc 1).
> **Đơn backend:** mục **50** `docs/superpowers/backend/CAN-LAM/GIA_DINH_NEN_MONG.md` (2026-10-23, người dùng nhờ viết tài liệu cho
> backend đọc) — chi tiết SQL nháp, 12 endpoint, mã lỗi, đồng bộ, Premium, sự kiện, câu kiểm.

---

## 0. Bối cảnh

Hôm nay mọi bản ghi gắn với **một** `idaccount`: ví thuộc một người, `/sync/pull` chỉ trả dữ liệu của tài khoản đăng nhập,
`purgeDataForOtherAccounts` xoá hàng của tài khoản khác khi đổi người dùng trên máy. Chưa có khái niệm chia sẻ nào ở client
lẫn backend (đo 2026-10-23: `grep` *household / wallet_member / shared* trên `schema.prisma`, `src/Backend/modules`,
`src/Client-app/lib` → 0). `SYNC_DOCUMENTATION.md` mục III.3 ghi *"Chia sẻ Ví nhóm — chưa hỗ trợ"*.

Đối chiếu app thị trường (theo nếp *đối chiếu trước khi chốt phạm vi*): **Money Lover / Spendee** — ví chia sẻ, quyền theo
từng ví; **YNAB Together** — một ngân sách cho tối đa 6 người; **Honeydue** — mỗi người chọn tài khoản nào cho người kia
xem; **Splitwise** — chia khoản chi, ai nợ ai, nút cân nợ. Nhu cầu của người dùng gộp cả bốn kiểu.

## 1. Quyết định của người dùng (2026-10-23, qua câu hỏi chọn được)

| Câu hỏi | Chốt |
|---|---|
| Vợ chồng / gia đình dùng để làm gì | **Cả bốn**: quỹ chung cùng ghi · xem chung bức tranh · chia tiền, ai nợ ai · mục tiêu tiết kiệm chung |
| Quỹ chung trong thực tế | **Cả hai kiểu**: quỹ thật cả nhà cùng ghi vào **và** khoản mỗi người tự trả rồi tính chung |
| Quy mô | **Gia đình nhiều người** (tối đa 6, trần server ghi đè được) |
| Ai làm phần server | **Backend làm theo đơn**; client làm phần mình theo hợp đồng, có API giả để test trước |
| Riêng tư | **Chung + chọn thêm**: mặc định chỉ thấy dữ liệu chung; mỗi người tự bật *"cho nhà xem"* từng ví riêng (chỉ xem) |
| Vai trò | **Ba vai cố định**, áp cho cả nhà: Chủ nhà · Thành viên · Chỉ xem |
| Gói | **Chủ nhà cần Premium**; người được mời dùng miễn phí; chủ hết Premium → nhà *chỉ xem*, không mất dữ liệu |
| Mô hình dữ liệu | **Hướng A — "nhà" là chủ sở hữu thứ ba** (loại B: quyền theo từng bản ghi; loại C: chỉ chiếu, không quỹ thật) |
| Dữ liệu nhà hiện ở đâu | **Chỉ ở khu "Nhà mình"**; màn cá nhân (Trang chủ, Sổ, Phân tích, Ngân sách) giữ nguyên, tổng cá nhân không lẫn tiền của nhà |
| Danh mục cho khoản của nhà | **Bộ danh mục riêng của nhà** (server sao bộ mặc định khi lập nhà; thành viên thêm được) |
| Giải tán nhà | Dữ liệu chung **biến mất với mọi người** (xoá mềm ở server) |

## 2. Lộ trình bốn phần con

| # | Phần | Nội dung | Phụ thuộc |
|---|---|---|---|
| **1** | **Nền móng** (spec này) | Nhà / thành viên / lời mời, ba vai, Premium, đồng bộ theo phạm vi nhà, cột `idhousehold` + bộ danh mục nhà, khu *Nhà mình* (thành viên), ba đường dọn dữ liệu | — |
| 2 | Quỹ chung + *cho nhà xem* + màn tổng hợp *Nhà mình* | Ví của nhà cả nhà cùng ghi; ví riêng bật chia sẻ (chỉ xem); tổng tài sản / chi tháng của nhà | 1 |
| 3 | Chi chung tự trả + ai nợ ai | Khoản riêng gắn cờ *chi chung* + tỷ lệ chia; bảng nợ giữa thành viên; giao dịch *trả nợ* để cân | 1 (dùng màn của 2 nếu có) |
| 4 | Mục tiêu chung | Mục tiêu của nhà, mỗi người góp từ ví của mình; tiến độ theo người | 1 |

**Ngoài phạm vi cả bốn phần:** hoá đơn chung (khoá ngoại `fk_bill_wallet` RESTRICT + tự trả là bài toán riêng); quét QR mời
(cần gói camera có mã Android gốc — bẫy R8 bản release, mục *D1* `CLAUDE.md`); tạo / tham gia nhà khi offline; một tài khoản ở
nhiều nhà.

## 3. Mô hình dữ liệu (hướng A)

### 3.1 Ba thực thể mới — server tạo, client đọc

- **Nhà** (`household`): id **số nguyên do server cấp** (`SERIAL`, như `idaccount` — nhà chỉ tạo khi có mạng, không cần UUID), tên (≤ 100 ký tự, `GioiHanDoRong` như tên ví), chủ nhà (`idaccount`), trần thành viên
  (mặc định 6), trạng thái `Active` · `ReadOnly` (chủ hết Premium) · `Dissolved` (đã giải tán), mốc tạo / sửa / xoá mềm.
- **Thành viên** (`household_member`): (nhà, tài khoản, vai `Owner` · `Member` · `Viewer`, ngày vào, ngày rời). Một tài khoản
  **tối đa một nhà đang ở** (chỉ mục duy nhất theo tài khoản trên hàng chưa rời). Đúng một `Owner` mỗi nhà.
- **Lời mời** (`household_invite`): mã 8 ký tự (chữ in hoa + số, bỏ ký tự dễ nhầm `0 O 1 I`), nhà, vai được cấp
  (`Member` · `Viewer`), người tạo, hết hạn sau **48 giờ**, dùng **một lần**, huỷ được.

### 3.2 Luật sở hữu bản ghi

- Năm bảng đồng bộ — **ví, giao dịch, mục tiêu, ngân sách, danh mục** — thêm cột `idhousehold` (số nguyên, nullable).
- `idhousehold` **trống** ⇒ dữ liệu riêng, mọi luật hiện có giữ nguyên.
- `idhousehold` **khác trống** ⇒ bản ghi thuộc **nhà**; `idaccount` khi ấy chỉ nghĩa **người tạo** (server lấy từ JWT lúc tạo,
  không đổi khi thành viên khác sửa). Không bao giờ suy `idaccount` từ dữ liệu (quy tắc 2).
- Ví của nhà: không bao giờ là ví mặc định của ai (`uq_wallet_default_active` chỉ xét hàng riêng); tên duy nhất **trong nhà**
  (chỉ mục mới theo `Idhousehold`), không đụng tên ví riêng. Các ràng buộc riêng (`uq` tên ví theo tài khoản, ví mặc định) phải
  thêm `WHERE "Idhousehold" IS NULL`.
- Bảng hoá đơn **không** thêm cột (ngoài phạm vi).

### 3.3 Bộ danh mục của nhà

- Lập nhà ⇒ server sao bộ danh mục mặc định thành danh mục **của nhà** (`Idhousehold` = nhà, `Is_default = false`,
  `Create_by` = chủ nhà). Thành viên (vai `Member` trở lên) thêm / sửa được danh mục của nhà.
- Trùng tên xét **trong nhà** (chỉ mục mới); `uq_category_owner_name` thêm `WHERE "Idhousehold" IS NULL`.
- Khoản của nhà (từ spec 2) **chỉ** được chọn danh mục của nhà — mọi máy trong nhà đều có (khắc phục việc danh mục là bản sao
  riêng từng tài khoản — quy tắc 8).
- Danh mục của nhà về máy **ngay ở spec này** ⇒ các danh sách danh mục cá nhân phải loại chúng (mục 7.2).
- `DefaultCategorySeeder` **không** sao chép danh mục của nhà sang tài khoản (nó chỉ đọc hàng `isDefault`, idaccount 0).

## 4. Đồng bộ

### 4.1 Phạm vi

- Server lọc `/sync/pull` theo JWT: **(`Idaccount` = tôi ∧ `Idhousehold` trống) ∨ (`Idhousehold` = nhà tôi đang ở)**.
  Hàng tôi từng ghi vào một nhà đã rời **không** còn về.
- Client lưu mọi thứ nhận về; payload đẩy lên mang `idhousehold` lấy từ chính hàng. ⇒ `core/sync` **không biết** khái niệm nhà
  (quét 25 luật 5: `core` chỉ được đọc năm tệp domain thuần — không cần thêm tệp thứ sáu).
- Hợp đồng `test/core/sync/sync_payload_contract_test.dart`: thêm khoá `idhousehold` cho 5 thực thể (đếm lại số trường trong
  kế hoạch thi công, không ghi số ở đây). Nhánh kéo về: server không trả khoá ⇒ `Value.absent()` (giữ giá trị cục bộ), như các
  cột nối khác.
- Thứ tự đẩy: `ENTITY_PRIORITY` hiện có (category 10 → wallet 20 → goal 30 → … → transaction 40) đã đặt danh mục / ví của nhà
  trước giao dịch của nhà; không đổi.

### 4.2 Quyền khi đẩy — bốn mã lỗi mới (đều **vĩnh viễn**)

Mỗi hàng có `idhousehold` khi tạo / sửa / xoá, server kiểm:

| Điều kiện sai | Mã |
|---|---|
| Người đẩy không còn là thành viên nhà ấy | `HOUSEHOLD_NOT_MEMBER` |
| Vai `Viewer`, hoặc nhà `ReadOnly` | `HOUSEHOLD_READ_ONLY` |
| Nhà `Dissolved` | `HOUSEHOLD_CLOSED` |
| Tham chiếu sai phạm vi (luật ngay dưới bảng) | `HOUSEHOLD_SCOPE_MISMATCH` |

**Luật tham chiếu** (`HOUSEHOLD_SCOPE_MISMATCH`): (a) hàng **của nhà H** chỉ được trỏ tới ví / danh mục / mục tiêu / ngân sách
của **chính H**; (b) hàng **riêng** chỉ được trỏ tới ví / danh mục **riêng của chính người ấy** — **ngoại lệ duy nhất**: giao
dịch riêng được trỏ `idgoal` tới mục tiêu của nhà **người ấy đang ở** (khoản góp từ ví riêng vào mục tiêu chung — phần con 4;
mở luật ngay ở nền móng để không phải đổi mã lỗi về sau).

Trả theo khuôn lỗi từng thao tác hiện có (`results[i].code`, HTTP 200 cho lô).

⚠️ **Tiền đề — kiểm chủ sở hữu khi sửa / xoá** (đo 2026-10-23, đọc mã backend): `/sync/push` chỉ so `payload.idaccount` với token
(`sync.service.js:103-113`); nhánh sửa của ví / giao dịch / ngân sách / hoá đơn / mục tiêu chỉ so `update_at` rồi ghi đè
(`sync.repository.js` `upsertWallet` …), `softDelete` xoá theo khoá chính — **không** so `existing.idaccount`. Ai biết UUID bản ghi
của người khác là sửa / xoá được. Gia đình làm lộ UUID giữa thành viên (từ phần con 2 — ví *cho nhà xem*), nên kiểm chủ sở hữu
(hàng riêng: `existing.idaccount` = người đẩy; hàng của nhà: luật bảng trên) là việc **đầu tiên** của đơn backend. ⚠️ Client thêm **cả bốn** (cùng mã `NOT_OWNER` của tiền đề kiểm chủ sở hữu ngay dưới) vào
`_permanentCodes` (`core/sync/gui_lo_dong_bo.dart`, danh sách **trắng**) **cùng lượt** — thiếu là hàng bị gửi lại mọi chu kỳ,
im lặng (lớp lỗi G31 / G14). Gặp một trong bốn mã ⇒ làm mới trạng thái nhà (mục 5.8) và hiện nhãn *"Chưa ghi được vào nhà"* trên
hàng ấy (spec 2 trở đi mới có hàng của nhà do người dùng ghi).

### 4.3 Vào nhà ⇒ kéo lại toàn bộ một lần

Kéo về là tăng dần theo `Server_update_at` kể từ mốc, nên dữ liệu cũ của nhà **không bao giờ** tới máy người mới vào. Sau khi
tham gia (và sau khi tạo nhà — danh mục nhà do server sinh), bộ điều phối gọi `SyncCheckpointStore.clear(idaccount)` (tệp công
khai của `core/sync` — quét 35) rồi `syncNow()`: lượt kéo kế tiếp đi từ 1970, đúng cơ chế G67 đã dùng khi đổi khoá mốc.

### 4.4 Xung đột

Giữ **ghi-sau-thắng theo `update_at`** như dữ liệu riêng. ⚠️ Rủi ro chấp nhận: đây là lần đầu đồng hồ của **hai người** quyết
một lần ghi — điện thoại lệch giờ có thể làm bản sửa trước thắng. Chấp nhận vì cùng sửa **một** khoản của nhà ở hai máy là hiếm
(phần lớn là khoản mới do một người tạo). Nếu nghiệm thu thấy vấn đề, xin backend lấy giờ server làm mốc LWW cho hàng của nhà —
một đơn riêng.

### 4.5 Báo cho máy khác (thời gian thực)

- Server phát `sync.completed` tới **mọi thành viên** khi có hàng của nhà được đẩy (hôm nay chỉ tới phòng `account_<người đẩy>`).
- Sự kiện mới **`household.changed`** tới mọi thành viên khi: có người vào / rời / bị mời ra, đổi vai, chuyển chủ, đổi trạng
  thái (`ReadOnly` / `Active` / `Dissolved`). Client chỉ đọc **tên** sự kiện (payload hộp đen — cam kết của kênh thời gian thực),
  thêm một giá trị `RealtimeEvent`, im lặng (`loiNhan null`), không đồng bộ lại (`canDongBoLai false`), chỉ làm mới trạng thái nhà.
  Người bị mời ra cũng phải nhận sự kiện (phát **trước** khi gỡ khỏi phòng nhà, hoặc tới phòng `account_<id>`).

### 4.6 Ba đường dọn dữ liệu — tách bạch, không gộp

1. **Đổi tài khoản trên máy** — `purgeDataForOtherAccounts(keep, {nhaGiu})`: xoá hàng `idaccount ≠ keep` **trừ** hàng có
   `idhousehold = nhaGiu`; và xoá hàng có `idhousehold` khác trống mà khác `nhaGiu` (kể cả hàng chính `keep` đã ghi vào nhà cũ).
   `nhaGiu` = nhà của tài khoản mới theo bản lưu trạng thái nhà (mục 5.8); chưa biết ⇒ `null` ⇒ xoá mọi hàng của nhà — an toàn vì
   server còn nguyên, lượt kéo sau mang về. Truyền qua hook `_donTaiKhoanKhac` của `PhienDieuPhoiThat` (core không import mảng).
2. **Rời nhà / bị mời ra / nhà giải tán** — bộ điều phối `features/household/application/don_du_lieu_nha.dart`: (a) nếu còn
   quyền ghi, thử đẩy nốt hàng của nhà đang chờ; (b) xoá **vật lý trên máy** mọi hàng `idhousehold = nhà ấy` (đây là bản sao
   cục bộ của dữ liệu không còn thuộc người dùng — server giữ nguyên / đã xoá mềm; không vi phạm quy tắc 5 vì server không bị xoá
   cứng); (c) gỡ trạng thái nhà đã lưu; (d) tính lại số dư ví nếu có (từ spec 2).
3. **`ACCOUNT_DELETED`** — **không** xoá gì (G89, giữ nguyên).

## 5. Luồng nền móng

### 5.1 Tạo nhà
Cần Premium (quyền mới, mục 5.7) và mạng. Màn *Tạo nhà*: ô tên nhà → *Tạo*. Người tạo thành `Owner`. Server sao bộ danh mục
(3.3). Client: lưu trạng thái nhà → xoá mốc + `syncNow()` (4.3). Basic bấm *Tạo nhà* ⇒ qua **một** cửa chặn route (khuôn
`chanTheoQuyen` + `await goi.choNapKho()` — G92) về `/premium`.

### 5.2 Mời
Chỉ `Owner`. Màn *Mời thành viên*: chọn vai (*Thành viên* / *Chỉ xem*) → *Tạo mã* → hiện mã 8 ký tự + hạn + nút **Chia sẻ**
(bảng chia sẻ của máy — tin nhắn soạn sẵn có mã) + nút *Chép mã*. Danh sách mã còn hiệu lực, mỗi mã một nút *Huỷ*. Nhà đủ trần
⇒ nút *Tạo mã* khoá kèm câu lý do. Chia sẻ ra ngoài dùng `share_plus` **đã có** (`pubspec.yaml`, đang dùng ở
`analytics/data/xuat_tep_service_impl.dart`) — không thêm gói mới; lời gọi chia sẻ chữ đặt sau một cổng ở `data/datasources/`.

### 5.3 Tham gia
Basic cũng được; cần mạng. Màn *Tham gia bằng mã*: ô 8 ký tự (tự in hoa, bỏ khoảng trắng) → *Xem trước* (server trả tên nhà, tên
chủ nhà, số thành viên, vai sẽ nhận, hạn mã) → *Tham gia*. Lỗi có câu riêng: mã sai / hết hạn / đã dùng · đã ở một nhà khác
(*"Rời nhà hiện tại trước"*) · nhà đủ người · nhà đã giải tán. Thành công ⇒ lưu trạng thái nhà, xoá mốc + `syncNow()`.

### 5.4 Đổi vai, chuyển chủ
`Owner` đổi vai `Member` ↔ `Viewer` cho người khác. *Chuyển chủ*: chọn một thành viên → hỏi xác nhận → người ấy thành `Owner`,
chủ cũ thành `Member`. Chủ mới không có Premium ⇒ nhà `ReadOnly` (5.6).

### 5.5 Rời nhà, mời ra, giải tán
- *Rời nhà*: `Member` / `Viewer` rời lúc nào cũng được (hỏi xác nhận một lần). `Owner` không rời được — câu *"Chuyển quyền chủ
  nhà hoặc giải tán trước"*.
- *Mời ra*: `Owner` gỡ một thành viên (hỏi xác nhận). Dữ liệu người ấy đã ghi **ở lại nhà**.
- *Giải tán*: chỉ `Owner`, hỏi **hai lần** (lần hai gõ tên nhà). Câu xác nhận: *"Quỹ chung, sổ chung và danh mục của nhà sẽ
  biến mất với mọi người."* Server: nhà `Dissolved`, mọi hàng của nhà xoá mềm, phát `household.changed`.
- Mọi máy liên quan chạy đường dọn 2 (4.6) khi thấy mình không còn ở nhà (sự kiện hoặc lần đọc trạng thái kế tiếp).

### 5.6 Chủ nhà hết Premium
Server đặt nhà `ReadOnly` (lúc gói hết hạn — cùng chỗ phát `account.downgraded` — và kiểm lại khi đọc trạng thái nhà); gia hạn ⇒
`Active`. Client **chỉ đọc** trạng thái, không tự hẹn giờ. Khu *Nhà mình* hiện dải *"Nhà đang ở chế độ chỉ xem — chủ nhà cần gia
hạn Premium"*; mọi nút ghi vào nhà khoá từ form (đọc trạng thái nhà trước khi mở form). Dữ liệu không mất.

### 5.7 Quyền gói
- `MaQuyen` thêm **`giaDinh`** (khoá server đề xuất `household`, tên *"Gia đình"*), `macDinhKhiThieu = false` — thiếu khoá thì
  **đóng**, như `ai_assistant` (bảng quyền cũ của server chưa biết tính năng này). Mọi chỗ hỏi qua `duocDung` (quét 21).
- Trần thành viên đọc từ `limits` của `/subscription-info` (khoá đề xuất `household_members`), thiếu ⇒ 6.
- Chỉ **tạo nhà** và **giữ nhà Active** cần Premium (của chủ nhà). Tham gia, ghi vào nhà khi nhà Active: không cần.

### 5.8 Trạng thái nhà ở client
`NhaRepository` (khuôn `GoiRepository`): bản lưu theo tài khoản trong secure storage (`nha_tai_khoan_<idaccount>`: id nhà, tên,
vai của tôi, trạng thái, danh sách thành viên + vai, trần, mốc nhận). `lamMoi()` không ném. Làm mới khi: đăng nhập (hook mới
`datNha` của `PhienDieuPhoiThat`, chạy **trước** bộ quét như `datGoi` — G93), app `resumed` (giãn 5 phút), sự kiện
`household.changed`, gặp một trong bốn mã 4.2, sau mỗi thao tác 5.1–5.5. Thấy mình **không còn** ở nhà đã lưu ⇒ chạy đường dọn 2.

## 6. Màn hình (đưa lên Stitch trước khi làm — nếp *đưa màn mới lên Stitch*)

1. **Nhà mình** (route `/nha`, mục drawer mới) — chưa có nhà: minh hoạ + hai nút *Tạo nhà* / *Tham gia bằng mã*; có nhà: tên nhà,
   dải trạng thái (nếu `ReadOnly`), danh sách thành viên (tên, vai, *Bạn*), nút *Mời* (chỉ chủ), menu *Quản lý* / *Rời nhà*; chỗ
   trống cho lối vào các phần 2–4 (chưa dựng ở spec này).
2. **Tạo nhà** (`/nha/tao`, qua cửa quyền).
3. **Mời thành viên** (`/nha/moi`).
4. **Tham gia bằng mã** (`/nha/tham-gia`).
5. **Quản lý thành viên** (`/nha/thanh-vien`) — đổi vai, mời ra, chuyển chủ, giải tán.
6. **Hộp xác nhận** rời / mời ra / chuyển chủ / giải tán.

Bố cục kiểm ở **360 dp** và có ca bàn phím hệ thống mở (bẫy G58). `/nha` là route **gốc ngoài shell** như `/budget` (mở từ drawer):
tới tab dùng `go`, không `push` (bẫy điều hướng nhóm D).

## 7. Cấu trúc mã client

### 7.1 Mảng mới `lib/features/household/` (luật vị trí tệp mục 8 `KIEN_TRUC_CLIENT_APP.md`)
- `data/models/` — `NhaEntity`, `ThanhVienNhaEntity`, `XemTruocLoiMoi`, `VaiNha` / `TrangThaiNha` (+ bộ đọc JSON).
- `data/datasources/household_api.dart` — mọi lời gọi server (mục 8.2); trang **không** gọi thẳng (quét 31).
- `data/repositories/nha_repository.dart` + `_impl.dart` — trạng thái nhà, bản lưu theo tài khoản, các thao tác 5.1–5.5.
- `domain/` — hàm thuần: `quyen_nha.dart` (vai × trạng thái ⇒ được tạo mã / đổi vai / ghi vào nhà / rời…), `ma_moi.dart` (chuẩn
  hoá + kiểm dạng mã), `cau_loi_nha.dart` (mã lỗi ⇒ câu tiếng Việt, một chỗ).
- `application/` — `tham_gia_nha.dart` (tham gia ⇒ lưu trạng thái ⇒ xoá mốc ⇒ `syncNow`), `don_du_lieu_nha.dart` (đường dọn 2).
- `presentation/bloc/nha_cubit.dart`; `pages/` 5 trang; `widgets/` hộp xác nhận, thẻ thành viên.

### 7.2 Chạm vào `core` (không import `features/` ngoài năm tệp domain thuần — quét 25)
- **Drift v32** — cột `idhousehold` (INTEGER nullable) cho `wallets`, `transactions`, `goals`, `budgets`, `categories` + chỉ mục;
  bước di trú thêm cột; fixture tối thiểu của các test di trú cũ phải có cột (bẫy *thêm bước di trú* ở `CLAUDE.md`).
- **DAO** — mọi truy vấn *"của tôi"* trên 5 bảng thêm `idhousehold IS NULL`: **25** chỗ lọc `idaccount` ở ví (6) · giao dịch (13)
  · ngân sách (3) · mục tiêu (3) (đếm `grep -c "idaccount.equals"` 2026-10-23; hoá đơn 7 chỗ không đổi vì bảng hoá đơn không thêm
  cột) — **cộng** các truy vấn danh sách danh mục cá nhân trong
  `category_dao.dart` (22 chỗ lọc `idaccount`; đếm lại khi thi công — một số là bảng tra tên / `getNamesInUse` phải xét riêng:
  bảng tra tên **giữ** danh mục của nhà để khoản của nhà có tên; trùng tên cá nhân **không** đếm danh mục nhà). Spec này
  **không** hiện danh mục nhà ở đâu cả; truy vấn theo nhà duy nhất cần là phép xoá theo `idhousehold` của đường dọn 2 (4.6).
  Truy vấn đọc theo nhà (`…TheoNha(idhousehold)`) thêm ở phần con nào cần nó.
- **Test quét 37** — truy vấn trên 5 bảng có lọc `idaccount` mà không ràng `idhousehold` (`isNull()` hoặc `equals`) là đỏ;
  danh sách miễn trừ có lý do + ngày (bảng tra tên, `purgeDataForOtherAccounts`).
- **Đồng bộ** — `thu_gom_day.dart` / `sync_payload_normalizer.dart` gửi `idhousehold`; `anh_xa_keo_ve.dart` đọc (`Value.absent`
  khi thiếu); `_permanentCodes` +4 mã; hợp đồng `sync_payload_contract_test.dart`.
- **`purgeDataForOtherAccounts(keep, {nhaGiu})`** — luật 4.6 (1).
- **Kênh thời gian thực** — `RealtimeEvent` thêm một giá trị cho `household.changed` (enum **bảy** giá trị).

### 7.3 Điểm ghép
- `core/di` — đăng ký `HouseholdApi` (`sl<DioClient>().dio`), `NhaRepository`, hai bộ điều phối; nối bộ nghe `household.changed`.
- `core/auth/phien_dieu_phoi_that.dart` — hook `datNha` (sau `datGoi`, trước bộ quét), hook `_donTaiKhoanKhac` nhận `nhaGiu`;
  `dongPhien` gỡ trạng thái nhà khỏi RAM (không xoá bản lưu).
- `core/router/app_router.dart` — 5 route `/nha/*`; `/nha/tao` qua cửa quyền `giaDinh`.
- Drawer — thêm mục *Nhà mình* vào `kMucDrawer` (`features/home/presentation/widgets/drawer_trang_chu.dart`); ca *"MỌI trang tính
  năng vào được từ menu"* tự canh.

## 8. Hợp đồng với backend (tóm tắt — bản đầy đủ là đơn 50 `CAN-LAM/GIA_DINH_NEN_MONG.md`; đơn thắng mục này nếu lệch)

### 8.1 CSDL — một tệp `database/N_*.sql` (N = số kế tiếp chưa dùng; đơn 49 vế C đang xin đổi tệp 27 trùng số sang 37)
- Bảng `household`, `household_member`, `household_invite` (3.1) + CHECK vai / trạng thái + chỉ mục duy nhất *một nhà đang ở mỗi
  tài khoản* + *đúng một Owner mỗi nhà*.
- Cột `Idhousehold` (INT NULL, FK → `household`, chỉ mục) cho `wallet`, `transaction`, `goal`, `budget`, `category`; trigger
  `Server_update_at` giữ nguyên.
- Chỉ mục duy nhất cá nhân thêm `WHERE "Idhousehold" IS NULL`; chỉ mục mới theo nhà cho tên ví, tên danh mục.
- Câu kiểm sau khi áp: đếm cột / chỉ mục / CHECK mới (đơn ghi sẵn câu `SELECT`).

### 8.2 API (tên đề xuất — backend được đổi, nhưng phải ghi lại trong đơn trả lời)
| Việc | Đề xuất |
|---|---|
| Tạo nhà | `POST /households` `{ name }` |
| Trạng thái nhà của tôi | `GET /households/me` ⇒ `{ household: {id, name, status, maxMembers, ownerId} \| null, myRole, members: [{idaccount, displayName, role, joinedAt}] }` |
| Tạo / huỷ / liệt kê mã mời | `POST /households/invites {role}` ⇒ `{code, role, expiresAt}` · `DELETE /households/invites/:code` · `GET /households/invites` |
| Xem trước mã | `GET /households/invites/:code` ⇒ `{householdName, ownerName, memberCount, maxMembers, role, expiresAt}` |
| Tham gia | `POST /households/join {code}` |
| Đổi vai | `PATCH /households/members/:idaccount {role}` |
| Chuyển chủ | `POST /households/transfer-owner {idaccount}` |
| Mời ra | `DELETE /households/members/:idaccount` |
| Rời nhà | `POST /households/leave` |
| Giải tán | `DELETE /households` |

Mã lỗi API (body 4xx, `code` ở **cấp gốc** như mọi lỗi hiện có): `HOUSEHOLD_INVITE_INVALID` · `HOUSEHOLD_INVITE_EXPIRED` ·
`HOUSEHOLD_INVITE_USED` · `HOUSEHOLD_ALREADY_IN_ONE` · `HOUSEHOLD_FULL` · `HOUSEHOLD_OWNER_MUST_TRANSFER` · `HOUSEHOLD_NOT_OWNER` ·
`HOUSEHOLD_CLOSED`; Premium thiếu ⇒ 403 `FEATURE_DISABLED` hiện có.

### 8.3 Đồng bộ, quyền, sự kiện
Phạm vi kéo về (4.1); bốn mã đẩy (4.2); sao danh mục khi lập nhà (3.3); `ReadOnly` theo Premium của chủ (5.6); khoá quyền
`household` + `limits.household_members` trong `/subscription-info`; `household.changed` + `sync.completed` tới mọi thành viên
(4.5); giải tán = xoá mềm mọi hàng của nhà (quy tắc 5 — không xoá cứng).

## 9. Kiểm thử và nghiệm thu

- **Domain** — `quyen_nha` (bảng vai × trạng thái × hành động), `ma_moi`, `cau_loi_nha` (mỗi mã một câu, không câu trùng).
- **Repository** với API giả (`test/helpers/`) — lưu / đọc theo tài khoản, `lamMoi` không ném, thấy mình bị gỡ ⇒ gọi đường dọn.
- **Bộ điều phối** — tham gia ⇒ `clear` mốc + `syncNow`; dọn ⇒ chỉ xoá hàng đúng nhà, không đụng hàng riêng.
- **DAO / di trú** — v31 → v32 giữ dữ liệu; mọi truy vấn cá nhân bỏ hàng của nhà (ca có một danh mục nhà cùng tên danh mục riêng);
  `purgeDataForOtherAccounts` ba ca của 4.6 (1).
- **Đồng bộ** — hợp đồng có `idhousehold`; bốn mã vào `_permanentCodes` (ca: hàng bị từ chối không được gửi lại).
- **Quét 37** + bản sai cấy thử (bỏ `isNull()` ở một truy vấn ⇒ đỏ).
- **Widget** — 5 trang ở 360 dp, có ca bàn phím mở, dựng bằng `AppTheme.lightTheme`; cửa quyền `/nha/tao` dựng router thật.
- **Nghiệm thu** (khi backend dev có API — **hai máy thật, hai tài khoản**): tạo nhà (Premium) → mời *Thành viên* + mời *Chỉ xem*
  → tham gia trên máy kia, danh mục nhà về → đổi vai → chuyển chủ → rời → mời ra (máy bị mời ra tự dọn) → giải tán → chủ hết Premium
  (nhà chỉ xem, dải hiện). Danh mục nhà **không** lọt vào danh sách danh mục cá nhân, Trang chủ / Sổ / Phân tích không đổi số.

## 10. Rủi ro và điều đã cân nhắc

- **Hướng B, C bị loại** (mục 1) — B lệch *ba vai áp cho cả nhà*; C không làm được quỹ thật.
- **Rò dữ liệu nhà vào tổng cá nhân** — rủi ro lớn nhất của hướng A cùng bảng; chặn bằng quét 37 + ca DAO + nghiệm thu so số.
- **LWW giữa người** — 4.4, chấp nhận có ghi.
- **Phụ thuộc backend** — client làm xong được tới mức API giả; nghiệm thu phải chờ đơn 50.
- **Số dư ví của nhà** (spec 2): `SoDuViService` là chỗ duy nhất ghi `balance`; neo *Số dư ban đầu* có id tất định từ `walletId`
  — chỉ máy tạo ví của nhà được đặt neo, máy khác nhận qua kéo về; thứ tự G85 áp cho giao dịch của nhà kéo về. Ghi ở đây để spec 2
  không quên.
- **Một tài khoản một nhà** — đơn giản hoá cố ý; mở rộng sau là đổi chỉ mục + màn chọn nhà.
