# Mục 50 — Chức năng GIA ĐÌNH (nhà nhiều người): Toàn bộ Thiết kế & Nhiệm vụ Client-App Phần 1 (Nền móng)

> 👑 **TÀI LIỆU YÊU CẦU KỸ THUẬT NGUỒN SỰ THẬT (SOURCE OF TRUTH) — ĐÃ ĐƯỢC PO DUYỆT 2026-10-27**
> **Người nhận:** Client-App Team (Flutter Mobile Engineers)  
> **Người giao:** Product Owner (PO) & Lead Business Analyst  
> **Mức độ ưu tiên:** **CAO (High / P1)** — Tính năng chiến lược mở rộng trải nghiệm người dùng  
> **Tài liệu nghiệp vụ gốc:** [`docs/Family/00_TONG_QUAN.md`](../../../Family/00_TONG_QUAN.md) & [`docs/Family/01_NEN_MONG.md`](../../../Family/01_NEN_MONG.md)  
> **Tài liệu phía Backend:** [`docs/superpowers/backend/CAN-LAM/GIA_DINH_NEN_MONG.md`](../../backend/CAN-LAM/GIA_DINH_NEN_MONG.md)  
> **Trạng thái:** 🟢 SẴN SÀNG TRIỂN KHAI — ĂN KHỚP 100% VỚI HỆ THỐNG BACKEND  

---

## 0. Tóm tắt Tổng quan (Executive Summary)

Phía Client-App (Flutter Mobile) chịu trách nhiệm xây dựng module mới **`features/household/`**, nâng cấp cơ sở dữ liệu ngoại tuyến **SQLite Drift (Schema v32)**, tích hợp 16 REST APIs với Backend, lắng nghe các sự kiện Socket.io và thiết lập cơ chế đồng bộ dữ liệu gia đình hai chiều an toàn, bảo vệ sự riêng tư tuyệt đối giữa tài chính cá nhân và tài chính gia đình.

```
┌────────────────────────────────────────────────────────────────────────┐
│              KIẾN TRÚC CLIENT-APP CHO TÍNH NĂNG GIA ĐÌNH               │
├────────────────────────────────┬───────────────────────────────────────┤
│ 1. GIAO DIỆN & ĐIỀU HƯỚNG      │ Mục "Nhà mình" (/nha) trong drawer;   │
│                                │ Màn Tạo nhà, Mời (Email + Mã 8 ký tự),│
│                                │ Màn Quản lý thành viên & Đổi vai trò  │
├────────────────────────────────┼───────────────────────────────────────┤
│ 2. CƠ SỞ DỮ LIỆU DRIFT SQLITE  │ Schema v32: Bổ sung cột idhousehold;  │
│                                │ Cô lập 25+ query cá nhân (IS NULL)    │
├────────────────────────────────┼───────────────────────────────────────┤
│ 3. ĐỒNG BỘ & CHỐT CHẶN SYNC    │ Xử lý 6 mã lỗi đẩy vĩnh viễn;         │
│                                │ Kéo lại toàn bộ (keoLaiToanBo)        │
├────────────────────────────────┼───────────────────────────────────────┤
│ 4. REALTIME & THÔNG BÁO        │ Socket: household.changed & .invited; │
│                                │ Nhóm thông báo NotificationGroup.giaDinh│
└────────────────────────────────┴───────────────────────────────────────┘
```

---

## 1. Cấu trúc Mã nguồn Module `features/household/`

Toàn bộ mã nguồn tính năng gia đình được tổ chức độc lập trong thư mục `src/Client-app/lib/features/household/` theo mô hình Clean Architecture:

