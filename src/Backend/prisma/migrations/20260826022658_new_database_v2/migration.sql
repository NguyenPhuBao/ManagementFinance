-- CreateTable
CREATE TABLE "role" (
    "Idrole" SERIAL NOT NULL,
    "Rolename" VARCHAR(20) NOT NULL,
    "Description" TEXT,

    CONSTRAINT "role_pkey" PRIMARY KEY ("Idrole")
);

-- CreateTable
CREATE TABLE "account" (
    "Idaccount" SERIAL NOT NULL,
    "Idrole" INTEGER NOT NULL,
    "Email" VARCHAR(100) NOT NULL,
    "Username" VARCHAR(255) NOT NULL,
    "Password" VARCHAR(255) NOT NULL,
    "Status" VARCHAR(20) NOT NULL DEFAULT 'Active',
    "Type" VARCHAR(20) NOT NULL DEFAULT 'Basic',
    "Create_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at" TIMESTAMP(6),
    "Delete_at" TIMESTAMP(6),

    CONSTRAINT "account_pkey" PRIMARY KEY ("Idaccount")
);

-- CreateTable
CREATE TABLE "user" (
    "Iduser" SERIAL NOT NULL,
    "Idaccount" INTEGER NOT NULL,
    "Fullname" VARCHAR(100) NOT NULL,
    "Email" VARCHAR(100) NOT NULL,
    "Phone" VARCHAR(15),
    "Address" TEXT,
    "Country_code" CHAR(4),
    "Create_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at" TIMESTAMP(6),
    "Delete_at" TIMESTAMP(6),

    CONSTRAINT "user_pkey" PRIMARY KEY ("Iduser")
);

-- CreateTable
CREATE TABLE "audit_log" (
    "Idlog" SERIAL NOT NULL,
    "Idaccount" INTEGER NOT NULL,
    "Request" VARCHAR(200) NOT NULL,
    "TimeReq" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "TimeRes" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_log_pkey" PRIMARY KEY ("Idlog")
);

-- CreateTable
CREATE TABLE "otp_code" (
    "Id_otp" SERIAL NOT NULL,
    "Idaccount" INTEGER NOT NULL,
    "Email" VARCHAR(100) NOT NULL,
    "code_hash" VARCHAR(255) NOT NULL,
    "purpose" VARCHAR(30) NOT NULL,
    "is_used" BOOLEAN NOT NULL DEFAULT false,
    "expires_at" TIMESTAMP(6) NOT NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_code_pkey" PRIMARY KEY ("Id_otp")
);

-- CreateTable
CREATE TABLE "category" (
    "Idcategory" VARCHAR(36) NOT NULL,
    "Create_by" INTEGER NOT NULL DEFAULT 1,
    "NameCategory" VARCHAR(200) NOT NULL,
    "Classify" VARCHAR(10) NOT NULL,
    "Is_default" BOOLEAN NOT NULL DEFAULT false,
    "Is_group" BOOLEAN NOT NULL DEFAULT false,
    "Idgroup" VARCHAR(36),
    "Keyword" VARCHAR(500),
    "Icon" VARCHAR(20),
    "Create_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "Update_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "Delete_at" TIMESTAMP(6),

    CONSTRAINT "category_pkey" PRIMARY KEY ("Idcategory")
);

-- CreateTable
CREATE TABLE "bank_account" (
    "Id_bank_account" VARCHAR(36) NOT NULL,
    "Idaccount" INTEGER NOT NULL,
    "Id_casso_account" VARCHAR(100) NOT NULL,
    "Account_number" VARCHAR(50) NOT NULL,
    "Account_name" VARCHAR(255) NOT NULL,
    "Bank_name" VARCHAR(100) NOT NULL,
    "Balance" DECIMAL(15,2) NOT NULL DEFAULT 0,
    "Connect_status" VARCHAR(20) NOT NULL DEFAULT 'active',
    "Create_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "Update_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "Delete_at" TIMESTAMP(6),

    CONSTRAINT "bank_account_pkey" PRIMARY KEY ("Id_bank_account")
);

