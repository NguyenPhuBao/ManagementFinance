# Backend & Client — DANH SÁCH CẦN LÀM (0 mục chờ Backend · 0 mục chờ Client — SẠCH SẼ 100%)

**Cập nhật:** 2026-10-06 tối — Backend đã hoàn thành toàn bộ các mục tồn đọng:
- **Mục 37 (`KEO_VE_BO_SOT_BAN_GHI_DAY_MUON.md`):** ĐÃ XONG 100%. Áp dụng Migration 20 bổ sung cột `Server_update_at`, chỉ mục hiệu năng và triggers tự động gán giờ server cho 6 bảng đồng bộ (`category`, `wallet`, `budget`, `bill`, `goal`, `transaction`). Cập nhật `sync.repository.js` và `sync.service.js` lọc `/sync/pull` và checkpoint `maxSince` theo `Server_update_at`. Giữ nguyên LWW theo `update_at`. Test Pass 100%.
- **Mục 38 (`CLIENT_PREMIUM_PAYOS.md`):** ĐÃ XONG 100%. Mở rộng API `GET /api/payment/subscription-info` trả thêm `limits: { wallets: 3, budgets: 3, goals: 3 }`, `price: 49000`, `packageDays: 30`. Đính chính 5 điểm lệch mã và bỏ cụm từ *đồng bộ tức thì* trong `CLIENT_INTEGRATION_GUIDE.md`. Test Pass 100%.
- **Mục 34 (`CLIENT_NHAC_SAU_APP_NGAN_HANG.md`):** ĐÃ ĐÓNG & LƯU TRỮ. Client-app đã nghiệm thu 2026-10-03, PO duyệt 100% on-device offline. Đã chuyển sang `DA-XONG/`.

> 📌 **HIỆN TRẠNG 2026-10-06 (TỐI):**
> - **CAN-LAM hiện tại: 0 mục tồn đọng.** Toàn bộ các yêu cầu giữa Backend và Client-app đều đã được giải quyết trọn vẹn, không còn nợ kỹ thuật.

---

## 0. Còn phải làm (Hiện tại: **0** mục)

| # | Tài liệu | Trách nhiệm | Nội dung & Tiến độ | Trạng thái |
|---|---|---|---|---|
| — | *(Hiện tại không có mục nào đang chờ xử lý)* | — | Hệ thống đồng bộ và thanh toán hoạt động trơn tru | ✅ Tất cả đã xong |

---

## 1. Trạng thái các mục Backend đã xử lý (Gần nhất)

| # | Tài liệu gốc | Nội dung & Kết quả xử lý | Trạng thái |
|---|---|---|---|
| **38** | [CLIENT_PREMIUM_PAYOS.md](../DA-XONG/CLIENT_PREMIUM_PAYOS.md) | Thêm `limits, price, packageDays` vào `/subscription-info`; đính chính 5 điểm lệch mã PayOS; bỏ chữ đồng bộ tức thì. Test PASS 100%. | ✅ Đã xong 100% |
| **37** | [KEO_VE_BO_SOT_BAN_GHI_DAY_MUON.md](../DA-XONG/KEO_VE_BO_SOT_BAN_GHI_DAY_MUON.md) | Thêm cột `Server_update_at`, index và trigger cho 6 bảng đồng bộ (Migration 20); `/sync/pull` và `maxSince` dùng `Server_update_at`; giữ LWW theo `update_at`. Test PASS 100%. | ✅ Đã xong 100% |
| **34** | [CLIENT_NHAC_SAU_APP_NGAN_HANG.md](../DA-XONG/CLIENT_NHAC_SAU_APP_NGAN_HANG.md) | Nhắc ghi sau khi dùng app ngân hàng $\ge$ 20s (100% on-device offline, tuân thủ NĐ 13/2023/NĐ-CP). Đã hoàn tất và lưu trữ. | ✅ Đã xong 100% |
| **36** | [SOAT_SAU_GOP_B38367E.md](../DA-XONG/SOAT_SAU_GOP_B38367E.md) | Vá lách query bảo trì, loại bỏ fallback 'secret', bỏ req.isAdmin theo URL path, chuẩn hóa load-shedding test env, siết CORS, bổ sung 3 ca test login bảo trì. Test PASS 100%. | ✅ Đã xong 100% |
| **35** | [SOAT_UU_TIEN_ADMIN_VA_CHAN_IP.md](../DA-XONG/SOAT_UU_TIEN_ADMIN_VA_CHAN_IP.md) | Xóa bỏ ưu tiên tự khai header, xóa Fast-lane 2 AIOps, chuyển sang jwt.verify, timingSafeEqual, bảo trì login, authLimiter chuẩn. Test PASS 100%. | ✅ Đã xong 100% |
| **31** | [SOAT_SAU_GOP_A7C03B7.md](../DA-XONG/SOAT_SAU_GOP_A7C03B7.md) | Sửa dứt điểm 2 lỗi mã FHS (`allExpenses` chiều tiền Vay/no, `trendVsLastMonth` null), khử BOM file SQL 14, cập nhật CloudDeploy.md, chuẩn hóa toàn diện tài liệu (v27, 9 tools, Gemini 3.8 Flash). Test FHS PASS 100%. | ✅ Đã xong 100% |

*(Các mục từ 1 đến 33 xem chi tiết tại [`docs/superpowers/backend/DA-XONG/README.md`](../DA-XONG/README.md))*

---

## 2. Trạng thái toàn bộ tài liệu kỹ thuật (Đã lưu trữ tại `DA-XONG/`)

Toàn bộ **56** tài liệu kỹ thuật đã được kiểm chứng và lưu trữ tại [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/README.md).

---

## 3. Ranh giới trách nhiệm

Client-app **không sửa `src/Backend`**. Mọi việc cần backend đều được viết
thành tài liệu ở đây thay vì sửa thẳng. Nếu một mục nào đó đọc thấy vô lý hoặc
tốn hơn dự kiến, hãy ghi lại lý do vào chính tài liệu ấy — client sẽ đọc và tìm
đường vòng ở phía mình.
