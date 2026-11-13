# Khảo sát pháp lý bảo vệ dữ liệu và an ninh mạng (2026-11-13)

Mục đích: đối chiếu FlowMoney (Backend, Admin-web, CSDL) với khung pháp lý đang có hiệu lực, làm nền cho việc sửa `Data_Security.md` và hệ thống.
Tình trạng nguồn: văn bản gốc trên cổng chính thức không truy cập được trong lần khảo sát này (vbpl.moj.gov.vn lỗi DNS, thuvienphapluat.vn trả 403, bản PDF của EY bị mã hóa). Các điểm dưới đây lấy từ nguồn thứ cấp (cổng công an tỉnh, Bộ Công an, LuatVietnam, Thư viện Pháp luật, hãng luật). Cột "Mức xác minh": **khớp nhiều nguồn** = từ hai nguồn độc lập trở lên nêu giống nhau; **một nguồn** = chỉ một nguồn, cần đối chiếu văn bản gốc trước khi viết vào tài liệu chính thức. Đây không phải ý kiến pháp lý.

## 1. Văn bản đang có hiệu lực

| Văn bản | Hiệu lực | Thay thế | Mức xác minh |
|---|---|---|---|
| Luật Bảo vệ dữ liệu cá nhân, số 91/2025/QH15 (ban hành 26/6/2025) | 01/01/2026 | (Nghị định 13/2023/NĐ-CP bị thay bởi Nghị định 356/2025) | khớp nhiều nguồn |
| Nghị định 356/2025/NĐ-CP hướng dẫn Luật 91/2025 (ban hành 31/12/2025) | 01/01/2026 | Nghị định 13/2023/NĐ-CP | khớp nhiều nguồn |
| Luật An ninh mạng 2025, số 116/2025/QH15 (thông qua 10/12/2025, 8 chương 45 điều) | 01/7/2026 | Luật An ninh mạng 2018 (24/2018/QH14) và Luật An toàn thông tin mạng 2015 (86/2015/QH13) | khớp nhiều nguồn |
| Nghị định 333/2026/NĐ-CP hướng dẫn Luật An ninh mạng 2025 | 19/8/2026 | Dự thảo nêu thay Nghị định 53/2022; bản chính thức chưa xác nhận | một nguồn (thay thế) |
| Nghị định 330/2026/NĐ-CP xử phạt vi phạm hành chính về an ninh mạng và bảo vệ dữ liệu cá nhân | 19/8/2026 | — | khớp nhiều nguồn |
| Nghị định 327, 328, 329, 331, 332/2026/NĐ-CP (các mảng khác của Luật An ninh mạng) | 19/8/2026 | — | một nguồn |

Hệ quả: các căn cứ `Data_Security.md` đang trích (Nghị định 13/2023, Luật An ninh mạng 2018, Nghị định 53/2022) đã hết hiệu lực hoặc bị thay.

## 2. Nghĩa vụ liên quan tới FlowMoney

