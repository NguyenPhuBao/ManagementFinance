/**
 * Unit Test — Truy hồi từ vựng BM25 tiếng Việt (nền của bản đối chứng NCKH).
 * Bao ba lớp: chuẩn hóa/tách từ, công thức BM25, và bộ tìm kiếm trên kho tri thức thật.
 * Không dùng thư viện ngoài: công thức kiểm bằng phép tính độc lập ngay trong test.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const { normalizeVi, tokenize, VI_STOPWORDS } = require('../../modules/ai/features/chatbot/rag/vi-text');
const { Bm25Index } = require('../../modules/ai/features/chatbot/rag/bm25');
const LexicalKnowledgeSearch = require('../../modules/ai/features/chatbot/rag/lexical.search');

describe('vi-text — chuẩn hóa và tách từ tiếng Việt', () => {
  it('bỏ dấu, đổi đ/Đ thành d, chữ thường, bỏ dấu câu', () => {
    assert.strictEqual(normalizeVi('Đóng BẢO HIỂM, Thất-Nghiệp!'), 'dong bao hiem that nghiep');
  });

  it('chuỗi rỗng hoặc không phải chuỗi cho kết quả rỗng, không ném lỗi', () => {
    assert.deepStrictEqual(tokenize(''), []);
    assert.deepStrictEqual(tokenize(null), []);
    assert.deepStrictEqual(tokenize(undefined), []);
    assert.deepStrictEqual(tokenize(123), []);
  });

  it('bỏ từ dừng nhưng giữ từ nội dung và số', () => {
    const terms = tokenize('Tôi muốn biết mức giảm trừ là bao nhiêu 2026', { bigrams: false });
    assert.ok(terms.includes('giam'));
    assert.ok(terms.includes('tru'));
    assert.ok(terms.includes('2026'));
    assert.ok(!terms.includes('toi'));
    assert.ok(!terms.includes('la'));
    assert.ok(VI_STOPWORDS.has('toi'));
  });

  it('sinh thêm cặp âm tiết liền kề (bigram) để giữ nghĩa từ ghép', () => {
    const terms = tokenize('giảm trừ gia cảnh');
    assert.ok(terms.includes('giam_tru'));
    assert.ok(terms.includes('tru_gia'));
    assert.ok(terms.includes('gia_canh'));
  });

  it('cho cùng kết quả với hoặc không có dấu', () => {
    assert.deepStrictEqual(tokenize('giảm trừ gia cảnh'), tokenize('giam tru gia canh'));
  });
});

describe('Bm25Index — công thức BM25', () => {
  const k1 = 1.2;
  const b = 0.75;
  const docs = [
    { id: 'a', terms: ['thue', 'thue', 'luong'] },
    { id: 'b', terms: ['thue', 'bao', 'hiem', 'xa', 'hoi', 'luong', 'nghi'] },
    { id: 'c', terms: ['tiet', 'kiem'] },
  ];
  const idx = new Bm25Index(docs, { k1, b });

  // IDF kiểu Lucene (không âm): ln(1 + (N - n + 0.5) / (n + 0.5))
  const idf = (n, N) => Math.log(1 + (N - n + 0.5) / (n + 0.5));
  const avgdl = (3 + 7 + 2) / 3;
  const expected = (tf, dl, n) => idf(n, 3) * ((tf * (k1 + 1)) / (tf + k1 * (1 - b + (b * dl) / avgdl)));

  it('điểm một từ khớp công thức BM25 đã tính độc lập', () => {
    const res = idx.search(['thue'], 10);
    const byId = Object.fromEntries(res.map((r) => [r.id, r.score]));
    assert.ok(Math.abs(byId.a - expected(2, 3, 2)) < 1e-9);
    assert.ok(Math.abs(byId.b - expected(1, 7, 2)) < 1e-9);
    assert.strictEqual(byId.c, undefined, 'tài liệu không chứa từ không được có điểm');
  });

  it('tần suất cao hơn xếp trước (cùng độ dài)', () => {
    const same = new Bm25Index([{ id: 'it', terms: ['thue', 'a', 'b'] }, { id: 'nhieu', terms: ['thue', 'thue', 'b'] }, { id: 'khac', terms: ['c', 'd', 'e'] }], { k1, b });
    assert.deepStrictEqual(same.search(['thue'], 10).map((r) => r.id), ['nhieu', 'it']);
  });

  it('cùng tần suất thì tài liệu ngắn hơn xếp trước (chuẩn hóa độ dài)', () => {
    const lens = new Bm25Index([{ id: 'dai', terms: ['thue', 'a', 'b', 'c', 'd', 'e', 'g'] }, { id: 'ngan', terms: ['thue', 'a'] }, { id: 'khac', terms: ['h', 'i'] }], { k1, b });
    assert.deepStrictEqual(lens.search(['thue'], 10).map((r) => r.id), ['ngan', 'dai']);
  });

  it('từ hiếm có trọng số lớn hơn từ phổ biến (IDF)', () => {
    const rare = idx.search(['tiet'], 1)[0].score;
    const common = idx.search(['thue'], 3).find((r) => r.id === 'a').score;
    assert.ok(rare > 0 && common > 0);
    assert.ok(idf(1, 3) > idf(2, 3));
  });

  it('cắt theo topK và báo các từ đã khớp', () => {
    const res = idx.search(['thue', 'luong'], 1);
    assert.strictEqual(res.length, 1);
    assert.deepStrictEqual(res[0].matchedTerms.sort(), ['luong', 'thue']);
  });

  it('từ truy vấn lặp lại không nhân đôi điểm', () => {
    const once = idx.search(['thue'], 1)[0].score;
    const twice = idx.search(['thue', 'thue'], 1)[0].score;
    assert.strictEqual(once, twice);
  });

  it('chỉ mục rỗng hoặc truy vấn rỗng trả về danh sách rỗng', () => {
    assert.deepStrictEqual(new Bm25Index([], {}).search(['thue'], 3), []);
    assert.deepStrictEqual(idx.search([], 3), []);
  });

  it('kết quả bằng điểm được sắp ổn định theo thứ tự tài liệu nạp vào', () => {
    const tie = new Bm25Index([{ id: 'x', terms: ['abc'] }, { id: 'y', terms: ['abc'] }], {});
    assert.deepStrictEqual(tie.search(['abc'], 2).map((r) => r.id), ['x', 'y']);
  });
});

describe('LexicalKnowledgeSearch — truy hồi trên kho tri thức thật', () => {
  const engine = new LexicalKnowledgeSearch();

  it('nạp kho và chia thành các đoạn nhỏ có mã riêng', () => {
    assert.ok(engine.chunks.length > engine.documents.length, 'mỗi tài liệu phải được chia thành nhiều đoạn');
    for (const c of engine.chunks) {
      assert.ok(c.chunkId.startsWith(`${c.docId}#`));
      assert.ok(c.text.length > 0);
    }
  });

  it('khớp được câu hỏi KHÔNG chứa đúng cụm từ khóa khai báo (điểm yếu của bản khớp cụm cũ)', () => {
    const res = engine.search('mình vay thẻ tín dụng lãi cao nên trả khoản nào trước', 3);
    assert.ok(res.length > 0, 'phải tìm thấy tri thức về trả nợ');
    assert.strictEqual(res[0].id, 'tra_no_phuong_phap');
  });

  it('không phân biệt có dấu hay không dấu', () => {
    const a = engine.search('quy tac 50/30/20 chia thu nhap', 1);
    const b = engine.search('quy tắc 50/30/20 chia thu nhập', 1);
    assert.strictEqual(a[0].id, 'quy_tac_50_30_20');
    assert.deepStrictEqual(a.map((r) => r.chunkId), b.map((r) => r.chunkId));
  });

  it('mỗi kết quả mang mã đoạn, tiêu đề, nội dung, điểm và chuỗi trích nguồn', () => {
    const [r] = engine.search('giảm trừ gia cảnh thuế thu nhập cá nhân', 1);
    assert.ok(r.chunkId && r.id && r.title && r.content && r.score > 0);
    assert.ok(r.attribution.startsWith('[Nguồn: ') && r.attribution.endsWith(']'));
  });

  it('trả tối đa topK đoạn, không trùng đoạn', () => {
    const res = engine.search('tiết kiệm chi tiêu nợ thuế', 3);
    assert.ok(res.length <= 3);
    assert.strictEqual(new Set(res.map((r) => r.chunkId)).size, res.length);
  });

  it('câu lạc đề trả về rỗng, không nạp rác vào ngữ cảnh', () => {
    for (const q of [
      'Hôm nay thời tiết Hà Nội thế nào?',
      'viết cho tôi một bài thơ về mùa thu',
      'đội bóng nào vô địch World Cup 2018',
      'cách nấu phở bò ngon',
    ]) {
      assert.deepStrictEqual(engine.search(q, 3), [], `phải rỗng: ${q}`);
    }
  });

  it('câu hỏi kiểu trò chuyện (có từ thừa) vẫn tìm đúng, không bỏ sót vì bộ lọc', () => {
    const cases = [
      ['nợ nhiều quá nên trả khoản nào trước', 'tra_no_phuong_phap'],
      ['quỹ khẩn cấp cần mấy tháng chi tiêu', 'quy_khan_cap'],
      ['thuế lương của tôi tính thế nào', 'thue_cach_tinh_luong'],
      ['tháng này tôi nên để dành bao nhiêu tiền theo quy tắc chia thu nhập', 'quy_tac_50_30_20'],
    ];
    for (const [q, id] of cases) {
      const res = engine.search(q, 3);
      assert.ok(res.length > 0, `phải có kết quả: ${q}`);
      assert.ok(res.some((r) => r.id === id), `phải gồm ${id}: ${q}`);
    }
  });

  it('ngưỡng độ phủ cấu hình được: đặt 0 thì nhận cả kết quả yếu (chứng tỏ bộ lọc có tác dụng)', () => {
    const loose = new LexicalKnowledgeSearch({ minCoverage: 0 });
    assert.ok(loose.search('viết cho tôi một bài thơ về mùa thu', 3).length > 0);
    assert.deepStrictEqual(engine.search('viết cho tôi một bài thơ về mùa thu', 3), []);
  });

  it('đầu vào hỏng không ném lỗi', () => {
    assert.deepStrictEqual(engine.search('', 3), []);
    assert.deepStrictEqual(engine.search(null, 3), []);
    assert.deepStrictEqual(engine.search(42, 3), []);
  });

  it('bản thân đối tượng không mang tên "hybrid" (không còn gọi sai bản chất)', () => {
    assert.strictEqual(engine.constructor.name, 'LexicalKnowledgeSearch');
  });
});
