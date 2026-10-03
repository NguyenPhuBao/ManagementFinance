# Backend — HOÀN TẤT TOÀN BỘ (Mục 1–33 đã hoàn tất 100%; 0 đơn tồn đọng)

**Cập nhật:** 2026-10-03 (Backend hoàn tất xử lý và nghiệm thu toàn diện 3 đơn 31, 32, 33 theo phê duyệt trực tiếp của Product Owner). Thư mục `CAN-LAM/` hiện hoàn toàn sạch sẽ — 0 đơn tồn đọng.

> 🎉 **CẬP NHẬT 2026-10-03 — 3 ĐƠN 31, 32, 33 ĐÃ HOÀN TẤT 100% THEO LỆNH CỦA PO:**
> - **Mục 31 (`SOAT_SAU_GOP_A7C03B7.md`):** Đã sửa triệt để 2 lỗi mã FHS: (1) `allExpenses` xét chuẩn chiều tiền `Vay/no` (tiền âm mới là trả nợ; loại trừ Cho vay / thu nợ khỏi DTI; tiền dương vay nợ không tính vào tiết kiệm 50/30/20); (2) `trendVsLastMonth` trả `null` minh bạch khi kỳ trước bằng 0, không bịa fake `+100%`, bổ sung đầy đủ test suite; (3) Khử sạch UTF-8 BOM khỏi `database/14_fix_grab_keyword_category.sql` và cập nhật danh sách áp trong `CloudDeploy.md`; (4) Sửa toàn bộ văn bản lệch: `Project.md`, `LogicBusinessAI.md`, `Classify.md`, `ChatbotAI_Moblie.md`, `AI_ARCHITECTURE_DIAGRAM.md`, `Notification_Client-app.md` (SQLite v27, 9 tools, Gemini 3.8 Flash, chuông badge số đếm).
> - **Mục 32 (`CLIENT_CHIA_SE_BIEN_LAI.md`):** Module Bank đã dừng hoàn toàn độc lập và không liên quan đến biên lai. Cập nhật `LogicBusinessAI.md` và `Project.md` bổ sung nguồn *"biên lai người dùng chia sẻ, đọc chữ trên máy qua Google ML Kit Text Recognition"* cạnh thông báo biến động số dư. Áp dụng cơ chế chia sẻ chủ động, 100% on-device offline, không gửi ra ngoài, không cần màn xin quyền riêng.
> - **Mục 33 (`SOAT_SAU_GOP_29E9A89.md`):** Khắc phục dứt điểm 4 điểm tồn tại của AIOps Quarantine: (1) Heuristic 4 chỉ kích hoạt khi thực sự có hành vi tái sử dụng token (`req.tokenReuseDetected`), không chặn các ca 401 thông thường; (2) IP lấy chuẩn xác qua `req.ip || req.socket?.remoteAddress` tuân thủ `trust proxy`, loại bỏ nguy cơ spoofing; (3) Miễn trừ loopback dev `127.0.0.1`, `::1`, `localhost` khi `NODE_ENV=development` bảo vệ môi trường test máy thật / adb reverse; (4) Thân HTTP 403 bổ sung chuẩn `code: 'AIOPS_QUARANTINED'`.

---

## 0. Còn phải làm (Hiện tại: **0** mục tồn đọng)

> Toàn bộ 33 mục yêu cầu kỹ thuật và soát xét đã được giải quyết triệt để và lưu trữ tại [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/README.md). Thư mục `CAN-LAM/` hiện không còn tài liệu tồn đọng nào cần giải quyết.

---

## 1. Trạng thái các mục đã xử lý (Gần nhất)

| # | Tài liệu gốc | Nội dung & Kết quả xử lý | Trạng thái |
|---|---|---|---|
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

**48** tài liệu (đếm bằng máy 2026-10-03, không tính `README.md`) đã được chuyển sang [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/README.md) và được kiểm chứng qua các bộ kiểm thử tự động, lệnh kiểm tra văn bản và đối soát mã nguồn.

---

## 3. Ranh giới trách nhiệm

Client-app **không sửa `src/Backend`**. Mọi việc cần backend đều được viết
thành tài liệu ở đây thay vì sửa thẳng. Nếu một mục nào đó đọc thấy vô lý hoặc
tốn hơn dự kiến, hãy ghi lại lý do vào chính tài liệu ấy — client sẽ đọc và tìm
đường vòng ở phía mình.