| # | Nghĩa vụ | Căn cứ | Mức xác minh |
|---|---|---|---|
| L1 | Dữ liệu phản ánh **hoạt động, lịch sử trên không gian mạng, theo dõi hành vi, sử dụng dịch vụ trực tuyến** chuyển sang nhóm **nhạy cảm**; thông tin đăng nhập ngân hàng, thẻ, **lịch sử giao dịch** cũng là nhạy cảm | Nghị định 356/2025 (danh mục nhạy cảm) | khớp nhiều nguồn |
| L2 | Với dữ liệu nhạy cảm: đặt giới hạn truy cập, quy trình xử lý, biện pháp bảo mật; **thông báo cho chủ thể biết dữ liệu nhạy cảm của họ đang được xử lý** (không thông báo bị xử phạt) | Nghị định 356/2025; Nghị định 330/2026 | khớp nhiều nguồn |
| L3 | Sự đồng ý gắn mục đích cụ thể, thể hiện bằng văn bản / giọng nói / đánh dấu (ô đánh dấu sẵn không hợp lệ); **bên kiểm soát lưu bằng chứng đồng ý** và chịu trách nhiệm chứng minh | Nghị định 356/2025 Điều 6 | khớp nhiều nguồn |
| L4 | Thời hạn trả lời yêu cầu của chủ thể: rút đồng ý / hạn chế / phản đối 2 ngày làm việc; ngừng xử lý 15 ngày (20 nếu có bên xử lý); xem, sửa, cung cấp dữ liệu 10 ngày (15); **xóa 20 ngày (30 nếu có bên xử lý)**; được gia hạn một lần có giải thích | Nghị định 356/2025 Điều 5 | một nguồn (LuatVietnam) |
| L5 | **Thông báo vi phạm cho cơ quan chuyên trách chậm nhất 72 giờ** kể từ khi phát hiện vi phạm có thể gây tổn hại | Luật 91/2025 Điều 23 | khớp nhiều nguồn |
| L6 | **Hồ sơ đánh giá tác động xử lý dữ liệu cá nhân**: lập và gửi cơ quan chuyên trách trong **60 ngày** kể từ ngày bắt đầu xử lý; cập nhật khi thay đổi | Luật 91/2025 Điều 21, 22 | khớp nhiều nguồn |
| L7 | Lưu dữ liệu trong thời gian phù hợp với mục đích xử lý, trừ khi luật khác quy định | Luật 91/2025 | một nguồn (bản dịch) |
| L8 | Nhật ký hệ thống đủ thông tin xác định phiên kết nối, lưu **tối thiểu 12 tháng** | Nghị định 333/2026 | một nguồn (HM&P), cần đọc văn bản gốc để biết đối tượng áp dụng |
| L9 | Lưu dữ liệu người dùng tại Việt Nam tối thiểu 24 tháng: theo bài phân tích, Điều 19 chỉ áp dụng **có điều kiện với doanh nghiệp nước ngoài** (khi có quyết định của Bộ trưởng Bộ Công an) | Nghị định 333/2026 Điều 19 | một nguồn; nghĩa vụ với doanh nghiệp trong nước chưa xác minh |
| L10 | Xác thực người dùng khi đăng ký tài khoản số bằng số điện thoại di động Việt Nam (hoặc số định danh cá nhân) | Nghị định 333/2026 Điều 16 | một nguồn; cần xác minh đối tượng áp dụng |
| L11 | Nhân sự bảo vệ dữ liệu: tối thiểu cao đẳng, 2 năm kinh nghiệm, được đào tạo | Nghị định 356/2025 Điều 13 | một nguồn |
| L12 | Mức phạt: tối đa 3 tỷ đồng với tổ chức (cá nhân bằng một nửa); mua bán dữ liệu 2–10 lần khoản thu; chuyển dữ liệu xuyên biên giới tới 5% doanh thu năm trước; không thông báo cơ quan chuyên trách 20–40 triệu đồng; thời hiệu 1 năm | Luật 91/2025; Nghị định 330/2026 | khớp nhiều nguồn (mức tối đa); một nguồn (từng hành vi) |
| L13 | IP gắn tài khoản là dữ liệu cá nhân; xử lý vì an ninh mạng là lợi ích chính đáng nếu cần thiết, tương xứng (tham chiếu quốc tế) | GDPR Recital 49; phán quyết Breyer C-582/14 | khớp nhiều nguồn |

## 3. Đối chiếu với hệ thống (đọc mã ngày 2026-11-13)

