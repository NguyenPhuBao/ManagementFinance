-- FlowMoney: lược đồ CSDL PostgreSQL đầy đủ cho bản cài mới.
-- Cài mới: chạy cả tệp một lần trên CSDL trống. Không chạy lại trên CSDL đã có dữ liệu.
-- Thay đổi về sau: viết database/N_*.sql, áp lên CSDL đang chạy, rồi gộp vào đây bằng scripts/gop-migration.js.
-- Nguồn: lược đồ public của CSDL vận hành (PostgreSQL 17.6), đọc ngày 2026-11-23, gồm cả các thay đổi
-- đã áp từ database/New_Database.sql và migration 5..56. Dữ liệu cấu hình kèm theo: role, feature, account_type_permission, aiops_setting.
-- Tài khoản quản trị gốc tạo sau bằng scripts/seed_root_admin.js.

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS public;


--
-- Name: check_bank_account_is_encrypted(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_bank_account_is_encrypted() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
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
$_$;


--
-- Name: check_phone_is_encrypted(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_phone_is_encrypted() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
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
$_$;


--
-- Name: fn_payment_ledger_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_payment_ledger_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'Bảng % là sổ chứng từ thanh toán: cấm % (quy định lưu trữ chứng từ)', TG_TABLE_NAME, TG_OP
    USING ERRCODE = 'P0001';
END;
$$;


--
-- Name: fn_protect_payment_order(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_protect_payment_order() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Đơn thanh toán % là chứng từ: cấm xoá', OLD."order_code" USING ERRCODE = 'P0001';
  END IF;
  IF OLD."status" = 'REFUNDED' THEN
    RAISE EXCEPTION 'Đơn % đã hoàn tiền: khoá, không được sửa', OLD."order_code" USING ERRCODE = 'P0001';
  END IF;
  IF NEW."id" IS DISTINCT FROM OLD."id"
     OR NEW."idaccount" IS DISTINCT FROM OLD."idaccount"
     OR NEW."order_code" IS DISTINCT FROM OLD."order_code"
     OR NEW."package_type" IS DISTINCT FROM OLD."package_type"
     OR NEW."amount" IS DISTINCT FROM OLD."amount"
     OR NEW."currency" IS DISTINCT FROM OLD."currency"
     OR NEW."is_template" IS DISTINCT FROM OLD."is_template"
     OR NEW."created_at" IS DISTINCT FROM OLD."created_at"
     OR (OLD."recognition_code" IS NOT NULL AND NEW."recognition_code" IS DISTINCT FROM OLD."recognition_code") THEN
    RAISE EXCEPTION 'Đơn %: cấm sửa trường gốc của chứng từ', OLD."order_code" USING ERRCODE = 'P0001';
  END IF;
  IF (OLD."paid_at" IS NOT NULL AND NEW."paid_at" IS DISTINCT FROM OLD."paid_at")
     OR (OLD."amount_received" <> 0 AND NEW."amount_received" IS DISTINCT FROM OLD."amount_received")
     OR (OLD."refunded_at" IS NOT NULL AND NEW."refunded_at" IS DISTINCT FROM OLD."refunded_at")
     OR (OLD."refunded_amount" IS NOT NULL AND NEW."refunded_amount" IS DISTINCT FROM OLD."refunded_amount")
     OR (OLD."refund_proof" IS NOT NULL AND NEW."refund_proof" IS DISTINCT FROM OLD."refund_proof")
     OR (OLD."hidden_at" IS NOT NULL AND NEW."hidden_at" IS DISTINCT FROM OLD."hidden_at") THEN
    RAISE EXCEPTION 'Đơn %: trường tiền / thời điểm chỉ ghi một lần', OLD."order_code" USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: fn_protect_root_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_protect_root_admin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  root_email CONSTANT TEXT := 'admin@wealthcommand.com';
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF lower(OLD."Email") = root_email THEN
      RAISE EXCEPTION 'ROOT_ACCOUNT_PROTECTED: không được xóa tài khoản quản trị gốc' USING ERRCODE = 'P0001';
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' AND lower(OLD."Email") = root_email THEN
    IF NEW."Email" IS DISTINCT FROM OLD."Email"
       OR NEW."Username" IS DISTINCT FROM OLD."Username"
       OR NEW."Idrole" IS DISTINCT FROM OLD."Idrole"
       OR NEW."Status" IS DISTINCT FROM 'Active'
       OR NEW."Delete_at" IS NOT NULL THEN
      RAISE EXCEPTION 'ROOT_ACCOUNT_PROTECTED: không được khóa, xóa hoặc đổi định danh / vai của tài khoản quản trị gốc' USING ERRCODE = 'P0001';
    END IF;
  END IF;

  IF lower(NEW."Email") = root_email AND NEW."Idrole" IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION 'ROOT_ACCOUNT_PROTECTED: email này dành riêng cho tài khoản quản trị gốc' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: FUNCTION fn_protect_root_admin(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_protect_root_admin() IS 'Bảo vệ tài khoản quản trị gốc (email admin@wealthcommand.com): không xóa, không khóa, không đổi định danh / vai';


--
-- Name: protect_auditlog_immutability(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_auditlog_immutability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: protect_data_incident_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_data_incident_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'Sổ sự cố dữ liệu là hồ sơ pháp lý: không được xóa (data_incident %)', OLD."code";
END;
$$;


--
-- Name: protect_policy_immutability(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_policy_immutability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'BẢO MẬT: % chỉ được thêm, không được sửa (bằng chứng chính sách / đồng ý).', TG_TABLE_NAME;
END;
$$;


--
-- Name: protect_privacy_policy_content(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_privacy_policy_content() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW."version" IS DISTINCT FROM OLD."version"
     OR NEW."title" IS DISTINCT FROM OLD."title"
     OR NEW."content" IS DISTINCT FROM OLD."content"
     OR NEW."published_at" IS DISTINCT FROM OLD."published_at"
     -- published_by chỉ được về NULL (khoá ngoại ON DELETE SET NULL)
     OR (NEW."published_by" IS DISTINCT FROM OLD."published_by" AND NEW."published_by" IS NOT NULL)
     -- document_id / doc_version: chỉ được gán một lần (lúc chuyển dữ liệu cũ)
     OR (OLD."document_id" IS NOT NULL AND NEW."document_id" IS DISTINCT FROM OLD."document_id")
     OR (OLD."doc_version" IS NOT NULL AND NEW."doc_version" IS DISTINCT FROM OLD."doc_version") THEN
    RAISE EXCEPTION 'BẢO MẬT: privacy_policy chỉ được đổi trạng thái; nội dung chính sách đã đăng không được sửa.';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: protect_transaction_hard_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_transaction_hard_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Chặn xóa vật lý giao dịch nếu chưa quá 5 năm (1825 ngày)
    IF OLD."DateTransaction" > (NOW() - INTERVAL '5 years') THEN
        RAISE EXCEPTION 'BẢO MẬT: Nghiêm cấm xóa vật lý giao dịch tài chính trước 5 năm theo Luật Kế toán 2015! Hãy sử dụng cơ chế xóa mềm (Deleted_at).';
    END IF;

    RETURN OLD;
END;
$$;


--
-- Name: set_server_update_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_server_update_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW."Server_update_at" = (now() AT TIME ZONE 'UTC');
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account (
    "Idaccount" integer NOT NULL,
    "Idrole" integer NOT NULL,
    "Email" character varying(100) NOT NULL,
    "Username" character varying(255) NOT NULL,
    "Password" character varying(255) NOT NULL,
    "Status" character varying(20) DEFAULT 'Active'::character varying NOT NULL,
    "Type" character varying(7) DEFAULT 'Basic'::character varying NOT NULL,
    "Create_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Update_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Delete_at" timestamp(6) without time zone,
    "Reason_Inactive" text,
    "Countdown" integer,
    premium_expires_at timestamp(6) without time zone,
    pin_hash character varying(255),
    is_first_login boolean DEFAULT true NOT NULL,
    created_by_admin_id integer,
    CONSTRAINT ck_account_status CHECK ((("Status")::text = ANY ((ARRAY['Active'::character varying, 'Inactive'::character varying, 'PendingDelete'::character varying, 'Deleted'::character varying])::text[])))
);


--
-- Name: COLUMN account."Countdown"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account."Countdown" IS 'Số ngày đếm ngược chờ xóa tài khoản (mặc định 30 khi chuyển sang PendingDelete, null khi Active/Deleted)';


--
-- Name: account_Idaccount_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."account_Idaccount_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_Idaccount_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."account_Idaccount_seq" OWNED BY public.account."Idaccount";


--
-- Name: account_device_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_device_history (
    id bigint NOT NULL,
    idaccount integer NOT NULL,
    device_name character varying(150) NOT NULL,
    ip_address character varying(256) NOT NULL,
    user_agent text,
    first_seen_at timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    last_active_at timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    ip_encrypted text,
    ip_hash character varying(64)
);


--
-- Name: TABLE account_device_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.account_device_history IS 'Bảng lưu vết lịch sử thiết bị và địa chỉ IP người dùng đăng nhập/truy cập (Append-only khi có thay đổi)';


--
-- Name: COLUMN account_device_history.device_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_device_history.device_name IS 'Tên thiết bị người dùng (ví dụ: Samsung Galaxy S24, iPhone 15 Pro, Web Desktop)';


--
-- Name: COLUMN account_device_history.ip_address; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_device_history.ip_address IS 'IP đã che (a.b.xx.xx), chỉ để hiển thị';


--
-- Name: COLUMN account_device_history.first_seen_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_device_history.first_seen_at IS 'Thời điểm phát hiện lần đầu tiên thiết bị/IP này truy cập';


--
-- Name: COLUMN account_device_history.last_active_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_device_history.last_active_at IS 'Thời điểm gần nhất thiết bị/IP này gửi yêu cầu';


--
-- Name: COLUMN account_device_history.ip_encrypted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_device_history.ip_encrypted IS 'IP đầy đủ mã hóa AES-256-GCM; chỉ giải khi admin xác thực PIN; xóa sau IP_RETENTION_DAYS';


--
-- Name: COLUMN account_device_history.ip_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_device_history.ip_hash IS 'HMAC-SHA256(BLIND_INDEX_SECRET, IP) để so khớp và tra cứu; xóa cùng ip_encrypted';


--
-- Name: account_device_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_device_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_device_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_device_history_id_seq OWNED BY public.account_device_history.id;


--
-- Name: account_type_permission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_type_permission (
    id integer NOT NULL,
    account_type character varying(20) NOT NULL,
    feature_id character varying(50) NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    limit_value integer,
    created_at timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    scope_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    downgrade_policy character varying(50) DEFAULT 'BLOCK_CREATE'::character varying NOT NULL,
    CONSTRAINT ck_perm_account_type CHECK (((account_type)::text = ANY ((ARRAY['Basic'::character varying, 'Premium'::character varying])::text[])))
);


--
-- Name: account_type_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_type_permission_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_type_permission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_type_permission_id_seq OWNED BY public.account_type_permission.id;


--
-- Name: admin_preference; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_preference (
    idaccount integer NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_admin_preference_settings_object CHECK ((jsonb_typeof(settings) = 'object'::text))
);


--
-- Name: TABLE admin_preference; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.admin_preference IS 'Cài đặt cá nhân của từng tài khoản quản trị trên Admin-web (giao diện, thông báo, kết nối, tự khoá)';


--
-- Name: COLUMN admin_preference.settings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admin_preference.settings IS 'Chỉ các khoá Backend cho phép: theme, tableDensity, soundEnabled, toastDuration, showUnreadBadge, metricsInterval, autoLockMinutes';


--
-- Name: aiops_account_quarantine; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aiops_account_quarantine (
    id character varying(64) NOT NULL,
    idaccount integer,
    username character varying(255) NOT NULL,
    status character varying(20) DEFAULT 'TEMPORARY'::character varying NOT NULL,
    reason text NOT NULL,
    violation_vector character varying(20),
    threat_score_at_ban integer,
    hits integer DEFAULT 1 NOT NULL,
    banned_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    unblocked_at timestamp with time zone,
    banned_by character varying(100) DEFAULT 'AIOps Sentinel'::character varying NOT NULL,
    unblocked_by character varying(100),
    unblock_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: aiops_incident; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aiops_incident (
    id character varying(256) NOT NULL,
    code character varying(50) NOT NULL,
    vector character varying(20) NOT NULL,
    severity character varying(10) NOT NULL,
    message text NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    actor_type character varying(30) NOT NULL,
    actor_identity character varying(256) NOT NULL,
    actor_hash character varying(256) NOT NULL,
    user_id integer,
    username character varying(255),
    user_agent text,
    target_endpoint character varying(255),
    metric_current numeric,
    metric_baseline numeric,
    metric_unit character varying(50),
    mitigation_taken text,
    root_cause_diagnosis text,
    hits integer DEFAULT 1 NOT NULL,
    first_detected_at timestamp(6) without time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp(6) without time zone DEFAULT now() NOT NULL,
    mitigated_at timestamp(6) without time zone,
    actor_role character varying(50)
);


--
-- Name: aiops_ip_quarantine; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aiops_ip_quarantine (
    id character varying(64) NOT NULL,
    ip_hash character varying(64) NOT NULL,
    masked_ip character varying(45) NOT NULL,
    raw_ip text,
    status character varying(20) DEFAULT 'TEMPORARY'::character varying NOT NULL,
    reason text NOT NULL,
    violation_vector character varying(20),
    threat_score_at_ban integer,
    hits integer DEFAULT 1 NOT NULL,
    banned_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    unblocked_at timestamp with time zone,
    banned_by character varying(100) DEFAULT 'AIOps Sentinel'::character varying NOT NULL,
    unblocked_by character varying(100),
    unblock_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_aiops_ip_quarantine_no_permanent CHECK (((status)::text = ANY ((ARRAY['TEMPORARY'::character varying, 'UNLOCKED'::character varying])::text[]))),
    CONSTRAINT chk_aiops_ip_quarantine_temp_has_expiry CHECK ((((status)::text <> 'TEMPORARY'::text) OR (expires_at IS NOT NULL)))
);


--
-- Name: COLUMN aiops_ip_quarantine.raw_ip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.aiops_ip_quarantine.raw_ip IS 'IP đầy đủ mã hóa AES-256-GCM (enc:...); xóa sau IP_RETENTION_DAYS';


--
-- Name: aiops_metric_snapshot; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aiops_metric_snapshot (
    id character varying(64) NOT NULL,
    threat_score integer DEFAULT 0 NOT NULL,
    auth_score integer DEFAULT 0 NOT NULL,
    traffic_score integer DEFAULT 0 NOT NULL,
    exploit_score integer DEFAULT 0 NOT NULL,
    resource_score integer DEFAULT 0 NOT NULL,
    requests_per_min integer DEFAULT 0 NOT NULL,
    cpu_percent integer DEFAULT 0 NOT NULL,
    ram_percent integer DEFAULT 0 NOT NULL,
    event_loop_lag_ms integer DEFAULT 0 NOT NULL,
    is_anomaly boolean DEFAULT false NOT NULL,
    recorded_at timestamp(6) without time zone DEFAULT now() NOT NULL
);


--
-- Name: aiops_quarantine_incident_link; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aiops_quarantine_incident_link (
    id integer NOT NULL,
    ip_quarantine_id character varying(64) NOT NULL,
    account_quarantine_id character varying(64) NOT NULL,
    ip_hash character varying(64) NOT NULL,
    username character varying(255) NOT NULL,
    reason text NOT NULL,
    incident_code character varying(50),
    detected_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: aiops_quarantine_incident_link_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.aiops_quarantine_incident_link_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: aiops_quarantine_incident_link_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.aiops_quarantine_incident_link_id_seq OWNED BY public.aiops_quarantine_incident_link.id;


--
-- Name: aiops_setting; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aiops_setting (
    key character varying(64) NOT NULL,
    value text NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    "Idlog" integer NOT NULL,
    "Idaccount" integer NOT NULL,
    "Request" character varying(200) NOT NULL,
    "TimeReq" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "TimeRes" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Req_status" character varying(12) DEFAULT 'Pass'::character varying NOT NULL,
    "Reason" character varying(200),
    "Action" character varying(255),
    CONSTRAINT ck_auditlog_req_status CHECK ((("Req_status")::text = ANY (ARRAY[('Accepted'::character varying)::text, ('Rejected'::character varying)::text, ('Interrupted'::character varying)::text, ('Pending'::character varying)::text, ('Processing'::character varying)::text, ('Pass'::character varying)::text, ('Fail'::character varying)::text])))
);


--
-- Name: audit_log_Idlog_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."audit_log_Idlog_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_log_Idlog_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."audit_log_Idlog_seq" OWNED BY public.audit_log."Idlog";


--
-- Name: bank_account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bank_account (
    "Id_bank_account" character varying(36) NOT NULL,
    "Idaccount" integer NOT NULL,
    "Id_casso_account" character varying(100) NOT NULL,
    "Account_number" character varying(256) NOT NULL,
    "Account_name" character varying(255) NOT NULL,
    "Bank_name" character varying(100) NOT NULL,
    "Balance" numeric(15,2) DEFAULT 0 NOT NULL,
    "Connect_status" character varying(12) DEFAULT 'Active'::character varying NOT NULL,
    "Create_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    "Update_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    "Delete_at" timestamp(6) without time zone,
    "Account_number_hash" character varying(256)
);


--
-- Name: bill; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bill (
    "Idbill" character varying(36) NOT NULL,
    "Idaccount" integer NOT NULL,
    "Idwallet" character varying(36) NOT NULL,
    "Idcategory" character varying(36) NOT NULL,
    "Name" character varying(100) NOT NULL,
    "Amount" numeric(15,2) NOT NULL,
    "Due_date" timestamp(6) without time zone NOT NULL,
    "Pay_status" character varying(7) DEFAULT 'Pending'::character varying NOT NULL,
    "Recurrence" boolean DEFAULT false NOT NULL,
    "Time_recurrence" character varying(7),
    "Icon" character varying(20) DEFAULT 'receipt'::character varying,
    "Color" character varying(20) DEFAULT '#4CAF50'::character varying,
    "Note" text,
    "Create_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Update_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Delete_at" timestamp(6) without time zone,
    "Start_date" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Time_notification" character varying(7) DEFAULT '3'::character varying,
    "Previous_bill_id" character varying(36),
    "Period_end" date,
    "Auto_pay" boolean DEFAULT false NOT NULL,
    "Anchor_day" smallint,
    "Server_update_at" timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    CONSTRAINT chk_bill_anchor_day CHECK ((("Anchor_day" IS NULL) OR (("Anchor_day" >= 1) AND ("Anchor_day" <= 31)))),
    CONSTRAINT chk_bill_pay_status CHECK ((("Pay_status")::text = ANY ((ARRAY['Pending'::character varying, 'Payed'::character varying, 'Overdue'::character varying, 'Skipped'::character varying])::text[])))
);


--
-- Name: broadcast_notification; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.broadcast_notification (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    message text NOT NULL,
    level character varying(20) DEFAULT 'INFO'::character varying NOT NULL,
    sender_username character varying(100) DEFAULT 'admin'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: broadcast_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.broadcast_notification_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: broadcast_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.broadcast_notification_id_seq OWNED BY public.broadcast_notification.id;


--
-- Name: budget; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.budget (
    "Idbudget" character varying(36) NOT NULL,
    "Idaccount" integer NOT NULL,
    "Idcategory" character varying(36),
    "TotalAmount" numeric(15,2) NOT NULL,
    "Spent" numeric(15,2) DEFAULT 0 NOT NULL,
    "OverSpending" character varying(7) DEFAULT 'Over'::character varying NOT NULL,
    "OverAmount" numeric(15,2),
    "Start" timestamp(6) without time zone NOT NULL,
    "End" timestamp(6) without time zone,
    "Recurrence" boolean DEFAULT false NOT NULL,
    "Time_recurrence" character varying(7),
    "Note" text,
    "Create_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Update_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Delete_at" timestamp(6) without time zone,
    "Nexttime_recurrence" timestamp(6) without time zone,
    "Threshold_Warning_Amount" numeric(15,2),
    "Threshold_Warning_Percent" numeric(15,2),
    "Server_update_at" timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    "Idhousehold" integer
);


--
-- Name: category; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category (
    "Idcategory" character varying(36) NOT NULL,
    "Create_by" integer DEFAULT 1 NOT NULL,
    "NameCategory" character varying(200) NOT NULL,
    "Classify" character varying(7) NOT NULL,
    "Is_default" boolean DEFAULT false NOT NULL,
    "Is_group" boolean DEFAULT false NOT NULL,
    "Idgroup" character varying(36),
    "Keyword" text,
    "Icon" character varying(20),
    "Create_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    "Update_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    "Delete_at" timestamp(6) without time zone,
    "Color" character varying(9),
    "Server_update_at" timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    "Idhousehold" integer
);


--
-- Name: data_export_request; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_export_request (
    id character varying(36) NOT NULL,
    idaccount integer NOT NULL,
    status character varying(20) DEFAULT 'PROCESSING'::character varying NOT NULL,
    json_ref text,
    csv_ref text,
    requested_at timestamp(6) without time zone DEFAULT now() NOT NULL,
    ready_at timestamp(6) without time zone,
    expires_at timestamp(6) without time zone,
    email_sent_at timestamp(6) without time zone,
    error text,
    CONSTRAINT ck_data_export_status CHECK (((status)::text = ANY ((ARRAY['PROCESSING'::character varying, 'READY'::character varying, 'EXPIRED'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: TABLE data_export_request; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.data_export_request IS 'Yêu cầu bản sao dữ liệu cá nhân; tệp ở Supabase Storage bucket data-exports, hết hạn sau 24 giờ';


--
-- Name: data_incident; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_incident (
    id integer NOT NULL,
    code character varying(20) NOT NULL,
    title character varying(200) NOT NULL,
    description text NOT NULL,
    source character varying(20) DEFAULT 'OTHER'::character varying NOT NULL,
    detected_at timestamp(6) without time zone NOT NULL,
    occurred_at timestamp(6) without time zone,
    data_types text,
    sensitive boolean DEFAULT false NOT NULL,
    affected_users integer,
    affected_records integer,
    consequences text,
    measures text,
    contact text,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    contained_at timestamp(6) without time zone,
    authority_reported_at timestamp(6) without time zone,
    authority_report_ref text,
    late_reason text,
    report_not_required boolean DEFAULT false NOT NULL,
    no_report_reason text,
    users_notified_at timestamp(6) without time zone,
    root_cause text,
    closed_at timestamp(6) without time zone,
    created_by integer,
    updated_by integer,
    created_at timestamp(6) without time zone DEFAULT now() NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_data_incident_source CHECK (((source)::text = ANY ((ARRAY['AIOPS'::character varying, 'AUDIT_LOG'::character varying, 'USER_REPORT'::character varying, 'PROCESSOR'::character varying, 'OTHER'::character varying])::text[]))),
    CONSTRAINT ck_data_incident_status CHECK (((status)::text = ANY ((ARRAY['OPEN'::character varying, 'CONTAINED'::character varying, 'REPORTED'::character varying, 'CLOSED'::character varying])::text[])))
);


--
-- Name: TABLE data_incident; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.data_incident IS 'Sổ sự cố dữ liệu cá nhân; hạn báo cơ quan chuyên trách = detected_at + 72 giờ; không được xóa';


--
-- Name: data_incident_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.data_incident_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: data_incident_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.data_incident_id_seq OWNED BY public.data_incident.id;


--
-- Name: feature; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feature (
    id character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    type character varying(20) DEFAULT 'TOGGLE'::character varying NOT NULL,
    category_group character varying(50) DEFAULT 'Chức năng'::character varying NOT NULL,
    default_limit integer,
    default_enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    scope_schema jsonb DEFAULT '{}'::jsonb NOT NULL,
    default_downgrade_policy character varying(50) DEFAULT 'BLOCK_CREATE'::character varying NOT NULL,
    CONSTRAINT ck_feature_type CHECK (((type)::text = ANY ((ARRAY['LIMIT'::character varying, 'TOGGLE'::character varying])::text[])))
);


--
-- Name: goal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.goal (
    "Idgoal" character varying(36) NOT NULL,
    "Idaccount" integer NOT NULL,
    "Idwallet" character varying(36),
    "Name" character varying(100) NOT NULL,
    "Target_amount" numeric(15,2) NOT NULL,
    "Current_amount" numeric(15,2) DEFAULT 0 NOT NULL,
    "Target_date" timestamp(6) without time zone NOT NULL,
    "Status_complete" character varying(20) DEFAULT 'False'::character varying NOT NULL,
    "Icon" character varying(20) DEFAULT 'flag'::character varying,
    "Color" character varying(20) DEFAULT '#4CAF50'::character varying,
    "Note" text,
    "Create_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Update_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Delete_at" timestamp(6) without time zone,
    "Cycle_take_money" character varying(7),
    "Recurrence" boolean DEFAULT false NOT NULL,
    "Start_date" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Time_cycle_take_money" timestamp(6) without time zone,
    "Time_recurrence" character varying(7),
    auto_deposit_amount numeric(18,2),
    auto_deposit_wallet_id character varying(36),
    auto_deposit_last_run timestamp without time zone,
    "Priority" integer,
    "Server_update_at" timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    "Idhousehold" integer
);


--
-- Name: household; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.household (
    "Idhousehold" integer NOT NULL,
    "Name" character varying(100) NOT NULL,
    "Owner_idaccount" integer NOT NULL,
    "Status" character varying(10) DEFAULT 'Active'::character varying NOT NULL,
    "Max_members" smallint DEFAULT 6 NOT NULL,
    "Max_shared_wallets" smallint DEFAULT 10 NOT NULL,
    "Contribution_due_day" smallint DEFAULT 5 NOT NULL,
    "Create_at" timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    "Update_at" timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    "Delete_at" timestamp(6) without time zone,
    CONSTRAINT chk_household_due_day CHECK ((("Contribution_due_day" >= 1) AND ("Contribution_due_day" <= 31))),
    CONSTRAINT chk_household_max_members CHECK ((("Max_members" >= 2) AND ("Max_members" <= 20))),
    CONSTRAINT chk_household_status CHECK ((("Status")::text = ANY ((ARRAY['Active'::character varying, 'ReadOnly'::character varying, 'Dissolved'::character varying])::text[])))
);


--
-- Name: household_Idhousehold_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."household_Idhousehold_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: household_Idhousehold_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."household_Idhousehold_seq" OWNED BY public.household."Idhousehold";


--
-- Name: household_invite; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.household_invite (
    "Code" character varying(8) NOT NULL,
    "Idhousehold" integer NOT NULL,
    "Role" character varying(7) NOT NULL,
    "Created_by" integer NOT NULL,
    "Email" character varying(100),
    "Invitee_idaccount" integer,
    "Create_at" timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    "Expires_at" timestamp(6) without time zone NOT NULL,
    "Used_by" integer,
    "Used_at" timestamp(6) without time zone,
    "Revoked_at" timestamp(6) without time zone,
    "Declined_at" timestamp(6) without time zone,
    CONSTRAINT chk_household_invite_role CHECK ((("Role")::text = ANY ((ARRAY['Member'::character varying, 'Viewer'::character varying])::text[])))
);


--
-- Name: household_member; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.household_member (
    "Id" integer NOT NULL,
    "Idhousehold" integer NOT NULL,
    "Idaccount" integer NOT NULL,
    "Role" character varying(7) NOT NULL,
    "Joined_at" timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    "Left_at" timestamp(6) without time zone,
    CONSTRAINT chk_household_member_role CHECK ((("Role")::text = ANY ((ARRAY['Owner'::character varying, 'Member'::character varying, 'Viewer'::character varying])::text[])))
);


--
-- Name: household_member_Id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."household_member_Id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: household_member_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."household_member_Id_seq" OWNED BY public.household_member."Id";


--
-- Name: maintenance_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.maintenance_history (
    id integer NOT NULL,
    type character varying(20) DEFAULT 'EMERGENCY'::character varying NOT NULL,
    reason text NOT NULL,
    activated_by character varying(100) NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    scheduled_end_at timestamp with time zone,
    ended_at timestamp with time zone,
    status character varying(20) DEFAULT 'ONGOING'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    actual_duration_seconds integer
);


--
-- Name: COLUMN maintenance_history.actual_duration_seconds; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.maintenance_history.actual_duration_seconds IS 'Thời lượng thực tế của phiên bảo trì hoặc nâng cấp tính bằng giây';


--
-- Name: maintenance_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.maintenance_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: maintenance_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.maintenance_history_id_seq OWNED BY public.maintenance_history.id;


--
-- Name: otp_code; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.otp_code (
    "Id_otp" integer NOT NULL,
    "Idaccount" integer,
    "Email" character varying(100) NOT NULL,
    code_hash character varying(512) NOT NULL,
    purpose character varying(20) NOT NULL,
    is_used boolean DEFAULT false NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: otp_code_Id_otp_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."otp_code_Id_otp_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: otp_code_Id_otp_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."otp_code_Id_otp_seq" OWNED BY public.otp_code."Id_otp";


--
-- Name: payment_order; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_order (
    id character varying(36) NOT NULL,
    idaccount integer NOT NULL,
    order_code bigint NOT NULL,
    package_type character varying(30) DEFAULT 'PREMIUM_1_MONTH'::character varying NOT NULL,
    amount numeric(15,2) DEFAULT 49000.00 NOT NULL,
    currency character varying(3) DEFAULT 'VND'::character varying NOT NULL,
    status character varying(25) DEFAULT 'PENDING'::character varying NOT NULL,
    checkout_url text,
    payment_link_id character varying(100),
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    paid_at timestamp(6) without time zone,
    expired_at timestamp(6) without time zone,
    recognition_code character varying(10),
    amount_received numeric(15,2) DEFAULT 0.00,
    fee numeric(15,2) DEFAULT 0.00,
    transfer_content character varying(100),
    refunded_at timestamp(6) without time zone,
    refunded_amount numeric(15,2),
    refund_reason text,
    refund_proof text,
    is_template boolean DEFAULT false NOT NULL,
    qr_url text,
    hidden_at timestamp(6) without time zone,
    hidden_by integer
);


--
-- Name: COLUMN payment_order.is_template; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.payment_order.is_template IS 'Cờ đánh dấu đơn hàng mẫu (TRUE) do Admin thử nghiệm, hoặc đơn thật (FALSE) của người dùng';


--
-- Name: COLUMN payment_order.qr_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.payment_order.qr_url IS 'URL mã QR thanh toán VietQR / PayOS, được lưu bền vững khi đơn PENDING và xóa (SET NULL) khi đơn hoàn tất hoặc hết hạn';


--
-- Name: payment_transaction; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_transaction (
    id character varying(36) NOT NULL,
    order_id character varying(36) NOT NULL,
    idaccount integer NOT NULL,
    payos_transaction_id character varying(100) NOT NULL,
    amount numeric(15,2) NOT NULL,
    bank_code character varying(50),
    transaction_time timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    signature_verified boolean DEFAULT true NOT NULL,
    raw_webhook_hash character varying(256),
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    direction character varying(3) DEFAULT 'IN'::character varying NOT NULL,
    source character varying(12),
    receiving_account_number character varying(50),
    payment_link_id character varying(64),
    transfer_description character varying(255),
    currency character varying(10),
    counter_account_bank_id character varying(20),
    counter_account_bank_name character varying(255),
    counter_account_name character varying(512),
    counter_account_number character varying(512),
    raw_payload text,
    created_by integer,
    proof text,
    CONSTRAINT ck_payment_transaction_direction CHECK (((direction)::text = ANY ((ARRAY['IN'::character varying, 'OUT'::character varying])::text[]))),
    CONSTRAINT ck_payment_transaction_source CHECK (((source IS NULL) OR ((source)::text = ANY ((ARRAY['WEBHOOK'::character varying, 'PAYOS_API'::character varying, 'ADMIN_REFUND'::character varying])::text[]))))
);


--
-- Name: COLUMN payment_transaction.payos_transaction_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.payment_transaction.payos_transaction_id IS 'Mã giao dịch ngân hàng (PayOS reference / mã chuyển khoản hoàn tiền). Bắt buộc, duy nhất, không thay bằng mã đơn.';


--
-- Name: COLUMN payment_transaction.counter_account_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.payment_transaction.counter_account_number IS 'Số tài khoản người chuyển (tiền vào) - mã hoá AES-256-GCM';


--
-- Name: COLUMN payment_transaction.raw_payload; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.payment_transaction.raw_payload IS 'Webhook gốc có chữ ký PayOS hoặc phản hồi API PayOS - mã hoá AES-256-GCM';


--
-- Name: payment_webhook_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_webhook_log (
    id bigint NOT NULL,
    received_at timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    order_code bigint,
    reference character varying(100),
    amount numeric(15,2),
    signature_valid boolean NOT NULL,
    handled_as character varying(40),
    payload text NOT NULL
);


--
-- Name: TABLE payment_webhook_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.payment_webhook_log IS 'Nhật ký mọi webhook PayOS có chữ ký hợp lệ (payload mã hoá). Append-only.';


--
-- Name: payment_webhook_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_webhook_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_webhook_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_webhook_log_id_seq OWNED BY public.payment_webhook_log.id;


--
-- Name: policy_acceptance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.policy_acceptance (
    id bigint NOT NULL,
    idaccount integer NOT NULL,
    policy_version integer NOT NULL,
    accepted_at timestamp(6) without time zone DEFAULT now() NOT NULL,
    ip_hash character varying(64),
    device_name character varying(150),
    user_agent text
);


--
-- Name: TABLE policy_acceptance; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.policy_acceptance IS 'Bằng chứng người dùng đồng ý từng phiên bản chính sách (Nghị định 356/2025 Điều 6); chỉ thêm';


--
-- Name: COLUMN policy_acceptance.ip_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.policy_acceptance.ip_hash IS 'HMAC-SHA256(BLIND_INDEX_SECRET, IP) lúc đồng ý; không lưu IP';


--
-- Name: policy_acceptance_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.policy_acceptance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: policy_acceptance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.policy_acceptance_id_seq OWNED BY public.policy_acceptance.id;


--
-- Name: policy_document; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.policy_document (
    id integer NOT NULL,
    title character varying(200) NOT NULL,
    created_at timestamp(6) without time zone DEFAULT now() NOT NULL,
    created_by integer
);


--
-- Name: TABLE policy_document; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.policy_document IS 'Mỗi dòng là một chính sách; các phiên bản nằm ở privacy_policy (document_id)';


--
-- Name: policy_document_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.policy_document_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: policy_document_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.policy_document_id_seq OWNED BY public.policy_document.id;


--
-- Name: privacy_policy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.privacy_policy (
    version integer NOT NULL,
    title character varying(200) NOT NULL,
    content text NOT NULL,
    published_at timestamp(6) without time zone DEFAULT now() NOT NULL,
    published_by integer,
    document_id integer NOT NULL,
    doc_version integer NOT NULL,
    status character varying(10) DEFAULT 'INACTIVE'::character varying NOT NULL,
    status_changed_at timestamp(6) without time zone,
    status_changed_by integer,
    CONSTRAINT ck_privacy_policy_doc_version_positive CHECK (((doc_version IS NULL) OR (doc_version > 0))),
    CONSTRAINT ck_privacy_policy_status CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'INACTIVE'::character varying])::text[]))),
    CONSTRAINT ck_privacy_policy_version_positive CHECK ((version > 0))
);


--
-- Name: TABLE privacy_policy; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.privacy_policy IS 'Phiên bản chính sách; nội dung đã đăng không sửa; chỉ đổi trạng thái ACTIVE / INACTIVE; mỗi chính sách tối đa một bản ACTIVE';


--
-- Name: COLUMN privacy_policy.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.privacy_policy.version IS 'Mã nội bộ của phiên bản (policy_acceptance tham chiếu); số phiên bản hiển thị là doc_version';


--
-- Name: COLUMN privacy_policy.doc_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.privacy_policy.doc_version IS 'Số phiên bản trong một chính sách (v1, v2…)';


--
-- Name: refreshtoken; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.refreshtoken (
    "Idtoken" integer NOT NULL,
    "Token_hash" character varying(512) NOT NULL,
    "Idaccount" integer NOT NULL,
    "Idrole" integer DEFAULT 2 NOT NULL,
    "Expired" timestamp(6) without time zone NOT NULL,
    "Status" boolean DEFAULT false NOT NULL,
    "Device_name" character varying(100),
    "IP_address" character varying(256),
    "User_agent" text,
    "Create_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Update_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: COLUMN refreshtoken."IP_address"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.refreshtoken."IP_address" IS 'Địa chỉ IP đã che mờ (Masked IP) hoặc Hash (dung lượng tối đa 256 ký tự)';


--
-- Name: refreshtoken_Idtoken_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."refreshtoken_Idtoken_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refreshtoken_Idtoken_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."refreshtoken_Idtoken_seq" OWNED BY public.refreshtoken."Idtoken";


--
-- Name: role; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role (
    "Idrole" integer NOT NULL,
    "Rolename" character varying(40) NOT NULL,
    "Description" text
);


--
-- Name: role_Idrole_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."role_Idrole_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: role_Idrole_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."role_Idrole_seq" OWNED BY public.role."Idrole";


--
-- Name: server_session; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.server_session (
    id bigint NOT NULL,
    instance_id character varying(100) NOT NULL,
    version character varying(64),
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    ended_at timestamp with time zone,
    end_reason character varying(20),
    CONSTRAINT ck_server_session_end_reason CHECK (((end_reason IS NULL) OR ((end_reason)::text = ANY ((ARRAY['GRACEFUL'::character varying, 'UNKNOWN'::character varying])::text[]))))
);


--
-- Name: TABLE server_session; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.server_session IS 'Phiên chạy của tiến trình Backend, phục vụ tính độ khả dụng theo kỳ';


--
-- Name: COLUMN server_session.end_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.server_session.end_reason IS 'GRACEFUL: tắt có chủ đích (SIGTERM/SIGINT); UNKNOWN: không kịp đóng (sập), đóng ở lần khởi động sau';


--
-- Name: server_session_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.server_session_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: server_session_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.server_session_id_seq OWNED BY public.server_session.id;


--
-- Name: transaction; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transaction (
    "Idtran" character varying(36) NOT NULL,
    "Idaccount" integer NOT NULL,
    "Idwallet" character varying(36) NOT NULL,
    "Idcategory" character varying(36),
    "Amount" numeric(15,2) NOT NULL,
    "Type" character varying(20) NOT NULL,
    "Provider" character varying(40) DEFAULT 'Manual'::character varying NOT NULL,
    "Note" text,
    "Images" text,
    "DateTransaction" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Update_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Deleted_at" timestamp(6) without time zone,
    "Idwallet_transfer" character varying(36),
    "Bank_tran_id" character varying(100),
    "Status" character varying(10) DEFAULT 'Confirmed'::character varying NOT NULL,
    "Idgoal" character varying(36),
    "Idbill" character varying(36),
    "Server_update_at" timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    "Idhousehold" integer,
    "Idfund_pair" character varying(36)
);


--
-- Name: user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."user" (
    "Iduser" integer NOT NULL,
    "Idaccount" integer NOT NULL,
    "Fullname" character varying(100) NOT NULL,
    "Email" character varying(100) NOT NULL,
    "Phone" character varying(256),
    "Address" text,
    "Country_code" character(4),
    "Create_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Update_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Delete_at" timestamp(6) without time zone
);


--
-- Name: user_Iduser_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."user_Iduser_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_Iduser_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."user_Iduser_seq" OWNED BY public."user"."Iduser";


--
-- Name: wallet; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallet (
    "Idwallet" character varying(36) NOT NULL,
    "Idaccount" integer NOT NULL,
    "Id_bank_casso" character varying(36),
    "Name" character varying(100) NOT NULL,
    "Type" character varying(7) DEFAULT 'Cash'::character varying NOT NULL,
    "Balance" numeric(15,2) DEFAULT 0 NOT NULL,
    "Currency" character varying(3) DEFAULT 'VND'::character varying NOT NULL,
    "Status" character varying(20) DEFAULT 'Active'::character varying NOT NULL,
    "IncludeInTotal" boolean DEFAULT true NOT NULL,
    "Is_default" boolean DEFAULT false NOT NULL,
    "Icon" character varying(20) DEFAULT 'wallet'::character varying,
    "Color" character varying(20) DEFAULT '#4CAF50'::character varying,
    "Create_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Update_at" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Delete_at" timestamp(6) without time zone,
    "Server_update_at" timestamp(6) without time zone DEFAULT (now() AT TIME ZONE 'UTC'::text) NOT NULL,
    "Idhousehold" integer,
    CONSTRAINT chk_wallet_household_not_default CHECK ((("Idhousehold" IS NULL) OR ("Is_default" = false)))
);


--
-- Name: account Idaccount; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account ALTER COLUMN "Idaccount" SET DEFAULT nextval('public."account_Idaccount_seq"'::regclass);


--
-- Name: account_device_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_device_history ALTER COLUMN id SET DEFAULT nextval('public.account_device_history_id_seq'::regclass);


--
-- Name: account_type_permission id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_type_permission ALTER COLUMN id SET DEFAULT nextval('public.account_type_permission_id_seq'::regclass);


--
-- Name: aiops_quarantine_incident_link id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiops_quarantine_incident_link ALTER COLUMN id SET DEFAULT nextval('public.aiops_quarantine_incident_link_id_seq'::regclass);


--
-- Name: audit_log Idlog; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN "Idlog" SET DEFAULT nextval('public."audit_log_Idlog_seq"'::regclass);


--
-- Name: broadcast_notification id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.broadcast_notification ALTER COLUMN id SET DEFAULT nextval('public.broadcast_notification_id_seq'::regclass);


--
-- Name: data_incident id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_incident ALTER COLUMN id SET DEFAULT nextval('public.data_incident_id_seq'::regclass);


--
-- Name: household Idhousehold; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household ALTER COLUMN "Idhousehold" SET DEFAULT nextval('public."household_Idhousehold_seq"'::regclass);


--
-- Name: household_member Id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_member ALTER COLUMN "Id" SET DEFAULT nextval('public."household_member_Id_seq"'::regclass);


--
-- Name: maintenance_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_history ALTER COLUMN id SET DEFAULT nextval('public.maintenance_history_id_seq'::regclass);


--
-- Name: otp_code Id_otp; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_code ALTER COLUMN "Id_otp" SET DEFAULT nextval('public."otp_code_Id_otp_seq"'::regclass);


--
-- Name: payment_webhook_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_webhook_log ALTER COLUMN id SET DEFAULT nextval('public.payment_webhook_log_id_seq'::regclass);


--
-- Name: policy_acceptance id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_acceptance ALTER COLUMN id SET DEFAULT nextval('public.policy_acceptance_id_seq'::regclass);


--
-- Name: policy_document id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_document ALTER COLUMN id SET DEFAULT nextval('public.policy_document_id_seq'::regclass);


--
-- Name: refreshtoken Idtoken; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refreshtoken ALTER COLUMN "Idtoken" SET DEFAULT nextval('public."refreshtoken_Idtoken_seq"'::regclass);


--
-- Name: role Idrole; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role ALTER COLUMN "Idrole" SET DEFAULT nextval('public."role_Idrole_seq"'::regclass);


--
-- Name: server_session id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.server_session ALTER COLUMN id SET DEFAULT nextval('public.server_session_id_seq'::regclass);


--
-- Name: user Iduser; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."user" ALTER COLUMN "Iduser" SET DEFAULT nextval('public."user_Iduser_seq"'::regclass);


--
-- Name: account_device_history account_device_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_device_history
    ADD CONSTRAINT account_device_history_pkey PRIMARY KEY (id);


--
-- Name: account account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_pkey PRIMARY KEY ("Idaccount");


--
-- Name: account_type_permission account_type_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_type_permission
    ADD CONSTRAINT account_type_permission_pkey PRIMARY KEY (id);


--
-- Name: admin_preference admin_preference_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_preference
    ADD CONSTRAINT admin_preference_pkey PRIMARY KEY (idaccount);


--
-- Name: aiops_account_quarantine aiops_account_quarantine_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiops_account_quarantine
    ADD CONSTRAINT aiops_account_quarantine_pkey PRIMARY KEY (id);


--
-- Name: aiops_incident aiops_incident_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiops_incident
    ADD CONSTRAINT aiops_incident_pkey PRIMARY KEY (id);


--
-- Name: aiops_ip_quarantine aiops_ip_quarantine_ip_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiops_ip_quarantine
    ADD CONSTRAINT aiops_ip_quarantine_ip_hash_key UNIQUE (ip_hash);


--
-- Name: aiops_ip_quarantine aiops_ip_quarantine_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiops_ip_quarantine
    ADD CONSTRAINT aiops_ip_quarantine_pkey PRIMARY KEY (id);


--
-- Name: aiops_metric_snapshot aiops_metric_snapshot_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiops_metric_snapshot
    ADD CONSTRAINT aiops_metric_snapshot_pkey PRIMARY KEY (id);


--
-- Name: aiops_quarantine_incident_link aiops_quarantine_incident_link_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiops_quarantine_incident_link
    ADD CONSTRAINT aiops_quarantine_incident_link_pkey PRIMARY KEY (id);


--
-- Name: aiops_setting aiops_setting_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiops_setting
    ADD CONSTRAINT aiops_setting_pkey PRIMARY KEY (key);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY ("Idlog");


--
-- Name: bank_account bank_account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_account
    ADD CONSTRAINT bank_account_pkey PRIMARY KEY ("Id_bank_account");


--
-- Name: bill bill_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT bill_pkey PRIMARY KEY ("Idbill");


--
-- Name: broadcast_notification broadcast_notification_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.broadcast_notification
    ADD CONSTRAINT broadcast_notification_pkey PRIMARY KEY (id);


--
-- Name: budget budget_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget
    ADD CONSTRAINT budget_pkey PRIMARY KEY ("Idbudget");


--
-- Name: category category_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT category_pkey PRIMARY KEY ("Idcategory");


--
-- Name: data_export_request data_export_request_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_export_request
    ADD CONSTRAINT data_export_request_pkey PRIMARY KEY (id);


--
-- Name: data_incident data_incident_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_incident
    ADD CONSTRAINT data_incident_code_key UNIQUE (code);


--
-- Name: data_incident data_incident_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_incident
    ADD CONSTRAINT data_incident_pkey PRIMARY KEY (id);


--
-- Name: feature feature_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature
    ADD CONSTRAINT feature_pkey PRIMARY KEY (id);


--
-- Name: goal goal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal
    ADD CONSTRAINT goal_pkey PRIMARY KEY ("Idgoal");


--
-- Name: household_invite household_invite_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_invite
    ADD CONSTRAINT household_invite_pkey PRIMARY KEY ("Code");


--
-- Name: household_member household_member_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_member
    ADD CONSTRAINT household_member_pkey PRIMARY KEY ("Id");


--
-- Name: household household_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household
    ADD CONSTRAINT household_pkey PRIMARY KEY ("Idhousehold");


--
-- Name: maintenance_history maintenance_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_history
    ADD CONSTRAINT maintenance_history_pkey PRIMARY KEY (id);


--
-- Name: otp_code otp_code_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_code
    ADD CONSTRAINT otp_code_pkey PRIMARY KEY ("Id_otp");


--
-- Name: payment_webhook_log payment_webhook_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_webhook_log
    ADD CONSTRAINT payment_webhook_log_pkey PRIMARY KEY (id);


--
-- Name: payment_order pk_payment_order; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_order
    ADD CONSTRAINT pk_payment_order PRIMARY KEY (id);


--
-- Name: payment_transaction pk_payment_transaction; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_transaction
    ADD CONSTRAINT pk_payment_transaction PRIMARY KEY (id);


--
-- Name: policy_acceptance policy_acceptance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_acceptance
    ADD CONSTRAINT policy_acceptance_pkey PRIMARY KEY (id);


--
-- Name: policy_document policy_document_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_document
    ADD CONSTRAINT policy_document_pkey PRIMARY KEY (id);


--
-- Name: privacy_policy privacy_policy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privacy_policy
    ADD CONSTRAINT privacy_policy_pkey PRIMARY KEY (version);


--
-- Name: refreshtoken refreshtoken_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refreshtoken
    ADD CONSTRAINT refreshtoken_pkey PRIMARY KEY ("Idtoken");


--
-- Name: role role_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT role_pkey PRIMARY KEY ("Idrole");


--
-- Name: server_session server_session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.server_session
    ADD CONSTRAINT server_session_pkey PRIMARY KEY (id);


--
-- Name: transaction transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT transaction_pkey PRIMARY KEY ("Idtran");


--
-- Name: account_type_permission uq_account_type_feature; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_type_permission
    ADD CONSTRAINT uq_account_type_feature UNIQUE (account_type, feature_id);


--
-- Name: payment_order uq_payment_order_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_order
    ADD CONSTRAINT uq_payment_order_code UNIQUE (order_code);


--
-- Name: policy_acceptance uq_policy_acceptance_account_version; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_acceptance
    ADD CONSTRAINT uq_policy_acceptance_account_version UNIQUE (idaccount, policy_version);


--
-- Name: policy_document uq_policy_document_title; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_document
    ADD CONSTRAINT uq_policy_document_title UNIQUE (title);


--
-- Name: transaction uq_transaction_external; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT uq_transaction_external UNIQUE ("Idaccount", "Provider", "Bank_tran_id");


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY ("Iduser");


--
-- Name: wallet wallet_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet
    ADD CONSTRAINT wallet_pkey PRIMARY KEY ("Idwallet");


--
-- Name: account_Email_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "account_Email_key" ON public.account USING btree ("Email") WHERE ("Delete_at" IS NULL);


--
-- Name: bank_account_Id_casso_account_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "bank_account_Id_casso_account_key" ON public.bank_account USING btree ("Id_casso_account");


--
-- Name: idx_account_premium_expires; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_premium_expires ON public.account USING btree (premium_expires_at) WHERE (premium_expires_at IS NOT NULL);


--
-- Name: idx_account_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_role ON public.account USING btree ("Idrole");


--
-- Name: idx_account_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_username ON public.account USING btree ("Username");


--
-- Name: idx_aiops_account_quarantine_banned_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_account_quarantine_banned_at ON public.aiops_account_quarantine USING btree (banned_at DESC);


--
-- Name: idx_aiops_account_quarantine_idaccount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_account_quarantine_idaccount ON public.aiops_account_quarantine USING btree (idaccount);


--
-- Name: idx_aiops_account_quarantine_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_account_quarantine_status ON public.aiops_account_quarantine USING btree (status);


--
-- Name: idx_aiops_account_quarantine_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_account_quarantine_username ON public.aiops_account_quarantine USING btree (username);


--
-- Name: idx_aiops_incident_actor_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_incident_actor_hash ON public.aiops_incident USING btree (actor_hash);


--
-- Name: idx_aiops_incident_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_incident_code ON public.aiops_incident USING btree (code);


--
-- Name: idx_aiops_incident_detected_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_incident_detected_at ON public.aiops_incident USING btree (first_detected_at DESC);


--
-- Name: idx_aiops_incident_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_incident_status ON public.aiops_incident USING btree (status);


--
-- Name: idx_aiops_incident_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_incident_vector ON public.aiops_incident USING btree (vector);


--
-- Name: idx_aiops_ip_quarantine_banned_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_ip_quarantine_banned_at ON public.aiops_ip_quarantine USING btree (banned_at DESC);


--
-- Name: idx_aiops_ip_quarantine_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_ip_quarantine_expires_at ON public.aiops_ip_quarantine USING btree (expires_at);


--
-- Name: idx_aiops_ip_quarantine_ip_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_ip_quarantine_ip_hash ON public.aiops_ip_quarantine USING btree (ip_hash);


--
-- Name: idx_aiops_ip_quarantine_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_ip_quarantine_status ON public.aiops_ip_quarantine USING btree (status);


--
-- Name: idx_aiops_metric_snapshot_recorded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aiops_metric_snapshot_recorded_at ON public.aiops_metric_snapshot USING btree (recorded_at DESC);


--
-- Name: idx_auditlog_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_auditlog_account ON public.audit_log USING btree ("Idaccount");


--
-- Name: idx_bank_account_number_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bank_account_number_hash ON public.bank_account USING btree ("Account_number_hash");


--
-- Name: idx_bank_account_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bank_account_owner ON public.bank_account USING btree ("Idaccount");


--
-- Name: idx_bank_account_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bank_account_status ON public.bank_account USING btree ("Connect_status");


--
-- Name: idx_bill_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bill_account ON public.bill USING btree ("Idaccount");


--
-- Name: idx_bill_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bill_category ON public.bill USING btree ("Idcategory");


--
-- Name: idx_bill_previous_bill; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bill_previous_bill ON public.bill USING btree ("Previous_bill_id") WHERE ("Previous_bill_id" IS NOT NULL);


--
-- Name: idx_bill_server_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bill_server_updated ON public.bill USING btree ("Idaccount", "Server_update_at");


--
-- Name: idx_bill_wallet; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bill_wallet ON public.bill USING btree ("Idwallet");


--
-- Name: idx_broadcast_notification_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_broadcast_notification_created_at ON public.broadcast_notification USING btree (created_at DESC);


--
-- Name: idx_broadcast_notification_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_broadcast_notification_level ON public.broadcast_notification USING btree (level);


--
-- Name: idx_budget_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_budget_account ON public.budget USING btree ("Idaccount");


--
-- Name: idx_budget_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_budget_category ON public.budget USING btree ("Idcategory");


--
-- Name: idx_budget_household; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_budget_household ON public.budget USING btree ("Idhousehold", "Server_update_at") WHERE ("Idhousehold" IS NOT NULL);


--
-- Name: idx_budget_server_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_budget_server_updated ON public.budget USING btree ("Idaccount", "Server_update_at");


--
-- Name: idx_category_create_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_category_create_by ON public.category USING btree ("Create_by");


--
-- Name: idx_category_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_category_group ON public.category USING btree ("Idgroup");


--
-- Name: idx_category_household; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_category_household ON public.category USING btree ("Idhousehold", "Server_update_at") WHERE ("Idhousehold" IS NOT NULL);


--
-- Name: idx_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_category_id ON public.category USING btree ("Idcategory");


--
-- Name: idx_category_server_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_category_server_updated ON public.category USING btree ("Create_by", "Server_update_at");


--
-- Name: idx_data_export_account_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_data_export_account_time ON public.data_export_request USING btree (idaccount, requested_at DESC);


--
-- Name: idx_data_export_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_data_export_expiry ON public.data_export_request USING btree (expires_at) WHERE ((status)::text = 'READY'::text);


--
-- Name: idx_data_incident_status_detected; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_data_incident_status_detected ON public.data_incident USING btree (status, detected_at DESC);


--
-- Name: idx_device_history_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_device_history_account ON public.account_device_history USING btree (idaccount, last_active_at DESC);


--
-- Name: idx_device_history_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_device_history_ip ON public.account_device_history USING btree (ip_address);


--
-- Name: idx_device_history_ip_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_device_history_ip_hash ON public.account_device_history USING btree (ip_hash) WHERE (ip_hash IS NOT NULL);


--
-- Name: idx_device_history_ip_retention; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_device_history_ip_retention ON public.account_device_history USING btree (last_active_at) WHERE (ip_encrypted IS NOT NULL);


--
-- Name: idx_goal_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_goal_account ON public.goal USING btree ("Idaccount");


--
-- Name: idx_goal_household; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_goal_household ON public.goal USING btree ("Idhousehold", "Server_update_at") WHERE ("Idhousehold" IS NOT NULL);


--
-- Name: idx_goal_server_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_goal_server_updated ON public.goal USING btree ("Idaccount", "Server_update_at");


--
-- Name: idx_goal_wallet; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_goal_wallet ON public.goal USING btree ("Idwallet");


--
-- Name: idx_household_invite_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_household_invite_email ON public.household_invite USING btree ("Email") WHERE ("Email" IS NOT NULL);


--
-- Name: idx_household_member_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_household_member_active ON public.household_member USING btree ("Idhousehold") WHERE ("Left_at" IS NULL);


--
-- Name: idx_maintenance_history_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maintenance_history_started_at ON public.maintenance_history USING btree (started_at DESC);


--
-- Name: idx_maintenance_history_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maintenance_history_status ON public.maintenance_history USING btree (status);


--
-- Name: idx_maintenance_history_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maintenance_history_type ON public.maintenance_history USING btree (type);


--
-- Name: idx_otp_account_purpose; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_account_purpose ON public.otp_code USING btree ("Idaccount", purpose);


--
-- Name: idx_otp_email_purpose; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_email_purpose ON public.otp_code USING btree ("Email", purpose);


--
-- Name: idx_otp_expires; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_expires ON public.otp_code USING btree (expires_at);


--
-- Name: idx_payment_order_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_order_account ON public.payment_order USING btree (idaccount);


--
-- Name: idx_payment_order_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_order_code ON public.payment_order USING btree (order_code);


--
-- Name: idx_payment_order_is_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_order_is_template ON public.payment_order USING btree (is_template);


--
-- Name: idx_payment_order_recognition_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_order_recognition_code ON public.payment_order USING btree (recognition_code);


--
-- Name: idx_payment_order_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_order_status ON public.payment_order USING btree (status);


--
-- Name: idx_payment_transaction_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_transaction_account ON public.payment_transaction USING btree (idaccount);


--
-- Name: idx_payment_transaction_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_transaction_order ON public.payment_transaction USING btree (order_id);


--
-- Name: idx_payment_webhook_log_order_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_webhook_log_order_code ON public.payment_webhook_log USING btree (order_code);


--
-- Name: idx_payment_webhook_log_received_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_webhook_log_received_at ON public.payment_webhook_log USING btree (received_at);


--
-- Name: idx_perm_account_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_perm_account_type ON public.account_type_permission USING btree (account_type);


--
-- Name: idx_policy_acceptance_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_policy_acceptance_version ON public.policy_acceptance USING btree (policy_version);


--
-- Name: idx_privacy_policy_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_privacy_policy_status ON public.privacy_policy USING btree (status);


--
-- Name: idx_quarantine_link_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quarantine_link_account ON public.aiops_quarantine_incident_link USING btree (account_quarantine_id);


--
-- Name: idx_quarantine_link_detected_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quarantine_link_detected_at ON public.aiops_quarantine_incident_link USING btree (detected_at DESC);


--
-- Name: idx_quarantine_link_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quarantine_link_ip ON public.aiops_quarantine_incident_link USING btree (ip_quarantine_id);


--
-- Name: idx_quarantine_link_ip_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quarantine_link_ip_hash ON public.aiops_quarantine_incident_link USING btree (ip_hash);


--
-- Name: idx_quarantine_link_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quarantine_link_username ON public.aiops_quarantine_incident_link USING btree (username);


--
-- Name: idx_refreshtoken_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refreshtoken_account ON public.refreshtoken USING btree ("Idaccount");


--
-- Name: idx_refreshtoken_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refreshtoken_expiry ON public.refreshtoken USING btree ("Expired");


--
-- Name: idx_refreshtoken_revoked; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refreshtoken_revoked ON public.refreshtoken USING btree ("Status");


--
-- Name: idx_refreshtoken_token_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refreshtoken_token_hash ON public.refreshtoken USING btree ("Token_hash");


--
-- Name: idx_server_session_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_server_session_open ON public.server_session USING btree (last_seen_at) WHERE (ended_at IS NULL);


--
-- Name: idx_server_session_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_server_session_started_at ON public.server_session USING btree (started_at);


--
-- Name: idx_transaction_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transaction_account ON public.transaction USING btree ("Idaccount");


--
-- Name: idx_transaction_bill; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transaction_bill ON public.transaction USING btree ("Idbill") WHERE ("Idbill" IS NOT NULL);


--
-- Name: idx_transaction_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transaction_category ON public.transaction USING btree ("Idcategory");


--
-- Name: idx_transaction_create; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transaction_create ON public.transaction USING btree ("DateTransaction");


--
-- Name: idx_transaction_fund_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transaction_fund_pair ON public.transaction USING btree ("Idfund_pair") WHERE ("Idfund_pair" IS NOT NULL);


--
-- Name: idx_transaction_goal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transaction_goal ON public.transaction USING btree ("Idgoal") WHERE ("Idgoal" IS NOT NULL);


--
-- Name: idx_transaction_household; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transaction_household ON public.transaction USING btree ("Idhousehold", "Server_update_at") WHERE ("Idhousehold" IS NOT NULL);


--
-- Name: idx_transaction_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transaction_provider ON public.transaction USING btree ("Provider");


--
-- Name: idx_transaction_server_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transaction_server_updated ON public.transaction USING btree ("Idaccount", "Server_update_at");


--
-- Name: idx_transaction_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transaction_status ON public.transaction USING btree ("Status");


--
-- Name: idx_transaction_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transaction_updated ON public.transaction USING btree ("Update_at");


--
-- Name: idx_transaction_wallet; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transaction_wallet ON public.transaction USING btree ("Idwallet");


--
-- Name: idx_wallet_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wallet_account ON public.wallet USING btree ("Idaccount");


--
-- Name: idx_wallet_bank; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wallet_bank ON public.wallet USING btree ("Id_bank_casso");


--
-- Name: idx_wallet_household; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wallet_household ON public.wallet USING btree ("Idhousehold", "Server_update_at") WHERE ("Idhousehold" IS NOT NULL);


--
-- Name: idx_wallet_server_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wallet_server_updated ON public.wallet USING btree ("Idaccount", "Server_update_at");


--
-- Name: idx_wallet_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wallet_updated ON public.wallet USING btree ("Update_at");


--
-- Name: refreshtoken_Token_hash_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "refreshtoken_Token_hash_key" ON public.refreshtoken USING btree ("Token_hash");


--
-- Name: role_Rolename_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "role_Rolename_key" ON public.role USING btree ("Rolename");


--
-- Name: uq_category_default_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_category_default_name ON public.category USING btree (lower(regexp_replace(btrim(NORMALIZE("NameCategory", NFC)), '\s+'::text, ' '::text, 'g'::text))) WHERE (("Is_default" = true) AND ("Delete_at" IS NULL));


--
-- Name: uq_category_household_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_category_household_name ON public.category USING btree ("Idhousehold", lower(regexp_replace(btrim(NORMALIZE("NameCategory", NFC)), '\s+'::text, ' '::text, 'g'::text))) WHERE (("Delete_at" IS NULL) AND ("Idhousehold" IS NOT NULL));


--
-- Name: uq_category_owner_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_category_owner_name ON public.category USING btree ("Create_by", lower(regexp_replace(btrim(NORMALIZE("NameCategory", NFC)), '\s+'::text, ' '::text, 'g'::text))) WHERE (("Is_default" = false) AND ("Delete_at" IS NULL) AND ("Idhousehold" IS NULL));


--
-- Name: uq_goal_household_wallet_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_goal_household_wallet_active ON public.goal USING btree ("Idwallet") WHERE (("Idhousehold" IS NOT NULL) AND ("Delete_at" IS NULL));


--
-- Name: uq_household_invite_email_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_household_invite_email_active ON public.household_invite USING btree ("Idhousehold", "Email") WHERE (("Email" IS NOT NULL) AND ("Used_at" IS NULL) AND ("Revoked_at" IS NULL) AND ("Declined_at" IS NULL));


--
-- Name: uq_household_member_active_account; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_household_member_active_account ON public.household_member USING btree ("Idaccount") WHERE ("Left_at" IS NULL);


--
-- Name: uq_household_one_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_household_one_owner ON public.household_member USING btree ("Idhousehold") WHERE ((("Role")::text = 'Owner'::text) AND ("Left_at" IS NULL));


--
-- Name: uq_payment_transaction_payos_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_payment_transaction_payos_id ON public.payment_transaction USING btree (payos_transaction_id) WHERE (payos_transaction_id IS NOT NULL);


--
-- Name: uq_privacy_policy_document_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_privacy_policy_document_version ON public.privacy_policy USING btree (document_id, doc_version);


--
-- Name: uq_privacy_policy_one_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_privacy_policy_one_active ON public.privacy_policy USING btree (document_id) WHERE ((status)::text = 'ACTIVE'::text);


--
-- Name: uq_wallet_account_name_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_wallet_account_name_active ON public.wallet USING btree ("Idaccount", "Name") WHERE (("Delete_at" IS NULL) AND ("Idhousehold" IS NULL));


--
-- Name: uq_wallet_default_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_wallet_default_active ON public.wallet USING btree ("Idaccount") WHERE (("Is_default" = true) AND ("Delete_at" IS NULL) AND ("Idhousehold" IS NULL));


--
-- Name: uq_wallet_household_name_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_wallet_household_name_active ON public.wallet USING btree ("Idhousehold", "Name") WHERE (("Delete_at" IS NULL) AND ("Idhousehold" IS NOT NULL));


--
-- Name: user_Email_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "user_Email_key" ON public."user" USING btree ("Email") WHERE ("Delete_at" IS NULL);


--
-- Name: user_Idaccount_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "user_Idaccount_key" ON public."user" USING btree ("Idaccount");


--
-- Name: bank_account trg_check_bank_account_encrypted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_bank_account_encrypted BEFORE INSERT OR UPDATE OF "Account_number" ON public.bank_account FOR EACH ROW EXECUTE FUNCTION public.check_bank_account_is_encrypted();


--
-- Name: user trg_check_phone_encrypted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_phone_encrypted BEFORE INSERT OR UPDATE OF "Phone" ON public."user" FOR EACH ROW EXECUTE FUNCTION public.check_phone_is_encrypted();


--
-- Name: audit_log trg_protect_auditlog; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_auditlog BEFORE DELETE OR UPDATE ON public.audit_log FOR EACH ROW EXECUTE FUNCTION public.protect_auditlog_immutability();


--
-- Name: data_incident trg_protect_data_incident; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_data_incident BEFORE DELETE ON public.data_incident FOR EACH ROW EXECUTE FUNCTION public.protect_data_incident_delete();


--
-- Name: payment_order trg_protect_payment_order; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_payment_order BEFORE DELETE OR UPDATE ON public.payment_order FOR EACH ROW EXECUTE FUNCTION public.fn_protect_payment_order();


--
-- Name: payment_transaction trg_protect_payment_transaction; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_payment_transaction BEFORE DELETE OR UPDATE ON public.payment_transaction FOR EACH ROW EXECUTE FUNCTION public.fn_payment_ledger_immutable();


--
-- Name: payment_webhook_log trg_protect_payment_webhook_log; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_payment_webhook_log BEFORE DELETE OR UPDATE ON public.payment_webhook_log FOR EACH ROW EXECUTE FUNCTION public.fn_payment_ledger_immutable();


--
-- Name: policy_acceptance trg_protect_policy_acceptance; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_policy_acceptance BEFORE UPDATE ON public.policy_acceptance FOR EACH ROW EXECUTE FUNCTION public.protect_policy_immutability();


--
-- Name: privacy_policy trg_protect_privacy_policy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_privacy_policy BEFORE UPDATE ON public.privacy_policy FOR EACH ROW EXECUTE FUNCTION public.protect_privacy_policy_content();


--
-- Name: account trg_protect_root_admin; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_root_admin BEFORE INSERT OR DELETE OR UPDATE ON public.account FOR EACH ROW EXECUTE FUNCTION public.fn_protect_root_admin();


--
-- Name: transaction trg_protect_transaction; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_transaction BEFORE DELETE ON public.transaction FOR EACH ROW EXECUTE FUNCTION public.protect_transaction_hard_delete();


--
-- Name: bill trg_set_server_update_at_bill; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_server_update_at_bill BEFORE UPDATE ON public.bill FOR EACH ROW EXECUTE FUNCTION public.set_server_update_at();


--
-- Name: budget trg_set_server_update_at_budget; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_server_update_at_budget BEFORE UPDATE ON public.budget FOR EACH ROW EXECUTE FUNCTION public.set_server_update_at();


--
-- Name: category trg_set_server_update_at_category; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_server_update_at_category BEFORE UPDATE ON public.category FOR EACH ROW EXECUTE FUNCTION public.set_server_update_at();


--
-- Name: goal trg_set_server_update_at_goal; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_server_update_at_goal BEFORE UPDATE ON public.goal FOR EACH ROW EXECUTE FUNCTION public.set_server_update_at();


--
-- Name: transaction trg_set_server_update_at_transaction; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_server_update_at_transaction BEFORE UPDATE ON public.transaction FOR EACH ROW EXECUTE FUNCTION public.set_server_update_at();


--
-- Name: wallet trg_set_server_update_at_wallet; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_server_update_at_wallet BEFORE UPDATE ON public.wallet FOR EACH ROW EXECUTE FUNCTION public.set_server_update_at();


--
-- Name: aiops_quarantine_incident_link aiops_quarantine_incident_link_account_quarantine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiops_quarantine_incident_link
    ADD CONSTRAINT aiops_quarantine_incident_link_account_quarantine_id_fkey FOREIGN KEY (account_quarantine_id) REFERENCES public.aiops_account_quarantine(id) ON DELETE CASCADE;


--
-- Name: aiops_quarantine_incident_link aiops_quarantine_incident_link_ip_quarantine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aiops_quarantine_incident_link
    ADD CONSTRAINT aiops_quarantine_incident_link_ip_quarantine_id_fkey FOREIGN KEY (ip_quarantine_id) REFERENCES public.aiops_ip_quarantine(id) ON DELETE CASCADE;


--
-- Name: budget budget_Idhousehold_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget
    ADD CONSTRAINT "budget_Idhousehold_fkey" FOREIGN KEY ("Idhousehold") REFERENCES public.household("Idhousehold") ON DELETE SET NULL;


--
-- Name: category category_Idhousehold_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT "category_Idhousehold_fkey" FOREIGN KEY ("Idhousehold") REFERENCES public.household("Idhousehold") ON DELETE SET NULL;


--
-- Name: data_export_request data_export_request_idaccount_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_export_request
    ADD CONSTRAINT data_export_request_idaccount_fkey FOREIGN KEY (idaccount) REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: data_incident data_incident_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_incident
    ADD CONSTRAINT data_incident_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.account("Idaccount") ON DELETE SET NULL;


--
-- Name: data_incident data_incident_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_incident
    ADD CONSTRAINT data_incident_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.account("Idaccount") ON DELETE SET NULL;


--
-- Name: account fk_account_created_by_admin; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT fk_account_created_by_admin FOREIGN KEY (created_by_admin_id) REFERENCES public.account("Idaccount") ON DELETE SET NULL;


--
-- Name: account fk_account_role; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT fk_account_role FOREIGN KEY ("Idrole") REFERENCES public.role("Idrole") ON DELETE RESTRICT;


--
-- Name: admin_preference fk_admin_preference_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_preference
    ADD CONSTRAINT fk_admin_preference_account FOREIGN KEY (idaccount) REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: audit_log fk_auditlog_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT fk_auditlog_account FOREIGN KEY ("Idaccount") REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: bank_account fk_bank_account_owner; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_account
    ADD CONSTRAINT fk_bank_account_owner FOREIGN KEY ("Idaccount") REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: bill fk_bill_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT fk_bill_account FOREIGN KEY ("Idaccount") REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: bill fk_bill_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT fk_bill_category FOREIGN KEY ("Idcategory") REFERENCES public.category("Idcategory") ON DELETE RESTRICT;


--
-- Name: bill fk_bill_previous_bill; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT fk_bill_previous_bill FOREIGN KEY ("Previous_bill_id") REFERENCES public.bill("Idbill") ON DELETE SET NULL;


--
-- Name: bill fk_bill_wallet; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT fk_bill_wallet FOREIGN KEY ("Idwallet") REFERENCES public.wallet("Idwallet") ON DELETE RESTRICT;


--
-- Name: budget fk_budget_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget
    ADD CONSTRAINT fk_budget_account FOREIGN KEY ("Idaccount") REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: budget fk_budget_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget
    ADD CONSTRAINT fk_budget_category FOREIGN KEY ("Idcategory") REFERENCES public.category("Idcategory") ON DELETE SET NULL;


--
-- Name: category fk_category_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT fk_category_account FOREIGN KEY ("Create_by") REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: category fk_category_parent; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT fk_category_parent FOREIGN KEY ("Idgroup") REFERENCES public.category("Idcategory") ON DELETE SET NULL;


--
-- Name: account_device_history fk_device_history_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_device_history
    ADD CONSTRAINT fk_device_history_account FOREIGN KEY (idaccount) REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: goal fk_goal_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal
    ADD CONSTRAINT fk_goal_account FOREIGN KEY ("Idaccount") REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: goal fk_goal_wallet; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal
    ADD CONSTRAINT fk_goal_wallet FOREIGN KEY ("Idwallet") REFERENCES public.wallet("Idwallet") ON DELETE SET NULL;


--
-- Name: otp_code fk_otp_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_code
    ADD CONSTRAINT fk_otp_account FOREIGN KEY ("Idaccount") REFERENCES public.account("Idaccount") ON DELETE SET NULL;


--
-- Name: payment_order fk_payment_order_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_order
    ADD CONSTRAINT fk_payment_order_account FOREIGN KEY (idaccount) REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: payment_transaction fk_payment_transaction_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_transaction
    ADD CONSTRAINT fk_payment_transaction_account FOREIGN KEY (idaccount) REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: payment_transaction fk_payment_transaction_order; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_transaction
    ADD CONSTRAINT fk_payment_transaction_order FOREIGN KEY (order_id) REFERENCES public.payment_order(id) ON DELETE CASCADE;


--
-- Name: account_type_permission fk_perm_feature; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_type_permission
    ADD CONSTRAINT fk_perm_feature FOREIGN KEY (feature_id) REFERENCES public.feature(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: privacy_policy fk_privacy_policy_document; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privacy_policy
    ADD CONSTRAINT fk_privacy_policy_document FOREIGN KEY (document_id) REFERENCES public.policy_document(id) ON DELETE RESTRICT;


--
-- Name: privacy_policy fk_privacy_policy_status_changed_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privacy_policy
    ADD CONSTRAINT fk_privacy_policy_status_changed_by FOREIGN KEY (status_changed_by) REFERENCES public.account("Idaccount") ON DELETE SET NULL;


--
-- Name: refreshtoken fk_refreshtoken_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refreshtoken
    ADD CONSTRAINT fk_refreshtoken_account FOREIGN KEY ("Idaccount") REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: transaction fk_transaction_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT fk_transaction_account FOREIGN KEY ("Idaccount") REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: transaction fk_transaction_bill; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT fk_transaction_bill FOREIGN KEY ("Idbill") REFERENCES public.bill("Idbill") ON DELETE SET NULL;


--
-- Name: transaction fk_transaction_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT fk_transaction_category FOREIGN KEY ("Idcategory") REFERENCES public.category("Idcategory") ON DELETE SET NULL;


--
-- Name: transaction fk_transaction_goal; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT fk_transaction_goal FOREIGN KEY ("Idgoal") REFERENCES public.goal("Idgoal") ON DELETE SET NULL;


--
-- Name: transaction fk_transaction_wallet; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT fk_transaction_wallet FOREIGN KEY ("Idwallet") REFERENCES public.wallet("Idwallet") ON DELETE CASCADE;


--
-- Name: transaction fk_transaction_wallet_transfer; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT fk_transaction_wallet_transfer FOREIGN KEY ("Idwallet_transfer") REFERENCES public.wallet("Idwallet") ON DELETE SET NULL;


--
-- Name: user fk_user_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT fk_user_account FOREIGN KEY ("Idaccount") REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: wallet fk_wallet_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet
    ADD CONSTRAINT fk_wallet_account FOREIGN KEY ("Idaccount") REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: wallet fk_wallet_bank; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet
    ADD CONSTRAINT fk_wallet_bank FOREIGN KEY ("Id_bank_casso") REFERENCES public.bank_account("Id_bank_account") ON DELETE SET NULL;


--
-- Name: goal goal_Idhousehold_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal
    ADD CONSTRAINT "goal_Idhousehold_fkey" FOREIGN KEY ("Idhousehold") REFERENCES public.household("Idhousehold") ON DELETE SET NULL;


--
-- Name: household household_Owner_idaccount_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household
    ADD CONSTRAINT "household_Owner_idaccount_fkey" FOREIGN KEY ("Owner_idaccount") REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: household_invite household_invite_Created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_invite
    ADD CONSTRAINT "household_invite_Created_by_fkey" FOREIGN KEY ("Created_by") REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: household_invite household_invite_Idhousehold_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_invite
    ADD CONSTRAINT "household_invite_Idhousehold_fkey" FOREIGN KEY ("Idhousehold") REFERENCES public.household("Idhousehold") ON DELETE CASCADE;


--
-- Name: household_invite household_invite_Invitee_idaccount_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_invite
    ADD CONSTRAINT "household_invite_Invitee_idaccount_fkey" FOREIGN KEY ("Invitee_idaccount") REFERENCES public.account("Idaccount") ON DELETE SET NULL;


--
-- Name: household_invite household_invite_Used_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_invite
    ADD CONSTRAINT "household_invite_Used_by_fkey" FOREIGN KEY ("Used_by") REFERENCES public.account("Idaccount") ON DELETE SET NULL;


--
-- Name: household_member household_member_Idaccount_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_member
    ADD CONSTRAINT "household_member_Idaccount_fkey" FOREIGN KEY ("Idaccount") REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: household_member household_member_Idhousehold_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_member
    ADD CONSTRAINT "household_member_Idhousehold_fkey" FOREIGN KEY ("Idhousehold") REFERENCES public.household("Idhousehold") ON DELETE CASCADE;


--
-- Name: policy_acceptance policy_acceptance_idaccount_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_acceptance
    ADD CONSTRAINT policy_acceptance_idaccount_fkey FOREIGN KEY (idaccount) REFERENCES public.account("Idaccount") ON DELETE CASCADE;


--
-- Name: policy_acceptance policy_acceptance_policy_version_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_acceptance
    ADD CONSTRAINT policy_acceptance_policy_version_fkey FOREIGN KEY (policy_version) REFERENCES public.privacy_policy(version) ON DELETE RESTRICT;


--
-- Name: policy_document policy_document_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_document
    ADD CONSTRAINT policy_document_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.account("Idaccount") ON DELETE SET NULL;


--
-- Name: privacy_policy privacy_policy_published_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privacy_policy
    ADD CONSTRAINT privacy_policy_published_by_fkey FOREIGN KEY (published_by) REFERENCES public.account("Idaccount") ON DELETE SET NULL;


--
-- Name: transaction transaction_Idhousehold_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT "transaction_Idhousehold_fkey" FOREIGN KEY ("Idhousehold") REFERENCES public.household("Idhousehold") ON DELETE SET NULL;


--
-- Name: wallet wallet_Idhousehold_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet
    ADD CONSTRAINT "wallet_Idhousehold_fkey" FOREIGN KEY ("Idhousehold") REFERENCES public.household("Idhousehold") ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

-- ============================== Dữ liệu cấu hình ==============================

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: feature; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('biometric_auth', 'Xác thực sinh trắc học', 'Đăng nhập an toàn bằng vân tay hoặc nhận diện khuôn mặt Face ID trên thiết bị', 'TOGGLE', 'Xác thực & Bảo mật', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"methods": ["fingerprint", "face_id"], "auto_prompt": true}', 'LOCK_FEATURE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('offline_login', 'Đăng nhập ngoại tuyến', 'Cho phép đăng nhập truy cập dữ liệu cục bộ an toàn khi không có kết nối internet', 'TOGGLE', 'Xác thực & Bảo mật', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"cache_token_days": 30, "allow_pin_fallback": true}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('account_deletion', 'Quyền xóa tài khoản & Ân hạn', 'Yêu cầu xóa tài khoản với thời gian ân hạn 30 ngày bảo vệ người dùng', 'TOGGLE', 'Xác thực & Bảo mật', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"allow_undo": true, "grace_period_days": 30}', 'BLOCK_CREATE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('budgets', 'Quản lý ngân sách chi tiêu', 'Thiết lập hạn mức chi tiêu định kỳ hàng tháng theo từng danh mục', 'LIMIT', 'Ngân sách Chi tiêu', 3, true, '2026-10-07 13:24:22.332877', '2026-10-19 06:57:23.5941', '{"recurrence_cycles": ["MONTHLY"]}', 'BLOCK_CREATE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('household', 'Gia đình — tạo & quản trị nhà', 'Chủ nhà cần Premium để tạo và quản trị nhà; người được mời dùng miễn phí', 'TOGGLE', 'Gia đình', NULL, false, '2026-10-28 14:42:55.837232', '2026-10-30 15:38:10.813009', '{}', 'LOCK_FEATURE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('household_members', 'Gia đình — số thành viên tối đa', 'Trần thành viên mỗi nhà (gồm cả Chủ nhà)', 'LIMIT', 'Gia đình', 6, true, '2026-10-28 14:42:55.837232', '2026-10-30 15:38:10.813009', '{}', 'BLOCK_CREATE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('household_join', 'Gia đình — tham gia nhà', 'Cho phép tài khoản tham gia vào nhà khi nhận được lời mời (cả Basic và Premium)', 'TOGGLE', 'Gia đình', NULL, true, '2026-10-30 15:38:10.813009', '2026-10-30 15:38:10.813009', '{}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('household_wallets', 'Gia đình — số ví chung tối đa', 'Trần số lượng ví dùng chung trong mỗi gia đình', 'LIMIT', 'Gia đình', 10, true, '2026-10-30 15:38:10.813009', '2026-10-30 15:38:10.813009', '{}', 'BLOCK_CREATE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('net_worth_overview', 'Tổng quan tài sản ròng', 'Theo dõi biến động tổng tài sản ròng và cơ cấu tiền mặt, ngân hàng, ví điện tử', 'TOGGLE', 'Trang chủ & Điều hướng', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"chart_history_days": 30, "allow_trend_breakdown": false}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('quick_action_shortcuts', 'Phím tắt ghi chép nhanh', 'Bộ phím tắt tạo nhanh thu chi, chuyển tiền giữa các ví, quét hóa đơn và khẩu lệnh', 'TOGGLE', 'Trang chủ & Điều hướng', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"custom_slots": 4, "allow_voice_shortcut": false}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('wallets', 'Quản lý ví tiền', 'Tạo và quản lý các ví tiền mặt, tài khoản ngân hàng, thẻ tín dụng, ví điện tử', 'LIMIT', 'Quản lý Ví & Tài sản', 3, true, '2026-10-07 13:24:22.332877', '2026-10-19 06:57:23.5941', '{"custom_color": false, "allowed_types": ["Cash", "Bank", "EWallet"]}', 'BLOCK_CREATE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('wallet_balance_adjustment', 'Điều chỉnh số dư ví', 'Kiểm kê thực tế và tự động tạo giao dịch bù trừ để cân đối số dư ví chính xác', 'TOGGLE', 'Quản lý Ví & Tài sản', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"auto_generate_diff_tx": true}', 'BLOCK_CREATE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('wallet_exclude_total', 'Loại trừ ví khỏi tổng tài sản', 'Cho phép đánh dấu không cộng số dư của ví phụ vào tổng tài sản ròng', 'TOGGLE', 'Quản lý Ví & Tài sản', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"max_excluded_wallets": null}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('transaction_management', 'Sổ giao dịch thu chi', 'Quản lý toàn diện sổ thu chi, phân loại chi tiết, đính kèm ảnh và tìm kiếm đa chiều', 'TOGGLE', 'Sổ giao dịch Thu Chi', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"max_photos_per_tx": 1, "search_history_days": 90}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('ai_quick_input', 'Ghi chép bằng giọng nói (Voice)', 'Bóc tách câu nói tự nhiên tiếng Việt thành giao dịch tự động qua mô hình Whisper', 'TOGGLE', 'Sổ giao dịch Thu Chi', NULL, false, '2026-10-07 13:24:22.332877', '2026-10-19 06:57:23.5941', '{"max_seconds": 30, "daily_voice_quota": null}', 'LOCK_FEATURE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('ocr_receipt', 'Quét hóa đơn / Biên lai (OCR)', 'Tự động bóc tách ảnh chụp hóa đơn, biên lai thành giao dịch qua camera bằng MLKit', 'TOGGLE', 'Sổ giao dịch Thu Chi', NULL, true, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"auto_crop": false, "max_file_mb": 5, "monthly_scans": 15}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('quick_category_assignment', 'Gán danh mục nhanh (C1)', 'Hỗ trợ phân loại nhanh hàng loạt giao dịch chưa có danh mục hoặc biến động số dư', 'TOGGLE', 'Sổ giao dịch Thu Chi', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"batch_assign_max": 20}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('in_app_calculator', 'Bàn phím máy tính tích hợp', 'Máy tính mini tích hợp tính toán số tiền trực tiếp trên bàn phím khi ghi chép', 'TOGGLE', 'Sổ giao dịch Thu Chi', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"allow_history_tape": true}', 'LOCK_FEATURE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('custom_categories', 'Quản lý danh mục tùy chỉnh', 'Tạo danh mục thu chi riêng đa cấp (nhóm danh mục cha và các danh mục con)', 'LIMIT', 'Hệ thống Danh mục', 5, true, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"max_depth": 2, "custom_icons": false, "custom_colors": false}', 'BLOCK_CREATE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('category_keywords_matching', 'Từ khóa nhận diện danh mục', 'Thiết lập danh sách từ khóa nhận diện tự động cho OCR, giọng nói và ngân hàng', 'TOGGLE', 'Hệ thống Danh mục', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"max_keywords_per_cat": 5}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('smart_budget_rebalancing', 'Tái phân bổ ngân sách AI', 'Gợi ý tự động điều chuyển hạn mức giữa các ngân sách khi sắp vượt ngưỡng chi', 'TOGGLE', 'Ngân sách Chi tiêu', NULL, false, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"apply_one_click": true, "auto_suggest_shift": true}', 'LOCK_FEATURE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('budget_overspend_alert', 'Dự báo vỡ hạn mức chi tiêu', 'Cảnh báo chi tiêu chạm ngưỡng và tính toán định mức chi an toàn mỗi ngày còn lại', 'TOGGLE', 'Ngân sách Chi tiêu', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"alert_threshold": 0.8, "daily_burn_rate": false}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('bills', 'Quản lý hóa đơn định kỳ', 'Theo dõi hóa đơn lặp lại (Điện, Nước, Internet, Thuê nhà...) và chu kỳ', 'LIMIT', 'Hóa đơn định kỳ', 3, true, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"cycles": ["MONTHLY"]}', 'BLOCK_CREATE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('bill_auto_pay', 'Tự động thanh toán hóa đơn', 'Tự động tạo giao dịch thanh toán trừ tiền ví khi hóa đơn đến hạn', 'TOGGLE', 'Hóa đơn định kỳ', NULL, false, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"retry_on_fail": 3, "auto_deduct_wallet": true}', 'GRACE_PERIOD_3D');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('bill_reminder_notifications', 'Nhắc hẹn hóa đơn đa tầng', 'Nhắc nhở thanh toán hóa đơn trước ngày đến hạn qua Push Notification', 'TOGGLE', 'Hóa đơn định kỳ', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"custom_hour": false, "remind_days_before": [1]}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('goals', 'Mục tiêu tích lũy tiết kiệm', 'Lập kế hoạch tích lũy tài chính (mua xe, du lịch, mua nhà, quỹ khẩn cấp...)', 'LIMIT', 'Mục tiêu Tích lũy', 3, true, '2026-10-07 13:24:22.332877', '2026-10-19 06:57:23.5941', '{"priority_sorting": false, "allow_sub_milestones": false}', 'BLOCK_CREATE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('goal_auto_deposit', 'Tự động trích tiền mục tiêu', 'Tự động trích tiền định kỳ từ ví vào hũ mục tiêu tiết kiệm', 'TOGGLE', 'Mục tiêu Tích lũy', NULL, false, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"frequency": ["DAILY", "WEEKLY", "MONTHLY"], "auto_pause_on_low_balance": true}', 'GRACE_PERIOD_3D');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('goal_deposit_withdraw', 'Nạp & Rút tiền mục tiêu', 'Thao tác nạp thêm tiền vào mục tiêu hoặc rút tiền mục tiêu về ví linh hoạt', 'TOGGLE', 'Mục tiêu Tích lũy', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"require_linked_wallet": true}', 'BLOCK_CREATE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('export_reports', 'Xuất báo cáo PDF / Excel', 'Xuất dữ liệu sao kê thu chi chuyên nghiệp ra file PDF in ấn hoặc bảng tính Excel', 'TOGGLE', 'Báo cáo & Phân tích', NULL, false, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"formats": ["PDF", "EXCEL", "CSV"], "watermark": false, "max_range_years": null}', 'LOCK_FEATURE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('financial_health_fhs', 'Chỉ số sức khỏe tài chính', 'Đánh giá thang điểm sức khỏe tài chính và phân tích cơ cấu chi tiêu 50/30/20', 'TOGGLE', 'Báo cáo & Phân tích', NULL, true, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"score_only": true, "ai_deep_insights": false}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('cashflow_forecast', 'Dự báo dòng tiền 30 ngày', 'Dự báo xu hướng số dư và dòng tiền tự do trong 30 ngày tiếp theo', 'TOGGLE', 'Báo cáo & Phân tích', NULL, false, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"forecast_days": 30, "scenario_model": true}', 'READ_ONLY');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('anomaly_spending_insights', 'Cảnh báo chi tiêu bất thường', 'Phát hiện và cảnh báo các khoản chi tiêu đột biến bất thường so với lịch sử', 'TOGGLE', 'Báo cáo & Phân tích', NULL, false, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"auto_notify": true, "deviation_percent_threshold": 30}', 'LOCK_FEATURE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('ai_assistant', 'Trợ lý tài chính Copilot AI', 'Hỏi đáp, tư vấn tài chính, tạo giao dịch/ngân sách qua ngôn ngữ tự nhiên Gemini', 'TOGGLE', 'Trí tuệ nhân tạo & Edge AI', NULL, false, '2026-10-07 13:24:22.332877', '2026-10-19 06:57:23.5941', '{"model": "gemini-3.8-flash", "daily_prompts": null, "context_window_days": 90}', 'LOCK_FEATURE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('payment_history', 'Lịch sử thanh toán gói cước', 'Tra cứu lịch sử giao dịch mua gói cước, biên lai thanh toán (lọc sạch đơn mẫu)', 'TOGGLE', 'Gói cước & Thanh toán', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"allow_download_invoice": false, "exclude_template_orders": true}', 'BLOCK_CREATE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('offline_first_sync', 'Đồng bộ 2 chiều Offline-First', 'Ghi chép ngoại tuyến trên SQLite 0ms độ trễ và tự động đồng bộ 2 chiều khi có mạng', 'TOGGLE', 'Đồng bộ Ngoại tuyến', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"debounce_seconds": 10, "realtime_priority": false, "cloud_photo_backup": false}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('ai_edge_model', 'Mô hình AI Offline trên máy', 'Tải và chạy mô hình ngôn ngữ trực tiếp trên chip điện thoại không cần internet', 'TOGGLE', 'Trí tuệ nhân tạo & Edge AI', NULL, false, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"models": ["whisper-tiny", "finance-slm"], "allow_offline_inference": true}', 'LOCK_FEATURE');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('ai_model_management', 'Quản lý bộ nhớ mô hình AI', 'Quản lý tải về, xóa giải phóng bộ nhớ mô hình AI On-Device trên thiết bị', 'TOGGLE', 'Trí tuệ nhân tạo & Edge AI', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"max_storage_mb": 500, "allow_purge_cache": true}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('bank_notification_parser', 'Đọc biến động số dư ngân hàng', 'Tự động nhận diện thông báo biến động số dư từ app ngân hàng trên máy để nhắc ghi chép', 'TOGGLE', 'Thông báo & Giám sát', NULL, true, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"supported_banks": ["VCB", "MB", "TCB", "ACB"], "auto_fill_category": false}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('daily_recording_reminder', 'Nhắc nhở ghi chép hàng ngày', 'Tự động phát thông báo nhắc nhở ghi chép thu chi vào các khung giờ cấu hình', 'TOGGLE', 'Thông báo & Giám sát', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"custom_message": false, "reminder_slots": ["20:00"]}', 'FALLBACK_DEFAULT');
INSERT INTO public.feature (id, name, description, type, category_group, default_limit, default_enabled, created_at, updated_at, scope_schema, default_downgrade_policy) VALUES ('vietqr_payment', 'Thanh toán tự động VietQR', 'Tạo mã VietQR Napas 247 động, đếm ngược và đối soát tự động qua PayOS Gateway', 'TOGGLE', 'Gói cước & Thanh toán', NULL, true, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"gateway": "PayOS", "support_jit_sync": true, "countdown_minutes": 15}', 'BLOCK_CREATE');


--
-- Data for Name: account_type_permission; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (51, 'Basic', 'biometric_auth', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"methods": ["fingerprint", "face_id"], "auto_prompt": true}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (52, 'Basic', 'offline_login', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"cache_token_days": 30, "allow_pin_fallback": true}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (53, 'Basic', 'account_deletion', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"allow_undo": true, "grace_period_days": 30}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (54, 'Basic', 'net_worth_overview', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"chart_history_days": 30, "allow_trend_breakdown": false}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (55, 'Basic', 'quick_action_shortcuts', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"custom_slots": 4, "allow_voice_shortcut": false}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (59, 'Basic', 'transaction_management', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"max_photos_per_tx": 1, "search_history_days": 90}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (5, 'Basic', 'ai_quick_input', false, NULL, '2026-10-07 13:24:22.332877', '2026-10-19 06:57:23.5941', '{"max_seconds": 0, "daily_voice_quota": 0}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (18, 'Basic', 'ocr_receipt', true, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"auto_crop": false, "max_file_mb": 5, "monthly_scans": 15}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (62, 'Basic', 'quick_category_assignment', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"batch_assign_max": 20}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (63, 'Basic', 'in_app_calculator', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"allow_history_tape": true}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (15, 'Basic', 'custom_categories', true, 5, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"max_depth": 2, "custom_icons": false, "custom_colors": false}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (65, 'Basic', 'category_keywords_matching', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"max_keywords_per_cat": 5}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (2, 'Basic', 'budgets', true, 3, '2026-10-07 13:24:22.332877', '2026-10-19 06:57:23.5941', '{"recurrence_cycles": ["MONTHLY"]}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (20, 'Basic', 'smart_budget_rebalancing', false, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"apply_one_click": false, "auto_suggest_shift": false}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (68, 'Basic', 'budget_overspend_alert', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"alert_threshold": 0.8, "daily_burn_rate": false}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (14, 'Basic', 'bills', true, 3, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"cycles": ["MONTHLY"]}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (25, 'Basic', 'bill_auto_pay', false, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"retry_on_fail": 0, "auto_deduct_wallet": false}', 'GRACE_PERIOD_3D');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (71, 'Basic', 'bill_reminder_notifications', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"custom_hour": false, "remind_days_before": [1]}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (437, 'Basic', 'household', false, NULL, '2026-10-28 14:42:55.837232', '2026-10-30 15:38:10.813009', '{}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (439, 'Basic', 'household_members', false, 0, '2026-10-28 14:42:55.837232', '2026-10-30 15:38:10.813009', '{}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (440, 'Premium', 'household_members', true, 6, '2026-10-28 14:42:55.837232', '2026-11-02 11:55:12.601', '{"invite_methods": ["code", "email"], "code_expire_hours": 48, "email_invite_expire_days": 7}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (438, 'Premium', 'household', true, NULL, '2026-10-28 14:42:55.837232', '2026-11-02 11:55:49.895', '{"allow_dissolve": true, "allow_transfer_owner": true}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (57, 'Basic', 'wallet_balance_adjustment', true, NULL, '2026-10-17 05:39:42.533343', '2026-11-04 06:33:34.971', '{"auto_generate_diff_tx": true}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (58, 'Basic', 'wallet_exclude_total', true, NULL, '2026-10-17 05:39:42.533343', '2026-11-17 08:09:25.304', '{"max_excluded_wallets": null}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (1, 'Basic', 'wallets', true, 3, '2026-10-07 13:24:22.332877', '2026-11-17 08:22:53.212', '{"custom_color": false, "allowed_types": ["Cash", "Bank", "EWallet"]}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (4, 'Basic', 'ai_assistant', false, NULL, '2026-10-07 13:24:22.332877', '2026-10-19 06:57:23.5941', '{"model": "none", "daily_prompts": 0, "context_window_days": 0}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (81, 'Basic', 'ai_model_management', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"max_storage_mb": 500, "allow_purge_cache": true}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (27, 'Basic', 'bank_notification_parser', true, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"supported_banks": ["VCB", "MB", "TCB", "ACB"], "auto_fill_category": false}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (83, 'Basic', 'daily_recording_reminder', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"custom_message": false, "reminder_slots": ["20:00"]}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (84, 'Basic', 'vietqr_payment', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"gateway": "PayOS", "support_jit_sync": true, "countdown_minutes": 15}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (85, 'Basic', 'payment_history', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"allow_download_invoice": false, "exclude_template_orders": true}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (86, 'Basic', 'offline_first_sync', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"debounce_seconds": 10, "realtime_priority": false, "cloud_photo_backup": false}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (88, 'Premium', 'offline_login', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"cache_token_days": 30, "allow_pin_fallback": true}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (89, 'Premium', 'account_deletion', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"allow_undo": true, "grace_period_days": 30}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (90, 'Premium', 'net_worth_overview', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"chart_history_days": null, "allow_trend_breakdown": true}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (91, 'Premium', 'quick_action_shortcuts', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"custom_slots": 8, "allow_voice_shortcut": true}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (6, 'Premium', 'wallets', true, NULL, '2026-10-07 13:24:22.332877', '2026-10-19 06:57:23.5941', '{"custom_color": true, "allowed_types": ["Cash", "Bank", "EWallet", "Credit", "Investment"]}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (94, 'Premium', 'wallet_exclude_total', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"max_excluded_wallets": null}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (95, 'Premium', 'transaction_management', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"max_photos_per_tx": 5, "search_history_days": null}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (10, 'Premium', 'ai_quick_input', true, NULL, '2026-10-07 13:24:22.332877', '2026-10-19 06:57:23.5941', '{"max_seconds": 30, "daily_voice_quota": null}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (99, 'Premium', 'in_app_calculator', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"allow_history_tape": true}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (450, 'Basic', 'household_join', true, NULL, '2026-10-30 15:38:10.813009', '2026-10-30 15:38:10.813009', '{}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (452, 'Basic', 'household_wallets', false, 0, '2026-10-30 15:38:10.813009', '2026-10-30 15:38:10.813009', '{}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (454, 'Premium', 'household_join', true, NULL, '2026-10-30 15:38:10.813009', '2026-10-30 15:38:10.813009', '{}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (456, 'Premium', 'household_wallets', true, 10, '2026-10-30 15:38:10.813009', '2026-10-30 15:38:10.813009', '{"max_shared_wallets": 10}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (35, 'Premium', 'ocr_receipt', true, NULL, '2026-10-07 15:28:48.028653', '2026-11-02 11:53:25.079', '{"auto_crop": true, "max_file_mb": 20, "monthly_scans": null}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (87, 'Premium', 'biometric_auth', true, NULL, '2026-10-17 05:39:42.533343', '2026-11-02 11:53:26.197', '{"methods": ["fingerprint", "face_id"], "auto_prompt": true}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (93, 'Premium', 'wallet_balance_adjustment', true, NULL, '2026-10-17 05:39:42.533343', '2026-11-05 08:57:21.518', '{"auto_generate_diff_tx": true}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (19, 'Basic', 'ai_edge_model', true, NULL, '2026-10-07 15:28:48.028653', '2026-11-17 05:02:16.011', '{"models": [], "allow_offline_inference": false}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (3, 'Basic', 'goals', true, 3, '2026-10-07 13:24:22.332877', '2026-10-19 06:57:23.5941', '{"priority_sorting": false, "allow_sub_milestones": false}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (26, 'Basic', 'goal_auto_deposit', false, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"frequency": [], "auto_pause_on_low_balance": false}', 'GRACE_PERIOD_3D');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (74, 'Basic', 'goal_deposit_withdraw', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"require_linked_wallet": true}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (22, 'Basic', 'export_reports', false, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"formats": [], "watermark": true, "max_range_years": 0}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (21, 'Basic', 'financial_health_fhs', true, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"score_only": true, "ai_deep_insights": false}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (23, 'Basic', 'cashflow_forecast', false, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"forecast_days": 0, "scenario_model": false}', 'READ_ONLY');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (24, 'Basic', 'anomaly_spending_insights', false, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"auto_notify": false, "deviation_percent_threshold": 50}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (98, 'Premium', 'quick_category_assignment', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"batch_assign_max": 100}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (32, 'Premium', 'custom_categories', true, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"max_depth": 3, "custom_icons": true, "custom_colors": true}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (101, 'Premium', 'category_keywords_matching', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"max_keywords_per_cat": 25}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (40, 'Premium', 'cashflow_forecast', true, NULL, '2026-10-07 15:28:48.028653', '2026-10-23 07:25:32.661', '{"forecast_days": 31, "scenario_model": true}', 'READ_ONLY');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (39, 'Premium', 'export_reports', true, NULL, '2026-10-07 15:28:48.028653', '2026-11-02 11:46:27.011', '{"formats": ["PDF", "EXCEL", "CSV"], "watermark": false, "max_range_years": null}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (7, 'Premium', 'budgets', true, NULL, '2026-10-07 13:24:22.332877', '2026-10-19 06:57:23.5941', '{"recurrence_cycles": ["WEEKLY", "MONTHLY", "CUSTOM"]}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (37, 'Premium', 'smart_budget_rebalancing', true, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"apply_one_click": true, "auto_suggest_shift": true}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (104, 'Premium', 'budget_overspend_alert', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"alert_threshold": 0.8, "daily_burn_rate": true}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (31, 'Premium', 'bills', true, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"cycles": ["WEEKLY", "MONTHLY", "QUARTERLY", "YEARLY"]}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (42, 'Premium', 'bill_auto_pay', true, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"retry_on_fail": 3, "auto_deduct_wallet": true}', 'GRACE_PERIOD_3D');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (107, 'Premium', 'bill_reminder_notifications', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"custom_hour": true, "remind_days_before": [1, 3, 7]}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (8, 'Premium', 'goals', true, NULL, '2026-10-07 13:24:22.332877', '2026-10-19 06:57:23.5941', '{"priority_sorting": true, "allow_sub_milestones": true}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (43, 'Premium', 'goal_auto_deposit', true, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"frequency": ["DAILY", "WEEKLY", "MONTHLY"], "auto_pause_on_low_balance": true}', 'GRACE_PERIOD_3D');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (110, 'Premium', 'goal_deposit_withdraw', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"require_linked_wallet": true}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (38, 'Premium', 'financial_health_fhs', true, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"score_only": false, "ai_deep_insights": true}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (41, 'Premium', 'anomaly_spending_insights', true, NULL, '2026-10-07 15:28:48.028653', '2026-10-19 06:57:23.5941', '{"auto_notify": true, "deviation_percent_threshold": 30}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (117, 'Premium', 'ai_model_management', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"max_storage_mb": 2000, "allow_purge_cache": true}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (119, 'Premium', 'daily_recording_reminder', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"custom_message": true, "reminder_slots": ["12:00", "18:00", "21:00"]}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (120, 'Premium', 'vietqr_payment', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"gateway": "PayOS", "support_jit_sync": true, "countdown_minutes": 15}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (121, 'Premium', 'payment_history', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"allow_download_invoice": true, "exclude_template_orders": true}', 'BLOCK_CREATE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (122, 'Premium', 'offline_first_sync', true, NULL, '2026-10-17 05:39:42.533343', '2026-10-19 06:57:23.5941', '{"debounce_seconds": 2, "realtime_priority": true, "cloud_photo_backup": true}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (36, 'Premium', 'ai_edge_model', true, NULL, '2026-10-07 15:28:48.028653', '2026-11-02 11:53:25.689', '{"models": ["whisper-tiny", "finance-slm"], "allow_offline_inference": true}', 'LOCK_FEATURE');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (44, 'Premium', 'bank_notification_parser', true, NULL, '2026-10-07 15:28:48.028653', '2026-11-02 11:56:29.946', '{"supported_banks": ["ALL"], "auto_fill_category": true}', 'FALLBACK_DEFAULT');
INSERT INTO public.account_type_permission (id, account_type, feature_id, is_enabled, limit_value, created_at, updated_at, scope_config, downgrade_policy) VALUES (9, 'Premium', 'ai_assistant', true, NULL, '2026-10-07 13:24:22.332877', '2026-11-07 20:13:34.640645', '{"model": "cloud", "daily_prompts": 20, "context_window_days": 90}', 'LOCK_FEATURE');


--
-- Data for Name: aiops_setting; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.aiops_setting (key, value, updated_at) VALUES ('custom_vector_thresholds', '{"authFailureThreshold":15,"trafficSpikeRps":50,"exploitLimit":5,"resourceCpuPercent":85,"resourceMemoryPercent":85,"eventLoopLagMs":155}', '2026-10-23 07:55:00.661341');
INSERT INTO public.aiops_setting (key, value, updated_at) VALUES ('target_concurrency', '100', '2026-10-24 16:38:34.446765');
INSERT INTO public.aiops_setting (key, value, updated_at) VALUES ('vector_toggles', '{"auth":true,"traffic":true,"exploit":true,"resource":true}', '2026-11-14 09:05:19.875623');


--
-- Data for Name: role; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.role ("Idrole", "Rolename", "Description") VALUES (1, 'admin', 'quản trị viên hệ thống');
INSERT INTO public.role ("Idrole", "Rolename", "Description") VALUES (2, 'user', 'người dùng');


--
-- Name: account_type_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.account_type_permission_id_seq', 485, true);


--
-- Name: role_Idrole_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."role_Idrole_seq"', 1, false);


--
-- PostgreSQL database dump complete
--

