# Kế Hoạch Triển Khai: Bước 5 — Xây Dựng Ràng Buộc Phân Quyền Động Tại Client-App

> **Dành cho Agentic Workers:** REQUIRED SUB-SKILL: Sử dụng `superpowers:subagent-driven-development` để triển khai kế hoạch này theo từng tác vụ. Các bước sử dụng cú pháp checkbox (`- [ ]`) để theo dõi tiến độ.

**Mục tiêu:** Kết nối Client-app (Flutter) với nguồn phân quyền động CSDL từ Backend (Bước 3 & 4), thay thế logic kiểm tra tĩnh/hardcode bằng việc đọc và áp dụng bảng phân quyền động (`limits` và `features`) cho toàn bộ 5 tính năng cốt lõi (`wallets`, `budgets`, `goals`, `ai_assistant`, `ai_quick_input`).

---

## 1. Hợp Đồng Dữ Liệu Phía Client (Đọc từ Backend)

Client-app nhận cấu hình từ `GET /api/payment/subscription-info`:
```json
{
  "accountType": "Basic",
  "premiumExpiresAt": null,
  "daysRemaining": 0,
  "isExpired": true,
  "limits": {
    "wallets": 3,
    "budgets": 3,
    "goals": 3
  },
  "features": {
    "ai_assistant": false,
    "ai_quick_input": false
  },
  "price": 49000,
  "packageDays": 30
}
```

* **Quy tắc giải mã (Parsing Rules):**
  1. `limits`: Hỗ trợ cả số nguyên dương (`int`) và không giới hạn (`null`).
     - Nếu ô có giá trị `null` (như gói Premium hoặc Admin bật không giới hạn cho Basic) -> lưu `null` (vô hạn).
     - Nếu ô có số nguyên > 0 -> lưu số nguyên đó.
     - Nếu ô bị thiếu / lỗi / âm -> fallback về giá trị mặc định của ô đó (`3`).
  2. `features`: Map chứa trạng thái bật/tắt của các tính năng logic (`TOGGLE`).
     - `ai_assistant`: `true` (cho phép dùng) | `false` (khóa tính năng).
     - `ai_quick_input`: `true` (cho phép dùng) | `false` (khóa tính năng).
     - Nếu trường `features` bị thiếu (backend phiên bản cũ) -> fallback tự động theo cờ `laPremium(now)`.

---

## 2. Kiến Trúc Thay Đổi Tại Client-App

### 2.1 Tầng Domain & Data (`lib/features/premium/`)
* **`tran_goi.dart`:**
  - Cho phép trần từng loại tài nguyên là `int?` (`null` = không giới hạn).
  - Cập nhật `TranGoi.tuJson(json)`: Phân biệt rõ ràng giữa `null` (vô hạn) và thiếu dữ liệu (rơi về mặc định `3`).
  - Cập nhật `conTaoDuoc`: Nếu `tran == null` hoặc tài khoản là Premium còn hạn -> luôn trả về `Duoc()`.
* **`trang_thai_goi.dart`:**
  - Bổ sung trường `quyenTinhNang: Map<String, bool>` vào `TrangThaiGoi` (mặc định `{}`).
  - Bổ sung helper `bool duocDung(String maTinhNang, {bool Function()? fallback})`:
    + Trả về `quyenTinhNang[maTinhNang]` nếu có cấu hình rõ ràng.
    + Nếu không có trong map -> gọi `fallback` (mặc định là `laPremium(now)`).
  - Cập nhật `trangThaiTuJson` và `tuJsonKho` / `toJson` để serialize / deserialize an toàn `quyenTinhNang`.
* **`goi_cubit.dart`:**
  - Bổ sung các getters tiện ích:
    + `bool get duocDungAiAssistant => state.duocDung('ai_assistant', fallback: () => laPremium);`
    + `bool get duocDungAiQuickInput => state.duocDung('ai_quick_input', fallback: () => laPremium);`

### 2.2 Tầng Giao Diện & Ràng Buộc Tính Năng (Presentation Layer)
* **Tính năng Trợ Lý AI (`lib/features/ai_chat/presentation/pages/ai_chat_page.dart`):**
  - Cập nhật hàm `lyDoKhoa`:
    - Thay thế tham số `bool laPremium` thành `bool duocDungAi`.
    - Nếu `!duocDungAi` -> trả về `LyDoKhoaHoiDap.goiBasic` (khóa ô nhập, chip gợi ý, hiển thị thông báo cần nâng cấp).
  - Cập nhật widget đọc cờ `duocDungAiAssistant` từ `context.watch<GoiCubit>()`.
