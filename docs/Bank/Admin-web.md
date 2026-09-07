# Đặc Tả Kỹ Thuật Module Admin-web — Theo Dõi & Giám Sát SePay Cá Nhân

Tài liệu này quy định chi tiết toàn bộ các hạng mục công việc, kiến trúc mã nguồn, quy chuẩn API, giao diện người dùng và các lưu ý vận hành trên môi trường **Cloud** để Module **Admin-web** theo dõi, giám sát và quản trị hệ thống giao dịch ngân hàng tích hợp qua **SePay Cá Nhân (`my.sepay.vn`)** đồng bộ với Module Backend.

---

## 1. Tổng Quan Kiến Trúc & Vai Trò Của Admin-web

### 1.1. Luồng Dữ Liệu Trong Hệ Thống Quản Trị
Module Admin-web đóng vai trò là trung tâm giám sát (Monitoring & Administration Dashboard) cho toàn bộ hoạt động tài chính, ngân hàng và Webhook trong hệ sinh thái FlowMoney:

```
[Tài Khoản SePay Cá Nhân (my.sepay.vn)]
         │ (Webhook IPN - Realtime < 2s)
         ▼
  [Backend Cloud (Render)] ◄──── Socket.io (Realtime Events) ────► [Admin-web Cloud]
  (PostgreSQL / Redis)     ◄──── REST API (Admin Authentication) ──► (React / Vite / Tailwind)
```

> [!IMPORTANT]
> **Nguyên tắc phân tầng bảo mật:**
> 1. **Admin-web KHÔNG nhận Webhook trực tiếp từ SePay:** Webhook IPN từ SePay chứa dữ liệu biến động số dư nhạy cảm và bắt buộc phải qua bước xác thực API Key, ghi nhận cơ sở dữ liệu và xử lý hàng đợi (BullMQ) tại **Backend Cloud**.
> 2. **Admin-web tương tác với Backend Cloud:** Mọi dữ liệu về tài khoản ngân hàng, biến động số dư, nhật ký Webhook và chỉ số phân tích đều được Backend Cloud cung cấp thông qua REST API bảo vệ bởi JWT (Role Admin: `idrole = 1`) và Socket.io.

---

## 2. Các Hạng Mục Cần Thực Hiện Tại Source Code Admin-web

### 2.1. Cấu Hình Biến Môi Trường (`.env` & `.env.production`)
Cập nhật file cấu hình môi trường để kết nối với Backend Cloud trên Render:

```env
# ==============================================================================
# BACKEND API & WEBSOCKET CONFIGURATION (RENDER CLOUD / PRODUCTION)
# ==============================================================================
VITE_API_BASE_URL=https://managementfinance.onrender.com/api
VITE_SOCKET_URL=https://managementfinance.onrender.com

# Thời gian tự động làm mới dữ liệu giám sát (milliseconds)
VITE_MONITOR_POLL_INTERVAL=30000
```

---

### 2.2. Xây Dựng Service API Tương Tác Backend (`src/Admin-web/src/api/bankAdminApi.js`)
Tạo module API chuyên biệt cho quản trị ngân hàng:

```javascript
import axiosClient from './axiosClient';

const bankAdminApi = {
  // 1. Thống kê tổng quan Module Bank
  getBankOverviewStats: () => {
    return axiosClient.get('/admin/bank/overview');
  },

  // 2. Danh sách tất cả tài khoản ngân hàng người dùng đã khai báo trong hệ thống
  getAllBankAccounts: (params) => {
    // params: { page, limit, status, gateway, search }
    return axiosClient.get('/admin/bank/accounts', { params });
  },

  // 3. Chi tiết một tài khoản ngân hàng (kèm ví Banking và lịch sử giao dịch)
  getBankAccountDetail: (idBankAccount) => {
    return axiosClient.get(`/admin/bank/accounts/${idBankAccount}`);
  },

  // 4. Ngắt/Xóa tài khoản ngân hàng (Hỗ trợ người dùng khi có tranh chấp/yêu cầu)
  unlinkBankAccount: (idBankAccount, reason) => {
    return axiosClient.post(`/admin/bank/accounts/${idBankAccount}/unlink`, { reason });
  },

  // 5. Nhật ký biến động số dư từ SePay (BankSync Transactions)
  getBankTransactions: (params) => {
    // params: { page, limit, status, transfer_type, gateway, fromDate, toDate }
    return axiosClient.get('/admin/bank/transactions', { params });
  },

  // 6. Giám sát nhật ký Webhook IPN từ SePay
  getWebhookLogs: (params) => {
    // params: { page, limit, status_code, gateway }
    return axiosClient.get('/admin/bank/webhooks', { params });
  },

  // 7. Thử lại (Retry) xử lý một Webhook bị lỗi
  retryWebhook: (idWebhookLog) => {
    return axiosClient.post(`/admin/bank/webhooks/${idWebhookLog}/retry`);
  },
};

export default bankAdminApi;
```

