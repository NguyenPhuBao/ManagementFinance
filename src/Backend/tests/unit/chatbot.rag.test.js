/**
 * Unit Test — Hybrid Knowledge Search RAG (TDD Phase 3)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const HybridKnowledgeSearch = require('../../modules/ai/features/chatbot/rag/hybrid.search');

describe('HybridKnowledgeSearch — Truy Vấn Tri Thức Tĩnh Chuẩn RAG', () => {
  const searchEngine = new HybridKnowledgeSearch();

  it('1. Đọc và nạp đủ 3 gói tài liệu cẩm nang tĩnh', () => {
    assert.ok(searchEngine.documents.length >= 3, 'Phải nạp ít nhất 3 tài liệu');
    const docIds = searchEngine.documents.map(d => d.id);
    assert.ok(docIds.includes('thue_tncn_2026'));
    assert.ok(docIds.includes('quy_tac_50_30_20'));
    assert.ok(docIds.includes('quan_ly_no_an_toan'));
  });

  it('2. Truy vấn câu hỏi về Thuế TNCN -> Trả về tài liệu biểu thuế và trích dẫn nguồn', () => {
    const results = searchEngine.search('Mức giảm trừ gia cảnh thuế thu nhập cá nhân hiện nay là bao nhiêu?', 1);
    assert.strictEqual(results.length, 1);
    assert.strictEqual(results[0].id, 'thue_tncn_2026');
    assert.ok(results[0].content.includes('11.000.000 VNĐ/tháng'));
    assert.ok(results[0].attribution.includes('Luật Thuế TNCN'));
  });

  it('3. Truy vấn câu hỏi về cách phân bổ tiền 50/30/20 -> Trả về tài liệu ngân sách', () => {
    const results = searchEngine.search('Làm sao để chia tiền theo quy tắc 50/30/20 và 6 chiếc lọ?', 1);
    assert.strictEqual(results.length, 1);
    assert.strictEqual(results[0].id, 'quy_tac_50_30_20');
    assert.ok(results[0].content.includes('NHU CẦU THIẾT YẾU'));
  });

  it('4. Truy vấn câu hỏi về phương pháp trả nợ Tuyết Lở -> Trả về tài liệu nợ', () => {
    const results = searchEngine.search('Nên trả nợ theo phương pháp Tuyết Lở hay Hòn Tuyết Lăn?', 1);
    assert.strictEqual(results.length, 1);
    assert.strictEqual(results[0].id, 'quan_ly_no_an_toan');
    assert.ok(results[0].content.includes('DEBT AVALANCHE'));
  });

  it('5. Câu hỏi hoàn toàn không liên quan -> Trả về danh sách rỗng (tránh nạp rác vào Prompt)', () => {
    const results = searchEngine.search('Hôm nay thời tiết Hà Nội thế nào?', 1);
    assert.strictEqual(results.length, 0);
  });
});
