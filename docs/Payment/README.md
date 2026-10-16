# MODULE THANH TOÁN (PAYMENT) & NÂNG CẤP TÀI KHOẢN PREMIUM

Thư mục này chứa tài liệu thiết kế kiến trúc, đặc tả API, chính sách bảo mật và hướng dẫn tích hợp cổng thanh toán **PayOS** cho hệ thống Quản lý Tài chính Cá nhân (WealthCommand).

---

## 📚 Danh mục tài liệu

1. **[PAYMENT_WORKFLOW_SPEC.md](./PAYMENT_WORKFLOW_SPEC.md)**: **[NGUỒN SỰ THẬT]** Đặc tả toàn diện quy trình thanh toán 6 bước tự động, đối soát sai lệch số tiền (thừa/thiếu), mã nhận diện ngẫu nhiên 6 ký tự, vòng đời trạng thái đơn và cơ chế hoàn tiền có minh chứng.
2. **[PAYMENT_PAYOS_SPEC.md](./PAYMENT_PAYOS_SPEC.md)**: Đặc tả kỹ thuật & nghiệp vụ module Payment (PayOS), sơ đồ CSDL DDL, chính sách bảo mật dữ liệu, vòng đời gói Premium và kịch bản kiểm thử.
3. **[PAYOS_SETUP_GUIDE.md](./PAYOS_SETUP_GUIDE.md)**: Hướng dẫn cấu hình, thiết lập Kênh thanh toán PayOS trên https://my.payos.vn, lấy API Credentials, cấu hình Webhook URL và kiểm thử kết nối tự động (`npm run payos:test`).
4. **[CLIENT_INTEGRATION_GUIDE.md](./CLIENT_INTEGRATION_GUIDE.md)**: Hướng dẫn tích hợp toàn diện dành cho Client-app / Mobile / Frontend Web: Checklist công việc, luồng UX, đặc tả 5 API endpoints, 2 phương án hiển thị mã VietQR & nút mở App Ngân Hàng, cơ chế lắng nghe Realtime Socket.IO và code mẫu tham khảo.
5. **Kế hoạch triển khai:** Được lưu tại `docs/superpowers/plans/2026-10-15-payment-reconciliation-and-client-admin-flow-plan.md`.
6. **Migration CSDL DDL:** Được lưu tại `src/Backend/database/` và áp dụng an toàn qua quy trình DB Guard.


