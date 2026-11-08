/**
 * Unit Test — Rào chắn của bộ test: `.env` trỏ Supabase dùng chung và Redis Railway, nên chạy test không có rào từng ghi
 * dữ liệu thật (phát hiện 2026-11-08). Mọi tiến trình con ở đây dùng địa chỉ không tới được, kể cả khi rào hỏng.
 */

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const http = require('node:http');
const https = require('node:https');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');

const BACKEND = path.resolve(__dirname, '..', '..');
const GUARD = path.join(BACKEND, 'tests', 'setup', 'test-guard.js');
const DEAD_PG = 'postgresql://x:y@127.0.0.1:1/x';
const DEAD_REDIS = 'redis://127.0.0.1:1';

/** Môi trường sạch: không thừa hưởng rào của tiến trình hiện tại. */
function cleanEnv(extra = {}) {
  const env = { PATH: process.env.PATH, SystemRoot: process.env.SystemRoot, TEMP: process.env.TEMP, TMP: process.env.TMP };
  return { ...env, ...extra };
}
const SAFE = { DATABASE_URL: DEAD_PG, DIRECT_URL: DEAD_PG, REDIS_PROVIDER: 'local', REDIS_URL: DEAD_REDIS, REDIS_LOCAL_URL: DEAD_REDIS };

function runNode(args, env) {
  return spawnSync(process.execPath, args, { cwd: BACKEND, env, encoding: 'utf8', timeout: 60000 });
}

const blocked = (start) => new Promise((resolve) => {
  start((err) => resolve(err));
});

describe('Rào chắn trong tiến trình đang chạy', () => {
  it('1. Dịch vụ thật bị thay: CSDL và Redis trỏ loopback, LLM trỏ loopback', () => {
    assert.strictEqual(process.env.FLOWMONEY_TEST_GUARD, '1');
    for (const key of ['DATABASE_URL', 'DIRECT_URL', 'REDIS_URL', 'REDIS_LOCAL_URL', 'DEEPSEEK_BASE_URL']) {
      assert.ok(['127.0.0.1', 'localhost', '[::1]'].includes(new URL(process.env[key]).hostname), `${key} phải là loopback`);
    }
    assert.strictEqual(process.env.REDIS_PROVIDER, 'local');
  });

  it('2. Kết nối TCP ra ngoài bị chặn', async () => {
    const err = await blocked((done) => {
      const s = net.connect({ host: '203.0.113.1', port: 5432 });
      s.on('error', done);
      s.on('connect', () => { s.destroy(); done(null); });
    });
    assert.ok(err, 'phải lỗi');
    assert.match(err.message, /NET_GUARD/);
  });

  it('2b. Dạng socket.connect(cổng, máy) mà gói pg dùng cũng bị chặn', async () => {
    const err = await blocked((done) => {
      const s = new net.Socket();
      s.on('error', done);
      s.on('connect', () => { s.destroy(); done(null); });
      s.connect(5432, '203.0.113.1');
    });
    assert.ok(err, 'phải lỗi');
    assert.match(err.message, /NET_GUARD/);
  });

  it('3. HTTPS và HTTP ra ngoài bị chặn', async () => {
    for (const client of [https, http]) {
      const err = await blocked((done) => {
        const req = client.request({ host: 'api.example.com', port: 443, method: 'GET' }, () => done(null));
        req.on('error', done);
        req.end();
      });
      assert.ok(err, 'phải lỗi');
      assert.match(err.message, /NET_GUARD/);
    }
  });

  it('4. fetch ra ngoài bị chặn', async () => {
    await assert.rejects(fetch('https://api.example.com/x'), (e) => /NET_GUARD/.test(`${e.message} ${e.cause?.message}`));
  });

  it('5. Loopback không bị chặn: lỗi là của hệ điều hành, không phải của rào', async () => {
    const err = await blocked((done) => {
      const s = net.connect({ host: '127.0.0.1', port: 1 });
      s.on('error', done);
      s.on('connect', () => { s.destroy(); done(null); });
    });
    assert.ok(err, 'cổng 1 không có dịch vụ');
    assert.doesNotMatch(err.message, /NET_GUARD/);
  });
});

