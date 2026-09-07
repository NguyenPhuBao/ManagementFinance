# Yêu cầu Backend: ba cột cấu hình trích tiền tự động của mục tiêu

**Ngày:** 2026-09-05
**Phạm vi:** Backend (PostgreSQL + Prisma + Sync API)
**Ưu tiên:** Thấp — **không có gì đang hỏng hôm nay**, đây là tài liệu *mở khoá*
**Từ:** Client-app

---

## 1. Tóm tắt trong ba câu

Client vừa làm xong **trích tiền tự động định kỳ** cho mục tiêu tiết kiệm
(schema v15). Ba cột cấu hình — số tiền mỗi kỳ, ví nguồn, và mốc kỳ đã trích —
cố ý là **cục bộ**, vì bảng `goal` phía backend chưa có chỗ chứa và quy tắc 4
trong `CLAUDE.md` cấm thêm trường vào payload đẩy trước khi backend sẵn sàng.

Hệ quả: bật trích tự động trên điện thoại rồi đăng nhập ở máy khác thì **máy kia
không trích gì cả**, và người dùng không có cách nào biết vì sao.

---

## 2. ⚠️ Đọc mục này trước khi làm bất cứ gì

**Ba cột phải lên cùng một lúc. Đưa hai cột đầu lên mà bỏ cột thứ ba là làm
hỏng nặng hơn hiện trạng.**

Lý do nằm ở vai trò của từng cột:

| Cột | Vai trò |
|---|---|
| `auto_deposit_amount` | số tiền trích mỗi kỳ |
| `auto_deposit_wallet_id` | ví **nguồn** (ví nhận là `Idwallet` đã có sẵn) |
| `auto_deposit_last_run` | **kỳ gần nhất đã trích xong** — cái chặn không cho trích lại |

Nếu chỉ hai cột đầu đồng bộ: cả hai máy đều thấy "đã bật trích tự động", nhưng
mỗi máy giữ một mốc `last_run` **riêng** của mình. Đến kỳ, **cả hai cùng
chuyển tiền** — và đó là tiền thật, chuyển khi người dùng không có mặt. Hiện tại
máy thứ hai không trích gì cả; như vậy vẫn tốt hơn trích hai lần.

Đây chính là lý do client chọn để **cả ba** ở lại máy thay vì đẩy phần dễ lên
trước.

---

## 3. Cột xin thêm

```prisma
model goal {
  // ... các cột đang có

  /// Số tiền trích mỗi kỳ. NULL = không bật trích tự động.
  auto_deposit_amount     Decimal?  @db.Decimal(18, 2)

  /// Ví NGUỒN của khoản trích. Ví nhận là `Idwallet` đã có.
  auto_deposit_wallet_id  String?   @db.VarChar(36)

  /// Mốc của kỳ gần nhất đã trích xong. NULL = chưa bật.
  auto_deposit_last_run   DateTime?
}
```

**Không** đặt khoá ngoại cho `auto_deposit_wallet_id`. Client đã tự kiểm ví còn
tồn tại trước mỗi lần trích, và một khoá ngoại ở đây sẽ chặn việc xoá ví theo
một đường mà giao diện chưa có lối thoát — đúng cái bế tắc đã gặp với `Idwallet`
(xem mục 3.1 `docs/GOAL_FEATURE.md`).

Kiểu `Decimal(18,2)` để khớp `Target_amount` / `Current_amount` đang dùng.

---

## 4. Chỗ cần sửa trong mã

| Việc | Ở đâu |
|---|---|
| Migration thêm ba cột nullable | Prisma migration |
| Ánh xạ tên trường payload → cột | `sync.repository.js` — nơi đã ánh xạ `time_cycle_take_money` |
| Trả ba cột ở nhánh pull | cùng file, hàm dựng payload mục tiêu |

Tên trường trong payload đẩy/kéo: `auto_deposit_amount`,
`auto_deposit_wallet_id`, `auto_deposit_last_run` — **giữ đúng dạng
snake_case này**, không đổi hoa thường. Bảng `goal` hiện dùng `snake_case` cho
`cycle_take_money` và `time_cycle_take_money`, khác với `Delete_at` /
`Status_complete` cùng bảng; đó là sự thật khó chịu nhưng có thật, nên hãy chép
theo hai cột chu kỳ chứ đừng suy từ các cột viết hoa.

---

## 5. Client phải làm gì sau khi backend xong

Bốn việc, theo thứ tự:

1. Thêm ba khoá vào `_collectPendingOps` (nhánh `goal`) và vào nhánh pull của
   `sync_engine.dart`.
2. **Cập nhật `sync_payload_contract_test.dart` cùng lúc** — payload mục tiêu
   hiện khoá đúng **18 trường**, và ba cột này đang nằm trong danh sách *cấm rò
   rỉ*. Không sửa test thì nó đỏ ngay, và đó là điều đúng: hợp đồng tên trường
   là thứ duy nhất bắt được lỗi này, vì sai tên trường thì **im lặng** (quy tắc
   4 trong `CLAUDE.md`).
3. Gỡ chú thích "CỘT CỤC BỘ" ở bảng `Goals` (`other_tables.dart`) và ở mục 3.12
   `docs/GOAL_FEATURE.md`.
4. Kiểm lại ca hai máy: bật trích ở máy A, đăng nhập máy B, đợi một chu kỳ →
   phải có **đúng một** giao dịch cho kỳ đó.

---

## 6. Vẫn còn một khe hở sau khi làm xong — và nó chấp nhận được

Đồng bộ không phải tức thời. Hai máy cùng mở, cùng tới kỳ, cùng chưa kịp kéo
`last_run` của nhau thì vẫn có thể trích hai lần.

Ba thứ làm khe hở này hẹp lại:

- Mốc kỳ là giá trị **tính ra** từ mốc neo, giống nhau trên mọi máy — nên hai
  máy sinh ra cùng một `dedupeKey` cho thông báo, và người dùng không nhận hai
  lời báo.
- `Current_amount` là **giá trị tuyệt đối**, không phải delta, nên LWW hội tụ về
  một con số chứ không cộng dồn sai.
- Trích tự động chỉ chạy khi app mở, và hai máy cùng mở đúng lúc tới kỳ là hiếm.

Vá triệt để cần một khoá phía máy chủ (ví dụ `UNIQUE(Idgoal, ky_trich)` trên
bảng giao dịch), và việc đó phụ thuộc cột `transaction.Idgoal` xin ở
`2026-09-05-backend-transaction-goal-id.md`. **Không cần làm ngay** — ghi ở đây
để người sau không tưởng khe hở này bị bỏ sót.

---

## 7. Nếu không làm thì sao

Không có gì hỏng. Trích tự động vẫn chạy đúng trên **máy đã bật nó**, và đó là
máy duy nhất của gần như mọi người dùng của đồ án này.

Thứ mất đi là tính năng ấy **không theo người dùng** sang máy mới. Chu kỳ và mốc
neo thì có — `cycle_take_money` và `time_cycle_take_money` vốn đã đồng bộ — nên
trên máy mới mục tiêu vẫn hiện đúng nhịp kế hoạch trong hộp dự báo, chỉ là không
tự trích. Đó là một sự im lặng khó hiểu với người dùng, nhưng **không mất tiền
và không sai số**.
