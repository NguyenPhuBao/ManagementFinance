import React from 'react';

const HINT_TONES = {
  neutral: 'text-ink-faint',
  success: 'text-success',
  warning: 'text-warning',
  danger: 'text-danger',
};

const StatCard = ({ label, value, hint, hintTone = 'neutral' }) => (
  <div className="rounded-xl border border-line bg-card px-5 py-4">
    <div className="text-sm text-ink-muted">{label}</div>
    <div className="mt-1.5 text-2xl font-bold tabular-nums text-ink">{value}</div>
    {hint && <div className={`mt-1 text-xs ${HINT_TONES[hintTone]}`}>{hint}</div>}
  </div>
);

export default StatCard;
