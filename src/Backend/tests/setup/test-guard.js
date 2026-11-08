/**
 * Rào chắn của bộ test, nạp bằng `node --require` trong các lệnh `npm test*`.
 *
 * `.env` trỏ Supabase dùng chung và Redis Railway; nhiều test dùng repository thật nên chạy trần sẽ ghi dữ liệu thật.
 * Rào làm hai việc, tiến trình con của `node --test` thừa hưởng cả hai:
 *  1. Đặt biến môi trường trước khi `dotenv` chạy (dotenv không ghi đè), nên CSDL, Redis, LLM không trỏ tới dịch vụ thật.
 *     Prisma dùng engine gốc, không đi qua `net` của Node, nên lớp này là thứ chặn được nó.
 *  2. Chặn mọi kết nối TCP/TLS ra ngoài loopback.
 *
 * Test cần CSDL thật: đặt TEST_DATABASE_URL trỏ CSDL thử trên máy này; không đặt thì các test đó đỏ vì không kết nối được.
 */

const net = require('net');
const path = require('path');

const LOOPBACK = new Set(['127.0.0.1', '::1', '[::1]', 'localhost', '0.0.0.0', '::']);
const DEAD_PG = 'postgresql://guard:guard@127.0.0.1:1/guard?connect_timeout=1';
const DEAD_REDIS = 'redis://127.0.0.1:1';
const INSTALLED = Symbol.for('flowmoney.testGuard');

/**
 * Cờ tường minh cho vài test cần CSDL thật khi không có CSDL thử (`npm run test:shared-db`): giữ CSDL trong `.env` và chỉ
 * mở đúng máy + cổng đó. Các test này GHI THẬT, không dùng cho cả bộ.
 */
function sharedDatabase() {
  if (process.env.TEST_USE_SHARED_DB !== '1') return null;
  require('dotenv').config({ path: path.join(__dirname, '..', '..', '.env') });
  const clean = (v) => String(v || '').trim().replace(/^["']|["']$/g, '');
  const url = clean(process.env.DATABASE_URL);
  if (!url) {
    process.stderr.write('[test-guard] TEST_USE_SHARED_DB=1 nhưng không có DATABASE_URL. Dừng.\n');
    process.exit(1);
  }
  const allowed = [url, clean(process.env.DIRECT_URL)].filter(Boolean).map((u) => {
    const parsed = new URL(u);
    return { host: parsed.hostname.toLowerCase(), port: Number(parsed.port || 5432) };
  });
  return { url, direct: clean(process.env.DIRECT_URL) || url, allowed };
}

function resolveDatabaseUrl() {
  const url = process.env.TEST_DATABASE_URL;
  if (!url) return DEAD_PG;
  let host;
  try {
    host = new URL(url).hostname;
  } catch (_) {
    process.stderr.write('[test-guard] TEST_DATABASE_URL không phải URL hợp lệ. Dừng.\n');
    process.exit(1);
  }
  if (!LOOPBACK.has(host.toLowerCase())) {
    process.stderr.write(`[test-guard] TEST_DATABASE_URL phải trỏ CSDL trên máy này, đang trỏ ${host}. Dừng.\n`);
    process.exit(1);
  }
  return url;
}

function targetOf(args) {
  let first = args[0];
  if (Array.isArray(first)) first = first[0]; // net.connect() chuyển vào đây dạng mảng đã chuẩn hoá
  if (first && typeof first === 'object') {
    return first.path ? null : { host: first.host || 'localhost', port: first.port };
  }
  if (typeof first === 'number' || (typeof first === 'string' && /^\d+$/.test(first))) {
    return { host: typeof args[1] === 'string' ? args[1] : 'localhost', port: first };
  }
  return null; // đường dẫn pipe / IPC
}

function installNetGuard(allowed = []) {
  if (net.Socket.prototype[INSTALLED]) return;
  const original = net.Socket.prototype.connect;
  net.Socket.prototype[INSTALLED] = true;
  net.Socket.prototype.connect = function guardedConnect(...args) {
    const target = targetOf(args);
    if (!target || LOOPBACK.has(String(target.host).toLowerCase())) return original.apply(this, args);
    if (allowed.some((a) => a.host === String(target.host).toLowerCase() && a.port === Number(target.port))) {
      return original.apply(this, args);
    }
    const err = Object.assign(new Error(`NET_GUARD chặn kết nối ra ngoài: ${target.host}:${target.port}`), { code: 'ECONNREFUSED' });
    process.nextTick(() => this.destroy(err));
    return this;
  };
}

const shared = sharedDatabase();
const databaseUrl = shared ? shared.url : resolveDatabaseUrl();
const self =path.resolve(__filename).replace(/\\/g, '/');
const nodeOptions = process.env.NODE_OPTIONS || '';

Object.assign(process.env, {
  FLOWMONEY_TEST_GUARD: '1',
  DATABASE_URL: databaseUrl,
  DIRECT_URL: shared ? shared.direct : databaseUrl,
  REDIS_PROVIDER: 'local',
  REDIS_URL: DEAD_REDIS,
  REDIS_LOCAL_URL: DEAD_REDIS,
  REDIS_RAILWAY_URL: DEAD_REDIS,
  REDIS_UPSTASH_URL: DEAD_REDIS,
  DEEPSEEK_API_KEY: 'sk-guard',
  DEEPSEEK_BASE_URL: 'http://127.0.0.1:1',
  GEMINI_API_KEY: 'guard',
  // NCKH: .env bản thực nghiệm bật truy hồi lai; test không được nạp mô hình nhúng thật (test hybrid tự tiêm bộ nhúng giả)
  NCKH_RETRIEVAL: 'lexical',
  NODE_OPTIONS: nodeOptions.includes(self) ? nodeOptions : `${nodeOptions} --require="${self}"`.trim(),
});

installNetGuard(shared ? shared.allowed : []);