-- CreateTable
CREATE TABLE "wallet" (
    "Idwallet" VARCHAR(36) NOT NULL,
    "Idaccount" INTEGER NOT NULL,
    "Id_bank_casso" VARCHAR(36),
    "Name" VARCHAR(40) NOT NULL,
    "Type" VARCHAR(10) NOT NULL DEFAULT 'Cash',
    "Balance" DECIMAL(15,2) NOT NULL DEFAULT 0,
    "Currency" VARCHAR(3) NOT NULL DEFAULT 'VND',
    "Status" VARCHAR(10) NOT NULL DEFAULT 'Active',
    "IncludeInTotal" BOOLEAN NOT NULL DEFAULT true,
    "Is_default" BOOLEAN NOT NULL DEFAULT false,
    "Icon" VARCHAR(20) DEFAULT 'wallet',
    "Color" VARCHAR(20) DEFAULT '#4CAF50',
    "Create_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at" TIMESTAMP(6) NOT NULL,
    "Delete_at" TIMESTAMP(6),

    CONSTRAINT "wallet_pkey" PRIMARY KEY ("Idwallet")
);

-- CreateTable
CREATE TABLE "budget" (
    "Idbudget" VARCHAR(36) NOT NULL,
    "Idaccount" INTEGER NOT NULL,
    "Idcategory" VARCHAR(36),
    "TotalAmount" DECIMAL(15,2) NOT NULL,
    "Spent" DECIMAL(15,2) NOT NULL DEFAULT 0,
    "Remaining" DECIMAL(15,2),
    "PercentSpent" INTEGER NOT NULL DEFAULT 0,
    "OverSpending" VARCHAR(20) NOT NULL DEFAULT 'Over',
    "OverAmount" DECIMAL(15,2),
    "Start" TIMESTAMP(6) NOT NULL,
    "End" TIMESTAMP(6),
    "Recurrence" BOOLEAN NOT NULL DEFAULT false,
    "Time_recurrence" VARCHAR(10) NOT NULL,
    "Note" TEXT,
    "Create_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at" TIMESTAMP(6) NOT NULL,
    "Delete_at" TIMESTAMP(6),

    CONSTRAINT "budget_pkey" PRIMARY KEY ("Idbudget")
);

-- CreateTable
CREATE TABLE "bill" (
    "Idbill" VARCHAR(36) NOT NULL,
    "Idaccount" INTEGER NOT NULL,
    "Idwallet" VARCHAR(36) NOT NULL,
    "Idcategory" VARCHAR(36) NOT NULL,
    "Name" VARCHAR(100) NOT NULL,
    "Amount" DECIMAL(15,2) NOT NULL,
    "due_date" TIMESTAMP(6) NOT NULL,
    "Pay_status" BOOLEAN NOT NULL DEFAULT false,
    "Recurrence" BOOLEAN NOT NULL DEFAULT false,
    "Time_recurrence" VARCHAR(10) NOT NULL,
    "Icon" VARCHAR(20) DEFAULT 'receipt',
    "Color" VARCHAR(20) DEFAULT '#4CAF50',
    "Note" TEXT,
    "Create_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at" TIMESTAMP(6) NOT NULL,
    "Delete_at" TIMESTAMP(6),

    CONSTRAINT "bill_pkey" PRIMARY KEY ("Idbill")
);

-- CreateTable
CREATE TABLE "goal" (
    "Idgoal" VARCHAR(36) NOT NULL,
    "Idaccount" INTEGER NOT NULL,
    "Idwallet" VARCHAR(36),
    "Name" VARCHAR(100) NOT NULL,
    "Target_amount" DECIMAL(15,2) NOT NULL,
    "Current_amount" DECIMAL(15,2) NOT NULL DEFAULT 0,
    "Target_date" TIMESTAMP(6) NOT NULL,
    "Status_complete" BOOLEAN NOT NULL DEFAULT false,
    "Icon" VARCHAR(20) DEFAULT 'flag',
    "Color" VARCHAR(20) DEFAULT '#4CAF50',
    "Note" TEXT,
    "Create_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at" TIMESTAMP(6) NOT NULL,
    "Delete_at" TIMESTAMP(6),

    CONSTRAINT "goal_pkey" PRIMARY KEY ("Idgoal")
);

