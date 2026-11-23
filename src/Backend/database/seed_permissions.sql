-- ============================================================================
-- Migration 32: Nạp Toàn Diện Dữ Liệu 4 Trụ Cột Cho 36 Tính Năng
-- Nguồn sự thật (SSOT): docs/Functional-Mobile/4_TRU_COT.md
-- Ngày thực hiện: 2026-10-17
-- Cơ chế an toàn: Bọc trong TRANSACTION (BEGIN...COMMIT), Idempotent (ON CONFLICT DO UPDATE)
-- ============================================================================

-- 1. Cập nhật scope_schema và default_downgrade_policy cho bảng feature
UPDATE "feature" SET 
  "scope_schema" = '{"methods": ["fingerprint", "face_id"], "auto_prompt": true}'::jsonb,
  "default_downgrade_policy" = 'LOCK_FEATURE',
  "updated_at" = NOW()
WHERE "id" = 'biometric_auth';

UPDATE "feature" SET 
  "scope_schema" = '{"cache_token_days": 30, "allow_pin_fallback": true}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'offline_login';

UPDATE "feature" SET 
  "scope_schema" = '{"grace_period_days": 30, "allow_undo": true}'::jsonb,
  "default_downgrade_policy" = 'BLOCK_CREATE',
  "updated_at" = NOW()
WHERE "id" = 'account_deletion';

UPDATE "feature" SET 
  "scope_schema" = '{"chart_history_days": 30, "allow_trend_breakdown": false}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'net_worth_overview';

UPDATE "feature" SET 
  "scope_schema" = '{"custom_slots": 4, "allow_voice_shortcut": false}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'quick_action_shortcuts';

UPDATE "feature" SET 
  "scope_schema" = '{"allowed_types": ["Cash", "Bank", "EWallet"], "custom_color": false}'::jsonb,
  "default_downgrade_policy" = 'BLOCK_CREATE',
  "updated_at" = NOW()
WHERE "id" = 'wallets';

UPDATE "feature" SET 
  "scope_schema" = '{"auto_generate_diff_tx": true}'::jsonb,
  "default_downgrade_policy" = 'BLOCK_CREATE',
  "updated_at" = NOW()
WHERE "id" = 'wallet_balance_adjustment';

UPDATE "feature" SET 
  "scope_schema" = '{"max_excluded_wallets": null}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'wallet_exclude_total';

UPDATE "feature" SET 
  "scope_schema" = '{"max_photos_per_tx": 1, "search_history_days": 90}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'transaction_management';

UPDATE "feature" SET 
  "scope_schema" = '{"daily_voice_quota": null, "max_seconds": 30}'::jsonb,
  "default_downgrade_policy" = 'LOCK_FEATURE',
  "updated_at" = NOW()
WHERE "id" = 'ai_quick_input';

UPDATE "feature" SET 
  "scope_schema" = '{"monthly_scans": 15, "max_file_mb": 5, "auto_crop": false}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'ocr_receipt';

UPDATE "feature" SET 
  "scope_schema" = '{"batch_assign_max": 20}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'quick_category_assignment';

UPDATE "feature" SET 
  "scope_schema" = '{"allow_history_tape": true}'::jsonb,
  "default_downgrade_policy" = 'LOCK_FEATURE',
  "updated_at" = NOW()
WHERE "id" = 'in_app_calculator';

UPDATE "feature" SET 
  "scope_schema" = '{"max_depth": 2, "custom_icons": false, "custom_colors": false}'::jsonb,
  "default_downgrade_policy" = 'BLOCK_CREATE',
  "updated_at" = NOW()
WHERE "id" = 'custom_categories';

UPDATE "feature" SET 
  "scope_schema" = '{"max_keywords_per_cat": 5}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'category_keywords_matching';

UPDATE "feature" SET 
  "scope_schema" = '{"recurrence_cycles": ["MONTHLY"]}'::jsonb,
  "default_downgrade_policy" = 'BLOCK_CREATE',
  "updated_at" = NOW()
