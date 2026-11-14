import React from 'react';
import TruncateCell from './TruncateCell';

const METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

const RequestCell = ({ value }) => {
  if (!value) return <span className="text-ink-faint">—</span>;
  const [method, ...rest] = value.trim().split(' ');
  if (!METHODS.includes(method?.toUpperCase())) return <TruncateCell text={value} className="font-mono text-xs text-ink-muted" />;
  return (
    <div className="flex min-w-0 items-center gap-1.5" title={value}>
      <span className="shrink-0 rounded bg-muted px-1.5 py-0.5 font-mono text-xs font-semibold text-ink">{method.toUpperCase()}</span>
      <TruncateCell text={rest.join(' ') || value} className="font-mono text-xs text-ink-muted" />
    </div>
  );
};

export default RequestCell;
