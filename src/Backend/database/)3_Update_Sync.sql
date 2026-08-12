-- ============================================
-- WealthCommand Backend
-- Script: Them bang Sync + Cap nhat Category
-- Database: PersonFinance (PostgreSQL 18)
-- Ngay: 2026-08-11
-- Mo ta: Them 5 bang moi (wallet, transaction, budget, bill, goal)
--         + Bo sung cot uuid cho bang category
--         De dong bo du lieu voi Client-app (Flutter + SQLite)
-- ============================================

-- ============================================
-- 1. CAP NHAT BANG CATEGORY HIEN CO
-- ============================================

ALTER TABLE Category
ADD COLUMN uuid VARCHAR(36) UNIQUE;

-- Tao UUID cho cac category hien co (su dung gen_random_uuid())
UPDATE Category SET uuid = gen_random_uuid()::VARCHAR(36) WHERE uuid IS NULL;

ALTER TABLE Category
ALTER COLUMN uuid SET NOT NULL;

CREATE INDEX idx_category_uuid ON Category(uuid);


-- ============================================
-- 2. BANG wallet - Vi tai chinh
-- ============================================

CREATE TABLE wallet (
    id          VARCHAR(36)   PRIMARY KEY,        -- UUID do client tao
    idaccount   INT           NOT NULL,
    name        VARCHAR(100)  NOT NULL,
    type        VARCHAR(20)   NOT NULL DEFAULT 'cash',
    -- 'cash' | 'bank' | 'ewallet' | 'investment' | 'debt'
    balance     DECIMAL(15,2) NOT NULL DEFAULT 0,
    currency    VARCHAR(10)   NOT NULL DEFAULT 'VND',
    icon        VARCHAR(50)   DEFAULT 'wallet',
    colour      VARCHAR(10)   DEFAULT '#4CAF50',
    is_default  BOOLEAN       DEFAULT false,
    is_deleted  BOOLEAN       DEFAULT false,
    updated_at  TIMESTAMP     NOT NULL,
    created_at  TIMESTAMP     DEFAULT NOW(),

    CONSTRAINT fk_wallet_account
        FOREIGN KEY (idaccount) REFERENCES account(idaccount) ON DELETE CASCADE
);

CREATE INDEX idx_wallet_account ON wallet(idaccount);
CREATE INDEX idx_wallet_updated ON wallet(updated_at);


-- ============================================
-- 3. BANG transaction - Giao dich thu/chi/transfer
-- ============================================

CREATE TABLE transaction (
    id          VARCHAR(36)   PRIMARY KEY,        -- UUID do client tao
    idaccount   INT           NOT NULL,
    wallet_id   VARCHAR(36)   NOT NULL,
    category_id VARCHAR(36)   NULL,              -- null cho transfer/adjustment
    amount      DECIMAL(15,2) NOT NULL,
    type        VARCHAR(20)   NOT NULL,
    -- 'thu' | 'chi' | 'transfer' | 'adjustment'
    note        TEXT          DEFAULT '',
    date        TIMESTAMP     NOT NULL,
    images      TEXT          DEFAULT '[]',       -- JSON array string
    is_deleted  BOOLEAN       DEFAULT false,
    updated_at  TIMESTAMP     NOT NULL,
    created_at  TIMESTAMP     DEFAULT NOW(),

    CONSTRAINT fk_transaction_account
        FOREIGN KEY (idaccount) REFERENCES account(idaccount) ON DELETE CASCADE,
    CONSTRAINT fk_transaction_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallet(id) ON DELETE CASCADE
);

CREATE INDEX idx_transaction_account ON transaction(idaccount);
CREATE INDEX idx_transaction_wallet  ON transaction(wallet_id);
CREATE INDEX idx_transaction_date    ON transaction(date);
CREATE INDEX idx_transaction_updated ON transaction(updated_at);


-- ============================================
-- 4. BANG budget - Ngan sach theo danh muc + ky
-- ============================================

CREATE TABLE budget (
    id          VARCHAR(36)   PRIMARY KEY,
    idaccount   INT           NOT NULL,
    category_id VARCHAR(36)   NULL,
    amount      DECIMAL(15,2) NOT NULL,
    period      VARCHAR(20)   NOT NULL DEFAULT 'monthly',
    -- 'weekly' | 'monthly' | 'yearly'
    start_date  TIMESTAMP     NOT NULL,
    end_date    TIMESTAMP     NULL,
    note        TEXT          DEFAULT '',
    is_deleted  BOOLEAN       DEFAULT false,
    updated_at  TIMESTAMP     NOT NULL,
    created_at  TIMESTAMP     DEFAULT NOW(),

    CONSTRAINT fk_budget_account
        FOREIGN KEY (idaccount) REFERENCES account(idaccount) ON DELETE CASCADE
);

CREATE INDEX idx_budget_account ON budget(idaccount);


-- ============================================
-- 5. BANG bill - Hoa don dinh ky
-- ============================================

CREATE TABLE bill (
    id          VARCHAR(36)   PRIMARY KEY,
    idaccount   INT           NOT NULL,
    name        VARCHAR(100)  NOT NULL,
    amount      DECIMAL(15,2) NOT NULL,
    due_date    TIMESTAMP     NOT NULL,
    is_paid     BOOLEAN       DEFAULT false,
    recurrence  VARCHAR(20)   DEFAULT 'monthly',
    -- 'once' | 'weekly' | 'monthly' | 'yearly'
    icon        VARCHAR(50)   DEFAULT 'receipt',
    colour      VARCHAR(10)   DEFAULT '#4CAF50',
    note        TEXT          DEFAULT '',
    is_deleted  BOOLEAN       DEFAULT false,
    updated_at  TIMESTAMP     NOT NULL,
    created_at  TIMESTAMP     DEFAULT NOW(),

    CONSTRAINT fk_bill_account
        FOREIGN KEY (idaccount) REFERENCES account(idaccount) ON DELETE CASCADE
);

CREATE INDEX idx_bill_account ON bill(idaccount);


-- ============================================
-- 6. BANG goal - Muc tieu tiet kiem
-- ============================================

CREATE TABLE goal (
    id              VARCHAR(36)   PRIMARY KEY,
    idaccount       INT           NOT NULL,
    name            VARCHAR(100)  NOT NULL,
    target_amount   DECIMAL(15,2) NOT NULL,
    current_amount  DECIMAL(15,2) DEFAULT 0,
    target_date     TIMESTAMP     NOT NULL,
    icon            VARCHAR(50)   DEFAULT 'flag',
    colour          VARCHAR(10)   DEFAULT '#4CAF50',
    note            TEXT          DEFAULT '',
    is_completed    BOOLEAN       DEFAULT false,
    is_deleted      BOOLEAN       DEFAULT false,
    updated_at      TIMESTAMP     NOT NULL,
    created_at      TIMESTAMP     DEFAULT NOW(),

    CONSTRAINT fk_goal_account
        FOREIGN KEY (idaccount) REFERENCES account(idaccount) ON DELETE CASCADE
);

CREATE INDEX idx_goal_account ON goal(idaccount);


-- ============================================
-- 7. VERIFY
-- ============================================
SELECT 'OK: 5 tables created + category.uuid added' AS result;
