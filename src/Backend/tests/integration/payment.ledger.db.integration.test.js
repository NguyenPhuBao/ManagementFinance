/**
 * Migration 53 trên CSDL thử thật (TEST_DATABASE_URL, máy này). Kế hoạch 2026-11-15 "đơn mẫu chống lạm dụng":
 *  P9  dọn đơn mẫu + giao dịch giả trước khi bật trigger; chạy lại migration không lỗi
 *  P10 sổ giao dịch / nhật ký webhook cấm sửa, cấm xoá; đơn cấm xoá, cấm sửa trường gốc, trường tiền ghi một lần,
 *      đơn REFUNDED khoá hẳn; vẫn cho đổi trạng thái hợp lệ
 *  P14 dòng sổ thiếu mã giao dịch ngân hàng / trùng mã ⇒ CSDL từ chối
 * Lượt đầu (trigger chưa có) mới kiểm được bước dọn; các lượt sau bỏ qua phần đó.
 */
const { describe, it, before } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { pool } = require('../../config/db');

const SQL = fs.readFileSync(path.join(__dirname, '../../database/53_payment_legal_retention.sql'), 'utf8').replace(/^﻿/, '');
const uid = () => crypto.randomUUID();
const code = () => Number(String(Date.now()).slice(-9) + String(Math.floor(Math.random() * 1000)).padStart(3, '0'));

