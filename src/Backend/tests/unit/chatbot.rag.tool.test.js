/**
 * Unit Test — Truy hồi là một công cụ do mô hình tự gọi, và các biện pháp ĐẢM BẢO RAG (PO duyệt 2026-11-08):
 *  (1) luật trong prompt; (2) cổng ép tra cứu ở vòng đầu cho câu rõ ràng là hỏi kiến thức; (3) máy chủ gắn nguồn khi mô
 *  hình quên; (4) sự kiện báo công cụ đang chạy. Đồng thời phủ chuỗi đa bước kiến thức → số liệu → trả lời.
 *
 * Tầng 1: khai báo công cụ, kết quả công cụ, văn bản prompt.
 * Tầng 2: yêu cầu thật gửi cho nhà cung cấp (tool_choice, messages), sự kiện SSE ghi ra phản hồi, nội dung người dùng nhận.
 */

const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');

const ChatbotService = require('../../modules/ai/features/chatbot/chatbot.service');
const ToolsExecutor = require('../../modules/ai/features/chatbot/tools/tools.executor');
const LexicalKnowledgeSearch = require('../../modules/ai/features/chatbot/rag/lexical.search');
const { financialToolsDeclarations, KNOWLEDGE_TOOL_NAME } = require('../../modules/ai/features/chatbot/tools/financial.tools');
const { buildSystemPrompt } = require('../../modules/ai/features/chatbot/prompts/advisor.system.prompt');
const { streamDeepseek, toOpenAiTools } = require('../../modules/ai/features/chatbot/llm/deepseek.provider');
const { CircuitBreaker } = require('../../modules/ai/features/chatbot/resilience/circuit-breaker');

const KNOWLEDGE_QUESTION = 'Mức giảm trừ gia cảnh thuế thu nhập cá nhân hiện nay là bao nhiêu?';
const PERSONAL_QUESTION = 'tháng này tôi chi bao nhiêu';

describe('Khai báo công cụ tra cứu', () => {
  it('1. Có trong danh sách công cụ, nhận tham số query bắt buộc, chuyển được sang định dạng nhà cung cấp', () => {
    assert.strictEqual(KNOWLEDGE_TOOL_NAME, 'tra_cuu_kien_thuc');
    const decl = financialToolsDeclarations.find((t) => t.name === KNOWLEDGE_TOOL_NAME);
    assert.ok(decl, 'phải có khai báo');
    assert.ok(decl.parameters.properties.query);
    assert.deepStrictEqual(decl.parameters.required, ['query']);
    const openAi = toOpenAiTools(financialToolsDeclarations).find((t) => t.function.name === KNOWLEDGE_TOOL_NAME);
    assert.strictEqual(openAi.function.parameters.type, 'object');
  });
});

describe('ToolsExecutor — thực thi tra cứu trên kho thật', () => {
  const exec = new ToolsExecutor();

  it('1. Tìm thấy: trả các đoạn kèm mã đoạn và chuỗi trích nguồn', async () => {
    const r = await exec.executeTool(KNOWLEDGE_TOOL_NAME, { query: 'giảm trừ gia cảnh thuế thu nhập cá nhân' }, 5);
    assert.strictEqual(r.found, true);
    assert.ok(r.results.length >= 1 && r.results.length <= 3);
    const [first] = r.results;
    assert.ok(first.chunkId.startsWith('thue_'));
    assert.ok(first.citation.startsWith('[Nguồn: '));
    assert.ok(first.content.length > 0);
  });

  it('2. Không thấy: found=false và nhắc không được tự suy đoán', async () => {
    const r = await exec.executeTool(KNOWLEDGE_TOOL_NAME, { query: 'cách nấu phở bò ngon' }, 5);
    assert.strictEqual(r.found, false);
    assert.deepStrictEqual(r.results, []);
    assert.ok(r.note && r.note.length > 0);
  });

  it('3. Thiếu query: found=false, không ném lỗi', async () => {
    const r = await exec.executeTool(KNOWLEDGE_TOOL_NAME, {}, 5);
    assert.strictEqual(r.found, false);
  });

  it('4. Vừa trần ký tự: bỏ cả đoạn xếp sau chứ không cắt giữa đoạn, luôn giữ đoạn đầu', async () => {
    const q = 'tiết kiệm chi tiêu nợ thuế thu nhập quy tắc';
    const full = await exec.executeTool(KNOWLEDGE_TOOL_NAME, { query: q }, 5);
    assert.ok(full.results.length >= 2, 'cần ít nhất 2 đoạn để kiểm tra cắt');
    const firstLen = JSON.stringify({ found: true, results: [full.results[0]] }).length;
    const r = await exec.executeTool(KNOWLEDGE_TOOL_NAME, { query: q }, 5, { maxResultChars: firstLen + 10 });
    assert.strictEqual(r.results.length, 1);
    assert.strictEqual(r.results[0].chunkId, full.results[0].chunkId);
    assert.strictEqual(r.results[0].content, full.results[0].content);
    assert.ok(JSON.stringify(r).length <= firstLen + 10);
  });
});

