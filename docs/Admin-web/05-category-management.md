# 🏷️ Chức Năng 05: Quản Lý Danh Mục Hệ Thống & Bảo Vệ Quyền Riêng Tư (Category Management & Privacy Defense)

> **Mã chức năng:** `ADMIN-FEAT-05`  
> **Module phụ trách:**  
> - Frontend: `src/Admin-web/src/pages/categories/CategoryPage.jsx`  
> - Backend: `src/Backend/modules/admin/admin.service.js`, `admin.repository.js`, `admin.controller.js`  

---

## 📌 1. TỔNG QUAN & MỤC ĐÍCH NGHIỆP VỤ

Chức năng **Quản Lý Danh Mục Hệ Thống** cho phép quản trị viên thiết lập và duy trì bộ danh mục thu chi chuẩn mực cho toàn bộ nền tảng. Khi một người dùng mới đăng ký tài khoản trên Mobile App, hệ thống sẽ sử dụng các danh mục mặc định này để khởi tạo bộ khung tài chính ban đầu cho họ.

Điểm kiến trúc then chốt của chức năng này là **Cơ chế Phòng Vệ Chiều Sâu (Defense-in-Depth Privacy Protection)**: Admin chỉ quản lý các danh mục công cộng của hệ thống (`is_default = true`), **tuyệt đối không được phép xem, chỉnh sửa hoặc xóa các danh mục riêng tư do người dùng tự tạo trên ứng dụng di động** (`is_default = false`).

---

## ⚙️ 2. CƠ CHẾ HOẠT ĐỘNG CHI TIẾT (END-TO-END FLOW)

```mermaid
graph TD
    subgraph "Thao Tác Admin (src/Admin-web)"
        A1[Thêm Danh Mục Hệ Thống Mới]
        A2[Chỉnh Sửa Danh Mục Hệ Thống]
        A3[Xóa Mềm Danh Mục Hệ Thống]
        A4[Đồng Bộ & Làm Mới Danh Mục]
    end

    subgraph "Tầng Xử Lý Nghiệp Vụ Backend (src/Backend)"
        B1[Chuẩn Hóa Phân Loại: canonicalClassify Thu/Chi/Vay-no]
        B2{Kiểm Tra is_default = true?}
        B3{Đã Tồn Tại Trùng Tên?}
        B4{Từng Bị Xóa Mềm?}
        B5[Tự Động Khôi Phục: Restore & Update delete_at = null]
        B6[INSERT Prisma category]
        B7[Soft-Delete: Set delete_at = now]
        B8[Socket.io Hub: emitCategoryUpdated]
    end

    subgraph "Phòng Vệ Riêng Tư Người Dùng (Privacy Shield)"
        P1[Mặt nạ hóa 100% bằng *** nếu là user category]
        P2[Chặn HTTP 403 Forbidden nếu cố tình sửa/xóa user category]
    end

    subgraph "Tác Động Tới Mobile App (Client-app)"
        M1[Client Pull Sync: Nhận danh mục hệ thống mới vào SQLite]
        M2[AI Giao Dịch: Nhận diện keyword để gợi ý danh mục tự động]
    end

    A1 --> B1 --> B3
    B3 -- "Chưa có" --> B4
    B4 -- "Đã từng xóa" --> B5 --> B8
    B4 -- "Mới hoàn toàn" --> B6 --> B8

    A2 --> B2
    B2 -- "is_default = false" --> P2
    B2 -- "is_default = true" --> B1 --> B8

    A3 --> B2
    B2 -- "is_default = false" --> P2
    B2 -- "is_default = true" --> B7 --> B8

    B8 -.->|admin.category_updated| A4
    B8 -.->|Data Sync Event| M1
    B6 & B5 --> M2
```

