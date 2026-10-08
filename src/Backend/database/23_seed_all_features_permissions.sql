-- ============================================================================
-- Migration 23: Nạp toàn diện danh mục 17 tính năng và phân quyền 2 loại tài khoản
-- Ngày thực hiện: 2026-10-07
-- Cơ chế an toàn: ON CONFLICT DO UPDATE (Idempotent, không mất dữ liệu hiện có)
-- ============================================================================

-- 1. Nạp toàn bộ 17 tính năng hệ thống vào bảng feature
INSERT INTO "feature" ("id", "name", "description", "type", "category_group", "default_limit", "default_enabled", "created_at", "updated_at")
VALUES
  -- 📂 Nhóm 1: Tài nguyên hạn mức (LIMIT)
  ('wallets', 'Số lượng ví tối đa', 'Số lượng ví tiền mặt, tài khoản ngân hàng, ví điện tử có thể tạo', 'LIMIT', 'Tài nguyên', 3, true, NOW(), NOW()),
  ('budgets', 'Số lượng ngân sách', 'Số lượng ngân sách chi tiêu có thể thiết lập đồng thời', 'LIMIT', 'Tài nguyên', 3, true, NOW(), NOW()),
  ('goals', 'Số lượng mục tiêu', 'Số lượng mục tiêu tích lũy tiết kiệm có thể tạo', 'LIMIT', 'Tài nguyên', 3, true, NOW(), NOW()),
  ('bills', 'Hóa đơn định kỳ', 'Số chuỗi hóa đơn lặp lại còn mở theo dõi', 'LIMIT', 'Tài nguyên', 3, true, NOW(), NOW()),
  ('custom_categories', 'Danh mục tự tạo', 'Số lượng danh mục thu chi riêng người dùng tự thêm', 'LIMIT', 'Tài nguyên', 5, true, NOW(), NOW()),

  -- 🧠 Nhóm 2: Trí tuệ nhân tạo (TOGGLE)
  ('ai_assistant', 'Trợ lý tài chính Copilot AI', 'Hỏi đáp, tư vấn tài chính, tạo giao dịch/ngân sách qua ngôn ngữ tự nhiên', 'TOGGLE', 'Trí tuệ nhân tạo', NULL, true, NOW(), NOW()),
  ('ai_quick_input', 'Nhập nhanh bằng câu nói', 'Nhập văn bản tự nhiên để tự động bóc tách và điền form giao dịch', 'TOGGLE', 'Trí tuệ nhân tạo', NULL, true, NOW(), NOW()),
  ('ocr_receipt', 'Quét hóa đơn/biên lai OCR', 'Bóc tách ảnh chụp hóa đơn/biên lai thành giao dịch qua Gemini Vision', 'TOGGLE', 'Trí tuệ nhân tạo', NULL, true, NOW(), NOW()),
  ('ai_edge_model', 'Mô hình AI Offline on-device', 'Tải và chạy mô hình ngôn ngữ Gemma 4 E2B trực tiếp trên máy không cần mạng', 'TOGGLE', 'Trí tuệ nhân tạo', NULL, false, NOW(), NOW()),
  ('smart_budget_rebalancing', 'Tái phân bổ ngân sách AI', 'Tự động đề xuất điều chuyển hạn mức giữa các ngân sách khi sắp vượt ngưỡng', 'TOGGLE', 'Trí tuệ nhân tạo', NULL, false, NOW(), NOW()),

  -- 📊 Nhóm 3: Báo cáo & Phân tích (TOGGLE)
  ('financial_health_fhs', 'Sức khỏe tài chính FHS', 'Bản chụp Sức khỏe Tài chính FHS, đánh giá thang điểm 100 và cơ cấu 50/30/20', 'TOGGLE', 'Báo cáo & Phân tích', NULL, true, NOW(), NOW()),
  ('export_reports', 'Xuất báo cáo PDF / Excel', 'Xuất dữ liệu lịch sử thu chi ra định dạng tài liệu PDF hoặc bảng tính Excel/CSV', 'TOGGLE', 'Báo cáo & Phân tích', NULL, false, NOW(), NOW()),
  ('cashflow_forecast', 'Dự báo dòng tiền 30 ngày', 'Dự báo xu hướng số dư và dòng tiền tự do trong 30 ngày tới', 'TOGGLE', 'Báo cáo & Phân tích', NULL, false, NOW(), NOW()),
  ('anomaly_spending_insights', 'Cảnh báo chi tiêu bất thường', 'Phát hiện và cảnh báo các khoản chi đột biến so với thói quen', 'TOGGLE', 'Báo cáo & Phân tích', NULL, false, NOW(), NOW()),

  -- ⚡ Nhóm 4: Tự động hóa & Tiện ích (TOGGLE)
  ('bill_auto_pay', 'Tự động thanh toán hóa đơn', 'Tự động tạo giao dịch thanh toán khi hóa đơn đến hạn', 'TOGGLE', 'Tự động hóa & Tiện ích', NULL, false, NOW(), NOW()),
  ('goal_auto_deposit', 'Tự động trích tiền mục tiêu', 'Tự động trích tiền định kỳ từ ví vào hũ mục tiêu tiết kiệm', 'TOGGLE', 'Tự động hóa & Tiện ích', NULL, false, NOW(), NOW()),
  ('bank_notification_parser', 'Đọc biến động số dư on-device', 'Tự động nhận diện thông báo biến động số dư từ ứng dụng ngân hàng trên máy', 'TOGGLE', 'Tự động hóa & Tiện ích', NULL, true, NOW(), NOW())

