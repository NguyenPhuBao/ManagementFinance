# 38 — Client tích hợp thanh toán PayOS: thông báo cách thi hành + xin ba trường nhỏ + năm chỗ hướng dẫn lệch mã

**Ngày:** 2026-10-06. **Người đặt:** Client-app (Trần Quang Đạt). **Mức:** thấp — **không chặn client**, mọi mục xin
đều có mặc định phía client. **Loại:** thông báo (mục 1) + xin nhẹ (mục 2–4) + sửa chữ (mục 3, 5).

Spec phía client: `docs/superpowers/specs/2026-10-06-premium-payos-client-design.md` (người dùng duyệt 2026-10-06).
Tài liệu client: `docs/PREMIUM_FEATURE.md`. Nguồn backend đã đọc: `docs/Payment/CLIENT_INTEGRATION_GUIDE.md`
(= `CAN-LAM/CLIENT_INTEGRATION_GUIDE.md`), `PAYOS_SETUP_GUIDE.md`, `api/payment.routes.js`,
`modules/payment/payment.service.js`, `modules/auth/auth.service.js`, `core/scheduler.service.js`.

---

## 1. Thông báo — client thi hành đặc quyền, backend không cần chặn

Người dùng chốt bốn đặc quyền Premium và cách thi hành:

| Đặc quyền | Basic | Thi hành ở |
|---|---|---|
| Ví | tối đa **3** ví đang hoạt động (chưa xoá, không lưu trữ) | client — `redirect` của `/wallets/add` |
| Ngân sách | tối đa **3** đang hoạt động (chưa xoá, chưa hết hạn) | client — `redirect` của `/budget/rules` (tạo mới) |
| Mục tiêu tiết kiệm | tối đa **3** đang hoạt động (chưa xoá, chưa đạt) | client — `redirect` của `/goals/add` |
| Trợ lý AI & Nhập nhanh bằng AI | khoá (màn mở, ô nhập khoá; ô Nhập nhanh khoá) | client |

- Người đã vượt trần (hạ cấp) **giữ nguyên** mọi thứ đang có, chỉ không tạo thêm. Backend **không cần** chặn gì ở
  `/sync/push`; chặn ở đó là bản ghi đã dùng bị kẹt hàng đợi đẩy (họ G31). Nếu backend muốn chặn thêm, báo client trước
  để thêm mã lỗi vĩnh viễn + đường gỡ.
- Đặc quyền *"đồng bộ đa thiết bị tức thì"* trong hướng dẫn **không thi hành** (người dùng chốt: đồng bộ giữ nguyên
  cho mọi tài khoản) → xin **bỏ chữ ấy** khỏi `CLIENT_INTEGRATION_GUIDE.md` mục 2; màn Nâng cấp của app không nhắc nó.
- Trạng thái gói phía client: cache `premiumExpiresAt` theo tài khoản, so **giờ máy**; làm mới khi đăng nhập, mở app
  (giãn 5 phút), khi socket `account.upgraded` tới (tín hiệu — client **không đọc payload**, gọi lại
  `/payment/subscription-info`), sau khi đơn `PAID`. Chấp nhận: lùi giờ máy khi offline kéo dài được Premium tới lần
  online kế — scheduler của backend vẫn hạ cấp đúng.

## 2. Xin thêm ba trường vào `GET /api/payment/subscription-info` (có mặc định, client không chờ)

```json
{
  "accountType": "Basic",
  "premiumExpiresAt": null,
  "daysRemaining": 0,
  "isExpired": true,
  "limits": { "wallets": 3, "budgets": 3, "goals": 3 },
  "price": 49000,
  "packageDays": 30
}
```

- `limits`: trần Basic — client hiện ghi cứng 3/3/3 (`TranGoi.macDinh`), có trường thì đè theo từng ô (ô thiếu / không
  dương → mặc định). Đổi trần sau này không cần phát hành app.
- `price`, `packageDays`: client hiện ghi cứng 49.000 / 30 (`kGiaPremium`, `kSoNgayGoi`) — khớp `PREMIUM_PRICE_VND`,
  `PREMIUM_PACKAGE_DAYS` của `.env`; có trường thì đè. Nguồn gợi ý: `process.env` đang dùng ở `payment.service.js`.
- Không đổi gì khác; thiếu cả ba thì client chạy như hiện tại.

## 3. Năm chỗ `CLIENT_INTEGRATION_GUIDE.md` lệch mã (client đã làm theo MÃ) — xin sửa chữ

| # | Hướng dẫn nói | Mã thật | Chỗ |
|---|---|---|---|
| 1 | Client nghe socket `payment.success` | Sự kiện tới room `account_<id>` là **`account.upgraded`** `{type, premiumExpiresAt}` (`payment.service.js:167-171`, `emitToAccount`); `payment.success` chỉ đi EventBus, không module nào phát ra socket | mục 3 / 6 |
| 2 | Trả xong quay về app | `PAYOS_RETURN_URL` / `CANCEL_URL` trỏ **web Admin** (`managementfinance-admin.vercel.app/payment/…`) — người dùng app tự quay lại, app phát hiện qua `resumed` + socket + `order-status`. Xem mục 4 | mục 5 |
| 3 | Base URL `http://localhost:10000` | Dev chạy **3000** (`npm run dev`) | mục 4, ví dụ mã |
| 4 | Mẫu Flutter dùng `package:http` + `url_launcher` | Client dùng **Dio** (`sl<DioClient>().dio`, `AuthInterceptor` gắn token); `url_launcher` **đã thêm** 2026-10-06 (một tệp import) | mục 5 |
| 5 | `/subscription-info` trả `type` | Trả **`accountType`** (`payment.service.js:235`) — client đọc `accountType ?? type` | mục 4.3 |

## 4. Tuỳ chọn — trang "quay lại ứng dụng" sau khi trả (client không phụ thuộc)

Return URL hiện đưa người dùng app sang web Admin. Nếu rẻ: một trang tĩnh trung lập *"Thanh toán xong — quay lại
FlowMoney"* (hoặc deep link `flowmoney://premium/xong`) làm `PAYOS_RETURN_URL` cho đơn tạo từ app (vd. theo
`x-client-platform` hoặc một trường trong body `create-order`). Client đã bắt được trạng thái bằng ba đường nên **không
cần** mục này để chạy.

## 5. Nghiệm thu phía client (để backend biết đường thử)

Sandbox PayOS trên dev (`PAYOS_SETUP_GUIDE.md` bước 1 chế độ Thử nghiệm): người dùng dán khoá vào `.env`; áp
`database/19` + `prisma generate` (client xin phép đích danh); webhook qua ngrok hoặc tự ký HMAC bằng checksum key và
POST vào `localhost:3000/api/payment/webhook`. Kết quả ghi ở `docs/PREMIUM_FEATURE.md` mục nghiệm thu.

⚠️ Bẫy đã vấp 2026-10-06: `npm install` ở `src/Backend` tự `prisma generate` (`postinstall`) → client Prisma đòi
`account.premium_expires_at` khi CSDL dev **chưa áp** `database/19` → mọi truy vấn `account` vỡ `P2022`, kể cả đăng
nhập. Đề nghị ghi vào `PAYOS_SETUP_GUIDE.md`: *áp `database/19` TRƯỚC `npm install`* (hoặc `postinstall` kiểm cột).
