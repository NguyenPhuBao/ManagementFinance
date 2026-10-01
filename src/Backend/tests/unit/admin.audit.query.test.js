/**
 * Test: Admin Audit Logs Query
 * Kiểm tra hàm getAuditLogs phân trang, giới hạn cap 200, và trả đúng shape
 */
const { describe, it } = require('node:test');
const assert = require('node:assert');
const adminService = require('../../modules/admin/admin.service');

describe('getAuditLogs', () => {
  it('should return paginated data with items, total, page, limit', async () => {
    const result = await adminService.getAuditLogs({ page: 1, limit: 10 });
    assert.ok(result, 'Result should exist');
    assert.ok('items' in result, 'Should have items');
    assert.ok('total' in result, 'Should have total');
    assert.strictEqual(result.page, 1);
    assert.strictEqual(result.limit, 10);
    assert.ok(Array.isArray(result.items), 'items should be an array');
  });

  it('should cap limit at 200', async () => {
    const result = await adminService.getAuditLogs({ page: 1, limit: 9999 });
    assert.ok(result.limit <= 200, 'limit should be <= 200');
  });
});
