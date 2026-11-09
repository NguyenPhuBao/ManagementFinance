-- 47_update_premium_ai_assistant_scope.sql
-- Cập nhật cấu hình gói Premium cho tính năng `ai_assistant` (Chatbot AI):
--   * daily_prompts : null (không giới hạn) -> 20 lượt/ngày. Mã backend đã coi null là "dùng mặc định hệ thống"
--     nên hạn mức vẫn được thi hành; ghi số rõ ràng để quản trị viên thấy đúng giá trị đang áp dụng.
--   * model         : "gemini-3.8-flash" -> "cloud". Backend gửi nguyên `scopes` xuống client qua /subscription-info
--     nên mọi tên mô hình ghi ở đây đều lộ trong lưu lượng mạng; dùng nhãn trung tính để không nêu tên nhà cung cấp.
-- Luỹ đẳng: chạy lại nhiều lần cho cùng kết quả; chỉ gộp thêm hai khoá vào scope_config, không xoá khoá nào khác.
-- KHÔNG áp lên Supabase / Production khi chưa có xác nhận đích danh của PO (CLAUDE.md mục 1, DB Guard).
-- Sau khi áp: báo Client-app rằng `daily_prompts` của `ai_assistant` nay được thi hành (client đọc `scopes`).
-- Kiểm sau khi áp (chỉ đọc):
--   SELECT scope_config FROM account_type_permission WHERE account_type = 'Premium' AND feature_id = 'ai_assistant';
--   -- mong đợi: có "daily_prompts": 20 và "model": "cloud"

BEGIN;

UPDATE "account_type_permission"
   SET "scope_config" = COALESCE("scope_config", '{}'::jsonb)
                        || jsonb_build_object('daily_prompts', 20, 'model', 'cloud'),
       "updated_at"   = NOW()
 WHERE "account_type" = 'Premium'
   AND "feature_id"   = 'ai_assistant';

COMMIT;
