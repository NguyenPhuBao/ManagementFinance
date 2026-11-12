import React from 'react';
import Icon from './Icon';
import { useLanguageSafe } from '../../store/language.context';

const pageNumbers = (current, total) => {
  if (total <= 6) return Array.from({ length: total }, (_, i) => i + 1);
  if (current <= 3) return [1, 2, 3, 4, '...', total];
  if (current >= total - 2) return [1, '...', total - 3, total - 2, total - 1, total];
  return [1, '...', current - 1, current, current + 1, '...', total];
};

const navClass =
  'inline-flex h-9 min-w-9 cursor-pointer items-center justify-center rounded-lg border px-2 text-sm transition-colors disabled:cursor-not-allowed disabled:opacity-40';

const Pagination = ({
  currentPage = 1,
  pageSize = 10,
  total = 0,
  pageSizeOptions = [5, 10, 20, 50],
  onPageChange,
  onPageSizeChange,
  itemLabel,
}) => {
  const { t } = useLanguageSafe();
  const totalPages = Math.ceil(total / pageSize) || 1;
  const page = Math.min(Math.max(1, currentPage), totalPages);
  const start = total > 0 ? (page - 1) * pageSize + 1 : 0;
  const end = Math.min(page * pageSize, total);
  const go = (p) => onPageChange && onPageChange(p);

  return (
    <div className="flex flex-col items-center justify-between gap-3 border-t border-line px-4 py-3 text-sm text-ink-muted sm:flex-row">
      <span className="tabular-nums">
        {start}–{end} / {total} {itemLabel || t('common.pagination.items', 'bản ghi')}
      </span>
      <div className="flex flex-wrap items-center gap-3">
        <select
          value={pageSize}
          aria-label={t('common.pagination.itemsPerPage', 'dòng / trang')}
          onChange={(e) => {
            const size = parseInt(e.target.value, 10);
            if (onPageSizeChange) onPageSizeChange(size);
            else go(1);
          }}
          className="h-9 cursor-pointer rounded-lg border border-line bg-card px-2 text-sm text-ink focus:border-brand focus:outline-none"
        >
          {pageSizeOptions.map((opt) => (
            <option key={opt} value={opt}>
              {opt} {t('common.pagination.itemsPerPage', 'dòng / trang')}
            </option>
          ))}
        </select>
        <div className="flex items-center gap-1">
          <button
            type="button"
            aria-label={t('common.pagination.previous', 'Trang trước')}
            disabled={page <= 1}
            onClick={() => go(page - 1)}
            className={`${navClass} border-line bg-card text-ink-muted hover:bg-muted`}
          >
            <Icon name="chevron_left" size="sm" />
          </button>
          {pageNumbers(page, totalPages).map((p, i) =>
            p === '...' ? (
              <span key={`gap-${i}`} className="inline-flex h-9 min-w-9 items-center justify-center">
                …
              </span>
            ) : (
              <button
                key={p}
                type="button"
                aria-current={p === page ? 'page' : undefined}
                onClick={() => go(p)}
                className={`${navClass} ${
                  p === page ? 'border-brand bg-brand font-semibold text-brand-on' : 'border-line bg-card text-ink hover:bg-muted'
                }`}
              >
                {p}
              </button>
            )
          )}
          <button
            type="button"
            aria-label={t('common.pagination.next', 'Trang tiếp')}
            disabled={page >= totalPages}
            onClick={() => go(page + 1)}
            className={`${navClass} border-line bg-card text-ink-muted hover:bg-muted`}
          >
            <Icon name="chevron_right" size="sm" />
          </button>
        </div>
      </div>
    </div>
  );
};

export default Pagination;
