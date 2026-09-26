/**
 * Integration Test — Chatbot Service & Streaming Controller (Phase 4)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const ChatbotService = require('../../modules/ai/features/chatbot/chatbot.service');

describe('ChatbotService — Streaming & Reasoning Integration', () => {
  const service = new ChatbotService();

  it('1. getSnapshot: Lấy bản chụp sức khỏe tài chính cho người dùng test', async () => {
    const snapshot = await service.getSnapshot(1);
    assert.ok(snapshot, 'Phải trả về snapshot');
    assert.ok(typeof snapshot.financialHealthScore === 'number');
    assert.ok(snapshot.budgetAllocation);
    assert.ok(snapshot.spendingInsights);
    assert.ok(snapshot.liquidityAndObligations);
  });

  it('2. chatStream: Phản hồi stream qua callback onMeta, onChunk, onDone', async () => {
    let metaReceived = false;
    let chunksReceived = 0;
    let doneReceived = false;
    let collectedText = '';

    await service.chatStream({
      message: 'Tôi đang có 20 triệu tiền thưởng thì nên làm gì?',
      idaccount: 1,
      onMeta: (meta) => {
        metaReceived = true;
        assert.ok(meta.snapshotLoaded);
      },
      onChunk: (chunk) => {
        chunksReceived++;
        collectedText += chunk;
      },
      onDone: (done) => {
        doneReceived = true;
      },
    });

    assert.strictEqual(metaReceived, true, 'Phải nhận được event meta');
    assert.ok(chunksReceived > 0, 'Phải nhận được các chunks');
    assert.strictEqual(doneReceived, true, 'Phải nhận được event done');
    assert.ok(collectedText.length > 50, 'Phải có nội dung trả lời');
  });

  it('3. Client ngắt kết nối: Signal aborted dừng stream sạch sẽ', async () => {
    const controller = new AbortController();
    let chunks = 0;

    // Giả lập client ngắt kết nối sau 1 chunk đầu tiên
    await service.chatStream({
      message: 'Tư vấn giúp tôi cách tiết kiệm tiền',
      idaccount: 1,
      signal: controller.signal,
      onChunk: () => {
        chunks++;
        controller.abort(); // Hủy kết nối ngay lập tức
      },
      onDone: () => {},
    });

    assert.ok(chunks >= 1, 'Nhận ít nhất 1 chunk trước khi ngắt');
  });
});
