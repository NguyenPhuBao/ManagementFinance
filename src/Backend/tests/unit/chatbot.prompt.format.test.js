/**
 * Unit Test — Prompt của trợ lý: phạm vi câu hỏi và cách trình bày công thức (PO 2026-11-09).
 * Ứng dụng hiển thị chữ thuần nên LaTeX ($$\frac{..}{..}$$) hiện nguyên ký hiệu, người dùng không đọc được.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const { buildSystemPrompt } = require('../../modules/ai/features/chatbot/prompts/advisor.system.prompt');

const p = buildSystemPrompt(null);

describe('Prompt — phạm vi câu hỏi', () => {
  it('1. Câu liên quan gián tiếp tới tài chính (công thức, bài toán, công thức bảng tính) là hợp lệ', () => {
    assert.match(p, /gián tiếp/);
    assert.match(p, /công thức/i);
    assert.match(p, /Excel/);
  });

  it('2. Bài tập chỉ bị từ chối khi không liên quan tài chính; viết mã lập trình vẫn ngoài phạm vi', () => {
    assert.match(p, /bài tập không liên quan tài chính/);
    assert.match(p, /viết mã lập trình/);
  });

  it('3. Đầu tư và giá thị trường thuộc phạm vi: vẫn trả lời, không khuyên mua bán một mã cụ thể (PO duyệt câu chữ 2026-11-09)', () => {
    assert.match(p, /Phạm vi: mọi câu hỏi về tiền của người dùng \(.*đầu tư\)/);
    assert.match(p, /cổ phiếu, vàng, ngoại tệ, tiền số, phái sinh/);
    assert.match(p, /không có giá theo thời gian thực/);
    assert.match(p, /không khuyên mua bán một mã cụ thể/);
    assert.match(p, /Chỉ từ chối yêu cầu không liên quan tới tiền/);
    assert.ok(!p.includes('Chỉ hỗ trợ tài chính cá nhân của người dùng (thu chi, ngân sách, mục tiêu, hóa đơn, vay nợ, tiết kiệm)'), 'còn câu phạm vi cũ thiếu đầu tư');
  });

  it('4. Câu được AI xác nhận thuộc phạm vi thì bản dặn ghi kèm lý do và dặn không từ chối; câu thường thì không có dòng này', () => {
    const coXacNhan = buildSystemPrompt(null, { scopeNote: 'bài toán lãi suất là chuyện tiền' });
    assert.match(coXacNhan, /XÁC NHẬN PHẠM VI/);
    assert.match(coXacNhan, /bài toán lãi suất là chuyện tiền/);
    assert.match(coXacNhan, /không từ chối/i);
    assert.ok(!p.includes('XÁC NHẬN PHẠM VI'));
  });
});

describe('Prompt — cách trình bày công thức', () => {
  it('1. Cấm LaTeX và nêu đích danh các ký hiệu không hiển thị được', () => {
    assert.match(p, /LaTeX/);
    for (const k of ['$$', '\\frac', '\\text', '\\times']) assert.ok(p.includes(k), k);
  });

  it('2. Có ví dụ công thức viết bằng chữ trên một dòng, dùng ký hiệu thường', () => {
    assert.match(p, /Số tháng quỹ khẩn cấp = .+ ÷ .+/);
    assert.match(p, /mũ/);
  });
});
