import React from 'react';

const Pagination = ({
  currentPage = 1,
  pageSize = 10,
  total = 0,
  pageSizeOptions = [5, 10, 20, 50],
  onPageChange,
  onPageSizeChange,
  itemLabel = 'items',
}) => {
  const totalPages = Math.ceil(total / pageSize) || 1;
  const currPage = Math.min(Math.max(1, currentPage), totalPages);

  const startItem = total > 0 ? (currPage - 1) * pageSize + 1 : 0;
  const endItem = Math.min(currPage * pageSize, total);

  const getPageNumbers = (curr, total) => {
    if (total <= 5) {
      return Array.from({ length: total }, (_, i) => i + 1);
    }
    if (curr <= 2) {
      return [1, 2, 3, '...', total];
    }
    if (curr >= total - 1) {
      return [1, '...', total - 2, total - 1, total];
    }
    return [1, '...', curr - 1, curr, curr + 1, '...', total];
  };

  return (
    <div className="p-3.5 px-5 border-t border-outline-variant flex flex-col sm:flex-row items-center justify-between gap-3 bg-surface-container-lowest text-[12px] text-on-surface-variant select-none">
      {/* Left: Item Range */}
      <div>
        <span>{startItem} - {endItem} of {total} {itemLabel}</span>
      </div>

      {/* Right: Page Size & Pagination Buttons */}
      <div className="flex items-center gap-3">
        {/* Custom Styled Select */}
        <div className="relative inline-flex items-center">
          <select
            value={pageSize}
            onChange={(e) => {
              const newSize = parseInt(e.target.value, 10);
              if (onPageSizeChange) {
                onPageSizeChange(newSize);
              }
              if (onPageChange) {
                onPageChange(1);
              }
            }}
            className="appearance-none bg-white border border-outline-variant rounded-md pl-3 pr-8 py-1 text-[12px] text-on-surface font-medium cursor-pointer focus:outline-none focus:border-primary shadow-2xs"
          >
            {pageSizeOptions.map((opt) => (
              <option key={opt} value={opt}>
                {opt} / page
              </option>
            ))}
          </select>
          <span className="material-symbols-outlined text-[18px] text-on-surface-variant pointer-events-none absolute right-1.5">
            arrow_drop_down
          </span>
        </div>

        <div className="flex items-center gap-1">
          {/* Prev Button */}
          <button
            onClick={() => onPageChange && onPageChange(Math.max(1, currPage - 1))}
            disabled={currPage <= 1}
            className={`w-7 h-7 flex items-center justify-center rounded border border-outline-variant/60 text-on-surface transition-colors cursor-pointer ${
              currPage <= 1 ? 'opacity-30 pointer-events-none' : 'hover:bg-surface-container-low'
            }`}
            title="Trang trước"
          >
            <span className="material-symbols-outlined text-[16px]">chevron_left</span>
          </button>

          {/* Smart Page numbers */}
          {getPageNumbers(currPage, totalPages).map((p, idx) => {
            if (p === '...') {
              return (
                <span key={`ellipsis-${idx}`} className="w-7 h-7 flex items-center justify-center text-on-surface-variant font-medium text-[12px]">
                  ...
                </span>
              );
            }
            const isActive = p === currPage;
            return (
              <button
                key={p}
                onClick={() => onPageChange && onPageChange(p)}
                className={`w-7 h-7 flex items-center justify-center rounded text-[12px] font-medium transition-colors cursor-pointer ${
                  isActive
                    ? 'border border-primary text-primary font-bold bg-primary/10'
                    : 'border border-transparent text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface'
                }`}
              >
                {p}
              </button>
            );
          })}

          {/* Next Button */}
          <button
            onClick={() => onPageChange && onPageChange(Math.min(totalPages, currPage + 1))}
            disabled={currPage >= totalPages}
            className={`w-7 h-7 flex items-center justify-center rounded border border-outline-variant/60 text-on-surface transition-colors cursor-pointer ${
              currPage >= totalPages ? 'opacity-30 pointer-events-none' : 'hover:bg-surface-container-low'
            }`}
            title="Trang tiếp"
          >
            <span className="material-symbols-outlined text-[16px]">chevron_right</span>
          </button>
        </div>
      </div>
    </div>
  );
};

export default Pagination;
