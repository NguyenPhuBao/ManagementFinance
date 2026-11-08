/**
 * Unit Test — Bản thực nghiệm NCKH: truy hồi lai (BM25 + embedding, hợp nhất RRF) trong công cụ `tra_cuu_kien_thuc`.
 *
 * Bất biến của thiết kế 2 nhánh: chỉ cách tìm trong kho thay đổi. Cổng ép tra cứu, định dạng kết quả công cụ và hợp
 * đồng SSE (`name`, `status`) giữ nguyên; truy hồi lai chỉ bật khi `NCKH_RETRIEVAL=hybrid`.
 *
 * Tầng 1: hàm RRF, chỉ mục vector, lớp truy hồi lai (kho thử + bộ nhúng giả lập tất định, không tải mô hình thật).
 * Tầng 2: công cụ tra cứu trả kết quả theo truy hồi lai và sự kiện SSE `tool` mang chẩn đoán truy hồi.
 */

const { describe, it, before, after, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { reciprocalRankFusion } = require('../../modules/ai/features/chatbot/rag/rrf');
const { VectorIndex } = require('../../modules/ai/features/chatbot/rag/vector.index');
const HybridKnowledgeSearch = require('../../modules/ai/features/chatbot/rag/hybrid.search');
const LexicalKnowledgeSearch = require('../../modules/ai/features/chatbot/rag/lexical.search');
const { createKnowledgeSearch } = require('../../modules/ai/features/chatbot/rag/knowledge.factory');
const { withQueryPrefix, withPassagePrefix } = require('../../modules/ai/features/chatbot/rag/embedder');
const ToolsExecutor = require('../../modules/ai/features/chatbot/tools/tools.executor');
const ChatbotService = require('../../modules/ai/features/chatbot/chatbot.service');
const { KNOWLEDGE_TOOL_NAME } = require('../../modules/ai/features/chatbot/tools/financial.tools');
const { CircuitBreaker } = require('../../modules/ai/features/chatbot/resilience/circuit-breaker');

// ── Kho thử nhỏ: ba chủ đề tách bạch để biết chắc đoạn nào đúng ──
const DOCS = [
  { id: 'quy_khan_cap', title: 'Quỹ khẩn cấp', source: 'Nguồn A', keywords: ['quỹ khẩn cấp'],
    content: 'Quỹ khẩn cấp nên bằng 3 đến 6 tháng chi tiêu thiết yếu.\n\nGửi quỹ khẩn cấp ở tài khoản rút được ngay.' },
  { id: 'thue_giam_tru', title: 'Giảm trừ gia cảnh', source: 'Nguồn B', keywords: ['giảm trừ gia cảnh', 'thuế'],
    content: 'Mức giảm trừ gia cảnh cho bản thân người nộp thuế là 15,5 triệu đồng mỗi tháng.' },
  { id: 'bao_hiem', title: 'Bảo hiểm xã hội bắt buộc', source: 'Nguồn C', keywords: ['bảo hiểm xã hội'],
    content: 'Người lao động đóng bảo hiểm xã hội bắt buộc 8% tiền lương.' },
];

// Bộ nhúng giả lập: mỗi chiều là một "khái niệm"; câu chứa từ của khái niệm nào thì vector nghiêng về chiều đó.
const CONCEPTS = [
  ['khẩn cấp', 'dự phòng', 'mất việc', 'phòng thân'],
  ['thuế', 'giảm trừ', 'gia cảnh'],
  ['bảo hiểm', 'bhxh'],
];
function fakeVector(text) {
  const t = text.toLowerCase();
  const v = CONCEPTS.map((words) => words.filter((w) => t.includes(w)).length);
  v.push(v.every((x) => x === 0) ? 1 : 0); // chiều "khác" cho câu không thuộc khái niệm nào
  const norm = Math.hypot(...v) || 1;
  return v.map((x) => x / norm);
}
function makeFakeEmbedder() {
  const calls = { query: 0, passages: 0 };
  return {
    calls,
    async embedQuery(text) { calls.query += 1; return fakeVector(text); },
    async embedPassages(texts) { calls.passages += 1; return texts.map(fakeVector); },
  };
}

let dataDir;
before(() => {
  dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'kho-thu-hybrid-'));
  DOCS.forEach((d) => fs.writeFileSync(path.join(dataDir, `${d.id}.json`), JSON.stringify(d), 'utf8'));
});
after(() => fs.rmSync(dataDir, { recursive: true, force: true }));

