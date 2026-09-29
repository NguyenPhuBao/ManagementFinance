/**
 * Unit Test — DB Bulkhead & Connection Pool Headroom (TDD)
 */

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const { DbBulkhead } = require('../../core/resilience/db-bulkhead');

describe('Resilience — DB Bulkhead: Phân chia hạn ngạch kết nối CSDL Supabase', () => {
  let bulkhead;

  beforeEach(() => {
    bulkhead = new DbBulkhead({
      maxConnections: 10,
      clientQuotaPercent: 80, // 80% cho Client, 20% cho Admin
    });
  });

  it('1. Cho phép Client mượn kết nối khi còn trong hạn ngạch 80%', () => {
    assert.strictEqual(bulkhead.canAcquire('client'), true);
    bulkhead.acquire('client');
    assert.strictEqual(bulkhead.activeClientConnections, 1);
  });

  it('2. Chặn Client khi đã dùng hết 80% (8 kết nối), nhưng Admin vẫn được phép mượn (20% Headroom)', () => {
    // Chiếm dụng đủ 8 kết nối cho client
    for (let i = 0; i < 8; i++) {
      assert.strictEqual(bulkhead.canAcquire('client'), true);
      bulkhead.acquire('client');
    }

    assert.strictEqual(bulkhead.activeClientConnections, 8);
    // Request thứ 9 của client phải bị từ chối
    assert.strictEqual(bulkhead.canAcquire('client'), false, 'Client không được vượt quá 80% quota');

    // Nhưng Admin vẫn được phép mượn trong khoang 20% còn lại
    assert.strictEqual(bulkhead.canAcquire('admin'), true, 'Admin phải được phép mượn từ 20% Headroom');
    bulkhead.acquire('admin');
    assert.strictEqual(bulkhead.activeAdminConnections, 1);
  });

  it('3. Giải phóng kết nối hoàn trả đúng hạn ngạch khi xong việc', () => {
    bulkhead.acquire('client');
    assert.strictEqual(bulkhead.activeClientConnections, 1);
    bulkhead.release('client');
    assert.strictEqual(bulkhead.activeClientConnections, 0);
  });
});
