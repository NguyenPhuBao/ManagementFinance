-- ============================================================================
-- WEALTHCOMMAND / FLOWMONEY — CSDL MỚI (v2)
-- ============================================================================
-- Ngày: 2026-08-26
-- Nguồn: New_Database.md (13 bảng) — áp dụng hoàn toàn CSDL mới
-- Lưu ý: uuid là id tự sinh tại Client-app, Backend chỉ ghi nhận mã.
-- Cơ chế xóa mềm: Delete_at NULL = đang dùng; có giá trị = đã xóa mềm.
-- ============================================================================

-- ============================================================================
-- 2.1. BẢNG ROLE
-- ============================================================================
CREATE TABLE "role" (
    "Idrole"      SERIAL      NOT NULL,
    "Rolename"    VARCHAR(20) NOT NULL,
    "Description" TEXT,
    CONSTRAINT "role_pkey" PRIMARY KEY ("Idrole"),
    CONSTRAINT "uq_role_rolename" UNIQUE ("Rolename")
);

-- ============================================================================
-- 2.2. BẢNG ACCOUNT
-- ============================================================================
CREATE TABLE "account" (
    "Idaccount" SERIAL       NOT NULL,
    "Idrole"    INTEGER      NOT NULL,
    "Email"     VARCHAR(100) NOT NULL,
    "Username"  VARCHAR(255) NOT NULL,
    "Password"  VARCHAR(255) NOT NULL,
    "Status"    VARCHAR(20)  NOT NULL DEFAULT 'Active',
    "Type"      VARCHAR(20)  NOT NULL DEFAULT 'Basic',
    "Create_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at" TIMESTAMP(6),
    "Delete_at" TIMESTAMP(6),
    CONSTRAINT "account_pkey" PRIMARY KEY ("Idaccount"),
    CONSTRAINT "uq_account_email" UNIQUE ("Email"),
    CONSTRAINT "uq_account_username" UNIQUE ("Username"),
    CONSTRAINT "ck_account_status" CHECK ("Status" IN ('Active', 'Inactive', 'PendingDelete', 'Deleted')),
    CONSTRAINT "ck_account_type" CHECK ("Type" IN ('Basic', 'Premium'))
);

-- ============================================================================
-- 2.3. BẢNG USER
-- ============================================================================
CREATE TABLE "user" (
    "Iduser"      SERIAL       NOT NULL,
    "Idaccount"   INTEGER      NOT NULL,
    "Fullname"    VARCHAR(100) NOT NULL,
    "Email"       VARCHAR(100) NOT NULL,
    "Phone"       VARCHAR(15),
    "Address"     TEXT,
    "Country_code" CHAR(4),
    "Create_at"   TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at"   TIMESTAMP(6),
    "Delete_at"   TIMESTAMP(6),
    CONSTRAINT "user_pkey" PRIMARY KEY ("Iduser"),
    CONSTRAINT "uq_user_idaccount" UNIQUE ("Idaccount"),
    CONSTRAINT "uq_user_email" UNIQUE ("Email")
);

-- ============================================================================
-- 2.4. BẢNG AUDIT_LOG
-- ============================================================================
CREATE TABLE "audit_log" (
    "Idlog"     SERIAL       NOT NULL,
    "Idaccount" INTEGER      NOT NULL,
    "Request"   VARCHAR(200) NOT NULL,
    "TimeReq"   TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "TimeRes"   TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "audit_log_pkey" PRIMARY KEY ("Idlog")
);

-- ============================================================================
-- 2.5. BẢNG OTP_CODE
-- ============================================================================
CREATE TABLE "otp_code" (
    "Id_otp"    SERIAL       NOT NULL,
    "Idaccount" INTEGER      NOT NULL,
    "Email"     VARCHAR(100) NOT NULL,
    "code_hash" VARCHAR(255) NOT NULL,
    "purpose"   VARCHAR(30)  NOT NULL,
    "is_used"   BOOLEAN      NOT NULL DEFAULT false,
    "expires_at" TIMESTAMP(6) NOT NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "otp_code_pkey" PRIMARY KEY ("Id_otp"),
    CONSTRAINT "ck_otp_expires" CHECK ("expires_at" > "created_at")
);

