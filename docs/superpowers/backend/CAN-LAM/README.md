# Backend & Client — DANH SÁCH CẦN LÀM (1 mục chờ Backend / Admin-web)

**Cập nhật:** 2026-10-07 — Client-app gộp `main` @ `1edab22`: Backend đã đóng **mục 34, 37, 38** (2026-10-06 tối) và chuyển sang `DA-XONG/`. README của lượt ấy viết trước khi có **mục 39** (Client-app đặt 2026-10-07) nên ghi *"0 mục"* — Client-app thêm lại mục 39.
- **Mục 37 (`KEO_VE_BO_SOT_BAN_GHI_DAY_MUON.md`):** ĐÃ XONG. Migration 20 bổ sung cột `Server_update_at`, chỉ mục và trigger tự gán giờ server cho 6 bảng đồng bộ (`category`, `wallet`, `budget`, `bill`, `goal`, `transaction`). `/sync/pull` và checkpoint `maxSince` lọc theo `Server_update_at`; giữ LWW theo `update_at`.
- **Mục 38 (`CLIENT_PREMIUM_PAYOS.md`):** ĐÃ XONG. `GET /api/payment/subscription-info` trả thêm `limits: { wallets: 3, budgets: 3, goals: 3 }`, `price: 49000`, `packageDays: 30`; đính chính 5 điểm lệch mã và bỏ cụm *đồng bộ tức thì* trong `CLIENT_INTEGRATION_GUIDE.md`.
- **Mục 34 (`CLIENT_NHAC_SAU_APP_NGAN_HANG.md`):** ĐÃ ĐÓNG & LƯU TRỮ (`DA-XONG/`).

> 📌 **HIỆN TRẠNG 2026-10-07:**
> - **Mục 39 (`PHAN_QUYEN_THEO_GOI_KHAO_SAT.md`) — chờ Backend / Admin-web, đầu vào cho bước 3–4 (không chặn client):** bốn loại chức năng; bảng phân quyền đang chạy ở client (3 ví · 3 ngân sách · 3 mục tiêu · Trợ lý AI + Nhập nhanh khoá với Basic); đề xuất trả `limits` + `features` ở `/payment/subscription-info`; năm câu hỏi có mặc định.
> - `CLIENT_INTEGRATION_GUIDE.md` trong thư mục này là **hướng dẫn** của Backend, không phải đơn xin.

---

## 0. Còn phải làm (Hiện tại: **1** mục)

| # | Tài liệu | Trách nhiệm | Nội dung & Tiến độ | Trạng thái |
|---|---|---|---|---|
| **39** | [PHAN_QUYEN_THEO_GOI_KHAO_SAT.md](./PHAN_QUYEN_THEO_GOI_KHAO_SAT.md) | Backend + Admin-web | Bước 1–2 của phân quyền chức năng động theo loại tài khoản: khảo sát đặc trưng chức năng (bốn loại), bảng phân quyền (giới hạn số lượng / khoá / không phân quyền), đề xuất hợp đồng `limits` + `features`, đường vòng qua trần, năm câu hỏi có mặc định. Bước 3 (CSDL) và 4 (Admin-web) do Backend thiết kế. | ⏳ Chờ Backend (không chặn) |

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
