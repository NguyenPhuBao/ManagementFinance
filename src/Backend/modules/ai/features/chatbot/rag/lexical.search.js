/**
 * Truy hồi từ vựng (BM25) trên kho tri thức tĩnh `rag/data/*.json`.
 *
 * Bản đối chứng của đề tài là RAG TỪ VỰNG; bản thực nghiệm thêm embedding + hợp nhất RRF (nhánh riêng). Tên lớp
 * không còn là "Hybrid" vì chưa có vector.
 *
 * Mỗi tài liệu được chia thành các đoạn (theo dòng trống) để trích nguồn gọn và truy hồi sát: đoạn nào khớp thì trả
 * đoạn đó, không trả cả tài liệu. Văn bản được lập chỉ mục = tiêu đề + từ khóa khai báo + nội dung đoạn.
 */

const fs = require('fs');
const path = require('path');
const { tokenize } = require('./vi-text');
const { Bm25Index } = require('./bm25');

const DATA_DIR = path.join(__dirname, 'data');

// Cổng ép tra cứu: ưu tiên độ chính xác, vì ép nhầm tốn thêm một lần gọi LLM cho câu không cần tra. Câu bị bỏ sót vẫn còn
// luật trong prompt. Đo 2026-11-08 trên kho 8 tài liệu (30 đoạn): độ phủ một mình KHÔNG tách được câu kiến thức khỏi câu
// về số liệu cá nhân (câu ngắn đạt > 0,5), còn số cặp âm tiết khớp kèm dấu hiệu ngôi thứ nhất thì tách được. Câu kiến
// thức thấp nhất 0,399, câu cá nhân không có ngôi thứ nhất cao nhất 0,312. PHẢI đo lại khi kho thay đổi.
const FORCE_MIN_BIGRAMS = 2;
const FORCE_MIN_COVERAGE = 0.35;
// Xét trên chữ còn dấu: bỏ dấu thì "tối thiểu", "tối đa" trùng với "tôi". Gõ không dấu thì loại các từ ghép đó ra.
const FIRST_PERSON = /(^|[^\p{L}])(tôi|mình|tui|minh|toi(?! (?:da|thieu|uu|nay|gian)\b))(?=$|[^\p{L}])/u;

class LexicalKnowledgeSearch {
  /**
   * @param {{dataDir?: string, minCoverage?: number}} [opts]
   *   minCoverage: tỷ lệ tối thiểu (theo trọng số IDF) của các từ truy vấn có mặt trong đoạn trả về. Đo 2026-11-08 trên
   *   kho 8 tài liệu: câu lạc đề ≤ 0,177, câu kiến thức ≥ 0,399. PHẢI đo lại khi kho thay đổi (test "lạc đề" sẽ đỏ nếu lệch).
   */
  constructor({ dataDir = DATA_DIR, minCoverage = 0.2 } = {}) {
    this.minCoverage = minCoverage;
    this.documents = [];
    this.chunks = [];
    this._loadDocuments(dataDir);
    this._buildIndex();
  }

  _loadDocuments(dataDir) {
    try {
      if (!fs.existsSync(dataDir)) return;
      const files = fs.readdirSync(dataDir).filter((f) => f.endsWith('.json')).sort();
      for (const file of files) {
        this.documents.push(JSON.parse(fs.readFileSync(path.join(dataDir, file), 'utf8')));
      }
    } catch (error) {
      console.error('Error loading knowledge data:', error);
    }
  }

  _buildIndex() {
    for (const doc of this.documents) {
      const parts = String(doc.content || '').split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean);
      parts.forEach((text, i) => {
        this.chunks.push({ chunkId: `${doc.id}#${i + 1}`, docId: doc.id, doc, text });
      });
    }
    this.index = new Bm25Index(
      this.chunks.map((c) => ({
        id: c.chunkId,
        terms: [
          ...tokenize(c.doc.title),
          ...tokenize((c.doc.keywords || []).join(' ')),
          ...tokenize(c.text),
        ],
      })),
    );
    this._byId = new Map(this.chunks.map((c) => [c.chunkId, c]));
  }

  /**
   * @param {string} query
   * @param {number} [topK=3]
   * @returns {Array<{chunkId: string, id: string, title: string, source: string, content: string,
   *   attribution: string, score: number}>}
   */
  search(query, topK = 3) {
    if (typeof query !== 'string' || !query.trim() || !this.chunks.length) return [];
    const queryTerms = [...new Set(tokenize(query))];
    if (!queryTerms.length) return [];
    const totalWeight = queryTerms.reduce((s, t) => s + this.index.idf(t), 0);
    const hits = this.index.search(queryTerms, topK * 4);
    const out = [];
    for (const hit of hits) {
      // Âm tiết trùng lẻ loi (vd. "tiết" trong "thời tiết" và "tiết kiệm") không phải bằng chứng liên quan:
      // cần cặp âm tiết khớp hoặc ≥ 2 âm tiết, và các từ khớp phải phủ đủ phần trọng số của câu hỏi.
      const hasBigram = hit.matchedTerms.some((t) => t.includes('_'));
      const unigrams = hit.matchedTerms.filter((t) => !t.includes('_')).length;
      if (!hasBigram && unigrams < 2) continue;
      const coverage = hit.matchedTerms.reduce((s, t) => s + this.index.idf(t), 0) / totalWeight;
      if (coverage < this.minCoverage) continue;
      const c = this._byId.get(hit.id);
      out.push({
        chunkId: c.chunkId,
        id: c.docId,
        title: c.doc.title,
        source: c.doc.source,
        content: c.text,
        attribution: `[Nguồn: ${c.doc.source}]`,
        score: hit.score,
        coverage,
        matchedBigrams: hit.matchedTerms.filter((t) => t.includes('_')).length,
      });
      if (out.length >= topK) break;
    }
    return out;
  }

  /** Câu hỏi có rõ ràng là hỏi kiến thức trong kho, đủ để ép mô hình tra cứu trước khi trả lời hay không. */
  shouldForceLookup(query) {
    if (typeof query !== 'string') return false;
    if (FIRST_PERSON.test(query.normalize('NFC').toLowerCase())) return false;
    const [top] = this.search(query, 1);
    return Boolean(top) && top.matchedBigrams >= FORCE_MIN_BIGRAMS && top.coverage >= FORCE_MIN_COVERAGE;
  }
}

module.exports = LexicalKnowledgeSearch;
