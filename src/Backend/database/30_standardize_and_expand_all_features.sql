-- ============================================================================
-- Migration 30: Chuẩn hóa tên và khai báo toàn diện 36 tính năng theo 13 Phân hệ Client-app
-- Ngày thực hiện: 2026-10-17
-- Cơ chế an toàn: ON CONFLICT ("id") DO UPDATE (Idempotent, bảo toàn dữ liệu hiện có)
-- ============================================================================

-- 1. Nạp và Chuẩn hóa toàn bộ danh mục 36 tính năng vào bảng feature
INSERT INTO "feature" ("id", "name", "description", "type", "category_group", "default_limit", "default_enabled", "created_at", "updated_at")
VALUES
  -- 📂 PHÂN HỆ 01: XÁC THỰC & BẢO MẬT (AUTH)
  ('biometric_auth', 'Xác thực sinh trắc học', 'Đăng nhập an toàn bằng vân tay hoặc nhận diện khuôn mặt Face ID trên thiết bị', 'TOGGLE', 'Xác thực & Bảo mật', NULL, true, NOW(), NOW()),
  ('offline_login', 'Đăng nhập ngoại tuyến', 'Cho phép đăng nhập truy cập dữ liệu cục bộ an toàn khi không có kết nối internet', 'TOGGLE', 'Xác thực & Bảo mật', NULL, true, NOW(), NOW()),
  ('account_deletion', 'Quyền xóa tài khoản & Ân hạn', 'Yêu cầu xóa tài khoản với thời gian ân hạn 30 ngày bảo vệ người dùng', 'TOGGLE', 'Xác thực & Bảo mật', NULL, true, NOW(), NOW()),

  -- 📂 PHÂN HỆ 02: TRANG CHỦ & ĐIỀU HƯỚNG (HOME)
  ('net_worth_overview', 'Tổng quan tài sản ròng', 'Theo dõi biến động tổng tài sản ròng và cơ cấu tiền mặt, ngân hàng, ví điện tử', 'TOGGLE', 'Trang chủ & Điều hướng', NULL, true, NOW(), NOW()),
  ('quick_action_shortcuts', 'Phím tắt ghi chép nhanh', 'Bộ phím tắt tạo nhanh thu chi, chuyển tiền giữa các ví, quét hóa đơn và khẩu lệnh', 'TOGGLE', 'Trang chủ & Điều hướng', NULL, true, NOW(), NOW()),

  -- 📂 PHÂN HỆ 03: QUẢN LÝ VÍ TIỀN & TÀI SẢN (WALLET)
  ('wallets', 'Quản lý ví tiền', 'Tạo và quản lý các ví tiền mặt, tài khoản ngân hàng, thẻ tín dụng, ví điện tử', 'LIMIT', 'Quản lý Ví & Tài sản', 3, true, NOW(), NOW()),
  ('wallet_balance_adjustment', 'Điều chỉnh số dư ví', 'Kiểm kê thực tế và tự động tạo giao dịch bù trừ để cân đối số dư ví chính xác', 'TOGGLE', 'Quản lý Ví & Tài sản', NULL, true, NOW(), NOW()),
  ('wallet_exclude_total', 'Loại trừ ví khỏi tổng tài sản', 'Cho phép đánh dấu không cộng số dư của ví phụ vào tổng tài sản ròng', 'TOGGLE', 'Quản lý Ví & Tài sản', NULL, true, NOW(), NOW()),

  -- 📂 PHÂN HỆ 04: SỔ GIAO DỊCH THU / CHI (TX)
  ('transaction_management', 'Sổ giao dịch thu chi', 'Quản lý toàn diện sổ thu chi, phân loại chi tiết, đính kèm ảnh và tìm kiếm đa chiều', 'TOGGLE', 'Sổ giao dịch Thu Chi', NULL, true, NOW(), NOW()),
  ('ai_quick_input', 'Ghi chép bằng giọng nói (Voice)', 'Bóc tách câu nói tự nhiên tiếng Việt thành giao dịch tự động qua mô hình Whisper', 'TOGGLE', 'Sổ giao dịch Thu Chi', NULL, false, NOW(), NOW()),
  ('ocr_receipt', 'Quét hóa đơn / Biên lai (OCR)', 'Tự động bóc tách ảnh chụp hóa đơn, biên lai thành giao dịch qua camera bằng MLKit', 'TOGGLE', 'Sổ giao dịch Thu Chi', NULL, true, NOW(), NOW()),
  ('quick_category_assignment', 'Gán danh mục nhanh (C1)', 'Hỗ trợ phân loại nhanh hàng loạt giao dịch chưa có danh mục hoặc biến động số dư', 'TOGGLE', 'Sổ giao dịch Thu Chi', NULL, true, NOW(), NOW()),
  ('in_app_calculator', 'Bàn phím máy tính tích hợp', 'Máy tính mini tích hợp tính toán số tiền trực tiếp trên bàn phím khi ghi chép', 'TOGGLE', 'Sổ giao dịch Thu Chi', NULL, true, NOW(), NOW()),

  -- 📂 PHÂN HỆ 05: HỆ THỐNG DANH MỤC (CAT)
  ('custom_categories', 'Quản lý danh mục tùy chỉnh', 'Tạo danh mục thu chi riêng đa cấp (nhóm danh mục cha và các danh mục con)', 'LIMIT', 'Hệ thống Danh mục', 5, true, NOW(), NOW()),
  ('category_keywords_matching', 'Từ khóa nhận diện danh mục', 'Thiết lập danh sách từ khóa nhận diện tự động cho OCR, giọng nói và ngân hàng', 'TOGGLE', 'Hệ thống Danh mục', NULL, true, NOW(), NOW()),

  -- 📂 PHÂN HỆ 06: NGÂN SÁCH CHI TIÊU (BUDGET)
  ('budgets', 'Quản lý ngân sách chi tiêu', 'Thiết lập hạn mức chi tiêu định kỳ hàng tháng theo từng danh mục', 'LIMIT', 'Ngân sách Chi tiêu', 3, true, NOW(), NOW()),
  ('smart_budget_rebalancing', 'Tái phân bổ ngân sách AI', 'Gợi ý tự động điều chuyển hạn mức giữa các ngân sách khi sắp vượt ngưỡng chi', 'TOGGLE', 'Ngân sách Chi tiêu', NULL, false, NOW(), NOW()),
  ('budget_overspend_alert', 'Dự báo vỡ hạn mức chi tiêu', 'Cảnh báo chi tiêu chạm ngưỡng và tính toán định mức chi an toàn mỗi ngày còn lại', 'TOGGLE', 'Ngân sách Chi tiêu', NULL, true, NOW(), NOW()),

  -- 📂 PHÂN HỆ 07: HÓA ĐƠN ĐỊNH KỲ (BILL)
  ('bills', 'Quản lý hóa đơn định kỳ', 'Theo dõi hóa đơn lặp lại (Điện, Nước, Internet, Thuê nhà...) và chu kỳ', 'LIMIT', 'Hóa đơn định kỳ', 3, true, NOW(), NOW()),
  ('bill_auto_pay', 'Tự động thanh toán hóa đơn', 'Tự động tạo giao dịch thanh toán trừ tiền ví khi hóa đơn đến hạn', 'TOGGLE', 'Hóa đơn định kỳ', NULL, false, NOW(), NOW()),
  ('bill_reminder_notifications', 'Nhắc hẹn hóa đơn đa tầng', 'Nhắc nhở thanh toán hóa đơn trước ngày đến hạn qua Push Notification', 'TOGGLE', 'Hóa đơn định kỳ', NULL, true, NOW(), NOW()),

  -- 📂 PHÂN HỆ 08: MỤC TIÊU TÍCH LŨY (GOAL)
  ('goals', 'Mục tiêu tích lũy tiết kiệm', 'Lập kế hoạch tích lũy tài chính (mua xe, du lịch, mua nhà, quỹ khẩn cấp...)', 'LIMIT', 'Mục tiêu Tích lũy', 3, true, NOW(), NOW()),
  ('goal_auto_deposit', 'Tự động trích tiền mục tiêu', 'Tự động trích tiền định kỳ từ ví vào hũ mục tiêu tiết kiệm', 'TOGGLE', 'Mục tiêu Tích lũy', NULL, false, NOW(), NOW()),
  ('goal_deposit_withdraw', 'Nạp & Rút tiền mục tiêu', 'Thao tác nạp thêm tiền vào mục tiêu hoặc rút tiền mục tiêu về ví linh hoạt', 'TOGGLE', 'Mục tiêu Tích lũy', NULL, true, NOW(), NOW()),

  -- 📂 PHÂN HỆ 09: BÁO CÁO & PHÂN TÍCH (ANALYTICS)
  ('export_reports', 'Xuất báo cáo PDF / Excel', 'Xuất dữ liệu sao kê thu chi chuyên nghiệp ra file PDF in ấn hoặc bảng tính Excel', 'TOGGLE', 'Báo cáo & Phân tích', NULL, false, NOW(), NOW()),
  ('financial_health_fhs', 'Chỉ số sức khỏe tài chính', 'Đánh giá thang điểm sức khỏe tài chính và phân tích cơ cấu chi tiêu 50/30/20', 'TOGGLE', 'Báo cáo & Phân tích', NULL, true, NOW(), NOW()),
  ('cashflow_forecast', 'Dự báo dòng tiền 30 ngày', 'Dự báo xu hướng số dư và dòng tiền tự do trong 30 ngày tiếp theo', 'TOGGLE', 'Báo cáo & Phân tích', NULL, false, NOW(), NOW()),
  ('anomaly_spending_insights', 'Cảnh báo chi tiêu bất thường', 'Phát hiện và cảnh báo các khoản chi tiêu đột biến bất thường so với lịch sử', 'TOGGLE', 'Báo cáo & Phân tích', NULL, false, NOW(), NOW()),

  -- 📂 PHÂN HỆ 10: TRÍ TUỆ NHÂN TẠO & EDGE AI (AI)
  ('ai_assistant', 'Trợ lý tài chính Copilot AI', 'Hỏi đáp, tư vấn tài chính, tạo giao dịch/ngân sách qua ngôn ngữ tự nhiên Gemini', 'TOGGLE', 'Trí tuệ nhân tạo & Edge AI', NULL, false, NOW(), NOW()),
  ('ai_edge_model', 'Mô hình AI Offline trên máy', 'Tải và chạy mô hình ngôn ngữ trực tiếp trên chip điện thoại không cần internet', 'TOGGLE', 'Trí tuệ nhân tạo & Edge AI', NULL, false, NOW(), NOW()),
  ('ai_model_management', 'Quản lý bộ nhớ mô hình AI', 'Quản lý tải về, xóa giải phóng bộ nhớ mô hình AI On-Device trên thiết bị', 'TOGGLE', 'Trí tuệ nhân tạo & Edge AI', NULL, true, NOW(), NOW()),

  -- 📂 PHÂN HỆ 11: THÔNG BÁO & GIÁM SÁT (NOTIF)
  ('bank_notification_parser', 'Đọc biến động số dư ngân hàng', 'Tự động nhận diện thông báo biến động số dư từ app ngân hàng trên máy để nhắc ghi chép', 'TOGGLE', 'Thông báo & Giám sát', NULL, true, NOW(), NOW()),
  ('daily_recording_reminder', 'Nhắc nhở ghi chép hàng ngày', 'Tự động phát thông báo nhắc nhở ghi chép thu chi vào các khung giờ cấu hình', 'TOGGLE', 'Thông báo & Giám sát', NULL, true, NOW(), NOW()),

  -- 📂 PHÂN HỆ 12: GÓI CƯỚC & THANH TOÁN (PREMIUM)
  ('vietqr_payment', 'Thanh toán tự động VietQR', 'Tạo mã VietQR Napas 247 động, đếm ngược và đối soát tự động qua PayOS Gateway', 'TOGGLE', 'Gói cước & Thanh toán', NULL, true, NOW(), NOW()),
  ('payment_history', 'Lịch sử thanh toán gói cước', 'Tra cứu lịch sử giao dịch mua gói cước, biên lai thanh toán (lọc sạch đơn mẫu)', 'TOGGLE', 'Gói cước & Thanh toán', NULL, true, NOW(), NOW()),

  -- 📂 PHÂN HỆ 13: ĐỒNG BỘ NGOẠI TUYẾN (SYNC)
  ('offline_first_sync', 'Đồng bộ 2 chiều Offline-First', 'Ghi chép ngoại tuyến trên SQLite 0ms độ trễ và tự động đồng bộ 2 chiều khi có mạng', 'TOGGLE', 'Đồng bộ Ngoại tuyến', NULL, true, NOW(), NOW())

