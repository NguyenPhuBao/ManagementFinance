-- ============================================
-- ManagementFinance Backend
-- Script: Module Bank — Tích hợp Casso (API Key)
-- Database: PersonFinance (PostgreSQL)
-- Ngay: 2026-08-17
-- Mô tả: Tạo bảng bank_account
--        + ALTER bảng transaction hỗ trợ provider/external_transaction_id
-- ============================================

-- ============================================
-- 1. BẢNG bank_account (Tài khoản NH từ Casso)
-- Mỗi user có thể có nhiều tài khoản NH (MB, VCB, BIDV...).
-- Không cần lưu API Key ở DB, đọc từ .env
-- ============================================
CREATE TABLE bank_account (
    id               VARCHAR(36)    PRIMARY KEY,         -- UUID do backend sinh
    idaccount        INT            NOT NULL,             -- Chủ sở hữu
    casso_account_id VARCHAR(100)   NOT NULL UNIQUE,      -- ID tài khoản phía Casso (để mapping)
    account_number   VARCHAR(50)    NOT NULL,             -- Số tài khoản NH (1903xxx)
    account_name     VARCHAR(255)   NOT NULL,             -- Tên chủ thẻ (NGUYEN VAN A)
    bank_name        VARCHAR(100)   NOT NULL,             -- Tên NH (Vietcombank, MB...)
    balance          DECIMAL(15,2)  DEFAULT 0,            -- Số dư đồng bộ từ Casso
    connect_status   VARCHAR(20)    DEFAULT 'active',     -- 'active' | 'inactive'
    created_at       TIMESTAMP      DEFAULT NOW(),
    updated_at       TIMESTAMP      DEFAULT NOW(),

    CONSTRAINT fk_bank_account_owner
        FOREIGN KEY (idaccount) REFERENCES account(idaccount) ON DELETE CASCADE
);

-- ============================================
-- 2. ALTER bảng transaction
-- Hỗ trợ nguồn gốc giao dịch và chống trùng lặp webhook
-- ============================================
ALTER TABLE transaction
    ADD COLUMN provider                VARCHAR(30)   DEFAULT 'manual',
    -- 'manual' = người dùng nhập tay | 'casso' = tự động từ webhook Casso
    ADD COLUMN external_transaction_id VARCHAR(100)  DEFAULT NULL,
    -- ID giao dịch phía Casso (tid) — null với giao dịch thường
    ADD CONSTRAINT uq_transaction_external
        UNIQUE (provider, external_transaction_id);
    -- Chống trùng lặp: cùng 1 provider + 1 external ID chỉ lưu 1 lần

-- ============================================
-- 3. INDEXES
-- ============================================
CREATE INDEX idx_bank_account_owner    ON bank_account(idaccount);
CREATE INDEX idx_bank_account_status   ON bank_account(connect_status);
CREATE INDEX idx_transaction_provider  ON transaction(provider);

-- ============================================
-- 4. VERIFY
-- ============================================
SELECT 'OK: bank_account created; transaction altered' AS result;
