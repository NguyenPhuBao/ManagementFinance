/**
 * Hạn mức lời nhắc Chatbot AI theo người dùng theo ngày (giờ Việt Nam, UTC+7).
 *
 * Bộ đếm nằm ở Redis (INCR + EXPIRE). Redis lỗi hoặc chưa sẵn sàng thì rơi về bộ đếm trong bộ nhớ —
 * KHÔNG mở toang (khác bộ giới hạn tần suất, cố ý fail-open): đây là lớp bảo vệ chi phí.
 */

const VN_OFFSET_MS = 7 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
const KEY_TTL_SECONDS = 2 * 24 * 60 * 60;

class UsageQuota {
  constructor({ redis = null, now = () => new Date() } = {}) {
    this.redis = redis;
    this.now = now;
    this.memory = new Map(); // key -> số lần
  }

  _vnNow() {
    return new Date(this.now().getTime() + VN_OFFSET_MS);
  }

  _dayKey() {
    const d = this._vnNow();
    const y = d.getUTCFullYear();
    const m = String(d.getUTCMonth() + 1).padStart(2, '0');
    const day = String(d.getUTCDate()).padStart(2, '0');
    return `${y}${m}${day}`;
  }

  _secondsToVnMidnight() {
    const vn = this._vnNow().getTime();
    return Math.max(1, Math.ceil((DAY_MS - (vn % DAY_MS)) / 1000));
  }

  _sweepMemory(currentDay) {
    for (const key of this.memory.keys()) {
      if (!key.endsWith(`:${currentDay}`)) this.memory.delete(key);
    }
  }

  /**
   * Tính một lượt cho người dùng.
   * @param {number|string} idaccount
   * @param {number} limit - số lượt tối đa mỗi ngày
   * @returns {Promise<{ allowed: boolean, used: number, limit: number, retryAfterSeconds: number }>}
   */
  async consume(idaccount, limit) {
    const day = this._dayKey();
    const key = `ai:quota:${idaccount}:${day}`;
    let used;
    let store = 'redis';

    if (this.redis && this.redis.status === 'ready') {
      try {
        used = await this.redis.incr(key);
        if (used === 1) await this.redis.expire(key, KEY_TTL_SECONDS);
      } catch (_) {
        used = undefined;
      }
    }

    if (used === undefined) {
      store = 'memory';
      this._sweepMemory(day);
      used = (this.memory.get(key) || 0) + 1;
      this.memory.set(key, used);
    }

    return {
      allowed: used <= limit,
      used,
      limit,
      retryAfterSeconds: used <= limit ? 0 : this._secondsToVnMidnight(),
      key,
      store,
    };
  }

  /**
   * Trả lại một lượt đã trừ khi lỗi do hệ thống (PO chốt 2026-11-08). Hoàn vào đúng khoá ngày và đúng nơi đã đếm
   * (trừ lúc 23:59 mà lỗi sau 0 giờ thì không giảm lượt của ngày mới). Không xuống dưới 0.
   * @param {{ key: string, store: 'redis'|'memory' }} consumed - kết quả của consume()
   */
  async refund(consumed) {
    const key = consumed?.key;
    if (!key) return;
    if (consumed.store === 'redis') {
      if (!this.redis || this.redis.status !== 'ready') return;
      try {
        const left = await this.redis.decr(key);
        if (left < 0) await this.redis.incrby(key, -left);
      } catch (_) { /* hoàn hỏng thì người dùng mất một lượt, không chặn luồng chính */ }
      return;
    }
    const left = (this.memory.get(key) || 0) - 1;
    if (left > 0) this.memory.set(key, left);
    else this.memory.delete(key);
  }
}

module.exports = { UsageQuota };
