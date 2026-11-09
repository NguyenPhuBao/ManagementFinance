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
