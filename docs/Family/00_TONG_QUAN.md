# Gia đình (nhà nhiều người) — 00. Tổng quan

> **Ngày:** 2026-10-26 · **Trạng thái:** thiết kế đã được người dùng (PO) duyệt từng phần qua brainstorming; **chưa có mã**
> ở client lẫn backend · **Người đọc:** backend, Admin-web, PO, client — để **xem và thảo luận** trước khi đặt đơn CAN-LAM.
> **Phía client viết** (nhánh `TranQuangDat`). Mỗi tệp có mục *Câu hỏi để thảo luận* và mục *Trả lời / thảo luận* ở cuối —
> backend ghi thẳng vào đó (hoặc trả lời trong đơn CAN-LAM khi có).
>
> **Bộ tài liệu:**
>
> | Tệp | Phần | Nội dung |
> |---|---|---|
> | `00_TONG_QUAN.md` (tệp này) | — | Mục tiêu, quyết định đã chốt, vai, lộ trình, nguyên tắc xuyên suốt, thay đổi so với đơn 50, tổng hợp việc backend |
> | `01_NEN_MONG.md` | 1 | Nhà · thành viên · ba vai · mã mời — **thêm mời bằng email** — và luật quyền mới khi đẩy |
> | `02A_VI_CHUNG_GOP_QUY.md` | 2a | Nhiều ví chung, chi từ ví chung, góp / rút quỹ (cặp hai khoản), bảng ai góp bao nhiêu, dòng hoạt động |
> | `02B_HAN_MUC_CHI.md` | 2b | Hạn mức chi của từng thành viên trong từng ví (kỳ ngày / tuần / tháng, theo danh mục, cảnh báo 80%, vượt mức báo chủ nhà) |
> | `02C_DINH_MUC_GOP.md` | 2c | Định mức góp hằng tháng, nhắc góp, tự góp định kỳ |
> | `02D_NGAN_SACH_BAO_CAO.md` | 2d | Ngân sách chung của nhà, báo cáo tháng, báo khi có người chi / góp |
> | `03_MUC_TIEU_CHUNG.md` | 3 | Mục tiêu chung = công tắc *"Đặt mục tiêu"* trên ví chung |
>
> **Nền của bộ này:** spec `docs/superpowers/specs/2026-10-23-gia-dinh-nen-mong-design.md` (phần 1, mục 11 = chỗ kế hoạch
> thi công lát 1 khác thân) và đơn **50** `docs/superpowers/backend/CAN-LAM/GIA_DINH_NEN_MONG.md` (bản chép ở
> `docs/Family/GIA_DINH_NEN_MONG.md`). **Bộ tài liệu này thắng hai tệp ấy khi lệch** — chỗ lệch liệt kê ở mục 6.

---

## 1. Gia đình trong FlowMoney là gì

Một gia đình (tối đa 6 người) lập **nhà** trên FlowMoney. Chủ nhà mở các **ví chung** (*Tiền chợ*, *Điện nước*, *Quỹ du lịch*…),
mời người nhà vào bằng **email** hoặc **mã mời**. Mỗi người **góp tiền** từ ví riêng của mình vào ví chung; cả nhà cùng **chi**
từ ví chung. Chủ nhà đặt **hạn mức chi** cho từng thành viên (ví dụ con được chi 50.000 đ / ngày ở ví *Tiền ăn sáng*) và **định
mức góp** hằng tháng (mỗi người góp 3 triệu vào *Tiền chợ*); app nhắc người chưa góp đủ, cảnh báo người sắp hết hạn mức, báo chủ
nhà khi có người vượt. Nhà có **ngân sách chung**, **báo cáo tháng**, **dòng hoạt động**, và ví chung có thể **đặt mục tiêu**
(*Quỹ du lịch: 20 triệu trước tháng 12*).

⚠️ **FlowMoney chỉ ghi sổ, không giữ tiền thật.** "Góp", "chi", "rút" là ghi chép; "chặn" chỉ chặn được việc ghi vào sổ chứ không
chặn được việc tiêu tiền. Vì vậy hạn mức **cảnh báo** chứ không chặn (mục 2, quyết định 2026-10-26).

## 2. Quyết định đã chốt

Người dùng chốt qua câu hỏi chọn được — đợt 1 ngày **2026-10-23** (spec nền móng), đợt 2 ngày **2026-10-26** (bộ tài liệu này).