describe('Rào chắn nạp vào tiến trình mới', () => {
  let dir;
  before(() => { dir = fs.mkdtempSync(path.join(os.tmpdir(), 'test-guard-')); });
  after(() => fs.rmSync(dir, { recursive: true, force: true }));

  const PRINT_DB = 'console.log("HOST="+new URL(process.env.DATABASE_URL).hostname)';

  it('1. TEST_DATABASE_URL trỏ máy ngoài: dừng ngay, không lộ mật khẩu', () => {
    const r = runNode(['--require', GUARD, '-e', PRINT_DB], cleanEnv({ TEST_DATABASE_URL: 'postgresql://nguoi:matkhaubimat@db.abc.supabase.com:5432/x' }));
    assert.strictEqual(r.status, 1);
    assert.match(r.stderr, /TEST_DATABASE_URL/);
    assert.ok(!`${r.stdout}${r.stderr}`.includes('matkhaubimat'));
    assert.ok(!r.stdout.includes('HOST='));
  });

  it('2. TEST_DATABASE_URL hỏng: dừng ngay', () => {
    const r = runNode(['--require', GUARD, '-e', PRINT_DB], cleanEnv({ TEST_DATABASE_URL: 'khong-phai-url' }));
    assert.strictEqual(r.status, 1);
  });

  it('3. TEST_DATABASE_URL cục bộ: được dùng làm cả DATABASE_URL lẫn DIRECT_URL', () => {
    const code = 'console.log(process.env.DATABASE_URL===process.env.TEST_DATABASE_URL, process.env.DIRECT_URL===process.env.TEST_DATABASE_URL)';
    const r = runNode(['--require', GUARD, '-e', code], cleanEnv({ TEST_DATABASE_URL: 'postgresql://a:b@127.0.0.1:5432/flowmoney_kiem_thu' }));
    assert.strictEqual(r.status, 0, r.stderr);
    assert.strictEqual(r.stdout.trim(), 'true true');
  });

  it('4. `.env` trỏ Supabase không thắng được rào (dotenv không ghi đè)', () => {
    const envFile = path.join(dir, 'gia.env');
    fs.writeFileSync(envFile, 'DATABASE_URL=postgresql://a:b@db.abc.supabase.com:5432/x\nREDIS_URL=redis://a.proxy.rlwy.net:1\n');
    const code = `require(${JSON.stringify(path.join(BACKEND, 'node_modules', 'dotenv'))}).config({path:${JSON.stringify(envFile)}});console.log(new URL(process.env.DATABASE_URL).hostname, new URL(process.env.REDIS_URL).hostname)`;
    const r = runNode(['--require', GUARD, '-e', code], cleanEnv());
    assert.strictEqual(r.status, 0, r.stderr);
    assert.strictEqual(r.stdout.trim(), '127.0.0.1 127.0.0.1');
  });

  it('4b. Cờ dùng CSDL dùng chung: giữ DATABASE_URL, chỉ mở đúng máy CSDL, Redis và LLM vẫn bị chặn', () => {
    const code = `
      const net = require('net');
      const probe = (host, port) => new Promise((res) => { const s = net.connect({ host, port }); s.on('error', (e) => res(e.message)); s.on('connect', () => { s.destroy(); res('connected'); }); });
      (async () => {
        const db = await probe('db.invalid', 5432);
        const other = await probe('203.0.113.1', 5432);
        const sameHostOtherPort = await probe('db.invalid', 443);
        console.log(JSON.stringify({ url: process.env.DATABASE_URL, redis: process.env.REDIS_URL, llm: process.env.DEEPSEEK_BASE_URL, db, other, sameHostOtherPort }));
        process.exit(0);
      })();`;
    const url = 'postgresql://a:b@db.invalid:5432/x';
    const r = runNode(['--require', GUARD, '-e', code], cleanEnv({ TEST_USE_SHARED_DB: '1', DATABASE_URL: url, DIRECT_URL: url }));
    assert.strictEqual(r.status, 0, r.stderr);
    const o = JSON.parse(r.stdout);
    assert.strictEqual(o.url, url);
    assert.doesNotMatch(o.db, /NET_GUARD/, 'máy CSDL phải được đi qua (lỗi DNS là của hệ điều hành)');
    assert.match(o.other, /NET_GUARD/);
    assert.match(o.sameHostOtherPort, /NET_GUARD/);
    assert.strictEqual(new URL(o.redis).hostname, '127.0.0.1');
    assert.strictEqual(new URL(o.llm).hostname, '127.0.0.1');
  });

  it('4c. Không có cờ: DATABASE_URL có sẵn trong môi trường vẫn bị thay', () => {
    const r = runNode(['--require', GUARD, '-e', PRINT_DB], cleanEnv({ DATABASE_URL: 'postgresql://a:b@db.invalid:5432/x' }));
    assert.strictEqual(r.stdout.trim(), 'HOST=127.0.0.1');
  });

  it('5. Tiến trình con của `node --test` được thừa hưởng rào', () => {
    const f = path.join(dir, 'con.test.js');
    fs.writeFileSync(f, `
      const { it } = require('node:test'); const assert = require('node:assert'); const net = require('node:net');
      it('con', async () => {
        assert.strictEqual(process.env.FLOWMONEY_TEST_GUARD, '1');
        const err = await new Promise((res) => { const s = net.connect({ host: '203.0.113.1', port: 80 }); s.on('error', res); s.on('connect', () => res(null)); });
        assert.match(String(err && err.message), /NET_GUARD/);
      });`);
    const r = runNode(['--require', GUARD, '--test', '--test-force-exit', f], cleanEnv());
    assert.strictEqual(r.status, 0, `${r.stdout}\n${r.stderr}`);
  });

  it('6. `node --test` không có rào mà nạp config/db: dừng với hướng dẫn, trước khi tạo kết nối', () => {
    const f = path.join(dir, 'tran-db.test.js');
    fs.writeFileSync(f, `require(${JSON.stringify(path.join(BACKEND, 'config', 'db.js'))});
      require('node:test').it('khong duoc toi day', () => { console.log('DA_NAP_DUOC'); });`);
    const r = runNode(['--test', '--test-force-exit', f], cleanEnv(SAFE));
    assert.notStrictEqual(r.status, 0);
    assert.match(`${r.stdout}${r.stderr}`, /npm test/);
    assert.ok(!r.stdout.includes('DA_NAP_DUOC'));
  });

  it('7. `node --test` không có rào mà nạp config/redis.resolver: cũng dừng', () => {
    const f = path.join(dir, 'tran-redis.test.js');
    fs.writeFileSync(f, `require(${JSON.stringify(path.join(BACKEND, 'config', 'redis.resolver.js'))});
      require('node:test').it('khong duoc toi day', () => { console.log('DA_NAP_DUOC'); });`);
    const r = runNode(['--test', '--test-force-exit', f], cleanEnv(SAFE));
    assert.notStrictEqual(r.status, 0);
    assert.match(`${r.stdout}${r.stderr}`, /npm test/);
  });

  it('8. Chạy ngoài bộ test (ứng dụng, script): config/db nạp bình thường', () => {
    const code = `require(${JSON.stringify(path.join(BACKEND, 'config', 'db.js'))});console.log('NAP_XONG');process.exit(0)`;
    const r = runNode(['-e', code], cleanEnv(SAFE));
    assert.strictEqual(r.status, 0, r.stderr);
    assert.ok(r.stdout.includes('NAP_XONG'));
  });
});
