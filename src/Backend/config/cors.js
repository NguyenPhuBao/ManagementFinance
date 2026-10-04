/**
 * CORS Origin Resolver & Validator
 * Đảm bảo hỗ trợ thông suốt và bảo mật cho:
 * 1. Các domain cấu hình trong biến môi trường CORS_ORIGIN
 * 2. Môi trường phát triển cục bộ (localhost / 127.0.0.1 ở mọi cổng)
 * 3. Tất cả các domain Vercel của dự án (management-finance*.vercel.app, managementfinance*.vercel.app)
 * 4. Các yêu cầu không kèm Origin (Mobile app Flutter, Server-to-server, curl, Postman)
 */

function isOriginAllowed(origin, configuredOrigins) {
  // Yêu cầu non-browser (Mobile app, cURL, server-to-server) không gửi header Origin
  if (!origin) return true;

  // Nếu cấu hình là wildcard '*'
  if (configuredOrigins === '*') return true;

  // Chuyển configuredOrigins thành danh sách mảng chuẩn
  const allowedList = Array.isArray(configuredOrigins)
    ? configuredOrigins
    : (typeof configuredOrigins === 'string'
        ? (configuredOrigins.includes(',') ? configuredOrigins.split(',').map((s) => s.trim()) : [configuredOrigins.trim()])
        : []);

  // 1. Khớp chính xác với danh sách được cấu hình
  if (allowedList.includes(origin)) return true;

  // 2. Khớp môi trường dev cục bộ (localhost hoặc 127.0.0.1 ở bất kỳ port nào)
  if (/^https?:\/\/localhost(:\d+)?$/.test(origin) || /^https?:\/\/127\.0\.0\.1(:\d+)?$/.test(origin)) {
    return true;
  }

  // 3. Khớp các tên miền Vercel của dự án (cả production lẫn preview/branch deployments)
  // Ví dụ: https://management-finance-gamma.vercel.app, https://managementfinance-admin.vercel.app
  if (/^https:\/\/(management-finance|managementfinance)[a-z0-9-]*\.vercel\.app$/.test(origin)) {
    return true;
  }

  return false;
}

/**
 * Tạo hàm callback tương thích với cả express cors middleware và socket.io cors
 * @param {string|string[]} configuredOrigins
 * @returns {function(string, function(Error|null, boolean)): void}
 */
function createCorsOriginValidator(configuredOrigins) {
  return function (origin, callback) {
    if (isOriginAllowed(origin, configuredOrigins)) {
      callback(null, true);
    } else {
      callback(null, false);
    }
  };
}

module.exports = {
  isOriginAllowed,
  createCorsOriginValidator,
};
