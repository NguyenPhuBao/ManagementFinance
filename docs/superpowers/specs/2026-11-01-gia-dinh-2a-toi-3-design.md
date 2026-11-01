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
- Ghi ở **cả hai** khối `data`: tạo (dòng 472) và sửa (dòng 511, `!== undefined`). Thiếu là bị bỏ qua im lặng.
- `/sync/pull` trả khoá `idfund_pair` (chuỗi hoặc `null`).

**`modules/sync/sync.service.js`:**
- `Transfer` mang `idfund_pair` ⇒ `HOUSEHOLD_SCOPE_MISMATCH`.
- Hàng của nhà có `Idfund_pair`: **sửa** chỉ người ghi (`existing.Idaccount`), khác ⇒ `HOUSEHOLD_ROLE_FORBIDDEN`. Chủ nhà vẫn **xoá** được. Bảng `01` mục 3.
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
| Xem ví, hoạt động, bảng góp, báo cáo | ✓ | ✓ | ✓ |

Chủ nhà hết Premium ⇒ nhà `ReadOnly` ⇒ mọi người như cột cuối.

Nút không được phép thì **không hiện** (không nút chết, quét 10). Server vẫn thi hành lại mọi luật; mã từ chối đã nằm trong `_permanentCodes`.

## 7. Ba lỗi đồng bộ phải sửa TRƯỚC khi mở đường ghi

Viết ca đỏ trước cho từng lỗi. Cả ba đều hỏng im lặng.

**7.1 Hàng sửa hộ không bao giờ lên server.** `transactionDao`, `walletDao`, `goalDao`, `budgetDao`.`getPending(idaccount)` và `categoryDao.getSyncableCategories` lọc `idaccount = tôi`, trong khi `idaccount` của hàng nhà là **người ghi**. Chủ nhà sửa khoản của Thành viên, Chủ mới sửa ví của Chủ cũ, Thành viên sửa danh mục người khác tạo: hàng nằm `pending` mãi. Đổi thành `idaccount = tôi ∨ idhousehold = nhà đang ở`, truyền nhà từ `NhaRepository` vào `ThuGomThaoTacDay`. Khối 1b thêm ca khoá `idhousehold` (G113 nợ 4). Backend giữ `Idaccount` người ghi đã đo (57.4).

**7.2 Sửa danh mục của nhà làm mất `idhousehold`.** Đường sửa đi `categoryDao.insert` (= `insertOrReplace`), companion từ draft không có trường này (G113 nợ 3). Phải mang trường theo; đường đọc danh mục cá nhân đang lọc `idhousehold IS NULL` giữ nguyên. Từ khoá, kiểm trùng tên, bộ chọn danh mục của nhà đọc theo nhà; danh sách chọn vẫn qua cửa quét 40.

**7.3 Dọn nhà xoá hàng chưa đẩy.** `purgeDataForOtherAccounts` (khi `nhaGiu` null) và `xoaHangCuaNha` xoá cả `pending` (G113 nợ 2):

| Tình huống | Xử lý |
|---|---|
| Người dùng bấm *Rời nhà* / *Giải tán* | Đẩy một lượt trước khi gọi API; còn hàng chưa đẩy được thì hỏi lại |
| Mở app, kho trạng thái nhà vắng hoặc đọc hỏng | Không xoá hàng `pending` của nhà do mình ghi, cùng ví chúng trỏ tới (khoá ngoại). Giữ tới khi đẩy được hoặc server từ chối rõ |
| Bị mời ra / nhà giải tán khi offline | Lượt đẩy nhận mã vĩnh viễn ⇒ hàng lỗi được dọn; khoản góp qua mục 8 |
| Đăng nhập tài khoản khác | Như cũ: mọi dữ liệu tài khoản cũ bị dọn |

⚠️ Giữ nguyên chốt ở `purgeDataForOtherAccounts`: lỗi xoá khoá ngoại ở đây khoá người dùng ở màn Đăng nhập (G113 lỗ hổng 3). Có ca canh.

## 8. Góp và rút

Theo `02A` mục 5–6.

- **`GopQuyService`** (`household/application/`): tạo / sửa / xoá **hai nửa trong một giao tác Drift**, khuôn `addTransactions` (neo số dư trước khi ghi). *Tiền mặt trao tay* chỉ có nửa của nhà, vẫn mang `fundPairId`. Mã cặp là UUID v4.
- **`GopQuyConflictResolver`:** nghe `pushResultStream`, khuôn `BillPaymentConflictResolver`, đăng ký và bắt đầu nghe cùng chỗ với nó (quét 5 có khuôn). Mã từ chối nửa của nhà ⇒ xoá mềm nửa riêng + thông báo `gopQuyBiTraVe`. Chịu **hai** lượt phát cho cùng một thất bại; khoá `gopTraVe:<cặp>` chống trùng.
- **Bộ gỡ khi Chủ nhà xoá:** kéo về thấy nửa của nhà mang cờ xoá mà nửa riêng còn sống ⇒ đọc `/me`. Nhà `Active` và mình còn ở ⇒ gỡ + `gopQuyBiXoa`. Nhà giải tán hoặc mình đã rời ⇒ giữ. Offline ⇒ hoãn lượt sau.
- **Rời nhà:** nửa riêng ở lại thành khoản riêng thường.
- **Thông báo:** `NotificationKind` thêm hai loại nhóm `giaDinh`, sửa hai `switch` không `default` và `tatCaUngVien()`. Chiều phụ thuộc `notification → household`, không tạo vòng (quét 29).

**Số liệu cá nhân** (`02A` mục 7.2): nửa riêng tính chi / thu qua `khoanVaoThongKe`; các khối gom theo danh mục dùng nhãn ảo *"Góp quỹ gia đình"* / *"Rút quỹ gia đình"*; `thuNhapCua` không gồm nửa rút; `laGhiChuMay`, `xetGan` bỏ mọi hàng có mã cặp; ngân sách theo danh mục không tính. Mở nửa riêng từ Sổ giao dịch thì vào form góp, không form thường.

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
