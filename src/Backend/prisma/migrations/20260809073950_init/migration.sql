-- CreateTable
CREATE TABLE "User" (
    "iduser" SERIAL NOT NULL,
    "fullname" VARCHAR(100) NOT NULL,
    "email" VARCHAR(100) NOT NULL,
    "phone" VARCHAR(15),
    "address" VARCHAR(255),
    "location" CHAR(5),
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "idaccount" INTEGER NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("iduser")
);

-- CreateTable
CREATE TABLE "account" (
    "idaccount" SERIAL NOT NULL,
    "username" VARCHAR(50) NOT NULL,
    "password" VARCHAR(255) NOT NULL,
    "status" VARCHAR(10) NOT NULL DEFAULT 'Active',
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "idrole" INTEGER NOT NULL,

    CONSTRAINT "account_pkey" PRIMARY KEY ("idaccount")
);

-- CreateTable
CREATE TABLE "auditlog" (
    "idlog" SERIAL NOT NULL,
    "idaccount" INTEGER NOT NULL,
    "action" TEXT,
    "details" TEXT,
    "time" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auditlog_pkey" PRIMARY KEY ("idlog")
);

-- CreateTable
CREATE TABLE "category" (
    "idcategory" SERIAL NOT NULL,
    "namecategory" VARCHAR(100) NOT NULL,
    "classify" VARCHAR(10) NOT NULL,
    "is_default" BOOLEAN DEFAULT false,
    "created_by" INTEGER NOT NULL,
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "category_pkey" PRIMARY KEY ("idcategory")
);

-- CreateTable
CREATE TABLE "role" (
    "idrole" SERIAL NOT NULL,
    "rolename" VARCHAR(50) NOT NULL,
    "description" VARCHAR(255),

    CONSTRAINT "role_pkey" PRIMARY KEY ("idrole")
);

-- CreateTable
CREATE TABLE "refreshtoken" (
    "idtoken" SERIAL NOT NULL,
    "token_hash" VARCHAR(255) NOT NULL,
    "idaccount" INTEGER NOT NULL,
    "idrole" INTEGER NOT NULL DEFAULT 2,
    "expiry" TIMESTAMP(6) NOT NULL,
    "revoked" BOOLEAN DEFAULT false,
    "device_name" VARCHAR(100),
    "ip_address" VARCHAR(45),
    "user_agent" TEXT,
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refreshtoken_pkey" PRIMARY KEY ("idtoken")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "User_idaccount_key" ON "User"("idaccount");

-- CreateIndex
CREATE UNIQUE INDEX "account_username_key" ON "account"("username");

-- CreateIndex
CREATE UNIQUE INDEX "role_rolename_key" ON "role"("rolename");

-- CreateIndex
CREATE UNIQUE INDEX "refreshtoken_token_hash_key" ON "refreshtoken"("token_hash");

-- CreateIndex
CREATE INDEX "idx_refreshtoken_account" ON "refreshtoken"("idaccount");

-- CreateIndex
CREATE INDEX "idx_refreshtoken_expiry" ON "refreshtoken"("expiry");

-- CreateIndex
CREATE INDEX "idx_refreshtoken_revoked" ON "refreshtoken"("revoked");

-- CreateIndex
CREATE INDEX "idx_refreshtoken_token_hash" ON "refreshtoken"("token_hash");

-- AddForeignKey
ALTER TABLE "User" ADD CONSTRAINT "fk_user_account" FOREIGN KEY ("idaccount") REFERENCES "account"("idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "account" ADD CONSTRAINT "fk_account_role" FOREIGN KEY ("idrole") REFERENCES "role"("idrole") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "auditlog" ADD CONSTRAINT "fk_actionlog_account" FOREIGN KEY ("idaccount") REFERENCES "account"("idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "category" ADD CONSTRAINT "fk_category_account" FOREIGN KEY ("created_by") REFERENCES "account"("idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "refreshtoken" ADD CONSTRAINT "fk_refreshtoken_account" FOREIGN KEY ("idaccount") REFERENCES "account"("idaccount") ON DELETE CASCADE ON UPDATE NO ACTION;