-- CreateTable
CREATE TABLE "transaction" (
    "Idtran" VARCHAR(36) NOT NULL,
    "Idaccount" INTEGER NOT NULL,
    "Idwallet" VARCHAR(36) NOT NULL,
    "Idcategory" VARCHAR(36),
    "Amount" DECIMAL(15,2) NOT NULL,
    "Type" VARCHAR(20) NOT NULL,
    "Provider" VARCHAR(40) NOT NULL DEFAULT 'Manual',
    "Note" TEXT,
    "Images" TEXT,
    "Create_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at" TIMESTAMP(6) NOT NULL,
    "Delete_at" TIMESTAMP(6),
    "Wallet_Transfer" VARCHAR(36),
    "Bank_tran_id" VARCHAR(100),

    CONSTRAINT "transaction_pkey" PRIMARY KEY ("Idtran")
);

-- CreateTable
CREATE TABLE "refreshtoken" (
    "Idtoken" SERIAL NOT NULL,
    "Token_hash" VARCHAR(255) NOT NULL,
    "Idaccount" INTEGER NOT NULL,
    "Idrole" INTEGER NOT NULL DEFAULT 2,
    "Expiry" TIMESTAMP(6) NOT NULL,
    "Revoked" BOOLEAN NOT NULL DEFAULT false,
    "Device_name" VARCHAR(100),
    "Ip_address" VARCHAR(45),
    "User_agent" TEXT,
    "Create_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Update_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refreshtoken_pkey" PRIMARY KEY ("Idtoken")
);

-- CreateIndex
CREATE UNIQUE INDEX "role_Rolename_key" ON "role"("Rolename");

-- CreateIndex
CREATE UNIQUE INDEX "account_Email_key" ON "account"("Email");

-- CreateIndex
CREATE UNIQUE INDEX "account_Username_key" ON "account"("Username");

-- CreateIndex
CREATE INDEX "idx_account_role" ON "account"("Idrole");

-- CreateIndex
CREATE UNIQUE INDEX "user_Idaccount_key" ON "user"("Idaccount");

-- CreateIndex
CREATE UNIQUE INDEX "user_Email_key" ON "user"("Email");

-- CreateIndex
CREATE INDEX "idx_auditlog_account" ON "audit_log"("Idaccount");

-- CreateIndex
CREATE INDEX "idx_otp_account_purpose" ON "otp_code"("Idaccount", "purpose");

-- CreateIndex
CREATE INDEX "idx_otp_expires" ON "otp_code"("expires_at");

-- CreateIndex
CREATE INDEX "idx_category_id" ON "category"("Idcategory");

-- CreateIndex
CREATE INDEX "idx_category_group" ON "category"("Idgroup");

-- CreateIndex
CREATE INDEX "idx_category_create_by" ON "category"("Create_by");

-- CreateIndex
CREATE UNIQUE INDEX "bank_account_Id_casso_account_key" ON "bank_account"("Id_casso_account");

-- CreateIndex
CREATE INDEX "idx_bank_account_owner" ON "bank_account"("Idaccount");

-- CreateIndex
CREATE INDEX "idx_bank_account_status" ON "bank_account"("Connect_status");

-- CreateIndex
CREATE INDEX "idx_wallet_account" ON "wallet"("Idaccount");

-- CreateIndex
CREATE INDEX "idx_wallet_bank" ON "wallet"("Id_bank_casso");

-- CreateIndex
CREATE INDEX "idx_wallet_updated" ON "wallet"("Update_at");

-- CreateIndex
CREATE INDEX "idx_budget_account" ON "budget"("Idaccount");

-- CreateIndex
CREATE INDEX "idx_budget_category" ON "budget"("Idcategory");

-- CreateIndex
CREATE INDEX "idx_bill_account" ON "bill"("Idaccount");

-- CreateIndex
CREATE INDEX "idx_bill_wallet" ON "bill"("Idwallet");

-- CreateIndex
CREATE INDEX "idx_bill_category" ON "bill"("Idcategory");

-- CreateIndex
CREATE INDEX "idx_goal_account" ON "goal"("Idaccount");

-- CreateIndex
CREATE INDEX "idx_goal_wallet" ON "goal"("Idwallet");

-- CreateIndex
CREATE INDEX "idx_transaction_account" ON "transaction"("Idaccount");

