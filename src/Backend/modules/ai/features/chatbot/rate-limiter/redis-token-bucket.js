/**
 * Redis Token-Bucket Rate Limiter
 * Giới hạn 15 request / phút / idaccount
 * Hỗ trợ Redis Token-Bucket chuẩn hóa kèm In-Memory Graceful Fallback
 */

const { redis } = require('../../../../../config/redis');
const logger = require('../../../../../core/logger');

const LUA_TOKEN_BUCKET = `
local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local refill_rate_per_ms = tonumber(ARGV[2])
local now = tonumber(ARGV[3])
local requested = tonumber(ARGV[4])

local data = redis.call('HMGET', key, 'tokens', 'last_refreshed')
local current_tokens = capacity
local last_refreshed = now

if data[1] and data[2] then
  current_tokens = tonumber(data[1])
  last_refreshed = tonumber(data[2])
  local elapsed = math.max(0, now - last_refreshed)
  current_tokens = math.min(capacity, current_tokens + (elapsed * refill_rate_per_ms))
end

if current_tokens >= requested then
  current_tokens = current_tokens - requested
  redis.call('HMSET', key, 'tokens', current_tokens, 'last_refreshed', now)
  redis.call('EXPIRE', key, 120)
  return {1, math.floor(current_tokens), 0}
else
  local missing = requested - current_tokens
  local retry_after = math.ceil(missing / (refill_rate_per_ms * 1000))
  return {0, math.floor(current_tokens), math.max(1, retry_after)}
end
`;

class TokenBucketLimiter {
  constructor({ capacity = 15, refillRatePerMinute = 15, redisClient = redis } = {}) {
    this.capacity = capacity;
    this.refillRatePerMinute = refillRatePerMinute;
    this.refillRatePerMs = refillRatePerMinute / (60 * 1000);
    this.redis = redisClient;
    this.inMemoryBuckets = new Map();

    // Dọn dẹp bộ nhớ in-memory mỗi 5 phút
    this.cleanupInterval = setInterval(() => {
      const now = Date.now();
      for (const [key, bucket] of this.inMemoryBuckets.entries()) {
        if (now - bucket.lastRefreshed > 120000) {
          this.inMemoryBuckets.delete(key);
        }
      }
    }, 5 * 60 * 1000);

    if (this.cleanupInterval.unref) {
      this.cleanupInterval.unref();
    }
  }

  /**
   * Tiêu thụ token cho một key định danh
   * @param {string} key 
   * @param {number} tokens 
   * @returns {Promise<{ allowed: boolean, remaining: number, retryAfterSeconds: number }>}
   */
  async consume(key, tokens = 1) {
    const prefixedKey = `ratelimit:chatbot:${key}`;
    const now = Date.now();

    if (this.redis && this.redis.status === 'ready') {
      try {
        const [allowed, remaining, retryAfter] = await this.redis.eval(
          LUA_TOKEN_BUCKET,
          1,
          prefixedKey,
          this.capacity,
          this.refillRatePerMs,
          now,
          tokens
        );

        return {
          allowed: allowed === 1,
          remaining: Math.max(0, remaining),
          retryAfterSeconds: retryAfter || 0,
        };
      } catch (err) {
        logger.warn(`[TokenBucket] Redis error, fallback sang in-memory: ${err.message}`);
      }
    }

    return this.consumeInMemory(key, tokens, now);
  }

  /**
   * Fallback in-memory Token Bucket khi Redis không sẵn sàng
   */
  consumeInMemory(key, tokens = 1, now = Date.now()) {
    let bucket = this.inMemoryBuckets.get(key);

    if (!bucket) {
      bucket = {
        tokens: this.capacity,
        lastRefreshed: now,
      };
    } else {
      const elapsed = Math.max(0, now - bucket.lastRefreshed);
      bucket.tokens = Math.min(this.capacity, bucket.tokens + elapsed * this.refillRatePerMs);
      bucket.lastRefreshed = now;
    }

    if (bucket.tokens >= tokens) {
      bucket.tokens -= tokens;
      this.inMemoryBuckets.set(key, bucket);
      return {
        allowed: true,
        remaining: Math.floor(bucket.tokens),
        retryAfterSeconds: 0,
      };
    } else {
      const missing = tokens - bucket.tokens;
      const retryAfter = Math.ceil(missing / (this.refillRatePerMs * 1000));
      this.inMemoryBuckets.set(key, bucket);
      return {
        allowed: false,
        remaining: Math.max(0, Math.floor(bucket.tokens)),
        retryAfterSeconds: Math.max(1, retryAfter),
      };
    }
  }
}

// Khởi tạo instance mặc định 15 req/phút
const defaultLimiter = new TokenBucketLimiter({
  capacity: 15,
  refillRatePerMinute: 15,
  redisClient: redis,
});

/**
 * Middleware Express giới hạn tần suất chat
 */
function redisTokenBucketLimiter(req, res, next) {
  const key = req.user?.idaccount ? `account_${req.user.idaccount}` : req.ip;

  defaultLimiter.consume(key, 1)
    .then(result => {
      res.setHeader('X-RateLimit-Limit', defaultLimiter.capacity);
      res.setHeader('X-RateLimit-Remaining', result.remaining);

      if (!result.allowed) {
        res.setHeader('Retry-After', result.retryAfterSeconds);
        return res.status(429).json({
          success: false,
          message: `Bạn đang gửi yêu cầu quá nhanh (giới hạn 15 tin nhắn/phút). Vui lòng thử lại sau ${result.retryAfterSeconds} giây.`,
        });
      }

      next();
    })
    .catch(err => {
      logger.error('[RateLimiter] Error consuming token:', err);
      next(); // Cho qua nếu limiter gặp lỗi nội bộ để không chặn người dùng
    });
}

module.exports = {
  TokenBucketLimiter,
  defaultLimiter,
  redisTokenBucketLimiter,
};