const SEMANTIC_QUESTION = 'Tiền dự phòng khi mất việc nên để bao nhiêu?';
const KEYWORD_QUESTION = 'Mức giảm trừ gia cảnh thuế là bao nhiêu?';
const OFF_TOPIC = 'Thời tiết hôm nay thế nào?';

describe('reciprocalRankFusion', () => {
  it('1. Điểm = Σ 1/(k + hạng), hạng tính từ 1; xếp giảm dần', () => {
    const out = reciprocalRankFusion([['a', 'b', 'c'], ['c', 'a']], { k: 60 });
    assert.deepStrictEqual(out.map((x) => x.id), ['a', 'c', 'b']);
    assert.ok(Math.abs(out[0].score - (1 / 61 + 1 / 62)) < 1e-12);
    assert.ok(Math.abs(out[2].score - 1 / 62) < 1e-12);
  });

  it('2. Ghi hạng của từng danh sách (null khi không có mặt)', () => {
    const out = reciprocalRankFusion([['a', 'b'], ['b']], { k: 60 });
    const b = out.find((x) => x.id === 'b');
    const a = out.find((x) => x.id === 'a');
    assert.deepStrictEqual(b.ranks, [2, 1]);
    assert.deepStrictEqual(a.ranks, [1, null]);
  });

  it('3. Bằng điểm thì giữ thứ tự xuất hiện; danh sách rỗng cho kết quả rỗng', () => {
    assert.deepStrictEqual(reciprocalRankFusion([['x'], ['y']]).map((r) => r.id), ['x', 'y']);
    assert.deepStrictEqual(reciprocalRankFusion([[], []]), []);
  });

  it('4. Mặc định k = 60', () => {
    const [top] = reciprocalRankFusion([['a']]);
    assert.ok(Math.abs(top.score - 1 / 61) < 1e-12);
  });
});

describe('VectorIndex', () => {
  it('1. Tìm theo cosine, xếp giảm dần, trả độ tương đồng', async () => {
    const idx = new VectorIndex({ embedder: makeFakeEmbedder() });
    await idx.build([{ id: 'k', text: 'quỹ khẩn cấp' }, { id: 't', text: 'thuế giảm trừ' }]);
    assert.strictEqual(idx.size, 2);
    const hits = await idx.search('khi mất việc cần dự phòng', 2);
    assert.strictEqual(hits[0].id, 'k');
    assert.ok(hits[0].similarity > hits[1].similarity);
  });

  it('2. Chưa dựng chỉ mục thì trả rỗng', async () => {
    const idx = new VectorIndex({ embedder: makeFakeEmbedder() });
    assert.deepStrictEqual(await idx.search('bất kỳ', 3), []);
  });
});

describe('Tiền tố của mô hình e5', () => {
  it('1. Mô hình e5 cần "query: " / "passage: ", mô hình khác giữ nguyên câu', () => {
    assert.strictEqual(withQueryPrefix('Xenova/multilingual-e5-small', 'abc'), 'query: abc');
    assert.strictEqual(withPassagePrefix('Xenova/multilingual-e5-small', 'abc'), 'passage: abc');
    assert.strictEqual(withQueryPrefix('Xenova/paraphrase-multilingual-MiniLM-L12-v2', 'abc'), 'abc');
  });
});