-- ============================================================================
-- 2.6. BẢNG CATEGORY (nhóm: Is_group=TRUE; con: Idgroup trỏ group)
-- ============================================================================
CREATE TABLE "category" (
    "Idcategory"   VARCHAR(36)  NOT NULL,
    "Create_by"    INTEGER      NOT NULL DEFAULT 1,
    "NameCategory" VARCHAR(200) NOT NULL,
    "Classify"     VARCHAR(10)  NOT NULL,
    "Is_default"   BOOLEAN      NOT NULL DEFAULT false,
    "Is_group"     BOOLEAN      NOT NULL DEFAULT false,
    "Idgroup"      VARCHAR(36),
    "Keyword"      VARCHAR(500),
    "Icon"         VARCHAR(20),
    "Create_at"    TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "Update_at"    TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "Delete_at"    TIMESTAMP(6),
    CONSTRAINT "category_pkey" PRIMARY KEY ("Idcategory"),
    CONSTRAINT "ck_category_classify" CHECK ("Classify" IN ('Thu', 'Chi', 'Vay/no')),
    CONSTRAINT "ck_category_group" CHECK (
        ("Is_group" = TRUE AND "Idgroup" IS NULL) OR
        ("Is_group" = FALSE)
    )
);

-- ============================================================================
-- 2.7. BẢNG BANK_ACCOUNT
-- ============================================================================
CREATE TABLE "bank_account" (
    "Id_bank_account"  VARCHAR(36)   NOT NULL,
    "Idaccount"        INTEGER       NOT NULL,
    "Id_casso_account" VARCHAR(100)  NOT NULL,
    "Account_number"   VARCHAR(50)   NOT NULL,
    "Account_name"     VARCHAR(255)  NOT NULL,
    "Bank_name"        VARCHAR(100)  NOT NULL,
    "Balance"          DECIMAL(15,2) NOT NULL DEFAULT 0,
    "Connect_status"   VARCHAR(20)   NOT NULL DEFAULT 'active',
    "Create_at"        TIMESTAMP(6)  DEFAULT CURRENT_TIMESTAMP,
    "Update_at"        TIMESTAMP(6)  DEFAULT CURRENT_TIMESTAMP,
    "Delete_at"        TIMESTAMP(6),
    CONSTRAINT "bank_account_pkey" PRIMARY KEY ("Id_bank_account"),
    CONSTRAINT "uq_bank_account_casso" UNIQUE ("Id_casso_account"),
    CONSTRAINT "ck_bank_connect_status" CHECK ("Connect_status" IN ('Active', 'Inactive'))
);

-- ============================================================================
-- 2.8. BẢNG WALLET
--   Type: Cash (tiền mặt ảo), Bank (user tự tạo), Saving (tiết kiệm),
--         Banking (chỉ tạo từ Casso — bắt buộc Id_bank_casso)
-- ============================================================================
CREATE TABLE "wallet" (
    "Idwallet"        VARCHAR(36)   NOT NULL,
    "Idaccount"       INTEGER       NOT NULL,
    "Id_bank_casso"   VARCHAR(36),
    "Name"            VARCHAR(100)  NOT NULL,
    "Type"            VARCHAR(10)   NOT NULL DEFAULT 'Cash',
    "Balance"         DECIMAL(15,2) NOT NULL DEFAULT 0,
    "Currency"        VARCHAR(3)    NOT NULL DEFAULT 'VND',
    "Status"          VARCHAR(10)   NOT NULL DEFAULT 'Active',
    "IncludeInTotal"  BOOLEAN       NOT NULL DEFAULT true,
    "Is_default"      BOOLEAN       NOT NULL DEFAULT false,
    "Icon"            VARCHAR(20)   DEFAULT 'wallet',
    "Color"           VARCHAR(20)   DEFAULT '#4CAF50',
    "Create_at"       TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at"       TIMESTAMP(6)  NOT NULL,
    "Delete_at"       TIMESTAMP(6),
    CONSTRAINT "wallet_pkey" PRIMARY KEY ("Idwallet"),
    CONSTRAINT "uq_wallet_account_name" UNIQUE ("Idaccount", "Name"),
    CONSTRAINT "ck_wallet_type" CHECK ("Type" IN ('Cash', 'Bank', 'Saving', 'Banking')),
    CONSTRAINT "ck_wallet_currency" CHECK ("Currency" IN ('VND', 'USD', 'RUP', 'NDT')),
    CONSTRAINT "ck_wallet_status" CHECK ("Status" IN ('Active', 'Inactive')),
    CONSTRAINT "ck_wallet_banking" CHECK (
        ("Type" = 'Banking' AND "Id_bank_casso" IS NOT NULL) OR
        ("Type" <> 'Banking' AND "Id_bank_casso" IS NULL)
    )
);