```
src/Client-app/lib/features/household/
├── data/
│   ├── datasources/
│   │   └── household_api.dart             # Gọi 16 REST endpoints của Backend
│   ├── models/
│   │   ├── household_model.dart           # Model thông tin nhà & trạng thái /me
│   │   ├── household_member_model.dart    # Model thành viên & cựu thành viên
│   │   └── household_invite_model.dart    # Model lời mời mã & email
│   └── repositories/
│       └── household_repository_impl.dart # Quản lý cache secure storage & API
├── domain/
│   ├── entities/
│   │   ├── household.dart                 # Entity Nhà (id, name, status, role)
│   │   ├── household_member.dart          # Entity Thành viên (Owner, Member, Viewer)
│   │   └── household_invite.dart          # Entity Lời mời (code, email, expiresAt)
│   └── repositories/
│       └── household_repository.dart      # Interface tầng domain
└── presentation/
    ├── bloc/
    │   ├── household_cubit.dart           # Quản lý trạng thái nhà, nạp /me
    │   └── household_state.dart           # Initial, Loading, HasHousehold, NoHousehold, Error
    ├── screens/
    │   ├── household_root_screen.dart     # Màn hình chính /nha (điều phối có nhà vs chưa có nhà)
    │   ├── household_create_screen.dart   # Màn hình Tạo nhà mới (chỉ cho Premium)
    │   ├── household_invite_screen.dart   # Màn hình Mời thành viên (2 khối Email & Mã mời)
    │   ├── household_join_screen.dart     # Màn hình Nhập mã 8 ký tự để vào nhà
    │   └── household_members_screen.dart  # Màn hình Danh sách thành viên (Đổi vai, mời ra, chuyển chủ)
    └── widgets/
        ├── pending_invitation_card.dart   # Thẻ "Lời mời đang chờ" (Chấp nhận / Từ chối)
        └── household_role_badge.dart      # Badge hiển thị vai trò (Chủ nhà / Thành viên / Chỉ xem)
```

---

## 2. Nâng cấp CSDL SQLite Drift (Schema Migration v32)

### 2.1. Bổ sung cột `idhousehold` vào 5 bảng cốt lõi
Trong `src/Client-app/lib/core/database/tables/`:
- `wallets.dart`: `IntColumn get idhousehold => integer().nullable()();`
- `transactions.dart`: `IntColumn get idhousehold => integer().nullable()();`
- `goals.dart`: `IntColumn get idhousehold => integer().nullable()();`
- `budgets.dart`: `IntColumn get idhousehold => integer().nullable()();`
- `categories.dart`: `IntColumn get idhousehold => integer().nullable()();`

### 2.2. Viết Migration Script trong `app_database.dart`
- Tăng schema version từ `31` lên `32`.
- Trong hàm `migration.onUpgrade`:
  ```dart
  if (from < 32) {
    await m.addColumn(wallets, wallets.idhousehold);
    await m.addColumn(transactions, transactions.idhousehold);
    await m.addColumn(goals, goals.idhousehold);
    await m.addColumn(budgets, budgets.idhousehold);
    await m.addColumn(categories, categories.idhousehold);
  }
  ```

### 2.3. Quy tắc "Zero Leakage" — Cô lập 100% dữ liệu cá nhân
* **Nguyên tắc sống còn:** Màn hình cá nhân (Trang chủ, Sổ giao dịch, Phân tích, Ngân sách cá nhân) **tuyệt đối không hiển thị tiền của nhà**.
* **Hành động bắt buộc:** Rà soát và cập nhật toàn bộ **25+ truy vấn DAO cá nhân** hiện có bổ sung điều kiện lọc:
  ```dart
  // Ví dụ trong WalletDao:
  (select(wallets)..where((t) => t.idaccount.equals(userId) & t.idhousehold.isNull()))
  ```

---

## 3. Tích hợp 16 REST APIs với Backend

Tất cả các lời gọi API sử dụng `DioClient` đã cấu hình JWT token và Headers (`x-device-name`, `x-platform`):

