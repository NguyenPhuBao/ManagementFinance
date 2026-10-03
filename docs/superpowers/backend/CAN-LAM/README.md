# Backend — CÒN 3 ĐƠN CHỜ XỬ LÝ (mục 31–33); 30 mục trước đã hoàn tất

**Cập nhật:** 2026-10-03 (phía client cập nhật theo yêu cầu người dùng: mục 0 liệt kê ba đơn đặt sau lần cập nhật 2026-10-01 của backend; phần lịch sử bên dưới giữ nguyên); 2026-10-01 (Backend hoàn tất 4 mục mới — 27-30 từ đợt soát gộp b350d40); 2026-09-27 (mục 26); 2026-09-26 (các mục 22-25); các đợt trước.

> 🎉 **CẬP NHẬT 2026-10-01 — 4 MỤC SOÁT GỘP B350D40 ĐÃ HOÀN TẤT:**
> - **Mục 27 (`SEED_TU_KHOA_GRAB.md`):** Sửa seed từ khoá `grab` về đúng danh mục Di chuyển (thay vì Ăn uống). Cập nhật `seed.js`, viết migration `14_fix_grab_keyword_category.sql`, cập nhật 2 hàng `Is_default=true` trên CSDL sản xuất.
> - **Mục 28 (`SOAT_SAU_GOP_B350D40.md`):** Sửa 2 lỗi code FHS: (1) bộ lọc DTI bỏ sót classify `'Vay/no'` — sửa `financial.snapshot.service.js` tách `allExpenses`/`regularExpenses`; (2) `trendVsLastMonth` hardcode `'0%'` — tính thực tế từ dữ liệu 90 ngày. Sửa bảo mật: ngừng lưu `accountNumber`/`amount` ngân hàng vào store user notification. Đồng bộ payload 3 sự kiện socket trong `Notification_Client-app.md`. Tất cả 98 tests PASS.
> - **Mục 29 (`D1_DOC_BIEN_DONG_XONG_SOAT.md`):** Cập nhật trạng thái Chức năng 3 trong `LogicBusinessAI.md` sang 🟢 Đã hoàn thành (Client-app, 2026-09-30). Sửa mô tả nguồn đọc: thông báo app MB Bank/MoMo/ZaloPay, không SMS.
> - **Mục 30 (`CLIENT_DOC_BIEN_DONG_THEM_VI_DIEN_TU.md`):** Ghi nhận D1 hoàn thành (kết hợp với mục 29). Đơn này là thông báo bối cảnh, không yêu cầu thêm hành động backend.
> Thư mục `CAN-LAM/` khi ấy (2026-10-01 09:16) **sạch — 0 đơn tồn đọng**. Từ chiều 2026-10-01 có thêm đơn mới — xem mục 0.

---

## 0. Còn phải làm (Hiện tại: **3** mục — 31, 32, 33)

> Mục 1–30 đã hoàn tất, lưu tại [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/README.md). Ba đơn dưới đây đặt **sau**
> lần cập nhật README ngày 2026-10-01 của backend, nên chưa từng có mặt ở bảng này. Client soát lại bằng mã ngày
> 2026-10-03: mục 31 **chưa có thay đổi nào** phía backend (tệp `financial.snapshot.service.js` sửa lần cuối `12f438d`,
> 2026-10-01 09:16 — đúng mã đơn đã soát).

