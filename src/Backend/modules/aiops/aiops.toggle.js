/**
 * Công tắc AIOps (2026-11-17): tính năng tạm dừng, thuộc phạm vi nâng cấp sau.
 * Chỉ bật khi AIOPS_ENABLED = 'true' (bật cùng VITE_AIOPS_ENABLED ở Admin-web).
 * Đọc biến mỗi lần gọi để test đổi được; chi phí không đáng kể.
 * Đặc tả: docs/Admin-web/09-aiops-sentinel-and-quarantine.md, mục "Trạng thái: tạm dừng".
 */
const isAiopsEnabled = (env = process.env) => String(env.AIOPS_ENABLED || '').trim().toLowerCase() === 'true';

/** Bọc middleware AIOps: công tắc tắt thì cho yêu cầu đi tiếp, không đếm, không chặn. */
const aiopsGated = (middleware) => function aiopsGatedMiddleware(req, res, next) {
  if (!isAiopsEnabled()) return next();
  return middleware(req, res, next);
};

/** Cổng cho /admin/aiops/*: công tắc tắt thì 404 AIOPS_DISABLED. */
const aiopsRouteGate = (req, res, next) => {
  if (isAiopsEnabled()) return next();
  return res.status(404).json({
    success: false,
    code: 'AIOPS_DISABLED',
    error: 'AIOPS_DISABLED',
    message: 'Tính năng giám sát an ninh AIOps đang tạm dừng.',
  });
};

/**
 * Khởi động lúc bootstrap. Tắt thì không chạy vòng đo, nhưng vẫn nạp danh sách phong toả
 * để bộ quét hết hạn (chạy sẵn trong AIOpsQuarantine) mở các tài khoản đang bị khoá tạm.
 * Không có nguồn nào tạo khoá mới khi tắt (collector, lá chắn, route đều bị chặn).
 */
const startAiops = async ({ service, quarantine, repository }) => {
  if (isAiopsEnabled()) service.start();
  await repository.initTables();
  await quarantine.hydrateFromDatabase();
};

module.exports = { isAiopsEnabled, aiopsGated, aiopsRouteGate, startAiops };
