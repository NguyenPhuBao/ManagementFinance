# 🧠 ĐẶC TẢ KIẾN TRÚC AI ĐIỀU PHỐI NGÂN SÁCH CÁ NHÂN (ON-DEVICE EDGE SLM) — CLIENT-APP

Tài liệu này ghi nhận ý tưởng khởi nguồn, định hướng kiến trúc và bản phác thảo thiết kế chi tiết hệ thống AI thông minh cục bộ trên thiết bị di động (**On-device Edge AI / SLM**) cho ứng dụng **Client-app (ManagementFinance)**.

---

## 💡 PHẦN I: Ý TƯỞNG KHỞI NGUỒN & PHƯƠNG ÁN ĐỊNH HƯỚNG BAN ĐẦU

### 1. Ý Tưởng & Mục Tiêu Cốt Lõi
Dự định phát triển một mô hình AI tích hợp trực tiếp tại máy người dùng (Edge AI / "AI Điên") có khả năng tự học hỏi thói quen chi tiêu và tiêu dùng cá nhân hóa:
1. **Ghi nhận các mục sử dụng thường xuyên:** Tự động đánh giá và xây dựng trọng số ưu tiên của khoản chi tiêu theo từng danh mục (tỷ số chi tiêu trên mỗi danh mục hàng tháng, nhận diện danh mục nào dùng nhiều, dùng thường xuyên, danh mục nào cố định).
2. **Hệ thống AI tự cân đối & đề xuất phân bổ ngân sách:** Dựa trên thói quen sử dụng tài chính, AI tự động cân đối và đề xuất phân bổ lại ngân sách theo danh mục để đạt mục tiêu tài chính mong muốn.
   - *Ví dụ thực tế:* Khoản sử dụng "Ăn uống" đang có nguy cơ thâm hụt, AI có thể gợi ý giảm bớt khoản tài chính trong mục "Tiệc tùng" & tăng khoản tài chính trong mục "Ăn uống" để cân đối tài chính.

### 2. Cơ Chế Vận Hành
- **Thu thập & Đánh giá:** AI ghi nhận lại nhật ký, lịch trình, mục đích sử dụng thường xuyên của các giao dịch thu chi trên mobile app $\rightarrow$ Đánh giá trọng số danh mục thu chi của khách hàng $\rightarrow$ Xác định nhu cầu nào là thiết yếu để ưu tiên $\rightarrow$ Phục vụ việc phân bổ ngân sách mỗi tháng và cân đối tài chính.
- **Đặc trưng Mobile:** Cài đặt và chạy trực tiếp trên thiết bị điện thoại, học thói quen người dùng cục bộ. Thu hẹp mô hình ngôn ngữ lớn (LLM) thành mô hình ngôn ngữ nhỏ gọn (**SLM - Small Language Model**) chạy trực tiếp trên mobile.

### 3. Kiến Trúc 3 Tầng Sơ Bộ & Lý Do Thiết Kế

#### Sơ bộ 3 tầng:
- **Tầng 1 — Feature Engineering (không cần AI):** Biến raw transactions thành các đặc trưng có ý nghĩa (tỷ trọng từng danh mục, độ biến động variance, tần suất, tính chu kỳ tuần/tháng, so sánh baseline cá nhân, tín hiệu bất thường). Đây là dữ liệu thống kê "sự thật" (ground truth) mà AI không được phép bịa.
- **Tầng 2 — Suy luận & Tối ưu (Rule-engine + Optimization):** Nhìn mối quan hệ giữa các danh mục (correlation matrix), phân loại essential/flexible theo hành vi thực tế. Giải bài toán tối ưu phân bổ lại với ràng buộc "tổng chi $\le$ thu nhập, mục tiêu tiết kiệm $X\%$".
- **Tầng 3 — SLM Diễn giải & Tương tác:** SLM nhận feature đã tính sẵn làm input để sinh phân tích bằng ngôn ngữ tự nhiên có ngữ cảnh cá nhân hóa, trả lời câu hỏi tự do và đề xuất kèm giải thích lý do.

#### Vì sao không để SLM tự "học" trực tiếp từ raw transactions:
1. **SLM (1–4B params) rất yếu ở suy luận số học nhiều bước:** Dễ tính sai phần trăm hoặc sai tổng nếu để mô hình tự tính toán từ dữ liệu thô.
2. **Khả năng kiểm toán (Auditability):** Với ứng dụng tài chính cá nhân, nếu AI khuyên sai mà không giải thích được nguồn gốc số liệu thì rủi ro rất cao.
3. **Giới hạn phần cứng & Context Window:** Muốn cá nhân hóa thật cần tích lũy dữ liệu qua nhiều tháng bằng thống kê. Nhồi hàng trăm giao dịch vào context window của một SLM nhỏ trên mobile sẽ gây quá tải tài nguyên và tràn bộ nhớ.

