/**
 * Unit Test — Chẩn đoán truy hồi cho đo đạc NCKH ở bản đối chứng (tag nckh-doi-chung-v4, PO duyệt 2026-11-10).
 *
 * Bản thực nghiệm đã gửi `retrieval {method, chunkIds, timings}` trong sự kiện SSE `tool` (done) của tra cứu; bản đối
 * chứng thêm đúng phần đó để máy đo ghi được đoạn đã tra ở CẢ HAI nhánh. Chỉ phục vụ đo: kết quả công cụ gửi LLM giữ
 * nguyên định dạng, `searchKnowledge` vẫn đồng bộ, sự kiện `start` giữ nguyên {name, status}.
 */

const { describe, it, before, after, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const LexicalKnowledgeSearch = require('../../modules/ai/features/chatbot/rag/lexical.search');
const ToolsExecutor = require('../../modules/ai/features/chatbot/tools/tools.executor');
const ChatbotService = require('../../modules/ai/features/chatbot/chatbot.service');
const { KNOWLEDGE_TOOL_NAME } = require('../../modules/ai/features/chatbot/tools/financial.tools');
const { CircuitBreaker } = require('../../modules/ai/features/chatbot/resilience/circuit-breaker');

const DOCS = [
  { id: 'quy_khan_cap', title: 'Quỹ khẩn cấp', source: 'Nguồn A', keywords: ['quỹ khẩn cấp'],
    content: 'Quỹ khẩn cấp nên bằng 3 đến 6 tháng chi tiêu thiết yếu.\n\nGửi quỹ khẩn cấp ở tài khoản rút được ngay.' },
  { id: 'thue_giam_tru', title: 'Giảm trừ gia cảnh', source: 'Nguồn B', keywords: ['giảm trừ gia cảnh', 'thuế'],
    content: 'Mức giảm trừ gia cảnh cho bản thân người nộp thuế là 15,5 triệu đồng mỗi tháng.' },
];
const KEYWORD_QUESTION = 'Mức giảm trừ gia cảnh thuế là bao nhiêu?';
const OFF_TOPIC = 'Thời tiết hôm nay thế nào?';

let dataDir;
before(() => {
  dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'kho-thu-chan-doan-'));
  DOCS.forEach((d) => fs.writeFileSync(path.join(dataDir, `${d.id}.json`), JSON.stringify(d), 'utf8'));
});
after(() => fs.rmSync(dataDir, { recursive: true, force: true }));

describe('ToolsExecutor — chẩn đoán truy hồi (bản đối chứng)', () => {
  it('1. Ghi lastRetrieval {method: lexical, chunkIds, timings}; kết quả vẫn đồng bộ, định dạng gửi LLM không đổi', () => {
    const exec = new ToolsExecutor({ knowledgeSearch: new LexicalKnowledgeSearch({ dataDir }) });
    assert.strictEqual(exec.lastRetrieval, null);
    const r = exec.searchKnowledge({ query: KEYWORD_QUESTION });
    assert.strictEqual(typeof r.then, 'undefined', 'không phải Promise');
    assert.deepStrictEqual(Object.keys(r).sort(), ['found', 'results']);
    assert.strictEqual(exec.lastRetrieval.method, 'lexical');
    assert.deepStrictEqual(exec.lastRetrieval.chunkIds, r.results.map((x) => x.chunkId));
    assert.strictEqual(typeof exec.lastRetrieval.timings.bm25Ms, 'number');
    assert.strictEqual(typeof exec.lastRetrieval.timings.totalMs, 'number');
  });

  it('2. Không tìm thấy: chunkIds rỗng, kết quả gửi LLM giữ nguyên', () => {
    const exec = new ToolsExecutor({ knowledgeSearch: new LexicalKnowledgeSearch({ dataDir }) });
    const r = exec.searchKnowledge({ query: OFF_TOPIC });
    assert.strictEqual(r.found, false);
    assert.deepStrictEqual(exec.lastRetrieval.chunkIds, []);
  });
});

describe('ChatbotService — sự kiện SSE tool mang chẩn đoán truy hồi (bản đối chứng)', () => {
  const keys = ['CHATBOT_LLM_PROVIDER', 'DEEPSEEK_API_KEY'];
  const saved = {};
  beforeEach(() => {
    keys.forEach((k) => { saved[k] = process.env[k]; });
    process.env.CHATBOT_LLM_PROVIDER = 'deepseek';
    process.env.DEEPSEEK_API_KEY = 'sk-test';
  });
  afterEach(() => keys.forEach((k) => { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; }));

  it('1. Mỗi lần tra có done kèm retrieval của đúng lần đó; start giữ nguyên {name, status}', async () => {
    const svc = new ChatbotService();
    const search = new LexicalKnowledgeSearch({ dataDir });
    svc.knowledgeSearch = search;
    svc.toolsExecutor = new ToolsExecutor({ knowledgeSearch: search });
    svc.snapshotService = { generateSnapshot: async () => null };
    svc._getUserName = async () => '';
    svc.breaker = new CircuitBreaker({});
    const usage = { prompt_tokens: 1, completion_tokens: 1 };
    const lookup = (id, query) => [{ type: 'done', finishReason: 'tool_calls', usage,
      toolCalls: [{ id, name: KNOWLEDGE_TOOL_NAME, args: JSON.stringify({ query }) }] }];
    const rounds = [
      lookup('c1', KEYWORD_QUESTION),
      lookup('c2', 'quỹ khẩn cấp'),
      [{ type: 'text', text: 'Giảm trừ 15,5 triệu đồng mỗi tháng.' }, { type: 'done', finishReason: 'stop', toolCalls: [], usage }],
    ];
    let i = 0;
    svc.deepseekStream = async function* () { for (const ev of rounds[Math.min(i++, rounds.length - 1)]) yield ev; };
    const tools = [];
    await svc.chatStream({ message: KEYWORD_QUESTION, idaccount: 5, onChunk: () => {}, onDone: () => {}, onTool: (e) => tools.push(e) });

    assert.strictEqual(tools.length, 4);
    assert.deepStrictEqual(tools[0], { name: KNOWLEDGE_TOOL_NAME, status: 'start' });
    assert.deepStrictEqual(tools[2], { name: KNOWLEDGE_TOOL_NAME, status: 'start' });
    assert.strictEqual(tools[1].retrieval.method, 'lexical');
    assert.strictEqual(tools[1].retrieval.chunkIds[0], 'thue_giam_tru#1');
    assert.ok(tools[3].retrieval.chunkIds.length > 0 && tools[3].retrieval.chunkIds.every((id) => id.startsWith('quy_khan_cap#')),
      'lần tra thứ hai mang đoạn của chính nó, không lặp lại đoạn của lần đầu');
    assert.strictEqual(typeof tools[3].retrieval.timings.totalMs, 'number');
  });
});
