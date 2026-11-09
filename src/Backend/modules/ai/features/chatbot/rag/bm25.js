/**
 * BM25 (Okapi) thuần JS cho truy hồi từ vựng.
 *   score(q, d) = Σ_t IDF(t) · tf·(k1+1) / (tf + k1·(1 − b + b·|d|/avgdl))
 *   IDF(t) = ln(1 + (N − n_t + 0.5) / (n_t + 0.5))   (biến thể Lucene, không âm)
 * Mỗi từ truy vấn chỉ tính một lần. Điểm bằng nhau giữ thứ tự nạp (ổn định, tái lập được khi đo).
 */

class Bm25Index {
  /**
   * @param {Array<{id: string, terms: string[]}>} docs  tài liệu đã tách từ
   * @param {{k1?: number, b?: number}} [opts]
   */
  constructor(docs, { k1 = 1.2, b = 0.75 } = {}) {
    this.k1 = k1;
    this.b = b;
    this.docs = (docs || []).map((d) => {
      const tf = new Map();
      for (const t of d.terms) tf.set(t, (tf.get(t) || 0) + 1);
      return { id: d.id, length: d.terms.length, tf };
    });
    this.df = new Map();
    for (const d of this.docs) for (const t of d.tf.keys()) this.df.set(t, (this.df.get(t) || 0) + 1);
    const total = this.docs.reduce((s, d) => s + d.length, 0);
    this.avgdl = this.docs.length ? total / this.docs.length : 0;
  }

  idf(term) {
    const n = this.df.get(term) || 0;
    return Math.log(1 + (this.docs.length - n + 0.5) / (n + 0.5));
  }

  /**
   * @param {string[]} queryTerms
   * @param {number} [topK=3]
   * @returns {Array<{id: string, score: number, matchedTerms: string[]}>}
   */
  search(queryTerms, topK = 3) {
    if (!this.docs.length || !Array.isArray(queryTerms) || !queryTerms.length) return [];
    const terms = [...new Set(queryTerms)];
    const scored = [];
    this.docs.forEach((d, order) => {
      let score = 0;
      const matchedTerms = [];
      for (const t of terms) {
        const tf = d.tf.get(t);
        if (!tf) continue;
        const norm = tf + this.k1 * (1 - this.b + (this.b * d.length) / this.avgdl);
        score += this.idf(t) *((tf * (this.k1 + 1)) / norm);
        matchedTerms.push(t);
      }
      if (score > 0) scored.push({ id: d.id, score, matchedTerms, order });
    });
    scored.sort((x, y) => y.score - x.score || x.order - y.order);
    return scored.slice(0, topK).map(({ id, score, matchedTerms }) => ({ id, score, matchedTerms }));
  }
}

module.exports = { Bm25Index };
