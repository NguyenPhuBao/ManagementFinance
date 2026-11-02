# Gia đình từ phần 2a tới phần 3 — thi công cả client lẫn backend trên nhánh dự phòng

> **Ngày:** 2026-11-01 · **Người đọc:** người thi công (client + backend) ở các phiên sau.
> **Nhánh:** `TranQuangDat-backend`, worktree `.superpowers/backend-worktree`. Mọi mã của spec này nằm trên nhánh ấy.
> **Luật nghiệp vụ:** `docs/Family/00`, `01`, `02A`, `02B`, `02C`, `02D`, `03` vẫn là nguồn; đọc tệp tương ứng trước mỗi đợt. Spec này chỉ ghi **quyết định mới, thứ tự thi công và các chỗ mã hiện tại phải đổi**. Spec này thắng bộ `Family` khi lệch; chỗ lệch ở mục 2.

---

## 1. Vì sao có spec này

Người dùng muốn hoàn chỉnh phần gia đình thay vì chờ backend. Ngày 2026-11-01 người dùng cho tạo nhánh `TranQuangDat-backend` để client tự sửa backend, và chốt: *"nếu backend chưa hoàn thành xong toàn bộ thì có thể lấy nhánh này ra để làm thành nhánh chính"*.

Đo trên `13fddd09` (2026-11-01):

| Có sẵn ở backend | Thiếu ở backend |
|---|---|
| `wallet`, `transaction`, `goal`, `budget`, `category` có `Idhousehold`; ma trận vai; trần ví `HOUSEHOLD_WALLET_LIMIT` | `transaction.Idfund_pair` (0 kết quả ở `modules`, `prisma`, `database`, `api`) |
| `/me` có `formerMembers`, `maxSharedWallets`; cột `household.Contribution_due_day` | `spendingLimits`, `contributionQuotas`, `myAutoContributions` và ba bảng của chúng |
| 16 endpoint `/api/households`, kịch bản 50 / 50 | L1, C1, C2, C3 (`02B` mục 7.2, `02C` mục 5.2); chỉ mục `uq_goal_household_wallet_active` |

Client hôm nay (schema v32): nhà tạo và mời được, **chưa có đường ghi vào nhà**, `TransactionEntity` chưa có `idhousehold`.

## 2. Quyết định

Người dùng chốt qua câu hỏi chọn được ngày 2026-11-01:

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Làm tới đâu | **Thiết kế một lượt từ 2a tới 3**; thi công năm đợt, mỗi đợt dừng được |
| 2 | Nơi làm | **Toàn bộ client + backend trên `TranQuangDat-backend`** |
| 3 | Thứ tự | **2a → 3 → 2b → 2c → 2d** |
| 4 | Danh mục của nhà | **Thêm / sửa được, làm ở đợt 1**, Chủ nhà và Thành viên (`00` mục 3) |
| 5 | Form ghi khoản | **Dùng lại form Thêm giao dịch** (`02A` mục 4), không trang riêng |
| 6 | Khoản chưa đẩy khi bị mời ra lúc offline | Hàng của nhà bị bỏ; khoản góp trả tiền về ví riêng kèm thông báo |
| 7 | CSDL | Áp `Idfund_pair` lên `PersonFinance` có sao lưu; **cấm áp lên Supabase**. Bảng của 2b, 2c và chỉ mục của 3 phải xin phép lại khi tới đợt |

Backend tự trả lời các câu mở của `Family`:

| Câu | Trả lời |
|---|---|
| `00` Q1 | Mỗi đợt một tệp `database/N_*.sql`, bắt đầu từ **45** |
| Q-A1 | Giữ tên `Idfund_pair` / khoá `idfund_pair` |
| Q-A2 | Dùng cột `household.max_shared_wallets` đã có |
| Q-A3 | Server không kiểm hai nửa khớp nhau |
| Q-B1, Q-C2, `00` Q4 | Endpoint riêng cho từng loại, thay toàn bộ danh sách mỗi lần lưu |
| Q-B2 | Trần 20 dòng / (ví, người) |
| Q-B3 | Xoá thật ở bảng cấu hình |
| Q-C1 | Một ngày hạn góp cho cả nhà |
| Q-C3 | `Enabled_at` do server ghi |
| Q-3.1 | Mục tiêu chung dùng bảng `goal` |

## 3. Thứ tự và tiêu chí xong

| Đợt | Nội dung | Xong khi |
|---|---|---|
| **1. 2a** | Mục 4–7 | Kịch bản đo `02A` mục 13 đạt trên máy ảo + Realme |
| **2. Mục tiêu chung** | `03` | Kịch bản đo `03` mục 7 đạt |
| **3. Hạn mức** | `02B` | Kịch bản đo `02B` mục 10 đạt |
| **4. Định mức + tự góp** | `02C` | Kịch bản đo `02C` mục 8 đạt, kể cả lượt nền |
| **5. Ngân sách + báo cáo** | `02D` | Kịch bản đo `02D` mục 7 đạt |

Mỗi đợt: áp migration (nếu có, đã xin phép) → backend + kịch bản → Stitch → client theo TDD → `flutter test` + `flutter analyze` đối chiếu mức nền → đo trên máy → cập nhật tài liệu. Mỗi đợt có kế hoạch thi công riêng, viết khi tới đợt để bám mã lúc ấy.

## 4. Backend đợt 1

**`database/45_add_transaction_fund_pair.sql`**

```sql
ALTER TABLE "transaction" ADD COLUMN IF NOT EXISTS "Idfund_pair" VARCHAR(36) NULL;
CREATE INDEX IF NOT EXISTS "idx_transaction_fund_pair"
  ON "transaction" ("Idfund_pair") WHERE "Idfund_pair" IS NOT NULL;
```

**Thêm vào `schema.prisma`:** `idfund_pair String? @db.VarChar(36) @map("Idfund_pair")` ở model `transaction`. Sinh lại client trong worktree, không đụng `src/Backend`.

**`modules/sync/sync.repository.js`:**
- `mapEntityFields('transaction', …)` nhận `idfund_pair`, `fundPairId`, cạnh khối `idwallet_transfer` (dòng 61–64).
- Ghi ở **cả hai** khối `data`: tạo và sửa. Thiếu là bị bỏ qua im lặng. Khối sửa dùng `mapped.idfund_pair || existing.idfund_pair` — **server không bao giờ gỡ mã cặp đã gắn** (máy có cột cục bộ `null` gửi `null` sẽ xoá mã nếu dùng `!== undefined`; đã đổi sau 1A, mục 15).
- `/sync/pull` trả khoá `idfund_pair` (chuỗi hoặc `null`).

**`modules/sync/sync.service.js`:**
- `Transfer` mang `idfund_pair` ⇒ `HOUSEHOLD_SCOPE_MISMATCH`.
- Hàng của nhà có `Idfund_pair`: **sửa** chỉ người ghi (`existing.Idaccount`), khác ⇒ `HOUSEHOLD_ROLE_FORBIDDEN`. Chủ nhà vẫn **xoá** được; "xoá" là `operation === 'delete'` (không đọc `is_deleted` trong payload; client thật luôn xoá bằng op `delete`). `isNewTx` loại op `delete`. Bảng `01` mục 3.
- Mọi thao tác mang `idcategory` / `categoryId` trỏ danh mục có `Idhousehold` khác phạm vi đích (riêng ↔ nhà, nhà A ↔ nhà B, **kể cả khuôn mặc định** vốn không có `Idhousehold`) ⇒ `HOUSEHOLD_SCOPE_MISMATCH` (`validateEntityScope`, thêm ở 1B, `6684cc6c`). Client 1B không tạo được ca này (danh mục chọn từ cây của nhà); đây là lưới.
- Giao dịch riêng trỏ `idgoal` tới mục tiêu của nhà ⇒ `HOUSEHOLD_SCOPE_MISMATCH` (`validateEntityScope` đã có; thêm ca canh).