describe('LexicalKnowledgeSearch.shouldForceLookup — cổng ép tra cứu (ưu tiên độ chính xác)', () => {
  const engine = new LexicalKnowledgeSearch();

  it('1. Câu rõ ràng hỏi kiến thức thì ép', () => {
    for (const q of [
      KNOWLEDGE_QUESTION,
      'quy tắc 50/30/20 là gì',
      'phương pháp hòn tuyết lăn là gì',
      'giảm trừ gia cảnh',
      'biểu thuế thu nhập cá nhân có mấy bậc',
    ]) {
      assert.strictEqual(engine.shouldForceLookup(q), true, `phải ép: ${q}`);
    }
  });

  it('2. Câu về số liệu của chính người dùng thì KHÔNG ép (tránh tốn thêm một lần gọi LLM)', () => {
    for (const q of [
      PERSONAL_QUESTION,
      'chi tiêu ăn uống của tôi tháng này thế nào',
      'hóa đơn nào sắp đến hạn',
      'so sánh chi tiêu tháng này với tháng trước',
      'tôi có nên mua xe không',
      'mục tiêu mua nhà của tôi còn bao lâu',
      'tình hình tài chính của tôi thế nào',
      'khoản chi lớn nhất tháng này của tôi là gì',
      'tiết kiệm mỗi tháng 5 triệu thì bao lâu đủ mua xe',
      'thu nhập tháng này của tôi là bao nhiêu',
      'tôi đang nợ bao nhiêu',
      'xin chào',
    ]) {
      assert.strictEqual(engine.shouldForceLookup(q), false, `không được ép: ${q}`);
    }
  });

  it('3. Đầu vào hỏng không ném lỗi', () => {
    assert.strictEqual(engine.shouldForceLookup(''), false);
    assert.strictEqual(engine.shouldForceLookup(null), false);
  });
});

describe('Prompt — bỏ chèn tài liệu, thêm luật tra cứu', () => {
  it('1. Không còn khối tài liệu tham khảo; có luật bắt buộc tra cứu và luật khi không tìm thấy', () => {
    const p = buildSystemPrompt(null);
    assert.ok(!p.includes('KNOWLEDGE BASE'));
    assert.ok(p.includes(KNOWLEDGE_TOOL_NAME));
    assert.ok(p.includes('citation'));
    assert.ok(p.includes('found=false'));
  });

  it('1b. Cấm lộ tên công cụ, tên trường kỹ thuật; không tìm thấy thì không ghi dòng nguồn (lỗi thấy khi chạy thật)', () => {
    const p = buildSystemPrompt(null);
    assert.ok(p.includes('Không nhắc tên công cụ hay tên trường dữ liệu'));
    assert.ok(p.includes('không ghi dòng nguồn'));
  });

  it('2. Tham số thứ hai cũ bị bỏ qua, tài liệu không lọt vào prompt', () => {
    assert.ok(!buildSystemPrompt(null, 'BI_MAT_TAI_LIEU').includes('BI_MAT_TAI_LIEU'));
  });
});

