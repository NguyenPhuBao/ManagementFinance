import React from 'react';

const PageHeader = ({ title, description, actions }) => (
  <div className="flex flex-wrap items-end justify-between gap-3">
    <div className="min-w-0">
      <h1 className="m-0 text-2xl font-bold text-ink">{title}</h1>
      {description && <p className="m-0 mt-1 text-sm text-ink-muted">{description}</p>}
    </div>
    {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
  </div>
);

export default PageHeader;
