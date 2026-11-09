# Chính sách dữ liệu của Trợ lý AI (BẢN NHÁP cho Admin duyệt)

> **Trạng thái:** bản nháp soạn ngày 2026-11-07, bám mã backend `src/Backend/modules/ai/features/chatbot/`. Phần A là nội dung để người dùng đọc và xác nhận. Phần B là việc Admin phải xác minh trước khi công bố, **không hiển thị cho người dùng**. Chỗ ghi `[…]` do Admin điền.
> **Chưa có trang chính sách nào trong ứng dụng.** Màn hình, vị trí liên kết và nút xác nhận thuộc Client-app, cần phối hợp với thành viên phụ trách.

---

## Phần A — Nội dung cho người dùng xác nhận

### 1. Trợ lý AI trực tuyến là gì
Khi có mạng và bạn bật Trợ lý online, câu hỏi của bạn được xử lý bởi một **mô hình ngôn ngữ lớn do bên thứ ba cung cấp, đặt máy chủ ở nước ngoài** (`[tên nhà cung cấp]`, `[quốc gia]`). Nếu bạn tắt Trợ lý online hoặc mất mạng, AI trên máy trả lời và **không có dữ liệu nào rời khỏi điện thoại**.

### 2. Dữ liệu nào được gửi đi
Mỗi lần bạn hỏi, hệ thống gửi tới nhà cung cấp mô hình:
- Câu hỏi của bạn và tối đa 4 tin gần nhất của cuộc trò chuyện (mỗi tin cắt tối đa 800 ký tự).
- Bản tóm tắt tài chính tổng hợp: điểm sức khỏe tài chính, tỉ lệ chi theo nhóm, các cảnh báo ngân sách, số tháng quỹ khẩn cấp, số hóa đơn sắp đến hạn.
- Khi câu hỏi cần chi tiết, kết quả tra cứu: một vài giao dịch (số tiền, danh mục, ngày, ghi chú), hóa đơn sắp đến hạn, tiến độ mục tiêu.

Trước khi gửi, hệ thống che số tài khoản, số điện thoại, email, số thẻ, số căn cước, mã OTP và họ tên của chính bạn trong ghi chú và câu hỏi.

### 3. Dữ liệu không được gửi đi
Mật khẩu, mã xác thực, mã thông báo đăng nhập, mã định danh tài khoản và địa chỉ email đăng ký **không** được gửi tới nhà cung cấp mô hình. Dữ liệu giao dịch ở dạng mã hóa trong cơ sở dữ liệu của FlowMoney chỉ được giải mã tạm thời trong máy chủ để trả lời câu hỏi của bạn.

### 4. Ai xử lý dữ liệu và ở đâu
Dữ liệu đi qua **máy chủ FlowMoney** rồi được chuyển qua mạng (mã hóa khi truyền) tới nhà cung cấp mô hình ở nước ngoài. Đây là **chuyển dữ liệu cá nhân ra nước ngoài**: nhà cung cấp xử lý dữ liệu theo chính sách riêng của họ và theo pháp luật của quốc gia nơi họ đặt máy chủ.

### 5. Dữ liệu được lưu ở đâu, trong bao lâu
- **FlowMoney không lưu nội dung câu hỏi và câu trả lời** của Trợ lý AI trên máy chủ. Lịch sử cuộc trò chuyện nằm trên điện thoại của bạn.
- FlowMoney chỉ lưu số liệu sử dụng để kiểm soát hạn mức: số lượt hỏi trong ngày và chi phí sử dụng trong tháng, không kèm nội dung.
- Nhà cung cấp mô hình có thể lưu giữ dữ liệu bạn gửi trong thời gian theo chính sách của họ: `[thời hạn lưu giữ và mục đích sử dụng, Admin điền sau khi xác minh điều khoản của nhà cung cấp]`.

### 6. Chúng tôi bảo vệ dữ liệu như thế nào
- Mã hóa khi truyền; ghi chú giao dịch mã hóa khi lưu trữ.
- Che thông tin định danh trước khi gửi (mục 2); không gửi mã định danh tài khoản.
- Mỗi tài khoản chỉ truy cập dữ liệu của chính mình.
- Giới hạn độ dài, số lượt hỏi và chi phí sử dụng mỗi người để tránh lạm dụng.
- Ghi nhật ký chỉ gồm số liệu kỹ thuật, không ghi nội dung câu hỏi hay câu trả lời.

