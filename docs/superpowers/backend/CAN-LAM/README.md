# Backend & Client — DANH SÁCH CẦN LÀM (1 mục đang triển khai tại Client-app)

**Cập nhật:** 2026-10-04 (Backend hoàn tất 100% mục 35 vá lỗ hổng logic; Mục 34 đã được PO trả lời/duyệt thiết kế và đang lưu tại `CAN-LAM/` để Client-app xây dựng chức năng trên thiết bị).

> 📌 **HIỆN TRẠNG 2026-10-04:**
> - **Mục 34 (`CLIENT_NHAC_SAU_APP_NGAN_HANG.md`):** Phía Client-app hỏi ý kiến thiết kế tính năng nhắc ghi sau khi dùng app ngân hàng $\ge$ 20s (`PACKAGE_USAGE_STATS`). PO đã phê duyệt: đồng ý với Client (100% on-device offline, không đòi thêm NĐ 13, bổ sung nguồn 3 vào tài liệu). Tệp nằm tại `CAN-LAM/` để Client-app tiến hành xây dựng và nghiệm thu chức năng trên máy.
> - **Mục 35 (`SOAT_UU_TIEN_ADMIN_VA_CHAN_IP.md`):** Đã vá triệt để 5 điểm yếu bảo mật logic phía Backend, vượt qua 30 unit tests và lưu trữ tại `DA-XONG/`.

---

## 0. Còn phải làm (Hiện tại: **1** mục đang triển khai tại Client-app)

| # | Tài liệu | Trách nhiệm | Nội dung & Tiến độ | Trạng thái |
|---|---|---|---|---|
| **34** | [CLIENT_NHAC_SAU_APP_NGAN_HANG.md](./CLIENT_NHAC_SAU_APP_NGAN_HANG.md) | Client-app | PO đã duyệt câu hỏi thiết kế (100% on-device offline, đồng bộ nguồn 3 vào Nguồn sự thật); Client-app đang triển khai tính năng trên máy. | ⏳ Đang làm tại Client-app |

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

**52** tài liệu (đếm bằng máy 2026-10-04, không tính `README.md`) đã được chuyển sang [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/README.md) và được kiểm chứng qua các bộ kiểm thử tự động, lệnh kiểm tra văn bản và đối soát mã nguồn.

---

## 3. Ranh giới trách nhiệm

Client-app **không sửa `src/Backend`**. Mọi việc cần backend đều được viết
thành tài liệu ở đây thay vì sửa thẳng. Nếu một mục nào đó đọc thấy vô lý hoặc
tốn hơn dự kiến, hãy ghi lại lý do vào chính tài liệu ấy — client sẽ đọc và tìm
đường vòng ở phía mình.
