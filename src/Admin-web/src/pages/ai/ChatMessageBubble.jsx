import React, { useState } from 'react';

/**
 * Hiển thị bong bóng tin nhắn chat hỗ trợ định dạng Markdown đơn giản & trích dẫn RAG
 * @param {Object} props
 * @param {'user'|'assistant'|'system'} props.role
 * @param {string} props.content
 * @param {Array} [props.sources] - Danh sách trích dẫn RAG [{ title, law_reference, ... }]
 * @param {boolean} [props.isStreaming]
 * @param {string} [props.timestamp]
 */
const ChatMessageBubble = ({ role, content, sources = [], isStreaming = false, timestamp }) => {
  const isUser = role === 'user';
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    if (!content) return;
    navigator.clipboard.writeText(content);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // Hàm render Markdown cơ bản không cần thư viện ngoài
  const renderFormattedContent = (text) => {
    if (!text) return null;

    const lines = text.split('\n');
    return lines.map((line, idx) => {
      // Heading 3: ###
      if (line.startsWith('### ')) {
        return (
          <h4 key={idx} className="font-bold text-gray-900 mt-2 mb-1 text-sm">
            {line.replace('### ', '')}
          </h4>
        );
      }
      // Heading 2: ##
      if (line.startsWith('## ')) {
        return (
          <h3 key={idx} className="font-bold text-gray-900 mt-3 mb-1.5 text-base border-b pb-1">
            {line.replace('## ', '')}
          </h3>
        );
      }
      // Bullet list item
      if (line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
        const bulletText = line.trim().substring(2);
        return (
          <li key={idx} className="ml-4 list-disc text-sm text-gray-700 my-0.5">
            {renderInlineMarkdown(bulletText)}
          </li>
        );
      }
      // Numbered list item: 1. , 2.
      const numberedMatch = line.trim().match(/^(\d+)\.\s+(.*)/);
      if (numberedMatch) {
        return (
          <li key={idx} className="ml-4 list-decimal text-sm text-gray-700 my-0.5">
            {renderInlineMarkdown(numberedMatch[2])}
          </li>
        );
      }
      // Empty line -> break
      if (!line.trim()) {
        return <div key={idx} className="h-2" />;
      }

      // Regular paragraph
      return (
        <p key={idx} className={`text-sm leading-relaxed my-1 ${isUser ? 'text-white' : 'text-gray-800'}`}>
          {renderInlineMarkdown(line)}
        </p>
      );
    });
  };

  // Render in đậm **bold** và `code`
  const renderInlineMarkdown = (str) => {
    const parts = [];
    let remaining = str;
    let keyIdx = 0;

    // Pattern tìm **in đậm** hoặc `code`
    const regex = /(\*\*[^*]+\*\*|`[^`]+`)/g;
    let match;
    let lastIndex = 0;

    while ((match = regex.exec(str)) !== null) {
      if (match.index > lastIndex) {
        parts.push(str.substring(lastIndex, match.index));
      }
      const token = match[0];
      if (token.startsWith('**') && token.endsWith('**')) {
        parts.push(
          <strong key={keyIdx++} className="font-semibold text-gray-900">
            {token.slice(2, -2)}
          </strong>
        );
      } else if (token.startsWith('`') && token.endsWith('`')) {
        parts.push(
          <code
            key={keyIdx++}
            className="px-1 py-0.5 bg-gray-100 text-pink-600 rounded text-xs font-mono"
          >
            {token.slice(1, -1)}
          </code>
        );
      }
      lastIndex = regex.lastIndex;
    }

    if (lastIndex < str.length) {
      parts.push(str.substring(lastIndex));
    }

    return parts.length > 0 ? parts : str;
  };

  return (
    <div className={`flex gap-3 my-3 ${isUser ? 'justify-end' : 'justify-start'}`}>
      {/* Avatar AI */}
      {!isUser && (
        <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-primary to-indigo-600 flex items-center justify-center text-white flex-shrink-0 shadow-sm mt-0.5">
          <span className="material-symbols-outlined text-sm">smart_toy</span>
        </div>
      )}

      {/* Bong bóng nội dung */}
      <div
        className={`relative max-w-[80%] rounded-2xl p-4 shadow-sm transition-all group ${
          isUser
            ? 'bg-primary text-white rounded-tr-none'
            : 'bg-white text-gray-800 rounded-tl-none border border-outline-variant hover:border-gray-300'
        }`}
      >
        {/* Nút copy nhỏ hiển thị khi hover */}
        {!isUser && content && (
          <button
            onClick={handleCopy}
            title="Sao chép nội dung"
            className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity p-1 rounded-md text-gray-400 hover:text-gray-600 hover:bg-gray-100"
          >
            <span className="material-symbols-outlined text-xs">
              {copied ? 'check' : 'content_copy'}
            </span>
          </button>
        )}

        {/* Thân tin nhắn */}
        <div className="prose prose-sm max-w-none">
          {renderFormattedContent(content)}
        </div>

        {/* Con trỏ typing khi đang stream */}
        {isStreaming && (
          <span className="inline-block w-2 h-4 bg-primary animate-pulse ml-1 align-middle" />
        )}

        {/* Trích dẫn nguồn tài liệu RAG */}
        {!isUser && sources && sources.length > 0 && (
          <div className="mt-3 pt-2.5 border-t border-gray-100">
            <div className="text-[11px] font-semibold text-gray-400 flex items-center gap-1 mb-1.5">
              <span className="material-symbols-outlined text-xs">auto_stories</span>
              Căn cứ pháp lý & cẩm nang tài chính:
            </div>
            <div className="flex flex-wrap gap-1.5">
              {sources.map((src, i) => (
                <span
                  key={i}
                  className="inline-flex items-center gap-1 text-[11px] px-2 py-0.5 rounded-md bg-blue-50 text-blue-700 border border-blue-200"
                  title={src.description || src.summary || ''}
                >
                  <span className="material-symbols-outlined text-[10px]">verified</span>
                  {src.title}
                </span>
              ))}
            </div>
          </div>
        )}

        {/* Dấu thời gian */}
        {timestamp && (
          <div
            className={`text-[10px] mt-1 text-right ${
              isUser ? 'text-blue-100' : 'text-gray-400'
            }`}
          >
            {timestamp}
          </div>
        )}
      </div>

      {/* Avatar User */}
      {isUser && (
        <div className="w-8 h-8 rounded-full bg-gray-700 flex items-center justify-center text-white flex-shrink-0 shadow-sm mt-0.5">
          <span className="material-symbols-outlined text-sm">person</span>
        </div>
      )}
    </div>
  );
};

export default ChatMessageBubble;
