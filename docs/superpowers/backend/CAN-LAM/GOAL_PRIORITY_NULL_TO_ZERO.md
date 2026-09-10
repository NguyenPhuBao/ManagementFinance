# `goal.Priority`: `null` bị ghi thành `0` — mục tiêu chưa sắp nhảy lên đầu danh sách sau một vòng đồng bộ

**Ngày:** 2026-09-10 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** một
dòng ở `mapEntityFields('goal')`, một giá trị mặc định ở nhánh tạo của
`upsertGoal`. Không migration.

---

## 1. Tóm tắt

`modules/sync/sync.repository.js:105`:

```js
if (m.priority !== undefined) { m.priority = Number(m.priority); }
```

`Number(null) === 0`. Client gửi `priority: null` cho mọi mục tiêu **chưa sắp**.
Đó là giá trị mặc định của cột, và là quy ước chốt với backend ngày 2026-09-05
(`DA-XONG/2026-09-05-backend-goal-priority.md`: *NULL = chưa sắp*, *NULL xếp
cuối*). Server lưu `0`, lượt kéo về mang `0` về máy, và `0` nhỏ hơn mọi giá trị
đã sắp nên mục tiêu ấy **nhảy lên đầu** danh sách — trên máy vừa tạo, và trên mọi
máy khác của người dùng.

**Xin:** giữ `null` là `null`.

---

## 2. Tái hiện đầu-cuối — 2026-09-10

Máy ảo `emulator-5554`, tài khoản 10, backend `localhost:3000`. Trước khi làm,
server có hai mục tiêu của tài khoản ấy: `MuaXe` (`Priority = 100`) và `MuaDT`
(`200`).

1. Tạo mục tiêu `ThuUuTien` qua giao diện, không kéo thả gì.
2. **Một giây** sau khi bấm Lưu, danh sách là `MuaXe`, `MuaDT`, `ThuUuTien` —
   mục tiêu mới đứng cuối, đúng luật NULL xếp cuối.
3. **16 giây** sau, đủ một chu kỳ đồng bộ (client đẩy trước, kéo sau), danh sách
   là `ThuUuTien`, `MuaXe`, `MuaDT`.
4. Truy vấn chỉ đọc trên server:

   ```
   f7482924-2326-4105-bc33-abc1d993a4cb | ThuUuTien | Priority = 0 | Update_at = 2026-09-10T10:58:09Z
   ```

Không lỗi, không log, không thông báo nào trên màn hình.

---

## 3. Chuỗi mắt xích — đọc mã

| Bước | Chỗ | Giá trị |
|---|---|---|
| Client dựng payload | `lib/core/sync/sync_engine.dart:1163` — `'priority': g.priority` | `null`. Khoá luôn có mặt; `sync_payload_contract_test.dart` khoá tập khoá |
| Client chuẩn hoá | `SyncPayloadNormalizer` không bỏ khoá mang `null` | `null` |
| Server ánh xạ | `sync.repository.js:105` — `Number(m.priority)` | **`0`** |
| Server ghi | dòng 477 (tạo) và 503 (sửa) — `mapped.priority !== undefined ? mapped.priority : …` | `0` |
| Client kéo về | `sync_engine.dart:891-892` — `int.tryParse('0')` | `0` |
| Client sắp | `lib/features/goal/domain/goal_grouping.dart:70-73` — `null` xếp cuối, số nhỏ đứng trước | **đứng đầu** |

```bash
node -e "console.log(Number(null))"   # 0
```

---

## 4. Vì sao `0` không bao giờ là giá trị hợp lệ từ client

`lib/features/goal/domain/goal_priority.dart:101-104`: phép chèn khi kéo thả giữ
`priority` **luôn dương**. Đánh số lại thì bắt đầu từ 100, cách nhau 100. Thả lên
đầu thì lấy `sau - 100` nếu còn dương, không thì `sau ~/ 2`, và nếu hết chỗ thì
đánh số lại cả danh sách. Mọi nhánh cho ra số **≥ 1**.

Nên trên server, **mọi** `Priority <= 0` đều là một `null` bị ép, không phải thứ
người dùng đã sắp.

---

## 5. Việc cần làm

### 5.1. Giữ `null`

`sync.repository.js:105`:

```js
if (m.priority !== undefined) {
  m.priority = m.priority === null ? null : Number(m.priority);
}
```

Giá trị không phải số (`Number('abc')` là `NaN`) thì Prisma từ chối. Để lỗi ấy đi
qua nhánh ánh xạ ở `SYNC_PUSH_ERROR_MAPPING.md` mục 3.1, **đừng** lặng lẽ đổi nó
thành `null`.

### 5.2. Nhánh tạo mặc định `null`, không phải `1`

`sync.repository.js:477`:

```js
priority: mapped.priority !== undefined ? mapped.priority : null,
```

Client này luôn gửi khoá nên không đi vào nhánh `1`. Nhưng mọi nguồn tạo mục tiêu
khác sẽ gắn `1`, tức một mục tiêu "đã sắp" đứng trên mọi mục tiêu người dùng tự
sắp — trái quy ước NULL.

### 5.3. Tuỳ chọn — dọn hàng đã bị ép, **không** đổi `Update_at`

Chỉ chạy sau khi 5.1 đã lên:

```sql
SELECT COUNT(*) FROM goal WHERE "Priority" <= 0;           -- đo trước
UPDATE goal SET "Priority" = NULL WHERE "Priority" <= 0;
```

⚠️ **Đừng** đặt `"Update_at" = NOW()` trong câu này, dù làm thế thì lượt kéo về
tăng dần mới mang giá trị sửa tới máy. Đồng bộ là *ghi sau thắng*: một máy đang
giữ sửa đổi ngoại tuyến của mục tiêu ấy, với dấu thời gian cũ hơn lúc dọn, sẽ
nhận `conflict` và **mất** sửa đổi của người dùng. Không đổi `Update_at` thì máy
cũ chưa thấy giá trị sửa, nhưng client đã cứng hoá (mục 7) vốn đọc `0` như chưa
sắp, còn máy cài mới kéo toàn bộ thì nhận `NULL`.

Đo 2026-09-10: **1** hàng — chính mục tiêu thử ở mục 2, đã được xoá mềm qua
giao diện sau khi kiểm bản vá client.

---

## 6. Kiểm lại sau khi sửa

1. Tạo một mục tiêu mới trên client, không kéo thả, chờ một chu kỳ đồng bộ.
2. Truy vấn:
   ```sql
   SELECT "Name", "Priority" FROM goal
   WHERE "Idaccount" = <id> ORDER BY "Update_at" DESC LIMIT 3;
   ```
   Hàng mới phải có `Priority` là **NULL**.
3. Trên máy: mục tiêu mới vẫn đứng **cuối** sau khi đồng bộ.

Rồi báo lại ở đây.

---

## 7. Liên quan tới client

✅ Client đọc `priority <= 0` như `null` (chưa sắp) từ 2026-09-10, ở cả ba ranh
giới đọc, lưu kéo về và đẩy lên (`lib/features/goal/domain/uu_tien_hop_le.dart`)
— xem G32 `docs/CLIENT_APP_KNOWN_GAPS.md`. Làm thế sửa được **hiển thị** trên máy
đã cập nhật, nhưng không sửa giá trị trên server, và bản client cũ vẫn thấy mục
tiêu nhảy lên đầu. Nên 5.1 vẫn cần.