-- CreateIndex
CREATE INDEX "idx_transaction_wallet" ON "transaction"("Idwallet");

-- CreateIndex
CREATE INDEX "idx_transaction_category" ON "transaction"("Idcategory");

-- CreateIndex
CREATE INDEX "idx_transaction_create" ON "transaction"("Create_at");

-- CreateIndex
CREATE INDEX "idx_transaction_updated" ON "transaction"("Update_at");

-- CreateIndex
CREATE INDEX "idx_transaction_provider" ON "transaction"("Provider");

-- CreateIndex
CREATE UNIQUE INDEX "uq_transaction_external" ON "transaction"("Provider", "Bank_tran_id");

-- CreateIndex
CREATE UNIQUE INDEX "refreshtoken_Token_hash_key" ON "refreshtoken"("Token_hash");

-- CreateIndex
CREATE INDEX "idx_refreshtoken_account" ON "refreshtoken"("Idaccount");

-- CreateIndex
CREATE INDEX "idx_refreshtoken_expiry" ON "refreshtoken"("Expiry");

-- CreateIndex
CREATE INDEX "idx_refreshtoken_revoked" ON "refreshtoken"("Revoked");

-- CreateIndex
CREATE INDEX "idx_refreshtoken_token_hash" ON "refreshtoken"("Token_hash");

-- AddForeignKey
ALTER TABLE "account" ADD CONSTRAINT "fk_account_role" FOREIGN KEY ("Idrole") REFERENCES "role"("Idrole") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user" ADD CONSTRAINT "fk_user_account" FOREIGN KEY ("Idaccount") REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "audit_log" ADD CONSTRAINT "fk_auditlog_account" FOREIGN KEY ("Idaccount") REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "otp_code" ADD CONSTRAINT "fk_otp_account" FOREIGN KEY ("Idaccount") REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "category" ADD CONSTRAINT "fk_category_account" FOREIGN KEY ("Create_by") REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "category" ADD CONSTRAINT "fk_category_parent" FOREIGN KEY ("Idgroup") REFERENCES "category"("Idcategory") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "bank_account" ADD CONSTRAINT "fk_bank_account_owner" FOREIGN KEY ("Idaccount") REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "wallet" ADD CONSTRAINT "fk_wallet_account" FOREIGN KEY ("Idaccount") REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "wallet" ADD CONSTRAINT "fk_wallet_bank" FOREIGN KEY ("Id_bank_casso") REFERENCES "bank_account"("Id_bank_account") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "budget" ADD CONSTRAINT "fk_budget_account" FOREIGN KEY ("Idaccount") REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "budget" ADD CONSTRAINT "fk_budget_category" FOREIGN KEY ("Idcategory") REFERENCES "category"("Idcategory") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "bill" ADD CONSTRAINT "fk_bill_account" FOREIGN KEY ("Idaccount") REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "bill" ADD CONSTRAINT "fk_bill_wallet" FOREIGN KEY ("Idwallet") REFERENCES "wallet"("Idwallet") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "bill" ADD CONSTRAINT "fk_bill_category" FOREIGN KEY ("Idcategory") REFERENCES "category"("Idcategory") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "goal" ADD CONSTRAINT "fk_goal_account" FOREIGN KEY ("Idaccount") REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "goal" ADD CONSTRAINT "fk_goal_wallet" FOREIGN KEY ("Idwallet") REFERENCES "wallet"("Idwallet") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "transaction" ADD CONSTRAINT "fk_transaction_account" FOREIGN KEY ("Idaccount") REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "transaction" ADD CONSTRAINT "fk_transaction_category" FOREIGN KEY ("Idcategory") REFERENCES "category"("Idcategory") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "transaction" ADD CONSTRAINT "fk_transaction_wallet" FOREIGN KEY ("Idwallet") REFERENCES "wallet"("Idwallet") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "transaction" ADD CONSTRAINT "fk_transaction_wallet_transfer" FOREIGN KEY ("Wallet_Transfer") REFERENCES "wallet"("Idwallet") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "refreshtoken" ADD CONSTRAINT "fk_refreshtoken_account" FOREIGN KEY ("Idaccount") REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;