-- Ràng buộc đặc biệt (partial unique — mỗi tài khoản tối đa 1 ví mỗi loại)
-- 1. Tối đa 1 ví tiết kiệm cứng (Type='Saving') mỗi tài khoản
CREATE UNIQUE INDEX "uq_wallet_saving_one" ON "wallet" ("Idaccount")
    WHERE "Type" = 'Saving' AND "Delete_at" IS NULL;
-- 2. Tối đa 1 ví tự thiết lập mặc định (Is_default=TRUE) mỗi tài khoản
CREATE UNIQUE INDEX "uq_wallet_default_one" ON "wallet" ("Idaccount")
    WHERE "Is_default" = TRUE AND "Delete_at" IS NULL;
-- 3. 1 tài khoản NH chỉ tạo 1 ví bank (Id_bank_casso không trùng)
CREATE UNIQUE INDEX "uq_wallet_bank_one" ON "wallet" ("Id_bank_casso")
    WHERE "Id_bank_casso" IS NOT NULL;

-- ============================================================================
-- 2.9. BẢNG BUDGET (Idcategory NULL = ngân sách tổng)
-- ============================================================================
CREATE TABLE "budget" (
    "Idbudget"       VARCHAR(36)   NOT NULL,
    "Idaccount"      INTEGER       NOT NULL,
    "Idcategory"     VARCHAR(36),
    "TotalAmount"    DECIMAL(15,2) NOT NULL,
    "Spent"          DECIMAL(15,2) NOT NULL DEFAULT 0,
    "Remaining"      DECIMAL(15,2),
    "PercentSpent"   INTEGER       NOT NULL DEFAULT 0,
    "OverSpending"   VARCHAR(20)   NOT NULL DEFAULT 'Over',
    "OverAmount"     DECIMAL(15,2),
    "Start"          TIMESTAMP(6)  NOT NULL,
    "End"            TIMESTAMP(6),
    "Recurrence"     BOOLEAN       NOT NULL DEFAULT false,
    "Time_recurrence" VARCHAR(10)  NOT NULL,
    "Note"           TEXT,
    "Create_at"      TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at"      TIMESTAMP(6)  NOT NULL,
    "Delete_at"      TIMESTAMP(6),
    CONSTRAINT "budget_pkey" PRIMARY KEY ("Idbudget"),
    CONSTRAINT "ck_budget_total" CHECK ("TotalAmount" > 0),
    CONSTRAINT "ck_budget_percent" CHECK ("PercentSpent" >= 0 AND "PercentSpent" <= 100),
    CONSTRAINT "ck_budget_overspending" CHECK ("OverSpending" IN ('Stop', 'Over')),
    CONSTRAINT "ck_budget_recurrence" CHECK ("Time_recurrence" IN ('Week', 'Month', 'Quarter', 'Year')),
    CONSTRAINT "ck_budget_period" CHECK ("End" IS NULL OR "End" > "Start")
);