describe('streamDeepseek — tham số toolChoice', () => {
  const tools = toOpenAiTools(financialToolsDeclarations);
  const base = { apiKey: 'k', model: 'm', messages: [], maxTokens: 10, timeoutMs: 5000 };
  const fetchRecording = (bodies) => async (_url, init) => {
    bodies.push(JSON.parse(init.body));
    return new Response('data: [DONE]\n\n', { status: 200 });
  };
  const drain = async (gen) => { for await (const _ of gen) { /* bỏ qua */ } };

  it('1. Mặc định auto khi có công cụ', async () => {
    const bodies = [];
    await drain(streamDeepseek({ ...base, tools, fetchImpl: fetchRecording(bodies) }));
    assert.strictEqual(bodies[0].tool_choice, 'auto');
  });

  it('2. Chỉ định hàm cụ thể thì gửi đúng dạng', async () => {
    const bodies = [];
    const choice = { type: 'function', function: { name: KNOWLEDGE_TOOL_NAME } };
    await drain(streamDeepseek({ ...base, tools, toolChoice: choice, fetchImpl: fetchRecording(bodies) }));
    assert.deepStrictEqual(bodies[0].tool_choice, choice);
  });

  it('3. Không có công cụ thì không gửi tool_choice', async () => {
    const bodies = [];
    await drain(streamDeepseek({ ...base, toolChoice: { type: 'function', function: { name: 'x' } }, fetchImpl: fetchRecording(bodies) }));
    assert.strictEqual(bodies[0].tool_choice, undefined);
    assert.strictEqual(bodies[0].tools, undefined);
  });
});