WHERE "id" = 'budgets';

UPDATE "feature" SET 
  "scope_schema" = '{"auto_suggest_shift": true, "apply_one_click": true}'::jsonb,
  "default_downgrade_policy" = 'LOCK_FEATURE',
  "updated_at" = NOW()
WHERE "id" = 'smart_budget_rebalancing';

UPDATE "feature" SET 
  "scope_schema" = '{"alert_threshold": 0.8, "daily_burn_rate": false}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'budget_overspend_alert';

UPDATE "feature" SET 
  "scope_schema" = '{"cycles": ["MONTHLY"]}'::jsonb,
  "default_downgrade_policy" = 'BLOCK_CREATE',
  "updated_at" = NOW()
WHERE "id" = 'bills';

UPDATE "feature" SET 
  "scope_schema" = '{"auto_deduct_wallet": true, "retry_on_fail": 3}'::jsonb,
  "default_downgrade_policy" = 'GRACE_PERIOD_3D',
  "updated_at" = NOW()
WHERE "id" = 'bill_auto_pay';

UPDATE "feature" SET 
  "scope_schema" = '{"remind_days_before": [1], "custom_hour": false}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'bill_reminder_notifications';

UPDATE "feature" SET 
  "scope_schema" = '{"allow_sub_milestones": false, "priority_sorting": false}'::jsonb,
  "default_downgrade_policy" = 'BLOCK_CREATE',
  "updated_at" = NOW()
WHERE "id" = 'goals';

UPDATE "feature" SET 
  "scope_schema" = '{"frequency": ["DAILY", "WEEKLY", "MONTHLY"], "auto_pause_on_low_balance": true}'::jsonb,
  "default_downgrade_policy" = 'GRACE_PERIOD_3D',
  "updated_at" = NOW()
WHERE "id" = 'goal_auto_deposit';

UPDATE "feature" SET 
  "scope_schema" = '{"require_linked_wallet": true}'::jsonb,
  "default_downgrade_policy" = 'BLOCK_CREATE',
  "updated_at" = NOW()
WHERE "id" = 'goal_deposit_withdraw';

UPDATE "feature" SET 
  "scope_schema" = '{"formats": ["PDF", "EXCEL", "CSV"], "max_range_years": null, "watermark": false}'::jsonb,
  "default_downgrade_policy" = 'LOCK_FEATURE',
  "updated_at" = NOW()
WHERE "id" = 'export_reports';

UPDATE "feature" SET 
  "scope_schema" = '{"score_only": true, "ai_deep_insights": false}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'financial_health_fhs';

UPDATE "feature" SET 
  "scope_schema" = '{"forecast_days": 30, "scenario_model": true}'::jsonb,
  "default_downgrade_policy" = 'READ_ONLY',
  "updated_at" = NOW()
WHERE "id" = 'cashflow_forecast';

UPDATE "feature" SET 
  "scope_schema" = '{"deviation_percent_threshold": 30, "auto_notify": true}'::jsonb,
  "default_downgrade_policy" = 'LOCK_FEATURE',
  "updated_at" = NOW()
WHERE "id" = 'anomaly_spending_insights';

UPDATE "feature" SET 
  "scope_schema" = '{"daily_prompts": null, "context_window_days": 90, "model": "gemini-3.8-flash"}'::jsonb,
  "default_downgrade_policy" = 'LOCK_FEATURE',
  "updated_at" = NOW()
WHERE "id" = 'ai_assistant';

UPDATE "feature" SET 
  "scope_schema" = '{"allow_offline_inference": true, "models": ["whisper-tiny", "finance-slm"]}'::jsonb,
  "default_downgrade_policy" = 'LOCK_FEATURE',
  "updated_at" = NOW()
WHERE "id" = 'ai_edge_model';