---

## 📐 PHẦN II: BẢN PHÁC THẢO THIẾT KẾ CHI TIẾT (DESIGN SPECIFICATION)

# Kiến trúc AI Điều Phối Ngân Sách Cá Nhân (On-device, 3 tầng)

## Tổng quan luồng dữ liệu

```
Raw Transactions (SQLite/local DB)
        │
        ▼
┌─────────────────────┐
│ TẦNG 1: Feature Eng  │  → Thống kê, không AI
│ (chạy nền, định kỳ)  │
└─────────┬────────────┘
          │  category features (JSON)
          ▼
┌─────────────────────┐
│ TẦNG 2: Reasoning &  │  → Rule-engine + weighted algorithm
│ Optimization Engine  │
└─────────┬────────────┘
          │  reallocation plan (JSON)
          ▼
┌─────────────────────┐
│ TẦNG 3: SLM Diễn giải│  → On-device SLM (Gemma Nano / MediaPipe LLM)
│ & Hội thoại          │
└─────────┬────────────┘
          │  natural language
          ▼
      Người dùng
```

Nguyên tắc xuyên suốt: **số liệu luôn đến từ Tầng 1-2 (deterministic, audit được), SLM ở Tầng 3 không bao giờ tự tính toán số học** — chỉ diễn giải và hội thoại trên số liệu đã đúng.

---

## TẦNG 1 — Feature Engineering (Thống kê, chạy nền)

