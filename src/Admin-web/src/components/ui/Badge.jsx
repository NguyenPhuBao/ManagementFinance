import React from 'react';

const TONES = {
  success: 'bg-success-soft text-success',
  warning: 'bg-warning-soft text-warning',
  danger: 'bg-danger-soft text-danger',
  neutral: 'bg-quiet-soft text-quiet',
  info: 'bg-info-soft text-info',
};

const Badge = ({ tone = 'neutral', children }) => (
  <span
    data-tone={tone}
    className={`inline-flex h-6 items-center whitespace-nowrap rounded-full px-2.5 text-xs font-semibold ${TONES[tone]}`}
  >
    {children}
  </span>
);

export default Badge;