---

### 2.3. Xây Dựng Màn Hình Quản Trị & Giám Sát

#### A. Màn Hình Quản Lý Tài Khoản Ngân Hàng (`/admin/bank-accounts`)
* **Vị trí file:** `src/Admin-web/src/pages/bank/BankAccountListPage.jsx`
* **Chức năng chính:**
  1. **Bảng dữ liệu (Data Table):**
     * **Người dùng:** Tên hiển thị, Email, User ID (`idaccount`).
     * **Ngân hàng & Số tài khoản:** Tên ngân hàng (`bank_name`), Số tài khoản (`account_number`), Tên chủ tài khoản (`account_name`).
     * **Ví liên kết:** Tên ví (`type = 'Banking'`), ID ví (`idwallet`).
     * **Số dư hiện tại:** Định dạng tiền tệ VND (`balance`), phản ánh số dư thực tế từ ngân hàng.
     * **Trạng thái:** `ACTIVE` (Đang hoạt động), `DISCONNECTED` (Đã ngừng đồng bộ).
     * **Ngày khai báo:** Thời gian khai báo lần đầu và thời điểm nhận giao dịch gần nhất.
  2. **Bộ lọc & Tìm kiếm:**
     * Lọc theo cổng ngân hàng (Vietcombank, MBBank, Techcombank, ACB, BIDV...).
     * Lọc theo trạng thái kết nối.
     * Ô tìm kiếm theo Tên người dùng, Email, Số tài khoản.
  3. **Hành động:**
     * Xem chi tiết tài khoản và lịch sử giao dịch.
     * Nút **"Ngắt kết nối" (Disconnect)** khi cần vô hiệu hóa tài khoản.

#### B. Màn Hình Giám Sát Biến Động Số Dư SePay (`/admin/bank-transactions`)
* **Vị trí file:** `src/Admin-web/src/pages/bank/BankTransactionListPage.jsx`
* **Chức năng chính:**
  1. **Hiển thị luồng giao dịch đồng bộ từ SePay (`Provider = 'BankSync'`):**
     * **Mã giao dịch:** `bank_tran_id` (Mã tham chiếu FT của ngân hàng hoặc ID SePay).
     * **Số tiền:** Hiển thị màu xanh lá `+` đối với `Thu` (Tiền vào), màu đỏ cam `-` đối với `Chi` (Tiền ra).
     * **Nội dung chuyển khoản:** Chuỗi thông tin thô do ngân hàng gửi về (`note`/`content`).
     * **Thời gian giao dịch:** Thời điểm phát sinh tại ngân hàng (`date_transaction`).
     * **Phân loại AI:** Danh mục do AI tự động gán (`category_name`) kèm độ tin cậy.
     * **Trạng thái xử lý:**
       * `Pending` (Chờ người dùng xác nhận trên Client-app).
       * `Confirmed` (Người dùng đã xác nhận, số dư ví đã ghi nhận).
       * `Rejected` (Người dùng từ chối / loại khỏi chi tiêu).
  2. **Modal chi tiết giao dịch (Inspect Payload):**
     * Xem toàn bộ JSON Payload gốc do SePay Cá Nhân gửi về để phục vụ kiểm toán và tra soát lỗi.

#### C. Màn Hình Giám Sát Webhook IPN (`/admin/bank-webhooks`)
* **Vị trí file:** `src/Admin-web/src/pages/bank/BankWebhookLogPage.jsx`
* **Chức năng chính:**
  1. **Nhật ký Webhook thời gian thực:**
     * Hiển thị danh sách các Webhook SePay bắn về Backend Render: Request ID, Gateway, Timestamp, HTTP Status Code (`200 OK`, `401 Unauthorized`, `500 Internal Error`).
     * Thời gian Backend xử lý (`execution_time_ms`).
     * Trạng thái job trong hàng đợi BullMQ.
  2. **Cơ chế Re-deliver / Retry:**
     * Nếu có Webhook bị xử lý thất bại (lỗi mạng, timeout), Admin có thể bấm **"Retry"** để Backend đẩy lại job vào hàng đợi Redis xử lý lại.

#### D. Bảng Điều Khiển Dashboard Tích Hợp Chỉ Số Bank (`/admin/dashboard`)
* **Vị trí file:** `src/Admin-web/src/pages/dashboard/DashboardPage.jsx`
* **Bổ sung các Widget thống kê ngân hàng:**
  1. **KPI Cards:**
     * Tổng số tài khoản ngân hàng đang khai báo (`Active Accounts`).
     * Tổng giá trị dòng tiền biến động qua BankSync trong 24h / 30 ngày.
     * Tỷ lệ người dùng xác nhận giao dịch AI (`AI Acceptance Rate`).
     * Tỷ lệ Webhook thành công (`Webhook Success Rate 99.9%`).
  2. **Biểu đồ thị phần ngân hàng:**
     * Pie chart trực quan hóa tỷ lệ người dùng liên kết các ngân hàng (MBBank chiếm bao nhiêu %, Vietcombank bao nhiêu %...).
  3. **Biểu đồ lưu lượng giao dịch theo giờ:**
     * Theo dõi các khung giờ cao điểm phát sinh giao dịch chi tiêu để giám sát tải hệ thống Backend Cloud.

