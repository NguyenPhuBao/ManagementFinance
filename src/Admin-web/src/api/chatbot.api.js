import { STORAGE_KEYS } from '../utils/constants';

const baseURL = import.meta.env.VITE_API_BASE_URL || '/api';

/**
 * Tiêu thụ luồng Server-Sent Events (SSE) từ API Chatbot
 * @param {Object} options
 * @param {string} options.message - Tin nhắn của người dùng
 * @param {Array} [options.conversationHistory] - Lịch sử hội thoại [{ role: 'user'|'model', content: string }]
 * @param {Function} [options.onMeta] - Callback khi nhận thông tin meta (FHS, ragSnippets)
 * @param {Function} [options.onDelta] - Callback khi nhận từng đoạn text stream
 * @param {Function} [options.onError] - Callback khi xảy ra lỗi
 * @param {Function} [options.onDone] - Callback khi kết thúc stream
 * @param {AbortSignal} [options.signal] - AbortSignal để hủy request khi người dùng muốn dừng
 */
export async function streamChatResponse({
  message,
  conversationHistory = [],
  onMeta,
  onDelta,
  onError,
  onDone,
  signal,
}) {
  const token = localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);

  try {
    const response = await fetch(`${baseURL}/ai/chatbot/chat/stream`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: token ? `Bearer ${token}` : '',
      },
      body: JSON.stringify({
        message,
        conversationHistory,
      }),
      signal,
    });

    if (!response.ok) {
      let errorMsg = `Lỗi máy chủ (${response.status})`;
      try {
        const errJson = await response.json();
        errorMsg = errJson.message || errJson.error || errorMsg;
      } catch (e) {
        // Ignored
      }
      throw new Error(errorMsg);
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder('utf-8');
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n\n');
      buffer = lines.pop(); // Giữ lại phần chưa hoàn chỉnh cuối cùng

      for (const block of lines) {
        if (!block.trim()) continue;

        let eventType = 'message';
        let dataStr = '';

        const eventLines = block.split('\n');
        for (const line of eventLines) {
          if (line.startsWith('event: ')) {
            eventType = line.replace('event: ', '').trim();
          } else if (line.startsWith('data: ')) {
            dataStr = line.replace('data: ', '').trim();
          }
        }

        if (eventType === 'meta') {
          try {
            const metaData = JSON.parse(dataStr);
            if (onMeta) onMeta(metaData);
          } catch (e) {
            console.warn('[SSE] Parse meta error:', e);
          }
        } else if (eventType === 'delta') {
          try {
            const deltaData = JSON.parse(dataStr);
            if (onDelta && deltaData.content) {
              onDelta(deltaData.content);
            }
          } catch (e) {
            // Trường hợp data thô
            if (onDelta) onDelta(dataStr);
          }
        } else if (eventType === 'error') {
          let errorText = 'Có lỗi xảy ra khi xử lý phản hồi';
          try {
            const errObj = JSON.parse(dataStr);
            errorText = errObj.error || errObj.message || errorText;
          } catch (e) {
            errorText = dataStr || errorText;
          }
          if (onError) onError(new Error(errorText));
        } else if (eventType === 'done') {
          if (onDone) onDone();
          return;
        }
      }
    }

    if (onDone) onDone();
  } catch (err) {
    if (err.name === 'AbortError') {
      console.log('[SSE] Request bị hủy bởi người dùng');
    } else {
      console.error('[SSE] Stream error:', err);
      if (onError) onError(err);
    }
  }
}

/**
 * Lấy báo cáo Sức khỏe tài chính tổng hợp
 */
export async function getFinancialHealth() {
  const token = localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);
  const response = await fetch(`${baseURL}/ai/chatbot/financial-health`, {
    method: 'GET',
    headers: {
      Authorization: token ? `Bearer ${token}` : '',
    },
  });

  if (!response.ok) {
    throw new Error(`Không thể lấy dữ liệu sức khỏe tài chính (${response.status})`);
  }

  const result = await response.json();
  return result.data;
}

export default {
  streamChatResponse,
  getFinancialHealth,
};
