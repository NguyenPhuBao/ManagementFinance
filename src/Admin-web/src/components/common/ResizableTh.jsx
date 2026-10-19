import React from 'react';

/**
 * Component ResizableTh: Thẻ <th> hỗ trợ co dãn độ rộng kéo thả kiểu Excel
 * @param {string} colKey - Khóa duy nhất của cột
 * @param {number} width - Độ rộng hiện tại theo pixel
 * @param {number} minWidth - Độ rộng tối thiểu
 * @param {function} onResize - Callback khi bắt đầu kéo (colKey, startX, startWidth)
 * @param {function} onReset - Callback khi double click để khôi phục mặc định
 * @param {boolean} resizable - Cho phép kéo thả hay không (mặc định true)
 * @param {string} className - Class CSS bổ sung
 * @param {React.ReactNode} children - Nội dung hiển thị của header
 */
export default function ResizableTh({
  colKey,
  width,
  minWidth = 60,
  onResize,
  onReset,
  resizable = true,
  className = '',
  style = {},
  children,
  ...props
}) {
  const inlineStyle = {
    ...style,
    width: width !== undefined && width !== null ? `${width}px` : undefined,
    minWidth: minWidth !== undefined && minWidth !== null ? `${minWidth}px` : undefined,
  };

  return (
    <th
      style={inlineStyle}
      className={`relative select-none ${className}`}
      {...props}
    >
      <div className="w-full flex items-center justify-between pr-2">
        <div className="truncate flex-1">{children}</div>
      </div>

      {resizable && (
        <div
          role="separator"
          aria-orientation="vertical"
          data-testid={`resize-handle-${colKey}`}
          className="absolute right-0 top-0 bottom-0 w-2.5 cursor-col-resize flex justify-center items-center group/resize z-10 touch-none select-none"
          title="Kéo để chỉnh độ rộng cột / Nhấp đúp để khôi phục mặc định"
          onMouseDown={(e) => {
            e.preventDefault();
            e.stopPropagation();
            if (onResize) onResize(colKey, e.clientX, width);
          }}
          onDoubleClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            if (onReset) onReset(colKey);
          }}
        >
          {/* Thanh phân cách vạch kẻ hiển thị khi hover hoặc kéo chuột */}
          <div className="w-[1.5px] h-full bg-outline-variant/60 group-hover/resize:w-[3px] group-hover/resize:bg-primary transition-all duration-150" />
        </div>
      )}
    </th>
  );
}
