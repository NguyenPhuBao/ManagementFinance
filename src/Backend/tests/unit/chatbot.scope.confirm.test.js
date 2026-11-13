/**
 * Unit Test — Xác nhận phạm vi bằng AI trước khi loại câu hỏi (PO 2026-11-09).
 * Bộ lọc từ khoá chặn câu nào thì hỏi AI thêm đúng một câu: "có thuộc phạm vi tài chính không". Có dòng "CÓ" thì giữ
 * câu hỏi (vừa có vừa không thì giữ câu có); "KHÔNG", mơ hồ hay lỗi dịch vụ thì loại như cũ.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const { parseScopeVerdict, confirmScope } = require('../../modules/ai/features/chatbot/scope/scope-confirm');

function fakeLlm(text, usage = { prompt_tokens: 180, completion_tokens: 12 }) {
  const calls = [];
  const fn = async function* llm(p) {
    calls.push(p);
    yield { type: 'text', text };
    yield { type: 'done', usage, finishReason: 'stop' };
  };
  fn.calls = calls;
  return fn;
}
const CFG = { apiKey: 'k', model: 'm', baseUrl: 'http://x' };

describe('parseScopeVerdict — đọc câu trả lời CÓ / KHÔNG', () => {
  it('1. "CÓ - lý do" thì cho qua và giữ lý do', () => {
    assert.deepStrictEqual(parseScopeVerdict('CÓ - hỏi cách tính lãi kép khi gửi tiết kiệm'), { allowed: true, reason: 'hỏi cách tính lãi kép khi gửi tiết kiệm' });
  });

  it('2. "KHÔNG - lý do" thì loại', () => {
    assert.strictEqual(parseScopeVerdict('KHÔNG - yêu cầu làm thơ, không liên quan tới tiền').allowed, false);
  });

  it('3. Vừa có vừa không thì giữ câu CÓ', () => {
    assert.deepStrictEqual(parseScopeVerdict('KHÔNG - phần viết mã\nCÓ - phần tính trả góp là chuyện tiền'), { allowed: true, reason: 'phần tính trả góp là chuyện tiền' });
  });

  it('4. Rỗng hoặc mơ hồ thì loại', () => {
    for (const t of ['', '   ', 'Tôi không chắc', 'Câu hỏi này khá thú vị']) assert.strictEqual(parseScopeVerdict(t).allowed, false, t);
  });

  it('5. Chấp nhận chữ thường, dấu đậm, gạch dài, dấu hai chấm; lý do một dòng, tối đa 200 ký tự', () => {
    assert.strictEqual(parseScopeVerdict('**Có** – đầu tư cổ phiếu là chuyện tiền').allowed, true);
    assert.strictEqual(parseScopeVerdict('có: bài toán lãi suất').reason, 'bài toán lãi suất');
    assert.ok(parseScopeVerdict(`CÓ - ${'x'.repeat(500)}`).reason.length <= 200);
    assert.strictEqual(parseScopeVerdict('Cổ phiếu là gì').allowed, false); // "Cổ" không phải "Có"
  });
});

describe('confirmScope — một lần gọi AI ngắn, chỉ để xác nhận', () => {
  it('1. Gửi câu hỏi đã che thông tin cá nhân, không công cụ, ít token; CÓ thì cho qua; ghi chi phí thật', async () => {
    const llm = fakeLlm('CÓ - hỏi bài toán lãi kép');
    const usage = [];
    const r = await confirmScope({ message: 'Giải bài toán lãi kép, gọi tôi số 0912345678', userName: '', llm, cfg: CFG, onUsage: (u) => usage.push(u) });
    assert.deepStrictEqual(r, { allowed: true, reason: 'hỏi bài toán lãi kép' });
    const p = llm.calls[0];
    assert.strictEqual(p.tools, undefined);
    assert.ok(p.maxTokens > 0 && p.maxTokens <= 80, `maxTokens ${p.maxTokens}`);
    assert.strictEqual(p.messages[0].role, 'system');
    assert.match(p.messages[0].content, /CÓ/);
    assert.ok(!p.messages[1].content.includes('0912345678'), 'chưa che số điện thoại');
    assert.strictEqual(usage.length, 1);
    assert.ok(usage[0].costMicroUsd > 0);
  });

  it('2. KHÔNG thì loại', async () => {
    const r = await confirmScope({ message: 'Viết giúp tôi bài thơ', llm: fakeLlm('KHÔNG - sáng tác thơ'), cfg: CFG });
    assert.strictEqual(r.allowed, false);
  });

  it('3. Dịch vụ AI lỗi thì loại như trước, không ném lỗi ra ngoài', async () => {
    const llm = async function* boom() { throw new Error('mạng hỏng'); }; // eslint-disable-line require-yield
    const r = await confirmScope({ message: 'Giải bài toán lãi kép', llm, cfg: CFG });
    assert.strictEqual(r.allowed, false);
  });

  it('4. Chưa cấu hình khoá dịch vụ AI thì không gọi, loại như trước', async () => {
    const llm = fakeLlm('CÓ - x');
    const r = await confirmScope({ message: 'Giải bài toán lãi kép', llm, cfg: { apiKey: '' } });
    assert.strictEqual(r.allowed, false);
    assert.strictEqual(llm.calls.length, 0);
  });
});
