const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { isOriginAllowed, createCorsOriginValidator } = require('../../config/cors');

describe('CORS Origin Resolver & Validator Suite', () => {
  it('1. Cho phép request không có origin (Mobile app, Server-to-server, cURL)', () => {
    assert.equal(isOriginAllowed(undefined, []), true);
    assert.equal(isOriginAllowed(null, []), true);
    assert.equal(isOriginAllowed('', []), true);
  });

  it('2. Cho phép nếu configuredOrigins là wildcard *', () => {
    assert.equal(isOriginAllowed('https://any-site.com', '*'), true);
  });

  it('3. Cho phép các origin khớp chính xác cấu hình', () => {
    const configured = ['https://my-domain.com', 'https://custom-admin.vercel.app'];
    assert.equal(isOriginAllowed('https://my-domain.com', configured), true);
    assert.equal(isOriginAllowed('https://custom-admin.vercel.app', configured), true);
    assert.equal(isOriginAllowed('https://unrelated.com', configured), false);
  });

  it('4. Tự động cho phép localhost mọi cổng và 127.0.0.1 cho dev', () => {
    assert.equal(isOriginAllowed('http://localhost:5173', []), true);
    assert.equal(isOriginAllowed('http://localhost:3000', []), true);
    assert.equal(isOriginAllowed('http://localhost:8080', []), true);
    assert.equal(isOriginAllowed('http://127.0.0.1:5173', []), true);
  });

  it('5. Tự động cho phép tất cả các domain Vercel của dự án', () => {
    assert.equal(isOriginAllowed('https://management-finance-gamma.vercel.app', []), true);
    assert.equal(isOriginAllowed('https://managementfinance-admin.vercel.app', []), true);
    assert.equal(isOriginAllowed('https://managementfinance.vercel.app', []), true);
    assert.equal(isOriginAllowed('https://management-finance-git-branch.vercel.app', []), true);
    // Không cho phép các domain vercel khác
    assert.equal(isOriginAllowed('https://some-other-project.vercel.app', []), false);
    assert.equal(isOriginAllowed('https://evil-site.com', []), false);
  });

  it('6. createCorsOriginValidator trả về callback tương thích chuẩn', (t, done) => {
    const validator = createCorsOriginValidator(['https://custom.com']);

    // Allowed
    validator('https://management-finance-gamma.vercel.app', (err, allowed) => {
      assert.equal(err, null);
      assert.equal(allowed, true);

      // Disallowed
      validator('https://malicious.com', (err2, allowed2) => {
        assert.equal(err2, null);
        assert.equal(allowed2, false);
        done();
      });
    });
  });
});