### 1.1. Trigger & tần suất chạy
- Chạy **incremental** mỗi khi có giao dịch mới (cập nhật rolling stats, chi phí tính toán thấp — $O(1)$ amortized nếu dùng thuật toán online như Welford's algorithm cho mean/variance)
- Chạy **full recompute** định kỳ (đầu ngày, hoặc khi mở app sau >6h) để đồng bộ lại trend/regularity

### 1.2. Dữ liệu đầu vào
```
Transaction = {
  id, amount, category_id, timestamp,
  is_recurring_hint (nếu người dùng đã gắn nhãn "định kỳ"),
  merchant/note (optional, dùng để clustering nếu category chưa gán)
}
```

### 1.3. Đặc trưng tính cho mỗi danh mục (category-level features)

| Đặc trưng | Công thức / cách tính | Ý nghĩa |
|---|---|---|
| `avg_spend_3m`, `avg_spend_6m` | trung bình trượt 3/6 tháng | baseline cá nhân |
| `current_spend` | tổng chi từ đầu tháng đến hiện tại | dùng để chiếu (project) |
| `projected_spend` | `current_spend * days_in_month / days_elapsed` | ước lượng cả tháng |
| `CV` (hệ số biến thiên) | `std(spend theo tháng) / mean(spend theo tháng)` | càng thấp càng "cố định" |
| `regularity` | số tháng có phát sinh / tổng số tháng theo dõi | tính chu kỳ |
| `trend_slope` | hồi quy tuyến tính đơn giản (least squares) trên 3-6 điểm tháng | đang tăng/giảm |
| `txn_frequency` | số giao dịch/tháng trong danh mục | mức độ dùng thường xuyên |
| `weekday_pattern` | phân bố chi theo thứ trong tuần (vector 7 chiều, chuẩn hoá) | phát hiện thói quen (VD: chi nhiều cuối tuần) |
| `post_payday_ratio` | tỷ lệ chi trong 3-5 ngày sau ngày nhận lương / tổng chi tháng | phát hiện hành vi "vung tay sau lương" |

### 1.4. Xử lý dữ liệu thưa (cold start)
- Danh mục mới hoặc < 2 tháng dữ liệu: dùng **giá trị mặc định theo nhóm** (VD nhóm "ăn uống" mặc định essentiality cao hơn nhóm "giải trí") làm prior, sau đó Bayesian update dần khi có thêm dữ liệu thực — tránh kết luận vội trên mẫu nhỏ.

### 1.5. Output (đưa sang Tầng 2)
```json
{
  "month": "2026-09",
  "income": 20000000,
  "categories": [
    {
      "id": "an_uong",
      "avg_spend": 4500000,
      "current_spend": 3200000,
      "projected_spend": 5100000,
      "budget_limit": 4500000,
      "cv": 0.18,
      "regularity": 0.95,
      "trend_slope": 0.06,
      "txn_frequency": 42
    }
  ]
}
```

---

## TẦNG 2 — Reasoning & Optimization Engine

### 2.1. Essentiality Score (điểm thiết yếu — học theo hành vi)

```
essentiality[i] = w1*(1 - CV[i]) + w2*regularity[i] + w3*(1 - elasticity[i])
```

- **elasticity[i]**: đo bằng cách nhìn lại lịch sử — trong các tháng người dùng từng bị thâm hụt (`projected > income*margin`), danh mục nào từng **giảm chi rõ rệt** (so với avg_spend) → elasticity cao (co giãn tốt, không thiết yếu).
  ```
  elasticity[i] = avg( (avg_spend[i] - spend_in_deficit_month[i]) / avg_spend[i] )
                  tính trên các tháng thâm hụt trong quá khứ
  ```
  Nếu chưa có tháng thâm hụt nào trong lịch sử → dùng prior mặc định theo nhóm danh mục.

- **Trọng số w1, w2, w3**: khởi tạo (0.4, 0.3, 0.3), có thể tinh chỉnh dần bằng feedback thực tế ở mục 2.4 (conflict handling).

- **Cập nhật**: essentiality không tính lại toàn bộ mỗi lần — dùng **exponential moving average** để cập nhật dần, tránh dao động mạnh khi có 1 tháng bất thường:
  ```
  essentiality_new[i] = α * essentiality_computed[i] + (1-α) * essentiality_old[i]
  ```
  ($\alpha \approx 0.2-0.3$, ưu tiên ổn định hơn phản ứng nhanh)

### 2.2. Phát hiện thâm hụt & chọn nguồn bù

```
deficit[i] = projected_spend[i] - budget_limit[i]     // nếu > threshold → kích hoạt

slack[j] = budget_limit[j] - projected_spend[j]        // dư địa còn lại
donor_score[j] = slack[j] * (1 - essentiality[j])      // dư nhiều + không thiết yếu = ưu tiên cắt
```

Sắp xếp donor theo `donor_score` giảm dần, chọn lần lượt.

### 2.3. Thuật toán phân bổ lại

```python
def reallocate(deficit_category, deficit_amount, donors, max_cut_ratio=0.25):
    plan = []
    remaining = deficit_amount
    donors_sorted = sorted(donors, key=lambda d: d.donor_score, reverse=True)

    for donor in donors_sorted:
        if remaining <= 0:
            break
        max_transfer = donor.slack * max_cut_ratio
        transfer = min(remaining, max_transfer)
        if transfer > MIN_MEANINGFUL_AMOUNT:  # tránh đề xuất số quá nhỏ, vô nghĩa
            plan.append({
                "category": donor.id,
                "change": -transfer,
                "reason": "high_slack_low_essentiality"
            })
            remaining -= transfer

    if remaining > 0:
        return {"status": "insufficient_slack", "shortfall": remaining, "plan": plan}
    return {"status": "resolved", "plan": plan}
```

- Nếu `insufficient_slack`: đây là tín hiệu **cảnh báo thực sự** (chi tiêu vượt khả năng thu nhập), không phải bài toán tái phân bổ nội bộ nữa → Tầng 3 cần đổi giọng điệu từ "gợi ý" sang "cảnh báo nghiêm túc".

### 2.4. Ràng buộc mục tiêu tiết kiệm (Goal Constraint)

```
total_allowed = income * (1 - saving_goal_ratio)

if Σ new_budget[j] > total_allowed:
    excess = Σ new_budget[j] - total_allowed
    for each non-essential category j (essentiality < threshold):
        cut[j] = excess * ( (1-essentiality[j]) / Σ(1-essentiality[k]) )   # cắt tỷ lệ theo mức "không thiết yếu"
        new_budget[j] -= cut[j]
```

### 2.5. Conflict Handling — học từ chỉnh tay của người dùng

Khi người dùng **từ chối** hoặc **tự sửa** đề xuất (VD: AI đề xuất cắt "tiệc tùng" nhưng người dùng tăng lại):

```
feedback_event = {
  category, proposed_change, user_final_change, action: "accepted" | "rejected" | "modified"
}
```

- Nếu `rejected` nhiều lần trên cùng danh mục → giảm dần `elasticity` ước tính của danh mục đó (nó "cứng" hơn AI nghĩ) → essentiality tăng lên qua EMA ở mục 2.1.
- Lưu **implicit signal**: không hỏi người dùng "đây có phải thiết yếu không", mà suy ra từ hành động — giữ trải nghiệm mượt, không làm phiền.
- Giới hạn: không để 1-2 lần từ chối làm essentiality nhảy vọt (do EMA đã có $\alpha$ nhỏ, tự nhiên chống nhiễu).

### 2.6. Output gửi sang Tầng 3

```json
{
  "status": "resolved",
  "deficit_category": "an_uong",
  "deficit_amount": 600000,
  "adjustments": [
    {"category": "tiec_tung", "change": -400000, "reason": "high_slack_low_essentiality"},
    {"category": "giai_tri", "change": -200000, "reason": "high_slack_low_essentiality"}
  ],
  "goal_status": "on_track",
  "confidence_note": "tiec_tung có regularity thấp (0.3), tin cậy đề xuất cao"
}
```

---

## TẦNG 3 — SLM Diễn giải & Tương tác

### 3.1. Vai trò duy nhất: diễn giải, KHÔNG tính toán
SLM nhận JSON từ Tầng 2 làm **context/grounding**, nhiệm vụ:
- Sinh câu giải thích tự nhiên, đúng số liệu đã cho (không được tự suy ra số mới)
- Trả lời câu hỏi tự do của người dùng dựa trên context đã nạp (transaction summary, feature JSON)
- Điều chỉnh giọng điệu theo `status` (resolved → gợi ý nhẹ nhàng; insufficient_slack → cảnh báo rõ ràng)

### 3.2. Kỹ thuật prompt (grounded generation)

```
System prompt (cố định, không đổi):
"Bạn là trợ lý tài chính. CHỈ sử dụng số liệu trong JSON được cung cấp.
KHÔNG được tự tính toán, suy đoán, hoặc tạo ra con số không có trong dữ liệu.
Nếu thiếu thông tin để trả lời, hãy nói rõ là không có dữ liệu, không bịa."

User context (dynamic, bơm vào mỗi lần):
{JSON từ Tầng 2 + vài dòng feature liên quan từ Tầng 1}

User query: "Tại sao tháng này tôi vượt ngân sách ăn uống?"
```

- Dùng **structured output constraint** (ép SLM chỉ được trích dẫn số trong context, có thể kiểm tra bằng regex/validator sau khi sinh: nếu số trong output không khớp số nào trong JSON input → reject và fallback về template cứng)

### 3.3. Cơ chế an toàn (Guardrail) — quan trọng với app tài chính

| Rủi ro | Cách xử lý |
|---|---|
| SLM bịa số liệu (hallucination) | Validator: parse số trong output, đối chiếu với JSON input, không khớp → dùng template fallback |
| SLM đưa lời khuyên tài chính vượt phạm vi (đầu tư, vay nợ...) | Giới hạn system prompt phạm vi chủ đề, có blocklist chủ đề nhạy cảm |
| Model quá yếu, output vô nghĩa | Fallback 2 lớp: SLM lỗi → dùng template có sẵn (string interpolation từ JSON) — người dùng vẫn nhận được thông tin đúng dù không "mượt" bằng AI |
| Số tiền/quyết định quan trọng | Luôn hiển thị kèm **số liệu thô** (bảng/card) bên cạnh câu văn AI sinh ra — không để người dùng chỉ thấy văn bản mà không thấy nguồn số |

### 3.4. Lựa chọn model & runtime

| Lựa chọn | Ghi chú |
|---|---|
| **Gemma 3n / Gemma Nano** qua Google AI Edge | Tối ưu cho Android, có quantization sẵn (int4/int8) |
| **MediaPipe LLM Inference API** | Dễ tích hợp nhất, hỗ trợ nhiều model nhỏ (1-4B) |
| **Apple Foundation Models** (iOS 18+) | Nếu build iOS, tận dụng model hệ thống có sẵn, không cần bundle riêng |
| **llama.cpp + GGUF** | Linh hoạt nhất nếu cần custom fine-tune, nhưng tốn công tích hợp hơn |

Khuyến nghị: bắt đầu với **MediaPipe LLM Inference + Gemma nhỏ (2B, quantized 4-bit)** để có tooling ổn định, đo hiệu năng trên máy tầm trung trước khi quyết định custom fine-tune.

### 3.5. Fine-tune hay Prompt-only?

- Giai đoạn đầu: **không cần fine-tune**, dùng few-shot prompting với vài ví dụ mẫu (input JSON → output câu giải thích chuẩn) nạp trong system prompt.
- Fine-tune chỉ cân nhắc khi: (1) đã có đủ dữ liệu thật về style câu trả lời người dùng thích, (2) model prompt-only cho thấy giới hạn rõ (sai giọng điệu, dài dòng, không theo format). LoRA fine-tune nhẹ trên Gemma là khả thi nhưng nên là giai đoạn 2, không phải MVP.

---

## Ghi chú triển khai (Roadmap gợi ý)

1. **MVP**: Tầng 1 (thống kê) + Tầng 2 (rule-engine) chạy hoàn chỉnh, Tầng 3 dùng **template string** thuần (chưa cần SLM) → validate logic nghiệp vụ trước.
2. **V2**: Tích hợp SLM ở Tầng 3 với guardrail validator, A/B so sánh với template để đo mức độ người dùng thích/tin tưởng hơn.
3. **V3**: Conflict handling (mục 2.5) đưa vào, essentiality trở nên thực sự cá nhân hóa theo thời gian sử dụng.
4. **V4** (tùy chọn): Nâng Tầng 2 từ greedy algorithm lên linear programming thực sự nếu cần độ chính xác tối ưu toàn cục cao hơn.
