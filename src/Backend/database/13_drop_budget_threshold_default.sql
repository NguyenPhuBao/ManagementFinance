-- ==============================================================================
-- MIGRATION 13: DROP DEFAULT ON budget.Threshold_Warning_Percent
-- Ref: VERIFY_7675B35_REMAINING.md §2.2
-- Purpose: Ngăn chặn giá trị mặc định 0 ép buộc khi ghi CSDL ngoài đường /sync/push
-- ==============================================================================

ALTER TABLE "budget" ALTER COLUMN "Threshold_Warning_Percent" DROP DEFAULT;