| # | Tài liệu | Loại | Việc xin | Mức |
|---|---|---|---|---|
| **31** | [SOAT_SAU_GOP_A7C03B7.md](SOAT_SAU_GOP_A7C03B7.md) (2026-10-01) | đơn xin — **lỗi mã** + sửa chữ | (1) FHS: tập `allExpenses` gom nhóm `Vay/no` **không xét chiều tiền** — cho vay, thu nợ về, nhận tiền đi vay đều thành *trả nợ* (DTI) và *tiết kiệm* (50/30/20); (2) `trendVsLastMonth` trả **`'+100%'`** khi kỳ trước không có dữ liệu, thiếu ca test; (3) chữ còn lại của đơn `B350D40` §5 và đơn D1; (4) `database/14` mang **BOM**, chưa có trong danh sách áp của `CloudDeploy.md`; (5) README này từng ghi *"0 đơn tồn đọng"* khi đơn vẫn nằm trong thư mục | **cao** (1, 2) · thấp (3–5) |
| **32** | [CLIENT_CHIA_SE_BIEN_LAI.md](CLIENT_CHIA_SE_BIEN_LAI.md) (2026-10-02) | **thông báo** + hai câu hỏi có mặc định | Client thêm đường *chia sẻ biên lai* cho D1 (người dùng tự chia sẻ ảnh biên lai từ app ngân hàng, đọc chữ trên máy, không gửi gì lên server). **Không xin đổi mã, không migration, không trường đồng bộ mới**; backend chỉ cần ghi nhận và trả lời hai câu ở mục 4 — không trả lời thì client làm theo mặc định | thấp — ghi nhận |
| **33** | [SOAT_SAU_GOP_29E9A89.md](SOAT_SAU_GOP_29E9A89.md) (2026-10-03) | đơn xin — **lỗi mã** (bảo mật) | *AIOps Quarantine* (PR #109): (1) **một** 401 ở `/auth/refresh` là IP bị chặn 15 phút — đường bình thường của client (refresh hết hạn, tài khoản khoá / xoá); (2) IP lấy từ phần tử đầu `X-Forwarded-For` (tự khai, bỏ qua `trust proxy`) → chặn được IP người khác; (3) đếm theo IP phạt nhóm dùng chung (CGNAT; dev `adb reverse` = `127.0.0.1`); (4) thân 403 dùng `error` thay `code` | **cao** (1, 2) · vừa (3) · thấp (4) |

---

## 1. Trạng thái các mục đã xử lý (Gần nhất)

| # | Tài liệu gốc | Nội dung & Kết quả xử lý | Trạng thái |
|---|---|---|---|
| **22** | [CLIENT_BO_LIEN_KET_NGAN_HANG.md](../DA-XONG/CLIENT_BO_LIEN_KET_NGAN_HANG.md) | PO duyệt phương án giữ 100% mã nguồn làm nền tảng chuẩn hóa (ground truth) cho Client đối soát, không xóa mã backend. | ✅ Đã xong 100% |
| **23** | [AI_EDGE_SLM_SOAT_SAU_B147FEE.md](../DA-XONG/AI_EDGE_SLM_SOAT_SAU_B147FEE.md) | Sửa 12 điểm tự mâu thuẫn trong tài liệu `AI_Edge-SLM.md/Client-app.md`: khử mâu thuẫn RAM vs Canary GPU H3, chốt saving_goal_ratio, sửa nguồn is_recurring_hint, sửa cửa sổ thu nhập D1 sang cửa sổ cuộn `[max(now-90d, firstTx), now)`, sửa B2, D5, F3, G1, H1, H2, màn chat, và cảnh báo `nguongChiLon == 0`. Test 4 lệnh grep ra 0 dòng. | ✅ Đã xong 100% |
| **24** | [AI_PHAN_DINH_10_CHUC_NANG_SOAT_C47E6E2.md](../DA-XONG/AI_PHAN_DINH_10_CHUC_NANG_SOAT_C47E6E2.md) | Chuẩn hóa bảng 10 chức năng AI ở `LogicBusinessAI.md`, `Project.md` §8.5 & §11.42, `AI_ARCHITECTURE_DIAGRAM.md` v2.2 (4 dịch vụ, sửa nhãn payload), `Classify.md` §1.3, `ORC.md`. Chốt Lối A cho Chức năng 7 (Backend tự tính). Test 3 lệnh grep ra 0 dòng. | ✅ Đã xong 100% |
| **25** | [CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md](../DA-XONG/CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md) | Phản hồi chính thức 5 câu hỏi của Client: đồng thuận không vi phạm chính sách dừng module bank, giữ nguyên `provider = 'Manual'`, đồng ý regex baseline, bắt buộc Consent Screen theo NĐ 13/2023, xác nhận gộp trùng SMS/thông báo app là hiện thân Chức năng 3 phía Client. | ✅ Đã xong 100% |
| **26** | [CHATBOT_AI_CON_LECH_SAU_8BBDD97.md](../DA-XONG/CHATBOT_AI_CON_LECH_SAU_8BBDD97.md) | Khử dứt điểm 7 điểm lệch Chatbot AI theo rà soát Client-app: thống nhất gemini-3.8-flash, bỏ hằng nợ cứng & tính DTI thực tế, bổ sung context userName che PII, sửa Project.md 4 endpoints, bổ sung done.fallback vào ChatbotAI_Moblie.md, bỏ fake healthScore: 65 (trả 503/null minh bạch), sửa lọc ngân sách active và chuẩn hóa phân bổ 50/30/20 với Di chuyển/Chi khác. Vượt qua 100% lệnh nghiệm thu. | ✅ Đã xong 100% |

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
