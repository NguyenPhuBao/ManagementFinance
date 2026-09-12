# `/auth/profile` trả `countdown`, và gỡ `pendingDeleteCancelled` khỏi response đăng nhập

**Ngày:** 2026-09-11 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** việc 1 —
một dòng ở `modules/auth/auth.repository.js` và một dòng ở `modules/auth/auth.service.js`;
việc 2 — hai dòng ở `auth.service.js`. Không migration, không đổi CSDL.

> Đo trên nhánh `TranQuangDat` sau khi gộp `main` @ `cc65f4f` (mã backend trùng `main`).
> Spec phía client: `docs/superpowers/specs/2026-09-10-cuong-che-dang-xuat-va-cho-xoa-design.md`
> §4.2, §4.3, §6. Client sửa G33 cùng ngày.

---

## 1. Tóm tắt

| | Xin gì | Vì sao | Mức |
|---|---|---|---|
| **1** | `GET /auth/profile` trả thêm `countdown` | Máy **đã giữ phiên** từ trước khi máy khác gửi yêu cầu xoá chỉ thấy `status` qua `/auth/profile`, không biết số ngày còn lại — thẻ nhắc chỉ hiện câu chung (§2.1). Cùng triệu chứng: bộ nhớ đệm do bản client cũ ghi, thiếu mốc nhận; còn máy giữ số của một lần chờ xoá trước thì hiện số cũ sai (§2.4). Đăng nhập máy khác hay cài lại app thì **có** số: response đăng nhập mang `countdown` | 🟡 |
| **2** | Gỡ `pendingDeleteCancelled` khỏi response `POST /auth/login` | Luôn `false` — di sản của đặc tả "đăng nhập lại là tự khôi phục" đã bỏ; client đã gỡ phía đọc | ⚪ |

## 2. Việc 1 — `countdown` ở `/auth/profile`

### 2.1. Đo được

- `auth.repository.js:219-235` — `getProfile` chọn `username, status, type, idrole, role`
  của `account`, **không** có `countdown`. (`formatUser` trải `...user` nên trường nào
  được chọn thì đi tiếp.)
- `auth.service.js:552-566` — `getProfile` trả `status` nhưng không `countdown`.

Số ngày hôm nay chỉ tới client qua `POST /auth/login` (`auth.service.js:367`) và
`DELETE /auth/account` (`:526`). JWT có `countdown` nhưng là số **lúc cấp**, và
`/auth/refresh` cấp lại đúng payload cũ. Client tự đếm lùi từ mốc nhận theo ngày lịch
UTC+7 (khớp `scheduler.service.js` trừ 1 lúc 00:00 giờ Việt Nam) — nhưng máy chỉ thấy
`status = 'PendingDelete'` qua `/auth/profile` thì không có mốc nào để đếm.

### 2.2. Sửa

`auth.repository.js`, trong `getProfile`:
```js
        account: {
          select: {
            username: true,
            status: true,
            countdown: true,
            type: true,
            idrole: true,
            role: { select: { rolename: true } },
          },
        },
```
`auth.service.js`, trong đối tượng `getProfile` trả về, ngay dưới `status`:
```js
      countdown: user.account?.countdown ?? null,
```

### 2.3. Kiểm lại

1. Tài khoản đang chờ xoá: `GET /api/auth/profile` → `data.countdown` là số nguyên, bằng
   `SELECT "Countdown" FROM "account" WHERE "Idaccount" = <id>;`
2. Tài khoản `Active`: `data.countdown` là `null`.

### 2.4. Client làm gì sau đó

`AuthRepositoryImpl._dongBoTrangThai` (client) hiện đặt `countdown = null` khi server báo
`PendingDelete` mà máy chưa biết, và **giữ nguyên** số đang có khi trạng thái khớp. Có
trường này thì mỗi lần `/auth/profile` trả `countdown`, client ghi lại **số và mốc nhận,
kể cả khi trạng thái khớp**. Việc ấy cứu cả ba ca thẻ nhắc hôm nay thiếu số hoặc sai số:

- máy đã giữ phiên từ trước khi máy khác gửi yêu cầu xoá — không có số (§2.1);
- bộ nhớ đệm do bản client cũ ghi — có `countdown` nhưng thiếu `countdown_nhan_luc`, nên
  thẻ chỉ hiện câu chung;
- **số cũ sai** — máy giữ số của một lần chờ xoá trước; máy khác huỷ rồi gửi lại yêu cầu;
  lần mở app sau `status` vẫn khớp nên máy giữ số cũ và hiện **ít** ngày hơn thật.

Vẫn là việc phía client — backend không phải làm thêm.

## 3. Việc 2 — `pendingDeleteCancelled`

`auth.service.js:309` khai `let pendingDeleteCancelled = false;`, không chỗ nào gán lại,
và `:356` trả nó trong response đăng nhập. Client đã gỡ phía đọc (2026-09-11). Xin gỡ hai
dòng ấy. `docs/Rule_Project/Rule_project.md` (dòng 650 trên `main`) đã mô tả đúng hành vi
hiện tại — *"Gửi yêu cầu xoá không thu hồi token — người dùng dùng tiếp trong 30 ngày"* —
không phải sửa.

## 4. Liên quan

- Không phụ thuộc CAN-LAM 17: `/auth/profile` đi qua `authenticate`, chỗ đang chạy đúng.
- Admin-web đọc `countdown` qua `api/admin.api` (danh sách và chi tiết người dùng), không
  qua `/auth/profile`; không nơi nào trong `src/Admin-web/src` đọc `pendingDeleteCancelled`
  (dò chỉ đọc 2026-09-11). Việc 2 không đụng tới Admin-web.
