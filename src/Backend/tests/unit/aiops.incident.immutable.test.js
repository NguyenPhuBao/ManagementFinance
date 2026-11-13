const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const { AIOpsIncidentRepository } = require('../../modules/aiops/aiops.repository');
const aiopsController = require('../../modules/aiops/aiops.controller');

describe('Nhật ký sự cố AIOps không có đường xóa toàn bộ', () => {
  it('không còn route, hàm controller, hàm repository xóa toàn bộ sự cố', () => {
    const routes = fs.readFileSync(require.resolve('../../api/admin.routes'), 'utf8');
    assert.ok(!routes.includes('incidents/clear'), 'route POST /aiops/incidents/clear phải bị bỏ');
    assert.strictEqual(aiopsController.clearIncidents, undefined);
    assert.strictEqual(AIOpsIncidentRepository.prototype.clearIncidents, undefined);
    const repoSrc = fs.readFileSync(require.resolve('../../modules/aiops/aiops.repository'), 'utf8');
    assert.ok(!/DELETE FROM "aiops_incident"/.test(repoSrc), 'không câu SQL nào xóa toàn bộ aiops_incident');
  });
});
