# ĐẶC TẢ KỸ THUẬT & HƯỚNG DẪN TRIỂN KHAI CHATBOT AI TRÊN CLIENT-APP (MOBILE)

> **Tài liệu bàn giao & giao việc cho đội ngũ Client-app (Flutter)**  
> **Phiên bản:** 1.0.0 · **Ngày lập:** 2026-09-26  
> **Nguồn sự thật kiến trúc:** [`docs/AI/ChatbotAI.md`](./ChatbotAI.md), [`docs/AI/LogicBusinessAI.md`](./LogicBusinessAI.md), [`docs/Rule_Project/Data_Security.md`](../Rule_Project/Data_Security.md).  
> **Trách nhiệm:** Thành viên phụ trách Client-app triển khai giao diện, kết nối SSE stream, quản lý lịch sử trò chuyện cục bộ và cơ chế chuyển đổi Online ↔ Offline.

---

## 1. TỔNG QUAN & PHÂN ĐỊNH TRÁCH NHIỆM

Hệ thống có **2 trợ lý AI song hành** phục vụ người dùng linh hoạt:
1. **Trợ lý AI Trên Máy (On-Device SLM - Đã có sẵn):** Chạy mô hình Gemma 4 E2B cục bộ qua LiteRT-LM + 7 tool chỉ đọc trên SQLite v24 (`lib/features/ai_chat/`). Hoạt động **100% Offline khi không có mạng**.
2. **Trợ lý Tài chính Trực Tuyến (Cloud AI Copilot - Đợt này):** Kết nối lên Backend (`POST /api/ai/chatbot/chat/stream`), sử dụng mô hình Google Gemini 2.0 Flash có khả năng suy luận mở, RAG tri thức luật thuế/quy tắc 50/30/20 và Tấm khiên riêng tư (Privacy Shield). Hoạt động **khi có kết nối mạng Internet**.

---

## 2. ĐẶC TẢ API GIAO TIẾP VỚI BACKEND

### 2.1. API Chat Thời Gian Thực (SSE Streaming) — Khuyên Dùng

- **Method & URL:** `POST /api/ai/chatbot/chat/stream`
- **Headers:**
  ```http
  Authorization: Bearer <ACCESS_TOKEN>
  Content-Type: application/json
  Accept: text/event-stream
  ```
- **Request Body (JSON):**
  ```json
  {
    "message": "Tháng này tôi thấy hơi áp lực chi tiêu, bạn xem giùm tôi nên cắt giảm khoản nào?",
    "conversationId": "550e8400-e29b-41d4-a716-446655440000",
    "history": [
      { "role": "user", "text": "Chào bạn" },
      { "role": "model", "text": "Chào bạn, tôi là Cố vấn Tài chính của bạn. Hôm nay tôi có thể hỗ trợ gì cho kế hoạch tài chính của bạn?" }
    ]
  }
  ```
  *(Lưu ý: Chỉ gửi tối đa 6–10 tin nhắn gần nhất trong `history` để tối ưu token)*.

- **Response Format (Server-Sent Events):**
  Backend trả về luồng `text/event-stream` gồm các sự kiện tuần tự:
  ```http
  event: meta
  data: {"snapshotLoaded": true, "healthScore": 72, "topExpense": "Ăn uống"}

  event: delta
  data: {"text": "Chào "}

  event: delta
  data: {"text": "bạn! Dựa trên bức tranh "}

  event: delta
  data: {"text": "tài chính tháng này, danh mục Ăn uống đang chiếm tới 34%..."}

  event: done
  data: {"status": "completed", "responseTimeMs": 720}
  ```

- **Mã lỗi thường gặp:**
  - `401 Unauthorized`: Token hết hạn $\rightarrow$ Chạy luồng Refresh Token.
  - `429 Too Many Requests`: Vượt hạn mức 15 req/phút $\rightarrow$ Hiện thông báo: *"Bạn đang thao tác quá nhanh, vui lòng chờ ít giây"*.
  - `503 Service Unavailable`: Circuit breaker đang mở / Gemini lỗi $\rightarrow$ Gợi ý người dùng chuyển sang Trợ lý Offline trên máy.

### 2.2. API Lấy Bản Chụp Sức Khỏe Tài Chính (Financial Health Snapshot)

- **Method & URL:** `GET /api/ai/chatbot/snapshot`
- **Headers:** `Authorization: Bearer <ACCESS_TOKEN>`
- **Response Format:**
  ```json
  {
    "success": true,
    "data": {
      "period": "Tháng 09/2026",
      "financialHealthScore": 72,
      "budgetAllocation": {
        "needs_essential": "58% (Chuẩn: 50%)",
        "wants_lifestyle": "27% (Chuẩn: 30%)",
        "savings_debt": "15% (Chuẩn: 20%)"
      },
      "spendingInsights": {
        "topExpenseCategories": [
          { "category": "Ăn uống", "percentage": 34, "trendVsLastMonth": "+15%" },
          { "category": "Thuê nhà", "percentage": 24, "trendVsLastMonth": "0%" }
        ],
        "overBudgetAlerts": ["Ăn uống đã chạm 92% ngân sách tháng"]
      },
      "liquidityAndObligations": {
        "emergencyFundMonths": 2.1,
        "upcomingBillsIn7DaysCount": 2,
        "activeSavingsGoalsCount": 1
      }
    }
  }
  ```
  *(Dùng để hiển thị Thẻ Sức Khỏe Tài Chính trực quan ở đầu màn hình Chat hoặc Dashboard)*.

---

