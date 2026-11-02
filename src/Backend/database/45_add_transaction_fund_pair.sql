ALTER TABLE "transaction" ADD COLUMN IF NOT EXISTS "Idfund_pair" VARCHAR(36) NULL;
CREATE INDEX IF NOT EXISTS "idx_transaction_fund_pair"
  ON "transaction" ("Idfund_pair") WHERE "Idfund_pair" IS NOT NULL;
