# KIẾN TRÚC HỆ THỐNG AI — MANAGEMENTFINANCE (FLOWMONEY)

> **Phiên bản:** Tối Giản (Minimalist Architecture v2.1)  
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
    EDGE_AI["<b>Edge AI (On-Device)</b><br/>Gemma 4 E2B + Hệ luật<br/><i>Dự báo dòng tiền & Tái phân bổ</i>"]:::edge
    LOCAL_DB <-->|"100% Offline (F1)"| EDGE_AI
  end

  subgraph BACKEND["☁️ BACKEND (Cloud AI Platform - Node.js)"]
    direction TB
    GATEWAY["<b>AI Security Gateway</b><br/>Quản lý API Key tập trung · Lọc Masking PII (SĐT, STK, Thẻ)"]:::gateway

    subgraph PIPELINES["3 Dịch Vụ AI Cốt Lõi"]
      direction LR
      OCR["<b>1. Receipt OCR</b><br/>Trích xuất hóa đơn"]:::service
      CLASSIFIER["<b>2. Smart Classifier</b><br/>Keyword → NLP → Gemini"]:::service
      ASSISTANT["<b>3. Financial Assistant</b><br/>Function-Calling + RAG"]:::service
    end

    GATEWAY --> PIPELINES
  end

  GEMINI["<b>🌐 Google Gemini 2.0 Flash</b><br/>Multimodal Vision & Few-shot API"]:::cloud

  %% Kết nối chính
  CLIENT -->|"Gửi ảnh biên lai & Text đã lọc PII (HTTPS)"| GATEWAY
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
  component "<b>Edge AI (On-Device)</b>\nGemma 4 E2B + Hệ luật\n<i>Dự báo dòng tiền & Tái phân bổ</i>" as EdgeAI #EDE9FE
  LocalDB <--> EdgeAI : 100% Offline (F1)
}

package "☁️ BACKEND (Cloud AI Platform)" #F8FAFC {
  component "<b>AI Security Gateway</b>\nQuản lý API Key tập trung · Lọc Masking PII" as Gateway #FEF3C7
  
  package "3 Dịch Vụ AI Cốt Lõi" #F1F5F9 {
    [1. Receipt OCR\nTrích xuất hóa đơn] as OCR #DCFCE7
    [2. Smart Classifier\nKeyword → NLP → Gemini] as Classify #DCFCE7
    [3. Financial Assistant\nFunction-Calling + RAG] as Chat #DCFCE7
  }
  
  Gateway --> OCR
  Gateway --> Classify
  Gateway --> Chat
}

cloud "<b>🌐 Google Gemini 2.0 Flash</b>\n(Multimodal & Reasoning)" as Gemini #E2E8F0

LocalDB --> Gateway : Gửi ảnh & Text đã Mask PII (HTTPS)
OCR --> Gemini
Classify --> Gemini
Chat --> Gemini

@enduml
```

---

## 3. Ý Nghĩa 3 Trục Kiến Trúc Cốt Lõi

1. **Khối Client (Edge AI):** Chạy 100% Offline trên Mobile. Mô hình **Gemma 4 E2B** đọc dữ liệu từ Drift SQLite cục bộ để dự báo và tối ưu ngân sách; dữ liệu cá nhân tuyệt đối không ra ngoài.
2. **Khối Backend (Cloud AI Gateway):** Đóng vai trò chốt chặn an toàn: giữ bí mật API Key (không đưa lên mobile) và lọc bỏ dữ liệu nhạy cảm (`masking.util.js`) trước khi gọi ra ngoài.
3. **3 Dịch Vụ AI Đám Mây:** Quét hóa đơn (OCR), phân loại giao dịch (Classifier), và trợ lý thông minh (Chatbot RAG) dùng chung mô hình Google Gemini 2.0 Flash.