| # | Hiện trạng | Nghĩa vụ | Đánh giá |
|---|---|---|---|
| C1 | `Data_Security.md` trích Nghị định 13/2023, Luật An ninh mạng 2018, Nghị định 53/2022 | §1 | Lỗi thời, phải cập nhật căn cứ |
| C2 | Lịch sử thiết bị / IP (`account_device_history`), nhật ký kiểm toán, giao dịch người dùng tự ghi (`transaction`) đang xếp như dữ liệu thường hoặc "cơ bản" | L1 | Phải xếp lại là nhạy cảm (ít nhất lịch sử thiết bị / IP; giao dịch: nên xếp nhạy cảm theo hướng thận trọng) |
| C3 | CSDL không có bảng hay cột lưu bằng chứng đồng ý (`grep consent` trong `schema.prisma` rỗng); chưa thấy thông báo xử lý dữ liệu nhạy cảm | L2, L3 | Thiếu. Cần bảng lưu đồng ý (ai, khi nào, phiên bản chính sách, mục đích) và API ghi; màn hình đồng ý thuộc Client-app (báo thành viên client) |
| C4 | Xóa tài khoản: 30 ngày ân hạn `PendingDelete` rồi mới xóa, ẩn danh | L4 | Có thể vượt 20 ngày. Cần xác định lại: 30 ngày ân hạn do người dùng chọn có được tính là "đang xử lý yêu cầu xóa" không; nếu không, rút còn ≤ 20 ngày hoặc ghi rõ căn cứ gia hạn |
| C5 | Giữ `transaction` 5 năm sau khi xóa, căn cứ "Luật Kế toán 2015" | L4, L7 | Căn cứ đáng ngờ: Luật Kế toán áp cho sổ sách của đơn vị kế toán, không phải sổ thu chi cá nhân người dùng tự ghi. Giữ lại sau khi người dùng xin xóa có thể trái quyền xóa. Cần Chủ dự án quyết, đề xuất xóa / ẩn danh theo yêu cầu, chỉ giữ dữ liệu thanh toán gói dịch vụ (`payment_order`, `payment_transaction`) theo nghĩa vụ hóa đơn |
| C6 | Chưa có API cho người dùng tải / xem toàn bộ dữ liệu của mình | L4 | Thiếu (quyền xem, cung cấp dữ liệu, 10 ngày). Có thể làm API xuất JSON; giao diện ở Client-app |
| C7 | AIOps phát hiện tấn công, nhưng chưa có quy trình ghi nhận sự cố dữ liệu và đồng hồ 72 giờ | L5 | Thiếu quy trình. Đề xuất: tài liệu quy trình + mục "Sự cố dữ liệu" (ghi thời điểm phát hiện, hạn 72 giờ, trạng thái đã báo) ở Admin-web |
| C8 | Chưa có hồ sơ đánh giá tác động xử lý dữ liệu | L6 | Thiếu tài liệu. Đề xuất soạn bản nháp hồ sơ theo mẫu Nghị định 356 (cần mẫu gốc) |
| C9 | Lịch sử thiết bị: IP đầy đủ mã hóa, xem bằng PIN, ghi nhật ký, giữ `IP_RETENTION_DAYS` = 730 (phương án B) | L1, L2, L8 | Đúng hướng. Thời hạn: tối thiểu 12 tháng theo L8 (nếu áp dụng); 730 ngày đang dựa vào Nghị định 53/2022 đã bị thay. Đề xuất 365 ngày (đủ L8, tối thiểu hóa) |
| C10 | `audit_log` giữ 12 tháng, sau đó lưu trữ lạnh tới 24–36 tháng, căn cứ Nghị định 53/2022 | L8 | Thời hạn tối thiểu 12 tháng vẫn đúng; đổi căn cứ sang Nghị định 333/2026; job lưu trữ lạnh chưa thấy trong mã (chưa xác minh) |
| C11 | `audit-log.middleware`, `auth.controller`, `aiops.controller` lấy IP từ giá trị đầu `x-forwarded-for` (client giả được) | L8 | Nhật ký có thể ghi IP sai. Sửa sang `req.ip` |
| C12 | `hashIp` của AIOps: SHA-256 với muối viết cứng, cắt 16 ký tự, dò lại được IP | L2 | Chuyển sang HMAC với khóa bí mật trong biến môi trường (bước G4.1) |
| C13 | `POST /admin/verify-security-action` và route xem IP chỉ có giới hạn tốc độ chung, không khóa sau nhiều lần sai PIN | L2 | Nên thêm giới hạn số lần sai PIN theo tài khoản admin |
| C14 | CSDL đặt tại Supabase (AWS Tokyo) | L9 | Theo bài phân tích, nghĩa vụ lưu tại Việt Nam chỉ phát sinh có điều kiện với doanh nghiệp nước ngoài; cần đọc văn bản gốc Nghị định 333 để kết luận cho doanh nghiệp trong nước. Ghi vào hạn chế của hệ thống |
| C15 | Đăng ký tài khoản xác thực bằng email OTP, chưa bằng số điện thoại | L10 | Chưa xác minh đối tượng áp dụng; nếu áp dụng thì là việc lớn của cả Client-app. Chỉ ghi nhận |
| C16 | Chú thích trong Client-app (`lib/core/api/ten_thiet_bi.dart`) ghi Backend lưu "IP che mờ" | — | Đã lỗi thời sau phương án B; báo thành viên client, không sửa |

## 4. Nguồn

