/**
 * Chọn cách truy hồi kho tri thức theo biến môi trường (bản thực nghiệm NCKH).
 *   - Không đặt `NCKH_RETRIEVAL` (mặc định): truy hồi từ vựng BM25, đúng như bản đối chứng.
 *   - `NCKH_RETRIEVAL=hybrid`: truy hồi lai BM25 + embedding + RRF.
 * Tham số (chốt trên tập phát triển, ghi vào nhật ký đo): NCKH_EMBED_MODEL, NCKH_EMBED_MIN_SIM, NCKH_RRF_K,
 * NCKH_RRF_CANDIDATES, NCKH_EMBED_CACHE.
 */

const path = require('path');
const LexicalKnowledgeSearch = require('./lexical.search');
const HybridKnowledgeSearch = require('./hybrid.search');
const { createEmbedder } = require('./embedder');

const DEFAULT_MODEL = 'Xenova/multilingual-e5-small';
const DEFAULT_CACHE = path.resolve(__dirname, '../../../../../.cache-embed');

const num = (v, fallback) => {
  const n = Number(v);
  return v !== undefined && v !== '' && Number.isFinite(n) ? n : fallback;
};

function createKnowledgeSearch({ env = process.env, dataDir, embedderFactory = createEmbedder } = {}) {
  const lexicalOpts = dataDir ? { dataDir } : {};
  if (String(env.NCKH_RETRIEVAL || '').toLowerCase() !== 'hybrid') return new LexicalKnowledgeSearch(lexicalOpts);
  const embedder = embedderFactory({
    model: env.NCKH_EMBED_MODEL || DEFAULT_MODEL,
    cacheDir: env.NCKH_EMBED_CACHE || DEFAULT_CACHE,
  });
  return new HybridKnowledgeSearch({
    ...lexicalOpts,
    embedder,
    minSimilarity: num(env.NCKH_EMBED_MIN_SIM, 0.8),
    rrfK: num(env.NCKH_RRF_K, 60),
    candidates: num(env.NCKH_RRF_CANDIDATES, 10),
  });
}

module.exports = { createKnowledgeSearch, DEFAULT_MODEL };