### 7. Lưu ý về giới hạn của việc che thông tin
Việc che thông tin có thể không bắt được mọi trường hợp, ví dụ tên người khác viết trong ghi chú, hoặc tên mục tiêu và hóa đơn do bạn tự đặt. Vui lòng **không nhập thông tin nhạy cảm của người khác** vào câu hỏi hoặc ghi chú nếu bạn dùng Trợ lý online.

### 8. Quyền của bạn
- Tắt Trợ lý online bất cứ lúc nào trong **Cài đặt AI** để chỉ dùng AI trên máy.
- Yêu cầu truy cập, chỉnh sửa, xóa dữ liệu cá nhân của bạn tại FlowMoney theo quy định pháp luật: `[kênh liên hệ của Admin]`.
- Rút lại sự đồng ý: việc rút lại có hiệu lực cho các lần hỏi sau đó.

### 9. Xác nhận
Bằng việc chọn **"Tôi đồng ý"**, bạn xác nhận đã đọc chính sách này và đồng ý cho FlowMoney gửi dữ liệu nêu ở mục 2 tới nhà cung cấp mô hình ngôn ngữ ở nước ngoài để trả lời câu hỏi của bạn.

---

## Phần B — Việc Admin cần xác minh (không hiển thị cho người dùng)

### B1. Điều chưa xác minh được
| Điểm | Tình trạng |
|---|---|
| Điều khoản **API** của nhà cung cấp: thời hạn lưu giữ, có dùng dữ liệu để huấn luyện hay không, vị trí máy chủ | Chưa xác minh. Chính sách quyền riêng tư công khai của DeepSeek nói dữ liệu được lưu tại Trung Quốc và dùng để cải tiến mô hình, nhưng không nói rõ riêng cho API (nguồn: cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html, đọc 2026-11-07). Cần đọc điều khoản dịch vụ API, tìm lựa chọn từ chối dùng dữ liệu để huấn luyện, và ghi kết quả vào mục 5 |
| Máy chủ FlowMoney (Render, Supabase) đặt ở khu vực nào | Chưa xác minh. Ảnh hưởng tới câu "dữ liệu đi qua máy chủ FlowMoney" ở mục 4 |
| Quy định pháp lý về chuyển dữ liệu cá nhân ra nước ngoài (Nghị định 13/2023/NĐ-CP) | Cần tư vấn pháp lý: có phải lập hồ sơ đánh giá tác động chuyển dữ liệu ra nước ngoài và gửi cơ quan có thẩm quyền hay không, và hình thức đồng ý phải ra sao. Tài liệu này không phải ý kiến pháp lý |

### B2. Điểm yếu đã biết của việc che thông tin (đối chiếu mã 2026-11-08)
- Luật che họ tên chỉ che **họ tên chính chủ**; tên người khác trong ghi chú đi qua nguyên văn.
- Tên mục tiêu, tên hóa đơn và tên danh mục đã được che họ tên chính chủ, số điện thoại và các chuỗi số nhạy cảm. Tên người khác trong đó (ví dụ "Mua nhà cho Lan") vẫn được gửi nguyên văn.
- Luật che chuỗi 9 đến 19 chữ số cũng che nhầm số tiền viết liền.
- Số tiền, ngày và nơi chi tiêu kết hợp lại có thể gián tiếp nhận diện người dùng, dù rủi ro thấp.
Các điểm này thuộc phạm vi cải thiện của backend, ghi nhận để quyết định có xử lý hay chỉ nêu trong chính sách (mục 7).

### B3. Việc cần làm ở ứng dụng và tài liệu
- Văn bản đồng ý hiện trong `ai_chat` ghi chung "dịch vụ AI đám mây" và không nêu nước ngoài. Cần thay bằng liên kết tới Phần A và nút xác nhận.
- Trang **Cài đặt AI** (`ai_edge/`) còn ghi "Google Gemini", sai so với nhà cung cấp hiện tại.
- Backend gửi nguyên `scopes` của ma trận quyền xuống client qua `/subscription-info` (client không đọc), trong đó khóa `model` của `ai_assistant` từng ghi tên mô hình. Migration 47 đổi thành nhãn trung tính `cloud`; chưa áp.
- Tài liệu `docs/Admin-web/10-ai-copilot-and-financial-health.md` và `docs/AI/ChatbotAI.md` còn mô tả chatbot trên Admin-web và endpoint snapshot đã gỡ.
- Nếu đổi nhà cung cấp mô hình, phải cập nhật lại toàn bộ Phần A và xin xác nhận lại.
