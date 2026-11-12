import React from 'react';
import Spinner from './Spinner';
import EmptyState from './EmptyState';

const ALIGN = { left: 'text-left', center: 'text-center', right: 'text-right' };

const DataTable = ({ columns, rows, rowKey, loading = false, emptyTitle, emptyDescription, minWidth = 720 }) => {
  const keyOf = (row, index) => (typeof rowKey === 'function' ? rowKey(row, index) : row[rowKey] ?? index);
  const showEmpty = !loading && rows.length === 0;
  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse text-sm" style={{ minWidth }}>
        <thead>
          <tr className="bg-muted/60">
            {columns.map((col) => (
              <th
                key={col.key}
                scope="col"
                className={`px-4 py-3 text-xs font-semibold uppercase tracking-wide text-ink-muted ${ALIGN[col.align || 'left']}`}
                style={col.width ? { width: col.width } : undefined}
              >
                {col.title}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {!loading &&
            rows.map((row, index) => (
              <tr key={keyOf(row, index)} className="border-t border-line hover:bg-muted/40">
                {columns.map((col) => (
                  <td key={col.key} className={`px-4 py-3 text-ink ${ALIGN[col.align || 'left']}`}>
                    {col.render ? col.render(row, index) : row[col.key]}
                  </td>
                ))}
              </tr>
            ))}
        </tbody>
      </table>
      {loading && (
        <div className="flex justify-center py-12 text-brand">
          <Spinner size="lg" />
        </div>
      )}
      {showEmpty && <EmptyState title={emptyTitle} description={emptyDescription} />}
    </div>
  );
};

export default DataTable;
