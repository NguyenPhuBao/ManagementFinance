import React from 'react';

export default function TruncateCell({ text, tooltip, className = '', children, ...props }) {
  const content = children !== undefined ? children : text;
  const title = tooltip || (typeof text === 'string' ? text : typeof content === 'string' ? content : '');
  return (
    <div className={`block max-w-full truncate ${className}`} title={title || undefined} {...props}>
      {content}
    </div>
  );
}
