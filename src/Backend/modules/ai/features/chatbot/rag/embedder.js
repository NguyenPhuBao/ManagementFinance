/**
 * Bộ nhúng câu chạy cục bộ (ONNX qua @huggingface/transformers), không gửi dữ liệu ra ngoài.
 *
 * Mô hình chỉ nạp ở lần dùng đầu (nạp mất vài giây). Vector trả về đã chuẩn hoá độ dài 1 (mean pooling + normalize).
 * Họ mô hình e5 được huấn luyện với tiền tố "query: " / "passage: ", thiếu tiền tố thì chất lượng giảm.
 */

const isE5 = (model) => /e5/i.test(String(model || ''));
const withQueryPrefix = (model, text) => (isE5(model) ? `query: ${text}` : text);
const withPassagePrefix = (model, text) => (isE5(model) ? `passage: ${text}` : text);

/**
 * @param {{model: string, cacheDir?: string, dtype?: string}} cfg
 * @returns {{model: string, embedQuery: (t: string) => Promise<number[]>, embedPassages: (t: string[]) => Promise<number[][]>}}
 */
function createEmbedder({ model, cacheDir, dtype = 'q8' }) {
  let extractorPromise = null;
  const load = () => {
    if (!extractorPromise) {
      extractorPromise = (async () => {
        const { pipeline, env } = await import('@huggingface/transformers');
        if (cacheDir) env.cacheDir = cacheDir;
        return pipeline('feature-extraction', model, { dtype });
      })();
      extractorPromise.catch(() => { extractorPromise = null; }); // lỗi nạp: lần sau thử lại
    }
    return extractorPromise;
  };
  const run = async (texts) => {
    const extractor = await load();
    const out = await extractor(texts, { pooling: 'mean', normalize: true });
    return out.tolist();
  };
  return {
    model,
    async embedQuery(text) {
      const [v] = await run([withQueryPrefix(model, text)]);
      return v;
    },
    async embedPassages(texts) {
      return run(texts.map((t) => withPassagePrefix(model, t)));
    },
  };
}

module.exports = { createEmbedder, withQueryPrefix, withPassagePrefix };