## 3. THIẾT KẾ GIAO DIỆN & TRẢI NGHIỆM NGƯỜI DÙNG (MOBILE UX)

### 3.1. Các Thành Phần Trên Màn Hình Chatbot:
1. **Thanh Header:**
   - Tiêu đề: *Cố Vấn Tài Chính AI (FlowMoney Copilot)*.
   - Huy hiệu trạng thái: 🟢 *Trực Tuyến (Cloud)* hoặc 🟡 *Ngoại Tuyến (On-Device)*.
   - Nút chuyển đổi nhanh chế độ Online / Offline.
2. **Thẻ Tóm Tắt Sức Khỏe Tài Chính (Header Card - Thu gọn/Mở rộng):**
   - Điểm FHS (ví dụ: `72/100`), thanh tiến độ 3 màu 50/30/20.
   - Giúp người dùng nhìn thấy ngay tình trạng tổng quan mà không cần gõ hỏi.
3. **Danh Sách Gợi Ý Câu Hỏi Nhanh (Quick Prompt Chips):**
   - *"Đánh giá chi tiêu tháng này của tôi"*
   - *"Làm sao để tiết kiệm 20% thu nhập?"*
   - *"Tôi có nên mua món đồ 5 triệu lúc này không?"*
   - *"Giải thích quy tắc quỹ khẩn cấp 3-6 tháng"*
4. **Hiệu Ứng Hiển Thị Chữ Chạy (Streaming Token UI):**
   - Đọc từng gói `event: delta` và cập nhật tức thì vào Bubble tin nhắn của AI.
   - Có nút **"Dừng tạo" (Stop Generating)** khi AI đang stream: Bấm vào sẽ hủy Stream và ngắt kết nối với server (`cancelToken.cancel()`).

---

## 4. HƯỚNG DẪN KỸ THUẬT TIÊU THỤ SSE STREAM TRONG FLUTTER

Thành viên Client-app có thể sử dụng thư viện `dio` (hoặc `http`) có sẵn trong dự án:

```dart
// Ví dụ mẫu tiêu thụ SSE stream bằng Dio trong Flutter
import 'dart:convert';
import 'package:dio/dio.dart';

Future<void> sendChatMessageStream({
  required String message,
  required List<Map<String, String>> history,
  required Function(String chunk) onTokenReceived,
  required Function(Map<String, dynamic> meta) onMetaReceived,
  required Function() onDone,
  required CancelToken cancelToken,
}) async {
  final dio = Dio();
  final response = await dio.post<ResponseBody>(
    'https://api-domain.com/api/ai/chatbot/chat/stream',
    data: {
      'message': message,
      'history': history,
    },
    options: Options(
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'text/event-stream',
      },
      responseType: ResponseType.stream,
    ),
    cancelToken: cancelToken,
  );

  String buffer = '';
  response.data!.stream.transform(utf8.decoder).listen(
    (data) {
      buffer += data;
      final lines = buffer.split('\n');
      buffer = lines.removeLast(); // giữ lại phần chưa đủ 1 dòng hoàn chỉnh

      String? currentEvent;
      for (final line in lines) {
        if (line.startsWith('event: ')) {
          currentEvent = line.substring(7).trim();
        } else if (line.startsWith('data: ')) {
          final payload = line.substring(6).trim();
          if (payload.isNotEmpty) {
            try {
              final json = jsonDecode(payload);
              if (currentEvent == 'meta') {
                onMetaReceived(json);
              } else if (currentEvent == 'delta') {
                onTokenReceived(json['text'] ?? '');
              } else if (currentEvent == 'done') {
                onDone();
              }
            } catch (_) {}
          }
        }
      }
    },
    onDone: () => onDone(),
    onError: (err) => print('Lỗi SSE Stream: $err'),
  );
}
```

---

## 5. LƯU TRỮ LỊCH SỬ CHAT CỤC BỘ (DRIFT SQLITE)

- **Bảng CSDL cục bộ:** Tạo bảng `LocalChatMessages` trên Drift SQLite v24 (chỉ lưu trên máy, không đồng bộ lên server để bảo vệ quyền riêng tư):
  - `id`: Int / UUID.
  - `role`: 'user' | 'model'.
  - `message`: String.
  - `healthScore`: Int (lưu vết tại thời điểm chat).
  - `createdAt`: DateTime.
  - `isOnline`: Boolean (đánh dấu tin nhắn trả về từ Cloud hay Edge).
- Khi người dùng xóa app hoặc xóa lịch sử chat, dữ liệu trên máy tự động giải phóng.

---

## 6. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA PHÍA CLIENT)

- [ ] **AC-MOB-01:** Màn hình chat kết nối thành công tới `POST /api/ai/chatbot/chat/stream` qua HTTPS kèm Bearer token.
- [ ] **AC-MOB-02:** Nhận diện và hiển thị mượt mà từng token theo thời gian thực (hiệu ứng gõ chữ streaming).
- [ ] **AC-MOB-03:** Nút "Dừng" ngắt stream ngay lập tức, không bị crash hoặc treo app.
- [ ] **AC-MOB-04:** Hiển thị thẻ Sức khỏe tài chính với điểm FHS và cơ cấu 50/30/20 lấy từ sự kiện `meta` hoặc endpoint `GET /snapshot`.
- [ ] **AC-MOB-05:** Khi mất kết nối mạng (Network Offline), hiển thị banner cảnh báo và cho phép người dùng trò chuyện với Trợ lý AI On-Device (`Gemma 4 E2B`).
- [ ] **AC-MOB-06:** Lịch sử chat được lưu trên SQLite cục bộ và cuộn mượt mà.
