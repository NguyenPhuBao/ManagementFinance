# Chặn trả tiền hai lần cho CÙNG MỘT KỲ hoá đơn, không chỉ cùng `Idbill` (mục 41)

**Người viết:** Client-app · **Ngày:** 2026-10-09 · **Mức:** cao — tiền bị trừ nhiều lần cho một kỳ, đã xảy ra thật
(tài khoản 10: −300.000 đ thay vì −100.000 đ).
**Xin Backend:** mở rộng chốt `chanTraHaiLan` ở `upsertTransaction` (`modules/sync/sync.repository.js:302`) từ *"cùng
`Idbill`"* sang *"cùng **kỳ**"* — tức cả các hàng `bill` **anh em** (cùng `Previous_bill_id`, cùng `Due_date`) — và trả
một **mã lỗi riêng**. Không đổi LWW, không đổi luật `/sync/pull`, không đổi lược đồ, không đổi payload.

---

## 1. Hiện tượng (G87 phía client, mở và đóng 2026-10-09)

Mỗi kỳ của hoá đơn lặp là **một hàng** `bill`, sinh ra lúc trả kỳ trước (`Previous_bill_id` trỏ về kỳ trước). Hai máy
cùng trả một kỳ (máy offline, bộ tự trả chạy) thì **mỗi máy sinh một kỳ kế tiếp riêng**, khác `Idbill`, cùng
`Previous_bill_id`, cùng `Due_date`. Chốt hiện tại chặn đúng khoản chi thứ hai cho kỳ **cha** (cùng `Idbill`), nhưng:

- client đẩy `bill` **trước** `transaction` (khoá ngoại; `ENTITY_PRIORITY` bill 30 < transaction 40), nên kỳ con của máy
  thua **lên server trót lọt** trước khi khoản chi của nó bị `BILL_ALREADY_PAID`;
- máy thua xoá mềm kỳ con ấy ở máy mình, nhưng bước Pull ngay sau trong cùng chu kỳ ghi đè lệnh xoá bằng bản sống của
  server — kỳ trùng sống lại;
- tới kỳ sau, bộ tự trả của một máy khác thấy **hai/ba kỳ "chưa trả"** và trả **từng kỳ**. Mỗi khoản chi mang một
  `Idbill` khác nhau → chốt hiện tại không thấy gì để chặn.

Client đã vá phía mình (gộp kỳ trùng sau mỗi lần kéo về — `features/bill/domain/bill_ky_trung.dart`; `payBill` và bộ tự
trả từ chối kỳ có kỳ trùng đã đóng). Nhưng còn **một khe client không đóng được**: máy A vừa kéo về xong (chưa thấy kỳ
trùng nào đã trả) thì máy B mới trả kỳ trùng kia — A trả kỳ của mình, server nhận cả hai. Chỉ server, nơi duy nhất thấy
mọi khoản chi, chặn được khe ấy.

## 2. Đo thật trên CSDL dev (2026-10-09, chỉ đọc)

Hàng `bill` sống có `Previous_bill_id` trùng nhau và cùng `Due_date` (CSDL dev có 37 hoá đơn sống):

| Tài khoản | Kỳ (8 ký tự đầu) | Cha | `Due_date` | `Pay_status` | `Auto_pay` | Khoản chi sống |
|---|---|---|---|---|---|---|
| 10 | `22bb274a` · `8027c914` · `cccb14ee` | `31617105` | `2026-10-05 00:00:00` | Payed × 3 | true | **1 + 1 + 1** |
| 17 | `0231f67e` · `059791de` | `e646d141` | `2026-10-13 00:00:00` | Pending × 2 | true | 0 |
| 19 | `98c84aa6` · `a4e347ab` · `a6682c91` | `d0f455fe` | `2026-10-13 00:00:00` | Pending × 3 | true | 0 |

- Tài khoản 10 (Netflix tự trả tuần): **ba khoản chi 100.000 đ cho cùng kỳ 05/10** — đúng thiệt hại chốt mới sẽ chặn.
- Tài khoản 17 và 19: kỳ trùng **chưa trả, bật tự trả, hạn 13/10**. Chưa mất tiền — cho tới khi một máy của tài khoản ấy
  tự trả từng kỳ. Chốt mới chặn đúng ca đó.
- `Due_date` của các kỳ anh em **bằng nhau tới từng micro giây** — cả hai cùng được tính từ cùng một kỳ cha bằng cùng một
  hàm phía client (`kyKeTiepCua`), nên **so bằng tuyệt đối** là đủ và an toàn hơn cắt về ngày (`date(...)`), vì cột là
  `timestamp` không múi giờ và CSDL từng mang hai đồng hồ (mục 40).

