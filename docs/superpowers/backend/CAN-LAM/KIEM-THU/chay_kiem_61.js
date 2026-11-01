// Kịch bản nghiệm thu đơn 61 (61.1, 61.2, 61.3, 61.4). KHÔNG cần CSDL, KHÔNG gọi Gemini, KHÔNG gửi thư:
// config/db, SDK Gemini và household.service đều bị thay bằng bản giả ngay trong tiến trình này.
// Cách chạy (từ src/Backend):
//   node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_61.js . kq_61.txt
// Dòng cuối phải là "6 đạt / 6 ca". Có ca hỏng thì mã thoát 1.
const path = require('path');
const fs = require('fs');

const ROOT = path.resolve(process.argv[2] || '.');
const DST = process.argv[3];

const cam = (rel, exportsObj) => {
  const f = path.join(ROOT, rel);
  require.cache[f] = { id: f, filename: f, loaded: true, exports: exportsObj, children: [], paths: [] };
};
cam('config/db.js', { prisma: { user: { findFirst: async () => ({ fullname: 'Nguoi Thu' }) } }, pool: {} });

let loiGemini = null;
class GeminiGia {
  getGenerativeModel() {
    return {
      startChat: () => ({
        sendMessageStream: async () => {
          throw loiGemini;
        },
      }),
    };
  }
}
const duongSdk = require.resolve('@google/generative-ai', { paths: [ROOT] });
require.cache[duongSdk] = { id: duongSdk, filename: duongSdk, loaded: true, exports: { GoogleGenerativeAI: GeminiGia }, children: [], paths: [] };

const daMoi = [];
cam('modules/household/household.service.js', {
  createEmailInvite: async (_id, { email }) => {
    daMoi.push(email);
    return { sent: true, email };
  },
});

process.env.GEMINI_API_KEY = 'khoa-gia';
const ChatbotService = require(path.join(ROOT, 'modules/ai/features/chatbot/chatbot.service'));
const { CircuitBreaker, geminiCircuitBreaker: cauDao } = require(path.join(ROOT, 'modules/ai/features/chatbot/resilience/circuit-breaker'));
const householdController = require(path.join(ROOT, 'modules/household/household.controller'));

const LOI_HET_GIO = '[GoogleGenerativeAI Error]: Request aborted when fetching https://generativelanguage.googleapis.com/x: This operation was aborted';

const datLaiCauDao = () => {
  cauDao.state = 'CLOSED';
  cauDao.failureCount = 0;
  cauDao.lastFailureTime = 0;
  cauDao.openedAt = 0;
};

async function hoi(signal) {
  const dv = new ChatbotService();
  dv.snapshotService = { generateSnapshot: async () => null };
  dv._streamFallbackResponse = async (_m, _s, _c, onDone, reason) => onDone({ fallback: true, reason });
  let done = null;
  await dv.chatStream({ message: 'cau hoi', history: [], idaccount: 1, signal, onChunk: () => {}, onMeta: () => {}, onDone: (d) => { done = d; } });
  return done;
}

const nghi = (ms) => new Promise((r) => setTimeout(r, ms));

async function moi(email) {
  let ma = null;
  const res = { status(s) { ma = s; return this; }, json() { return this; } };
  await householdController.createEmailInvite({ body: { email, role: 'Member' }, user: { idaccount: 1 } }, res);
  return ma;
}

const CA = [
  ['61.2 Gemini hết giờ 60 s (signal client chưa ngắt): phải có done kèm fallback, luồng không được treo', async () => {
    datLaiCauDao();
    loiGemini = new Error(LOI_HET_GIO);
    const done = await hoi(new AbortController().signal);
    if (!done) throw new Error('không gọi onDone: client treo tới khi tự bỏ');
    if (done.fallback !== true) throw new Error(`done không có fallback: ${JSON.stringify(done)}`);
  }],
  ['61.2 Gemini hết giờ vẫn được cầu dao đếm là một lỗi', async () => {
    datLaiCauDao();
    loiGemini = new Error(LOI_HET_GIO);
    await hoi(new AbortController().signal);
    if (cauDao.failureCount !== 1) throw new Error(`failureCount = ${cauDao.failureCount}, phải là 1`);
  }],
  ['61.3 Người dùng Dừng 6 lần: cầu dao vẫn CLOSED, bộ đếm 0, không gọi onDone', async () => {
    datLaiCauDao();
    loiGemini = new Error(LOI_HET_GIO);
    for (let i = 0; i < 6; i++) {
      const ac = new AbortController();
      ac.abort();
      const done = await hoi(ac.signal);
      if (done) throw new Error(`lượt ${i + 1} vẫn gọi onDone`);
    }
    if (cauDao.state !== 'CLOSED') throw new Error(`state = ${cauDao.state}: Dừng đã đóng chatbot của mọi tài khoản`);
    if (cauDao.failureCount !== 0) throw new Error(`failureCount = ${cauDao.failureCount}, phải là 0`);
  }],
  ['61.3 Người dùng Dừng lúc đang thăm dò HALF-OPEN: không quay lại OPEN', async () => {
    datLaiCauDao();
    cauDao.state = 'HALF-OPEN';
    loiGemini = new Error(LOI_HET_GIO);
    const ac = new AbortController();
    ac.abort();
    await hoi(ac.signal);
    if (cauDao.state === 'OPEN') throw new Error('Dừng của một người đã mở lại cầu dao');
  }],
  ['61.4 Hai lỗi cách nhau quá windowMs không cộng dồn', async () => {
    const cd = new CircuitBreaker({ failureThreshold: 3, cooldownPeriodMs: 1000, windowMs: 40 });
    const hong = async () => { throw new Error('loi that'); };
    for (let i = 0; i < 3; i++) {
      await cd.execute(hong).catch(() => {});
      await nghi(80);
    }
    if (cd.state !== 'CLOSED') throw new Error(`state = ${cd.state}, ba lỗi rời rạc đã mở cầu dao`);
    if (cd.failureCount !== 1) throw new Error(`failureCount = ${cd.failureCount}, phải là 1`);
    // Sau khoảng nghỉ, lỗi đầu tính lại từ 1, nên cần đúng ba lỗi liền nhau mới mở.
    for (let i = 0; i < 3; i++) await cd.execute(hong).catch(() => {});
    if (cd.state !== 'OPEN') throw new Error('ba lỗi liền nhau trong cửa sổ phải mở cầu dao');
  }],
  ['61.1 Email có dấu trả 400 và không tạo lời mời; email thường vẫn 202', async () => {
    daMoi.length = 0;
    const co = await moi('an@flowmoney.tét');
    if (co !== 400) throw new Error(`an@flowmoney.tét trả ${co}, phải là 400`);
    if (daMoi.length !== 0) throw new Error('đã gọi createEmailInvite với địa chỉ có dấu');
    const khong = await moi('an@flowmoney.test');
    if (khong !== 202) throw new Error(`an@flowmoney.test trả ${khong}, phải là 202`);
  }],
];

(async () => {
  const dong = [];
  let dat = 0;
  for (const [ten, chay] of CA) {
    try {
      await chay();
      dat++;
      dong.push(`ĐẠT  ${ten}`);
    } catch (e) {
      dong.push(`HỎNG ${ten}\n     ${e.message}`);
    }
  }
  dong.push(`${dat} đạt / ${CA.length} ca`);
  const chu = `${dong.join('\n')}\n`;
  process.stdout.write(chu);
  if (DST) fs.writeFileSync(DST, chu);
  process.exit(dat === CA.length ? 0 : 1);
})();