ON CONFLICT ("id") DO UPDATE SET
  "name" = EXCLUDED."name",
  "description" = EXCLUDED."description",
  "type" = EXCLUDED."type",
  "category_group" = EXCLUDED."category_group",
  "default_limit" = EXCLUDED."default_limit",
  "default_enabled" = EXCLUDED."default_enabled",
  "updated_at" = NOW();


-- 2. Cấu hình phân quyền chi tiết cho gói Basic (Mặc định Miễn phí)
INSERT INTO "account_type_permission" ("account_type", "feature_id", "is_enabled", "limit_value", "created_at", "updated_at")
VALUES
  -- 01. AUTH
  ('Basic', 'biometric_auth', true, NULL, NOW(), NOW()),
  ('Basic', 'offline_login', true, NULL, NOW(), NOW()),
  ('Basic', 'account_deletion', true, NULL, NOW(), NOW()),

  -- 02. HOME
  ('Basic', 'net_worth_overview', true, NULL, NOW(), NOW()),
  ('Basic', 'quick_action_shortcuts', true, NULL, NOW(), NOW()),

  -- 03. WALLET (Trần Basic: 3 ví)
  ('Basic', 'wallets', true, 3, NOW(), NOW()),
  ('Basic', 'wallet_balance_adjustment', true, NULL, NOW(), NOW()),
  ('Basic', 'wallet_exclude_total', true, NULL, NOW(), NOW()),

  -- 04. TX
  ('Basic', 'transaction_management', true, NULL, NOW(), NOW()),
  ('Basic', 'ai_quick_input', false, NULL, NOW(), NOW()), -- Khóa Basic
  ('Basic', 'ocr_receipt', true, NULL, NOW(), NOW()),
  ('Basic', 'quick_category_assignment', true, NULL, NOW(), NOW()),
  ('Basic', 'in_app_calculator', true, NULL, NOW(), NOW()),

  -- 05. CAT (Trần Basic: 5 danh mục riêng)
  ('Basic', 'custom_categories', true, 5, NOW(), NOW()),
  ('Basic', 'category_keywords_matching', true, NULL, NOW(), NOW()),

  -- 06. BUDGET (Trần Basic: 3 ngân sách)
  ('Basic', 'budgets', true, 3, NOW(), NOW()),
  ('Basic', 'smart_budget_rebalancing', false, NULL, NOW(), NOW()), -- Khóa Basic
  ('Basic', 'budget_overspend_alert', true, NULL, NOW(), NOW()),

  -- 07. BILL (Trần Basic: 3 hóa đơn)
  ('Basic', 'bills', true, 3, NOW(), NOW()),
  ('Basic', 'bill_auto_pay', false, NULL, NOW(), NOW()), -- Khóa Basic
  ('Basic', 'bill_reminder_notifications', true, NULL, NOW(), NOW()),

  -- 08. GOAL (Trần Basic: 3 mục tiêu)
  ('Basic', 'goals', true, 3, NOW(), NOW()),
  ('Basic', 'goal_auto_deposit', false, NULL, NOW(), NOW()), -- Khóa Basic
  ('Basic', 'goal_deposit_withdraw', true, NULL, NOW(), NOW()),

  -- 09. ANALYTICS
  ('Basic', 'export_reports', false, NULL, NOW(), NOW()), -- Khóa Basic (Độc quyền Premium)
  ('Basic', 'financial_health_fhs', true, NULL, NOW(), NOW()),
  ('Basic', 'cashflow_forecast', false, NULL, NOW(), NOW()), -- Khóa Basic
  ('Basic', 'anomaly_spending_insights', false, NULL, NOW(), NOW()), -- Khóa Basic

  -- 10. AI
  ('Basic', 'ai_assistant', false, NULL, NOW(), NOW()), -- Khóa Basic
  ('Basic', 'ai_edge_model', false, NULL, NOW(), NOW()), -- Khóa Basic
  ('Basic', 'ai_model_management', true, NULL, NOW(), NOW()),

  -- 11. NOTIF
  ('Basic', 'bank_notification_parser', true, NULL, NOW(), NOW()),
  ('Basic', 'daily_recording_reminder', true, NULL, NOW(), NOW()),

  -- 12. PREMIUM
  ('Basic', 'vietqr_payment', true, NULL, NOW(), NOW()),
  ('Basic', 'payment_history', true, NULL, NOW(), NOW()),

  -- 13. SYNC
  ('Basic', 'offline_first_sync', true, NULL, NOW(), NOW())

