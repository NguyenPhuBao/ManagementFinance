# 🧠 ĐẶC TẢ KIẾN TRÚC & QUY TẮC NGHIỆP VỤ AI ĐIỀU PHỐI NGÂN SÁCH (ON-DEVICE EDGE SLM) — CLIENT-APP

Tài liệu này là **Nguồn sự thật (Source of Truth)** toàn diện về kiến trúc, bản phác thảo thiết kế và toàn bộ hệ thống quy tắc nghiệp vụ vận hành (Business Rules) của hệ thống AI thông minh cục bộ trên thiết bị di động (**On-device Edge AI / "AI Điên"**) cho ứng dụng **Client-app (ManagementFinance)**.

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

### Tổng quan luồng dữ liệu

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

### TẦNG 1 — Feature Engineering (Thống kê, chạy nền)

#### 1.1. Trigger & tần suất chạy
- Chạy **incremental** mỗi khi có giao dịch mới (cập nhật rolling stats, chi phí tính toán thấp — $O(1)$ amortized nếu dùng thuật toán online như Welford's algorithm cho mean/variance).
- Chạy **full recompute** định kỳ (đầu ngày, hoặc khi mở app sau >6h) để đồng bộ lại trend/regularity.

#### 1.2. Dữ liệu đầu vào
```
Transaction = {
  id, amount, category_id, timestamp,
  is_recurring_hint (nếu người dùng đã gắn nhãn "định kỳ"),
  merchant/note (optional, dùng để clustering nếu category chưa gán)
}
```

#### 1.3. Đặc trưng tính cho mỗi danh mục (category-level features)

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

#### 1.4. Xử lý dữ liệu thưa (cold start)
- Danh mục mới hoặc < 2 tháng dữ liệu: dùng **giá trị mặc định theo nhóm** (VD nhóm "ăn uống" mặc định essentiality cao hơn nhóm "giải trí") làm prior, sau đó Bayesian update dần khi có thêm dữ liệu thực — tránh kết luận vội trên mẫu nhỏ.

#### 1.5. Output (đưa sang Tầng 2)
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

### TẦNG 2 — Reasoning & Optimization Engine

#### 2.1. Essentiality Score (điểm thiết yếu — học theo hành vi)

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

#### 2.2. Phát hiện thâm hụt & chọn nguồn bù

```
deficit[i] = projected_spend[i] - budget_limit[i]     // nếu > threshold → kích hoạt

slack[j] = budget_limit[j] - projected_spend[j]        // dư địa còn lại
donor_score[j] = slack[j] * (1 - essentiality[j])      // dư nhiều + không thiết yếu = ưu tiên cắt
```

Sắp xếp donor theo `donor_score` giảm dần, chọn lần lượt.

#### 2.3. Thuật toán phân bổ lại

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

#### 2.4. Ràng buộc mục tiêu tiết kiệm (Goal Constraint)

```
total_allowed = income * (1 - saving_goal_ratio)

if Σ new_budget[j] > total_allowed:
    excess = Σ new_budget[j] - total_allowed
    for each non-essential category j (essentiality < threshold):
        cut[j] = excess * ( (1-essentiality[j]) / Σ(1-essentiality[k]) )   # cắt tỷ lệ theo mức "không thiết yếu"
        new_budget[j] -= cut[j]
```

#### 2.5. Conflict Handling — học từ chỉnh tay của người dùng

Khi người dùng **từ chối** hoặc **tự sửa** đề xuất (VD: AI đề xuất cắt "tiệc tùng" nhưng người dùng tăng lại):

```
feedback_event = {
  category, proposed_change, user_final_change, action: "accepted" | "rejected" | "modified"
}
```

- Nếu `rejected` nhiều lần trên cùng danh mục → giảm dần `elasticity` ước tính của danh mục đó (nó "cứng" hơn AI nghĩ) → essentiality tăng lên qua EMA ở mục 2.1.
- Lưu **implicit signal**: không hỏi người dùng "đây có phải thiết yếu không", mà suy ra từ hành động — giữ trải nghiệm mượt, không làm phiền.
- Giới hạn: không để 1-2 lần từ chối làm essentiality nhảy vọt (do EMA đã có $\alpha$ nhỏ, tự nhiên chống nhiễu).

#### 2.6. Output gửi sang Tầng 3

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

### TẦNG 3 — SLM Diễn giải & Tương tác

#### 3.1. Vai trò duy nhất: diễn giải, KHÔNG tính toán
SLM nhận JSON từ Tầng 2 làm **context/grounding**, nhiệm vụ:
- Sinh câu giải thích tự nhiên, đúng số liệu đã cho (không được tự suy ra số mới).
- Trả lời câu hỏi tự do của người dùng dựa trên context đã nạp (transaction summary, feature JSON).
- Điều chỉnh giọng điệu theo `status` (resolved $\rightarrow$ gợi ý nhẹ nhàng; insufficient_slack $\rightarrow$ cảnh báo rõ ràng).

#### 3.2. Kỹ thuật prompt (grounded generation)

```
System prompt (cố định, không đổi):
"Bạn là trợ lý tài chính. CHỈ sử dụng số liệu trong JSON được cung cấp.
KHÔNG được tự tính toán, suy đoán, hoặc tạo ra con số không có trong dữ liệu.
Nếu thiếu thông tin để trả lời, hãy nói rõ là không có dữ liệu, không bịa."

User context (dynamic, bơm vào mỗi lần):
{JSON từ Tầng 2 + vài dòng feature liên quan từ Tầng 1}

User query: "Tại sao tháng này tôi vượt ngân sách ăn uống?"
```

- Dùng **structured output constraint** (ép SLM chỉ được trích dẫn số trong context, có thể kiểm tra bằng regex/validator sau khi sinh: nếu số trong output không khớp số nào trong JSON input $\rightarrow$ reject và fallback về template cứng).

#### 3.3. Cơ chế an toàn (Guardrail) — quan trọng với app tài chính

| Rủi ro | Cách xử lý |
|---|---|
| SLM bịa số liệu (hallucination) | Validator: parse số trong output, đối chiếu với JSON input, không khớp $\rightarrow$ dùng template fallback |
| SLM đưa lời khuyên tài chính vượt phạm vi (đầu tư, vay nợ...) | Giới hạn system prompt phạm vi chủ đề, có blocklist chủ đề nhạy cảm |
| Model quá yếu, output vô nghĩa | Fallback 2 lớp: SLM lỗi $\rightarrow$ dùng template có sẵn (string interpolation từ JSON) — người dùng vẫn nhận được thông tin đúng dù không "mượt" bằng AI |
| Số tiền/quyết định quan trọng | Luôn hiển thị kèm **số liệu thô** (bảng/card) bên cạnh câu văn AI sinh ra — không để người dùng chỉ thấy văn bản mà không thấy nguồn số |

#### 3.4. Lựa chọn model & runtime

| Lựa chọn | Ghi chú |
|---|---|
| **Gemma 3n / Gemma Nano** qua Google AI Edge | Tối ưu cho Android, có quantization sẵn (int4/int8) |
| **MediaPipe LLM Inference API** | Dễ tích hợp nhất, hỗ trợ nhiều model nhỏ (1-4B) |
| **Apple Foundation Models** (iOS 18+) | Nếu build iOS, tận dụng model hệ thống có sẵn, không cần bundle riêng |
| **llama.cpp + GGUF** | Linh hoạt nhất nếu cần custom fine-tune, nhưng tốn công tích hợp hơn |

Khuyến nghị: bắt đầu với **MediaPipe LLM Inference + Gemma nhỏ (2B, quantized 4-bit)** để có tooling ổn định, đo hiệu năng trên máy tầm trung trước khi quyết định custom fine-tune.

#### 3.5. Fine-tune hay Prompt-only?
- Giai đoạn đầu: **không cần fine-tune**, dùng few-shot prompting với vài ví dụ mẫu (input JSON $\rightarrow$ output câu giải thích chuẩn) nạp trong system prompt.
- Fine-tune chỉ cân nhắc khi: (1) đã có đủ dữ liệu thật về style câu trả lời người dùng thích, (2) model prompt-only cho thấy giới hạn rõ (sai giọng điệu, dài dòng, không theo format). LoRA fine-tune nhẹ trên Gemma là khả thi nhưng nên là giai đoạn 2, không phải MVP.

#### 3.6. Ghi chú triển khai (Roadmap gợi ý)
1. **MVP**: Tầng 1 (thống kê) + Tầng 2 (rule-engine) chạy hoàn chỉnh, Tầng 3 dùng **template string** thuần (chưa cần SLM) $\rightarrow$ validate logic nghiệp vụ trước.
2. **V2**: Tích hợp SLM ở Tầng 3 với guardrail validator, A/B so sánh với template để đo mức độ người dùng thích/tin tưởng hơn.
3. **V3**: Conflict handling (mục 2.5) đưa vào, essentiality trở nên thực sự cá nhân hóa theo thời gian sử dụng.
4. **V4** (tùy chọn): Nâng Tầng 2 từ greedy algorithm lên linear programming thực sự nếu cần độ chính xác tối ưu toàn cục cao hơn.

---

## 📜 PHẦN III: HỆ THỐNG QUY TẮC NGHIỆP VỤ & ĐẶC TẢ VẬN HÀNH CHI TIẾT (BUSINESS RULES)

Phần này chốt lại toàn bộ các quy tắc nghiệp vụ thực chiến — kết hợp chặt chẽ giữa **7 nhóm quy tắc kinh doanh (A-G)** và **4 giải pháp khắc phục góc khuất kỹ thuật/toán học**. Đây là luật bất biến để hệ thống vận hành nhất quán, chính xác về toán và hợp lý về trải nghiệm người dùng.

---

### 🧹 NHÓM A: Quy Tắc Phân Loại, Làm Sạch & Nhận Diện Bản Chất Giao Dịch

| Mã Quy Tắc | Tên Quy Tắc | Nội Dung Chi Tiết & Giải Thuật Thực Hiện | Lý Do Kỹ Thuật & Nghiệp Vụ |
|:---:|---|---|---|
| **A1** | **Xử lý Outlier Chi Tiêu Đột Biến** | Nếu một giao dịch có giá trị: `amount > 3 * avg_spend` của danh mục đó (hoặc vượt ngưỡng tuyệt đối do người dùng cấu hình), giao dịch sẽ được gắn cờ `is_outlier = true`.<br>• Giao dịch bị **loại trừ hoàn toàn** khỏi phép tính `avg_spend_3m`, `avg_spend_6m`, `CV`, `trend_slope`.<br>• Giao dịch **vẫn được tính 100%** vào `current_spend` và `projected_spend` của tháng hiện tại. | Tránh trường hợp 1 giao dịch mua xe máy hay đồ điện tử đắt tiền trong mục "Mua sắm" làm méo mó baseline dài hạn, nhưng vẫn phải phản ánh đúng nguy cơ thủng ngân sách trong tháng hiện tại. |
| **A2** | **Loại Trừ Giao Dịch Một Lần (One-Time Event)** | Giao dịch được người dùng gắn cờ thủ công `is_one_time = true` (viện phí, tai nạn, sửa nhà, mua đồ công nghệ) luôn bị loại khỏi tính toán `regularity` và `essentiality`. | Tránh việc hệ thống học nhầm các sự kiện hy hữu mang tính bất khả kháng thành nhu cầu lặp lại định kỳ. |
| **A3** | **Xử Lý Hoàn Tiền (Refund / Reversal)** | Khi phát sinh giao dịch hoàn tiền (`amount < 0` trong danh mục Chi tiêu), số tiền hoàn được cộng bù trực tiếp vào `current_spend` của **tháng ghi nhận refund** (`current_spend += amount`). Tuyệt đối không trừ lùi vào tháng gốc trong quá khứ. | Bảo toàn nguyên tắc thiết kế: Giữ tính đơn giản, không phải kích hoạt recompute lại lịch sử các tháng trước. |
| **A4** | **Chặn Giao Dịch Chưa Phân Loại (Uncategorized Guard)** | Các giao dịch chưa được gán danh mục (`category_id IS NULL`) tuyệt đối không được đưa vào Tầng 2 để tính tái phân bổ ngân sách (Reallocation) cho đến khi được gán danh mục hợp lệ (tự động qua Keyword/Merchant matching hoặc người dùng tự chọn). | Tránh đưa ra đề xuất tái phân bổ sai lệch do thiếu ngữ cảnh phân loại. |
| **A5** | **Bảo Vệ Outlier Trên Danh Mục Baseline Nhỏ** | Ngưỡng xác định `outlier` ở quy tắc A1 áp dụng hệ số $3\times$, nhưng nếu danh mục có `avg_spend < 100.000đ`, hệ thống chuyển sang dùng ngưỡng tuyệt đối tối thiểu (mặc định: `> 500.000đ`) mới tính là outlier. | Tránh tình trạng dương tính giả (False Positive) trên số nhỏ (Ví dụ: Danh mục gửi xe tháng trước chi 20.000đ, tháng này phát sinh 80.000đ là gấp 4 lần nhưng không phải outlier bất thường). |
| **A6** *(Góc khuất 2)* | **Phân Tách Chi Phí Một Lần (Lump-sum) vs Liên Tục (Continuous)** | Hệ thống phân loại bản chất danh mục dựa trên tần suất:<br>• **Khoản chi một lần / Cố định (Lump-sum Fixed):** Danh mục có `txn_frequency <= 2` và `regularity >= 0.8` (Tiền nhà, tiền điện, tiền mạng, học phí).<br>• **Khoản chi liên tục (Continuous):** Danh mục có `txn_frequency > 5` (Ăn uống, cafe, đi chợ, đổ xăng). | Khoản chi một lần phát sinh tập trung vào 1 ngày duy nhất trong tháng, không thể nhân tỷ lệ theo ngày trôi qua vì sẽ làm sai lệch dự phóng. |

---

### 🚨 NHÓM B: Quy Tắc Kích Hoạt Cảnh Báo & Dự Phóng Ngân Sách (Deficit Detection)

| Mã Quy Tắc | Tên Quy Tắc | Nội Dung Chi Tiết & Công Thức Chuẩn Hóa | Lý Do Kỹ Thuật & Nghiệp Vụ |
|:---:|---|---|---|
| **B1** | **Ngưỡng Dữ Liệu Tối Thiểu (Cold-start Guard)** | Chỉ kích hoạt tính năng phát hiện thâm hụt và đề xuất nguồn bù cho danh mục khi danh mục đó đã tích lũy **$\ge 2$ tháng dữ liệu thực tế**. Dưới 2 tháng chỉ hiển thị theo dõi cơ bản. | Tránh việc đưa ra cảnh báo và đề xuất sai lệch khi mẫu dữ liệu chưa đủ độ tin cậy thống kê. |
| **B2** | **Bộ Lọc Thâm Hụt Kép (Dual Deficit Threshold)** | Cảnh báo thâm hụt danh mục chỉ được kích hoạt khi thỏa mãn **ĐỒNG THỜI 2 ĐIỀU KIỆN**:<br>1. Điều kiện tỷ lệ: $\frac{\text{deficit}[i]}{\text{budget\_limit}[i]} \ge 10\%$<br>2. Điều kiện giá trị tuyệt đối: $\text{deficit}[i] \ge 50.000đ$. | Triệt tiêu hoàn toàn các cảnh báo spam khi người dùng chỉ vượt ngân sách vài nghìn hoặc vài chục nghìn đồng không đáng kể. |
| **B3** | **Cửa Sổ Giảm Tải Cảnh Báo (48-Hour Cooldown Window)** | Không kích hoạt cảnh báo mới cho cùng một danh mục trong vòng **48 giờ** kể từ lần cảnh báo gần nhất, **TRỪ KHI** mức độ thâm hụt tăng thêm $\ge 20\%$ so với lần cảnh báo trước đó. | Tránh gây phiền hà, làm người dùng mệt mỏi khi nhận thông báo liên tục trong ngày. |
| **B4** *(Góc khuất 1)* | **Khóa Dự Phóng Đầu Tháng (Early-Month Spike Lock)** | Trong **5 ngày đầu tiên của tháng** (`days_elapsed < 5`), hệ thống **CẤM HOÀN TOÀN** việc áp dụng công thức nhân tỷ lệ tuyến tính (`current_spend * days_in_month / days_elapsed`) để cảnh báo thâm hụt. | Khắc phục triệt để lỗi chia cho số nhỏ (Small Sample Trap): Người dùng đóng tiền nhà 5 triệu vào ngày mùng 2 sẽ không bị hệ thống tính thành 75 triệu/tháng. |
| **B5** *(Góc khuất 1)* | **Công Thức Dự Phóng Nội Suy Bayesian (Bayesian Projection)** | Quy tắc tính `projected_spend` chuẩn theo từng mốc thời gian và loại chi phí:<br>• **Với danh mục Lump-sum Fixed (Quy tắc A6):**<br>  $$\text{projected\_spend} = \max(\text{current\_spend}, \text{avg\_spend\_3m})$$<br>• **Với danh mục Continuous:**<br>  - Nếu `days_elapsed < 5`: $\text{projected\_spend} = \text{current\_spend} + \text{avg\_spend\_3m} \times \frac{\text{days\_in\_month} - \text{days\_elapsed}}{\text{days\_in\_month}}$<br>  - Nếu `days_elapsed >= 5`: $\text{projected\_spend} = \text{current\_spend} \times \frac{\text{days\_in\_month}}{\text{days\_elapsed}}$. | Phản ánh chính xác tốc độ chi tiêu thực tế, dung hòa giữa lịch sử quá khứ và diễn biến thực tế đầu tháng. |
| **B6** | **Chống Quá Tải Thông Báo (AI Fatigue Prevention)** | Tối đa **1 đề xuất tái phân bổ chủ động/tuần** được phép hiển thị dưới dạng Thông báo đẩy (Push Notification) hoặc Pop-up. Toàn bộ các cảnh báo khác chỉ được hiển thị thụ động (Passive) trên màn hình Dashboard/Báo cáo khi người dùng tự mở app. | Giữ sự tôn trọng không gian riêng tư của người dùng; tránh biến AI thành "kẻ làm phiền" khiến người dùng tắt thông báo. |

---

### ⚖️ NHÓM C: Quy Tắc Chọn Nguồn Bù (Donor) & Giới Hạn Cắt Giảm

| Mã Quy Tắc | Tên Quy Tắc | Nội Dung Chi Tiết & Công Thức Chuẩn Hóa | Lý Do Kỹ Thuật & Nghiệp Vụ |
|:---:|---|---|---|
| **C1** | **Danh Mục Bảo Vệ Tuyệt Đối (Protected Category)** | Mọi danh mục có điểm thiết yếu $\text{essentiality} \ge 0.75$ được tự động gắn cờ **Protected** $\rightarrow$ **CẤM TUYỆT ĐỐI** không bao giờ được chọn làm nguồn bù (Donor), bất kể danh mục đó đang có dư địa (`slack`) lớn đến mức nào. | Bảo vệ các chi phí sống còn: AI tuyệt đối không bao giờ được khuyên cắt tiền thuê nhà, tiền học phí, tiền điện nước hay bảo hiểm để bù sang tiền ăn uống. |
| **C2** | **Quyền Ghi Đè Thủ Công (Manual Override)** | Danh mục do người dùng tự gắn nhãn "Cố định / Không đụng vào" trong cài đặt cá nhân sẽ có **quyền lực tối cao** ghi đè lên mọi tính toán tự động của AI $\rightarrow$ Lập tức đưa vào danh sách Protected. | Tôn trọng 100% quyền tự quyết và quan điểm giá trị cá nhân của người dùng. |
| **C3** | **Giới Hạn Tỷ Lệ Cắt Giảm Động (Adaptive Max Cut Ratio)** | Tỷ lệ cắt giảm tối đa `max_cut_ratio` mặc định là **$25\%$** trên phần dư địa (`slack`) của donor trong một lần đề xuất.<br>• Nếu danh mục donor đó **đã bị cắt trong 2 tháng liên tiếp gần nhất**, hạ tỷ lệ xuống tối đa **$15\%$** cho lần tiếp theo. | Tránh việc "bóp nghẹt" liên tục một danh mục yêu thích của người dùng qua nhiều tháng gây cảm giác bức bối, ức chế. |
| **C4** *(Góc khuất 4)* | **Vùng Đệm An Toàn Của Donor (Donor Safety Buffer)** | Một danh mục chỉ đủ điều kiện làm Donor khi thỏa mãn: `slack[j] >= MIN_DONOR_SLACK` (mặc định: **100.000đ**). Nếu dư địa dưới 100.000đ $\rightarrow$ Bỏ qua không chọn làm nguồn bù. | Tránh rút cạn ngân sách của donor về mức 0 đồng, luôn giữ một khoản đệm an toàn cho các nhu cầu bất ngờ của chính danh mục đó. |
| **C5** *(Góc khuất 4)* | **Ngưỡng Điều Chuyển Có Ý Nghĩa (Min Meaningful Amount)** | Không bao giờ sinh đề xuất điều chuyển nếu số tiền cắt giảm nhỏ hơn `MIN_MEANINGFUL_AMOUNT` (được tính bằng $\max(1\%\ \text{thu nhập}, 50.000đ)$). | Loại bỏ các đề xuất vụn vặt, vô nghĩa (như bớt 5.000đ hay 12.000đ) làm giảm uy tín và tính chuyên nghiệp của trợ lý AI. |
| **C6** | **Chỉ Số Ưu Tiên Tuyển Chọn Nguồn Bù** | Các donor hợp lệ được xếp hạng theo công thức: `donor_score[j] = slack[j] * (1 - essentiality[j])`. Ưu tiên chọn danh mục có dư địa nhiều nhất và ít thiết yếu nhất trước. | Tối ưu hóa việc phân bổ: Lấy từ nơi có khả năng chi trả cao nhất với mức độ ảnh hưởng đến chất lượng sống thấp nhất. |
| **C7** | **Xử Lý Cạn Kiệt Nguồn Bù (Insufficient Slack Handling)** | Nếu tất cả các donor khả dụng đều đã ở trạng thái Protected hoặc tổng `slack` không đủ bù đắp $\rightarrow$ Hàm `reallocate` trả về trạng thái `status: 'insufficient_slack'`, báo rõ số tiền thiếu hụt (`shortfall`). Tuyệt đối không cố ép tính toán để sinh ra con số vô căn cứ. | Đảm bảo tính trung thực: Giúp người dùng nhận thức rõ tổng thu nhập không đủ gánh tổng mức sống, chuyển từ "tái phân bổ nội bộ" sang "cắt giảm chi tiêu toàn diện". |

---

### 🎯 NHÓM D: Quy Tắc Mục Tiêu Tài Chính & Quản Lý Thu Nhập Biến Động

| Mã Quy Tắc | Tên Quy Tắc | Nội Dung Chi Tiết & Quy Chuẩn Áp Dụng | Lý Do Kỹ Thuật & Nghiệp Vụ |
|:---:|---|---|---|
| **D1** | **Xử Lý Thu Nhập Không Cố Định (Freelance / Kinh Doanh)** | Với người dùng có thu nhập biến động, giá trị `income` đưa vào Tầng 2 để tính toán là **Trung bình trượt 3 tháng gần nhất** (`avg_income_3m`), không dùng số thu nhập thực nhận của tháng hiện tại. | Tránh tính sai margin và mục tiêu khi tháng hiện tại tiền lương/doanh thu chưa về đủ tài khoản. |
| **D2** | **Chế Độ Thận Trọng Tức Thì (Precautionary Mode)** | Khi phát hiện thu nhập thực tế của tháng hiện tại bị sụt giảm $> 30\%$ so với mức trung bình 3 tháng $\rightarrow$ Hệ thống lập tức kích hoạt Chế độ Thận trọng: Tự động hạ toàn bộ `budget_limit` của các danh mục linh hoạt theo tỷ lệ tương ứng trước khi tính thâm hụt. | Chủ động phòng ngừa rủi ro tài chính sớm thay vì chờ thâm hụt xảy ra rồi mới đi tìm nguồn bù. |
| **D3** | **Bất Khả Xâm Phạm Mục Tiêu Tiết Kiệm (Goal Sovereign)** | Tỷ lệ mục tiêu tiết kiệm (`saving_goal_ratio`) do người dùng toàn quyền thiết lập. AI **tuyệt đối không tự ý tăng giảm mục tiêu này** mà chỉ đưa ra khuyến nghị phân tích để người dùng tự xác nhận. | Mục tiêu tiết kiệm là quyết định tài chính cá nhân mang tính chiến lược, AI không được phép áp đặt. |
| **D4** | **Cảnh Báo Thâm Hụt Cấu Trúc Dài Hạn** | Nếu tình trạng mục tiêu tiết kiệm rơi vào trạng thái nguy cấp (`goal_status = 'at_risk'`) trong **3 tháng liên tiếp** $\rightarrow$ Hệ thống chuyển đổi chiến lược: Ngừng đề xuất tái phân bổ vụn vặt hàng tuần, chuyển sang khuyến nghị xem xét lại cơ cấu mục tiêu hoặc kế hoạch tài chính vĩ mô. | Khi vấn đề mang tính cơ cấu (thu không đủ bù chi dài hạn), việc tái phân bổ vi mô giữa các danh mục không còn giải quyết được tận gốc vấn đề. |
| **D5** | **Ràng Buộc Trần Ngân Sách Tuyệt Đối** | Tổng ngân sách sau khi điều phối lại bắt buộc thỏa mãn: $\sum \text{new\_budget}[j] \le \text{income} \times (1 - \text{saving\_goal\_ratio})$. Nếu vi phạm, phần vượt (`excess`) sẽ bị trừ dần vào các danh mục có `essentiality < 0.5`. | Đảm bảo nguyên tắc kế toán vàng: Không bao giờ chi vượt quá khả năng thu nhập trừ đi khoản tiết kiệm bắt buộc. |

---

### 🤝 NHÓM E: Quy Tắc Tương Tác, Xác Nhận & Học Ngầm Thói Quen (Implicit Learning)

| Mã Quy Tắc | Tên Quy Tắc | Nội Dung Chi Tiết & Giải Thuật Học Tập | Lý Do Kỹ Thuật & Nghiệp Vụ |
|:---:|---|---|---|
| **E1** | **Trạng Thái Chờ Duyệt (Pending Confirmation)** | Mọi kế hoạch điều chỉnh ngân sách do AI đề xuất đều ở trạng thái `status: 'pending'`. **Tuyệt đối không tự động cập nhật CSDL ngân sách** nếu người dùng chưa bấm nút "Xác nhận áp dụng". | Nguyên tắc đạo đức nghề nghiệp Fintech: AI chỉ giữ vai trò cố vấn, người dùng nắm 100% quyền quyết định đồng tiền của mình. |
| **E2** | **Chấp Nhận Từng Phần (Partial Plan Acceptance)** | Giao diện cho phép người dùng tick chọn chấp nhận từng hạng mục trong kế hoạch (Ví dụ: Đồng ý trích 400k từ "Tiệc tùng" nhưng bỏ chọn trích 200k từ "Giải trí"). Hệ thống chỉ thực thi những điều chỉnh được tick chọn. | Tôn trọng tự do ý chí của người dùng, không ép buộc theo kiểu "chấp nhận tất cả hoặc không gì cả". |
| **E3** | **Thu Thập Tín Hiệu Học Ngầm (Implicit Feedback Event)** | Mỗi hành động của người dùng sinh ra một bản ghi sự kiện:<br>`feedback_event = { category_id, proposed_change, user_final_change, action: 'accepted' | 'rejected' | 'modified' }`.<br>Nếu người dùng tự sửa số tiền, `user_final_change` được lưu lại làm cơ sở học tập cho các lần sau. | Học từ hành vi thực tế một cách tự nhiên, không cần làm phiền người dùng bằng các câu hỏi khảo sát. |
| **E4** | **Cập Nhật Điểm Co Giãn & Thiết Yếu Qua Phản Hồi** | Nếu một danh mục bị `rejected` liên tiếp 2 lần khi được đề xuất làm donor:<br>• Hệ số co giãn ước tính giảm: $\text{elasticity} = \text{elasticity} \times 0.7$.<br>• Điểm thiết yếu mới được cập nhật qua EMA: $\text{essentiality}_{\text{new}} = 0.25 \times \text{essentiality}_{\text{computed}} + 0.75 \times \text{essentiality}_{\text{old}}$. | Nhận diện danh mục này thực chất rất quan trọng với người dùng (dù chi tiêu có vẻ biến động), lần sau AI sẽ tự động tránh chọn danh mục này làm nguồn cắt. |
| **E5** | **Phân Biệt Trực Quan Giao Diện (UI Status Distinction)** | Đề xuất ở trạng thái `resolved` (cân đối thành công) hiển thị thẻ màu Xanh dương/Xanh lá với icon gợi ý nhẹ nhàng. Đề xuất ở trạng thái `insufficient_slack` (thiếu hụt thực sự) hiển thị thẻ màu Cam/Đỏ cảnh báo kèm icon nguy cấp. | Giúp người dùng phân biệt rạch ròi giữa một "gợi ý tối ưu hóa chi tiêu bình thường" và một "cảnh báo nguy cơ khủng hoảng ngân sách". |

---

### ⚡ NHÓM H: Quy Tắc Hiệu Năng Mobile, Luồng Xử Lý & Bộ Nhớ Cục Bộ

*(Tích hợp giải pháp từ Góc khuất 3)*

| Mã Quy Tắc | Tên Quy Tắc | Nội Dung Chi Tiết & Giải Pháp Kiến Trúc | Lý Do Kỹ Thuật & Nghiệp Vụ |
|:---:|---|---|---|
| **H1** | **Cách Ly Tiến Trình Nền (Background Isolate Separation)** | Toàn bộ các tác vụ tính toán Tầng 1 (Full recompute), Tầng 2 (Tối ưu hóa phân bổ) và Tầng 3 (Chạy suy luận SLM + Regex Validator) **BẮT BUỘC PHẢI CHẠY TRONG DART ISOLATE / `compute()`**. Tuyệt đối không chạy trên Main UI Thread. | Đảm bảo giao diện người dùng trên Flutter luôn duy trì mượt mà 60 FPS / 120 FPS, không bị giật lag hay đơ màn hình khi AI đang suy luận. |
| **H2** | **Quản Lý Mức Pin & Nhiệt Độ (Thermal & Battery Throttling)** | Nếu pin thiết bị $< 15\%$ hoặc hệ điều hành báo trạng thái thiết bị quá nhiệt (Thermal Throttling):<br>• Tạm hoãn việc khởi chạy mô hình SLM Tầng 3.<br>• Tự động chuyển sang sử dụng bộ sinh câu mẫu **Template String** ở Tầng 3. | Bảo vệ phần cứng điện thoại, tiết kiệm pin tối đa và phòng ngừa ứng dụng bị hệ điều hành tắt ngang. |
| **H3** | **Cơ Chế Suy Thoái Mềm (Graceful Degradation Fallback)** | Với các thiết bị đời cũ có RAM khả dụng $< 1.0\text{GB}$, hoặc khi thư viện suy luận SLM gặp lỗi khởi tạo runtime $\rightarrow$ Tầng 1 và Tầng 2 vẫn chạy 100% bình thường, Tầng 3 chuyển 100% sang Template String Engine mà không hiển thị thông báo lỗi kỹ thuật nào ra UI. | Đảm bảo trải nghiệm người dùng không bao giờ bị đứt gãy hay crash app trên mọi dòng máy từ yếu đến mạnh. |
| **H4** | **Cấu Trúc Bảng Dữ Liệu SQLite Cục Bộ Của AI Điên** | Thiết lập 2 bảng SQLite nội bộ trên Client-app để lưu trữ trạng thái hoạt động (không đồng bộ lên Backend để bảo đảm tốc độ và quyền riêng tư):<br>1. `local_category_features`: Lưu các chỉ số đặc trưng đã tính toán (Tầng 1 cache).<br>2. `local_rebalancing_feedback`: Lưu trữ nhật ký phản hồi ngầm phục vụ vòng lặp học tập của Tầng 2. | Đạt tốc độ truy vấn tức thì $O(1)$, không phụ thuộc vào kết nối mạng hay server. |

---

### 🛡️ NHÓM F: Quy Tắc Bảo Mật & Quyền Riêng Tư Cục Bộ (100% On-Device Privacy)

| Mã Quy Tắc | Tên Quy Tắc | Nội Dung Chi Tiết & Ràng Buộc Kỹ Thuật | Căn Cứ Pháp Lý & An Toàn |
|:---:|---|---|---|
| **F1** | **Bảo Mật Cục Bộ Tuyệt Đối (Air-Gapped Processing)** | Toàn bộ dữ liệu giao dịch thô, bảng đặc trưng Feature JSON (Tầng 1) và kế hoạch tái phân bổ Reallocation JSON (Tầng 2) **hoàn toàn không được phép rời khỏi thiết bị di động**. Không gửi dữ liệu này lên bất kỳ API phân tích nào của bên thứ ba. | Tuân thủ 100% Nghị định 13/2023/NĐ-CP, Luật Bảo vệ dữ liệu cá nhân 2025 và chuẩn PCI-DSS. |
| **F2** | **Mã Hóa Đồng Bộ Đầu Cuối (E2E Backup Protection)** | Trong trường hợp người dùng kích hoạt tính năng đồng bộ đám mây (Cloud Sync) của hệ thống: Toàn bộ ghi chú giao dịch, thông tin nhạy cảm đã được mã hóa AES-256 theo chuẩn `Data_Security.md`. Hệ thống AI Điên chỉ đọc và giải mã cục bộ trên máy để tính toán đặc trưng. | Đảm bảo dữ liệu an toàn ở cả 2 trạng thái: At-rest và In-transit. |
| **F3** | **Cô Lập Mạng Cho SLM On-Device (Zero Network Access)** | Thư viện suy luận mô hình SLM (MediaPipe / llama.cpp) được cấu hình chạy ở chế độ Offline 100%, không cấp quyền mở Socket hay HTTP Request ra Internet. Nếu trong tương lai có tùy chọn fallback sang Cloud LLM cho các câu hỏi phức tạp, bắt buộc phải có màn hình xin phép đồng ý rõ ràng (Consent Dialog) từ người dùng. | Triệt tiêu hoàn toàn nguy cơ lộ lọt dữ liệu thói quen chi tiêu cá nhân qua các truy vấn AI. |

---

### 📏 NHÓM G: Quy Tắc Làm Tròn Số Học & Định Dạng Hiển Thị (Rounding & Presentation)

*(Tích hợp giải pháp từ Góc khuất 4)*

| Mã Quy Tắc | Tên Quy Tắc | Nội Dung Chi Tiết & Định Dạng Hiển Thị | Trải Nghiệm Người Dùng (UX) |
|:---:|---|---|---|
| **G1** *(Góc khuất 4)* | **Làm Tròn Số Tiền Thực Tế Đến 10.000đ** | Mọi con số đề xuất điều chuyển hoặc cắt giảm ngân sách hiển thị cho người dùng **bắt buộc phải làm tròn đến bội số của 10.000đ** (hoặc 50.000đ) theo quy tắc làm tròn chuẩn: $\text{round}(x / 10000) \times 10000$.<br>*(Ví dụ: Tính toán nội bộ ra 437.582đ $\rightarrow$ Hiển thị đề xuất là **440.000đ**).* | Loại bỏ cảm giác "máy móc, gượng ép" khi người dùng nhìn thấy những con số lẻ vụn vặt; giúp người dùng dễ nhớ và dễ thực thi. |
| **G2** | **Làm Tròn Tỷ Lệ Phần Trăm (Percentage Rounding)** | Mọi tỷ lệ phần trăm (tỷ trọng chi tiêu, mức độ thâm hụt, tỷ lệ cắt giảm) hiển thị trên giao diện đều được làm tròn chính xác **1 chữ số thập phân** (Ví dụ: `15.4%`, `25.0%`). | Giữ giao diện gọn gàng, tinh tế, tránh hiển thị chuỗi số thập phân dài ngoằng gây rối mắt. |
| **G3** | **Bảng Dữ Liệu Đi Kèm Minh Bạch (Grounding Data Card)** | Mọi câu khuyến nghị hay lời thoại do SLM sinh ra bắt buộc phải được hiển thị kèm theo một **Thẻ Dữ Liệu Đối Soát (Data Card / Summary Table)** hiển thị các con số thô: Số ngân sách hiện tại, số dự kiến vượt, số tiền đề xuất điều chuyển. Người dùng không bao giờ chỉ đọc văn bản suông mà luôn nhìn thấy bằng chứng số liệu rõ ràng. | Tăng độ tin cậy tuyệt đối (Credibility), giúp người dùng dễ dàng thẩm định tính đúng đắn của đề xuất trước khi bấm duyệt. |

---

## 🏗️ PHẦN IV: CẤU TRÚC BẢNG DỮ LIỆU SQLITE CỤC BỘ CHO CLIENT-APP

Để hiện thực hóa toàn bộ các quy tắc trên mà không làm ảnh hưởng đến cấu trúc CSDL đồng bộ với Backend, Client-app sẽ tạo thêm 2 bảng nội bộ trên SQLite cục bộ (`local_only`):

```sql
-- 1. Bảng lưu trữ đặc trưng danh mục đã tính toán (Tầng 1 Cache)
CREATE TABLE IF NOT EXISTS local_category_features (
    category_id VARCHAR(36) PRIMARY KEY,
    month VARCHAR(7) NOT NULL,               -- Định dạng 'YYYY-MM'
    avg_spend_3m REAL DEFAULT 0,
    avg_spend_6m REAL DEFAULT 0,
    current_spend REAL DEFAULT 0,
    projected_spend REAL DEFAULT 0,
    budget_limit REAL DEFAULT 0,
    cv REAL DEFAULT 0,                       -- Hệ số biến thiên (Std / Mean)
    regularity REAL DEFAULT 0,               -- Tính chu kỳ (0.0 -> 1.0)
    elasticity REAL DEFAULT 0.5,             -- Độ co giãn chi tiêu
    essentiality REAL DEFAULT 0.5,           -- Điểm thiết yếu tổng hợp
    is_protected BOOLEAN DEFAULT FALSE,      -- Cờ bảo vệ tuyệt đối (Quy tắc C1, C2)
    category_nature VARCHAR(20) DEFAULT 'continuous', -- 'lump_sum' hoặc 'continuous' (A6)
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Bảng ghi nhận phản hồi người dùng để học ngầm hành vi (Tầng 2 Feedback Loop)
CREATE TABLE IF NOT EXISTS local_rebalancing_feedback (
    id VARCHAR(36) PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deficit_category_id VARCHAR(36) NOT NULL,
    donor_category_id VARCHAR(36) NOT NULL,
    suggested_amount REAL NOT NULL,
    actual_amount REAL NOT NULL,
    action VARCHAR(20) NOT NULL,             -- 'accepted', 'rejected', 'modified'
    applied BOOLEAN DEFAULT FALSE
);

-- 3. Bảng ghi nhận nhật ký cảnh báo để chống spam (Quy tắc B3 & B6)
CREATE TABLE IF NOT EXISTS local_ai_alert_history (
    id VARCHAR(36) PRIMARY KEY,
    category_id VARCHAR(36) NOT NULL,
    alert_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deficit_amount REAL NOT NULL,
    alert_type VARCHAR(20) NOT NULL          -- 'active_popup', 'passive_dashboard'
);
```

---

> [!TIP]
> Toàn bộ hệ thống quy tắc nghiệp vụ này đã được chốt và đồng bộ hoàn chỉnh, sẵn sàng làm tài liệu tham chiếu chuẩn mực cho các kỹ sư phát triển tính năng AI Điều Phối Ngân Sách trên Client-app (Flutter).
