/**
 * Hợp nhất xếp hạng nghịch đảo (Reciprocal Rank Fusion, Cormack và cộng sự, SIGIR 2009).
 *
 * Điểm của một mục = Σ 1 / (k + hạng) trên các danh sách có chứa nó (hạng tính từ 1). Chỉ dùng hạng, không dùng điểm gốc,
 * nên gộp được điểm BM25 và độ tương đồng cosine vốn khác thang đo.
 *
 * @param {Array<Array<string>>} rankings - mỗi phần tử là danh sách id đã xếp hạng
 * @param {{k?: number}} [opts]
 * @returns {Array<{id: string, score: number, ranks: Array<number|null>}>} xếp giảm dần; bằng điểm giữ thứ tự xuất hiện
 */
function reciprocalRankFusion(rankings, { k = 60 } = {}) {
  const byId = new Map();
  rankings.forEach((list, li) => {
    list.forEach((id, i) => {
      if (!byId.has(id)) byId.set(id, { id, score: 0, ranks: rankings.map(() => null), order: byId.size });
      const item = byId.get(id);
      if (item.ranks[li] !== null) return; // id lặp trong cùng danh sách: chỉ tính lần đầu
      item.ranks[li] = i + 1;
      item.score += 1 / (k + i + 1);
    });
  });
  return [...byId.values()]
    .sort((a, b) => b.score - a.score || a.order - b.order)
    .map(({ id, score, ranks }) => ({ id, score, ranks }));
}

module.exports = { reciprocalRankFusion };
