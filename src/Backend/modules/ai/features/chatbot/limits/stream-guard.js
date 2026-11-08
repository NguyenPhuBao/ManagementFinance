/**
 * Giới hạn số luồng SSE chạy đồng thời của Chatbot AI (dịch vụ nặng, mỗi luồng giữ kết nối + gọi LLM).
 * `acquire` trả hàm nhả slot (an toàn khi gọi nhiều lần) hoặc `null` khi đã hết chỗ.
 */

class StreamGuard {
  constructor({ perUser = 1, global = 30 } = {}) {
    this.perUser = perUser;
    this.global = global;
    this.byUser = new Map();
    this.total = 0;
  }

  acquire(idaccount) {
    const current = this.byUser.get(idaccount) || 0;
    if (current >= this.perUser || this.total >= this.global) return null;

    this.byUser.set(idaccount, current + 1);
    this.total += 1;

    let released = false;
    return () => {
      if (released) return;
      released = true;
      const left = (this.byUser.get(idaccount) || 1) - 1;
      if (left <= 0) this.byUser.delete(idaccount);
      else this.byUser.set(idaccount, left);
      this.total = Math.max(0, this.total - 1);
    };
  }
}

module.exports = { StreamGuard };
