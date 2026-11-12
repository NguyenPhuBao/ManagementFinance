import React from 'react';

const Card = ({ title, actions, padded = false, className = '', children }) => (
  <section className={`overflow-hidden rounded-xl border border-line bg-card ${className}`}>
    {(title || actions) && (
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-5 py-4">
        {title && <h2 className="m-0 text-base font-semibold text-ink">{title}</h2>}
        {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
      </div>
    )}
    {padded ? <div className="p-5">{children}</div> : children}
  </section>
);

export default Card;
