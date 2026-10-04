# Backend — HOÀN TẤT TOÀN BỘ (Mục 1–35 đã hoàn tất 100%; 0 đơn tồn đọng)

**Cập nhật:** 2026-10-04 (Backend hoàn tất xử lý và nghiệm thu toàn diện mục 34 và 35 theo phê duyệt trực tiếp của Product Owner). Thư mục `CAN-LAM/` hiện hoàn toàn sạch sẽ — 0 đơn tồn đọng.

> 🎉 **CẬP NHẬT 2026-10-04 — 2 ĐƠN 34 & 35 ĐÃ HOÀN TẤT 100% THEO PHÊ DUYỆT CỦA PO:**
> - **Mục 34 (`CLIENT_NHAC_SAU_APP_NGAN_HANG.md`):** PO duyệt đồng ý với Client về quyền riêng tư & Nghị định 13/2023/NĐ-CP (100% on-device offline, không gửi dữ liệu ra ngoài, không đòi thêm điều kiện). Đã đồng bộ tài liệu nguồn sự thật (Single Source of Truth): bổ sung nguồn thứ 3 (*nhắc ghi sau khi dùng app ngân hàng $\ge$ 20s, quyền PACKAGE_USAGE_STATS*) vào `LogicBusinessAI.md` (Chức năng 3), `docs/progress/Client-app.md` (§15) và `Project.md` (§11.62). Chuyển sang `DA-XONG/`.
> - **Mục 35 (`SOAT_UU_TIEN_ADMIN_VA_CHAN_IP.md`):** Đã vá triệt để 5 điểm yếu bảo mật logic: (1) Xóa bỏ logic tự khai `x-client-platform` / Origin cấp `req.isAdmin`; (2) Xóa bỏ Fast-lane 2 trong AIOps Quarantine; (3) Chuyển `jwt.decode` sang `jwt.verify(token, secret)` trong `admin-priority.middleware.js` và `rate-limiter.js`; (4) Dùng `crypto.timingSafeEqual` an toàn; (5) Bắt `/auth/login` qua chế độ bảo trì và gắn trực tiếp `authLimiter` vào route xác thực công khai. Đã gỡ bypass trong `authLimiter.skip`. Toàn bộ test suite PASS 100%.

---

## 0. Còn phải làm (Hiện tại: **0** mục tồn đọng)

> Toàn bộ 35 mục yêu cầu kỹ thuật và soát xét đã được giải quyết triệt để và lưu trữ tại [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/README.md). Thư mục `CAN-LAM/` hiện không còn tài liệu tồn đọng nào cần giải quyết.

---

## 1. Trạng thái các mục đã xử lý (Gần nhất)

| # | Tài liệu gốc | Nội dung & Kết quả xử lý | Trạng thái |
|---|---|---|---|
| **34** | [CLIENT_NHAC_SAU_APP_NGAN_HANG.md](../DA-XONG/CLIENT_NHAC_SAU_APP_NGAN_HANG.md) | PO duyệt đồng ý với Client (100% on-device, không đòi thêm NĐ 13); đã đồng bộ nguồn 3 vào LogicBusinessAI.md, progress/Client-app.md, Project.md. | ✅ Đã xong 100% |
| **35** | [SOAT_UU_TIEN_ADMIN_VA_CHAN_IP.md](../DA-XONG/SOAT_UU_TIEN_ADMIN_VA_CHAN_IP.md) | Xóa bỏ ưu tiên tự khai header, xóa Fast-lane 2 AIOps, chuyển sang jwt.verify, timingSafeEqual, bảo trì login, authLimiter chuẩn. Test PASS 100%. | ✅ Đã xong 100% |
| **31** | [SOAT_SAU_GOP_A7C03B7.md](../DA-XONG/SOAT_SAU_GOP_A7C03B7.md) | Sửa dứt điểm 2 lỗi mã FHS (`allExpenses` chiều tiền Vay/no, `trendVsLastMonth` null), khử BOM file SQL 14, cập nhật CloudDeploy.md, chuẩn hóa toàn diện tài liệu (v27, 9 tools, Gemini 3.8 Flash). Test FHS PASS 100%. | ✅ Đã xong 100% |
| **32** | [CLIENT_CHIA_SE_BIEN_LAI.md](../DA-XONG/CLIENT_CHIA_SE_BIEN_LAI.md) | Module Bank đã dừng độc lập, cập nhật tài liệu ăn khớp với cơ chế chia sẻ biên lai on-device ML Kit của Client-app. | ✅ Đã xong 100% |
| **33** | [SOAT_SAU_GOP_29E9A89.md](../DA-XONG/SOAT_SAU_GOP_29E9A89.md) | Khắc phục dứt điểm AIOps Quarantine: Heuristic 4 lọc đúng tokenReuseDetected, IP an toàn qua req.ip, miễn trừ loopback dev, chuẩn hóa code HTTP 403. Test PASS 100%. | ✅ Đã xong 100% |
| **27** | [SEED_TU_KHOA_GRAB.md](../DA-XONG/SEED_TU_KHOA_GRAB.md) | Sửa seed grab về Di chuyển, migration 14, update CSDL sản xuất. | ✅ Đã xong 100% |
| **28** | [SOAT_SAU_GOP_B350D40.md](../DA-XONG/SOAT_SAU_GOP_B350D40.md) | Sửa lỗi FHS DTI, bảo mật store user notification, đồng bộ payload socket. | ✅ Đã xong 100% |
| **29** | [D1_DOC_BIEN_DONG_XONG_SOAT.md](../DA-XONG/D1_DOC_BIEN_DONG_XONG_SOAT.md) | Cập nhật Chức năng 3 hoàn thành, đọc thông báo app MB/MoMo/ZaloPay. | ✅ Đã xong 100% |
| **30** | [CLIENT_DOC_BIEN_DONG_THEM_VI_DIEN_TU.md](../DA-XONG/CLIENT_DOC_BIEN_DONG_THEM_VI_DIEN_TU.md) | Ghi nhận hoàn thành D1. | ✅ Đã xong 100% |

*(Các mục từ 1 đến 21 xem chi tiết tại [`docs/superpowers/backend/DA-XONG/README.md`](../DA-XONG/README.md))*

---

## 2. Trạng thái toàn bộ tài liệu kỹ thuật (Đã lưu trữ tại `DA-XONG/`)

**53** tài liệu (đếm bằng máy 2026-10-04, không tính `README.md`) đã được chuyển sang [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/README.md) và được kiểm chứng qua các bộ kiểm thử tự động, lệnh kiểm tra văn bản và đối soát mã nguồn.

---

## 3. Ranh giới trách nhiệm

Client-app **không sửa `src/Backend`**. Mọi việc cần backend đều được viết
thành tài liệu ở đây thay vì sửa thẳng. Nếu một mục nào đó đọc thấy vô lý hoặc
tốn hơn dự kiến, hãy ghi lại lý do vào chính tài liệu ấy — client sẽ đọc và tìm
đường vòng ở phía mình.