describe('HybridKnowledgeSearch', () => {
  const make = (embedder = makeFakeEmbedder(), opts = {}) =>
    new HybridKnowledgeSearch({ dataDir, embedder, minSimilarity: 0.7, ...opts });

  it('1. search() đồng bộ và cổng ép tra cứu giữ nguyên như bản đối chứng', () => {
    const lexical = new LexicalKnowledgeSearch({ dataDir });
    const hybrid = make();
    for (const q of [SEMANTIC_QUESTION, KEYWORD_QUESTION, OFF_TOPIC]) {
      assert.deepStrictEqual(hybrid.search(q, 3).map((h) => h.chunkId), lexical.search(q, 3).map((h) => h.chunkId));
      assert.strictEqual(hybrid.shouldForceLookup(q), lexical.shouldForceLookup(q));
    }
  });

  it('2. Câu diễn đạt khác chữ trong kho: BM25 trượt, truy hồi lai tìm được nhờ vector', async () => {
    const hybrid = make();
    assert.deepStrictEqual(hybrid.search(SEMANTIC_QUESTION, 3), [], 'tiền đề: BM25 không tìm thấy');
    const hits = await hybrid.searchHybrid(SEMANTIC_QUESTION, 3);
    assert.ok(hits.length > 0);
    assert.strictEqual(hits[0].id, 'quy_khan_cap');
    assert.strictEqual(hits[0].lexicalRank, null);
    assert.strictEqual(hits[0].vectorRank, 1);
  });

  it('3. Hai cách cùng đồng ý thì đoạn đó đứng đầu', async () => {
    const hits = await make().searchHybrid(KEYWORD_QUESTION, 3);
    assert.strictEqual(hits[0].id, 'thue_giam_tru');
    assert.strictEqual(hits[0].lexicalRank, 1);
    assert.strictEqual(hits[0].vectorRank, 1);
  });

  it('4. Câu lạc đề: không đoạn nào đạt ngưỡng, trả rỗng', async () => {
    assert.deepStrictEqual(await make().searchHybrid(OFF_TOPIC, 3), []);
  });

  it('5. Kết quả giữ định dạng của truy hồi từ vựng, thêm điểm RRF và độ tương đồng', async () => {
    const [hit] = await make().searchHybrid(KEYWORD_QUESTION, 3);
    for (const k of ['chunkId', 'id', 'title', 'source', 'content', 'attribution']) assert.ok(k in hit, k);
    assert.strictEqual(hit.attribution, '[Nguồn: Nguồn B]');
    assert.ok(hit.rrfScore > 0);
    assert.ok(hit.similarity > 0.7);
  });

  it('6. Ghi thời gian từng bước của lần tra gần nhất', async () => {
    const hybrid = make();
    await hybrid.searchHybrid(KEYWORD_QUESTION, 3);
    const t = hybrid.lastTimings;
    assert.strictEqual(t.method, 'hybrid');
    for (const k of ['bm25Ms', 'embedMs', 'vectorMs', 'fuseMs', 'totalMs']) {
      assert.strictEqual(typeof t[k], 'number', k);
      assert.ok(t[k] >= 0, k);
    }
  });

  it('7. Bộ nhúng lỗi: rơi về truy hồi từ vựng, đánh dấu fallback', async () => {
    const broken = { embedQuery: async () => { throw new Error('model'); }, embedPassages: async (x) => x.map(fakeVector) };
    const hybrid = make(broken);
    const hits = await hybrid.searchHybrid(KEYWORD_QUESTION, 3);
    assert.deepStrictEqual(hits.map((h) => h.chunkId), hybrid.search(KEYWORD_QUESTION, 3).map((h) => h.chunkId));
    assert.strictEqual(hybrid.lastTimings.method, 'lexical-fallback');
  });

  it('8. Chỉ mục vector dựng một lần, kể cả khi chưa gọi ready()', async () => {
    const emb = makeFakeEmbedder();
    const hybrid = make(emb);
    await Promise.all([hybrid.searchHybrid(KEYWORD_QUESTION, 3), hybrid.searchHybrid(SEMANTIC_QUESTION, 3)]);
    await hybrid.searchHybrid(KEYWORD_QUESTION, 3);
    assert.strictEqual(emb.calls.passages, 1);
  });

  it('9. Tôn trọng topK', async () => {
    const hits = await make(makeFakeEmbedder(), { minSimilarity: 0 }).searchHybrid('quỹ khẩn cấp thuế bảo hiểm', 2);
    assert.ok(hits.length <= 2);
  });
});

describe('Rào chắn test', () => {
  it('1. Ép NCKH_RETRIEVAL=lexical để .env bản thực nghiệm không làm test nạp mô hình nhúng thật', () => {
    assert.strictEqual(process.env.NCKH_RETRIEVAL, 'lexical');
    assert.ok(!(new ChatbotService().knowledgeSearch instanceof HybridKnowledgeSearch));
  });
});

describe('createKnowledgeSearch', () => {
  it('1. Không đặt NCKH_RETRIEVAL: dùng truy hồi từ vựng như bản đối chứng', () => {
    const s = createKnowledgeSearch({ env: {}, dataDir });
    assert.ok(s instanceof LexicalKnowledgeSearch);
    assert.ok(!(s instanceof HybridKnowledgeSearch));
  });

  it('2. NCKH_RETRIEVAL=hybrid: dùng truy hồi lai với mô hình và ngưỡng lấy từ biến môi trường', () => {
    let seen;
    const s = createKnowledgeSearch({
      env: { NCKH_RETRIEVAL: 'hybrid', NCKH_EMBED_MODEL: 'm-x', NCKH_EMBED_MIN_SIM: '0.81', NCKH_RRF_K: '50' },
      dataDir,
      embedderFactory: (cfg) => { seen = cfg; return makeFakeEmbedder(); },
    });
    assert.ok(s instanceof HybridKnowledgeSearch);
    assert.strictEqual(seen.model, 'm-x');
    assert.strictEqual(s.minSimilarity, 0.81);
    assert.strictEqual(s.rrfK, 50);
  });
});

