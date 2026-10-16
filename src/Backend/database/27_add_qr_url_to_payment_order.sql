-- ============================================================================
-- Migration 27: Bổ sung trường qr_url vào bảng payment_order
-- Phục vụ lưu trữ bền vững mã QR tại CSDL và xóa (SET NULL) khi đơn hoàn tất
-- Tuân thủ: Data_Security.md (PCI-DSS & NĐ 13/2023/NĐ-CP), Rule 10 (DB Guard)
-- ============================================================================

-- 1. Thêm cột qr_url (Text lưu link ảnh VietQR / PayOS)
ALTER TABLE "payment_order"
ADD COLUMN IF NOT EXISTS "qr_url" TEXT NULL;

-- 2. Thêm ghi chú tài liệu cột
COMMENT ON COLUMN "payment_order"."qr_url" IS 'URL mã QR thanh toán VietQR / PayOS, được lưu bền vững khi đơn PENDING và xóa (SET NULL) khi đơn hoàn tất hoặc hết hạn';