- Luật 91/2025/QH15: [Bộ Công an](https://bocongan.gov.vn/chinh-sach-phap-luat/co-so-du-lieu-van-ban/luat-bao-ve-du-lieu-ca-nhan-1753688803), [Công báo](https://congbaocdn.chinhphu.vn/CongBaoCP/VanBan/2025/6/45578/57730-1-2025971-97291-2025-qh15.pdf), [LuatVietnam (EN)](https://english.luatvietnam.vn/dan-su/law-on-personal-data-protection-law-no-91-2025-qh15-405135-d1.html), [Cổng Hải Phòng](https://bandandunghatang.haiphong.gov.vn/luat-so-91-2025-qh15-cua-quoc-hoi--luat-bao-ve-du-lieu-ca-nhan-n133.html)
- Nghị định 356/2025: [LuatVietnam: điểm mới so với Nghị định 13/2023](https://luatvietnam.vn/dan-su/diem-moi-cua-nghi-dinh-356-2025-so-voi-nghi-dinh-13-2023-ve-bao-ve-du-lieu-ca-nhan-568-106269-article.html), [LSVN](https://lsvn.vn/mot-so-thay-doi-can-luu-y-trong-xu-ly-du-lieu-ca-nhan-tu-01-01-2026-a167892.html), [Find-law](https://find-law.asia/nghi-dinh-3562025nd-cp-7-diem-moi-ve-bao-ve-du-lieu-ca-nhan-nd59e5763dfba31)
- Luật An ninh mạng 2025: [VTV](https://vtv.gov.vn/news/an-toan-thong-tin-1/luat-an-ninh-mang-chinh-thuc-co-hieu-luc-tu-172026), [Công an Cần Thơ](https://congan.cantho.gov.vn/tuyen-truyen-pho-bien-giao-duc-phap-luat/nhung-diem-moi-cua-luat-an-ninh-mang-nam-2025-8736.html), [Frasers](https://www.frasersvn.com/vi/legal-updates-and-publications/vietnam-s-law-on-cybersecurity-2025-what-s-new-and-what-businesses-need-to-know)
- Nghị định hướng dẫn 2026: [LuatVietnam: danh sách văn bản](https://luatvietnam.vn/linh-vuc-khac/danh-sach-van-ban-huong-dan-luat-an-ninh-mang-2025-co-hieu-luc-tu-01-7-2026-883-111870-article.html), [HM&P: Nghị định 333/2026](https://hmplaw.vn/vi/nghi-dinh-huong-dan-luat-an-ninh-mang-2025-da-duoc-ban-hanh-va-co-hieu-luc-doanh-nghiep-can-luu-y-nhung-gi), [Bộ Công an: lấy ý kiến dự thảo](https://bocongan.gov.vn/chinh-sach-phap-luat/bai-viet/lay-y-kien-du-thao-nghi-dinh-quy-dinh-chi-tiet-mot-so-dieu-cua-luat-an-ninh-mang-1770996834)
- Nghị định 330/2026: [Thư viện Pháp luật](https://thuvienphapluat.vn/chinh-sach-phap-luat-moi/vn/ho-tro-phap-luat/chinh-sach-moi/119851/nghi-dinh-330-2026-nd-cp-xu-phat-hanh-chinh-ve-an-ninh-mang-va-bao-ve-du-lieu-ca-nhan-ra-sao), [Chính phủ](https://xaydungchinhsach.chinhphu.vn/nghi-dinh-330-2026-nd-cp-ve-xu-phat-vi-pham-hanh-chinh-trong-linh-vuc-an-ninh-mang-119260824172446407.htm), [Cà Mau](https://pbgdpl.camau.gov.vn/bao-ve-du-lieu-ca-nhan-theo-nghi-dinh-3302026ndcp-mot-so-van-de-can-luu-y.8911)
- Nghị định 53/2022 (đã bị thay): [LSVN](https://lsvn.vn/nhung-loai-du-lieu-nao-phai-duoc-luu-tru-tai-viet-nam1660725896-a122651.html), [Thư viện Pháp luật](https://thuvienphapluat.vn/phap-luat/co-bat-buoc-luu-tru-du-lieu-nguoi-dung-mang-internet-tai-viet-nam-hay-khong-thoi-han-luu-tru-du-lie-41851.html)
- Quốc tế: [Breyer C-582/14](https://www.thomashelbing.com/en/wissen/dsgvo-hub/rechtsprechung/1.4.37-eugh-breyer), [Osborne Clarke](https://osborneclarke.com/insights/european-court-rules-website-and-app-operators-must-treat-dynamic-ip-addresses-as-personal-data-what-this-means-in-practice)

Việc cần làm trước khi trích chính thức: tải văn bản gốc Luật 91/2025, Nghị định 356/2025, Luật 116/2025, Nghị định 333/2026, Nghị định 330/2026 (PDF Công báo), chuyển sang Markdown bằng `markitdown`, đối chiếu lại các dòng "một nguồn".

## 5. Quyết định của Chủ dự án (2026-11-13)

- `IP_RETENTION_DAYS` = 365 (C9).
- Giữ dữ liệu tài chính người dùng 5 năm như hiện tại (C5); ghi là chính sách hệ thống, nêu trong thông báo xử lý dữ liệu (`Data_Security.md` 7.3).
- Duyệt kế hoạch T1–T4. T1 (tài liệu) và T2 (IP qua `req.ip` ở mọi nơi, khóa xác thực PIN sau 5 lần sai / 15 phút) đã làm cùng ngày; T3, T4 tiếp theo.
- Văn bản gốc (PDF) Chủ dự án gửi sau; trong lúc chờ làm theo thiết kế này.