describe('ToolsExecutor — tra cứu bằng truy hồi lai', () => {
  it('1. Trả đoạn tìm được nhờ vector, ghi chẩn đoán truy hồi', async () => {
    const exec = new ToolsExecutor({ knowledgeSearch: new HybridKnowledgeSearch({ dataDir, embedder: makeFakeEmbedder(), minSimilarity: 0.7 }) });
    const r = await exec.executeTool(KNOWLEDGE_TOOL_NAME, { query: SEMANTIC_QUESTION }, 5);
    assert.strictEqual(r.found, true);
    assert.strictEqual(r.results[0].chunkId, 'quy_khan_cap#1');
    assert.deepStrictEqual(Object.keys(r).sort(), ['found', 'results'], 'kết quả gửi LLM giữ định dạng cũ');
    assert.strictEqual(exec.lastRetrieval.method, 'hybrid');
    assert.strictEqual(exec.lastRetrieval.chunkIds[0], 'quy_khan_cap#1');
    assert.strictEqual(typeof exec.lastRetrieval.timings.embedMs, 'number');
  });

  it('2. Truy hồi từ vựng: searchKnowledge vẫn trả kết quả đồng bộ, chẩn đoán ghi method lexical', () => {
    const exec = new ToolsExecutor({ knowledgeSearch: new LexicalKnowledgeSearch({ dataDir }) });
    const r = exec.searchKnowledge({ query: KEYWORD_QUESTION });
    assert.strictEqual(typeof r.then, 'undefined', 'không phải Promise');
    assert.strictEqual(r.found, true);
    assert.strictEqual(exec.lastRetrieval.method, 'lexical');
  });
});

describe('ChatbotService — sự kiện SSE tool mang chẩn đoán truy hồi', () => {
  const keys = ['CHATBOT_LLM_PROVIDER', 'DEEPSEEK_API_KEY'];
  const saved = {};
  beforeEach(() => {
    keys.forEach((k) => { saved[k] = process.env[k]; });
    process.env.CHATBOT_LLM_PROVIDER = 'deepseek';
    process.env.DEEPSEEK_API_KEY = 'sk-test';
  });
  afterEach(() => keys.forEach((k) => { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; }));

  it('1. done của tra cứu có retrieval {method, chunkIds, timings}; start giữ nguyên {name, status}', async () => {
    const svc = new ChatbotService({
      knowledgeSearch: new HybridKnowledgeSearch({ dataDir, embedder: makeFakeEmbedder(), minSimilarity: 0.7 }),
    });
    svc.snapshotService = { generateSnapshot: async () => null };
    svc._getUserName = async () => '';
    svc.breaker = new CircuitBreaker({});
    const rounds = [
      [{ type: 'done', finishReason: 'tool_calls', usage: { prompt_tokens: 1, completion_tokens: 1 },
        toolCalls: [{ id: 'c1', name: KNOWLEDGE_TOOL_NAME, args: JSON.stringify({ query: SEMANTIC_QUESTION }) }] }],
      [{ type: 'text', text: 'Nên để 3–6 tháng chi tiêu.' }, { type: 'done', finishReason: 'stop', toolCalls: [], usage: { prompt_tokens: 1, completion_tokens: 1 } }],
    ];
    let i = 0;
    svc.deepseekStream = async function* () { for (const ev of rounds[Math.min(i++, rounds.length - 1)]) yield ev; };
    const tools = [];
    await svc.chatStream({ message: SEMANTIC_QUESTION, idaccount: 5, onChunk: () => {}, onDone: () => {}, onTool: (e) => tools.push(e) });
    assert.deepStrictEqual(tools[0], { name: KNOWLEDGE_TOOL_NAME, status: 'start' });
    assert.strictEqual(tools[1].status, 'done');
    assert.strictEqual(tools[1].retrieval.method, 'hybrid');
    assert.deepStrictEqual(tools[1].retrieval.chunkIds.slice(0, 1), ['quy_khan_cap#1']);
    assert.strictEqual(typeof tools[1].retrieval.timings.totalMs, 'number');
  });
});
