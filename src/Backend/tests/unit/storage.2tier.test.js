const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const storageMod = require('../../core/storage');

const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3]);
const JPG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
const PDF = Buffer.from('%PDF-1.7\n...');
const WEBP = Buffer.concat([Buffer.from('RIFF'), Buffer.from([0, 0, 0, 0]), Buffer.from('WEBPVP8 ')]);
const FAKE = Buffer.from('<html>khong phai anh</html>');

const fakeRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  return res;
};

describe('Tầng 1: chọn chế độ lưu trữ và nhận diện loại tệp', () => {
  it('không có khóa Supabase thì dùng local; có đủ khóa thì dùng supabase; STORAGE_DRIVER ghi đè', () => {
    assert.strictEqual(storageMod.resolveDriverName({}), 'local');
    assert.strictEqual(storageMod.resolveDriverName({ SUPABASE_URL: 'https://x.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'k' }), 'supabase');
    assert.strictEqual(storageMod.resolveDriverName({ SUPABASE_URL: 'https://x.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'k', STORAGE_DRIVER: 'local' }), 'local');
    assert.strictEqual(storageMod.resolveDriverName({ STORAGE_DRIVER: 'supabase' }), 'local', 'thiếu khóa thì không thể dùng supabase');
  });

  it('nhận diện loại tệp theo nội dung, không theo đuôi tên', () => {
    assert.deepStrictEqual(storageMod.detectFileType(PNG), { ext: 'png', mime: 'image/png' });
    assert.deepStrictEqual(storageMod.detectFileType(JPG), { ext: 'jpg', mime: 'image/jpeg' });
    assert.deepStrictEqual(storageMod.detectFileType(PDF), { ext: 'pdf', mime: 'application/pdf' });
    assert.deepStrictEqual(storageMod.detectFileType(WEBP), { ext: 'webp', mime: 'image/webp' });
    assert.strictEqual(storageMod.detectFileType(FAKE), null);
    assert.strictEqual(storageMod.detectFileType(null), null);
  });

  it('isStorageRef / parseRef chỉ nhận khóa của kho, giữ nguyên đường dẫn http và đường dẫn cũ', () => {
    assert.ok(storageMod.isStorageRef('sb://refund-proofs/a/b.png'));
    assert.ok(storageMod.isStorageRef('local://refund-proofs/a/b.png'));
    assert.ok(!storageMod.isStorageRef('https://x/y.png'));
    assert.ok(!storageMod.isStorageRef('/assets/Refunds/x.png'));
    assert.deepStrictEqual(storageMod.parseRef('sb://refund-proofs/a/b.png'), { scheme: 'sb', bucket: 'refund-proofs', key: 'a/b.png' });
  });
});

describe('Tầng 2: chế độ local ghi, đọc, ký đường dẫn, xóa thật trên đĩa', () => {
  let dir;
  beforeEach(() => { dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fm-storage-')); });
  afterEach(() => fs.rmSync(dir, { recursive: true, force: true }));

  it('put → tệp có trên đĩa; download trả đúng nội dung; signedUrl là đường dẫn tĩnh; remove xóa tệp', async () => {
    const s = storageMod.createStorage({ env: { STORAGE_LOCAL_DIR: dir } });
    assert.strictEqual(s.driver, 'local');
    const ref = await s.put({ bucket: 'refund-proofs', key: 'don-1/abc.png', buffer: PNG, contentType: 'image/png' });
    assert.strictEqual(ref, 'local://refund-proofs/don-1/abc.png');
    assert.ok(fs.existsSync(path.join(dir, 'refund-proofs', 'don-1', 'abc.png')));
    assert.deepStrictEqual(await s.download(ref), PNG);
    assert.strictEqual(await s.signedUrl(ref, 600), '/assets/Storage/refund-proofs/don-1/abc.png');
    await s.remove(ref);
    assert.ok(!fs.existsSync(path.join(dir, 'refund-proofs', 'don-1', 'abc.png')));
  });

  it('khóa có ".." bị từ chối (không ghi ra ngoài thư mục kho)', async () => {
    const s = storageMod.createStorage({ env: { STORAGE_LOCAL_DIR: dir } });
    await assert.rejects(() => s.put({ bucket: 'refund-proofs', key: '../thoat.png', buffer: PNG, contentType: 'image/png' }));
  });
});

describe('Tầng 2: chế độ supabase gọi đúng REST API của Storage', () => {
  const env = { SUPABASE_URL: 'https://demo.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'eyJhbGciOi.khoa-cu-bi-mat' };
  const makeHttp = () => {
    const calls = [];
    const http = async (cfg) => {
      calls.push(cfg);
      if (cfg.url.includes('/object/sign/')) return { data: { signedURL: '/object/sign/refund-proofs/don-1/abc.png?token=TK' } };
      if (cfg.method === 'get') return { data: PNG };
      return { data: { Key: 'ok' } };
    };
    return { http, calls };
  };

  it('put tải lên đúng bucket / khóa, có khóa dịch vụ trong header, không ghi đè', async () => {
    const { http, calls } = makeHttp();
    const s = storageMod.createStorage({ env, http });
    const ref = await s.put({ bucket: 'refund-proofs', key: 'don-1/abc.png', buffer: PNG, contentType: 'image/png' });
    assert.strictEqual(ref, 'sb://refund-proofs/don-1/abc.png');
    const c = calls[0];
    assert.strictEqual(c.method, 'post');
    assert.strictEqual(c.url, 'https://demo.supabase.co/storage/v1/object/refund-proofs/don-1/abc.png');
    assert.strictEqual(c.headers.Authorization, 'Bearer eyJhbGciOi.khoa-cu-bi-mat');
    assert.strictEqual(c.headers['Content-Type'], 'image/png');
    assert.strictEqual(c.headers['x-upsert'], 'false');
    assert.strictEqual(c.data, PNG);
  });

  it('khóa dạng mới sb_secret_: chỉ gửi header apikey, không gửi Authorization Bearer (khóa không phải JWT)', async () => {
    const { http, calls } = makeHttp();
    const s = storageMod.createStorage({ env: { ...env, SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_khoa-moi' }, http });
    await s.put({ bucket: 'refund-proofs', key: 'don-1/abc.png', buffer: PNG, contentType: 'image/png' });
    await s.signedUrl('sb://refund-proofs/don-1/abc.png', 60);
    for (const c of calls) {
      assert.strictEqual(c.headers.apikey, 'sb_secret_khoa-moi');
      assert.ok(!('Authorization' in c.headers), 'không gửi Authorization với khóa sb_secret_');
    }
  });

  it('signedUrl ký với thời hạn yêu cầu, trả đường dẫn tuyệt đối, không chứa khóa dịch vụ', async () => {
    const { http, calls } = makeHttp();
    const s = storageMod.createStorage({ env, http });
    const url = await s.signedUrl('sb://refund-proofs/don-1/abc.png', 600);
    assert.strictEqual(calls[0].url, 'https://demo.supabase.co/storage/v1/object/sign/refund-proofs/don-1/abc.png');
    assert.deepStrictEqual(calls[0].data, { expiresIn: 600 });
    assert.strictEqual(url, 'https://demo.supabase.co/storage/v1/object/sign/refund-proofs/don-1/abc.png?token=TK');
    assert.ok(!url.includes('khoa-cu-bi-mat'));
  });

  it('download đọc nhị phân; remove xóa đúng khóa; ensureBucket tạo bucket riêng tư', async () => {
    const { http, calls } = makeHttp();
    const s = storageMod.createStorage({ env, http });
    const buf = await s.download('sb://refund-proofs/don-1/abc.png');
    assert.deepStrictEqual(Buffer.from(buf), PNG);
    assert.strictEqual(calls[0].responseType, 'arraybuffer');
    await s.remove('sb://refund-proofs/don-1/abc.png');
    assert.strictEqual(calls[1].method, 'delete');
    assert.deepStrictEqual(calls[1].data, { prefixes: ['don-1/abc.png'] });
    await s.ensureBucket('refund-proofs', { fileSizeLimit: 5 * 1024 * 1024 });
    assert.strictEqual(calls[2].url, 'https://demo.supabase.co/storage/v1/bucket');
    assert.strictEqual(calls[2].data.public, false);
  });
});

describe('Tầng 2: hoàn tiền lưu minh chứng vào kho, admin nhận đường dẫn tạm', () => {
  const paymentController = require('../../modules/payment/payment.controller');
  const paymentService = require('../../modules/payment/payment.service');
  const paymentRepository = require('../../modules/payment/payment.repository');
  let dir;
  const orig = {};

  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fm-refund-'));
    storageMod.setStorageForTest(storageMod.createStorage({ env: { STORAGE_LOCAL_DIR: dir } }));
    orig.process = paymentService.processOrderRefund;
    orig.detail = paymentRepository.getOrderDetailForAdmin;
  });
  afterEach(() => {
    storageMod.setStorageForTest(null);
    paymentService.processOrderRefund = orig.process;
    paymentRepository.getOrderDetailForAdmin = orig.detail;
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('tệp hợp lệ: lưu vào bucket refund-proofs theo mã đơn, truyền khóa kho cho service', async () => {
    let got;
    paymentService.processOrderRefund = async (id, data) => { got = { id, data }; return { ok: true }; };
    const req = { params: { id: 'order-123456789' }, body: { refundedAmount: '50000' }, file: { buffer: PNG, originalname: 'a.png', mimetype: 'image/png', size: PNG.length } };
    const res = fakeRes();
    await paymentController.processRefund(req, res, (e) => { throw e; });
    assert.strictEqual(res.statusCode, 200);
    assert.match(got.data.refundProof, /^local:\/\/refund-proofs\/order-123456789\/[a-f0-9-]+\.png$/);
    const key = storageMod.parseRef(got.data.refundProof).key;
    assert.ok(fs.existsSync(path.join(dir, 'refund-proofs', ...key.split('/'))));
  });

  it('tệp giả (đuôi .jpg nhưng nội dung không phải ảnh) bị từ chối 400, không lưu', async () => {
    let called = false;
    paymentService.processOrderRefund = async () => { called = true; };
    const req = { params: { id: 'order-1' }, body: { refundedAmount: '50000' }, file: { buffer: FAKE, originalname: 'a.jpg', mimetype: 'image/jpeg', size: FAKE.length } };
    const res = fakeRes();
    await paymentController.processRefund(req, res, (e) => { throw e; });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(called, false);
    assert.ok(!fs.existsSync(path.join(dir, 'refund-proofs')));
  });

  it('chi tiết đơn cho admin: khóa kho đổi thành đường dẫn tạm; đường dẫn http giữ nguyên', async () => {
    paymentRepository.getOrderDetailForAdmin = async () => ({ id: 'o1', status: 'REFUNDED', refund_proof: 'local://refund-proofs/o1/x.png' });
    const order = await paymentService.getOrderDetailForAdmin('o1');
    assert.strictEqual(order.refund_proof, '/assets/Storage/refund-proofs/o1/x.png');
    paymentRepository.getOrderDetailForAdmin = async () => ({ id: 'o2', status: 'REFUNDED', refund_proof: 'https://ngan-hang/x.png' });
    assert.strictEqual((await paymentService.getOrderDetailForAdmin('o2')).refund_proof, 'https://ngan-hang/x.png');
  });

  it('middleware tải lên giữ tệp trong bộ nhớ, không ghi ra ổ đĩa', () => {
    const src = fs.readFileSync(require.resolve('../../middleware/upload.middleware'), 'utf8');
    assert.ok(!src.includes('diskStorage'), 'không còn diskStorage');
    assert.match(src, /memoryStorage\(\)/);
  });
});