**Kiểm chứng:** `KIEM-THU/chay_kiem_gia_dinh_2.js` chạy trên CSDL thử `flowmoney_kiem_thu` (khuôn `chay_kiem.js`), không `.env`. Ca tối thiểu: khứ hồi `idfund_pair` qua push + pull ở cả tạo lẫn sửa · `Transfer` có mã cặp bị từ chối · Chủ nhà sửa nửa của nhà của người khác bị từ chối, xoá thì được · người ghi sửa được · hàng riêng mang mã cặp về đúng máy chủ nhân. `verify:household` vẫn 50 / 50.

## 5. Dữ liệu client đợt 1

- **Drift v33:** cột `transactions.fund_pair_id` (TEXT NULL), **đi qua đồng bộ**; bước di trú + fixture của test di trú cũ. Đọc kỹ cảnh báo di trú ở *Lệnh hay dùng* của `CLAUDE.md`.
- **`TransactionEntity`:** thêm `idhousehold`, `fundPairId`, cùng mapper và lối ghi. Chưa có trường này thì khoản của nhà lưu thành khoản riêng. Đây là việc đầu của đợt 1.
- **Payload:** `thu_gom_day.dart` gửi `idfund_pair`; `sync_payload_contract_test.dart` thêm khoá (quy tắc 4); nhánh kéo về `Value.absent()` khi server không trả khoá.
- **Đọc dữ liệu nhà:** repository riêng trong `features/household/data/repositories/`, DAO thêm phép đọc theo `idhousehold`. **Không nới** truy vấn cá nhân. Phân loại bộ chọn ví mới ở quét 2 (đọc ví viết trên một dòng), tuân quét 37.
- **Ví chung:** `WalletRepository.addWallet` chưa nhận `idhousehold`. Thêm tham số hoặc lối riêng; `_kiemRangBuocServer` so tên **trong nhà** khi là ví nhà (`uq_wallet_household_name_active`); ép không mặc định, không tính vào tổng. Số dư là cache cục bộ (G113 nợ 9 đã đóng), neo kế thừa `idhousehold` (nợ 1 đã đóng, chưa đo trên máy).
- **Một định nghĩa phân loại:** `household/domain/loai_khoan_nha.dart` theo bảng `02A` mục 3. Mọi màn và phép tính đi qua đây.

## 6. Quyền

`ViecNha.ghiDuLieu` gộp mọi thực thể (G113 nợ 6). Tách theo `01` mục 3 và `00` mục 3:

| Việc | Chủ nhà | Thành viên | Chỉ xem hoặc nhà chỉ xem |
|---|---|---|---|
| Tạo / sửa / lưu trữ / xoá ví chung; mục tiêu, ngân sách, hạn mức, định mức | ✓ | | |
| Chi, thu, góp, rút, tự góp; thêm / sửa danh mục của nhà | ✓ | ✓ | |
| Chuyển giữa hai ví chung | ✓ | | |
| Sửa khoản thu / chi thường | mọi khoản | khoản của mình | |
| Sửa khoản có mã cặp | chỉ của mình | của mình | |
| Xoá khoản | mọi khoản | khoản của mình | |
| Sửa / xoá khoản **chuyển** (`Transfer`) | ✓ | | |

Hàm `duocSuaKhoanNha` / `duocXoaKhoanNha` nhận thêm `laChuyen` (mã: `household/domain/quyen_nha.dart`): khoản chuyển chỉ Chủ, kể cả khoản do Thành viên ghi (đường thật là Chủ cũ bị hạ xuống Thành viên). Nơi gọi tính `laChuyen` từ cả `type` hiện có lẫn `type` mới của form.
| Xem ví, hoạt động, bảng góp, báo cáo | ✓ | ✓ | ✓ |

Chủ nhà hết Premium ⇒ nhà `ReadOnly` ⇒ mọi người như cột cuối.

Nút không được phép thì **không hiện** (không nút chết, quét 10). Server vẫn thi hành lại mọi luật; mã từ chối đã nằm trong `_permanentCodes`.

## 7. Ba lỗi đồng bộ phải sửa TRƯỚC khi mở đường ghi

Viết ca đỏ trước cho từng lỗi. Cả ba đều hỏng im lặng.

**7.1 Hàng sửa hộ không bao giờ lên server.** `transactionDao`, `walletDao`, `goalDao`, `budgetDao`.`getPending(idaccount)` và `categoryDao.getSyncableCategories` lọc `idaccount = tôi`, trong khi `idaccount` của hàng nhà là **người ghi**. Chủ nhà sửa khoản của Thành viên, Chủ mới sửa ví của Chủ cũ, Thành viên sửa danh mục người khác tạo: hàng nằm `pending` mãi. Đổi thành `idaccount = tôi ∨ idhousehold = nhà đang ở`, truyền nhà từ `NhaRepository` vào `ThuGomThaoTacDay`. Khối 1b thêm ca khoá `idhousehold` (G113 nợ 4). Backend giữ `Idaccount` người ghi đã đo (57.4).

**7.2 Sửa danh mục của nhà làm mất `idhousehold`.** Đường sửa đi `categoryDao.insert` (= `insertOrReplace`), companion từ draft không có trường này (G113 nợ 3). Phải mang trường theo; đường đọc danh mục cá nhân đang lọc `idhousehold IS NULL` giữ nguyên. Kiểm trùng tên và bộ chọn danh mục của nhà đọc **`getCuaNha`** (theo nhà), **không** qua cửa quét 40 (cửa ấy tồn tại để ẩn theo khuôn mặc định, danh mục nhà không có luật đó). Từ khoá: danh mục nhà **không có từ khoá** ở 1B (draft `keywords: []`, không `replaceKeywords`; từ khoá nhà không đọc được trên máy thành viên) — mục 16.

**7.3 Dọn nhà xoá hàng chưa đẩy.** `purgeDataForOtherAccounts` (khi `nhaGiu` null) và `xoaHangCuaNha` xoá cả `pending` (G113 nợ 2):

| Tình huống | Xử lý |
|---|---|
| Người dùng bấm *Rời nhà* / *Giải tán* | Đẩy một lượt trước khi gọi API; còn hàng chưa đẩy được thì hỏi lại |
| Mở app, kho trạng thái nhà vắng hoặc đọc hỏng | Không xoá hàng `pending` của nhà do mình ghi, cùng ví chúng trỏ tới (khoá ngoại), ở **cả năm bảng**. Còn dấu bền "đã xử lý tới nhà H" thì **hỏi `/me` rồi mới quyết** (người dùng chốt 2026-11-01): còn ở H ⇒ giữ và đẩy; đã bị mời ra ⇒ `DoiNha(H → null)`; offline ⇒ giữ, chờ. Giữ tới khi đẩy được hoặc server từ chối rõ |
| Bị mời ra / nhà giải tán khi offline | Lượt đẩy nhận mã vĩnh viễn ⇒ hàng lỗi được dọn; khoản góp qua mục 8 |
| Đăng nhập tài khoản khác | Như cũ: mọi dữ liệu tài khoản cũ bị dọn |

