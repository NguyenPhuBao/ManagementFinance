-- ============================================
-- CSDL CẬP NHẬT MODULE AUTH (SOFT DELETE & OTP)
-- ============================================

-- 1. Bảng otp_code
CREATE TABLE otp_code (
    id SERIAL PRIMARY KEY,
    email VARCHAR(100) NOT NULL,
    code_hash VARCHAR(255) NOT NULL,
    purpose VARCHAR(30) NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    expires_at TIMESTAMP(6) NOT NULL,
    created_at TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_otp_code_email_purpose ON otp_code(email, purpose);
CREATE INDEX idx_otp_code_expires_at ON otp_code(expires_at);

-- 2. Bổ sung 'Deleted' vào account.status
ALTER TABLE Account
DROP CONSTRAINT IF EXISTS account_status_check;

ALTER TABLE Account
ADD CONSTRAINT account_status_check 
CHECK (status IN ('Active', 'Inactive', 'Deleted'));
