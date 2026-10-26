# Gia đình — 03. Mục tiêu chung (công tắc trên ví chung)

> **Ngày:** 2026-10-26 · **Trạng thái:** thiết kế người dùng đã duyệt, chưa có mã · **Người đọc:** backend, PO, client.
> **Cần trước:** `02A` (ví chung, góp). Quyết định gốc: `00_TONG_QUAN.md` mục 2 — #17 **mục tiêu chung là công tắc "Đặt mục tiêu" trên ví chung**,
> bật / tắt tuỳ nhu cầu, tiến độ = số dư ví.

---

## 1. Mục đích và vì sao làm theo cách này

Nhà muốn tiết kiệm cho một việc (*Du lịch Đà Lạt 20 triệu trước 12/2026*). Thay vì một đối tượng *mục tiêu* riêng với luồng góp riêng, mục tiêu
là **thuộc tính bật / tắt của một ví chung**: ví *Quỹ du lịch* bật *"Đặt mục tiêu"*, góp vào ví ấy (`02A`) **chính là** góp vào mục tiêu.

Vì sao (người dùng chọn 2026-10-26, so với bản *đối tượng riêng*):

- **Không luồng góp thứ hai**, không khoản gắn `idgoal`, không ngoại lệ luật tham chiếu (đơn 50 D.2 — `01` mục 3 bỏ ngoại lệ ấy).
- **Không mất số khi nhiều người góp cùng lúc offline.** Mục tiêu cá nhân lưu tiến độ ở cột `currentAmount`, cộng dồn mỗi lần nạp, đồng bộ
  ghi-sau-thắng — hai người cùng góp offline thì máy đẩy sau **đè mất** khoản của người kia. Ở đây tiến độ **suy từ số dư ví**, mọi máy cùng tập
  khoản ⇒ cùng số.
- Đổi lại: một mục tiêu gắn **đúng một** ví chung — không gom từ nhiều ví (chấp nhận).

Mục tiêu **cá nhân** không đổi gì.

## 2. Người dùng thấy gì

- **Tạo / Sửa ví chung** (Chủ nhà — `02A` mục 10 màn 2) có công tắc **"Đặt mục tiêu"**; bật ⇒ hiện hai ô **Số tiền mục tiêu** (trần 13 chữ số) và
  **Hạn** (bắt buộc — bảng mục tiêu đòi ngày đích). Bật lúc tạo ví hay bật về sau đều được; **tắt** lúc nào cũng được (hỏi xác nhận một lần:
  *"Bỏ mục tiêu của Quỹ du lịch? Tiền trong ví giữ nguyên."*).
- **Thẻ ví** ở *Nhà mình* và đầu **Chi tiết ví chung**: thanh tiến độ *"12.000.000 / 20.000.000 đ — 60%"*, còn thiếu, còn bao nhiêu ngày, và *"cần
  góp khoảng {X} mỗi tháng"* (thiếu / số tháng còn lại, làm tròn lên); đã đạt ⇒ nhãn *"Đã đạt mục tiêu"*; quá hạn chưa đạt ⇒ nhãn *"Quá hạn"*.
