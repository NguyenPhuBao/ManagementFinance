# MODULE THANH TOÁN (PAYMENT) & NÂNG CẤP TÀI KHOẢN PREMIUM

Thư mục này chứa tài liệu thiết kế kiến trúc, đặc tả API, chính sách bảo mật và hướng dẫn tích hợp cổng thanh toán **PayOS** cho hệ thống Quản lý Tài chính Cá nhân (WealthCommand).

---

## 📚 Danh mục tài liệu

1. **[PAYMENT_PAYOS_SPEC.md](./PAYMENT_PAYOS_SPEC.md)**: Đặc tả kỹ thuật & nghiệp vụ toàn diện module Payment (PayOS), sơ đồ CSDL DDL, chính sách bảo mật dữ liệu, vòng đời gói Premium và kịch bản kiểm thử.
2. **[PAYOS_SETUP_GUIDE.md](./PAYOS_SETUP_GUIDE.md)**: Hướng dẫn cấu hình, thiết lập Kênh thanh toán PayOS trên https://my.payos.vn, lấy API Credentials, cấu hình Webhook URL và kiểm thử kết nối tự động (`npm run payos:test`).
3. **[CLIENT_INTEGRATION_GUIDE.md](./CLIENT_INTEGRATION_GUIDE.md)**: Hướng dẫn tích hợp toàn diện dành cho Client-app / Mobile / Frontend Web: Checklist công việc, luồng UX, đặc tả 5 API endpoints, 2 phương án hiển thị mã VietQR & nút mở App Ngân Hàng, cơ chế lắng nghe Realtime Socket.IO và code mẫu tham khảo.
4. **Kế hoạch triển khai:** Được lưu tại `docs/superpowers/plans/2026-10-05-real-database-and-payos-setup-plan.md`.
5. **Migration CSDL DDL:** Được lưu tại `database/19_create_payment_subscription_tables.sql` (đã thực thi thành công 100% trên Supabase PostgreSQL Cloud).