-- ============================================================================
-- 2.10. BẢNG BILL (Idwallet & Idcategory BẮT BUỘC — chọn khi tạo bill)
-- ============================================================================
CREATE TABLE "bill" (
    "Idbill"         VARCHAR(36)   NOT NULL,
    "Idaccount"      INTEGER       NOT NULL,
    "Idwallet"       VARCHAR(36)   NOT NULL,
    "Idcategory"     VARCHAR(36)   NOT NULL,
    "Name"           VARCHAR(100)  NOT NULL,
    "Amount"         DECIMAL(15,2) NOT NULL,
    "due_date"       TIMESTAMP(6)  NOT NULL,
    "Pay_status"     BOOLEAN       NOT NULL DEFAULT false,
    "Recurrence"     BOOLEAN       NOT NULL DEFAULT false,
    "Time_recurrence" VARCHAR(10)  NOT NULL,
    "Icon"           VARCHAR(20)   DEFAULT 'receipt',
    "Color"          VARCHAR(20)   DEFAULT '#4CAF50',
    "Note"           TEXT,
    "Create_at"      TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at"      TIMESTAMP(6)  NOT NULL,
    "Delete_at"      TIMESTAMP(6),
    CONSTRAINT "bill_pkey" PRIMARY KEY ("Idbill"),
    CONSTRAINT "ck_bill_amount" CHECK ("Amount" > 0),
    CONSTRAINT "ck_bill_recurrence" CHECK ("Time_recurrence" IN ('Week', 'Month', 'Quarter', 'Year'))
);

-- ============================================================================
-- 2.11. BẢNG GOAL (Idwallet NULL = chưa gán ví đích)
-- ============================================================================
CREATE TABLE "goal" (
    "Idgoal"          VARCHAR(36)   NOT NULL,
    "Idaccount"       INTEGER       NOT NULL,
    "Idwallet"        VARCHAR(36),
    "Name"            VARCHAR(100)  NOT NULL,
    "Target_amount"   DECIMAL(15,2) NOT NULL,
    "Current_amount"  DECIMAL(15,2) NOT NULL DEFAULT 0,
    "Target_date"     TIMESTAMP(6)  NOT NULL,
    "Status_complete" BOOLEAN       NOT NULL DEFAULT false,
    "Icon"            VARCHAR(20)   DEFAULT 'flag',
    "Color"           VARCHAR(20)   DEFAULT '#4CAF50',
    "Note"            TEXT,
    "Create_at"       TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at"       TIMESTAMP(6)  NOT NULL,
    "Delete_at"       TIMESTAMP(6),
    CONSTRAINT "goal_pkey" PRIMARY KEY ("Idgoal"),
    CONSTRAINT "ck_goal_target" CHECK ("Target_amount" > 0),
    CONSTRAINT "ck_goal_current" CHECK ("Current_amount" >= 0)
);

-- ============================================================================
-- 2.12. BẢNG TRANSACTION
--   Amount giữ dấu ±: dương (+) = tiền vào, âm (-) = tiền ra.
--   Provider: Manual / Casso / SMS / OCR. Chống trùng (Provider, Bank_tran_id).
--   Luồng webhook: ghi TRƯỚC (Idcategory=NULL) → phân loại category SAU.
-- ============================================================================
CREATE TABLE "transaction" (
    "Idtran"          VARCHAR(36)   NOT NULL,
    "Idaccount"       INTEGER       NOT NULL,
    "Idwallet"        VARCHAR(36)   NOT NULL,
    "Idcategory"      VARCHAR(36),
    "Amount"          DECIMAL(15,2) NOT NULL,
    "Type"            VARCHAR(20)   NOT NULL,
    "Provider"        VARCHAR(40)   NOT NULL DEFAULT 'Manual',
    "Note"            TEXT,
    "Images"          TEXT,
    "Create_at"       TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at"       TIMESTAMP(6)  NOT NULL,
    "Delete_at"       TIMESTAMP(6),
    "Wallet_Transfer" VARCHAR(36),
    "Bank_tran_id"    VARCHAR(100),
    CONSTRAINT "transaction_pkey" PRIMARY KEY ("Idtran"),
    CONSTRAINT "uq_transaction_external" UNIQUE ("Provider", "Bank_tran_id"),
    CONSTRAINT "ck_txn_type" CHECK ("Type" IN ('Transaction', 'Transfer')),
    CONSTRAINT "ck_txn_provider" CHECK ("Provider" IN ('Manual', 'Casso', 'SMS', 'OCR')),
    CONSTRAINT "ck_txn_amount" CHECK ("Amount" <> 0),
    -- Casso/SMS bắt buộc có Bank_tran_id; Manual/OCR không có
    CONSTRAINT "ck_txn_bank_id" CHECK (
        ("Provider" IN ('Casso', 'SMS') AND "Bank_tran_id" IS NOT NULL) OR
        ("Provider" IN ('Manual', 'OCR') AND "Bank_tran_id" IS NULL)
    )
);