⚠️ Giữ nguyên chốt ở `purgeDataForOtherAccounts`: lỗi xoá khoá ngoại ở đây khoá người dùng ở màn Đăng nhập (G113 lỗ hổng 3). Có ca canh.

## 8. Góp và rút

Theo `02A` mục 5–6.

- **`GopQuyService`** (`household/application/`): tạo / sửa / xoá **hai nửa trong một giao tác Drift**, khuôn `addTransactions` (neo số dư trước khi ghi). *Tiền mặt trao tay* chỉ có nửa của nhà, vẫn mang `fundPairId`. Mã cặp là UUID v4.
- **`GopQuyConflictResolver`:** nghe `pushResultStream`, khuôn `BillPaymentConflictResolver`, đăng ký và bắt đầu nghe cùng chỗ với nó (quét 5 có khuôn). Mã từ chối nửa của nhà ⇒ xoá mềm nửa riêng + thông báo `gopQuyBiTraVe`. Chịu **hai** lượt phát cho cùng một thất bại; khoá `gopTraVe:<cặp>` chống trùng.
- **Bộ gỡ khi Chủ nhà xoá:** kéo về thấy nửa của nhà mang cờ xoá mà nửa riêng còn sống ⇒ đọc `/me`. Mình còn ở đúng nhà của nửa riêng (`coNha`, gồm cả nhà `ReadOnly`) ⇒ gỡ + `gopQuyBiXoa`. Nhà giải tán hoặc mình đã rời ⇒ giữ. Offline ⇒ hoãn lượt sau.
- **Rời nhà:** nửa riêng ở lại thành khoản riêng thường.
- **Thông báo:** `NotificationKind` thêm hai loại nhóm `giaDinh`, sửa hai `switch` không `default` và `tatCaUngVien()`. Chiều phụ thuộc thật là `household/application → notification/domain` (cạnh từ `application/`, không vào quét 29).

**Số liệu cá nhân** (`02A` mục 7.2): nửa riêng tính chi / thu qua `khoanVaoThongKe`; các khối gom theo danh mục dùng nhãn ảo *"Góp quỹ gia đình"* / *"Rút quỹ gia đình"*; `thuNhapCua` không gồm nửa rút (cờ `KhoanThuChi.laRutQuy` / `DiemVayNo.rutQuy`, mã ảo chỉ để gom nhãn); `xetGan` bỏ mọi hàng có mã cặp; `khoaNhomCua` (khoản lặp) bỏ khoản có mã cặp; `laGhiChuMay` **nhận thêm** hai tiền tố `kTienToGopQuy` / `kTienToRutQuy` (sau khi rời nhà mà gắn danh mục thì nửa riêng vẫn không vào mẫu học — 1B, Task 9); ngân sách theo danh mục không tính. Mở nửa riêng từ Sổ giao dịch thì vào form góp, không form thường.

## 9. Form chế độ nhà

`ThemGiaoDichCubit` đã 1.130 dòng, trần quét 23 là 1.200. **Không thêm logic vào cubit.**

- `household/data/them_giao_dich_nguon_nha.dart` hiện thực `ThemGiaoDichNguon`: `napViDangDung` trả ví chung đang hoạt động, danh mục trả của nhà; phản hồi gợi ý, từ khoá học, biến động, ảnh, AI, ngân sách cá nhân đều rỗng hoặc không làm gì. Có ca canh từng lối.
- `AddTransactionPage` nhận một tham số phạm vi nhà; khi có thì ẩn Nhập nhanh, Quét, Nói, thẻ gợi ý, tách khoản, và gắn `idhousehold` vào hàng lưu. *Chuyển khoản* chỉ hiện cho Chủ nhà.
- Đường Lưu đi `TransactionBloc` như cũ; `idaccount` từ phiên (quy tắc 2).
- **Chặn lối sang:** nút + thanh dưới và mọi lối mở `/add` cá nhân không nhận phạm vi nhà.
- Đợt 3 và 5 thêm hộp cảnh báo ở bước chuẩn bị lưu của form, chung một hộp (`02B` mục 8, `02D` mục 2.1); logic nằm ở `household/domain`, nguồn cung cấp.

## 10. Màn hình

Vẽ Stitch trước khi viết mã giao diện, dự án `5106367939423432838`. Lượt gọi có thể `timeout` mà màn vẫn hiện sau lâu; **không gọi lại**, nhờ người dùng nhìn và xác nhận.

| Đợt | Màn |
|---|---|
| 1 | Nhà mình có khối Ví chung · Tạo / Sửa ví chung · Chi tiết ví chung (hai tab) · Góp / Rút · Thêm giao dịch chế độ nhà · Hoạt động · Hộp xoá khoản góp · Danh mục của nhà |
| 2 | Khối công tắc trong form ví · Thẻ ví có tiến độ |
| 3 | Hạn mức · Sửa hạn mức một người · Thẻ Hạn mức của bạn · Dòng *Còn …* · Hộp vượt mức |
| 4 | Định mức góp · Tự góp · Cột đủ / thiếu |
| 5 | Ngân sách của nhà · Báo cáo tháng · Hàng công tắc |

**Mã màn đợt 1** (design system `assets/e8b7d56ef9284443bfacb7474e52c74a`, tạo 2026-11-01; năm lượt báo `timeout` nhưng màn vẫn hiện sau khoảng 7 phút):

| Màn | Mã |
|---|---|
| Nhà mình - Có ví chung, vai Chủ nhà | `d2a8c9bb3ab0435d9227378ed06f0e78` |
| Tạo ví chung | `3bfb38b3a2a940029ab6599e63a5e1be` |
| Chi tiết ví chung - tab Giao dịch | `ac57e216b5f7489aa34e1e957df347ca` |
| Chi tiết ví chung - tab Bảng góp | `6d63311f552142daaa089a2caff6c08a` |
| Góp vào quỹ | `f77f5bc010c445b98c7dfe5c61d28817` |
| Thêm giao dịch - Chế độ nhà | `5a53df6e68fa4b75ac094034fa0553c9` |
| Hoạt động của nhà | `50af4171315f47e6a31ae8d9b7fa7b00` |
| Danh mục của nhà + Hộp xoá khoản góp | `6dc96c4aaa4846fb91a30a67a45a22fa` |

Stitch vẽ thêm vài chi tiết không nằm trong yêu cầu, ví dụ chấm xanh cạnh tên nhà, nút ba chấm ở Nhà mình, phím *+ − .* ở bàn phím. Form chế độ nhà giữ bàn phím thật của `AddTransactionPage`, các chi tiết thừa ghi vào kế hoạch 1B khi thi công.