- **Bảng góp, định mức góp, tự góp** là của ví (`02A` mục 8, `02C`) — không có bảng riêng cho mục tiêu.
- Mục tiêu chung **không** hiện ở trang Mục tiêu cá nhân (`/goals`), khối Nhận xét hay tool mục tiêu của Trợ lý AI (dữ liệu nhà chỉ ở khu *Nhà
  mình* — quyết định #5).

## 3. Luật

- **Dữ liệu:** một hàng `goal` có `Idhousehold` = nhà, `idwallet` = ví chung, `name` = tên ví (lưu lại mỗi lần lưu; giao diện luôn hiện tên **ví**),
  `targetAmount`, `targetDate`, `startDate` = lúc bật. Các cột trích tự động (`auto_deposit_*`), chu kỳ, lặp lại, ưu tiên: trống / mặc định —
  **không dùng** cho mục tiêu chung (tự góp thay thế — `02C`).
- **Một mục tiêu sống mỗi ví chung.** Tắt công tắc = **xoá mềm** hàng `goal`; bật lại = hàng mới (id mới).
- **Tiến độ** = `max(0, số dư ví chung) / targetAmount` — số dư do `SoDuViService` tính từ các khoản của nhà (`02A` mục 7.1). **Không** đọc cột
  `currentAmount`; client gửi lên giá trị gì cũng được (đề xuất 0), server không dùng.
- **Đã đạt** = số dư ≥ mục tiêu — **suy ra**, không ghi cờ `isCompleted`. Chi từ ví làm số dư tụt dưới mục tiêu ⇒ thanh tiến độ lùi, nhãn *Đã đạt*
  mất (đúng với tiền thật còn trong quỹ). Mục tiêu không tự tắt khi đạt — Chủ nhà tự tắt.
- Phép tính *cần góp mỗi tháng*, *còn thiếu*, *còn ngày* là hàm thuần ở `household/domain/muc_tieu_chung.dart`; dùng lại hàm thuần của mục tiêu
  cá nhân **khi** chúng nhận con số tiến độ làm tham số (truyền số dư ví thay cho `currentAmount`) — không chép luật mốc / chậm kế hoạch ra bản thứ
  hai.
- Chỉ **Chủ nhà** bật / sửa / tắt (`01` mục 3).

## 4. Thông báo (nhóm *Gia đình*, mặc định **bật**, mọi người trong nhà)

| Loại | Khi | Khoá chống trùng | Câu |
|---|---|---|---|
| `nhaMucTieuMoc` | tiến độ lần đầu vượt 25% / 50% / 75% | `nhaMucTieu:<idgoal>:<25\|50\|75>` | *"Quỹ du lịch đã được {50%} mục tiêu"* |
| `nhaMucTieuDat` | tiến độ lần đầu chạm 100% | `nhaMucTieu:<idgoal>:100` | *"Quỹ du lịch đã đạt mục tiêu"* |

- **Mỗi mốc một lần trong đời mục tiêu** — số dư tụt rồi lên lại không báo lại (khoá theo id mục tiêu; bật lại mục tiêu là id mới ⇒ báo lại từ đầu,
  đúng ý).
- **Lần đầu máy thấy mục tiêu** (vừa vào nhà, vừa cài lại app): mốc đã vượt được **ghi nhận im lặng**, chỉ báo mốc vượt về sau — không đổ ba thông báo
  25 / 50 / 75 cùng lúc cho người mới vào.
- Các mốc dùng lại định nghĩa mốc của mục tiêu cá nhân (3.21 `GOAL_FEATURE.md`) — không đẻ luật thứ hai.

## 5. Việc backend

- **Chỉ mục duy nhất** — một mục tiêu sống mỗi ví chung:

  ```sql
  CREATE UNIQUE INDEX IF NOT EXISTS "uq_goal_household_wallet_active"
    ON "goal" ("Idwallet") WHERE "Idhousehold" IS NOT NULL AND "Delete_at" IS NULL;
  ```

  Vi phạm qua `/sync/push` ⇒ `UNIQUE_VIOLATION` (đã có, client xếp vĩnh viễn) — client chặn trước nên chỉ xảy ra khi hai máy Chủ nhà cùng bật
  offline. Backend muốn mã riêng thì ghi tên trong đơn trả lời — client phải thêm vào danh sách vĩnh viễn **trước** khi backend lên.
- Ma trận quyền `01` mục 3 đã gồm `goal` của nhà (chỉ Chủ nhà); luật tham chiếu đơn 50 D.2: `idwallet` của mục tiêu của nhà phải là ví của **chính**
  nhà ấy.
- **Bỏ ngoại lệ `idgoal`** (giao dịch riêng trỏ mục tiêu của nhà) — `01` mục 3.
- Không endpoint / sự kiện mới. `Current_amount` của mục tiêu chung: lưu như gửi, không cần tính.

## 6. Phía client

- Form ví chung (`02A`) thêm khối công tắc + hai ô; lưu ví và hàng `goal` trong **một** thao tác repository (bật lần đầu ⇒ tạo `goal`; tắt ⇒ xoá
  mềm `goal`).
- `household/domain/muc_tieu_chung.dart` (tiến độ, còn thiếu, cần góp mỗi tháng — tháng ngắn / năm nhuận).
- Lọc của phần 1 (`idhousehold IS NULL` ở DAO mục tiêu) giữ mục tiêu chung khỏi trang Mục tiêu cá nhân, khối Nhận xét, tool AI và **bộ trích tự
  động** `GoalAutoDepositRunner` (đọc `goalDao.getAll(idaccount)` — phải loại hàng của nhà, ca test riêng).
- `NotificationKind` thêm `nhaMucTieuMoc`, `nhaMucTieuDat` (nhóm `giaDinh`).
- **Stitch:** công tắc trong form ví chung, thẻ ví có thanh tiến độ.

## 7. Kiểm thử và nghiệm thu

- **Domain:** tiến độ từ số dư (số dư âm ⇒ 0%; vượt ⇒ > 100% hiện *Đã đạt*); cần góp mỗi tháng với hạn còn < 1 tháng / đã quá.
- **Dữ liệu:** bật / tắt / bật lại ⇒ hai hàng `goal` (một xoá mềm); không lọt vào trang Mục tiêu cá nhân, không bị bộ trích tự động chạy.
- **Thông báo:** mốc một lần; người mới vào nhà không nhận mốc cũ; bật lại mục tiêu báo lại từ đầu.
- **Nghiệm thu hai máy thật:** Chủ nhà bật mục tiêu 1.000.000 đ cho ví chung → Thành viên góp 300.000 đ ⇒ hai máy cùng 30%, nhận mốc 25% → Thành viên
  chi 100.000 đ từ ví ⇒ tiến độ lùi 20% (không báo lại) → góp tiếp tới đủ ⇒ *"đã đạt mục tiêu"* trên cả hai máy.

## 8. Câu hỏi để thảo luận

- **Q-3.1** — Dùng lại bảng `goal` (đề xuất — đã có cột `Idhousehold` từ phần 1, đồng bộ sẵn) hay backend thích hai cột `Target_amount` /
  `Target_date` trên `wallet`? Thêm cột vào `wallet` là đổi payload ví (13 trường) và hợp đồng đồng bộ — client nghiêng về dùng `goal`.

## 9. Trả lời / thảo luận

*(Chờ backend / PO.)*
