/**
 * Unit Test — Truy vấn tri thức tĩnh trên kho thật (thay cho bản khớp cụm từ khóa cũ). Chi tiết BM25: chatbot.bm25.test.js
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const LexicalKnowledgeSearch = require('../../modules/ai/features/chatbot/rag/lexical.search');

describe('LexicalKnowledgeSearch — Truy Vấn Tri Thức Tĩnh Chuẩn RAG', () => {
  const searchEngine = new LexicalKnowledgeSearch();

  it('1. Đọc và nạp đủ các tài liệu tri thức', () => {
    const docIds = searchEngine.documents.map(d => d.id);
    assert.ok(docIds.includes('thue_giam_tru_2026'));
    assert.ok(docIds.includes('quy_tac_50_30_20'));
    assert.ok(docIds.includes('tra_no_phuong_phap'));
  });

  it('2. Truy vấn câu hỏi về giảm trừ gia cảnh -> Trả về mức 2026 và trích dẫn đúng văn bản', () => {
    const results = searchEngine.search('Mức giảm trừ gia cảnh thuế thu nhập cá nhân hiện nay là bao nhiêu?', 3);
    assert.strictEqual(results[0].id, 'thue_giam_tru_2026');
    assert.ok(results.map((r) => r.content).join('\n').includes('15.500.000'));
    assert.ok(results[0].attribution.includes('110/2025/UBTVQH15'));
  });

  // Kết quả là từng ĐOẠN, nên câu hỏi về hai nội dung phải lấy được cả hai đoạn trong topK.
  it('3. Câu hỏi về 50/30/20 và 6 chiếc lọ -> Lấy được cả hai đoạn của tài liệu ngân sách', () => {
    const results = searchEngine.search('Làm sao để chia tiền theo quy tắc 50/30/20 và 6 chiếc lọ?', 3);
    assert.strictEqual(results[0].id, 'quy_tac_50_30_20');
    const text = results.map((r) => r.content).join('\n');
    assert.ok(text.includes('NHU CẦU THIẾT YẾU'));
    assert.ok(text.includes('6 CHIẾC LỌ'));
  });

  it('4. Câu hỏi so sánh Tuyết Lở và Hòn Tuyết Lăn -> Lấy được cả hai đoạn của tài liệu nợ', () => {
    const results = searchEngine.search('Nên trả nợ theo phương pháp Tuyết Lở hay Hòn Tuyết Lăn?', 3);
    assert.strictEqual(results[0].id, 'tra_no_phuong_phap');
    const text = results.map((r) => r.content).join('\n');
    assert.ok(text.includes('DEBT AVALANCHE'));
    assert.ok(text.includes('DEBT SNOWBALL'));
  });

  it('5. Câu hỏi hoàn toàn không liên quan -> Trả về danh sách rỗng (tránh nạp rác vào Prompt)', () => {
    const results = searchEngine.search('Hôm nay thời tiết Hà Nội thế nào?', 1);
    assert.strictEqual(results.length, 0);
  });
});