### 2.1. Cơ Chế Chuẩn Hóa Phân Loại Danh Mục (Canonical Classify Normalization)
Để đảm bảo tính nhất quán giữa cơ sở dữ liệu tiếng Việt và mobile app đa ngôn ngữ, hệ thống tự động chuẩn hóa mọi biến thể của nhóm Vay/Nợ về một định danh duy nhất:
- Nhập vào: `'Vay/nợ'`, `'Vay'`, hoặc `'no'` $\implies$ Chuẩn hóa lưu trữ: `'Vay/no'`.
- Ba nhóm phân loại chuẩn:
  1. **`Thu` (`income`):** Danh mục nguồn thu nhập (Lương, Thưởng, Lãi tiết kiệm, Đầu tư).
  2. **`Chi` (`expense`):** Danh mục chi tiêu (Ăn uống, Đi lại, Mua sắm, Y tế, Giáo dục).
  3. **`Vay/no` (`debt`):** Danh mục công nợ (Cho vay, Đi vay, Trả nợ, Thu nợ).

### 2.2. Cơ Chế Chống Trùng Lặp & Tự Động Phục Hồi (Auto-Restore on Re-create)
Để tránh tình trạng duplicate dữ liệu:
1. Khi Admin tạo danh mục `"Tiền Điện"`, Backend kiểm tra trong các danh mục hệ thống đang active (`delete_at: null`). Nếu đã có danh mục cùng tên (so sánh không phân biệt hoa thường - `mode: 'insensitive'`), hệ thống báo lỗi HTTP 400.
2. Nếu danh mục `"Tiền Điện"` đã từng bị xóa mềm trong quá khứ (`delete_at: { not: null }`), hệ thống **tự động phục hồi bản ghi cũ**, cập nhật lại `delete_at = null`, gán icon và từ khóa mới. Cơ chế này giúp giữ nguyên khóa chính `idcategory`, bảo toàn tính toàn vẹn cho các giao dịch lịch sử trước đây từng liên kết với danh mục này.

### 2.3. Phòng Vệ Chiều Sâu 3 Tầng (Defense-in-Depth Privacy)
- **Tầng 1 (Query Level):** Mọi câu lệnh truy vấn từ Admin Repository luôn bắt buộc có điều kiện `where: { is_default: true, delete_at: null }`.
- **Tầng 2 (Masking Fallback):** Nếu vì lỗi hệ thống hoặc dữ liệu bất thường mà một danh mục của người dùng lọt vào kết quả, service tự động che tên và từ khóa thành `***` trước khi gửi ra response.
- **Tầng 3 (Mutation Guard):** Tại API Update và Delete, service kiểm tra cờ `if (!currentCat.is_default)`. Nếu phát hiện là danh mục cá nhân của người dùng, server lập tức ném lỗi HTTP 403: *"Vi phạm quyền riêng tư: Tuyệt đối cấm chỉnh sửa/xóa danh mục của người dùng"*.

---

## 📐 3. CẤU TRÚC DỮ LIỆU & TỪ KHÓA HỌC MÁY (KEYWORD FIELD)

Mỗi danh mục hệ thống chứa các trường dữ liệu quan trọng phục vụ vận hành:

```json
{
  "id": "uuid-v4",
  "name": "Ăn uống",
  "classify": "Chi",
  "type": "expense",
  "is_default": true,
  "keyword": "com, bun, pho, ca phe, tra sua, nha hang, sieu thi, bach hoa",
  "icon": "restaurant",
  "created_by": "Hệ thống"
}
```

- **Ý nghĩa trường `keyword`:** Là chuỗi các từ khóa ngữ nghĩa không dấu và có dấu phân cách bằng dấu phẩy. Trường này là **nguồn tri thức nền tảng (Ground Truth) để mô hình Edge AI & SLM trên điện thoại di động** tự động phân loại giao dịch khi quét SMS ngân hàng hoặc OCR hóa đơn bán lẻ.

---

## ⛔ 4. CÁC RÀNG BUỘC KỸ THUẬT