ON CONFLICT ("id") DO UPDATE SET
  "name" = EXCLUDED."name",
  "description" = EXCLUDED."description",
  "type" = EXCLUDED."type",
  "category_group" = EXCLUDED."category_group",
  "default_limit" = EXCLUDED."default_limit",
  "default_enabled" = EXCLUDED."default_enabled",
  "updated_at" = NOW();


-- 2. Nạp cấu hình phân quyền cho gói Basic (Hạn chế tài nguyên & tính năng nâng cao)
INSERT INTO "account_type_permission" ("account_type", "feature_id", "is_enabled", "limit_value", "created_at", "updated_at")
VALUES
  -- Nhóm 1: Tài nguyên hạn mức
  ('Basic', 'wallets', true, 3, NOW(), NOW()),
  ('Basic', 'budgets', true, 3, NOW(), NOW()),
  ('Basic', 'goals', true, 3, NOW(), NOW()),
  ('Basic', 'bills', true, 3, NOW(), NOW()),
  ('Basic', 'custom_categories', true, 5, NOW(), NOW()),

  -- Nhóm 2: Trí tuệ nhân tạo
  ('Basic', 'ai_assistant', false, NULL, NOW(), NOW()),
  ('Basic', 'ai_quick_input', false, NULL, NOW(), NOW()),
  ('Basic', 'ocr_receipt', true, NULL, NOW(), NOW()),
  ('Basic', 'ai_edge_model', false, NULL, NOW(), NOW()),
  ('Basic', 'smart_budget_rebalancing', false, NULL, NOW(), NOW()),

  -- Nhóm 3: Báo cáo & Phân tích
  ('Basic', 'financial_health_fhs', true, NULL, NOW(), NOW()),
  ('Basic', 'export_reports', false, NULL, NOW(), NOW()),
  ('Basic', 'cashflow_forecast', false, NULL, NOW(), NOW()),
  ('Basic', 'anomaly_spending_insights', false, NULL, NOW(), NOW()),

  -- Nhóm 4: Tự động hóa & Tiện ích
  ('Basic', 'bill_auto_pay', false, NULL, NOW(), NOW()),
  ('Basic', 'goal_auto_deposit', false, NULL, NOW(), NOW()),
  ('Basic', 'bank_notification_parser', true, NULL, NOW(), NOW())

ON CONFLICT ("account_type", "feature_id") DO UPDATE SET
  "is_enabled" = EXCLUDED."is_enabled",
  "limit_value" = EXCLUDED."limit_value",
  "updated_at" = NOW();


-- 3. Nạp cấu hình phân quyền cho gói Premium (Mở khóa toàn bộ & Không giới hạn)
INSERT INTO "account_type_permission" ("account_type", "feature_id", "is_enabled", "limit_value", "created_at", "updated_at")
VALUES
  -- Nhóm 1: Tài nguyên hạn mức (Không giới hạn = NULL)
  ('Premium', 'wallets', true, NULL, NOW(), NOW()),
  ('Premium', 'budgets', true, NULL, NOW(), NOW()),
  ('Premium', 'goals', true, NULL, NOW(), NOW()),
  ('Premium', 'bills', true, NULL, NOW(), NOW()),
  ('Premium', 'custom_categories', true, NULL, NOW(), NOW()),

  -- Nhóm 2: Trí tuệ nhân tạo
  ('Premium', 'ai_assistant', true, NULL, NOW(), NOW()),
  ('Premium', 'ai_quick_input', true, NULL, NOW(), NOW()),
  ('Premium', 'ocr_receipt', true, NULL, NOW(), NOW()),
  ('Premium', 'ai_edge_model', true, NULL, NOW(), NOW()),
  ('Premium', 'smart_budget_rebalancing', true, NULL, NOW(), NOW()),

  -- Nhóm 3: Báo cáo & Phân tích
  ('Premium', 'financial_health_fhs', true, NULL, NOW(), NOW()),
  ('Premium', 'export_reports', true, NULL, NOW(), NOW()),
  ('Premium', 'cashflow_forecast', true, NULL, NOW(), NOW()),
  ('Premium', 'anomaly_spending_insights', true, NULL, NOW(), NOW()),

  -- Nhóm 4: Tự động hóa & Tiện ích
  ('Premium', 'bill_auto_pay', true, NULL, NOW(), NOW()),
  ('Premium', 'goal_auto_deposit', true, NULL, NOW(), NOW()),
  ('Premium', 'bank_notification_parser', true, NULL, NOW(), NOW())

ON CONFLICT ("account_type", "feature_id") DO UPDATE SET
  "is_enabled" = EXCLUDED."is_enabled",
  "limit_value" = EXCLUDED."limit_value",
  "updated_at" = NOW();