describe('ChatbotService — đường chạy của truy hồi', () => {
  const keys = ['CHATBOT_LLM_PROVIDER', 'DEEPSEEK_API_KEY', 'AI_MAX_TURN_COST_MICRO_USD', 'AI_MAX_TOOL_ROUNDS'];
  const saved = {};
  beforeEach(() => {
    keys.forEach((k) => { saved[k] = process.env[k]; delete process.env[k]; });
    process.env.CHATBOT_LLM_PROVIDER = 'deepseek';
    process.env.DEEPSEEK_API_KEY = 'sk-test';
  });
  afterEach(() => keys.forEach((k) => { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; }));

  const text = (t) => ({ type: 'text', text: t });
  const done = () => ({ type: 'done', finishReason: 'stop', toolCalls: [], usage: { prompt_tokens: 10, completion_tokens: 2 } });
  const callDone = (calls) => ({ type: 'done', finishReason: 'tool_calls', toolCalls: calls, usage: { prompt_tokens: 10, completion_tokens: 2 } });
  const lookup = (id, query) => ({ id, name: KNOWLEDGE_TOOL_NAME, args: JSON.stringify({ query }) });

  /** Dùng ToolsExecutor thật cho tra cứu; công cụ số liệu được giả lập để không chạm CSDL. */
  function makeService(rounds) {
    const svc = new ChatbotService();
    svc.snapshotService = { generateSnapshot: async () => null };
    svc._getUserName = async () => '';
    svc.breaker = new CircuitBreaker({});
    svc._requests = [];
    svc._toolLog = [];
    const real = svc.toolsExecutor;
    svc.toolsExecutor = {
      executeTool: async (name, args, id, opts) => {
        svc._toolLog.push({ name, args });
        return name === KNOWLEDGE_TOOL_NAME ? real.executeTool(name, args, id, opts) : { ok: true };
      },
    };
    let i = 0;
    svc.deepseekStream = async function* (args) {
      svc._requests.push(args);
      for (const ev of rounds[Math.min(i++, rounds.length - 1)]) yield ev;
    };
    return svc;
  }

  async function run(svc, over = {}) {
    const chunks = [];
    const tools = [];
    let doneArg;
    await svc.chatStream({
      message: KNOWLEDGE_QUESTION,
      idaccount: 5,
      onChunk: (c) => chunks.push(c),
      onDone: (d) => { doneArg = d; },
      onTool: (e) => tools.push(e),
      ...over,
    });
    return { text: chunks.join(''), chunks, tools, done: doneArg };
  }

  it('1. Prompt không còn chứa nội dung kho kể cả khi câu hỏi đúng chủ đề (tiết kiệm token, đúng nghĩa công cụ động)', async () => {
    const svc = makeService([[callDone([lookup('c1', 'giảm trừ gia cảnh')])], [text('Trả lời.'), done()]]);
    await run(svc);
    const system = svc._requests[0].messages[0].content;
    assert.ok(!system.includes('MỨC GIẢM TRỪ GIA CẢNH'));
  });

  it('2. Câu kiến thức: vòng đầu ép đúng công cụ, vòng sau trả quyền tự quyết cho mô hình', async () => {
    const svc = makeService([[callDone([lookup('c1', 'giảm trừ gia cảnh')])], [text('Trả lời.'), done()]]);
    await run(svc);
    assert.deepStrictEqual(svc._requests[0].toolChoice, { type: 'function', function: { name: KNOWLEDGE_TOOL_NAME } });
    assert.strictEqual(svc._requests[1].toolChoice, undefined);
    assert.ok(svc._requests[1].tools, 'vòng sau vẫn được gọi công cụ');
  });

  it('3. Câu về số liệu cá nhân: không ép, mô hình tự quyết', async () => {
    const svc = makeService([[text('Bạn đã chi 2 triệu.'), done()]]);
    await run(svc, { message: PERSONAL_QUESTION });
    assert.strictEqual(svc._requests[0].toolChoice, undefined);
    assert.ok(svc._requests[0].tools.some((t) => t.function.name === KNOWLEDGE_TOOL_NAME));
    assert.strictEqual(svc._toolLog.length, 0);
  });

  it('4. Kết quả tra cứu đi vào messages của vòng sau, kèm chuỗi trích nguồn', async () => {
    const svc = makeService([[callDone([lookup('c1', 'giảm trừ gia cảnh thuế thu nhập')])], [text('Trả lời.'), done()]]);
    await run(svc);
    const tool = svc._requests[1].messages.find((m) => m.role === 'tool');
    const body = JSON.parse(tool.content);
    assert.strictEqual(body.found, true);
    assert.ok(body.results[0].citation.startsWith('[Nguồn: '));
  });

  it('5. Mô hình gọi công cụ mà thiếu query: dùng chính câu hỏi (đã che PII) để tra', async () => {
    const svc = makeService([[callDone([{ id: 'c1', name: KNOWLEDGE_TOOL_NAME, args: '{}' }])], [text('Trả lời.'), done()]]);
    await run(svc);
    assert.strictEqual(svc._toolLog[0].args.query, KNOWLEDGE_QUESTION);
    const body = JSON.parse(svc._requests[1].messages.find((m) => m.role === 'tool').content);
    assert.strictEqual(body.found, true);
  });

  it('6. Mô hình quên trích nguồn: máy chủ gửi thêm đúng nguồn của đoạn đứng đầu, đúng một lần', async () => {
    const svc = makeService([[callDone([lookup('c1', 'giảm trừ gia cảnh thuế thu nhập')])], [text('Mức giảm trừ là như trên.'), done()]]);
    const { text: out, chunks, done: d } = await run(svc);
    const citation = JSON.parse(svc._requests[1].messages.find((m) => m.role === 'tool').content).results[0].citation;
    assert.ok(out.endsWith(citation), `phải kết thúc bằng nguồn: ${out}`);
    assert.strictEqual(out.split(citation).length - 1, 1);
    assert.ok(chunks.length >= 2, 'nguồn đi như một mẩu chữ riêng');
    assert.strictEqual(d.citationAppended, true);
  });

  it('7. Mô hình đã chép đúng nguồn: máy chủ không gửi thêm', async () => {
    const citation = (await new ToolsExecutor().executeTool(KNOWLEDGE_TOOL_NAME, { query: 'giảm trừ gia cảnh thuế thu nhập' }, 5)).results[0].citation;
    const svc = makeService([[callDone([lookup('c1', 'giảm trừ gia cảnh thuế thu nhập')])], [text(`Mức giảm trừ là như trên. ${citation}`), done()]]);
    const { text: out, done: d } = await run(svc);
    assert.strictEqual(out.split(citation).length - 1, 1);
    assert.strictEqual(d.citationAppended, false);
  });

  it('8. Mô hình tự ghi một nguồn không có trong kết quả tra cứu: vẫn gắn nguồn thật', async () => {
    const svc = makeService([[callDone([lookup('c1', 'giảm trừ gia cảnh thuế thu nhập')])], [text('Theo [Nguồn: Một trang web nào đó].'), done()]]);
    const { done: d } = await run(svc);
    assert.strictEqual(d.citationAppended, true);
  });

  it('9. Tra không thấy hoặc không tra: không gắn nguồn', async () => {
    const svc = makeService([[callDone([lookup('c1', 'cách nấu phở bò ngon')])], [text('Kho chưa có thông tin này.'), done()]]);
    const a = await run(svc);
    assert.strictEqual(a.text, 'Kho chưa có thông tin này.');
    assert.strictEqual(a.done.citationAppended, false);

    const svc2 = makeService([[text('Bạn đã chi 2 triệu.'), done()]]);
    const b = await run(svc2, { message: PERSONAL_QUESTION });
    assert.strictEqual(b.text, 'Bạn đã chi 2 triệu.');
  });

  it('10. Chuỗi đa bước phụ thuộc: tra kiến thức → lấy số liệu → trả lời, các vòng sau không bị ép', async () => {
    const svc = makeService([
      [callDone([lookup('c1', 'quy tắc 50/30/20')])],
      [callDone([{ id: 'c2', name: 'compare_spending_periods', args: '{}' }])],
      [text('So với quy tắc thì bạn chi hơi cao.'), done()],
    ]);
    const { text: out, done: d } = await run(svc, { message: 'quy tắc 50/30/20 là gì' });
    assert.deepStrictEqual(svc._toolLog.map((t) => t.name), [KNOWLEDGE_TOOL_NAME, 'compare_spending_periods']);
    assert.strictEqual(svc._requests.length, 3);
    assert.strictEqual(svc._requests[1].toolChoice, undefined);
    assert.ok(out.includes('[Nguồn: '), 'nguồn của vòng đầu vẫn được giữ tới cuối lượt');
    assert.strictEqual(d.toolRounds, 2);
    assert.strictEqual(d.lookups, 1);
    assert.strictEqual(d.forcedLookup, true);
  });

  it('11. Vượt trần chi phí sau khi tra cứu: thôi gọi công cụ nhưng vẫn trả lời và vẫn có nguồn', async () => {
    const expensive = { prompt_tokens: 9000, prompt_cache_miss_tokens: 9000, prompt_cache_hit_tokens: 0, completion_tokens: 0 };
    const svc = makeService([
      [{ type: 'done', finishReason: 'tool_calls', toolCalls: [lookup('c1', 'giảm trừ gia cảnh thuế thu nhập')], usage: expensive }],
      [text('Trả lời.'), done()],
    ]);
    const { text: out } = await run(svc, { turnCostCapMicroUsd: 2000 });
    assert.strictEqual(svc._requests[1].tools, undefined);
    assert.ok(out.includes('[Nguồn: '));
  });

  it('12. Báo công cụ đang chạy: start rồi done cho từng lời gọi, đúng thứ tự, trước chữ của vòng sau', async () => {
    const order = [];
    const svc = makeService([
      [callDone([lookup('c1', 'giảm trừ gia cảnh'), { id: 'c2', name: 'get_bill_details', args: '{}' }])],
      [text('Trả lời.'), done()],
    ]);
    const { tools } = await run(svc, { onChunk: () => order.push('chu'), onTool: (e) => order.push(`${e.name}:${e.status}`) });
    assert.deepStrictEqual(tools, []);
    assert.deepStrictEqual(order.slice(0, 5), [
      `${KNOWLEDGE_TOOL_NAME}:start`, `${KNOWLEDGE_TOOL_NAME}:done`, 'get_bill_details:start', 'get_bill_details:done', 'chu',
    ]);
  });

  it('13. Không truyền onTool (trả một lần, đo đạc) vẫn chạy bình thường', async () => {
    const svc = makeService([[callDone([lookup('c1', 'giảm trừ gia cảnh')])], [text('Trả lời.'), done()]]);
    const { text: out } = await run(svc, { onTool: undefined });
    assert.ok(out.startsWith('Trả lời.'));
  });

  it('14. Nội dung hai cách phân phối giống hệt: cả chuỗi chữ đều đi qua onChunk, kể cả phần nguồn máy chủ gắn', async () => {
    const rounds = () => [[callDone([lookup('c1', 'giảm trừ gia cảnh thuế thu nhập')])], [text('Mức '), text('giảm trừ.'), done()]];
    const streamed = await run(makeService(rounds()));
    let oneShot = '';
    await makeService(rounds()).chatStream({ message: KNOWLEDGE_QUESTION, idaccount: 5, onChunk: (c) => { oneShot += c; }, onDone: () => {} });
    assert.strictEqual(oneShot, streamed.text);
  });
});