1. **Ràng buộc tên danh mục:** Độ dài từ 2 đến 50 ký tự, không được chỉ chứa khoảng trắng.
2. **Ràng buộc un-link danh mục con khi xóa Group:** Nếu xóa một danh mục cha (`is_group = true`), toàn bộ danh mục con trực thuộc sẽ được tự động tách độc lập (`updateMany: idgroup = null`), không gây lỗi ràng buộc khóa ngoại (Foreign Key Constraint).
3. **Admin chỉ tạo danh mục hệ thống:** Toàn bộ danh mục tạo từ Admin-web đều bắt buộc gán `is_default = true`.

---

## 💼 5. CÔNG DỤNG & GIÁ TRỊ NGHIỆP VỤ

- **Chuẩn hóa hệ sinh thái tài chính:** Định hình sẵn các thói quen ghi chép thu chi cho người dùng khi mới cài app.
- **Tối ưu hóa độ chính xác của AI:** Khi Admin bổ sung các từ khóa mới xuất hiện trên thị trường (ví dụ: *"ShopeeFood"*, *"GrabMart"*), năng lực nhận diện của Chatbot AI và OCR sẽ tự động thông minh hơn.
- **Độc lập và bảo mật:** Người dùng thoải mái tạo danh mục riêng tư cá nhân mà không sợ nhân viên quản trị đọc lén.

---

## 🧩 6. TÍNH NĂNG ĐI KÈM TRÊN GIAO DIỆN

1. **Bảng Danh Mục Hệ Thống (`CategoryPage.jsx`):**
   - Tìm kiếm thông minh hỗ trợ tiếng Việt không dấu (`normalizeVietnameseUnaccent`).
   - Lọc nhanh theo phân loại (Tất cả, Khoản Thu, Khoản Chi, Vay/Nợ).
   - Lọc theo từ khóa chi tiết.
   - Phân trang tùy chỉnh 10, 20, 50 bản ghi.
2. **Modal Thêm Mới & Chỉnh Sửa:**
   - Chọn loại phân loại bằng Selectbox trực quan.
   - Hướng dẫn nhập từ khóa gợi ý cho AI.
3. **Modal Cảnh Báo Xóa An Toàn:**
   - Cảnh báo rõ việc xóa chỉ là ẩn khỏi danh mục mặc định của hệ thống, không làm mất giao dịch cũ.
4. **Nút Đồng Bộ & Làm Mới Tức Thời:**
   - Kích hoạt refetch và hiển thị Toast thông báo trạng thái.

---

## 📱 7. ẢNH HƯỞNG ĐẾN HỆ THỐNG & MOBILE APP (CLIENT-APP)

- **Đến Backend:**
  - Index độc lập trên `[name_category, is_default, delete_at]` giúp tốc độ kiểm tra trùng lặp chỉ mất $< 2\text{ms}$.
- **Đến Mobile App (Client-app):**
  - Khi người dùng đăng ký mới hoặc cài lại ứng dụng, Mobile App gọi `GET /api/sync/pull` để kéo danh sách các danh mục `is_default = true` mới nhất này vào CSDL SQLite nội bộ trên điện thoại.
  - Các giao dịch mới tạo trên điện thoại sẽ tự động gợi ý danh mục dựa trên bộ từ khóa `keyword` mà Admin đã cấu hình.

---

## 📡 8. DANH MỤC API & SOCKET.IO PHỤ TRÁCH

### REST API Endpoints
| Phương thức | Endpoint | Chức năng | Phân quyền |
|---|---|---|---|
| `GET` | `/api/admin/getcategory` | Lấy danh sách danh mục mặc định hệ thống | Admin |
| `POST` | `/api/admin/addcategory` | Tạo mới hoặc phục hồi danh mục hệ thống | Admin |
| `PUT` | `/api/admin/updatecategory/:id` | Cập nhật thông tin danh mục hệ thống | Admin |
| `DELETE` | `/api/admin/deletecategory/:id` | Xóa mềm danh mục hệ thống | Admin |

### Socket.io Events
- **Phát tán (`Server -> admin_room`):**
  - Sự kiện `admin.category_updated`: Phát payload `{ action: 'create'|'update'|'delete', category }` giúp mọi tab Admin-web khác tự động đồng bộ danh mục tức thời mà không cần F5.
