# Backend & Client — DANH SÁCH CẦN LÀM (1 mục chờ Backend · 1 mục Client đã xong, chờ đóng)

**Cập nhật:** 2026-10-05 (Client-app soát mục 35 sau gộp `main` @ `b38367e`: đạt cả bốn mục, đặt **mục 36** cho một lỗi lách lớp bảo trì + bốn chỗ nhẹ; mục 34 Client-app đã làm xong). Trước đó 2026-10-04: Backend hoàn tất 100% mục 35 vá lỗ hổng logic; Mục 34 đã được PO trả lời/duyệt thiết kế.

> 📌 **HIỆN TRẠNG 2026-10-05:**
> - **Mục 36 (`SOAT_SAU_GOP_B38367E.md`) — MỚI, chờ Backend:** Client-app soát mã sau gộp `b38367e` (`node --test tests/unit/*.test.js` 166/166). Mục 35 đạt; còn **một lỗi mức vừa** — `maintenance.middleware.js` cho qua mọi URL **chứa** `/auth/login` kể cả trong query string (đo: `/api/sync/push?x=/auth/login` lọt khi bảo trì BẬT) — và bốn chỗ nhẹ (khoá dự phòng `'secret'`, `/api/admin/*` ưu tiên trước xác thực, cắt tải nhận môi trường test theo đường dẫn chứa `test`, CORS mở cho mọi project Vercel cùng tiền tố). Client-app không phải sửa gì.
> - **Mục 34:** Client-app đã **làm xong** tính năng nhắc ghi (2026-10-03, nghiệm thu Realme bản debug + release) — có thể chuyển sang `DA-XONG/`.

> 📌 **HIỆN TRẠNG 2026-10-04:**
> - **Mục 34 (`CLIENT_NHAC_SAU_APP_NGAN_HANG.md`):** Phía Client-app hỏi ý kiến thiết kế tính năng nhắc ghi sau khi dùng app ngân hàng $\ge$ 20s (`PACKAGE_USAGE_STATS`). PO đã phê duyệt: đồng ý với Client (100% on-device offline, không đòi thêm NĐ 13, bổ sung nguồn 3 vào tài liệu). Tệp nằm tại `CAN-LAM/` để Client-app tiến hành xây dựng và nghiệm thu chức năng trên máy.
> - **Mục 35 (`SOAT_UU_TIEN_ADMIN_VA_CHAN_IP.md`):** Đã vá triệt để 5 điểm yếu bảo mật logic phía Backend, vượt qua 30 unit tests và lưu trữ tại `DA-XONG/`.

---

## 0. Còn phải làm (Hiện tại: **1** mục chờ Backend · **1** mục Client đã xong, chờ đóng)

| # | Tài liệu | Trách nhiệm | Nội dung & Tiến độ | Trạng thái |
|---|---|---|---|---|
| **36** | [SOAT_SAU_GOP_B38367E.md](./SOAT_SAU_GOP_B38367E.md) | Backend | Lớp bảo trì cho qua URL chứa `/auth/login` trong query (mức vừa, có lệnh đo lại ở mục 1 của đơn); khoá dự phòng `'secret'` + kiểm `JWT_ACCESS_SECRET` lúc khởi động; bỏ ưu tiên `/api/admin/*` trước xác thực; bỏ vế `process.argv` ở lớp cắt tải; thu hẹp CORS Vercel (tuỳ chọn); thêm test nhánh bảo trì của `auth.service`. | ⏳ Chờ Backend |
| **34** | [CLIENT_NHAC_SAU_APP_NGAN_HANG.md](./CLIENT_NHAC_SAU_APP_NGAN_HANG.md) | Client-app | PO đã duyệt câu hỏi thiết kế (100% on-device offline, đồng bộ nguồn 3 vào Nguồn sự thật). Client-app **đã làm xong** 2026-10-03 (10 task, nghiệm thu Realme debug + release). | ✅ Client xong — chờ chuyển `DA-XONG/` |

---

## 1. Trạng thái các mục Backend đã xử lý (Gần nhất)

| # | Tài liệu gốc | Nội dung & Kết quả xử lý | Trạng thái |
|---|---|---|---|
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

**53** tài liệu (đếm bằng máy 2026-10-05 sau gộp `b38367e` — mục 35 đã chuyển sang; không tính `README.md`) đã được chuyển sang [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/README.md) và được kiểm chứng qua các bộ kiểm thử tự động, lệnh kiểm tra văn bản và đối soát mã nguồn.

---

## 3. Ranh giới trách nhiệm

Client-app **không sửa `src/Backend`**. Mọi việc cần backend đều được viết
thành tài liệu ở đây thay vì sửa thẳng. Nếu một mục nào đó đọc thấy vô lý hoặc
tốn hơn dự kiến, hãy ghi lại lý do vào chính tài liệu ấy — client sẽ đọc và tìm
đường vòng ở phía mình.