---

### 2.4. Tích Hợp Realtime Socket.io Cho Admin (`src/Admin-web/src/hooks/useBankSocket.js`)

Custom Hook giúp Admin-web nhận thông báo biến động tức thì từ Backend Cloud:

```javascript
import { useEffect } from 'react';
import { io } from 'socket.io-client';
import { toast } from 'react-toastify';

export const useBankSocket = (onNewTransaction, onWebhookFailure) => {
  useEffect(() => {
    const socketUrl = import.meta.env.VITE_SOCKET_URL || 'https://managementfinance.onrender.com';
    const token = localStorage.getItem('admin_token');

    const socket = io(socketUrl, {
      auth: { token },
      transports: ['websocket'],
    });

    socket.on('connect', () => {
      // Tham gia phòng giám sát của Admin
      socket.emit('join_admin_room');
    });

    // Lắng nghe khi có giao dịch SePay mới vừa bắn qua Webhook
    socket.on('admin.bank_transaction_created', (data) => {
      toast.info(`Giao dịch ngân hàng mới: ${Number(data.amount).toLocaleString()} đ (${data.gateway || 'Bank'})`);
      if (onNewTransaction) onNewTransaction(data);
    });

    // Cảnh báo ngay lập tức nếu có Webhook bị lỗi
    socket.on('admin.webhook_error', (errorData) => {
      toast.error(`[CẢNH BÁO] Webhook SePay lỗi: ${errorData.message}`);
      if (onWebhookFailure) onWebhookFailure(errorData);
    });

    return () => {
      socket.disconnect();
    };
  }, [onNewTransaction, onWebhookFailure]);
};
```

---

### 2.5. Cập Nhật Router và Menu Điều Hướng (`src/Admin-web/src/router/routes.jsx`)

Thêm các routes mới vào hệ thống định tuyến của Admin-web:

```jsx
import BankAccountListPage from '../pages/bank/BankAccountListPage';
import BankTransactionListPage from '../pages/bank/BankTransactionListPage';
import BankWebhookLogPage from '../pages/bank/BankWebhookLogPage';

// Trong routes array:
{
  path: '/bank/accounts',
  element: <BankAccountListPage />,
},
{
  path: '/bank/transactions',
  element: <BankTransactionListPage />,
},
{
  path: '/bank/webhooks',
  element: <BankWebhookLogPage />,
},
```

---

## 3. Các Lưu Ý Kỹ Thuật Khi Triển Khai Admin-web Lên Cloud

1. **Đồng Bộ HTTPS & WSS:**
   * Admin-web chạy trên Vercel / Netlify (`https://admin.flowmoney.io`).
   * Bắt buộc gọi Backend Render qua HTTPS (`https://managementfinance.onrender.com/api`) và WebSocket bảo mật (`wss://managementfinance.onrender.com`).
2. **Cấu Hình CORS Tại Backend:**
   * Backend Cloud (`src/Backend/config/index.js`) cần thêm domain Admin-web vào whitelist CORS.
3. **Phân Quyền Quản Trị (RBAC):**
   * Toàn bộ API `/admin/bank/*` chỉ cấp quyền cho tài khoản Admin (`idrole = 1`).
4. **Bảo Vệ Khóa Bí Mật:**
   * `SEPAY_WEBHOOK_API_KEY` chỉ được lưu trên Backend Render, tuyệt đối không đặt trên Admin-web frontend.

---

## 4. Checklist Kiểm Thử & Nghiệm Thu Cho Admin-web

- [ ] **Kết nối API Cloud:** Admin-web gọi thành công các endpoint `/admin/bank/*` trên Render Cloud.
- [ ] **Hiển thị danh sách tài khoản:** Hiển thị chính xác các tài khoản ngân hàng người dùng đã khai báo kèm số dư.
- [ ] **Theo dõi biến động số dư:** Danh sách giao dịch `BankSync` hiển thị đầy đủ số tiền, ngày giờ, nội dung, danh mục AI và trạng thái.
- [ ] **Giám sát Webhook:** Hiển thị log các lần SePay bắn IPN về Backend, kiểm tra mã HTTP status và payload.
- [ ] **Socket Realtime:** Khi có giao dịch SePay bắn về Backend, màn hình Admin-web tự động hiển thị Toast thông báo mà không cần F5.
- [ ] **Phân quyền bảo mật:** Người dùng không có quyền Admin (`idrole != 1`) bị chặn truy cập màn hình Bank Admin.