ON CONFLICT ("account_type", "feature_id") DO UPDATE SET
  "is_enabled" = EXCLUDED."is_enabled",
  "limit_value" = EXCLUDED."limit_value",
  "updated_at" = NOW();


-- 3. Cấu hình phân quyền toàn diện cho gói Premium (Mở khóa toàn bộ & Không giới hạn)
INSERT INTO "account_type_permission" ("account_type", "feature_id", "is_enabled", "limit_value", "created_at", "updated_at")
VALUES
  -- 01. AUTH
  ('Premium', 'biometric_auth', true, NULL, NOW(), NOW()),
  ('Premium', 'offline_login', true, NULL, NOW(), NOW()),
  ('Premium', 'account_deletion', true, NULL, NOW(), NOW()),

  -- 02. HOME
  ('Premium', 'net_worth_overview', true, NULL, NOW(), NOW()),
  ('Premium', 'quick_action_shortcuts', true, NULL, NOW(), NOW()),

  -- 03. WALLET (Premium: Vô hạn ví = NULL)
  ('Premium', 'wallets', true, NULL, NOW(), NOW()),
  ('Premium', 'wallet_balance_adjustment', true, NULL, NOW(), NOW()),
  ('Premium', 'wallet_exclude_total', true, NULL, NOW(), NOW()),

  -- 04. TX
  ('Premium', 'transaction_management', true, NULL, NOW(), NOW()),
  ('Premium', 'ai_quick_input', true, NULL, NOW(), NOW()),
  ('Premium', 'ocr_receipt', true, NULL, NOW(), NOW()),
  ('Premium', 'quick_category_assignment', true, NULL, NOW(), NOW()),
  ('Premium', 'in_app_calculator', true, NULL, NOW(), NOW()),

  -- 05. CAT (Premium: Vô hạn danh mục = NULL)
  ('Premium', 'custom_categories', true, NULL, NOW(), NOW()),
  ('Premium', 'category_keywords_matching', true, NULL, NOW(), NOW()),

  -- 06. BUDGET (Premium: Vô hạn ngân sách = NULL)
  ('Premium', 'budgets', true, NULL, NOW(), NOW()),
  ('Premium', 'smart_budget_rebalancing', true, NULL, NOW(), NOW()),
  ('Premium', 'budget_overspend_alert', true, NULL, NOW(), NOW()),

  -- 07. BILL (Premium: Vô hạn hóa đơn = NULL)
  ('Premium', 'bills', true, NULL, NOW(), NOW()),
  ('Premium', 'bill_auto_pay', true, NULL, NOW(), NOW()),
  ('Premium', 'bill_reminder_notifications', true, NULL, NOW(), NOW()),

  -- 08. GOAL (Premium: Vô hạn mục tiêu = NULL)
  ('Premium', 'goals', true, NULL, NOW(), NOW()),
  ('Premium', 'goal_auto_deposit', true, NULL, NOW(), NOW()),
  ('Premium', 'goal_deposit_withdraw', true, NULL, NOW(), NOW()),

  -- 09. ANALYTICS
  ('Premium', 'export_reports', true, NULL, NOW(), NOW()),
  ('Premium', 'financial_health_fhs', true, NULL, NOW(), NOW()),
  ('Premium', 'cashflow_forecast', true, NULL, NOW(), NOW()),
  ('Premium', 'anomaly_spending_insights', true, NULL, NOW(), NOW()),

  -- 10. AI
  ('Premium', 'ai_assistant', true, NULL, NOW(), NOW()),
  ('Premium', 'ai_edge_model', true, NULL, NOW(), NOW()),
  ('Premium', 'ai_model_management', true, NULL, NOW(), NOW()),

  -- 11. NOTIF
  ('Premium', 'bank_notification_parser', true, NULL, NOW(), NOW()),
  ('Premium', 'daily_recording_reminder', true, NULL, NOW(), NOW()),

  -- 12. PREMIUM
  ('Premium', 'vietqr_payment', true, NULL, NOW(), NOW()),
  ('Premium', 'payment_history', true, NULL, NOW(), NOW()),

  -- 13. SYNC
  ('Premium', 'offline_first_sync', true, NULL, NOW(), NOW())

ON CONFLICT ("account_type", "feature_id") DO UPDATE SET
  "is_enabled" = EXCLUDED."is_enabled",
  "limit_value" = EXCLUDED."limit_value",
  "updated_at" = NOW();
