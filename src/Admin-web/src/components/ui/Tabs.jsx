import React from 'react';

const Tabs = ({ items, value, onChange, ariaLabel }) => (
  <div role="tablist" aria-label={ariaLabel} className="inline-flex flex-wrap gap-1 rounded-lg bg-muted p-1">
    {items.map((item) => {
      const selected = item.key === value;
      return (
        <button
          key={item.key}
          type="button"
          role="tab"
          aria-selected={selected}
          onClick={() => onChange(item.key)}
          className={`h-8 cursor-pointer rounded-md px-3 text-sm transition-colors ${
            selected ? 'bg-card font-semibold text-ink shadow-sm' : 'font-medium text-ink-muted hover:text-ink'
          }`}
        >
          {item.label}
          {item.count !== undefined && <span className="ml-1.5 text-xs tabular-nums text-ink-faint">{item.count}</span>}
        </button>
      );
    })}
  </div>
);

export default Tabs;