Câu truy vấn đã dùng (chạy từ `src/Backend` qua `$queryRawUnsafe`):

```sql
SELECT b."Idaccount", b."Idbill", b."Previous_bill_id", b."Due_date", b."Pay_status",
       (SELECT count(*) FROM "transaction" t WHERE t."Idbill" = b."Idbill" AND t."Deleted_at" IS NULL) AS khoan_chi
FROM bill b
WHERE b."Delete_at" IS NULL
  AND (b."Previous_bill_id", b."Due_date") IN (
        SELECT "Previous_bill_id", "Due_date" FROM bill
        WHERE "Delete_at" IS NULL AND "Previous_bill_id" IS NOT NULL
        GROUP BY 1, 2 HAVING count(*) > 1)
ORDER BY 1, 3, 2;
```

## 3. Xin làm

### 3.1. Chốt trả tiền theo kỳ trong `upsertTransaction`

Ở cả hai nhánh (tạo mới và cập nhật thắng LWW), **sau** phép kiểm cùng `Idbill` hiện có (giữ nguyên, giữ nguyên mã
`BILL_ALREADY_PAID`), thêm phép kiểm **kỳ anh em** — chỉ khi khoản chi đích còn sống và có `idbill`:

1. Đọc hàng `bill` của `idbill`. Hàng không có, hoặc `Previous_bill_id` là `NULL` (kỳ gốc — không sinh từ lần trả nào)
   → bỏ qua.
2. Tìm khoản chi **sống** (`Deleted_at IS NULL`), `idtran` không phải chính nó và **không nằm trong
   `dangXoaTrongLo`** (cùng lý do với chốt hiện tại — hoàn tác + trả lại trong cùng lô phải lọt), mà `Idbill` của nó là
   một hàng `bill` **sống** khác `idbill`, cùng `Previous_bill_id`, cùng `Due_date` (so bằng tuyệt đối).
3. Có → ném lỗi mã **`BILL_PERIOD_ALREADY_PAID`**.

Phác (chỉ để rõ ý, viết theo nếp của tệp):

```js
const chanTraTheoKy = async ({ idtran, idbill, deleted_at }) => {
  if (!idbill || deleted_at) return;
  const ky = await prisma.bill.findUnique({
    where: { idbill },
    select: { previous_bill_id: true, due_date: true },
  });
  if (!ky?.previous_bill_id) return;
  const khac = await prisma.transaction.findFirst({
    where: {
      deleted_at: null,
      idtran: { notIn: [idtran, ...dangXoaTrongLo] },
      idbill: { not: idbill },
      bill: { previous_bill_id: ky.previous_bill_id, due_date: ky.due_date, delete_at: null },
    },
    select: { idtran: true },
  });
  if (khac) {
    throw Object.assign(new Error('Kỳ hoá đơn này đã được thanh toán ở một kỳ trùng'), {
      code: 'BILL_PERIOD_ALREADY_PAID',
    });
  }
};
```

(Tên quan hệ `bill` trong `where` lồng nhau tuỳ `schema.prisma`; viết bằng hai truy vấn cũng được.)

### 3.2. Đưa mã mới qua phép ánh xạ lỗi của `sync.service.js`

Ngay cạnh nhánh `BILL_ALREADY_PAID` (`modules/sync/sync.service.js:181`), và **trước** nó nếu dùng regex (chuỗi
`BILL_PERIOD_ALREADY_PAID` không chứa `BILL_ALREADY_PAID`, nhưng đặt trước cho chắc):

```js
if (err.code === 'BILL_PERIOD_ALREADY_PAID') {
  code = 'BILL_PERIOD_ALREADY_PAID';
  friendlyMessage = err.message || 'Kỳ hoá đơn này đã được thanh toán ở một kỳ trùng';
}
```

⚠️ Thiếu bước này thì lỗi rơi về `DB_ERROR`; client xếp `DB_ERROR` là lỗi **tạm thời** và gửi lại khoản chi ở **mọi**
chu kỳ đồng bộ, im lặng — cùng vòng lặp `DA-XONG/SYNC_PUSH_ERROR_MAPPING.md` đã sửa. `code` phải nằm trong
`results[idx]` như mọi mã khác.

### 3.3. Vì sao phải là MÃ RIÊNG, không dùng lại `BILL_ALREADY_PAID`

