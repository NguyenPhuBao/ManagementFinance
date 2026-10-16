const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

/**
 * Tự động phân giải URL kết nối Redis theo cấu hình REDIS_PROVIDER:
 * - 'railway': Ưu tiên REDIS_RAILWAY_URL
 * - 'upstash': Ưu tiên REDIS_UPSTASH_URL
 * - 'local':   Ưu tiên REDIS_LOCAL_URL hoặc redis://127.0.0.1:6379
 * - Mặc định:  REDIS_URL || REDIS_RAILWAY_URL || REDIS_UPSTASH_URL || redis://127.0.0.1:6379
 * 
 * Luôn gán ngược lại vào process.env.REDIS_URL để đảm bảo 100% các file
 * trong hệ thống (core, workers, modules) đều dùng chung một URL nhất quán.
 */
function resolveRedisUrl() {
  const provider = (process.env.REDIS_PROVIDER || '').toLowerCase().trim();
  let selectedUrl = '';

  if (provider === 'upstash') {
    selectedUrl = process.env.REDIS_UPSTASH_URL;
  } else if (provider === 'railway') {
    selectedUrl = process.env.REDIS_RAILWAY_URL;
  } else if (provider === 'local') {
    selectedUrl = process.env.REDIS_LOCAL_URL || 'redis://127.0.0.1:6379';
  }

  if (!selectedUrl) {
    selectedUrl = process.env.REDIS_URL || process.env.REDIS_RAILWAY_URL || process.env.REDIS_UPSTASH_URL || 'redis://127.0.0.1:6379';
  }

  process.env.REDIS_URL = selectedUrl;
  return selectedUrl;
}

// Tự động phân giải ngay khi nạp module
const currentRedisUrl = resolveRedisUrl();

module.exports = {
  resolveRedisUrl,
  currentRedisUrl,
};
