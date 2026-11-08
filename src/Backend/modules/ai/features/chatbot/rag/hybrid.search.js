/**
 * Truy hồi lai (bản thực nghiệm NCKH): cùng một kho, tìm bằng hai cách rồi hợp nhất bằng RRF.
 *   - Theo chữ: BM25 kèm các bộ lọc liên quan của bản đối chứng (cặp âm tiết, độ phủ IDF).
 *   - Theo nghĩa: nhúng câu truy vấn, so cosine với vector các đoạn; chỉ giữ đoạn đạt ngưỡng tương đồng.
 *
 * `search()` (đồng bộ, BM25) và `shouldForceLookup()` kế thừa NGUYÊN VẸN từ bản đối chứng, nên cổng ép tra cứu của hai
 * nhánh giống hệt nhau. Chỉ công cụ `tra_cuu_kien_thuc` gọi `searchHybrid()`.
 *
 * Ngưỡng tương đồng là bộ lọc "không tìm thấy" của đường vector (vector luôn trả về đoạn gần nhất, kể cả câu lạc đề):
 * phải chốt trên tập phát triển của bộ câu hỏi, không chỉnh trên tập kiểm.
 */

const { performance } = require('perf_hooks');
const LexicalKnowledgeSearch = require('./lexical.search');
const { VectorIndex } = require('./vector.index');
const { reciprocalRankFusion } = require('./rrf');

const ms = (t0) => Math.round((performance.now() - t0) * 1000) / 1000;

class HybridKnowledgeSearch extends LexicalKnowledgeSearch {
  /**
   * @param {{dataDir?: string, minCoverage?: number, embedder: object, rrfK?: number, candidates?: number,
   *   minSimilarity?: number}} opts
   */
  constructor({ embedder, rrfK = 60, candidates = 10, minSimilarity = 0.8, ...lexicalOpts } = {}) {
    super(lexicalOpts);
    this.embedder = embedder;
    this.rrfK = rrfK;
    this.candidates = candidates;
    this.minSimilarity = minSimilarity;
    this.vectorIndex = new VectorIndex({ embedder });
    this._readyPromise = null;
    this.indexMs = null;
    this.lastTimings = null;
  }

  /** Nhúng toàn bộ đoạn của kho một lần (gọi lúc khởi động để lượt hỏi đầu không gánh thời gian lập chỉ mục). */
  ready() {
    if (!this._readyPromise) {
      const t0 = performance.now();
      this._readyPromise = this.vectorIndex
        .build(this.chunks.map((c) => ({ id: c.chunkId, text: `${c.doc.title}\n${c.text}` })))
        .then(() => { this.indexMs = ms(t0); });
      this._readyPromise.catch(() => { this._readyPromise = null; });
    }
    return this._readyPromise;
  }

  /**
   * @param {string} query
   * @param {number} [topK=3]
   * @returns {Promise<Array<object>>} cùng định dạng với `search()`, thêm rrfScore, similarity, lexicalRank, vectorRank
   */
  async searchHybrid(query, topK = 3) {
    const tStart = performance.now();
    let t0 = performance.now();
    const lexical = this.search(query, this.candidates);
    const bm25Ms = ms(t0);
    if (typeof query !== 'string' || !query.trim() || !this.chunks.length) {
      this.lastTimings = { method: 'hybrid', bm25Ms, embedMs: 0, vectorMs: 0, fuseMs: 0, totalMs: ms(tStart) };
      return [];
    }

    let embedMs; let vectorMs; let similarities; let indexBuiltNow = false;
    try {
      if (!this.vectorIndex.size) { indexBuiltNow = true; await this.ready(); }
      t0 = performance.now();
      const qv = await this.embedder.embedQuery(query);
      embedMs = ms(t0);
      t0 = performance.now();
      similarities = this.vectorIndex.searchByVector(qv, this.vectorIndex.size);
      vectorMs = ms(t0);
    } catch (error) {
      this.lastTimings = { method: 'lexical-fallback', bm25Ms, totalMs: ms(tStart), error: error.message };
      return lexical.slice(0, topK);
    }

    t0 = performance.now();
    const simById = new Map(similarities.map((s) => [s.id, s.similarity]));
    const vectorIds = similarities.filter((s) => s.similarity >= this.minSimilarity).slice(0, this.candidates).map((s) => s.id);
    const lexById = new Map(lexical.map((h) => [h.chunkId, h]));
    const fused = reciprocalRankFusion([lexical.map((h) => h.chunkId), vectorIds], { k: this.rrfK });
    const out = fused.slice(0, topK).map(({ id, score, ranks }) => {
      const c = this._byId.get(id);
      const lex = lexById.get(id) || {};
      return {
        chunkId: c.chunkId,
        id: c.docId,
        title: c.doc.title,
        source: c.doc.source,
        content: c.text,
        attribution: `[Nguồn: ${c.doc.source}]`,
        score: lex.score ?? null,
        coverage: lex.coverage ?? null,
        matchedBigrams: lex.matchedBigrams ?? null,
        rrfScore: score,
        similarity: simById.get(id),
        lexicalRank: ranks[0],
        vectorRank: ranks[1],
      };
    });
    const fuseMs = ms(t0);
    this.lastTimings = {
      method: 'hybrid', bm25Ms, embedMs, vectorMs, fuseMs, totalMs: ms(tStart),
      ...(indexBuiltNow ? { indexMs: this.indexMs } : {}),
    };
    return out;
  }
}

module.exports = HybridKnowledgeSearch;