Với `BILL_ALREADY_PAID`, client gỡ khoản trả rồi **đánh dấu chính hoá đơn ấy là đã trả** — đúng, vì server có khoản chi
cho **đúng `Idbill`** ấy. Với kỳ anh em thì sai: hoá đơn của máy này **không** được trả, kỳ **trùng** của nó mới được
trả. Đánh dấu nó *đã trả* làm phép gộp phía client thấy hai kỳ cùng đã đóng và giữ cả hai mãi — một kỳ "đã trả" không
có khoản chi nào. Nên client cần phân biệt hai ca, và chỉ mã mới phân biệt được.

**Hợp đồng phía client** khi nhận `BILL_PERIOD_ALREADY_PAID` (client làm, không phải việc của backend): gỡ khoản trả và
hoàn tiền về ví ở máy này, cho khoản chi thoát hàng đợi (server chưa từng có nó), **để hoá đơn ở trạng thái còn phải
trả** — lượt gộp kỳ trùng sau lần kéo về kế tiếp sẽ xoá mềm nó và đẩy lệnh xoá lên. ⚠️ Client sẽ thêm mã vào danh sách
lỗi vĩnh viễn **trước** khi bản backend này lên môi trường nào; nếu đổi tên mã, xin ghi lại tên cuối cùng vào chính tệp
này.

## 4. Kiểm lại

Ca thử đề nghị thêm vào bộ test sync của backend (`node --test`):

1. Kỳ cha P có hai kỳ con C1, C2 (cùng `Previous_bill_id`, cùng `Due_date`); khoản chi T1 cho C1 đã có → đẩy T2 cho C2
   → `BILL_PERIOD_ALREADY_PAID`, T2 không được tạo.
2. Đẩy khoản chi thứ hai cho **cùng** `Idbill` → vẫn `BILL_ALREADY_PAID` (mã cũ không đổi).
3. Cùng lô: xoá T1 + tạo T2 cho C2 → T2 lọt (`dangXoaTrongLo`).
4. C1 đã bị xoá mềm (dù T1 còn sống) → T2 cho C2 lọt — chỉ xét kỳ anh em **sống**.
5. Hai kỳ cùng cha nhưng **khác** `Due_date` (hai kỳ nối tiếp hợp lệ) → không chặn.
6. Kỳ gốc (`Previous_bill_id` NULL) → không xét kỳ anh em.
7. Sửa (LWW thắng) chính T1 → lọt.

Trên CSDL, sau khi triển khai: câu truy vấn mục 2 thêm điều kiện `khoan_chi > 0` rồi đếm theo nhóm — không nhóm nào được
có **hơn một** kỳ mang khoản chi sống, trừ dữ liệu cũ của tài khoản 10 (người dùng sẽ tự hoàn tác hai khoản thừa ở máy).

## 5. Phạm vi — cố ý KHÔNG xin

- **Không xin chặn tạo hàng `bill` kỳ trùng** (từ chối hàng thứ hai cùng `Previous_bill_id` + `Due_date`). Nghe gọn hơn
  nhưng có hại: client đẩy `bill` trước `transaction`, nên một máy offline qua nhiều kỳ tự trả mà bị từ chối kỳ con thì
  khoản chi của kỳ ấy và kỳ cháu phía sau vỡ **khoá ngoại** — client xếp lỗi khoá ngoại là tạm thời (thường chỉ là sai
  thứ tự) và gửi lại mãi. Kỳ trùng **chưa trả** thì client đã tự gộp được; thứ chỉ server chặn được là **trả tiền**.
- **Không xin dò theo gốc chuỗi.** Client gộp kỳ trùng theo *gốc chuỗi + ngày hạn* (năm kỳ 12/10 của tài khoản 10 nằm
  dưới ba cha khác nhau — chính là ba kỳ 05/10 trùng). Chốt ở server theo *cha* chặn từ nhánh rẽ **đầu tiên**: kỳ con
  chỉ sinh ra khi kỳ cha được trả, nên chặn được lần trả thứ hai của kỳ 05/10 thì không còn ba cha để đẻ năm kỳ 12/10.
- **Kỳ trùng đã *bỏ qua* (`Skipped`)** không có khoản chi nên chốt này không thấy — client tự chặn ca ấy
  (`kyCungKyDaDong` trong `payBill` và bộ tự trả).
- Không dọn dữ liệu cũ, không thêm unique index (ba kỳ đã trả của tài khoản 10 sẽ làm index không tạo được).

## 6. Liên quan

- Chốt hiện tại: CAN-LAM 20 §2.1 (`DA-XONG/CON_LAI_SAU_CBBEEB4.md`), có từ `7779999`.
- Phía client: `docs/bill/BILL_DOCUMENTATION.md` mục 6.8 (khối G87), `docs/CLIENT_APP_KNOWN_GAPS.md` G87.