describe('Migration 53: sổ thanh toán bất biến', () => {
  let acc;
  let firstRun;
  const seeded = {};

  before(async () => {
    acc = (await pool.query('SELECT "Idaccount" AS id FROM "account" ORDER BY 1 LIMIT 1')).rows[0].id;
    firstRun = (await pool.query("SELECT 1 FROM pg_trigger WHERE tgname = 'trg_protect_payment_transaction'")).rowCount === 0;
    if (firstRun) {
      seeded.tpl = uid();
      seeded.real = uid();
      await pool.query(
        `INSERT INTO "payment_order" ("id","idaccount","order_code","amount","status","is_template") VALUES ($1,$2,$3,2000,'PAID',TRUE),($4,$2,$5,49000,'PAID',FALSE)`,
        [seeded.tpl, acc, code(), seeded.real, code()]
      );
      await pool.query(
        `INSERT INTO "payment_transaction" ("id","order_id","idaccount","payos_transaction_id","amount") VALUES
         ($1,$2,$3,'SAMPLE-TXN-1',2000),($4,$5,$3,$6,49000),($7,$5,$3,$8,49000)`,
        [uid(), seeded.tpl, acc, uid(), seeded.real, `SIM-REF-${Date.now()}`, uid(), `FT-IT-${Date.now()}`]
      );
    }
    await pool.query(SQL);
  });

  it('P9. Lượt đầu: đơn mẫu và giao dịch giả bị dọn, đơn thật và giao dịch thật giữ nguyên; chạy lại không lỗi', async () => {
    if (firstRun) {
      assert.equal((await pool.query('SELECT 1 FROM "payment_order" WHERE "id" = $1', [seeded.tpl])).rowCount, 0);
      assert.equal((await pool.query(`SELECT 1 FROM "payment_transaction" WHERE "payos_transaction_id" LIKE 'SIM-REF-%' OR "payos_transaction_id" LIKE 'SAMPLE-TXN-%'`)).rowCount, 0);
      assert.equal((await pool.query('SELECT 1 FROM "payment_order" WHERE "id" = $1', [seeded.real])).rowCount, 1);
      assert.equal((await pool.query(`SELECT 1 FROM "payment_transaction" WHERE "order_id" = $1 AND "payos_transaction_id" LIKE 'FT-IT-%'`, [seeded.real])).rowCount, 1);
    }
    await pool.query(SQL);
  });

  describe('Sau migration', () => {
    let orderId;
    let txId;
    before(async () => {
      orderId = uid();
      txId = uid();
      await pool.query(`INSERT INTO "payment_order" ("id","idaccount","order_code","amount","status") VALUES ($1,$2,$3,49000,'PENDING')`, [orderId, acc, code()]);
      await pool.query(
        `INSERT INTO "payment_transaction" ("id","order_id","idaccount","payos_transaction_id","amount","direction","source") VALUES ($1,$2,$3,$4,49000,'IN','WEBHOOK')`,
        [txId, orderId, acc, `FT-IT-${uid().slice(0, 8)}`]
      );
    });

    it('P10a. payment_transaction: cấm UPDATE và DELETE', async () => {
      await assert.rejects(pool.query('UPDATE "payment_transaction" SET "amount" = 1 WHERE "id" = $1', [txId]), /sổ chứng từ/);
      await assert.rejects(pool.query('DELETE FROM "payment_transaction" WHERE "id" = $1', [txId]), /sổ chứng từ/);
    });

    it('P10b. payment_webhook_log: cấm UPDATE và DELETE', async () => {
      const id = (await pool.query(`INSERT INTO "payment_webhook_log" ("signature_valid","payload") VALUES (TRUE,'enc:x') RETURNING "id"`)).rows[0].id;
      await assert.rejects(pool.query('UPDATE "payment_webhook_log" SET "handled_as" = $2 WHERE "id" = $1', [id, 'x']), /sổ chứng từ/);
      await assert.rejects(pool.query('DELETE FROM "payment_webhook_log" WHERE "id" = $1', [id]), /sổ chứng từ/);
    });

    it('P10c. payment_order: cấm xoá; cấm sửa số tiền / chủ đơn / cờ mẫu', async () => {
      await assert.rejects(pool.query('DELETE FROM "payment_order" WHERE "id" = $1', [orderId]), /cấm xoá/);
      await assert.rejects(pool.query('UPDATE "payment_order" SET "amount" = 1 WHERE "id" = $1', [orderId]), /trường gốc/);
      await assert.rejects(pool.query('UPDATE "payment_order" SET "is_template" = TRUE WHERE "id" = $1', [orderId]), /trường gốc/);
    });

    it('P10d. Đổi trạng thái hợp lệ và ghi trường tiền lần đầu được; ghi đè lần hai bị chặn', async () => {
      await pool.query(`UPDATE "payment_order" SET "status" = 'PAID', "paid_at" = now(), "amount_received" = 49000, "checkout_url" = NULL WHERE "id" = $1`, [orderId]);
      await assert.rejects(pool.query(`UPDATE "payment_order" SET "paid_at" = now() + interval '1 day' WHERE "id" = $1`, [orderId]), /một lần/);
      await assert.rejects(pool.query(`UPDATE "payment_order" SET "amount_received" = 1 WHERE "id" = $1`, [orderId]), /một lần/);
      await pool.query(`UPDATE "payment_order" SET "hidden_at" = now() WHERE "id" = $1`, [orderId]);
      await assert.rejects(pool.query(`UPDATE "payment_order" SET "hidden_at" = NULL WHERE "id" = $1`, [orderId]), /một lần/);
    });

    it('P10e. Đơn REFUNDED: khoá hẳn', async () => {
      await pool.query(`UPDATE "payment_order" SET "status" = 'REFUNDED', "refunded_at" = now(), "refunded_amount" = 49000 WHERE "id" = $1`, [orderId]);
      await assert.rejects(pool.query(`UPDATE "payment_order" SET "status" = 'PAID' WHERE "id" = $1`, [orderId]), /đã hoàn tiền/);
      await assert.rejects(pool.query(`UPDATE "payment_order" SET "refund_reason" = 'x' WHERE "id" = $1`, [orderId]), /đã hoàn tiền/);
    });

    it('P14. Dòng sổ thiếu mã giao dịch ngân hàng hoặc trùng mã ⇒ CSDL từ chối', async () => {
      await assert.rejects(
        pool.query(`INSERT INTO "payment_transaction" ("id","order_id","idaccount","amount") VALUES ($1,$2,$3,1000)`, [uid(), orderId, acc]),
        /null value|not-null/i
      );
      const dup = (await pool.query('SELECT "payos_transaction_id" r FROM "payment_transaction" WHERE "id" = $1', [txId])).rows[0].r;
      await assert.rejects(
        pool.query(`INSERT INTO "payment_transaction" ("id","order_id","idaccount","payos_transaction_id","amount") VALUES ($1,$2,$3,$4,1000)`, [uid(), orderId, acc, dup]),
        /duplicate key|uq_payment_transaction_payos_id/
      );
    });
  });
});