describe('Controller — phát sự kiện SSE `tool`', () => {
  const controller = require('../../modules/ai/features/chatbot/chatbot.controller');
  const { StreamGuard } = require('../../modules/ai/features/chatbot/limits/stream-guard');
  const sseRes = () => ({ written: [], ended: false, setHeader() {}, flushHeaders() {}, write(s) { this.written.push(s); return true; }, end() { this.ended = true; }, on() {}, get writableEnded() { return this.ended; } });
  const jsonRes = () => ({ status() { return this; }, json() { return this; }, setHeader() {}, on() {} });
  const req = () => ({ user: { idaccount: 5, type: 'Premium' }, body: { message: 'chi tiêu tháng này' }, on() {} });

  beforeEach(() => {
    controller.getBudget = () => ({ add: async () => {} });
    controller.streamGuard = new StreamGuard({ perUser: 1, global: 5 });
  });

  it('1. Truyền dòng: ghi đúng định dạng event: tool, đúng thứ tự với delta và done', async () => {
    controller.chatbotService = {
      chatStream: async (p) => {
        p.onTool({ name: KNOWLEDGE_TOOL_NAME, status: 'start' });
        p.onTool({ name: KNOWLEDGE_TOOL_NAME, status: 'done' });
        p.onChunk('Chữ');
        p.onDone({});
      },
    };
    const res = sseRes();
    await controller.handleChatStream(req(), res);
    const events = res.written.map((s) => s.split('\n')[0]);
    assert.deepStrictEqual(events, ['event: tool', 'event: tool', 'event: delta', 'event: done']);
    const data = JSON.parse(res.written[0].split('\n')[1].replace('data: ', ''));
    assert.deepStrictEqual(data, { name: KNOWLEDGE_TOOL_NAME, status: 'start' });
  });

  it('2. Trả một lần: không nhận onTool, không ghi gì thêm', async () => {
    let got = 'chua-goi';
    controller.chatbotService = { chatStream: async (p) => { got = p.onTool; p.onDone({}); } };
    await controller.handleChatNonStream(req(), jsonRes());
    assert.strictEqual(got, undefined);
  });
});
