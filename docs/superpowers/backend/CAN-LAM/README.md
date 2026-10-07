# Backend & Client — DANH SÁCH CẦN LÀM (3 mục chờ Backend · 1 mục Client đã xong, chờ đóng)

**Cập nhật:** 2026-10-07 — Client-app đặt **mục 39** `PHAN_QUYEN_THEO_GOI_KHAO_SAT.md` (thông tin đầu vào, không chặn client): khảo sát chức năng + bảng phân quyền theo loại tài khoản (bước 1–2) cho việc phân quyền động ở CSDL + Admin-web (bước 3–4). Trước đó 2026-10-06 chiều — Client-app đặt **mục 38** `CLIENT_PREMIUM_PAYOS.md` (mức thấp, **không chặn client**): thông báo client thi hành đặc quyền Premium ở client; xin `limits · price · packageDays` trong `/payment/subscription-info` (có mặc định); năm chỗ `CLIENT_INTEGRATION_GUIDE.md` lệch mã (`payment.success` → `account.upgraded`, return URL sang web Admin, `localhost:10000`, `http` → Dio, `type` → `accountType`); xin bỏ chữ *đồng bộ tức thì*. Sáng cùng ngày: Client-app gộp `main` @ `872462f` (Backend đóng **mục 36**, chuyển `DA-XONG/`; **mục 37** vẫn chờ — README lượt `872462f` làm rơi nó, Client-app thêm lại). Trước đó 2026-10-05: Backend hoàn thành **Mục 36**; Client-app đặt **mục 37**; mục 34 Client-app đã làm xong.

> 📌 **HIỆN TRẠNG 2026-10-07:**
> - **Mục 39 (`PHAN_QUYEN_THEO_GOI_KHAO_SAT.md`) — chờ Backend / Admin-web, đầu vào cho bước 3–4:** bốn loại chức năng; bảng phân quyền đang chạy ở client (3 ví · 3 ngân sách · 3 mục tiêu · Trợ lý AI + Nhập nhanh khoá với Basic); đề xuất trả `limits` + `features` ở `/payment/subscription-info`; năm câu hỏi có mặc định.
> - **Mục 38 (`CLIENT_PREMIUM_PAYOS.md`) — chờ Backend, mức thấp:** client đã tích hợp PayOS theo MÃ (không theo hướng dẫn ở năm chỗ lệch); xin ba trường nhỏ có mặc định và sửa chữ hướng dẫn. Không chặn client.
> - **Mục 37 (`KEO_VE_BO_SOT_BAN_GHI_DAY_MUON.md`) — chờ Backend, mức cao:** `/sync/pull` lọc `update_at > since` mà `update_at` là giờ ghi **của máy** (cũng là khoá LWW), nên bản ghi lên server **muộn hơn giờ ghi** (máy offline lâu) rơi dưới mốc của máy khác và **không bao giờ** được kéo. Xin cột giờ-server riêng cho việc kéo; không đổi LWW.
> - **Mục 36 (`DA-XONG/SOAT_SAU_GOP_B38367E.md`) — ĐÃ HOÀN THÀNH 100%:** Backend đã khắc phục trọn vẹn: vá lách query string bảo trì, loại bỏ fallback `'secret'`, bỏ gán `req.isAdmin` theo URL path trước xác thực, sửa nhận diện test load-shedding, siết CORS, bổ sung 3 ca test bảo trì auth. Toàn bộ 220/220 unit tests PASS 100%.
> - **Mục 34:** Client-app đã **làm xong** tính năng nhắc ghi (2026-10-03, nghiệm thu Realme bản debug + release) — có thể chuyển sang `DA-XONG/`.

---

## 0. Còn phải làm (Hiện tại: **3** mục chờ Backend · **1** mục Client đã xong, chờ đóng)

