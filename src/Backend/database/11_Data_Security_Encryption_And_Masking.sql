-- ============================================================================
-- 11_DATA_SECURITY_ENCRYPTION_AND_MASKING.SQL
-- Mục đích: Thiết lập chuẩn hóa lưu trữ an toàn thông tin & bảo mật CSDL:
-- 1. Mở rộng độ dài cột Phone và Account_number lên VARCHAR(256) phục vụ mã hóa At-Rest AES-256-GCM.
-- 2. Bổ sung cột Account_number_hash (VARCHAR(64)) có Index phục vụ tra soát Blind Index SePay Webhook.
-- 3. Cài đặt Database Triggers chặn lưu số điện thoại và số tài khoản ngân hàng dạng rõ (plaintext).
-- Căn cứ pháp lý: Nghị định 13/2023/NĐ-CP (Điều 13, 26, 27) & PCI-DSS v4.0.
-- Ngày tạo: 2026-09-10
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CẬP NHẬT KIỂU DỮ LIỆU CỘT & BỔ SUNG CỘT TRA SOÁT BLIND INDEX
-- ----------------------------------------------------------------------------

-- Mở rộng cột Phone của bảng user để chứa chuỗi ciphertext AES-256
ALTER TABLE "user" ALTER COLUMN "Phone" TYPE VARCHAR(256);

-- Mở rộng cột Account_number của bảng bank_account để chứa chuỗi ciphertext AES-256
ALTER TABLE "bank_account" ALTER COLUMN "Account_number" TYPE VARCHAR(256);

-- Bổ sung cột Account_number_hash cho bảng bank_account (HMAC-SHA256 Blind Index)
ALTER TABLE "bank_account" ADD COLUMN IF NOT EXISTS "Account_number_hash" VARCHAR(64);

-- Đánh chỉ mục B-tree để tối ưu tốc độ tra soát Webhook ngân hàng O(1)
CREATE INDEX IF NOT EXISTS "idx_bank_account_number_hash" ON "bank_account" ("Account_number_hash");


-- ----------------------------------------------------------------------------
-- 2. TRIGGER CHẶN LƯU SỐ ĐIỆN THOẠI DẠNG RÕ (PLAINTEXT) TRÊN BẢNG USER
-- Cơ chế: Xác thực 2 đầu (Client/Backend + CSDL Trigger).
-- Nếu dữ liệu đầu vào là chuỗi số điện thoại rõ (7-15 chữ số) -> Chặn và ném ngoại lệ.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_phone_is_encrypted()
RETURNS TRIGGER AS $$
BEGIN
    -- Chỉ kiểm tra khi Phone có giá trị khác NULL và không rỗng
    IF NEW."Phone" IS NOT NULL AND TRIM(NEW."Phone") <> '' THEN
        -- Kiểm tra nếu Phone là chuỗi số rõ (định dạng SĐT phổ biến: 7-15 ký tự số, có thể có dấu +, dấu gạch hoặc khoảng trắng)
        -- Hoặc chuỗi không bắt đầu bằng tiền tố mã hóa 'enc:' mà chỉ toàn ký tự số
        IF NEW."Phone" ~ '^\+?[0-9\s\-\.]{7,15}$' OR (NEW."Phone" NOT LIKE 'enc:%' AND NEW."Phone" ~ '^[0-9]+$') THEN
            RAISE EXCEPTION 'BẢO MẬT: Nghiêm cấm lưu trữ số điện thoại người dùng dạng rõ (plaintext) trong CSDL! Dữ liệu bắt buộc phải được mã hóa AES-256 trước khi lưu theo Nghị định 13/2023/NĐ-CP.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_phone_encrypted ON "user";
CREATE TRIGGER trg_check_phone_encrypted
BEFORE INSERT OR UPDATE OF "Phone" ON "user"
FOR EACH ROW
EXECUTE FUNCTION check_phone_is_encrypted();


-- ----------------------------------------------------------------------------
-- 3. TRIGGER CHẶN LƯU SỐ TÀI KHOẢN NGÂN HÀNG DẠNG RÕ TRÊN BẢNG BANK_ACCOUNT
-- Cơ chế: Xác thực 2 đầu (Client/Backend + CSDL Trigger).
-- Nếu dữ liệu đầu vào là chuỗi số tài khoản ngân hàng rõ (6-25 chữ số) -> Chặn và ném ngoại lệ.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_bank_account_is_encrypted()
RETURNS TRIGGER AS $$
BEGIN
    -- Chỉ kiểm tra khi Account_number có giá trị khác NULL và không rỗng
    IF NEW."Account_number" IS NOT NULL AND TRIM(NEW."Account_number") <> '' THEN
        -- Kiểm tra nếu Account_number là chuỗi số tài khoản rõ (6-25 chữ số ngân hàng)
        -- Hoặc chuỗi không bắt đầu bằng tiền tố mã hóa 'enc:' mà chỉ toàn số
        IF NEW."Account_number" ~ '^[0-9]{6,25}$' OR (NEW."Account_number" NOT LIKE 'enc:%' AND NEW."Account_number" ~ '^[0-9]+$') THEN
            RAISE EXCEPTION 'BẢO MẬT: Nghiêm cấm lưu trữ số tài khoản ngân hàng dạng rõ (plaintext) trong CSDL! Dữ liệu bắt buộc phải được mã hóa AES-256 trước khi lưu theo chuẩn PCI-DSS.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_bank_account_encrypted ON "bank_account";
CREATE TRIGGER trg_check_bank_account_encrypted
BEFORE INSERT OR UPDATE OF "Account_number" ON "bank_account"
FOR EACH ROW
EXECUTE FUNCTION check_bank_account_is_encrypted();
