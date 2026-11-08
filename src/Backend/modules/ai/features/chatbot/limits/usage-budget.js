/**
 * Ngân sách chi phí AI theo người dùng theo THÁNG (giờ Việt Nam), tính bằng micro-USD thật từ `usage`.
 *
 * Giới hạn số lượt mỗi ngày không chặn được lỗ: số đo thật cho thấy một lượt "xấu nhất" tốn gấp nhiều lần lượt
 * thường. Ngân sách tiền mới là trần cứng của thiệt hại theo từng người dùng.
 * Redis lỗi hoặc chưa sẵn sàng thì rơi về bộ nhớ (không mở toang).
 */

const VN_OFFSET_MS = 7 * 60 * 60 * 1000;
const KEY_TTL_SECONDS = 40 * 24 * 60 * 60;

class UsageBudget {
  constructor({ redis = null, now = () => new Date() } = {}) {
    this.redis = redis;
    this.now = now;
    this.memory = new Map();
  }

  _vn() {
    return new Date(this.now().getTime() + VN_OFFSET_MS);
  }

  _monthKey() {
    const d = this._vn();
    return `${d.getUTCFullYear()}${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
  }

  /** Giây còn lại tới 0 giờ ngày 1 tháng sau (giờ VN). */
  secondsToNextMonth() {
    const d = this._vn();
    const next = Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1);
    return Math.max(1, Math.ceil((next - d.getTime()) / 1000));
  }

  /** Số ngày còn lại của tháng, tính cả hôm nay (giờ VN). */
  daysLeftInMonth() {
    const d = this._vn();
    const lastDay = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
    return lastDay - d.getUTCDate() + 1;
  }

  _key(idaccount) {
    return `ai:budget:${idaccount}:${this._monthKey()}`;
  }

  async spent(idaccount) {
    const key = this._key(idaccount);
    if (this.redis && this.redis.status === 'ready') {
      try {
        const v = await this.redis.get(key);
        return v === null || v === undefined ? (this.memory.get(key) || 0) : Number(v) || 0;
      } catch (_) { /* rơi về bộ nhớ */ }
    }
    return this.memory.get(key) || 0;
  }

  async add(idaccount, microUsd) {
    const amount = Math.round(Number(microUsd));
    if (!Number.isFinite(amount) || amount <= 0) return;
    const key = this._key(idaccount);

    if (this.redis && this.redis.status === 'ready') {
      try {
        const total = await this.redis.incrby(key, amount);
        if (total === amount) await this.redis.expire(key, KEY_TTL_SECONDS);
        return;
      } catch (_) { /* rơi về bộ nhớ */ }
    }
    for (const k of this.memory.keys()) {
      if (!k.endsWith(`:${this._monthKey()}`)) this.memory.delete(k);
    }
    this.memory.set(key, (this.memory.get(key) || 0) + amount);
  }
}

module.exports = { UsageBudget };
