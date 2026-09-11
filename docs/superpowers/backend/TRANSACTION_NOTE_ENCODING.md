# Client mã hoá ý nghĩa vào `transaction.Note` — đừng vô tình phá

**Thêm 2026-09-08; cập nhật 2026-09-11 (mục 3).** Đây **không phải một việc cần backend làm.** Không xin cột
mới, không xin migration, không xin đổi endpoint. Tài liệu này tồn tại vì phía
client đang gửi lên một quy ước mà nhìn vào lược đồ **không thấy được**, và
người đọc dữ liệu ở đầu bên kia — Admin-web, truy vấn báo cáo, một lần dọn dữ
liệu — sẽ gặp nó.

---

## 1. Quy ước

Cột `transaction."Note"` (kiểu `@db.Text`) của các giao dịch **thuộc mục tiêu
tiết kiệm** không phải chữ tự do. Client sinh nó theo đúng ba khuôn:

| Việc người dùng làm | Chuỗi client ghi vào `Note` |
|---|---|
| Tự bấm "Nạp vào mục tiêu" | `Tích lũy mục tiêu: <tên mục tiêu>` |
| **App tự trích** theo chu kỳ đã cài | `Tích lũy mục tiêu: <tên mục tiêu> (tự động)` |
| Tự bấm "Rút khỏi mục tiêu" | `Rút từ mục tiêu: <tên mục tiêu>` |

Cả ba đều là giao dịch `Type = 'transfer'` mang cùng một `Idgoal`.

Hậu tố `" (tự động)"` là phần **mới từ 2026-09-08**. Hai tiền tố đã có từ trước.

---

## 2. Vì sao ý nghĩa lại nằm trong một trường chữ

Vì phía client không có chỗ nào khác đặt nó mà không hỏng.

- **Chiều tiền** (nạp hay rút) không suy được từ `Type` — cả hai đều là
  `'transfer'` — cũng không suy được từ vị trí ví. Suy từ ví là diễn giải hàng
  **cũ** bằng cấu hình **hiện tại** của mục tiêu: người dùng đổi ví tích luỹ một
  lần là mọi khoản nạp trước đó đọc thành khoản rút. Lỗi này đã xảy ra thật trên
  máy ảo ngày 2026-09-05.
- **Ai đã chuyển tiền** (người dùng hay bộ chạy nền) cũng không có cột nào. Một
  cột chỉ-có-ở-client thì hàng kéo về từ server luôn trống, nên máy thứ hai của
  cùng người dùng sẽ thấy mọi khoản là "tay".

Tiền tố và hậu tố thì nằm **trong chính hàng dữ liệu**, đi qua được cả hai chiều
đồng bộ, và không đổi khi cấu hình mục tiêu đổi.

Client biết rõ đây là đánh đổi: `Note` **sửa được**, nên nhãn có thể mất. Mất thì
client đọc về mặc định an toàn ("tay", "nạp"), không phải về một lời khẳng định
sai. Đó là lý do quy ước này chấp nhận được — không phải vì nó chắc chắn.

---

## 3. Backend cần biết gì

> ⚠️ **Cập nhật 2026-09-10 — yêu cầu số 1 dưới đây nay đang bị vi phạm.** Đợt
> `main` ngày 2026-09-10 cho `/sync/push` chạy mọi `Note` qua
> `filterSensitiveNote()` rồi mới mã hoá, và bộ lọc ấy bắt nhầm cả chuỗi do app
> sinh: `Tích lũy mục tiêu: Két mật khẩu (tự động)` bị lưu thành
> `… Két Mật khẩu: [ĐÃ LƯỢC BỎ] động)` — mất hậu tố, nên khoản trích tự động đọc
> thành khoản nạp tay. Bản đã lọc còn **đè lên máy người dùng** ở ngay chu kỳ đồng
> bộ ấy. Tái hiện đầu-cuối và việc xin sửa:
> [`DA-XONG/SYNC_NOTE_FILTER_REWRITE.md`](./DA-XONG/SYNC_NOTE_FILTER_REWRITE.md).
> Tài liệu này vẫn "không xin gì" — việc xin nằm ở tệp kia.
>
> ✅ **2026-09-11 — vi phạm ấy đã hết, theo mã.** Sau khi gộp `main` @ `cc65f4f`,
> bộ lọc viết lại (Luhn + khuôn số thẻ, "mật khẩu"/"password" chỉ khớp khi có
> `:`/`=`, bỏ "pin" — `utils/content-filter.util.js`) chạy đúng cả 15 ca của tài
> liệu kia khi thử bằng chính hàm ấy, kể cả chuỗi `(tự động)` ở trên. Chưa kiểm
> đầu-cuối. Còn hai chỗ nên biết: tên mục tiêu **tự gõ** có dạng `password: …` vẫn
> bị lọc (chấp nhận được); và `Note` nay được **mã hoá** khi ghi, mà `decrypt()`
> hỏng thì trả nguyên chuỗi `enc:…` — đổi khoá mã hoá mà không mã hoá lại dữ liệu
> cũ thì tiền tố/hậu tố ở mục 1 không còn đọc được ở lượt kéo về (mục 2.6
> [`CAN-LAM/VERIFY_7675B35_REMAINING.md`](./CAN-LAM/VERIFY_7675B35_REMAINING.md)).

**Ba điều, tất cả đều là "đừng làm", không phải "hãy làm":**

1. **Đừng cắt, chuẩn hoá, hay viết hoa lại `Note`** của giao dịch mang `Idgoal`.
   Cột đang là `@db.Text` nên không có giới hạn độ dài — đã kiểm trong
   `schema.prisma`, và đó chính là lý do client thấy an toàn khi thêm hậu tố.
   Đặt một giới hạn độ dài về sau sẽ cắt cụt phần cuối, tức **đúng chỗ chứa
   hậu tố**.

2. **Đừng sinh `Note` thay client** cho các hàng thuộc mục tiêu. Nếu một luồng
   phía server có lúc nào đó tự tạo giao dịch tích luỹ, nó phải ghi đúng một
   trong ba khuôn ở mục 1, nếu không client đọc sai chiều tiền.

3. **Admin-web sẽ thấy chữ "(tự động)"** trong danh sách giao dịch, bắt đầu từ
   những khoản trích tự động ghi sau 2026-09-08. Đó là chủ ý, không phải rác dữ
   liệu — đừng dọn.

**Không có việc gì phải làm trong đợt này.** Nếu về sau backend muốn đưa hai
thông tin ấy thành cột thật (một cột chiều tiền, một cột nguồn gốc bản ghi), đó
là cải tiến hợp lý — nhưng nó phải đi kèm phần **suy ngược cho dữ liệu cũ**, và
client sẽ vẫn phải giữ đường đọc theo ghi chú cho những hàng ghi trước đó.

---

## 4. Đọc thêm

- Client: `src/Client-app/lib/features/goal/domain/goal_history_direction.dart`
  — nơi duy nhất định nghĩa cả ba khuôn, dùng chung cho nơi ghi lẫn nơi đọc.
- Lý lẽ đầy đủ và các phương án đã loại: mục **3.25** `docs/GOAL_FEATURE.md`.
- Vì sao khoản trích tự động cố ý giống hệt khoản nạp tay trên mọi cột khác:
  mục **3.12** cùng tài liệu.