-- ============================================================================
-- 2.13. BẢNG REFRESHTOKEN
-- ============================================================================
CREATE TABLE "refreshtoken" (
    "Idtoken"     SERIAL       NOT NULL,
    "Token_hash"  VARCHAR(255) NOT NULL,
    "Idaccount"   INTEGER      NOT NULL,
    "Idrole"      INTEGER      NOT NULL DEFAULT 2,
    "Expiry"      TIMESTAMP(6) NOT NULL,
    "Revoked"     BOOLEAN      NOT NULL DEFAULT false,
    "Device_name" VARCHAR(100),
    "Ip_address"  VARCHAR(45),
    "User_agent"  TEXT,
    "Create_at"   TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at"   TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "refreshtoken_pkey" PRIMARY KEY ("Idtoken"),
    CONSTRAINT "uq_refreshtoken_hash" UNIQUE ("Token_hash"),
    CONSTRAINT "ck_refreshtoken_expiry" CHECK ("Expiry" > "Create_at")
);

-- ============================================================================
-- INDEX
-- ============================================================================
CREATE INDEX "idx_account_role" ON "account" ("Idrole");
CREATE INDEX "idx_auditlog_account" ON "audit_log" ("Idaccount");
CREATE INDEX "idx_otp_account_purpose" ON "otp_code" ("Idaccount", "purpose");
CREATE INDEX "idx_otp_expires" ON "otp_code" ("expires_at");
CREATE INDEX "idx_category_group" ON "category" ("Idgroup");
CREATE INDEX "idx_category_create_by" ON "category" ("Create_by");
CREATE INDEX "idx_bank_account_owner" ON "bank_account" ("Idaccount");
CREATE INDEX "idx_bank_account_status" ON "bank_account" ("Connect_status");
CREATE INDEX "idx_wallet_account" ON "wallet" ("Idaccount");
CREATE INDEX "idx_wallet_bank" ON "wallet" ("Id_bank_casso");
CREATE INDEX "idx_wallet_updated" ON "wallet" ("Update_at");
CREATE INDEX "idx_budget_account" ON "budget" ("Idaccount");
CREATE INDEX "idx_budget_category" ON "budget" ("Idcategory");
CREATE INDEX "idx_bill_account" ON "bill" ("Idaccount");
CREATE INDEX "idx_bill_wallet" ON "bill" ("Idwallet");
CREATE INDEX "idx_bill_category" ON "bill" ("Idcategory");
CREATE INDEX "idx_goal_account" ON "goal" ("Idaccount");
CREATE INDEX "idx_goal_wallet" ON "goal" ("Idwallet");
CREATE INDEX "idx_transaction_account" ON "transaction" ("Idaccount");
CREATE INDEX "idx_transaction_wallet" ON "transaction" ("Idwallet");
CREATE INDEX "idx_transaction_category" ON "transaction" ("Idcategory");
CREATE INDEX "idx_transaction_create" ON "transaction" ("Create_at");
CREATE INDEX "idx_transaction_updated" ON "transaction" ("Update_at");
CREATE INDEX "idx_transaction_provider" ON "transaction" ("Provider");
CREATE INDEX "idx_refreshtoken_account" ON "refreshtoken" ("Idaccount");
CREATE INDEX "idx_refreshtoken_expiry" ON "refreshtoken" ("Expiry");
CREATE INDEX "idx_refreshtoken_revoked" ON "refreshtoken" ("Revoked");
CREATE INDEX "idx_refreshtoken_token_hash" ON "refreshtoken" ("Token_hash");

-- ============================================================================
-- FOREIGN KEY
-- ============================================================================
ALTER TABLE "account" ADD CONSTRAINT "fk_account_role"
    FOREIGN KEY ("Idrole") REFERENCES "role" ("Idrole") ON DELETE RESTRICT ON UPDATE NO ACTION;
