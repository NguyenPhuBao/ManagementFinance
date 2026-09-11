# `bank_transaction.incoming` phát ra hai hình dạng payload khác nhau

> ⛔ **2026-09-11 — soát lại sau `7675b35`:** chưa thống nhất — worker chỉ thêm
> `transaction_status`, `notification.service.js` vẫn phát hình dạng thứ hai, `type` vẫn hai
> nghĩa. Và nay tệ hơn: worker gọi thẳng `emitBankTransaction` **rồi** publish
> `bank_transaction.pending`, nên **mỗi giao dịch phát hai lần**. Câu "chưa làm hỏng gì" dưới
> đây là ảnh chụp 2026-09-09. `CAN-LAM/VERIFY_7675B35_REMAINING.md` §2.5.

> **Xin thống nhất một hình dạng.** Không đổi lược đồ, không cần migration,
> không cần client sửa gì *hôm nay*. Chi phí: sửa một trong hai chỗ phát cho
> khớp chỗ kia. Đây là việc **phòng ngừa** — nó chưa làm hỏng gì, và đó chính
> là lý do nó dễ bị bỏ qua cho tới khi hỏng thật.

**Ngày:** 2026-09-09 · **Người xin:** phía client

---

## 1. Triệu chứng

Chưa có triệu chứng nào cả — và sẽ không có, cho tới khi ai đó viết một dòng
đọc trường từ payload của sự kiện này. Lúc ấy nó hỏng theo đúng kiểu tệ nhất:
**một nửa số sự kiện cho `null`, không exception, không log**.

Đây đúng loại lỗi mà quy tắc 4 của `CLAUDE.md` phía client cảnh báo, chỉ khác
là lần này nó nằm ở đường socket chứ không ở đường `/sync/push`.

## 2. Nguyên nhân, đo được ngày 2026-09-09

Cùng một tên sự kiện được phát từ **hai** chỗ, với **hai** bộ tên trường.

**Chỗ thứ nhất** — `src/Backend/workers/bank.worker.js:206-217`, gọi thẳng
`customSocket.emitToUser(idaccount, 'bank_transaction.incoming', socketPayload)`:

```js
const socketPayload = {
  idtran, amount, type, status, note,
  gateway: bankAcc.bank_name || gateway,
  account_number: bankAcc.account_number,
  date_transaction: newTx.date_transaction,
  suggested_category: predictedCategoryName,
  confidence: aiConfidence,
};
```

**Chỗ thứ hai** — `src/Backend/modules/notification/notification.service.js:23-33`,
qua `emitBankTransaction`, sau khi nghe `bank_transaction.pending`:

```js
emitBankTransaction(data.idaccount, {
  idtran, amount,
  bankName: data.bankName,
  accountNumber: data.accountNumber,
  description: data.description,
  date: data.date,
  title: 'Giao dịch mới từ Ngân hàng',
  message: `...`,
  type: 'BankTransactionPending',
  createdAt: new Date().toISOString(),
});
```

Đặt cạnh nhau:

| Ý nghĩa | Chỗ 1 (worker) | Chỗ 2 (notification) |
|---|---|---|
| Tên ngân hàng | `gateway` | `bankName` |
| Số tài khoản | `account_number` | `accountNumber` |
| Ngày giao dịch | `date_transaction` | `date` |
| Nội dung | `note` | `description` |
| `type` | trạng thái giao dịch (`Pending`…) | **loại thông báo** (`BankTransactionPending`) |
| Chỉ có ở chỗ 1 | `status`, `suggested_category`, `confidence` | — |
| Chỉ có ở chỗ 2 | — | `title`, `message`, `createdAt` |

Đáng chú ý nhất là dòng **`type`**: cùng một tên trường, hai *ý nghĩa* khác
nhau. Một bên là trạng thái của giao dịch, bên kia là nhãn phân loại thông báo.
Đây là kiểu bất nhất nguy hiểm hơn cả việc đặt tên khác nhau, vì phép đọc
`data['type']` chạy trót lọt ở cả hai đường rồi cho ra hai thứ không so sánh
được với nhau.

Cả hai chỗ đều xuất phát từ cùng một luồng xử lý webhook SePay, nên trên thực
tế **cả hai đều nổ cho cùng một giao dịch** — chỗ 1 gọi trực tiếp, chỗ 2 qua
EventBus.

## 3. Việc xin backend làm

Chọn **một** hình dạng rồi sửa chỗ còn lại cho khớp. Client không có ý kiến về
việc chọn cái nào; đề nghị lấy chỗ 2 làm chuẩn vì nó đã mang sẵn `title`/
`message` dùng được cho thông báo, và đổi `type` ở chỗ 1 thành một tên khác
(`transaction_status` chẳng hạn) để tên ấy chỉ còn một nghĩa.

Nếu quyết định giữ nguyên cả hai vì lý do nào đó, xin **ghi lại** trong mã
nguồn rằng đây là chủ ý — một câu chú thích ở cả hai chỗ là đủ để người sau
không mất một buổi đi tìm.

## 4. Client sẽ dùng nó thế nào

**Hôm nay: không đọc trường nào cả.** Client dịch **tên sự kiện** thành một enum
rồi hiện một câu tiếng Việt là hằng số của chính client
(`lib/core/realtime/realtime_event.dart`); dữ liệu thật đi đường `/sync/pull`.

Quyết định ấy được đưa ra **chính vì** phát hiện này — nó biến cái bẫy thành vô
hại, và có test canh: một test cấm chữ số xuất hiện trong lời nhắn, một test
khác bắn payload rác (`null`, chuỗi, mảng) vào và đòi client vẫn chạy đúng.

Nên đây **không phải việc chặn client**. Nó là việc phải làm trước khi bất kỳ ai
— client, Admin-web, hay một dịch vụ khác — bắt đầu đọc payload này.