| # | Câu hỏi | Chốt | Ngày |
|---|---|---|---|
| 1 | Quy mô | Gia đình nhiều người, tối đa 6 (trần server ghi đè được) | 10-23 |
| 2 | Vai trò | Ba vai cố định áp cho cả nhà: **Chủ nhà · Thành viên · Chỉ xem** | 10-23 |
| 3 | Gói | **Chủ nhà cần Premium**; người được mời dùng miễn phí; chủ hết Premium → nhà *chỉ xem*, không mất dữ liệu | 10-23 |
| 4 | Mô hình dữ liệu | **"Nhà" là chủ sở hữu thứ ba** — cột `Idhousehold` trên ví, giao dịch, mục tiêu, ngân sách, danh mục | 10-23 |
| 5 | Dữ liệu nhà hiện ở đâu | **Chỉ trong khu *Nhà mình*** — Trang chủ, Sổ, Phân tích, Ngân sách cá nhân không lẫn tiền của nhà (ngoại lệ có chủ đích: nửa riêng của khoản góp / rút — #14) | 10-23 |
| 6 | Danh mục | Nhà có **bộ danh mục riêng** (server sao bộ mặc định khi lập nhà) | 10-23 |
| 7 | Giải tán | Dữ liệu chung biến mất với mọi người (xoá mềm ở server) | 10-23 |
| 8 | Lộ trình | **Bỏ "ai nợ ai"** (chi tự trả rồi chia); **giữ mục tiêu chung**; **bỏ "cho nhà xem" ví riêng** | 10-26 |
| 9 | Ai đặt hạn mức / cấu hình | **Chỉ Chủ nhà** (nguyên tắc ở mục 3) | 10-26 |
| 10 | Vượt hạn mức | **Cảnh báo + báo Chủ nhà**, vẫn ghi được (không chặn cứng, không xin duyệt) | 10-26 |
| 11 | Mời đích danh | **Email: lời mời trong app + thư kèm mã** (cùng một câu trả lời dù email có tài khoản hay không; mã trong thư gắn với email đó) | 10-26 |
| 12 | Cách lưu một khoản góp / rút | **Cặp hai khoản nối nhau** (nửa riêng ở ví riêng + nửa của nhà ở ví chung, chung một mã cặp) | 10-26 |
| 13 | Hạn mức, định mức góp lưu ở đâu | **Trên server, đi kèm trạng thái nhà** (sửa cần mạng; xem + cảnh báo chạy offline) | 10-26 |
| 14 | Nửa riêng của góp / rút trong số liệu cá nhân | **Tính là chi "Góp quỹ gia đình"** (rút = thu "Rút quỹ gia đình") | 10-26 |
| 15 | Ai sửa / xoá một khoản của nhà | **Người ghi + Chủ nhà** | 10-26 |
| 16 | Ai thấy hạn mức | **Chủ nhà thấy của mọi người; Thành viên chỉ thấy của mình** (server chỉ trả phần được thấy) | 10-26 |
| 17 | Mục tiêu chung | **Công tắc "Đặt mục tiêu" trên ví chung**, bật / tắt tuỳ nhu cầu; tiến độ = số dư ví | 10-26 |
| 18 | Thêm (chọn từ danh sách mở rộng) | Bảng ai góp bao nhiêu · định mức góp hằng tháng · tự góp định kỳ · rút quỹ · cảnh báo 80% · kỳ ngày / tuần / tháng · hạn mức theo danh mục · ngân sách chung · dòng hoạt động · báo khi có người chi / góp · báo cáo tháng | 10-26 |

## 3. Vai và quyền

**Nguyên tắc: Chủ nhà cấu hình · Thành viên giao dịch · Chỉ xem thì xem.**

| Việc | Chủ nhà | Thành viên | Chỉ xem | Phần |
|---|:-:|:-:|:-:|---|
| Tạo nhà (cần Premium) | ✓ | | | 1 |
| Mời (email / mã), đổi vai, mời ra, chuyển chủ, giải tán | ✓ | | | 1 |
| Tạo / sửa / lưu trữ ví chung, bật / tắt mục tiêu trên ví | ✓ | | | 2a, 3 |
| Thêm / sửa danh mục của nhà | ✓ | ✓ | | 1 (giữ spec 2026-10-23 — câu hỏi mở Q3) |
| Đặt hạn mức chi, định mức góp, ngân sách chung | ✓ | | | 2b, 2c, 2d |
| Chi / thu khác vào ví chung | ✓ (không hạn mức) | ✓ (theo hạn mức) | | 2a |
| Chuyển giữa hai ví chung | ✓ | | | 2a |
| Góp, rút, tự góp | ✓ | ✓ (rút tính vào hạn mức) | | 2a, 2c |
| Sửa / xoá một khoản của nhà | mọi khoản (khoản góp / rút của người khác: chỉ **xoá**) | khoản do mình ghi | | 2a |
| Xem ví chung, dòng hoạt động, báo cáo, bảng góp | ✓ | ✓ | ✓ | 2a, 2d |
| Xem hạn mức / định mức | của mọi người | của mình | | 2b, 2c |
| Rời nhà | chuyển chủ trước | ✓ | ✓ | 1 |

## 4. Lộ trình

| Phần | Tệp | Cần trước | Ghi chú |
|---|---|---|---|
| **1** Nền móng | `01_NEN_MONG.md` | — | Đã có spec + đơn 50 + kế hoạch thi công lát 1 (chưa mã); bộ này thêm mời email + luật quyền |
| **2a** Ví chung + góp / rút | `02A_VI_CHUNG_GOP_QUY.md` | 1 | Lõi của tính năng; mọi phần sau dựa vào |
| **2b** Hạn mức chi | `02B_HAN_MUC_CHI.md` | 2a | |
| **2c** Định mức góp + tự góp | `02C_DINH_MUC_GOP.md` | 2a | |
| **2d** Ngân sách + báo cáo + báo có người chi | `02D_NGAN_SACH_BAO_CAO.md` | 2a | |
| **3** Mục tiêu chung | `03_MUC_TIEU_CHUNG.md` | 2a | Nhỏ: một hàng mục tiêu gắn một ví chung |

2b, 2c, 2d, 3 độc lập với nhau, làm theo thứ tự nào cũng được. Mỗi phần: thảo luận → đơn CAN-LAM → kế hoạch thi công client →
mã → nghiệm thu hai máy thật, hai tài khoản.

## 5. Nguyên tắc xuyên suốt

1. **Offline-first như phần còn lại của app.** Mọi khoản của nhà ghi vào SQLite trước, đồng bộ nền sau. Thứ cần mạng: tạo nhà,
   mời, tham gia, đổi vai, rời / giải tán, **sửa cài đặt của nhà** (hạn mức, định mức góp, tự góp).
2. **Nhà là chủ sở hữu thứ ba** (đơn 50 mục B, D): hàng có `Idhousehold` thuộc nhà; `Idaccount` khi ấy là **người ghi**. `/sync/pull`
   trả *(của tôi ∧ riêng) ∨ (của nhà tôi đang ở)*. Client không suy `idaccount` từ dữ liệu.
3. **Cặp hai khoản cho mọi dòng tiền qua lại riêng ↔ nhà** (góp, rút, tự góp): mỗi nửa nằm đúng phạm vi của nó — nửa riêng chỉ về
   máy chính chủ, nửa của nhà về máy mọi thành viên — nối bằng **mã cặp** (`Idfund_pair`). Không khoản nào trỏ từ phạm vi này sang
   phạm vi kia, nên **luật tham chiếu của đơn 50 không phải nới** và ví riêng của ai không lộ sang máy người khác.
4. **Cài đặt của nhà sống ở server, đi kèm trạng thái nhà** (`GET /api/households/me`). Client nhớ bản mới nhất theo tài khoản; offline
   vẫn xem và vẫn cảnh báo bằng bản đã nhớ. Server **không** thêm thực thể đồng bộ mới.
5. **Con số tính ở máy, từ các khoản đã đồng bộ** — số dư ví chung, "đã dùng" của hạn mức, "đã góp", tiến độ mục tiêu. Mọi máy có
   cùng tập khoản của nhà nên ra cùng số. ⚠️ Cảnh báo lúc Lưu dựa trên dữ liệu máy đang có — khoản người khác vừa ghi mà máy chưa
   kéo về thì chưa được tính.
6. **Thông báo của gia đình là luật cục bộ trên từng máy** (như mọi thông báo của app — bảng thông báo không đồng bộ). Máy Chủ nhà
   biết có người vượt hạn mức khi **máy ấy kéo được khoản vượt về**: ngay lập tức nếu app đang mở (socket `sync.completed` tới mọi
   thành viên — đơn 50 mục F), hoặc ở lượt đồng bộ nền kế tiếp (WorkManager, ~15 phút trở lên) / lần mở app. **App chưa có push
   từ server (FCM)** — ngoài phạm vi bộ này.
7. **Riêng tư:** server không trả email / số điện thoại của thành viên khác (đơn 50 C); hạn mức, định mức góp, cấu hình tự góp chỉ
   trả cho người được thấy (mục 3); ví riêng không bao giờ về máy người khác.
8. **Không tiền nào được tính hai lần trong cùng một màn:** màn cá nhân thấy nửa riêng (chi *"Góp quỹ gia đình"*), khu Nhà mình thấy
   nửa của nhà (*"Minh góp"*), không màn nào cộng cả hai.

## 6. Thay đổi so với đơn 50 (backend đã đọc) — **đọc mục này trước khi làm đơn 50**

| # | Đơn 50 | Bộ tài liệu này | Ở đâu |
|---|---|---|---|
| 1 | Mời chỉ bằng mã 8 ký tự (C #3–#7) | Thêm **mời bằng email**: bảng `household_invite` thêm cột, 4 endpoint mới, sự kiện `household.invited`, mã lỗi mới | `01` mục 2 |
| 2 | Hàng của nhà: Thành viên được tạo / sửa / xoá **mọi** hàng (D.2) | **Ma trận vai × thực thể**: ví / ngân sách / mục tiêu của nhà chỉ Chủ nhà; giao dịch của nhà: người ghi + Chủ nhà; mã đẩy mới `HOUSEHOLD_ROLE_FORBIDDEN` | `01` mục 3 |
| 3 | Luật tham chiếu có **ngoại lệ**: giao dịch riêng trỏ `idgoal` tới mục tiêu của nhà (D.2) | **Bỏ ngoại lệ** — mục tiêu chung là công tắc trên ví chung, góp qua cặp hai khoản | `01` mục 3, `03` |
| 4 | Nạp / rút quỹ (Transfer riêng ↔ nhà) = `HOUSEHOLD_SCOPE_MISMATCH`, *"phần 2 có thể phải nới"* (D.2) | **Giữ nguyên lệnh cấm** — góp / rút là cặp hai khoản, mỗi nửa đúng phạm vi; thêm cột `Idfund_pair` trên `transaction` | `02A` |
| 5 | Trạng thái nhà C.1 | Thêm `formerMembers`, `maxSharedWallets`, `spendingLimits`, `contributionQuotas`, `contributionDueDay`, `myAutoContributions` | `01` mục 4, `02B`, `02C` |
| 6 | Sự kiện F: `household.changed` khi vào / rời / đổi vai… | Thêm `household.invited`; `household.changed` phát thêm khi đổi hạn mức / định mức góp / trần ví | `01`, `02B`, `02C` |
| 7 | Mục 4 — phần 2 *quỹ chung + cho nhà xem*, phần 3 *chi chung + ai nợ ai*, phần 4 *mục tiêu chung qua `idgoal`* | Phần 2 tách 2a–2d **không có** *cho nhà xem*; **bỏ** *ai nợ ai* (không bảng `transaction_split`); mục tiêu chung = phần 3 mới, công tắc trên ví | mục 4 tệp này |
| 8 | (không có) | Trần số ví chung mỗi nhà (đề xuất 10, server thi hành) + mã đẩy `HOUSEHOLD_WALLET_LIMIT` | `02A` |

Phần còn lại của đơn 50 (A kiểm chủ sở hữu, B migration, C 12 endpoint, D phạm vi kéo về, E Premium, F, G danh mục nhà) **giữ
nguyên**.

## 7. Tổng hợp việc backend theo phần (để thảo luận khối lượng)

| Phần | CSDL | API | Đồng bộ | Thời gian thực / khác |
|---|---|---|---|---|
| 1 | đơn 50 B + 3 cột `household_invite` | đơn 50 C (12) + 4 endpoint lời mời email | đơn 50 D + ma trận vai × thực thể + `HOUSEHOLD_ROLE_FORBIDDEN` | `household.invited`; gửi thư (Brevo / Resend — đường OTP) |
| 2a | `transaction."Idfund_pair"` | `/me` thêm `formerMembers`, `maxSharedWallets` | nhận / trả `idfund_pair`; trần ví chung `HOUSEHOLD_WALLET_LIMIT`; khoản có mã cặp chỉ người ghi được **sửa** | — |
| 2b | bảng `household_spending_limit` | 1 endpoint đặt hạn mức; `/me` thêm `spendingLimits` (lọc theo người hỏi) | không | `household.changed` khi đổi |
| 2c | bảng `household_contribution_quota`, `household_auto_contribution`; cột `household."Contribution_due_day"` | 3 endpoint; `/me` thêm `contributionQuotas`, `contributionDueDay`, `myAutoContributions` | không | `household.changed` khi đổi định mức |
| 2d | không | không | ngân sách của nhà chỉ Chủ nhà (đã nằm trong ma trận phần 1) | — |
| 3 | chỉ mục duy nhất *một mục tiêu sống mỗi ví chung* | không | mục tiêu của nhà chỉ Chủ nhà, `idwallet` phải là ví chung của nhà | — |

## 8. Tổng hợp mã lỗi và thông báo

**Lỗi đẩy (`/sync/push`, `results[i].code`, client xếp VĨNH VIỄN — không gửi lại):**

| Mã | Từ | Khi | Client |
|---|---|---|---|
| `NOT_OWNER` | đơn 50 A | sửa / xoá hàng riêng của người khác | ✅ đã xếp 2026-10-26 |
| `HOUSEHOLD_NOT_MEMBER` · `HOUSEHOLD_READ_ONLY` · `HOUSEHOLD_CLOSED` · `HOUSEHOLD_SCOPE_MISMATCH` | đơn 50 D.3 | như đơn 50 | ✅ đã xếp 2026-10-26 |
| `HOUSEHOLD_ROLE_FORBIDDEN` | **mới** (`01` mục 3) | vai đủ quyền ghi vào nhà nhưng **không** đủ cho thao tác này (Thành viên sửa ví chung / ngân sách / mục tiêu; sửa khoản của người khác; chuyển giữa hai ví chung; Chủ nhà **sửa** khoản góp / rút của người khác) | ✅ đã xếp sớm 2026-10-27 (tên do tài liệu này đề xuất — backend đổi tên thì báo client) |
| `HOUSEHOLD_WALLET_LIMIT` | **mới** (`02A`) | tạo ví chung vượt trần của nhà | ✅ đã xếp sớm 2026-10-27 (như trên) |

⚠️ Mã nào rơi vào `DB_ERROR` là client **gửi lại mãi** (lỗi tạm) — mọi mã trên phải ném có `code` riêng và bắt ở `sync.service.js`
cạnh `BILL_ALREADY_PAID` (đơn 50 D.3).

**Lỗi API (4xx, `code` ở cấp gốc):** của đơn 50 C.3, cộng: `HOUSEHOLD_INVITE_WRONG_ACCOUNT` (403) · `HOUSEHOLD_INVITE_DECLINED` (409) ·
`HOUSEHOLD_INVITE_RATE_LIMIT` (429) — `01`; `HOUSEHOLD_LIMIT_INVALID_TARGET` (409) — `02B`; `HOUSEHOLD_QUOTA_INVALID_TARGET` (409) ·
`HOUSEHOLD_AUTO_CONTRIBUTION_INVALID` (409) — `02C`.

**Thông báo của gia đình (client, luật cục bộ — không phải việc backend):** nhóm mới `NotificationGroup.giaDinh`, **14** loại mới
(`NotificationKind` 20 → 34, đếm 2026-10-26). Mỗi loại phải sửa hai `switch` không `default` ở `notification_prefs.dart` và dựng đầu vào cho
`tatCaUngVien()` — bẫy của mảng thông báo.

| Loại | Phần | Trên máy | Mặc định | Khoá chống trùng |
|---|---|---|---|---|
| `loiMoiNha` | 1 | người được mời | bật | `loiMoiNha:<code>` |
| `gopQuyBiTraVe` · `gopQuyBiXoa` | 2a | người góp | bật | `gopTraVe:<cặp>` · `gopBiXoa:<cặp>` |
| `hanMucSapHet` · `hanMucVuot` | 2b | Thành viên · Chủ nhà | bật | `hanMuc80:<ví>:<dòng>:<kỳ>` · `hanMucVuot:<ví>:<người>:<dòng>:<kỳ>` |
| `gopConThieu` · `gopChuaDuTongHop` | 2c | người có định mức · Chủ nhà | bật | `gopThieu:<ví>:<tháng>` · `gopChuaDu:<tháng>` |
| `tuGopDaChay` · `tuGopKhongChay` | 2c | người bật tự góp | bật | `tuGop:<cấu hình>:<kỳ>` · `tuGopLoi:<cấu hình>:<kỳ>` |
| `nhaNganSachSapHet` · `nhaNganSachVuot` | 2d | Chủ nhà + Thành viên | bật | `nhaNganSach:<ngân sách>:<kỳ>:canhBao` · `…:vuot` |
| `nhaCoGiaoDich` | 2d | mọi thành viên | **tắt** | `nhaGiaoDich:<id khoản>` |
| `nhaMucTieuMoc` · `nhaMucTieuDat` | 3 | mọi người trong nhà | bật | `nhaMucTieu:<mục tiêu>:<25\|50\|75\|100>` |

Kế hoạch *Tin từ FlowMoney* (`system.broadcast`, 2026-10-26, chưa thi công) cũng thêm một nhóm — làm sau thì đếm lại.

## 9. Rủi ro chấp nhận

- **Cảnh báo hạn mức trên dữ liệu chưa đầy đủ** (nguyên tắc 5): hai người ghi cùng lúc offline, hay một người dùng hai máy offline, có
  thể vượt mà không được cảnh báo. Người dùng chọn *cảnh báo* chính vì lý do offline (quyết định #10).
- **Ghi-sau-thắng giữa người** (spec 2026-10-23 mục 4.4): hai người sửa **cùng một** khoản của nhà — hiếm, vì Thành viên chỉ sửa khoản
  của mình; chỉ còn Chủ nhà ↔ người ghi.
- **Một nửa của cặp lên server, nửa kia bị từ chối:** client tự gỡ nửa riêng (`02A` mục 6). Cửa sổ ngắn hai nửa lệch nhau trên máy
  người góp là chấp nhận được.
- **Thông báo trễ khi app đóng** (nguyên tắc 6).

## 10. Ngoài phạm vi

Ai nợ ai / chia khoản tự trả · cho nhà xem ví riêng · hoá đơn chung · push FCM · quét QR mời (bẫy R8 bản release) · tạo / tham gia nhà
khi offline · một tài khoản ở nhiều nhà · App Links mở thẳng app từ thư mời · Nhập nhanh / quét ảnh / giọng nói ở chế độ nhà (2a) ·
xuất báo cáo của nhà ra tệp.

## 11. Câu hỏi để thảo luận (backend / PO)

- **Q1 — Số migration.** Đơn 50 đề xuất `database/37_create_household.sql`. Bộ này thêm cột / bảng cho 1, 2a, 2b, 2c, 3. Gộp vào một tệp
  37 hay mỗi phần một tệp (38, 39…)? Client đề xuất **mỗi phần một tệp** để phần nào xong phần ấy.
- **Q2 — Thư mời.** Hạn mức gửi của Brevo / Resend trên tài khoản dev / production? Trần 20 thư / nhà / ngày có cần thấp hơn?
- **Q3 — Danh mục của nhà.** Spec 2026-10-23 cho Thành viên thêm / sửa danh mục của nhà; nguyên tắc mới *"Chủ nhà cấu hình"* gợi ý chỉ
  Chủ nhà. Client giữ như cũ (Thành viên cần thêm danh mục lúc ghi khoản chi) — backend / PO có muốn siết?
- **Q4 — Một hay nhiều endpoint cho cài đặt.** `02B` / `02C` đề xuất endpoint riêng cho từng loại cài đặt; gộp thành một `PUT
  /api/households/settings` có tiện hơn cho backend không?
- **Q5 — Tên trường.** Tên khoá / cột ở bộ này là **đề xuất**; backend đổi được nhưng ghi lại tên thật trong đơn trả lời (client dựng
  hợp đồng theo đó).

## 12. Trả lời / thảo luận

*(Chờ backend / PO.)*

## Lịch sử tài liệu

- **2026-10-26** — bản đầu (client, sau brainstorming với người dùng: 18 quyết định mục 2).