ALTER TABLE "user" ADD CONSTRAINT "fk_user_account"
    FOREIGN KEY ("Idaccount") REFERENCES "account" ("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "audit_log" ADD CONSTRAINT "fk_auditlog_account"
    FOREIGN KEY ("Idaccount") REFERENCES "account" ("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "otp_code" ADD CONSTRAINT "fk_otp_account"
    FOREIGN KEY ("Idaccount") REFERENCES "account" ("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "category" ADD CONSTRAINT "fk_category_account"
    FOREIGN KEY ("Create_by") REFERENCES "account" ("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "category" ADD CONSTRAINT "fk_category_parent"
    FOREIGN KEY ("Idgroup") REFERENCES "category" ("Idcategory") ON DELETE SET NULL ON UPDATE NO ACTION;
ALTER TABLE "bank_account" ADD CONSTRAINT "fk_bank_account_owner"
    FOREIGN KEY ("Idaccount") REFERENCES "account" ("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "wallet" ADD CONSTRAINT "fk_wallet_account"
    FOREIGN KEY ("Idaccount") REFERENCES "account" ("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "wallet" ADD CONSTRAINT "fk_wallet_bank"
    FOREIGN KEY ("Id_bank_casso") REFERENCES "bank_account" ("Id_bank_account") ON DELETE SET NULL ON UPDATE NO ACTION;
ALTER TABLE "budget" ADD CONSTRAINT "fk_budget_account"
    FOREIGN KEY ("Idaccount") REFERENCES "account" ("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "budget" ADD CONSTRAINT "fk_budget_category"
    FOREIGN KEY ("Idcategory") REFERENCES "category" ("Idcategory") ON DELETE SET NULL ON UPDATE NO ACTION;
ALTER TABLE "bill" ADD CONSTRAINT "fk_bill_account"
    FOREIGN KEY ("Idaccount") REFERENCES "account" ("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "bill" ADD CONSTRAINT "fk_bill_wallet"
    FOREIGN KEY ("Idwallet") REFERENCES "wallet" ("Idwallet") ON DELETE RESTRICT ON UPDATE NO ACTION;
ALTER TABLE "bill" ADD CONSTRAINT "fk_bill_category"
    FOREIGN KEY ("Idcategory") REFERENCES "category" ("Idcategory") ON DELETE RESTRICT ON UPDATE NO ACTION;
ALTER TABLE "goal" ADD CONSTRAINT "fk_goal_account"
    FOREIGN KEY ("Idaccount") REFERENCES "account" ("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "goal" ADD CONSTRAINT "fk_goal_wallet"
    FOREIGN KEY ("Idwallet") REFERENCES "wallet" ("Idwallet") ON DELETE SET NULL ON UPDATE NO ACTION;
ALTER TABLE "transaction" ADD CONSTRAINT "fk_transaction_account"
    FOREIGN KEY ("Idaccount") REFERENCES "account" ("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "transaction" ADD CONSTRAINT "fk_transaction_category"
    FOREIGN KEY ("Idcategory") REFERENCES "category" ("Idcategory") ON DELETE SET NULL ON UPDATE NO ACTION;
ALTER TABLE "transaction" ADD CONSTRAINT "fk_transaction_wallet"
    FOREIGN KEY ("Idwallet") REFERENCES "wallet" ("Idwallet") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "transaction" ADD CONSTRAINT "fk_transaction_wallet_transfer"
    FOREIGN KEY ("Wallet_Transfer") REFERENCES "wallet" ("Idwallet") ON DELETE SET NULL ON UPDATE NO ACTION;
ALTER TABLE "refreshtoken" ADD CONSTRAINT "fk_refreshtoken_account"
    FOREIGN KEY ("Idaccount") REFERENCES "account" ("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- ============================================================================
-- SEED MẪU (dữ liệu nền)
-- ============================================================================
-- Role mặc định (Idrole 1 = admin, 2 = user)
INSERT INTO "role" ("Rolename", "Description") VALUES
    ('admin', 'Quản trị hệ thống'),
    ('user',  'Người dùng thường')
ON CONFLICT ("Rolename") DO NOTHING;
