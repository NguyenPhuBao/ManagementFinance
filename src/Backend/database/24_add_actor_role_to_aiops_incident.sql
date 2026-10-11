-- Migration 24: Bổ sung cột actor_role vào bảng aiops_incident để định danh phân quyền tác nhân (Admin, User, System, Guest)
ALTER TABLE "aiops_incident" ADD COLUMN IF NOT EXISTS "actor_role" VARCHAR(50) NULL;
