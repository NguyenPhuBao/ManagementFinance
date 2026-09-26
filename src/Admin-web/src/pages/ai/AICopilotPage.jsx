import React, { useState, useEffect, useRef } from 'react';
import FinancialHealthCard from './FinancialHealthCard';
import ChatMessageBubble from './ChatMessageBubble';
import PromptSuggestionChips from './PromptSuggestionChips';
import { streamChatResponse, getFinancialHealth } from '../../api/chatbot.api';

const AICopilotPage = () => {
  const [messages, setMessages] = useState([]);
  const [inputValue, setInputValue] = useState('');
  const [isStreaming, setIsStreaming] = useState(false);
  const [fhsData, setFhsData] = useState(null);
  const [loadingFhs, setLoadingFhs] = useState(false);
  const [debugMeta, setDebugMeta] = useState(null);
  const [showDebug, setShowDebug] = useState(false);
  const [errorMessage, setErrorMessage] = useState(null);

  const messagesEndRef = useRef(null);
  const abortControllerRef = useRef(null);
  const textareaRef = useRef(null);

  // Tự động tải FHS ban đầu nếu có token
  useEffect(() => {
    fetchFhsInitial();
  }, []);

  // Tự động cuộn xuống đáy khi có tin nhắn mới hoặc delta stream
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isStreaming]);

  const fetchFhsInitial = async () => {
    setLoadingFhs(true);
    try {
      const data = await getFinancialHealth();
      if (data?.fhs) {
        setFhsData(data.fhs);
        setDebugMeta(data);
      }
    } catch (err) {
      console.warn('[Copilot] Chưa có dữ liệu FHS ban đầu:', err.message);
    } finally {
      setLoadingFhs(false);
    }
  };

  const handleSendMessage = async (textToSend) => {
    const text = (textToSend || inputValue).trim();
    if (!text || isStreaming) return;

    setErrorMessage(null);
    setInputValue('');

    const now = new Date().toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Ho_Chi_Minh' });
    const userMsgId = `user_${Date.now()}`;
    const botMsgId = `bot_${Date.now()}`;

    // Thêm tin nhắn của User
    const newMessages = [
      ...messages,
      {
        id: userMsgId,
        role: 'user',
        content: text,
        timestamp: now,
      },
    ];

    // Tạo sẵn bong bóng tin nhắn trống cho AI để stream vào
    const botMsg = {
      id: botMsgId,
      role: 'assistant',
      content: '',
      sources: [],
      timestamp: now,
    };

    setMessages([...newMessages, botMsg]);
    setIsStreaming(true);

    // Chuẩn bị conversation history gửi lên server (tối đa 6 lượt trao đổi gần nhất)
    const historyPayload = messages.slice(-6).map((m) => ({
      role: m.role === 'user' ? 'user' : 'model',
      content: m.content,
    }));

    const abortController = new AbortController();
    abortControllerRef.current = abortController;

    let accumulatedContent = '';

    await streamChatResponse({
      message: text,
      conversationHistory: historyPayload,
      signal: abortController.signal,
      onMeta: (meta) => {
        setDebugMeta(meta);
        if (meta?.fhs) {
          setFhsData(meta.fhs);
        }
        if (meta?.ragSnippets) {
          setMessages((prev) =>
            prev.map((m) =>
              m.id === botMsgId ? { ...m, sources: meta.ragSnippets } : m
            )
          );
        }
      },
      onDelta: (chunk) => {
        accumulatedContent += chunk;
        setMessages((prev) =>
          prev.map((m) =>
            m.id === botMsgId ? { ...m, content: accumulatedContent } : m
          )
        );
      },
      onError: (err) => {
        setErrorMessage(err.message || 'Không thể kết nối đến Trợ lý AI');
        setIsStreaming(false);
      },
      onDone: () => {
        setIsStreaming(false);
        abortControllerRef.current = null;
      },
    });
  };

  const handleStopStream = () => {
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
      abortControllerRef.current = null;
      setIsStreaming(false);
    }
  };

  const handleClearChat = () => {
    if (isStreaming) handleStopStream();
    setMessages([]);
    setErrorMessage(null);
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  return (
    <div className="h-[calc(100vh-80px)] flex flex-col p-4 md:p-6 bg-gray-50/50">
      {/* Header thanh công cụ Copilot */}
      <div className="flex flex-wrap items-center justify-between gap-4 mb-4 pb-3 border-b border-outline-variant bg-white p-4 rounded-2xl shadow-xs">
        <div className="flex items-center gap-3">
          <div className="w-11 h-11 rounded-xl bg-gradient-to-tr from-primary to-indigo-600 flex items-center justify-center text-white shadow-md">
            <span className="material-symbols-outlined text-2xl">smart_toy</span>
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="font-bold text-gray-800 text-lg">AI Financial Copilot</h2>
              <span className="inline-flex items-center gap-1 text-[11px] px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700 font-semibold border border-emerald-200">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                Gemini 2.5 Flash Online
              </span>
            </div>
            <p className="text-xs text-gray-500 mt-0.5">
              Cố vấn tài chính cá nhân hoạch định theo chuẩn CFP®, phân tích số liệu thực tế an toàn dữ liệu
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {/* Nút bật/tắt Debug Panel */}
          <button
            onClick={() => setShowDebug(!showDebug)}
            title="Kiểm tra dữ liệu AI (Snapshot, Tools, RAG)"
            className={`flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium border transition-colors cursor-pointer ${
              showDebug
                ? 'bg-indigo-50 border-indigo-200 text-indigo-700'
                : 'bg-white border-outline-variant text-gray-600 hover:bg-gray-50'
            }`}
          >
            <span className="material-symbols-outlined text-sm">developer_mode</span>
            <span>{showDebug ? 'Đóng Debug' : 'Debug Logs'}</span>
          </button>

          {/* Nút làm mới đoạn hội thoại */}
          <button
            onClick={handleClearChat}
            disabled={messages.length === 0 && !isStreaming}
            className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium border border-outline-variant bg-white text-gray-600 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors cursor-pointer"
          >
            <span className="material-symbols-outlined text-sm">restart_alt</span>
            <span>Hội thoại mới</span>
          </button>
        </div>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 flex gap-5 overflow-hidden">
        {/* Khung Chat Chính (Bên trái) */}
        <div className="flex-1 flex flex-col bg-white rounded-2xl border border-outline-variant shadow-xs overflow-hidden">
          {/* Khu vực thông báo lỗi nếu có */}
          {errorMessage && (
            <div className="mx-4 mt-3 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="material-symbols-outlined text-sm">error</span>
                <span>{errorMessage}</span>
              </div>
              <button
                onClick={() => setErrorMessage(null)}
                className="text-rose-500 hover:text-rose-700 font-bold"
              >
                ✕
              </button>
            </div>
          )}

          {/* Danh sách tin nhắn */}
          <div className="flex-1 overflow-y-auto p-4 md:p-6 space-y-2">
            {messages.length === 0 ? (
              /* Màn hình Chào Mừng (Empty State) */
              <div className="h-full flex flex-col items-center justify-center text-center max-w-lg mx-auto py-10">
                <div className="w-16 h-16 rounded-2xl bg-indigo-50 border border-indigo-100 flex items-center justify-center text-primary mb-4 shadow-xs">
                  <span className="material-symbols-outlined text-3xl">psychology</span>
                </div>
                <h3 className="text-base font-bold text-gray-800 mb-1">
                  Xin chào! Tôi là Trợ Lý Cố Vấn Tài Chính AI
                </h3>
                <p className="text-xs text-gray-500 leading-relaxed mb-6">
                  Tôi có thể giúp bạn phân tích cơ cấu chi tiêu 50/30/20, lập kế hoạch trả nợ, tối ưu hóa thuế TNCN 2026 và đưa ra lời khuyên tài chính cá nhân hóa dựa trên dữ liệu thực tế.
                </p>

                <div className="w-full text-left">
                  <div className="text-[11px] font-semibold text-gray-400 uppercase tracking-wider mb-2 flex items-center gap-1">
                    <span className="material-symbols-outlined text-xs">tips_and_updates</span>
                    Câu hỏi gợi ý nhanh:
                  </div>
                  <PromptSuggestionChips onSelect={(text) => handleSendMessage(text)} disabled={isStreaming} />
                </div>
              </div>
            ) : (
              /* Danh sách các bong bóng chat */
              <>
                {messages.map((msg) => (
                  <ChatMessageBubble
                    key={msg.id}
                    role={msg.role}
                    content={msg.content}
                    sources={msg.sources}
                    isStreaming={isStreaming && msg.role === 'assistant' && !msg.content}
                    timestamp={msg.timestamp}
                  />
                ))}
                <div ref={messagesEndRef} />
              </>
            )}
          </div>

          {/* Khu vực Nhập tin nhắn & Phím thao tác */}
          <div className="p-3 md:p-4 border-t border-outline-variant bg-white">
            {/* Gợi ý nhanh khi đã có tin nhắn */}
            {messages.length > 0 && (
              <div className="mb-2 overflow-x-auto pb-1">
                <PromptSuggestionChips onSelect={(text) => handleSendMessage(text)} disabled={isStreaming} />
              </div>
            )}

            <div className="relative flex items-center gap-2">
              <textarea
                ref={textareaRef}
                value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder="Nhập câu hỏi tài chính (ví dụ: Phân tích chi tiêu tháng này, có nên mua xe không?...)"
                rows={1}
                disabled={isStreaming}
                className="w-full px-4 py-3 pr-24 rounded-xl border border-outline-variant focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary text-sm resize-none disabled:bg-gray-50 disabled:text-gray-400"
              />

              <div className="absolute right-2 flex items-center gap-1">
                {isStreaming ? (
                  <button
                    onClick={handleStopStream}
                    className="flex items-center gap-1 px-3 py-1.5 bg-rose-50 text-rose-600 hover:bg-rose-100 border border-rose-200 rounded-lg text-xs font-semibold cursor-pointer active:scale-95 transition-all"
                  >
                    <span className="material-symbols-outlined text-sm">stop_circle</span>
                    <span>Dừng</span>
                  </button>
                ) : (
                  <button
                    onClick={() => handleSendMessage()}
                    disabled={!inputValue.trim()}
                    className="w-9 h-9 rounded-lg bg-primary hover:bg-primary/90 text-white flex items-center justify-center disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer transition-all shadow-xs active:scale-95"
                  >
                    <span className="material-symbols-outlined text-lg">arrow_upward</span>
                  </button>
                )}
              </div>
            </div>

            <div className="flex justify-between items-center text-[10px] text-gray-400 mt-1.5 px-1">
              <span>Nhấn <kbd className="px-1 py-0.5 bg-gray-100 rounded text-gray-600">Enter</kbd> để gửi, <kbd className="px-1 py-0.5 bg-gray-100 rounded text-gray-600">Shift+Enter</kbd> để xuống dòng</span>
              <span>Thông tin được ẩn danh & bảo vệ theo chuẩn PCI-DSS & ND13</span>
            </div>
          </div>
        </div>

        {/* Cột Phụ (Bên phải): Thẻ FHS & Debug Inspector */}
        <div className="w-80 md:w-96 flex flex-col gap-4 overflow-y-auto">
          {/* Card Sức khỏe tài chính FHS */}
          <FinancialHealthCard fhs={fhsData} loading={loadingFhs} />

          {/* Panel Debug Inspector cho Admin/Tester */}
          {showDebug && (
            <div className="bg-white rounded-2xl p-4 border border-outline-variant shadow-xs text-xs space-y-3">
              <div className="flex items-center justify-between pb-2 border-b border-gray-100">
                <span className="font-bold text-gray-800 flex items-center gap-1">
                  <span className="material-symbols-outlined text-sm text-indigo-500">bug_report</span>
                  Metadata Inspector
                </span>
                <span className="text-[10px] px-1.5 py-0.5 bg-gray-100 rounded text-gray-600">Admin Only</span>
              </div>

              <div>
                <div className="font-semibold text-gray-600 mb-1">RAG Snippets Đã Match:</div>
                {debugMeta?.ragSnippets && debugMeta.ragSnippets.length > 0 ? (
                  <div className="space-y-1">
                    {debugMeta.ragSnippets.map((s, idx) => (
                      <div key={idx} className="p-2 bg-gray-50 rounded border border-gray-200">
                        <div className="font-medium text-primary text-[11px]">{s.title}</div>
                        <div className="text-[10px] text-gray-500 mt-0.5 line-clamp-2">{s.content}</div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-gray-400 italic">Không có tri thức tĩnh được nạp</div>
                )}
              </div>

              <div>
                <div className="font-semibold text-gray-600 mb-1">Raw FHS Snapshot:</div>
                <pre className="p-2 bg-gray-900 text-emerald-400 rounded-lg overflow-x-auto text-[10px] max-h-48 font-mono">
                  {JSON.stringify(debugMeta?.fhs || fhsData || {}, null, 2)}
                </pre>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default AICopilotPage;