UPDATE "feature" SET 
  "scope_schema" = '{"allow_purge_cache": true, "max_storage_mb": 500}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'ai_model_management';

UPDATE "feature" SET 
  "scope_schema" = '{"supported_banks": ["VCB", "MB", "TCB", "ACB"], "auto_fill_category": false}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'bank_notification_parser';

UPDATE "feature" SET 
  "scope_schema" = '{"reminder_slots": ["20:00"], "custom_message": false}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'daily_recording_reminder';

UPDATE "feature" SET 
  "scope_schema" = '{"gateway": "PayOS", "countdown_minutes": 15, "support_jit_sync": true}'::jsonb,
  "default_downgrade_policy" = 'BLOCK_CREATE',
  "updated_at" = NOW()
WHERE "id" = 'vietqr_payment';

UPDATE "feature" SET 
  "scope_schema" = '{"exclude_template_orders": true, "allow_download_invoice": false}'::jsonb,
  "default_downgrade_policy" = 'BLOCK_CREATE',
  "updated_at" = NOW()
WHERE "id" = 'payment_history';

UPDATE "feature" SET 
  "scope_schema" = '{"debounce_seconds": 10, "cloud_photo_backup": false, "realtime_priority": false}'::jsonb,
  "default_downgrade_policy" = 'FALLBACK_DEFAULT',
  "updated_at" = NOW()
WHERE "id" = 'offline_first_sync';