Điều hướng: route gốc ngoài shell, vào từ drawer, như lát 2. `go` khi sang tab trong shell, `push` trong khu nhà (bẫy *Đụng vào điều hướng*). Dữ liệu nhà không hiện ở Trang chủ, Sổ, Phân tích, Ngân sách cá nhân (quyết định #5). Bố cục kiểm 360 dp, có ca bàn phím hệ thống mở, số 13 chữ số.

## 11. Các đợt sau: chỗ mã cần chú ý

- **Đợt 2 (`03`):** `GoalAutoDepositRunner` đọc `goalDao.getAll(idaccount)`, phải loại hàng của nhà, có ca riêng. Tiến độ suy từ số dư ví, không đọc `currentAmount`. Migration chỉ mục cần xin phép.
- **Đợt 3 (`02B`):** bảng `household_spending_limit`, L1, `/me` thêm `spendingLimits` **lọc ở server**. `NhaCuaToi` + kho nhớ theo tài khoản; offline dùng bản đã nhớ. Một hàm kỳ `ky_han_muc.dart`, dùng `tuan_iso.dart`. Dọn dòng khi đổi vai / rời / chuyển chủ / giải tán.
- **Đợt 4 (`02C`):** hai bảng, C1–C3. `TuGopRunner` nối vào `NotificationScanner.scan()` **cả** `main.dart` lẫn `chay_nen.dart`, dưới khoá thuê v30. Kỳ theo UTC+7 cố định, id tất định namespace riêng. Đo lượt nền theo bẫy ở hàng *trích tiền tự động* của `CLAUDE.md`.
- **Đợt 5 (`02D`):** không backend. `budget/` nhận phạm vi nhà qua nguồn, không nhân đôi trang. Biểu đồ dùng lại donut (`fl_chart` 1.2.0, `FlClipData.all()`); tầng vẽ nghiệm thu bằng mắt.

## 12. Kiểm thử

- **Domain, viết trước:** `loai_khoan_nha` mỗi ô bảng một ca, neo và điều chỉnh không lọt; bảng góp (người đã rời, tiền mặt trao tay, rút); số liệu nhà với biên `[from, to)`.
- **Application:** `GopQuyService` lỗi giữa chừng không để lại nửa nào; resolver chạy một lần dù hai lượt phát; bộ gỡ ba ca (`Active`, giải tán, offline).
- **Đồng bộ:** `sync_payload_contract_test`; di trú v33 từ các bản cũ; ba lỗi mục 7.
- **Không rò:** thẻ tổng Sổ = Trang chủ khi có khoản góp; bộ chọn ví cá nhân không có ví chung; form cá nhân không nhận phạm vi nhà; quét 37.
- **Widget:** các màn đợt 1 ở 360 dp theo khuôn `takeException` + đo chiều cao chữ.
- **Backend:** mục 4. ⚠️ Không chạy test backend nơi có `.env` trỏ CSDL dùng chung: `admin.payment.test.js` chạm CSDL thật.
- Test quét mới lấy số **43**.

## 13. Đo trên máy

- **Máy:** máy ảo `FlowMoney_16G` (tài khoản 30, Chủ nhà, Premium) + Realme (`dat`, Thành viên). Ghi đúng là **một máy thật + một máy ảo**. OnePlus cắm được thì thêm.
- **Backend:** `node index.js` từ worktree, biến môi trường trỏ `PersonFinance`, khoá dev; log phải ghi đúng tên CSDL. Thay PID đang chạy từ `src/Backend`.
- **APK:** dựng từ worktree, so SHA-1 trước khi cài. ⚠️ Mã nhánh này gửi `idfund_pair`; backend cũ của `src/Backend` bỏ qua im lặng, nên đừng trỏ APK nhánh này về nó.
- **Realme:** chép CSDL ra `D:\FlowMoney-saoluu\` trước khi cài. Đừng đăng nhập tài khoản thử trên Realme (dọn dữ liệu của `dat`).
- **Kịch bản đợt 1:** `02A` mục 13, thêm: Chủ nhà sửa khoản của Thành viên ⇒ lên server và về máy kia (mục 7.1); sửa danh mục của nhà ⇒ vẫn thuộc nhà (mục 7.2); rời nhà có hàng chưa đẩy (mục 7.3); neo ví chung lần đầu đo trên máy (G113 nợ 1).

## 14. Rủi ro và giới hạn

- **Nhánh tách xa `main`:** gộp `origin/main` vào nhánh khi backend có PR mới. Tệp hay xung đột: `sync.service.js`, `sync.repository.js`, `household.service.js`, `schema.prisma`. Số migration có thể trùng nếu backend cũng thêm.
- **Supabase và Render chưa có các cột mới:** nhánh chưa chạy được trên môi trường chung tới khi người dùng cho áp.
- **Cảnh báo khi offline** chỉ dựa trên dữ liệu máy đang có (`00` mục 9).
- **Thông báo của 2b, 2c, 2d** chỉ tới khi máy đã kéo được dữ liệu, vì chưa có FCM (`00` mục 10).
- **Khối lượng:** nhiều phiên làm việc. Mỗi đợt kết thúc ở trạng thái chạy được; dừng giữa hai đợt không để nợ mở đường ghi.

## 15. Chỗ mã đợt 1A khác spec

Ghi 2026-11-01 sau đợt 1A (dải mã `2c18bf77..9cfca7bd`; nguồn: sổ đợt `Ruling:` và báo cáo review toàn nhánh). Cuối 1B (2026-11-02) các chỗ lệch ở mục 4, 6, 7.2, 7.3 hàng 2 và 8 của thân spec đã được **sửa chữ** theo bảng này (chỉ chữ, không đổi quyết định); phần còn lại của thân giữ nguyên. Khi lệch thì mục này, mục 16 và mã thắng.

| Mục spec | Spec viết | Mã làm | Lý do |
|---|---|---|---|
| 4 (sửa `sync.repository.js`) | khối sửa ghi `idfund_pair` với `!== undefined` | `idfund_pair: mapped.idfund_pair \|\| existing.idfund_pair` — server **không bao giờ gỡ** mã đã gắn | không có nhu cầu gỡ; máy có cột cục bộ `null` gửi `null` sẽ xoá mã |
| 4 (`sync.service.js`) | "Chủ nhà vẫn xoá được" | `laXoa = operation === 'delete'` (bỏ vế `payload.is_deleted`); `isNewTx = operation !== 'delete' && !existingRecord` | đo được chuỗi hai lượt đẩy gỡ mã rồi đổi tiền; nhánh "mới" từng bắt cả op `delete` (lỗi có từ trước). Client thật luôn xoá bằng op `delete` |
| 6 (bảng quyền) | `ghiDuLieu` tách theo vai | thêm tham số **`laChuyen`** vào `duocSuaKhoanNha` / `duocXoaKhoanNha`: khoản chuyển chỉ Chủ | server `sync.service.js` từ chối Member sửa / xoá `Transfer`; đường thật là Chủ cũ bị hạ xuống Member. 1B: `laChuyen` tính từ cả `existing.type` lẫn `type` mới |
| 7.2 (danh mục nhà) | nhắc dùng cửa chọn danh mục chung | trùng tên trong nhà đọc **`getCuaNha`**, **không** qua cửa quét 40 (`danh_sach_chon_danh_muc.dart`): cửa ấy tồn tại để ẩn theo khuôn, danh mục nhà không có luật đó. Draft nhà `keywords: []`, không `replaceKeywords`: **1A chưa sửa từ khoá danh mục nhà** (1B quyết hình dạng dữ liệu) | tránh dựng luật ẩn không có ở nhà; từ khoá nhà chưa đọc được trên máy thành viên |
| 7.3 hàng 1 (Rời nhà / Giải tán) | "đẩy một lượt trước, còn hàng chưa đẩy thì hỏi lại" | `SyncEngine.dayVaCho` (chờ cả lượt bù, trần 30 s) + `NhaRepositoryImpl` ném `LoiNha(hangChuaDay)` trừ khi gọi **`boQuaHangChuaDay: true`**; khi bỏ qua, `traVeKhiBoNha` trả tiền nửa nhà chưa đẩy về ví riêng TRƯỚC `xoaHangCuaNha`. Hộp hỏi lại thuộc **1B** (điều kiện chặn phát hành: phải nêu rõ hàng nào mất) | spec 7.3 đòi; mất hàng chưa đẩy khi rời là lỗi im lặng |
| 7.3 hàng 2 (kho nhà vắng / hỏng) | "không xoá hàng `pending` của nhà do mình ghi" | giữ `pending` ở **cả năm bảng**, không chỉ giao dịch + ví. Khi kho vắng **và còn dấu bền** "đã xử lý tới nhà H": `_doiChieuDauXuLy` KHÔNG phát `DoiNha(H → null)`, mà hỏi `/me` (người dùng chốt 2026-11-01 "hỏi server rồi mới quyết"): còn ở H ⇒ giữ và đẩy; đã bị mời ra ⇒ `DoiNha(H → null)`; offline ⇒ giữ, chờ. Phân biệt kho **vắng** (`doc` null) với kho **ghi "không nhà"** (giữ phát lại của G113 lỗ hổng 1). Sau purge `nhaGiu == null` ví nhà còn lại được **tính lại** (`SoDuViService`), vì cắt sổ sinh neo tiền ảo | tránh `DoiNha` oan xoá hàng chưa đẩy; số dư ví nhà lệch sau purge (đo: 550.000 thay vì 250.000) |
| 7.3 hàng 3 (mời ra / giải tán khi offline) | "lượt đẩy nhận mã vĩnh viễn ⇒ hàng lỗi được dọn" | thêm **`NhaDaDoc`**: sau mỗi `/me` đọc được, quét hàng có `idhousehold` khác nhà hiện tại ở năm bảng; với mỗi nhà X khác `traVeKhiBoNha(X)` rồi `xoaHangCuaNha(X)`, không dựa vào dấu hay `DoiNha`. Kiểm tài khoản phiên lúc chạy; `truocKhiDon` ném thì KHÔNG xoá nhà ấy và không ghi dấu (làm lại ở `/me` sau); `xuLy(DoiNha)` cũng chốt phiên | hàng kẹt khi kho vắng + dấu vắng + `/me` không nhà thì không có cặp `DoiNha` nào để dọn; tiền không được mất vì lỗi nhất thời |
| 8 (resolver) | "xoá mềm nửa riêng" | gỡ **cả hai nửa** khi nửa của nhà bị từ chối: xoá mềm + `markSynced` nửa nhà sau xoá mềm (khuôn Bill resolver), tính lại ví chung. Chỉ gỡ nửa do **phiên ghi**; Chủ xoá hộ bị từ chối chỉ `markSynced`. `HOUSEHOLD_ROLE_FORBIDDEN` trên hàng khác của nhà ⇒ xoá mềm + `markSynced` + một lượt `keoLaiToanBo` | khớp quyết định #6 (hàng của nhà bị bỏ). Hệ quả: lệch hai nửa ở ca sửa / xoá bị từ chối, đẩy mất phản hồi — **G119** |
| 8 (bộ gỡ khi Chủ xoá) | "nhà `Active` và mình còn ở ⇒ gỡ" | xét **mình còn ở đúng nhà của nửa riêng** (`coNha`, gồm `ReadOnly`) | Chủ xoá lúc `Active`, kéo về lúc nhà đã chỉ xem thì nửa riêng vẫn phải gỡ |
| 8 (thông báo) | nhóm `giaDinh`, chịu công tắc nhóm; chiều `notification → household` | hai loại **`luonBao = true`**; chiều thật **`household/application → notification/domain`** (cạnh từ `application/`, không vào quét 29) | tiền hoàn về ví lúc người dùng vắng, cùng lý lẽ `billPaidOnOtherDevice`; chữ spec về chiều là sai |
| 8 (số liệu cá nhân) | "`laGhiChuMay`, `xetGan` bỏ mọi hàng có mã cặp" | (ảnh chụp cuối 1A; **1B đảo `laGhiChuMay`**: nhận thêm tiền tố góp / rút, xem thân mục 8 và `02A` 7.2) `laGhiChuMay` **không đổi** (mẫu học đã đòi danh mục); `xetGan` bỏ hàng có mã cặp; thêm `khoaNhomCua` (khoản lặp) bỏ khoản có mã cặp | góp đều mỗi tháng sẽ hiện thẻ "Có vẻ là khoản lặp"; bấm Tạo ra hoá đơn cá nhân không có nửa nhà |
| 5 / đồng bộ | — | khối 1b gửi danh mục kèm theo bỏ qua giao dịch đang bị chặn theo thời gian; năm mã `HOUSEHOLD_*` thuần không tính chu kỳ hỏng, bậc chặn theo `syncRetryCount` của hàng; Pull giữ lệnh xoá chưa đẩy của giao dịch khi bản server còn sống | tránh vòng nóng G63; một khoản nhà bị từ chối không kéo cả đồng bộ cá nhân xuống 1 lần/giờ (đo: giãn cách tới 3.600 s) — `docs/superpowers/sync/SYNC_DOCUMENTATION.md` |

## 16. Chỗ mã đợt 1B khác spec

Ghi 2026-11-02 sau đợt 1B (28 commit `503fc9d5..9f4e5e97`, đếm `git rev-list --count` 2026-11-02; trong đó 1 commit backend `6684cc6c` và 1 commit chỉ sửa `CLAUDE.md`). Nguồn: sổ đợt (`Ruling:`), kế hoạch `docs/superpowers/plans/2026-11-01-gia-dinh-dot-1b-man-hinh.md` (gitignore), báo cáo soát toàn nhánh. **Trạng thái: mã xong + soát toàn nhánh (Opus: 0 Critical, 3 Important đã sửa ở đợt sửa cuối, soát lại đạt); CHƯA đo trên máy thật** (Task 13 thuộc phiên chính; đừng ghi "đạt trên máy" trước khi có bảng đo). Cột "sai thì sao" ghi hệ quả nếu quyết định này hoá ra sai.

### 16.1 Quyết định về Stitch (dự án `5106367939423432838`)

Mã màn: Nhà mình `d2a8c9bb`, Tạo ví `3bfb38b3`, Chi tiết ví `ac57e216` + `6d63311f`, Góp `f77f5bc0`, Form nhà `5a53df6e`, Hoạt động `50af4171`, Danh mục + Hộp xoá `6dc96c4a`; thêm 2026-11-01 (phiên 32): Sửa ví `be328002`, Rút `c39ac4f7`, Chi tiết khoản `a8d53198`, Hàng chưa đồng bộ `1e99ebfa` (người dùng chốt "Dùng luôn, xem sau": có thể đổi sau khi nhìn máy).

| Chi tiết Stitch | Xử lý | Lý do |
|---|---|---|
| Chấm xanh cạnh tên nhà, nút ba chấm `more_vert` Nhà mình | Bỏ | Không có nghĩa, nút chết (quét 10) |
| Phím `.` | Bỏ | Bàn phím thật đã bỏ (A12: số lẻ đọc sai) |
| Phím `+` `−`, thứ tự 7-8-9 ở trên | Theo `BanPhimSo` thật | Spec mục 10 |
| ✓ thanh tiêu đề + ✓ bàn phím | Theo luật G58: ✓ tiêu đề chỉ khi 16 phím không trên màn | Đã có ở form cá nhân |
| "VNĐ - VIỆT NAM ĐỒNG" | Giữ | `KhoiSoTien` in dòng này khi không có phép toán; nhất quán với form (bảng Stitch ghi sai là không có) |
| Chip *Thu nhập* ở form nhà | Giữ | `02A` mục 3 có *Thu khác* |
| Chip *Chuyển khoản* | Chỉ Chủ nhà | Mục 6 |
| Hai nút "Lưu" + "Tạo ví chung" | Giữ cả hai | `WalletAddPage` cá nhân cũng có cặp này |
| Số dư ban đầu dạng chữ ở Tạo ví | Dùng `OSoDuVi` thật | Stitch không vẽ bàn phím, ô phải nhập được |
| Huy hiệu "Đã góp" ở Bảng góp | Bỏ, chỉ giữ "Đã rời" | Không có điều kiện ở 2a; đủ / thiếu thuộc `02C` |
| "Cập nhật tháng này" | Bỏ | Bảng có cả cột từ trước tới nay, câu sai |
| "Chế độ gia đình · Đồng bộ thời gian thực", thanh Home, thanh trạng thái giả | Bỏ | Không thuộc app; không có đồng bộ thời gian thực |
| "Chỉ các thành viên trong nhà mới có thể xem hoạt động" | Giữ | Câu đúng |
| Hai tab Chi / Thu ở Danh mục của nhà | Ba tab `kCategoryClassifies` | Server sao cả danh mục vay / nợ vào nhà; hai tab là không sửa được chúng |
| Dòng phụ "Từ ví riêng" / "Về ví riêng" ở Chi tiết ví | Hiện theo màn 3, hoặc ghi chú nếu có; khoản góp không ghi chú đổi thành "Góp vào quỹ" (trung tính) | Máy người khác không có nửa riêng nên không biết tên ví; tiền mặt trao tay không có ví riêng |
| Nhà mình (người dùng chốt 2026-11-01 "Giữ màn đã đo") | Giữ bố cục lát 2, chèn khối Ví chung + hai lối vào giữa thẻ lời mời và THÀNH VIÊN | Màn đã đo trên máy |
| Màu chênh rất nhỏ so với token (`#767873` ~ `#767872`, `#1a1a19` ~ `#1A1C1A`, `#e8e7e1` ~ outlineVariant, `#f2f1ec` ~ surfaceContainerLow) | Coi là trùng token | Mắt không phân biệt; nhất quán với cả app. Khác hẳn (`#868882`, `#9a9c95` người đã rời, đỏ hộp 8B) thì theo hex Stitch |

### 16.2 Không mở ở 1B (quyết định #4 chỉ thêm, sửa)

- **Không mở xoá danh mục của nhà** (G120 dòng 16 phần xoá còn mở): màn *Danh mục của nhà* chỉ xem, thêm, sửa. Sai thì chỉ thiếu tính năng.
- **Danh mục của nhà không có từ khoá** (M-17): form nhà không nhập từ khoá, draft `keywords: []`, không `replaceKeywords`. Sai thì chỉ thiếu tính năng từ khoá nhà.
- **Ba tab** `kCategoryClassifies` thay vì hai (bảng 16.1). Sai thì thừa một tab.
- **Form danh mục nhà dùng lại `CategoryAddPage` thêm `idNha`** (có sẵn thiết kế), không dựng màn mới. Sai thì trang thêm vài nhánh.
- **Backend chặn danh mục sai phạm vi** (mục 4): nằm trong phép đích danh "sửa backend trong worktree". Client 1B không tạo được ca này; sai thì thừa một luật.
- Vế "xét lại `tinhLaiViNha` khi có đường tạo ví chung" **đã kiểm, không cần việc**: purge giữ ví `pending` của người ghi, `tinhLaiViNha` đọc `getTatCaViNha` nên ví chung mới tạo được tính lại.

### 16.3 Ruling của sổ đợt 1B

| Ruling | Mã làm | Khác spec / `02A` | Sai thì sao |
|---|---|---|---|
| Thu nhập rút + nhãn ảo làm cùng đợt (Task 10) | `thuNhapCua` loại nửa rút; nhãn ảo *"Góp quỹ gia đình"* / *"Rút quỹ gia đình"* ở các khối gom | `02A` 7.2 chưa ra mã | Dài kế hoạch, không đổi hành vi |
| I-1: `nhanAoQuy(id)` trả record là định nghĩa duy nhất của nhãn ảo (`transaction/domain/danh_muc_ao_quy.dart`) | Mã ảo không vào danh sách `Category` Drift; `dungKhoan` giữ chữ ký | Spec 8 nói "mã ảo" mơ hồ | Một chỗ tra tên sót hiện "Danh mục đã xoá" |
| I-7: `KhoanThuChi.laRutQuy`, `DiemVayNo.rutQuy`; `chuoiVayNo` cộng theo cờ rồi `continue`; mã ảo chỉ để gom nhãn | Thu nhập quyết bằng **cờ**, không bằng mã ảo; `continue` bắt buộc (nửa rút gắn danh mục vay nợ mà không `continue` sẽ trừ thu nhập hai lần) | `02A` 7.2 không có ngoại lệ danh mục | Một chỗ dựng `KhoanThuChi` thiếu cờ sẽ tính rút là thu nhập; có ca canh `tai_phan_bo_nguon` |
| Chi bất thường giữ nửa góp dưới nhãn *"Góp quỹ gia đình"* (Task 10) | `analytics_repository_impl` | Trước đây `categoryId` null bị bỏ qua | Nhận xét có thể nhắc một khoản góp chủ ý là "bất thường"; đổi sau được |
| I-2: `CategoryEntity` thêm `idhousehold` (`fromDrift`, `props`) | Để `getById` chốt nhà | — | Thêm một trường |
| I-3: `hangChuaDay(idNha, {required int? idaccount})`: chỉ nửa của tôi vào *gop* / *rut*, nửa người khác vào *khoan*; nửa của tôi đã xoá mềm vào *khoan* | Hộp rời nhà nói đúng tiền nào được trả | Spec 7.3 chưa phân loại | Hộp đếm sai loại, không mất tiền |
| I-4: hàm thuần `huongFormNha` chặn `huong=transfer` khi không `choChuyen` | `che_do_nha_form.dart` | — | Khoản chuyển của Thành viên bị server từ chối rồi biến mất im lặng |
| I-5: vuốt xoá nửa riêng: `confirmDismiss` luôn `return false`, tự `baoNhanh` | Trả `true` là gỡ một nửa, lệch cặp | — | Hàng biến mất chậm một nhịp stream |
| M-4: giữ dòng "VNĐ - VIỆT NAM ĐỒNG" | Bảng 16.1 | — | Thừa một dòng chữ |
| M-6: bộ vẽ icon ví chung là `categoryIconFor`, thêm `account_balance`, `bank`, `shopping_basket`, `wallet` | `kIconViChung` dùng `account_balance` | — | Icon rơi về mặc định |
| M-8: `theoDoiBangTraDanhMuc(idaccount)` bọc `watchBangTraTen`, không thêm DAO | Quy tắc 8: một định nghĩa bảng tra | — | Bảng tra thừa hàng riêng, vô hại |
| M-10: nhánh đếm lại rỗng mà vẫn vướng thì tự `baoNhanh`; `dayVaCho` chạy hai lần chấp nhận | Hộp rời nhà | — | Chờ thêm tối đa 30 s |
| M-11: route `/nha/vi/:id` thuộc Task 7; nút trỏ route chưa có không bao giờ hiện giữa các task | — | — | Thiếu lối tạm |
| M-16: chấp nhận redirect `/nha` chồng thêm một `NhaMinhPage` | — | — | Phải Back thêm một lần |
| T3: form `/nha/khoan` đọc `final nha = t.nha`, `null` thì trả `NhaMinhPage` | Lệch nguyên văn kế hoạch (`t.nha!`) | — | Nhà có thể về `null` lúc form đang mở (giải tán, bị mời ra): người dùng mất chữ đang gõ, khoản đó vốn không lưu được nữa |
| T5: ô đổi số dư ví chung áp `MaQuyen.walletBalanceAdjustment` như ví riêng (ô chỉ đọc + `DongKhoaQuyen`); `_luu` / `_xoa` kiểm lại vai và id nhà đầu hàm; ô số dư trống ở Sửa = không đổi; khoá khi ví đang lưu trữ | `02A` mục 2 "như ví riêng" | Server không có chốt trên đường đẩy | Chủ nhà Basic không đối soát được ví chung (một dòng đổi) |
| T6/T7: hộp xoá khoản cặp không hứa trả tiền cho người đã rời; câu "Chủ xoá hộ" có điều kiện (*"Nếu góp từ ví riêng, tiền được trả về đó."*) vì máy Chủ không phân biệt tiền mặt trao tay | `02A` 107 + mục 6 | Chữ về tiền phải đúng | Câu dài hơn |
| T7: nối `SheetKhoanNha` vào dòng giao dịch ở Chi tiết ví (chạm mở sheet, sửa / xoá như Hoạt động); người ngoài danh sách không gắn "đã rời"; chi tiết chỉ thoát khi route đang trên cùng (`ModalRoute.isCurrent`) | Kế hoạch ghi *Consumes* mà không task nào nhận | — | Thừa một lối vào |
| T8: cubit gop / rut nhận cặp phải so người ghi (nửa của người khác ⇒ `cauDong`, không sửa) | Spec mục 6 "sửa khoản có mã cặp chỉ của mình" | — | Trang đóng, không mất dữ liệu |
| T9: sửa, xoá nửa riêng từ Sổ giao dịch và Chi tiết ngân sách đi theo **cả cặp** (`CapGopQuyNguon`, `doc_cap_gop_quy.dart`); Bill không đổi (nửa riêng không bao giờ có `billId`) | `02A` 7.2 "mở nửa riêng thì vào form góp" | Thêm `laGhiChuMay` nhận tiền tố góp / rút | Dây DI mất thì âm thầm về đường cũ (có ca đọc mã) |
| FINAL I-1: sửa nửa riêng đã rời ở form thường: trang khoá chiều (`khoaChieu`), cubit thêm đúng hai chốt (chiều không đổi; danh mục không bắt buộc) | Lệch luật "không thêm logic vào `ThemGiaoDichCubit`" (mục 9); cubit 1.140 dòng, trần 1.200 | — | Không chặn thì hàng kẹt `pending` vĩnh viễn, im lặng, số dư đã đổi |
| FINAL I-2: khử trùng thành viên cũ **một chỗ** khi đọc `/me` ở client (`nhaCuaToiTuJson` bỏ id đang ở và khử trùng theo id), không sửa backend lượt này | Đơn backend **64** (`CAN-LAM/VIEC_BACKEND_CON_LAI.md`) | `addMember` tạo hàng mới, không khoá duy nhất theo (nhà, tài khoản) | Backend vẫn trả trùng nhưng client đã chịu được |
| FINAL I-3: helper `conDuocLamViecNha(repo, idNha, viec)` (`household/application/quyen_hien_tai.dart`) cho cả bốn form ghi; `transaction` / `category` nhận closure từ router, không import `household` | Kiểm lại quyền lúc Lưu một định nghĩa | — | Thừa một tham số |
| FINAL mục 9 (sheet 13 chữ số): ca ×1,6 chưa đỏ khi bỏ hẳn `FittedBox` (chỉ đỏ với `BoxFit.none`) | Park, không mở đợt sửa thứ hai | — | Sau này bỏ `FittedBox` mà không ca nào đỏ; đo bằng mắt ở Task 13 |
| Phân loại minor sau soát toàn nhánh | Sửa trước đo máy: `choNapKho` ở DI đọc cặp, `tenVi` lỗi rơi về câu chung, chữ tiền rút không nửa riêng, `moTa` ném thì báo, `conDuocGhi`, nạp lại bộ chọn danh mục; đóng sổ: context sau await, `detail_sheet`, `_goSo` | — | Một mục để sau lộ khi đo, sửa khi ấy |

### 16.4 Chỗ hay hỏng im lặng của 1B (đọc trước khi sửa)

- Route mới (`app_router.dart`): `/nha/vi/tao`, `/nha/vi/:id/sua`, `/nha/vi/:id`, `/nha/hoat-dong`, `/nha/khoan` (+ `/nha/khoan/category`), `/nha/danh-muc`, `/nha/danh-muc/them`, `/nha/danh-muc/:id/sua`, `/nha/gop`. Cửa quyền route chỉ kiểm bằng đọc chuỗi, chưa có ca `GoRouter` thật cho Viewer và nhà `null` (G121). `/nha/khoan` không xét `duocSuaKhoanNha`: cửa gọi phải chặn.
- Chế độ nhà của form: `CheDoNhaForm` ở `transaction/presentation/state/che_do_nha_form.dart` (không import `household`); nguồn dữ liệu `household/data/them_giao_dich_nguon_nha.dart`.
- Nhãn ảo chỉ ở **tầng gom thống kê**; đừng đưa vào bảng chọn danh mục hay đồng bộ.

## 17. Chỗ mã đợt 2 (mục tiêu chung) khác spec và `03`

Ghi 2026-11-02 sau đợt 2. Kế hoạch `docs/superpowers/plans/2026-11-02-gia-dinh-dot-2-muc-tieu-chung.md` (gitignore), bản chép + sổ đợt `Temp/flowmoney-phien34-so-dot-2/`. Khi lệch thì mục này và mã thắng `03`. Bảng đo ở khối 🏠 đợt 2 mục 14 `PROJECT_CONTEXT.md`.

### 17.1 Quyết định

| # | `03` / spec viết | Mã làm | Lý do | Sai thì sao |
|---|---|---|---|---|
| Q1 | Tắt = xoá mềm, bật lại = hàng mới | Bật lại mà hàng cùng ví **đã xoá mềm + còn `pending`** thì **hồi sinh chính hàng ấy** (giữ id, đặt lại số tiền, hạn, `startDate`, cột chặn đồng bộ). Lệnh xoá đã lên server thì mới là hàng mới | Server chạy lệnh tạo (trọng số 30) trước lệnh xoá (70) trong một lô: hàng mới vướng `uq_goal_household_wallet_active`. Có ca kịch bản ghi nhận hành vi này | Đổi ý trước khi đồng bộ thì mốc đã báo không báo lại |
| Q2 | Hai máy Chủ cùng bật offline ⇒ `UNIQUE_VIOLATION`, client xếp vĩnh viễn | Resolver gỡ hàng thua (xoá mềm + `markSynced`) rồi kéo toàn bộ. Hai hàng cùng sống trên máy thì hiện hàng `updatedAt` mới nhất; `BoMucTieu` xoá mềm mọi hàng sống | Mã vĩnh viễn để hàng kẹt `pending` mãi. Chưa đo trên máy (cần hai máy Chủ), chỉ có test + hai SQLite qua Pull thật | Giá trị gõ trên máy thua bị thay bằng máy thắng không câu báo, và chu kỳ ấy phát *"Đồng bộ chưa thành công"* |
| Q3 | G120 dòng 5: mục tiêu của nhà bị `ROLE_FORBIDDEN` ở lại `pending` | Gỡ cùng khuôn `_traBanServerVi` | Đường ghi mục tiêu mở ở đợt này nên nợ tới được | Bản sửa offline của người vừa bị hạ vai mất, đúng thiết kế |
| Q4 | G121 dòng 12 chưa quyết | `xoaViChung` **từ chối** khi còn mục tiêu sống, câu chỉ lối tắt rồi Lưu | Cùng khuôn ví riêng; không tự xoá thứ người dùng vừa đặt | Thừa một thao tác |
| Q5 | Một tiền tố `nhaMucTieu:<id>:<25\|50\|75\|100>` | `nhaMucTieu:<id>:<25\|50\|75>`, **`nhaMucTieuDat:<id>`**, dấu đã thấy `nhaMucTieu:<id>:0` | `loaiTuKhoa` ánh xạ tiền tố → loại | Chỉ là tên khoá |
| Q6 | Lần đầu thấy: ghi nhận im lặng | Ứng viên `imLang`: hàng ghi sẵn `dismissedAt` + `readAt`, không bắn hệ điều hành. Đã thấy = có hàng `…:0`. **Khoá sống cả đời mục tiêu:** `purgeOlderThan(giuLoai:)` không xoá hai loại này, tới 90 ngày chỉ đặt `dismissedAt`. **Nguồn trả rỗng khi `SyncEngine` đang `syncing`**, vì ví vừa về có số dư 0 là chưa biết | Không thêm bảng; soát Task 5 chỉ ra dọn 90 ngày làm *"đã đạt"* báo lại, và quét chen giữa lượt kéo làm người mới vào nhận mốc cũ | Thừa tối đa 5 hàng ẩn mỗi mục tiêu; trễ một lượt quét |
| Q7 | Mỗi mốc một lần | Một khoản vượt nhiều mốc: chỉ báo mốc cao nhất, các mốc thấp hơn ghi im cùng lượt | Thiếu vế này thì 60 % tụt về 30 % lại báo 25 % | Không thấy tin của mốc thấp |
| Q8 | Không nói | Cả hai loại deeplink `/nha` | Khoá không chứa id ví | Vào Nhà mình, không vào thẳng ví |
| Q9 | Thiếu / số tháng, làm tròn lên | `n` = số nguyên ≥ 1 nhỏ nhất sao cho `mocThuN(hôm nay, 'Month', n)` không trước hạn; `ceil(thiếu / n)`. Không dùng `tocDoKeHoach` (quy 30 ngày, hạn 15 ngày thành gấp đôi số thiếu) | Lịch thật cho tháng ngắn, năm nhuận | Số gợi ý lệch một kỳ |
| Q10 | Thẻ ví đủ các dòng ở cả hai chỗ | Dòng ví: thanh + `a / b đ` + `%` hoặc nhãn; đủ *Còn thiếu · Còn lại · Cần góp* ở Chi tiết ví | Stitch `7b5f0f89…`; dòng ví 360 dp không đủ chỗ | Phải mở Chi tiết mới thấy số cần góp |
| Thêm | Tiến độ 100 % khi làm tròn | Chưa đạt thì chữ % không lên 100: `chuPhanTramMucTieu` kẹp .99 | 99,6 % mà hiện 100 % trong khi còn thiếu là nói sai | Lệch 1 % chữ |
| Thêm | `03` mục 4: *"bật lại là id mới ⇒ báo lại từ đầu"* | Bật lại là lần đầu thấy: mốc đã vượt im, chỉ mốc vượt sau đó mới báo | Ví đã 60 % mà ba tin cùng lúc là ồn, cùng lý lẽ Q6 | Đổi một vế ở bộ luật |
| Thêm | Không nói | Ví lưu trữ vẫn có thanh nhưng không có *Cần góp* (không có nút Góp); mục tiêu của ví lưu trữ vẫn vào bộ quét vì số dư đóng băng | Câu mời góp vào ví đóng băng là vô nghĩa | Thừa vài hàng im |
| Thêm | Không nói | Lượt kéo không ghi đè hàng mục tiêu **của nhà** đang `pending` (`GoalDao.upsertKeoVe`, khuôn `TransactionDao.upsertKeoVe`); mục tiêu riêng không đổi | Soát toàn nhánh: Chủ bấm *Bỏ mục tiêu* đúng lúc lượt kéo đang bay thì mục tiêu sống lại | Khe còn lại ghi ở G122 |

### 17.2 Chấp nhận, người dùng nên biết

- Người bật mục tiêu trên ví đã có tiền không nhận mốc cho phần đã có.
- Bật lại nhóm *Gia đình* sau khi tắt: máy đã từng thấy mục tiêu nhận **một** thông báo mốc cao nhất vượt lúc tắt (đo: *"đã đạt"*). Máy chưa từng thấy thì im.
- Rời rồi vào lại cùng nhà: dấu `:0` còn, mốc vượt lúc vắng báo một lần.
- Thông báo của mục tiêu đã tắt ở lại trung tâm (giữ lịch sử).
- Hàng `goal` `pending` đếm vào *"N mục khác"* ở hộp Rời nhà / Giải tán.
- Tần suất các khe đồng bộ còn lại: xem G122.

### 17.3 Stitch (dự án `5106367939423432838`)

Form `74ebe178c5d046fea3679e5b11ccfe8d`, thẻ tiến độ `7b5f0f895f9a4a9092d81d5095a11552`, người dùng chốt *"Dùng luôn, xem sau"*. Bỏ khung so sánh (tiêu đề hai khối, huy hiệu *360dp*, chân trang), viền cam và nhãn *Quá hạn* cạnh *SỐ DƯ*: số dư không quá hạn, mục tiêu mới quá hạn. Dòng ví quá hạn (Stitch không vẽ) dùng viên thuốc cùng khuôn *Đã đạt mục tiêu*. Thanh thụt 48 theo ô tròn thật 36 + khe 12. Khối mục tiêu ở màn Tạo dùng cùng thẻ, chèn giữa thẻ chính và chú thích.
