# THIẾT KẾ KIẾN TRÚC: CƠ CHẾ ƯU TIÊN & CỬA THOÁT HIỂM CHO ADMIN-WEB (PHƯƠNG ÁN ĐÃ CHỐT)

> **Trạng thái:** **PO ĐÃ CHỐT PHƯƠNG ÁN 1 (2026-09-29)**  
> **Phương án lựa chọn:** **Cơ chế Phân luồng ưu tiên (Priority Lane) & Cách ly tài nguyên (Bulkhead Pattern)**  
> **Phạm vi áp dụng:** `src/Backend`, `src/Admin-web`

---

## 1. MỤC TIÊU & NGUYÊN TẮC THIẾT KẾ

Khi hệ thống Backend gặp sự cố nghẽn mạng, quá tải request từ Client-app hoặc gặp bão dữ liệu:
- **Admin-web là công cụ cứu nạn duy nhất**: Quản trị viên bắt buộc phải truy cập được vào hệ thống trong mọi hoàn cảnh.
- **Không tốn thêm chi phí Cloud**: Triển khai trên cùng 1 codebase và 1 server hiện tại (Render/Vercel) mà không cần cấu hình hạ tầng mạng phức tạp hay mua thêm gói dịch vụ.
- **Không làm ảnh hưởng hay gãy mapping của Client-app**: Mọi API của người dùng di động vẫn giữ nguyên URL và luồng xử lý.

---

## 2. SƠ ĐỒ VẬN HÀNH PHÂN LUỒNG ƯU TIÊN

```
                                  [ INCOMING TRAFFIC ]
                                            │
                     ┌──────────────────────┴──────────────────────┐
                     ▼                                             ▼
          [ Mobile / Client-app ]                           [ Admin-web ]
                     │                                             │
            (Làn thường - Rate Limited)                  (LÀN ƯU TIÊN - FAST-LANE)
                     │                                             │
      Kiểm tra trạng thái nghẽn:                          - Bỏ qua Rate Limiter thường
      - Event Loop Lag > 100ms?                           - Luôn có sẵn Headroom DB Pool (20%)
      - Đang bật Maintenance Mode?                        - Không bị Drop khi nghẽn tải
      ──► NẾU CÓ: Trả ngay HTTP 503                       - Có quyền can thiệp Emergency Switch
          (Thông báo rõ ràng, không âm thầm)                       │
      ──► NẾU KHÔNG: Vào xử lý bình thường                         │
                     │                                             ▼
                     └──────────────────────┬──────────────────────┘
                                            ▼
                               [ Xử lý nghiệp vụ an toàn ]
```

---

## 3. CHI TIẾT 4 TRỤ CỘT KỸ THUẬT ĐÃ ĐƯỢC PO PHÊ DUYỆT

### 3.1. Làn ưu tiên đặc quyền (Admin Fast-Lane Middleware)
- **Vị trí:** Đặt tại middleware đầu tiên trong chuỗi xử lý của Express (`app.js`), trước cả các bộ phân tích body và bộ giới hạn request chung.
- **Cơ chế nhận diện:**
  - Nhận diện qua tiền tố đường dẫn: `/api/admin/*`, `/api/auth/admin/*`
  - Nhận diện qua JWT Token có Role là `admin` hoặc API Key Admin khẩn cấp trong Header (`X-Emergency-Admin-Key`).
- **Đặc quyền:**
  - Bỏ qua hoàn toàn bộ giới hạn tần suất request (`generalLimiter`).
  - Không bị chặn bởi các quy tắc Load Shedding thông thường.

### 3.2. Khoang cách ly kết nối CSDL (Bulkhead DB Pool Headroom)
- **Nguyên lý:**
  - Kết nối Supabase PostgreSQL được phân chia hạn mức rõ ràng:
    - **Tối đa 80% dung lượng kết nối (Client Quota):** Dành cho các request từ người dùng thông thường và Client-app.
    - **Tối thiểu 20% dung lượng kết nối (Admin Headroom):** Được khóa bảo vệ dành riêng cho Admin-web.
- **Hiệu quả:** Dù hàng nghìn người dùng mobile có gửi request đồng thời làm đầy 80% kết nối, Admin-web vẫn luôn có kết nối dự trữ sẵn sàng để truy vấn Dashboard, xem thống kê và kiểm tra trạng thái máy chủ.

### 3.3. Cơ chế Cắt tải bảo vệ (Load Shedding) thông minh & Minh bạch
- **Cơ chế:**
  - Giám sát độ trễ của Event Loop Node.js theo thời gian thực (ngưỡng cảnh báo: độ trễ lag > 100ms hoặc CPU tăng vọt).
  - Khi hệ thống bị nghẽn:
    - **Đối với Client-app:** Tự động phản hồi HTTP `503 Service Temporarily Overloaded` kèm header `Retry-After: 5` và thông báo người dùng minh bạch:
      ```json
      {
        "success": false,
        "statusCode": 503,
        "code": "SERVER_BUSY",
        "message": "Máy chủ đang phục vụ lượng truy cập lớn. Vui lòng thử lại sau giây lát!",
        "retryAfter": 5
      }
      ```
    - **Tuyệt đối KHÔNG chặn request của Admin-web:** Mọi request từ Admin vẫn được thông luồng bình thường để thực hiện cứu hộ máy chủ.

### 3.4. Công tắc bảo trì khẩn cấp (Emergency Maintenance Mode Switch)
- **Cơ chế:**
  - Cung cấp API quản trị đặc biệt nhẹ:
    - `POST /api/admin/system/maintenance` (bật/tắt chế độ bảo trì).
    - `GET /api/admin/system/maintenance` (xem trạng thái hiện tại).
  - Cờ trạng thái `MAINTENANCE_MODE` được lưu trực tiếp trong bộ nhớ RAM / Redis / cờ file cục bộ (không phụ thuộc vào CSDL để đảm bảo hoạt động được ngay cả khi CSDL bị treo).
- **Cơ chế tách biệt UI chống SPOF:**
  - Trên giao diện Quản trị (`ServerHealthPanel.jsx`), khối công tắc bảo trì được gọi và hiển thị hoàn toàn độc lập với API đo tải tài nguyên `/api/admin/system/health`.
  - Nếu API đo tải phần cứng bị lỗi, timeout hoặc 404, công tắc bảo trì khẩn cấp vẫn hoạt động 100% bình thường, không bao giờ bị khóa chết.
- **Hành vi khi bật bảo trì:**
  - Mọi request từ Client-app ngay lập tức nhận phản hồi `503 Service Unavailable`:
    ```json
    {
      "success": false,
      "statusCode": 503,
      "code": "MAINTENANCE_MODE",
      "message": "Hệ thống đang bảo trì để nâng cấp định kỳ. Quý khách vui lòng quay lại sau ít phút!"
    }
    ```
  - Giải phóng 100% tài nguyên CPU/RAM/DB Pool để Quản trị viên thao tác, sửa lỗi, và khôi phục hệ thống an toàn.

---

## 4. TRẠNG THÁI & KẾT QUẢ TRIỂN KHAI

- [x] Đã được PO phê duyệt Phương án 1 chính thức.
- [x] Đã hoàn thành Backend Priority Lane, Maintenance Mode, Load Shedding và DB Bulkhead.
- [x] Đã hoàn thành Admin-web Operations Center & Resilience Panel (chống SPOF).
- [x] Đã đồng bộ Real-time Socket.io cho Audit Log và Dashboard Activity.
- [x] Tất cả bộ test 98/98 unit tests pass hoàn toàn.
