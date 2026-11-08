/**
 * Chỉ mục vector trong bộ nhớ: tìm vét cạn theo cosine. Vector đã chuẩn hoá độ dài 1 nên cosine = tích vô hướng.
 * Kho vài chục đến vài trăm đoạn thì vét cạn nhanh hơn dựng cấu trúc ANN và cho kết quả chính xác tuyệt đối.
 */

const dot = (a, b) => {
  let s = 0;
  for (let i = 0; i < a.length; i += 1) s += a[i] * b[i];
  return s;
};

class VectorIndex {
  /** @param {{embedder: {embedQuery: Function, embedPassages: Function}}} opts */
  constructor({ embedder }) {
    this.embedder = embedder;
    this.items = [];
  }

  get size() {
    return this.items.length;
  }

  /** @param {Array<{id: string, text: string}>} docs */
  async build(docs) {
    const vectors = await this.embedder.embedPassages(docs.map((d) => d.text));
    this.items = docs.map((d, i) => ({ id: d.id, vector: vectors[i] }));
  }

  /** @returns {Promise<Array<{id: string, similarity: number}>>} */
  async search(query, topN) {
    if (!this.items.length) return [];
    const q = await this.embedder.embedQuery(query);
    return this.searchByVector(q, topN);
  }

  searchByVector(q, topN) {
    return this.items
      .map((it) => ({ id: it.id, similarity: dot(q, it.vector) }))
      .sort((a, b) => b.similarity - a.similarity)
      .slice(0, topN);
  }
}

module.exports = { VectorIndex };