| # | Tài liệu | Trách nhiệm | Nội dung & Tiến độ | Trạng thái |
|---|---|---|---|---|
| **39** | [PHAN_QUYEN_THEO_GOI_KHAO_SAT.md](./PHAN_QUYEN_THEO_GOI_KHAO_SAT.md) | Backend + Admin-web | Bước 1–2 của phân quyền chức năng động theo loại tài khoản: khảo sát đặc trưng chức năng (bốn loại), bảng phân quyền (giới hạn số lượng / khoá / không phân quyền), đề xuất hợp đồng `limits` + `features`, đường vòng qua trần, năm câu hỏi có mặc định. Bước 3 (CSDL) và 4 (Admin-web) do Backend thiết kế. | ⏳ Chờ Backend (không chặn) |
| **38** | [CLIENT_PREMIUM_PAYOS.md](./CLIENT_PREMIUM_PAYOS.md) | Backend (nhẹ) | Client thi hành đặc quyền Premium (3 ví · 3 ngân sách · 3 mục tiêu · Trợ lý AI + Nhập nhanh) ở client — backend không cần chặn. Xin `limits · price · packageDays` trong `/payment/subscription-info` (client có mặc định, không chờ); sửa năm chỗ `CLIENT_INTEGRATION_GUIDE.md` lệch mã; bỏ chữ *đồng bộ tức thì*. Tuỳ chọn: trang "quay lại app" cho return URL. | ⏳ Chờ Backend (không chặn) |
| **37** | [KEO_VE_BO_SOT_BAN_GHI_DAY_MUON.md](./KEO_VE_BO_SOT_BAN_GHI_DAY_MUON.md) | Backend | Thêm cột giờ-server (`Server_update_at`, đặt `now()` ở mọi lần ghi) cho sáu bảng đồng bộ; `/sync/pull` lọc và trả theo cột ấy; giữ `update_at` cho LWW. Đo: máy A thiếu hai giao dịch của máy B (server có đủ). Client đổi mốc kéo về sau khi backend xong. | ⏳ Chờ Backend |
| **34** | [CLIENT_NHAC_SAU_APP_NGAN_HANG.md](./CLIENT_NHAC_SAU_APP_NGAN_HANG.md) | Client-app | PO đã duyệt câu hỏi thiết kế (100% on-device offline, đồng bộ nguồn 3 vào Nguồn sự thật). Client-app **đã làm xong** 2026-10-03 (10 task, nghiệm thu Realme debug + release). | ✅ Client xong — chờ chuyển `DA-XONG/` |

---

## 1. Trạng thái các mục Backend đã xử lý (Gần nhất)

| # | Tài liệu gốc | Nội dung & Kết quả xử lý | Trạng thái |
|---|---|---|---|
| **36** | [SOAT_SAU_GOP_B38367E.md](../DA-XONG/SOAT_SAU_GOP_B38367E.md) | Vá lách query bảo trì, loại bỏ fallback 'secret', bỏ req.isAdmin theo URL path, chuẩn hóa load-shedding test env, siết CORS, bổ sung 3 ca test login bảo trì. Test PASS 220/220 (100%). | ✅ Đã xong 100% |
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

**53** tài liệu (đếm bằng máy 2026-10-06 sau gộp `872462f` — mục 36 đã chuyển sang; không tính `README.md`. Mốc cũ ghi 53 cho lượt `b38367e` là đếm lệch một — bản trước gộp này có 52) đã được chuyển sang [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/README.md) và được kiểm chứng qua các bộ kiểm thử tự động, lệnh kiểm tra văn bản và đối soát mã nguồn.

---

## 3. Ranh giới trách nhiệm

Client-app **không sửa `src/Backend`**. Mọi việc cần backend đều được viết
thành tài liệu ở đây thay vì sửa thẳng. Nếu một mục nào đó đọc thấy vô lý hoặc
tốn hơn dự kiến, hãy ghi lại lý do vào chính tài liệu ấy — client sẽ đọc và tìm
đường vòng ở phía mình.
