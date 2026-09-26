# KIẾN TRÚC HỆ THỐNG AI — MANAGEMENTFINANCE (FLOWMONEY)

> **Phiên bản:** Tối Giản (Minimalist Architecture v2.2)  
> **Mục tiêu:** Trực quan, cô đọng, dễ hiểu ngay trong 5 giây, tối ưu hiển thị trên `app.diagrams.net`.

---

## 1. Sơ Đồ Mermaid Tối Giản (Dán vào Mermaid trong draw.io)

```mermaid
flowchart TB
  %% Theme & Styling tối giản, hiện đại
  classDef client fill:#EFF6FF,stroke:#3B82F6,stroke-width:2px,color:#1E3A8A;
  classDef edge fill:#EDE9FE,stroke:#8B5CF6,stroke-width:2px,color:#5B21B6;
  classDef gateway fill:#FEF3C7,stroke:#D97706,stroke-width:2px,color:#78350F;
  classDef service fill:#DCFCE7,stroke:#16A34A,stroke-width:2px,color:#064E3B;
  classDef cloud fill:#F1F5F9,stroke:#64748B,stroke-width:2px,color:#0F172A;

  subgraph CLIENT["📱 CLIENT (Mobile App - Flutter)"]
    direction LR
    LOCAL_DB[("Drift SQLite v24<br/>(Dữ liệu tài chính cá nhân)")]:::client
    EDGE_AI["<b>Edge AI (On-Device)</b><br/>Hệ luật: dự báo dòng tiền, tái phân bổ, nhận xét<br/><i>Gemma 4 E2B: Trợ lý AI (tool chỉ đọc, offline)</i>"]:::edge
    LOCAL_DB <-->|"100% Offline (F1)"| EDGE_AI
  end

  subgraph BACKEND["☁️ BACKEND (Cloud AI Platform - Node.js)"]
    direction TB
    GATEWAY["<b>AI Security Gateway</b><br/>Quản lý API Key tập trung · Lọc Masking PII văn bản (SĐT, STK, Thẻ)"]:::gateway

    subgraph PIPELINES["4 Dịch Vụ AI Cốt Lõi"]
      direction LR
      OCR["<b>1. Receipt OCR</b><br/>Trích xuất hóa đơn"]:::service
      CLASSIFIER["<b>2. Smart Classifier</b><br/>Tầng 3 Gemini Flash"]:::service
      ASSISTANT["<b>3. Financial Assistant</b><br/>Dual-Phase Privacy Shield"]:::service
      HEALTH["<b>4. Financial Health</b><br/>Chấm điểm FHS & 50/30/20"]:::service
    end

    GATEWAY --> PIPELINES
  end

  GEMINI["<b>🌐 Google Gemini 2.0 Flash</b><br/>Multimodal Vision & Few-shot API"]:::cloud

  %% Kết nối chính
  CLIENT -->|"Gửi ảnh biên lai & văn bản (HTTPS)"| GATEWAY
  PIPELINES -->|"Gọi API an toàn (Backend Key)"| GEMINI
```

---

## 2. Sơ Đồ PlantUML Tối Giản (Dán vào PlantUML trong draw.io)

```plantuml
@startuml
skinparam backgroundColor #FFFFFF
skinparam roundCorner 10
skinparam defaultFontName Arial
skinparam shadowing false

package "📱 CLIENT (Mobile App - Flutter)" #EFF6FF {
  database "Drift SQLite v24\n(Dữ liệu cá nhân cục bộ)" as LocalDB #DBEAFE
  component "<b>Edge AI (On-Device)</b>\nHệ luật: dự báo, tái phân bổ, nhận xét\n<i>Gemma 4 E2B: Trợ lý AI (tool chỉ đọc, offline)</i>" as EdgeAI #EDE9FE
  LocalDB <--> EdgeAI : 100% Offline (F1)
}

package "☁️ BACKEND (Cloud AI Platform)" #F8FAFC {
  component "<b>AI Security Gateway</b>\nQuản lý API Key tập trung · Lọc Masking PII văn bản" as Gateway #FEF3C7
  
  package "4 Dịch Vụ AI Cốt Lõi" #F1F5F9 {
    [1. Receipt OCR\nTrích xuất hóa đơn] as OCR #DCFCE7
    [2. Smart Classifier\nTầng 3 Gemini Flash] as Classify #DCFCE7
    [3. Financial Assistant\nDual-Phase Privacy Shield] as Chat #DCFCE7
    [4. Financial Health\nChấm điểm FHS & 50/30/20] as Health #DCFCE7
  }
  
  Gateway --> OCR
  Gateway --> Classify
  Gateway --> Chat
  Gateway --> Health
}

cloud "<b>🌐 Google Gemini 2.0 Flash</b>\n(Multimodal & Reasoning)" as Gemini #E2E8F0

LocalDB --> Gateway : Gửi ảnh biên lai & văn bản (HTTPS)
OCR --> Gemini
Classify --> Gemini
Chat --> Gemini
Health --> Gemini

@enduml
```

---

## 3. Ý Nghĩa 3 Trục Kiến Trúc Cốt Lõi

1. **Khối Client (Edge AI & Hệ luật cục bộ):** Chạy 100% Offline trên Mobile. Hệ luật đảm nhiệm dự báo dòng tiền 30 ngày, gợi ý ngân sách $\le 90$ ngày, tái phân bổ ngân sách C1–C7 và các khối nhận xét. Mô hình **Gemma 4 E2B** phục vụ màn Trợ lý AI hỏi đáp bằng 7 tool chỉ đọc dữ liệu từ Drift SQLite cục bộ; dữ liệu cá nhân tuyệt đối không ra ngoài.
2. **Khối Backend (Cloud AI Gateway):** Đóng vai trò chốt chặn an toàn: giữ bí mật API Key (không đưa lên mobile) và lọc bỏ dữ liệu nhạy cảm văn bản (`masking.util.js`) trước khi gọi ra ngoài.
3. **4 Dịch Vụ AI Cốt Lõi Tại Backend:** Quét hóa đơn (OCR), phân loại giao dịch tầng 3 (Classifier), trợ lý tài chính trực tuyến có Privacy Shield (Chatbot), và đánh giá sức khỏe tài chính Lối A (Financial Health Score) kết hợp trí tuệ Google Gemini 2.0 Flash.
