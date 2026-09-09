# Đặc Tả Kỹ Thuật Module Client-app — Khai Báo Tài Khoản Ngân Hàng & Nhận Giao Dịch Realtime (SePay Cá Nhân)

Tài liệu này quy định chi tiết toàn bộ các hạng mục công việc, kiến trúc mã nguồn, màn hình giao diện (UI/UX), quy chuẩn dữ liệu và các lưu ý vận hành trên nền tảng **Flutter (Client-app)** để hoàn thiện chức năng **Khai Báo Tài Khoản Ngân Hàng** và **Nhận Giao Dịch Biến Động Số Dư Thời Gian Thực** thông qua hệ thống **SePay Cá Nhân (`my.sepay.vn`)**.

---

## 1. Tổng Quan Trải Nghiệm Người Dùng & Kiến Trúc Mobile

### 1.1. Bản Chất Mô Hình Tích Hợp
* **Bảo Mật Tuyệt Đối (Zero Credential Risk):** 
  * Ứng dụng **hoàn toàn KHÔNG yêu cầu** người dùng nhập Tên đăng nhập, Mật khẩu Internet Banking hay mã OTP ngân hàng.
  * Người dùng chỉ khai báo các thông tin tài khoản công khai: **Số tài khoản**, **Tên ngân hàng**, **Tên chủ tài khoản**.
  * Chủ hệ thống (Admin / Sinh viên) đã liên kết sẵn tài khoản ngân hàng thực trên Dashboard SePay Cá Nhân ([my.sepay.vn](https://my.sepay.vn)) và cài đặt Webhook trỏ về Backend Render Cloud.
* **Đồng Bộ Dòng Tiền Tự Động:**
  * Khi phát sinh giao dịch chuyển khoản thực tế tại ngân hàng, SePay cá nhân bắn Webhook IPN về Backend Render.
  * Backend tự động đối soát `account_number` $\rightarrow$ Phát Socket.io tức thì tới đúng điện thoại của người dùng đó (độ trễ < 2 giây).
  * Điện thoại rung, chuông báo tiền về kèm gợi ý danh mục chi tiêu từ AI.

---

### 1.2. Luồng Vận Hành Tổng Thể

```
[Người dùng Client-app]
         │ (1) Vào "Thêm ví ngân hàng"
         │     Nhập: STK, Tên NH, Tên chủ thẻ, Số dư ban đầu
         ▼
[Backend Cloud (Render)] ──(2) POST /api/bank/register-account
         │                     Lưu CSDL bank_account & sinh Ví Banking
         ▼
[Người Dùng Có Giao Dịch Ngân Hàng Thực Tế]
         │ (Chuyển khoản / Nhận tiền vào tài khoản)
         ▼
[Hệ thống SePay Cá Nhân (my.sepay.vn)]
         │ (3) Webhook IPN (< 2 giây)
         ▼
[Backend Cloud (Render)] ──(4) Worker BullMQ xử lý & AI Classify
         │
         ▼ (5) Socket.io Realtime Push (bank_transaction.incoming)
[Client-app UI]
  - Rung & Chuông báo tiền về
  - Hiện Toast Banner trên đầu màn hình
  - Cập nhật Hộp Thư Giao Dịch Chờ Duyệt (Pending Inbox)
```

---

## 2. Các Hạng Mục Cần Thực Hiện Tại Source Code Client-app

### 2.1. Bổ Sung Dependencies Trong `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter

  # ... các dependencies hiện có (flutter_bloc, drift, dio, go_router...) ...

  # 1. Kết nối WebSocket thời gian thực nhận biến động số dư từ Backend Cloud
  socket_io_client: ^3.0.2

  # 2. Thông báo nổi in-app khi có tiền vào/ra
  overlay_support: ^2.1.0

  # 3. Rung phản hồi xúc giác
  vibration: ^2.0.0
```

> [!NOTE]
> Mô hình SePay Cá Nhân **không cần `webview_flutter`** vì người dùng không phải mở WebView đăng nhập Internet Banking, giúp giảm dung lượng ứng dụng và tăng tính an toàn bảo mật.

---

### 2.2. Xây Dựng Màn Hình Khai Báo Tài Khoản Ngân Hàng (`BankRegisterPage`)

#### A. Service API Client (`src/Client-app/lib/features/bank/data/bank_api_service.dart`)

```dart
import 'package:dio/dio.dart';

class BankApiService {
  final Dio dio;
  BankApiService(this.dio);

  /// Người dùng khai báo tài khoản ngân hàng để liên kết ví
  Future<Map<String, dynamic>> registerBankAccount({
    required String accountNumber,
    required String bankName,
    required String accountName,
    double balance = 0,
  }) async {
    final response = await dio.post(
      '/api/bank/register-account',
      data: {
        'account_number': accountNumber,
        'bank_name': bankName,
        'account_name': accountName,
        'balance': balance,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.data['data'];
    }
    throw Exception(response.data['message'] ?? 'Lỗi khai báo tài khoản ngân hàng');
  }

  /// Lấy danh sách tài khoản ngân hàng của người dùng
  Future<List<dynamic>> getBankAccounts() async {
    final response = await dio.get('/api/bank/accounts');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data['data'] as List<dynamic>;
    }
    throw Exception('Lỗi tải danh sách tài khoản ngân hàng');
  }

  /// Lấy danh sách giao dịch ngân hàng đang chờ duyệt
  Future<List<dynamic>> getPendingTransactions() async {
    final response = await dio.get('/api/bank/pending-transactions');
    if (response.statusCode == 200 && response.data['success'] == true) {
      return response.data['data'] as List<dynamic>;
    }
    throw Exception('Lỗi tải giao dịch chờ duyệt');
  }

  /// Xác nhận duyệt giao dịch ngân hàng
  Future<void> confirmTransaction(String idtran, {String? idcategory, String? note}) async {
    await dio.post('/api/bank/confirm-transaction', data: {
      'idtran': idtran,
      'idcategory': idcategory,
      'note': note,
    });
  }

  /// Từ chối giao dịch ngân hàng
  Future<void> rejectTransaction(String idtran) async {
    await dio.post('/api/bank/reject-transaction', data: {
      'idtran': idtran,
    });
  }
}
```

#### B. Giao Diện Người Dùng (`BankRegisterPage.dart`)
* **Vị trí file:** `src/Client-app/lib/features/bank/presentation/pages/bank_register_page.dart`
* **Form nhập liệu trực quan & an toàn:**
  1. **Chọn Ngân Hàng:** Dropdown danh sách ngân hàng kèm Logo nhận diện (Vietcombank, MBBank, Techcombank, ACB, VPBank, TPBank, BIDV...).
  2. **Số Tài Khoản:** Trường nhập số tài khoản ngân hàng (bàn phím số).
  3. **Tên Chủ Tài Khoản:** Trường nhập tên chủ tài khoản (tự động chuyển in hoa không dấu: `NGUYEN PHU BAO`).
  4. **Số Dư Ban Đầu (Tùy chọn):** Nhập số dư hiện tại của tài khoản.
  5. **Nút "Khai Báo & Tạo Ví Banking":**
     * Gọi `registerBankAccount` $\rightarrow$ Backend lưu vào `bank_account` và sinh ví `wallet` (`type = 'Banking'`).
     * Hiển thị thông báo thành công $\rightarrow$ Chuyển về màn hình Danh sách ví.

---

### 2.3. Quy Tắc Nghiệp Vụ Ví `Banking` Trên Client-app (Bắt Buộc)

Mỗi tài khoản ngân hàng được khai báo sẽ tương ứng với một ví có `type = 'Banking'`. Client-app **bắt buộc tuân thủ 3 nguyên tắc bảo vệ dữ liệu:**

> [!CAUTION]
> **QUY TẮC BẢO TOÀN SỐ DƯ VÍ BANKING:**
> 1. **Khóa sửa số dư thủ công:** Nút "Chỉnh sửa số dư" trên chi tiết ví `Banking` phải bị ẩn hoặc vô hiệu hóa. Số dư chỉ được biến động từ ngân hàng.
> 2. **Khóa đổi tên & đổi loại ví:** Cố định tên ví theo dạng `[Tên NH] - [Số TK]`.
> 3. **Chặn tạo giao dịch thủ công vào ví Banking:**
>    * Trong màn hình **"Tạo giao dịch mới" (Create Transaction Form)**: Dropdown chọn nguồn tiền thanh toán phải **ẨN hoặc VÔ HIỆU HÓA** các ví có `type == 'Banking'`.
>    * Tooltip cảnh báo: *"Tài khoản ngân hàng chỉ tự động ghi nhận biến động qua chuyển khoản thực tế, quét hóa đơn ORC hoặc SMS."*

---

### 2.4. Nhận Biến Động Số Dư Thời Gian Thực (Socket.io)

> ⚠️ **Mục này là bản thiết kế cũ, KHÔNG khớp mã đang chạy (soát 2026-09-09).**
> Client đã nối Socket.io thật, nhưng ở `lib/core/realtime/` chứ **không** phải
> `lib/core/services/socket_service.dart`; nó **không** emit `join_account`
> (backend đã gỡ, room suy từ JWT), **tắt** cơ chế nối lại của thư viện để tự
> làm backoff có đọc lại token, và **không đọc trường nào** trong payload. Xem
> `docs/superpowers/specs/2026-09-09-socket-io-realtime-channel-design.md`.
> Đoạn mã bên dưới giữ nguyên làm bối cảnh của mảng Ngân hàng — **đừng chép
> nó**.

#### A. Socket Service (`src/Client-app/lib/core/services/socket_service.dart`)
Duy trì kết nối WebSocket liên tục với Backend Render Cloud:

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  IO.Socket? _socket;
  final String backendSocketUrl = 'https://managementfinance.onrender.com';

  void connect(String accessToken, int idaccount) {
    _socket = IO.io(
      backendSocketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket?.onConnect((_) {
      print('>>> [Socket] Đã kết nối thành công tới Backend Render');
      // Tham gia phòng riêng của tài khoản để nhận biến động
      _socket?.emit('join_account', idaccount);
    });

    _socket?.onDisconnect((_) {
      print('>>> [Socket] Mất kết nối tới Backend Render');
    });
  }

  /// Lắng nghe sự kiện biến động số dư ngân hàng từ SePay
  void onBankTransactionIncoming(Function(Map<String, dynamic> data) callback) {
    _socket?.on('bank_transaction.incoming', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
```

#### B. Phản Hồi Trực Quan Khi Có Tiền Về
Khi nhận được sự kiện `bank_transaction.incoming`:
1. **Phản hồi xúc giác & Âm thanh:**
   * Kích hoạt rung `HapticFeedback.mediumImpact()`.
   * Phát âm thanh chuông thông báo (sound effect "Ting ting").
2. **In-App Toast Banner (Hiện trên đầu màn hình):**
   * **Tiền vào (+):** *"Biến động số dư: +50,000 đ từ MBBank - Gợi ý AI: Thu nhập khác"* (Nền xanh lá).
   * **Tiền ra (-):** *"Biến động số dư: -45,000 đ tại Highlands Coffee - Gợi ý AI: Ăn uống"* (Nền đỏ cam).
3. **Cập nhật Badge Hộp Thư:** Hiển thị chấm đỏ thông báo có giao dịch chờ duyệt trên Tab Ví và Icon Chuông.

---

### 2.5. Màn Hình Hộp Thư Giao Dịch Chờ Duyệt (Bank Transaction Inbox)

* **Vị trí file:** `src/Client-app/lib/features/bank/presentation/pages/bank_inbox_page.dart`
* **Mục đích:** Người dùng kiểm tra và xác nhận các giao dịch do SePay tự động bắt được từ ngân hàng trước khi đưa vào báo cáo tài chính cá nhân.

#### A. Cấu Trúc Thẻ Giao Dịch Chờ Duyệt (Pending Transaction Card)
* **Header:** Logo ngân hàng, Tên ngân hàng, Số tài khoản rút gọn (`**** 8888`).
* **Số tiền:** Hiển thị màu xanh lá `+ 50,000 đ` (Tiền vào) hoặc màu đỏ `- 45,000 đ` (Tiền ra).
* **Nội dung ngân hàng:** Chuỗi tin nhắn chuyển khoản gốc (ví dụ: *"NGUYEN VAN A chuyen tien an toi"*).
* **Thời gian giao dịch:** Ngày giờ phát sinh tại ngân hàng.
* **Gợi ý phân loại AI (AI Category Suggestion):**
  * Hiển thị danh mục AI tự động gán (Ví dụ: `Ăn uống` 🍜).
  * Kèm nhãn: `AI gợi ý: Ăn uống (95% tin cậy)`.
  * Cho phép người dùng bấm vào để đổi danh mục khác nếu muốn.
* **2 Nút Thao Tác Trực Tiếp:**
  * **Nút "Xác nhận" (Confirm):**
    * Gọi API `confirmTransaction(idtran, idcategory)`.
    * Giao dịch chuyển sang `Confirmed`, số dư ví Banking được chốt, đồng bộ vào cơ sở dữ liệu Drift SQLite.
  * **Nút "Bỏ qua" (Reject):**
    * Gọi API `rejectTransaction(idtran)`.
    * Giao dịch chuyển sang `Rejected` (không tính vào chi tiêu hay ngân sách).

---

### 2.6. Đồng Bộ Dữ Liệu Ngoại Tuyến (Offline & Reconnect)

1. **Khi thiết bị Offline (Mất mạng):**
   * Người dùng vẫn xem được danh sách ví Banking và lịch sử giao dịch đã lưu trong Drift SQLite.
   * Chặn không cho khai báo tài khoản ngân hàng mới khi không có mạng.
2. **Khi thiết bị Online trở lại:**
   * Socket.io tự động reconnect tới Render Cloud (`autoConnect`).
   * Tự động gọi API `getPendingTransactions()` để tải bù toàn bộ các giao dịch ngân hàng phát sinh trong lúc mất mạng hoặc app bị tắt.

---

## 3. Checklist Kiểm Thử & Nghiệm Thu Cho Client-app

- [ ] **Khai báo tài khoản ngân hàng:** Form nhập STK, Tên NH, Tên chủ thẻ hoạt động trơn tru; gửi request thành công và tự tạo ví `Banking`.
- [ ] **Bảo mật tuyệt đối:** Ứng dụng không bao giờ yêu cầu mật khẩu Internet Banking hay mã OTP ngân hàng.
- [ ] **Khóa sửa số dư ví Banking:** Không có nút sửa số dư tay; dropdown tạo giao dịch thủ công vô hiệu hóa ví Banking.
- [ ] **Nhận thông báo realtime:** Khi có tiền chuyển vào ngân hàng thực tế, điện thoại rung, chuông reo và hiện banner thông báo sau < 2 giây.
- [ ] **Hộp thư chờ duyệt:** Giao dịch mới xuất hiện trong Inbox kèm nhãn gợi ý danh mục từ AI.
- [ ] **Duyệt giao dịch:** Bấm "Xác nhận" $\rightarrow$ Giao dịch chuyển trạng thái `Confirmed`, cập nhật số dư ví và lưu vào SQLite.
- [ ] **Bỏ qua giao dịch:** Bấm "Bỏ qua" $\rightarrow$ Giao dịch biến mất khỏi danh sách chờ, không ảnh hưởng báo cáo chi tiêu.
- [ ] **Tự phục hồi kết nối:** Khi bật lại WiFi, app tự động reconnect Socket và fetch lại các giao dịch đang chờ duyệt.
