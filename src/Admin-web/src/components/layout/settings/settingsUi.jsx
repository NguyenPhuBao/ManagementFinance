import React, { useId } from 'react';

export const inputClass =
  'h-10 w-full rounded-lg border border-line bg-card px-3 text-sm text-ink placeholder:text-ink-faint focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

export const selectClass =
  'h-9 cursor-pointer rounded-lg border border-line bg-card px-3 pr-8 text-sm text-ink focus:border-brand focus:outline-none';

export const SettingRow = ({ label, hint, htmlFor, children, testId }) => (
  <div data-testid={testId} className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-line px-4 py-3">
    <div className="min-w-0 flex-1">
      {htmlFor ? (
        <label htmlFor={htmlFor} className="text-sm font-medium text-ink">
          {label}
        </label>
      ) : (
        <div className="text-sm font-medium text-ink">{label}</div>
      )}
      {hint && <p className="m-0 mt-0.5 text-sm text-ink-muted">{hint}</p>}
    </div>
    <div className="flex flex-wrap items-center gap-2">{children}</div>
  </div>
);

export const Switch = ({ label, checked, onChange }) => (
  <button
    type="button"
    role="switch"
    aria-checked={checked}
    aria-label={label}
    onClick={() => onChange(!checked)}
    className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full transition-colors ${checked ? 'bg-brand' : 'bg-line'}`}
  >
    <span className={`inline-block h-5 w-5 rounded-full bg-card shadow transition-transform ${checked ? 'translate-x-5' : 'translate-x-0.5'}`} />
  </button>
);

export const ChoiceGroup = ({ label, value, options, onChange }) => {
  const name = useId();
  return (
    <div role="radiogroup" aria-label={label} className="inline-flex gap-1 rounded-lg bg-muted p-1">
      {options.map((o) => (
        <label
          key={o.value}
          className={`relative flex h-8 cursor-pointer items-center rounded-md px-3 text-sm ${
            value === o.value ? 'bg-card font-semibold text-ink shadow-sm' : 'font-medium text-ink-muted hover:text-ink'
          }`}
        >
          <input type="radio" name={name} value={o.value} checked={value === o.value} onChange={() => onChange(o.value)} className="sr-only" />
          {o.label}
        </label>
      ))}
    </div>
  );
};

export const Field = ({ label, children, id }) => (
  <div>
    <label htmlFor={id} className="mb-1 block text-sm font-medium text-ink">
      {label}
    </label>
    {children}
  </div>
);

export const FormError = ({ message }) =>
  message ? (
    <p role="alert" className="m-0 rounded-lg bg-danger-soft px-3 py-2 text-sm text-danger">
      {message}
    </p>
  ) : null;

export const digits6 = (v) => v.replace(/\D/g, '').slice(0, 6);