| # | Endpoint | Chức năng trên Client | Xử lý dữ liệu & Phản hồi |
|:---:|---|---|---|
| **1** | `POST /api/households` | Tạo nhà mới (cần Premium) | Thành công $\rightarrow$ Lưu trạng thái nhà, gọi `SyncEngine.keoLaiToanBo()`. |
| **2** | `GET /api/households/me` | Lấy trạng thái nhà của tôi | Trả về `household`, `myRole`, `members`, `formerMembers`. Lưu vào SecureStorage. |
| **3** | `POST /api/households/invites` | Tạo mã mời 8 ký tự | Nhận `{ code, role, expiresAt }`, hiển thị dialog chia sẻ mã. |
| **4** | `GET /api/households/invites` | Lấy danh sách mã & email mời | Hiển thị tại tab quản lý lời mời của Chủ nhà. |
| **5** | `DELETE /api/households/invites/:code` | Thu hồi / Hủy lời mời | Xóa mã mời khỏi danh sách. |
| **6** | `GET /api/households/invites/:code` | Xem trước thông tin nhà từ mã | Hiển thị tên nhà, tên chủ nhà, số thành viên trước khi bấm Tham gia. |
| **7** | `POST /api/households/join` | Tham gia nhà bằng mã 8 ký tự | Thành công $\rightarrow$ Lưu trạng thái nhà, kích hoạt `SyncEngine.keoLaiToanBo()`. |
| **8** | `PATCH /api/households/members/:id` | Đổi vai trò thành viên | Cập nhật vai trò Member $\leftrightarrow$ Viewer. |
| **9** | `POST /api/households/transfer-owner` | Chuyển quyền Chủ nhà | Dialog xác nhận nghiêm ngặt trước khi chuyển. |
| **10**| `DELETE /api/households/members/:id` | Mời thành viên ra khỏi nhà | Dialog xác nhận xóa thành viên. |
| **11**| `POST /api/households/leave` | Tự rời khỏi nhà | Xóa sạch dữ liệu của nhà trong SQLite Drift cục bộ (`purgeHouseholdData()`). |
| **12**| `POST /api/households/dissolve` | Giải tán nhà (Chủ nhà) | Xóa sạch dữ liệu nhà trong SQLite Drift trên máy. |
| **13**| `POST /api/households/invites/email` | Mời qua Email | Ô nhập email (giới hạn 100 ký tự). Nhận `202 Accepted` $\rightarrow$ Toast thông báo. |
| **14**| `GET /api/households/invitations` | Lấy danh sách lời mời gửi tới tôi | Hiển thị thẻ *"Lời mời đang chờ"* ở màn hình `/nha`. |
| **15**| `POST /api/households/invitations/:code/accept` | Chấp nhận lời mời email | Tham gia nhà $\rightarrow$ Kích hoạt `SyncEngine.keoLaiToanBo()`. |
| **16**| `POST /api/households/invitations/:code/decline` | Từ chối lời mời email | Ẩn thẻ lời mời, thông báo từ chối thành công. |

---

## 4. Xử lý Mã lỗi Đẩy Vĩnh viễn trong Sync Engine

Trong `src/Client-app/lib/core/sync/gui_lo_dong_bo.dart`:
Bổ sung mã lỗi mới vào danh sách `_permanentCodes` để Client **xếp vào lỗi vĩnh viễn và không bao giờ gửi lại (tránh kẹt hàng đợi đồng bộ)**:

```dart
final _permanentCodes = {
  // Các mã hiện có:
  'NOT_OWNER',
  'BILL_ALREADY_PAID',
  
  // 5 Mã gia đình:
  'HOUSEHOLD_NOT_MEMBER',       // Không còn là thành viên
  'HOUSEHOLD_READ_ONLY',        // Nhà đang ở chế độ chỉ xem (hết Premium)
  'HOUSEHOLD_CLOSED',           // Nhà đã giải tán
  'HOUSEHOLD_SCOPE_MISMATCH',   // Tham chiếu sai phạm vi riêng vs chung
  'HOUSEHOLD_ROLE_FORBIDDEN',   // Vi phạm phân quyền vai trò (Viewer ghi, Member sửa ví chung...)
  'HOUSEHOLD_WALLET_LIMIT',     // Vượt trần số ví chung của nhà (chuẩn bị cho Phần 2a)
};
```

---

## 5. Tiếp nhận Sự kiện Thời gian thực & Thông báo

### 5.1. Socket.io Events trong `realtime_event.dart`
Bổ sung 2 enum sự kiện Socket mới:
```dart
enum RealtimeEvent {
  // Các sự kiện hiện có...
  dongBoXong,
  
  // Bổ sung sự kiện Gia đình:
  nhaThayDoi,     // 'household.changed': Trạng thái nhà / thành viên / vai trò thay đổi
  duocMoiVaoNha,  // 'household.invited': Có lời mời mới gửi tới email của tài khoản
}
```

