# Backend & Client — DANH SÁCH CẦN LÀM (0 mục tồn đọng — ĐÃ HOÀN TẤT 100%)

**Cập nhật:** 2026-10-07 tối — Toàn bộ chuỗi 5 bước phát triển tính năng **Phân quyền tính năng động theo loại tài khoản** (Mục 39) đã hoàn tất 100% trên cả 3 phân hệ: CSDL Supabase (Migration 22), Backend Node.js (`permission.repository.js`, API `/permissions`, API `/subscription-info`), Admin-web (trang `/permissions`), và Client-app Flutter (`TranGoi`, `TrangThaiGoi`, UI guards AI Chat & Nhập nhanh). Hiện tại **0 mục tồn đọng**.

- **Mục 39 (`PHAN_QUYEN_THEO_GOI_KHAO_SAT.md`):** ĐÃ XONG 100%. Đã triển khai đầy đủ 5 bước: CSDL bảng `feature` và `account_type_permission`, API Admin ma trận quyền, trang `/permissions` Admin-web, và ràng buộc động Client-app Flutter. 256/256 tests Backend PASS, 60/60 tests Admin-web PASS, 100% tests Client-app PASS.
- **Mục 40 (`SERVER_UPDATE_AT_HAI_DONG_HO.md`):** ĐÃ XONG. Migration 21 sửa trigger `set_server_update_at()` và DEFAULT của 6 bảng đồng bộ thành `(now() AT TIME ZONE 'UTC')`. Độ lệch trigger đo thực tế là 0 ms. 246/246 tests PASS 100%. Đã lưu trữ sang `DA-XONG/`.
- **Mục 37 (`KEO_VE_BO_SOT_BAN_GHI_DAY_MUON.md`):** ĐÃ XONG. Migration 20 bổ sung cột `Server_update_at`, chỉ mục và trigger tự gán giờ server cho 6 bảng đồng bộ. Đã lưu trữ sang `DA-XONG/`.
- **Mục 38 (`CLIENT_PREMIUM_PAYOS.md`):** ĐÃ XONG. `GET /api/payment/subscription-info` trả thêm `limits`, `price`, `packageDays`. Đã lưu trữ sang `DA-XONG/`.
- **Mục 34 (`CLIENT_NHAC_SAU_APP_NGAN_HANG.md`):** ĐÃ ĐÓNG & LƯU TRỮ (`DA-XONG/`).

> 📌 **HIỆN TRẠNG 2026-10-07:**
> - Toàn bộ các yêu cầu tích hợp giữa Backend, Admin-web và Client-app đã được hoàn tất và thẩm định thực tế.
> - `CLIENT_INTEGRATION_GUIDE.md` trong thư mục này là **hướng dẫn** của Backend, không phải đơn xin.

---

## 0. Còn phải làm (Hiện tại: **0** mục)

| # | Tài liệu | Trách nhiệm | Nội dung & Tiến độ | Trạng thái |
|---|---|---|---|---|
| — | Không còn mục tồn đọng | — | Toàn bộ 40 mục kỹ thuật đã hoàn thành | ✅ ĐÃ HOÀN TẤT |

---

## 1. Trạng thái các mục Backend đã xử lý (Gần nhất)

| # | Tài liệu gốc | Nội dung & Kết quả xử lý | Trạng thái |
|---|---|---|---|
| **39** | [PHAN_QUYEN_THEO_GOI_KHAO_SAT.md](./PHAN_QUYEN_THEO_GOI_KHAO_SAT.md) | Phân quyền tính năng động theo loại tài khoản: CSDL Migration 22, API Admin, Trang `/permissions` Admin-web, Ràng buộc Client-app (`TranGoi`, `TrangThaiGoi`, AI Chat & Nhập nhanh). | ✅ Đã xong 100% |
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
