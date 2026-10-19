import React from 'react';

/**
 * Component TruncateCell: Ô dữ liệu tự động cắt chữ bằng dấu ba chấm `...` và hiển thị tooltip đầy đủ khi hover
 * @param {string} text - Nội dung chuỗi
 * @param {string} tooltip - Nội dung tooltip tùy biến (mặc định lấy text hoặc children dạng chuỗi)
 * @param {string} className - Class CSS bổ sung
 * @param {React.ReactNode} children - Nội dung con (nếu có)
 */
export default function TruncateCell({
  text,
  tooltip,
  className = '',
  children,
  ...props
}) {
  const displayContent = children !== undefined ? children : text;
  
  // Xác định text title hiển thị tooltip
  let titleText = tooltip;
  if (!titleText) {
    if (typeof text === 'string') {
      titleText = text;
    } else if (typeof displayContent === 'string') {
      titleText = displayContent;
    } else {
      titleText = '';
    }
  }

  return (
    <div
      className={`truncate block max-w-full overflow-hidden text-ellipsis whitespace-nowrap ${className}`}
      title={titleText || undefined}
      {...props}
    >
      {displayContent}
    </div>
  );
}
