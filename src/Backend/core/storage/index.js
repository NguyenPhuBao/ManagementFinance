const fs = require('fs');
const path = require('path');
const axios = require('axios');
const logger = require('../logger');

const BUCKETS = { REFUND_PROOFS: 'refund-proofs', DATA_EXPORTS: 'data-exports' };
const DEFAULT_LOCAL_DIR = path.join(__dirname, '..', '..', 'Assets', 'Storage');
const REF_PATTERN = /^(sb|local):\/\/([a-z0-9-]+)\/(.+)$/;

const clean = (v) => String(v || '').trim().replace(/^["']|["']$/g, '');

function resolveDriverName(env = process.env) {
  const hasKeys = Boolean(clean(env.SUPABASE_URL) && clean(env.SUPABASE_SERVICE_ROLE_KEY));
  const wanted = clean(env.STORAGE_DRIVER).toLowerCase();
  if (wanted === 'local') return 'local';
  return hasKeys ? 'supabase' : 'local';
}

function detectFileType(buffer) {
  if (!buffer || buffer.length < 4) return null;
  const b = Buffer.from(buffer);
  if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) return { ext: 'png', mime: 'image/png' };
  if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return { ext: 'jpg', mime: 'image/jpeg' };
  if (b.subarray(0, 5).toString('latin1') === '%PDF-') return { ext: 'pdf', mime: 'application/pdf' };
  if (b.length >= 12 && b.subarray(0, 4).toString('latin1') === 'RIFF' && b.subarray(8, 12).toString('latin1') === 'WEBP') {
    return { ext: 'webp', mime: 'image/webp' };
  }
  return null;
}

const isStorageRef = (value) => typeof value === 'string' && REF_PATTERN.test(value);

function parseRef(ref) {
  const m = String(ref || '').match(REF_PATTERN);
  if (!m) throw new Error('Khóa lưu trữ không hợp lệ');
  return { scheme: m[1], bucket: m[2], key: m[3] };
}

function assertSafeKey(bucket, key) {
  if (!/^[a-z0-9-]+$/.test(bucket)) throw new Error('Tên bucket không hợp lệ');
  if (!key || key.startsWith('/') || key.split('/').some((p) => p === '..' || p === '.' || p === '')) {
    throw new Error('Khóa tệp không hợp lệ');
  }
}

function createLocalStorage(env) {
  const base = clean(env.STORAGE_LOCAL_DIR) || DEFAULT_LOCAL_DIR;
  const fileOf = (bucket, key) => path.join(base, bucket, ...key.split('/'));
  return {
    driver: 'local',
    async put({ bucket, key, buffer }) {
      assertSafeKey(bucket, key);
      const file = fileOf(bucket, key);
      await fs.promises.mkdir(path.dirname(file), { recursive: true });
      await fs.promises.writeFile(file, buffer, { flag: 'wx' });
      return `local://${bucket}/${key}`;
    },
    async signedUrl(ref) {
      const { bucket, key } = parseRef(ref);
      return `/assets/Storage/${bucket}/${key}`;
    },
    async download(ref) {
      const { bucket, key } = parseRef(ref);
      return fs.promises.readFile(fileOf(bucket, key));
    },
    async remove(ref) {
      const { bucket, key } = parseRef(ref);
      await fs.promises.rm(fileOf(bucket, key), { force: true });
    },
    async ensureBucket() {
      return undefined;
    },
  };
}

function createSupabaseStorage(env, http) {
  const baseUrl = `${clean(env.SUPABASE_URL).replace(/\/+$/, '')}/storage/v1`;
  const serviceKey = clean(env.SUPABASE_SERVICE_ROLE_KEY);
  const auth = serviceKey.startsWith('eyJ') ? { Authorization: `Bearer ${serviceKey}`, apikey: serviceKey } : { apikey: serviceKey };
  const objectPath = (bucket, key) => `${bucket}/${key.split('/').map(encodeURIComponent).join('/')}`;
  return {
    driver: 'supabase',
    async put({ bucket, key, buffer, contentType }) {
      assertSafeKey(bucket, key);
      await http({
        method: 'post',
        url: `${baseUrl}/object/${objectPath(bucket, key)}`,
        headers: { ...auth, 'Content-Type': contentType || 'application/octet-stream', 'x-upsert': 'false' },
        data: buffer,
        maxBodyLength: Infinity,
      });
      return `sb://${bucket}/${key}`;
    },
    async signedUrl(ref, expiresIn = 600) {
      const { bucket, key } = parseRef(ref);
      const res = await http({
        method: 'post',
        url: `${baseUrl}/object/sign/${objectPath(bucket, key)}`,
        headers: { ...auth, 'Content-Type': 'application/json' },
        data: { expiresIn },
      });
      const signed = res?.data?.signedURL || res?.data?.signedUrl;
      if (!signed) throw new Error('Không ký được đường dẫn tải tệp');
      return `${baseUrl}${signed.startsWith('/') ? '' : '/'}${signed}`;
    },
    async download(ref) {
      const { bucket, key } = parseRef(ref);
      const res = await http({ method: 'get', url: `${baseUrl}/object/${objectPath(bucket, key)}`, headers: auth, responseType: 'arraybuffer' });
      return Buffer.from(res.data);
    },
    async remove(ref) {
      const { bucket, key } = parseRef(ref);
      await http({ method: 'delete', url: `${baseUrl}/object/${bucket}`, headers: { ...auth, 'Content-Type': 'application/json' }, data: { prefixes: [key] } });
    },
    async ensureBucket(bucket, { fileSizeLimit, allowedMimeTypes } = {}) {
      try {
        await http({
          method: 'post',
          url: `${baseUrl}/bucket`,
          headers: { ...auth, 'Content-Type': 'application/json' },
          data: { id: bucket, name: bucket, public: false, file_size_limit: fileSizeLimit, allowed_mime_types: allowedMimeTypes },
        });
        return 'created';
      } catch (err) {
        const status = err?.response?.status;
        const text = JSON.stringify(err?.response?.data || '');
        if (status === 409 || /already exists|Duplicate/i.test(text)) return 'exists';
        throw err;
      }
    },
  };
}

function createStorage({ env = process.env, http = axios } = {}) {
  return resolveDriverName(env) === 'supabase' ? createSupabaseStorage(env, http) : createLocalStorage(env);
}

let instance = null;
let warned = false;

function getStorage() {
  if (!instance) {
    instance = createStorage();
    if (instance.driver === 'local' && process.env.NODE_ENV === 'production' && !warned) {
      warned = true;
      logger.error('[Storage] Production đang lưu tệp trên ổ đĩa máy chủ: thiếu SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY. Tệp sẽ mất khi deploy lại.');
    }
  }
  return instance;
}

function setStorageForTest(storage) {
  instance = storage;
}

async function resolveUrl(value, expiresIn = 600) {
  if (!isStorageRef(value)) return value;
  try {
    return await getStorage().signedUrl(value, expiresIn);
  } catch (err) {
    logger.warn('[Storage] Không ký được đường dẫn tệp', { error: err.message });
    return null;
  }
}

module.exports = {
  BUCKETS,
  resolveDriverName,
  detectFileType,
  isStorageRef,
  parseRef,
  createStorage,
  getStorage,
  setStorageForTest,
  resolveUrl,
};
