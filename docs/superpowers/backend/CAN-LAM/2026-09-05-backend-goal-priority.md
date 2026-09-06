# Yêu cầu Backend: một cột thứ tự ưu tiên cho mục tiêu

**Ngày:** 2026-09-05
**Phạm vi:** Backend (PostgreSQL + Prisma + Sync API)
**Ưu tiên:** Thấp — **client chưa làm tính năng này**, đây là tài liệu *mở đường*
**Từ:** Client-app

---

## 1. Tóm tắt trong ba câu

Khảo sát các app quản lý tài chính trên thị trường (2026-09-05) cho thấy phần
mục tiêu của FlowMoney thiếu hai thứ đáng làm: **làm tròn số lẻ** và **ưu tiên
mục tiêu kèm phân bổ tự động**. Thứ nhất làm được hoàn toàn ở client. Thứ hai
cần **một cột** mà bảng `goal` phía backend không có.

Tài liệu này xin đúng cột ấy, **trước** khi client viết một dòng nào — vì đây là
lần thứ ba dự án gặp cùng một tình huống và hai lần trước đều để lại hậu quả.

---

## 2. ⚠️ Vì sao xin trước khi làm, thay vì làm rồi xin sau

Dự án đã có **hai** cột cục bộ sinh ra đúng theo lối "làm trước, xin sau":

| Cột | Hệ quả đang chịu |
|---|---|
| `transactions.goal_id` (v14) | Máy khác rơi xuống nhánh so **tên** — xem `2026-09-05-backend-transaction-goal-id.md` |
| `goals.auto_deposit_*` (v15) | Bật trích ở máy A thì máy B **không trích gì cả** — xem `2026-09-05-backend-goal-auto-deposit.md` |

Cái thứ hai đã được chứng kiến trực tiếp ngày 2026-09-05: sau khi chuyển sang
một máy ảo mới và đăng nhập lại, `cycle_take_money` và mốc neo **về được** từ
server (hai cột ấy vốn đã đồng bộ), còn `auto_deposit_amount` thì rỗng. Kết quả
là màn hình hiện đúng nhịp kế hoạch trong khi không có gì chạy — một sự im lặng
khó hiểu hơn hẳn việc tính năng không tồn tại.

Thứ tự ưu tiên **còn tệ hơn** nếu đi cùng đường ấy. Ba lý do:

1. Nó là **thứ tự người dùng tự sắp**, tức công sức bỏ ra chứ không phải một giá
   trị suy lại được. Mất là mất hẳn.
2. Nó **không có mặc định đúng**. Số tiền trích thiếu thì để trống là an toàn;
   còn thứ tự thiếu thì phải bịa ra một thứ tự nào đó, và bất kỳ thứ tự bịa nào
   cũng sai với người đã sắp tay.
3. Nếu về sau nối thêm **phân bổ tự động**, thứ tự ấy quyết định **tiền đi đâu**.
   Một cột cục bộ điều khiển dòng tiền là chỗ dự án đã tự cấm mình đi vào.

---

## 3. Cột xin thêm

Đúng một cột, nullable:

```prisma
model goal {
  // ... các cột đang có

  /// Thứ tự ưu tiên do người dùng sắp. NULL = chưa sắp.
  /// Số NHỎ hơn đứng trước. Xem quy ước ở mục 4.
  priority  Int?  @map("Priority")
}
```

Không index, không ràng buộc `UNIQUE`. Mục 4 giải thích vì sao trùng số là chấp
nhận được.

⚠️ **Tên cột trong CSDL viết hoa chữ đầu (`Priority`)**, còn tên trường Prisma
viết thường (`priority`). Đó là quy ước bảng `goal` đang dùng cho `Name`,
`Target_amount`, `Status_complete`; hai cột `cycle_take_money` /
`time_cycle_take_money` là ngoại lệ chứ không phải khuôn mẫu. Payload đồng bộ
dùng **`priority`**.

---

## 4. Quy ước giá trị — thưa, không liên tục

Client sẽ ghi các số **cách nhau 100**: `100`, `200`, `300`…

**Vì sao không dùng 1, 2, 3:** chèn một mục tiêu vào giữa thì phải đánh số lại
toàn bộ danh sách, tức một thao tác kéo thả sinh ra *n* bản ghi `pending` cùng
lúc. Với khoảng cách 100, chèn giữa hai mục tiêu chỉ ghi **một** hàng (`150`), và
hàng đợi đẩy chỉ có một phần tử.