* **Xử lý khi nhận sự kiện:**
  - `nhaThayDoi`: Gọi lại `GET /api/households/me` để cập nhật trạng thái mới nhất; nếu phát hiện bị mời ra hoặc nhà giải tán $\rightarrow$ dọn dẹp dữ liệu nhà trên SQLite.
  - `duocMoiVaoNha`: Gọi lại `GET /api/households/invitations` để hiển thị ngay thẻ lời mời trên giao diện.

### 5.2. Hệ thống Thông báo (Notification)
- Khai báo nhóm mới: `NotificationGroup.giaDinh`.
- Bổ sung loại thông báo mới: `NotificationKind.loiMoiNha` (mặc định BẬT).
- Khóa chống trùng: `loiMoiNha:<code>`. Khi người dùng chạm vào thông báo $\rightarrow$ Deep link dẫn thẳng về màn hình `/nha`.

---

## 6. Ma trận Kiểm thử 2 Tầng cho Client-App (Lead BA & QA Nghiệm thu)

Áp dụng quy tắc kiểm thử 2 tầng **(Rule 11 — 2-Tier Testing Architecture)**:

| STT | Kịch bản kiểm thử | Tầng 1: Hiển thị & Thao tác Giao diện | Tầng 2: Tác động Hệ thống & CSDL thực tế | Đánh giá |
|:---:|---|---|---|:---:|
| **1** | Mở khu vực Nhà mình (`/nha`) khi chưa có nhà | Drawer có mục "Nhà mình"; hiển thị màn hình rỗng kèm nút "Tạo nhà" (nếu Premium) và "Tham gia bằng mã". | Gọi `GET /api/households/me` nhận `household: null`; không crash giao diện. | ⏳ Chờ test |
| **2** | Nhận lời mời qua Email | Thẻ "Lời mời đang chờ" xuất hiện ở đầu màn hình `/nha` kèm tên nhà, tên người mời và nút Chấp nhận/Từ chối. | Gọi `GET /api/households/invitations` trả về danh sách chính xác; socket `household.invited` kích hoạt mượt mà. | ⏳ Chờ test |
| **3** | Chấp nhận lời mời gia nhập nhà | Bấm "Chấp nhận" $\rightarrow$ Giao diện chuyển sang màn hình chính của Nhà mình. | SQLite Drift kích hoạt `SyncEngine.keoLaiToanBo()`; tải toàn bộ danh mục của nhà về máy. | ⏳ Chờ test |
| **4** | Gửi lời mời qua Email (Chủ nhà) | Form Mời có ô nhập email, bàn phím email, giới hạn 100 ký tự; nút "Gửi lời mời". | Bấm Gửi $\rightarrow$ Gọi `POST /api/households/invites/email` nhận `202`; hiển thị toast thông báo thành công. | ⏳ Chờ test |
| **5** | Tạo mã mời 8 ký tự | Màn hình sinh mã 8 ký tự ngẫu nhiên; có nút "Sao chép mã" và thời hạn 48h. | Gọi `POST /api/households/invites` lưu mã vào CSDL; danh sách lời mời active cập nhật. | ⏳ Chờ test |
| **6** | Cô lập dữ liệu cá nhân (Zero Leakage) | Màn hình Trang chủ, Sổ giao dịch, Phân tích chi tiêu cá nhân không hiển thị ví hay giao dịch của nhà. | Các câu query DAO cá nhân đều chứa `idhousehold IS NULL`; số dư cá nhân không bị sai lệch. | ⏳ Chờ test |
| **7** | Chốt chặn mã lỗi đẩy vĩnh viễn | Thành viên cố gắng gửi payload vi phạm vai trò lên server. | `results[i].code` nhận `HOUSEHOLD_ROLE_FORBIDDEN` $\rightarrow$ Client xóa khỏi hàng đợi đẩy, không thử lại liên tục. | ⏳ Chờ test |
| **8** | Rời nhà hoặc Nhà giải tán | Người dùng bấm "Rời nhà" $\rightarrow$ Giao diện quay về trạng thái chưa có nhà. | SQLite Drift chạy `purgeHouseholdData()`, xóa sạch toàn bộ bản ghi có `idhousehold != null`; dữ liệu riêng bảo toàn 100%. | ⏳ Chờ test |
