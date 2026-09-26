import React from 'react';

const DEFAULT_SUGGESTIONS = [
  {
    icon: 'bar_chart',
    text: 'Tháng này tôi tiêu nhiều nhất vào khoản nào?',
    color: 'hover:border-indigo-300 hover:bg-indigo-50/50 text-indigo-700',
  },
  {
    icon: 'two_wheeler',
    text: 'Với thu nhập hiện tại, tôi có nên mua xe máy mới không?',
    color: 'hover:border-amber-300 hover:bg-amber-50/50 text-amber-700',
  },
  {
    icon: 'trending_down',
    text: 'Lập kế hoạch trả hết nợ trong 6 tháng giúp tôi',
    color: 'hover:border-rose-300 hover:bg-rose-50/50 text-rose-700',
  },
  {
    icon: 'security',
    text: 'Đánh giá quỹ dự phòng khẩn cấp của tôi',
    color: 'hover:border-emerald-300 hover:bg-emerald-50/50 text-emerald-700',
  },
];

/**
 * Các chip gợi ý câu hỏi mẫu nhanh cho người dùng
 * @param {Object} props
 * @param {Function} props.onSelect - Callback khi click chọn câu hỏi
 * @param {boolean} [props.disabled] - Vô hiệu hóa khi đang stream
 */
const PromptSuggestionChips = ({ onSelect, disabled = false }) => {
  return (
    <div className="flex flex-wrap gap-2 my-2">
      {DEFAULT_SUGGESTIONS.map((sug, idx) => (
        <button
          key={idx}
          disabled={disabled}
          onClick={() => onSelect(sug.text)}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium border border-outline-variant bg-white transition-all shadow-xs cursor-pointer active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed ${sug.color}`}
        >
          <span className="material-symbols-outlined text-sm">{sug.icon}</span>
          <span>{sug.text}</span>
        </button>
      ))}
    </div>
  );
};

export default PromptSuggestionChips;