-- 2. Cập nhật cấu hình phân quyền Trụ 1, 2, 3, 4 cho gói Basic (36 tính năng)
INSERT INTO "account_type_permission" ("account_type", "feature_id", "is_enabled", "limit_value", "scope_config", "downgrade_policy", "updated_at")
VALUES
  ('Basic', 'biometric_auth', true, NULL, '{"methods": ["fingerprint", "face_id"], "auto_prompt": true}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Basic', 'offline_login', true, NULL, '{"cache_token_days": 30, "allow_pin_fallback": true}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'account_deletion', true, NULL, '{"grace_period_days": 30, "allow_undo": true}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Basic', 'net_worth_overview', true, NULL, '{"chart_history_days": 30, "allow_trend_breakdown": false}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'quick_action_shortcuts', true, NULL, '{"custom_slots": 4, "allow_voice_shortcut": false}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'wallets', true, 3, '{"allowed_types": ["Cash", "Bank", "EWallet"], "custom_color": false}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Basic', 'wallet_balance_adjustment', true, NULL, '{"auto_generate_diff_tx": true}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Basic', 'wallet_exclude_total', true, NULL, '{"max_excluded_wallets": null}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'transaction_management', true, NULL, '{"max_photos_per_tx": 1, "search_history_days": 90}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'ai_quick_input', false, NULL, '{"daily_voice_quota": 0, "max_seconds": 0}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Basic', 'ocr_receipt', true, NULL, '{"monthly_scans": 15, "max_file_mb": 5, "auto_crop": false}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'quick_category_assignment', true, NULL, '{"batch_assign_max": 20}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'in_app_calculator', true, NULL, '{"allow_history_tape": true}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Basic', 'custom_categories', true, 5, '{"max_depth": 2, "custom_icons": false, "custom_colors": false}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Basic', 'category_keywords_matching', true, NULL, '{"max_keywords_per_cat": 5}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'budgets', true, 3, '{"recurrence_cycles": ["MONTHLY"]}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Basic', 'smart_budget_rebalancing', false, NULL, '{"auto_suggest_shift": false, "apply_one_click": false}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Basic', 'budget_overspend_alert', true, NULL, '{"alert_threshold": 0.8, "daily_burn_rate": false}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'bills', true, 3, '{"cycles": ["MONTHLY"]}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Basic', 'bill_auto_pay', false, NULL, '{"auto_deduct_wallet": false, "retry_on_fail": 0}'::jsonb, 'GRACE_PERIOD_3D', NOW()),
  ('Basic', 'bill_reminder_notifications', true, NULL, '{"remind_days_before": [1], "custom_hour": false}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'goals', true, 3, '{"allow_sub_milestones": false, "priority_sorting": false}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Basic', 'goal_auto_deposit', false, NULL, '{"frequency": [], "auto_pause_on_low_balance": false}'::jsonb, 'GRACE_PERIOD_3D', NOW()),
  ('Basic', 'goal_deposit_withdraw', true, NULL, '{"require_linked_wallet": true}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Basic', 'export_reports', false, NULL, '{"formats": [], "max_range_years": 0, "watermark": true}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Basic', 'financial_health_fhs', true, NULL, '{"score_only": true, "ai_deep_insights": false}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'cashflow_forecast', false, NULL, '{"forecast_days": 0, "scenario_model": false}'::jsonb, 'READ_ONLY', NOW()),
  ('Basic', 'anomaly_spending_insights', false, NULL, '{"deviation_percent_threshold": 50, "auto_notify": false}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Basic', 'ai_assistant', false, NULL, '{"daily_prompts": 0, "context_window_days": 0, "model": "none"}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Basic', 'ai_edge_model', false, NULL, '{"allow_offline_inference": false, "models": []}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Basic', 'ai_model_management', true, NULL, '{"allow_purge_cache": true, "max_storage_mb": 500}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'bank_notification_parser', true, NULL, '{"supported_banks": ["VCB", "MB", "TCB", "ACB"], "auto_fill_category": false}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'daily_recording_reminder', true, NULL, '{"reminder_slots": ["20:00"], "custom_message": false}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Basic', 'vietqr_payment', true, NULL, '{"gateway": "PayOS", "countdown_minutes": 15, "support_jit_sync": true}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Basic', 'payment_history', true, NULL, '{"exclude_template_orders": true, "allow_download_invoice": false}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Basic', 'offline_first_sync', true, NULL, '{"debounce_seconds": 10, "cloud_photo_backup": false, "realtime_priority": false}'::jsonb, 'FALLBACK_DEFAULT', NOW())
ON CONFLICT ("account_type", "feature_id") DO UPDATE SET
  "is_enabled" = EXCLUDED."is_enabled",
  "limit_value" = EXCLUDED."limit_value",
  "scope_config" = EXCLUDED."scope_config",
  "downgrade_policy" = EXCLUDED."downgrade_policy",
  "updated_at" = NOW();


-- 3. Cập nhật cấu hình phân quyền Trụ 1, 2, 3, 4 cho gói Premium (36 tính năng)
INSERT INTO "account_type_permission" ("account_type", "feature_id", "is_enabled", "limit_value", "scope_config", "downgrade_policy", "updated_at")
VALUES
  ('Premium', 'biometric_auth', true, NULL, '{"methods": ["fingerprint", "face_id"], "auto_prompt": true}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Premium', 'offline_login', true, NULL, '{"cache_token_days": 30, "allow_pin_fallback": true}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'account_deletion', true, NULL, '{"grace_period_days": 30, "allow_undo": true}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Premium', 'net_worth_overview', true, NULL, '{"chart_history_days": null, "allow_trend_breakdown": true}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'quick_action_shortcuts', true, NULL, '{"custom_slots": 8, "allow_voice_shortcut": true}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'wallets', true, NULL, '{"allowed_types": ["Cash", "Bank", "EWallet", "Credit", "Investment"], "custom_color": true}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Premium', 'wallet_balance_adjustment', true, NULL, '{"auto_generate_diff_tx": true}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Premium', 'wallet_exclude_total', true, NULL, '{"max_excluded_wallets": null}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'transaction_management', true, NULL, '{"max_photos_per_tx": 5, "search_history_days": null}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'ai_quick_input', true, NULL, '{"daily_voice_quota": null, "max_seconds": 30}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Premium', 'ocr_receipt', true, NULL, '{"monthly_scans": null, "max_file_mb": 20, "auto_crop": true}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'quick_category_assignment', true, NULL, '{"batch_assign_max": 100}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'in_app_calculator', true, NULL, '{"allow_history_tape": true}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Premium', 'custom_categories', true, NULL, '{"max_depth": 3, "custom_icons": true, "custom_colors": true}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Premium', 'category_keywords_matching', true, NULL, '{"max_keywords_per_cat": 25}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'budgets', true, NULL, '{"recurrence_cycles": ["WEEKLY", "MONTHLY", "CUSTOM"]}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Premium', 'smart_budget_rebalancing', true, NULL, '{"auto_suggest_shift": true, "apply_one_click": true}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Premium', 'budget_overspend_alert', true, NULL, '{"alert_threshold": 0.8, "daily_burn_rate": true}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'bills', true, NULL, '{"cycles": ["WEEKLY", "MONTHLY", "QUARTERLY", "YEARLY"]}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Premium', 'bill_auto_pay', true, NULL, '{"auto_deduct_wallet": true, "retry_on_fail": 3}'::jsonb, 'GRACE_PERIOD_3D', NOW()),
  ('Premium', 'bill_reminder_notifications', true, NULL, '{"remind_days_before": [1, 3, 7], "custom_hour": true}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'goals', true, NULL, '{"allow_sub_milestones": true, "priority_sorting": true}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Premium', 'goal_auto_deposit', true, NULL, '{"frequency": ["DAILY", "WEEKLY", "MONTHLY"], "auto_pause_on_low_balance": true}'::jsonb, 'GRACE_PERIOD_3D', NOW()),
  ('Premium', 'goal_deposit_withdraw', true, NULL, '{"require_linked_wallet": true}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Premium', 'export_reports', true, NULL, '{"formats": ["PDF", "EXCEL", "CSV"], "max_range_years": null, "watermark": false}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Premium', 'financial_health_fhs', true, NULL, '{"score_only": false, "ai_deep_insights": true}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'cashflow_forecast', true, NULL, '{"forecast_days": 30, "scenario_model": true}'::jsonb, 'READ_ONLY', NOW()),
  ('Premium', 'anomaly_spending_insights', true, NULL, '{"deviation_percent_threshold": 30, "auto_notify": true}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Premium', 'ai_assistant', true, NULL, '{"daily_prompts": null, "context_window_days": 90, "model": "gemini-3.8-flash"}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Premium', 'ai_edge_model', true, NULL, '{"allow_offline_inference": true, "models": ["whisper-tiny", "finance-slm"]}'::jsonb, 'LOCK_FEATURE', NOW()),
  ('Premium', 'ai_model_management', true, NULL, '{"allow_purge_cache": true, "max_storage_mb": 2000}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'bank_notification_parser', true, NULL, '{"supported_banks": ["ALL"], "auto_fill_category": true}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'daily_recording_reminder', true, NULL, '{"reminder_slots": ["12:00", "18:00", "21:00"], "custom_message": true}'::jsonb, 'FALLBACK_DEFAULT', NOW()),
  ('Premium', 'vietqr_payment', true, NULL, '{"gateway": "PayOS", "countdown_minutes": 15, "support_jit_sync": true}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Premium', 'payment_history', true, NULL, '{"exclude_template_orders": true, "allow_download_invoice": true}'::jsonb, 'BLOCK_CREATE', NOW()),
  ('Premium', 'offline_first_sync', true, NULL, '{"debounce_seconds": 2, "cloud_photo_backup": true, "realtime_priority": true}'::jsonb, 'FALLBACK_DEFAULT', NOW())
ON CONFLICT ("account_type", "feature_id") DO UPDATE SET
  "is_enabled" = EXCLUDED."is_enabled",
  "limit_value" = EXCLUDED."limit_value",
  "scope_config" = EXCLUDED."scope_config",
  "downgrade_policy" = EXCLUDED."downgrade_policy",
  "updated_at" = NOW();