**Trùng số là chấp nhận được.** Hai mục tiêu cùng `priority` thì client sắp tiếp
theo `target_date` — cùng quy tắc phụ mà `chiaMucTieu` đang dùng. Đặt `UNIQUE`
lên cột này sẽ biến một va chạm vô hại thành một bản ghi kẹt vĩnh viễn trong
hàng đợi đẩy.

**`NULL` xếp cuối**, không phải đầu. Mục tiêu cũ chưa từng được sắp thì không có
lý do gì để chúng nhảy lên trên những mục tiêu người dùng đã cố ý xếp.

---

## 5. Một khe hở còn lại, và vì sao nó chấp nhận được

Hai máy cùng sắp lại thứ tự khi đang ngoại tuyến thì LWW phân xử **theo từng
hàng**, không theo cả danh sách. Kết quả có thể là một thứ tự trộn giữa hai lần
sắp — không hàng nào sai, nhưng tổng thể không giống lần sắp nào cả.

Không vá ở đợt này, vì:

- Vá triệt để cần một khoá thứ tự kiểu phân số hoặc chuỗi (`"a0"`, `"a0V"`) —
  đắt hơn nhiều so với giá trị nó mang lại cho một đồ án.
- Hậu quả tệ nhất là người dùng phải kéo lại vài mục tiêu. **Không mất tiền,
  không mất bản ghi, không kẹt hàng đợi.**
- FlowMoney gần như luôn chỉ có một máy đang hoạt động cho mỗi tài khoản.

Ghi ở đây để người sau không tưởng chỗ này bị bỏ sót.

---

## 6. Chỗ cần sửa trong mã

| Việc | Ở đâu |
|---|---|
| Migration thêm một cột nullable | Prisma migration |
| Ánh xạ `priority` → cột `Priority` | `sync.repository.js` — nơi đã ánh xạ `cycle_take_money` |
| Trả cột ở nhánh pull | cùng file, hàm dựng payload mục tiêu |

Rẻ nhất là **gộp vào đúng đợt migration ở bước 5 của README** cùng
`transaction.Idgoal` và ba cột `auto_deposit_*`. Cả bốn đều chỉ thêm cột
nullable và không đụng dữ liệu cũ.

---

## 7. Client sẽ làm gì sau khi backend xong

Theo thứ tự:

1. Thêm cột `priority` vào bảng `Goals` (Drift) và vào `GoalEntity` — **cả bốn
   chỗ**: khai báo trường, hằng số dựng, `fromDrift`, `toCompanion`, `copyWith`.
   Bỏ sót một chỗ là cột chết y như `recurrence` từng chết: nó có mặt ở cả hai
   đầu, đồng bộ đủ hai chiều, nhưng `GoalEntity` không mang nên không tầng nào
   phía trên nhìn thấy.
2. Thêm `'priority'` vào payload đẩy **và** cập nhật
   `sync_payload_contract_test.dart` cùng lúc — payload mục tiêu hiện khoá đúng
   **18 trường**. Sai tên trường thì **im lặng** (quy tắc 4 trong `CLAUDE.md`),
   và test hợp đồng là thứ duy nhất bắt được.
3. Đọc `priority` ở nhánh pull.
4. Giao diện kéo thả ở tab "Đang theo đuổi", và sắp lại trong `chiaMucTieu` —
   nơi đã có **một** định nghĩa thứ tự cho cả hai tab.
5. Chỉ khi ba bước trên xong mới tính tới **phân bổ tự động**. Phần logic ấy
   nằm trọn ở client và không cần thêm gì từ backend; nhưng nó chuyển tiền
   thật, nên phải đi qua đúng bộ quyết định của `goal_auto_deposit.dart` chứ
   không viết lại.

---

## 8. Nếu không làm thì sao

Client có **hai** đường vòng, và cả hai đều có giá:

**Làm cột cục bộ như `auto_deposit_*`.** Chạy được ngay, không cần backend —
nhưng mắc đúng bệnh ở mục 2: thứ tự người dùng sắp tay không sang máy khác, và
không có gì trên màn hình nói vì sao. Với một thứ do chính người dùng tạo ra
bằng thao tác kéo thả, đây là kiểu mất dữ liệu khó chấp nhận nhất.

**Không làm gì cả.** Cũng là một lựa chọn hợp lý: danh sách hiện đã sắp theo hạn
gần nhất trước, và với hai hay ba mục tiêu thì đó gần như đã là thứ tự ưu tiên.
Tính năng này chỉ bắt đầu có nghĩa khi người dùng có năm mục tiêu trở lên.

Client **chọn phương án thứ hai** cho tới khi cột này có mặt. Đó là lý do tài
liệu này nằm ở nhóm 3 của README chứ không phải nhóm 2: không có gì đang hỏng,
và cũng chưa có tính năng nào đang chờ.
