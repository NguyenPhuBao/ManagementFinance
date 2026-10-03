-- Migration 14: Sửa từ khoá mặc định danh mục 'Ăn uống' và 'Di chuyển'
-- Ngày: 2026-10-01
-- Lý do: 'grab' đứng riêng trong Ăn uống gây xếp nhầm mọi ghi chú "grab đi làm/về nhà"
--        vào Ăn uống thay vì Di chuyển (mâu thuẫn với training-data.csv:11).
-- Phạm vi: CHỈ 2 hàng Is_default=true — không đụng bản sao danh mục của từng tài khoản.
-- Tham chiếu: docs/superpowers/backend/CAN-LAM/SEED_TU_KHOA_GRAB.md

BEGIN;

UPDATE category
SET "Keyword" = 'an uong, food, grabfood',
    "Update_at" = NOW()
WHERE "Idcategory" = '8e06aaf6-4608-4cb3-8770-2c2c1eae25b6'
  AND "Is_default" = TRUE;

UPDATE category
SET "Keyword" = 'di chuyen, xang, grab, grabcar',
    "Update_at" = NOW()
WHERE "Idcategory" = '08639bd7-ef8f-4c58-ae8a-7f58198ad79b'
  AND "Is_default" = TRUE;

COMMIT;