* **Tính năng Nhập Nhanh Giao Dịch (`lib/features/transaction/presentation/pages/add_transaction_page.dart`):**
  - Cập nhật biến `_laPremium` hoặc tạo getter `_duocDungNhapNhanh`:
    - Đọc từ `context.read<GoiCubit>().duocDungAiQuickInput`.
    - Nếu không được dùng -> làm mờ ô nhập nhanh và nút "Điền" tự chuyển thành nút "Nâng cấp".
* **Tính năng Giới Hạn Tài Nguyên (`app_router.dart`):**
  - Ba route tạo (`/wallets/add`, `/budget/rules`, `/goals/add`) đã gọi qua `redirectTaoTheoGoi`.
  - Cơ chế `conTaoDuoc` tự động tôn trọng hạn mức động mới từ `TranGoi` (kể cả khi Basic được nâng lên 5 ví hay 10 mục tiêu).

---

## 3. Danh Sách Tác Vụ Chi Tiết

### Tác Vụ 1: Nâng Cấp Tầng Domain Phân Quyền (`TranGoi` & `TrangThaiGoi`)
**Files:**
- Modify: `src/Client-app/lib/features/premium/domain/tran_goi.dart`
- Modify: `src/Client-app/lib/features/premium/domain/trang_thai_goi.dart`
- Modify: `src/Client-app/test/features/premium/domain/tran_goi_test.dart`
- Modify: `src/Client-app/test/features/premium/domain/trang_thai_goi_test.dart`

- [x] Cập nhật `TranGoi`: cho phép `int? vi, int? nganSach, int? mucTieu;`, parse đúng `null` (vô hạn) và fallback an toàn khi thiếu key.
- [x] Cập nhật `conTaoDuoc`: tôn trọng `tran == null` là `Duoc()`.
- [x] Cập nhật `TrangThaiGoi`: thêm `quyenTinhNang: Map<String, bool>`, method `duocDung(String ma, {bool Function()? fallback})`, cập nhật `trangThaiTuJson` và lưu trữ cục bộ `tuJsonKho` / `toJson`.
- [x] Cập nhật unit test và chạy `rtk flutter test test/features/premium/` đảm bảo pass (47/47 domain tests pass).

### Tác Vụ 2: Nâng Cấp State Management (`GoiCubit`)
**Files:**
- Modify: `src/Client-app/lib/features/premium/presentation/cubit/goi_cubit.dart`
- Modify: `src/Client-app/test/features/premium/presentation/goi_cubit_test.dart`

- [x] Bổ sung `bool get duocDungAiAssistant` và `bool get duocDungAiQuickInput` vào `GoiCubit`.
- [x] Viết unit test cho `GoiCubit` xác nhận phản ánh đúng trạng thái động của tính năng (pass 100%).

### Tác Vụ 3: Áp Dụng Ràng Buộc Phân Quyền Tại Màn Hình Trợ Lý AI
**Files:**
- Modify: `src/Client-app/lib/features/ai_chat/presentation/pages/ai_chat_page.dart`
- Modify: `src/Client-app/test/features/ai_chat/ly_do_khoa_test.dart`

- [x] Cập nhật `_laPremium` trong `ai_chat_page.dart` đọc `context.read<GoiCubit>().duocDungAiAssistant`.
- [x] Giữ nguyên tương thích với test tiêm `widget.laPremium`.
- [x] Kiểm thử `ly_do_khoa_test.dart` PASS 100%.

### Tác Vụ 4: Áp Dụng Ràng Buộc Phân Quyền Tại Màn Hình Nhập Nhanh Giao Dịch
**Files:**
- Modify: `src/Client-app/lib/features/transaction/presentation/pages/add_transaction_page.dart`

- [x] Cập nhật kiểm tra quyền Nhập nhanh bằng câu theo `context.read<GoiCubit>().duocDungAiQuickInput`.
- [x] Đảm bảo khi admin khóa tính năng thì ô nhập nhanh bị mờ và hiển thị nút "Nâng cấp".

### Tác Vụ 5: Kiểm Thử Toàn Diện & Cập Nhật Nguồn Sự Thật
**Files:**
- Chạy toàn bộ test của Client-app: `rtk flutter test`
- Modify: `Project.md`

- [x] Chạy `rtk flutter test test/features/premium/` (112/112 tests PASS 100%).
- [x] Cập nhật mục 11.73 trong `Project.md` ghi nhận hoàn thành Bước 5.
- [x] Chạy `rtk npx codegraph build`.
