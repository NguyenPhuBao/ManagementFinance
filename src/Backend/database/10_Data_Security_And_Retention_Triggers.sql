-- ============================================================================
-- 10_DATA_SECURITY_AND_RETENTION_TRIGGERS.SQL
-- Mục đích: Thiết lập Database Security Triggers trên PostgreSQL để bảo vệ
-- tính toàn vẹn bất biến (Append-only) của Audit Log và chống xóa vật lý
-- giao dịch tài chính trước thời hạn luật định (NĐ 53/2022 & Luật Kế toán 2015).
-- Ngày tạo: 2026-09-10
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. BẢO VỆ TÍNH TOÀN VẸN VÀ BẤT BIẾN CỦA NHẬT KÝ KIỂM TOÁN (AUDITLOG)
-- Căn cứ: Điều 26 Nghị định 53/2022/NĐ-CP — Lưu trữ tối thiểu 12 tháng (365 ngày).
-- Cơ chế: Append-only (Chỉ cho phép INSERT, cấm tuyệt đối UPDATE, cấm DELETE < 12 tháng).
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION protect_auditlog_immutability()
RETURNS TRIGGER AS $$
BEGIN
    -- Chặn hoàn toàn mọi hành vi cập nhật / sửa đổi nội dung log
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'BẢO MẬT: Bảng auditlog có tính chất Append-only, nghiêm cấm chỉnh sửa dữ liệu nhật ký kiểm toán!';
    END IF;

    -- Chặn hành vi xóa log nếu thời gian yêu cầu chưa đủ 365 ngày (12 tháng)
    IF TG_OP = 'DELETE' THEN
        IF OLD."TimeReq" > (NOW() - INTERVAL '365 days') THEN
            RAISE EXCEPTION 'BẢO MẬT: Không được phép xóa bản ghi auditlog trước thời hạn tối thiểu 12 tháng theo Nghị định 53/2022/NĐ-CP!';
        END IF;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_protect_auditlog ON "audit_log";
CREATE TRIGGER trg_protect_auditlog
BEFORE UPDATE OR DELETE ON "audit_log"
FOR EACH ROW
EXECUTE FUNCTION protect_auditlog_immutability();


-- ----------------------------------------------------------------------------
-- 2. BẢO VỆ CHỐNG XÓA VẬT LÝ DỮ LIỆU GIAO DỊCH TÀI CHÍNH (TRANSACTION)
-- Căn cứ: Điều 41 Luật Kế toán 2015 & NĐ 174/2016/NĐ-CP — Lưu trữ tối thiểu 5 năm.
-- Cơ chế: Nghiêm cấm DELETE vật lý trong vòng 5 năm; bắt buộc dùng xóa mềm (Deleted_at).
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION protect_transaction_hard_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- Chặn xóa vật lý giao dịch nếu chưa quá 5 năm (1825 ngày)
    IF OLD."DateTransaction" > (NOW() - INTERVAL '5 years') THEN
        RAISE EXCEPTION 'BẢO MẬT: Nghiêm cấm xóa vật lý giao dịch tài chính trước 5 năm theo Luật Kế toán 2015! Hãy sử dụng cơ chế xóa mềm (Deleted_at).';
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_protect_transaction ON "transaction";
CREATE TRIGGER trg_protect_transaction
BEFORE DELETE ON "transaction"
FOR EACH ROW
EXECUTE FUNCTION protect_transaction_hard_delete();
